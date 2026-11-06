#!/usr/bin/env python3
"""Creed UI's class emblems, from the user's own picture of nine class bars (source/class_bars.webp,
1159x1356, made for them with an image generator; asked for in 1.21.2): for each class, the big
emblem on the bar's left end and the round crest on its right end, lifted off the picture's black
and cut away from its bar, as 256x256 painted textures in their own colors (the game doesn't tint
them): PanelEmblem<Class>L and PanelEmblem<Class>R.

Each picture row is scaled so its rails are RAIL texture pixels apart; the anchor (the emblem's or
crest's middle, on the line midway between the rails) is at ANCHOR_L / ANCHOR_R as shares of the
texture. Core's C.Panel puts that point on the panel's end, the rails then lying on its own.

usage: cut_classes.py <source picture> <blp folder> <png folder>"""
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SRC, OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)

T = 256
RAIL = 110.0                        # texture pixels between the two rails' lines
ANCHOR_L = (160 / T, 0.5)          # the left emblem's middle
ANCHOR_R = (70 / T, 0.5)           # the right crest's middle
# the picture's rows, top to bottom: the class, its top and bottom rail lines (picture pixels)
ROWS = [
    ("Warrior", 38, 148), ("Paladin", 198, 305), ("Hunter", 356, 462), ("Rogue", 512, 618),
    ("Mage", 667, 771), ("Druid", 822, 926), ("Shaman", 975, 1069), ("Priest", 1109, 1196),
    ("Warlock", 1235, 1325),
]
LEFT_X, RIGHT_X = 255, 962          # the emblems' and crests' middles across the picture
BG = np.array([0.035, 0.035, 0.04])  # the picture's black


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


im = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64) / 255
PH, PW, _ = im.shape

# alpha off the black: glows and light by how far they rise above it, solid shapes (dark shields,
# wood) whole, their holes filled
lift = np.clip(im - BG, 0, 1)
glow_a = np.clip(lift.max(axis=2) / 0.32, 0, 1)
solid = lift.max(axis=2) > 0.07
solid = ndimage.binary_opening(solid, iterations=1)
solid = ndimage.binary_fill_holes(solid)
solid_a = ndimage.gaussian_filter(solid.astype(np.float64), 0.7)
solid_a = np.clip(solid_a * 1.2, 0, 1)

yy, xx = np.mgrid[0:PH, 0:PW].astype(np.float64)


def ramp(v, a, b):
    """0 at a, 1 at b (either way round)"""
    return np.clip((v - a) / (b - a), 0, 1)


def cut(name, mid, top_lim, bot_lim, cx, anchor, keep_x, keep_solid, s, disc=None):
    """the picture's piece round (cx, mid), scaled so its rails are RAIL apart, onto a T x T texture"""
    # the picture's region of this row only, faded at its edges, and the bar cut away by keep_x
    # solid only within the emblem itself (keep_solid): the picture's own dark bar beside it goes clear
    w = ramp(yy, top_lim, top_lim + 4) * ramp(yy, bot_lim, bot_lim - 4) * keep_x
    a = np.maximum(glow_a, solid_a * keep_solid) * w
    if disc is not None:  # the round face is whole, whatever its paint (the bar runs behind it)
        a = np.maximum(a, ramp(np.hypot(xx - cx, yy - disc[1]), disc[0] + 2, disc[0] - 2) * w)
    with np.errstate(invalid="ignore", divide="ignore"):
        color_all = np.clip(np.where(a[..., None] > 1e-3, lift / np.maximum(a, 1e-3)[..., None], 0), 0, 1)
    # sample: texture pixel (u, v) -> picture (cx + (u - ax) * s, mid + (v - ay) * s)
    ax, ay = anchor[0] * T, anchor[1] * T
    u = (np.arange(T) + 0.5 - ax) * s + cx
    v = (np.arange(T) + 0.5 - ay) * s + mid
    V, U_ = np.meshgrid(v, u, indexing="ij")
    coords = np.array([V - 0.5, U_ - 0.5])
    pa = ndimage.map_coordinates(a, coords, order=1, mode="constant", cval=0)
    pc = np.dstack([ndimage.map_coordinates(color_all[..., i] * a, coords, order=1, mode="constant", cval=0) for i in range(3)])
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(pa[..., None] > 1e-4, pc / pa[..., None], 0)
    # a soft shadow under it, so it sits on the bar rather than on top of it
    sh = np.clip(ndimage.gaussian_filter(pa, 5) * 0.75, 0, 1) * 0.6
    out_a = pa + sh * (1 - pa)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(out_a[..., None] > 1e-4, c * (pa / np.maximum(out_a, 1e-4))[..., None], 0)
    write_blp(name, np.dstack([np.clip(c, 0, 1), np.clip(out_a, 0, 1)]))


for i, (cls, top, bot) in enumerate(ROWS):
    mid = (top + bot) / 2
    prev_mid = (ROWS[i - 1][1] + ROWS[i - 1][2]) / 2 if i > 0 else -1e9
    next_mid = (ROWS[i + 1][1] + ROWS[i + 1][2]) / 2 if i + 1 < len(ROWS) else 1e9
    top_lim, bot_lim = max(0, (prev_mid + mid) / 2), min(PH, (mid + next_mid) / 2)
    s = (bot - top) / RAIL            # picture pixels per texture pixel
    # left: the emblem and what flies off it to the left; the bar's body faded away past its middle
    # everything on its outer half (wings, capes, smoke); on its inner half, over the bar, only the
    # emblem's round, fading softly out round it (no straight cut), the picture's own rails with it
    keep_l = np.maximum(ramp(xx, LEFT_X + 12 * s, LEFT_X - 4 * s), ramp(np.hypot(xx - LEFT_X, yy - mid), 96 * s, 70 * s))
    solid_l = np.maximum(ramp(xx, LEFT_X + 30 * s, LEFT_X + 20 * s), ramp(np.hypot(xx - LEFT_X, yy - mid), 82 * s, 72 * s))
    # its round face whole too, so the bar's rails and glass never show through it (asked for: the bow)
    cut("PanelEmblem" + cls + "L", mid, top_lim, bot_lim, LEFT_X, ANCHOR_L, keep_l, solid_l, s, (66 * s, mid - 4 * s))
    # right: the crest and its ribbon; the bar's end bracket and its words cut away before it
    keep_r = np.maximum(ramp(xx, RIGHT_X - 6 * s, RIGHT_X + 10 * s), ramp(np.hypot(xx - RIGHT_X, yy - mid - 8 * s), 50 * s, 38 * s))
    solid_r = np.maximum(ramp(xx, RIGHT_X, RIGHT_X + 10 * s), ramp(np.hypot(xx - RIGHT_X, yy - mid - 8 * s), 44 * s, 36 * s))
    cut("PanelEmblem" + cls + "R", mid, top_lim, bot_lim, RIGHT_X, ANCHOR_R, keep_r, solid_r, s, (34 * s, mid + 8 * s))
print("wrote", OUT_BLP)
