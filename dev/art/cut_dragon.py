#!/usr/bin/env python3
"""Creed UI's panel dragon, from the user's own bar picture (source/bar_reference.webp, 2000x667, made
for them with an image generator): the left dragon, facing in, lifted off the picture by its gold
(warm, bright) against the frame's grey metal and dark wood, the frame's bits beside it cut away, as
a 256x256 painted texture (its own colors; the game doesn't tint it). The right dragon is the same,
mirrored. Where it sits, as fractions of the texture: the panel's end at x 15/370, its foot at
y 345/370, the eye at (0.872, 0.236); Core's C.Panel uses these.

usage: cut_dragon.py <source picture> <blp folder> <png folder>"""
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SRC, OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


im = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32) / 255
C = im[100:470, 0:370]                      # the left dragon and the panel's end under it
R, G, B = C[..., 0], C[..., 1], C[..., 2]
lum = 0.3 * R + 0.59 * G + 0.11 * B
a = np.clip((R - B - 0.16) / 0.14, 0, 1) * np.clip((lum - 0.10) / 0.10, 0, 1)   # its gold
H, W = a.shape
yy, xx = np.mgrid[0:H, 0:W]
# not the dragon: the first slot, the XP bar's end gem, the bottom rail right of the tail, a rail
# stub behind the neck
a[(xx >= 313) & (yy >= 180) & (yy <= 310)] = 0
a[(xx >= 352) & (yy >= 100) & (yy <= 170)] = 0
a[(xx >= 300) & (yy >= 300)] = 0
a[(xx >= 204) & (xx <= 242) & (yy >= 84) & (yy <= 104) & (R - B < 0.5)] = 0
m = ndimage.binary_closing(a > 0.5, iterations=2)
# the dark crevices between its scales filled; the open gaps (between wing and neck) left open
lab, n = ndimage.label(~m)
for i, size in enumerate(ndimage.sum(np.ones_like(lab), lab, range(1, n + 1)), 1):
    if size < 260:
        m[lab == i] = True
# only the dragon itself (and its base flourish): the big pieces
lab, n = ndimage.label(m)
keep = np.zeros_like(m)
for i, size in enumerate(ndimage.sum(np.ones_like(lab), lab, range(1, n + 1)), 1):
    if size > 1500:
        keep |= (lab == i)
alpha = np.clip(ndimage.gaussian_filter(keep.astype(np.float32), 0.8) * 1.15, 0, 1)
rgba = np.dstack([C, alpha])
img = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").resize((256, 256), Image.LANCZOS)
write_blp("PanelDragon", np.asarray(img).astype(np.float32) / 255)
print("PanelDragon from", SRC)
