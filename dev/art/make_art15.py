#!/usr/bin/env python3
"""Creed UI's minimap button (original): a round metal bezel with a dark face (MapButton, tinted
the ring's metal in game) and the C crest sunk in it (MapCrest, tinted the title's gold). BLP2 + PNG."""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
SS = 4


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    assert w & (w - 1) == 0 and h & (h - 1) == 0, (name, w, h)
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def grid(w, h):
    xs = (np.arange(w * SS) + 0.5) / (w * SS) * 2 - 1
    ys = (np.arange(h * SS) + 0.5) / (h * SS) * 2 - 1
    return np.meshgrid(xs, ys)


def down(a):
    h, w = a.shape[0] // SS, a.shape[1] // SS
    return a.reshape(h, SS, w, SS).mean(axis=(1, 3))


def premul_down(col, alpha):
    pa, a = down(col * alpha), down(alpha)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a > 1e-6, pa / a, 0)
    c = np.clip(c, 0, 1)
    return np.dstack([c, c, c, np.clip(a, 0, 1)])


def cover(sdf, px):
    return np.clip(0.5 - sdf / px, 0, 1)


def emboss(t, light=(-0.35, -0.75, 0.6), strength=2.2, spec=0.55, power=18):
    hgt = np.sin(np.pi * np.clip(t, 0, 1)) ** 0.85
    gy, gx = np.gradient(hgt)
    nx, ny = -gx * strength * SS, -gy * strength * SS
    nz = np.ones_like(nx)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / n, ny / n, nz / n
    L = np.array(light, dtype=float)
    L = L / np.linalg.norm(L)
    diff = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    H = L + np.array([0, 0, 1.0])
    H = H / np.linalg.norm(H)
    sp = np.clip(nx * H[0] + ny * H[1] + nz * H[2], 0, 1) ** power
    return diff, sp


def rrect(x, y, half, r):
    """Signed distance to a rounded square (negative inside)."""
    qx, qy = np.abs(x) - (half - r), np.abs(y) - (half - r)
    out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    return out + np.minimum(np.maximum(qx, qy), 0) - r


def layer_over(c, a, col, al):
    na = al + a * (1 - al)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(na > 1e-6, (col * al + c * a * (1 - al)) / na, 0)
    return c, na


def metal_ring(d_out, d_in, px, strength=1.2):
    """Coverage and shade of an embossed band between two shapes."""
    outer, hole = cover(d_out, px), cover(d_in, px)
    band = np.clip(outer - hole, 0, 1)
    with np.errstate(invalid="ignore", divide="ignore"):
        t = np.clip(d_in / np.minimum(d_in - d_out, -1e-4) * -1, 0, 1)
        t = np.clip(d_in / np.maximum(d_in - d_out, 1e-4), 0, 1)
    diff, sp = emboss(t, strength=strength)
    g = 0.16 + 0.80 * diff + 0.55 * sp
    edge = np.exp(-(d_out / 0.02) ** 2) + np.exp(-(d_in / 0.018) ** 2)
    g = np.clip(g * (1 - 0.68 * np.clip(edge, 0, 1)), 0, 1.15)
    return band, g, outer, hole



def make_map_button():
    """A round button for the minimap's edge in the ring's metal: a band with a groove and four
    studs, the face inside dark and sunk, its rim shadowed on the lit side's far edge."""
    n = 64
    x, y = grid(n, n)
    px = 2.0 / (n * SS)
    r = np.sqrt(x * x + y * y)
    d_out, d_in = r - 0.95, r - 0.74
    band, g, outer, hole = metal_ring(d_out, d_in, px, 1.6)
    groove = np.exp(-((r - 0.845) / 0.012) ** 2)
    g = g * (1 - 0.3 * groove)
    c, a = np.zeros_like(x), np.zeros_like(x)
    # a soft shadow under it, a little down, so it sits on the map's edge
    drop = np.clip(1 - (np.sqrt(x * x + (y - 0.04) ** 2) - 0.95) / 0.05, 0, 1) ** 2 * 0.55 * (1 - outer)
    c, a = layer_over(c, a, np.zeros_like(x), drop)
    # the face: dark, a touch lighter low (the light falls from the top left into the hollow)
    face = cover(d_in + 0.01, px)
    fg = 0.10 + 0.07 * np.clip((y + 0.2) * 0.8 + 0.3, 0, 1) * np.clip(1 - r / 0.74, 0, 1) ** 0.5
    sh = np.exp(-(np.clip(-d_in, 0, 1) / 0.09) ** 2) * np.clip(-y * 0.7 + 0.5, 0.2, 1)
    fg = fg * (1 - 0.75 * sh)
    c, a = layer_over(c, a, fg, face * 0.97)
    c, a = layer_over(c, a, g, band)
    for k in range(4):
        ang = np.pi / 4 + k * np.pi / 2
        sx, sy = np.cos(ang) * 0.845, np.sin(ang) * 0.845
        d = np.sqrt((x - sx) ** 2 + (y - sy) ** 2) - 0.055
        stud = cover(d, px)
        sd, ssp = emboss(np.clip(-d / 0.055, 0, 1) * 0.5 + 0.5 * stud, strength=0.9)
        c, a = layer_over(c, a, np.clip(0.28 + 0.8 * sd + 0.5 * ssp, 0, 1.1), stud)
    write_blp("MapButton", premul_down(c, a))


def make_map_crest():
    """Creed's C, cut from the addon's own serif (Letters.ttf, from Lora), raised in metal with a
    small diamond held in its bowl and a dark shadow under both so they read on the dark face."""
    from PIL import ImageDraw, ImageFont, ImageFilter
    n = 64
    big = n * SS
    im = Image.new("L", (big, big), 0)
    dr = ImageDraw.Draw(im)
    font = ImageFont.truetype(FONT, int(big * 0.64))
    l, t, rr, b = dr.textbbox((0, 0), "C", font=font)
    cx, cy = big * 0.5 - (l + rr) * 0.5 - big * 0.025, big * 0.5 - (t + b) * 0.5
    dr.text((cx, cy), "C", fill=255, font=font)
    letter = np.asarray(im, dtype=np.float64) / 255.0
    x, y = grid(n, n)
    px = 2.0 / (n * SS)
    # the diamond, held in the C
    dx, dy = x - 0.08, y
    dd = (np.abs(dx) / 0.11 + np.abs(dy) / 0.155 - 1) * 0.1
    gem = cover(dd, px)
    shape = np.maximum(letter, gem)
    # height: the shape's distance in from its edge, as a bevel
    def soft(m, k):
        return np.asarray(Image.fromarray(np.clip(m * 255, 0, 255).astype(np.uint8), "L").filter(
            ImageFilter.GaussianBlur(k * SS)), dtype=np.float64) / 255.0
    t_l = np.clip(soft(letter, 0.9) * 1.6 - 0.3, 0, 1) * letter
    diff, sp = emboss(t_l * 0.5 + 0.5 * letter, strength=1.3)
    gl = np.clip(0.35 + 0.75 * diff + 0.55 * sp, 0, 1.1)
    # the diamond's four facets, lit from the top left
    pd = np.where(dy < 0, np.where(dx < 0, 1.0, 0.82), np.where(dx < 0, 0.62, 0.45))
    edge = np.exp(-(dd / 0.006) ** 2)
    pd = pd * (1 - 0.5 * np.clip(edge, 0, 1))
    c, a = np.zeros_like(x), np.zeros_like(x)
    shadow = soft(np.roll(np.roll(shape, int(0.9 * SS), axis=0), int(0.5 * SS), axis=1), 1.0)
    c, a = layer_over(c, a, np.zeros_like(x), np.clip(shadow * 1.4, 0, 0.85))
    c, a = layer_over(c, a, gl, letter)
    c, a = layer_over(c, a, pd, gem)
    write_blp("MapCrest", premul_down(c, a))


FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "CreedUI", "Fonts", "Letters.ttf")
make_map_button()
make_map_crest()
