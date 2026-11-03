#!/usr/bin/env python3
"""Creed UI's downed-friend art (original): ReviveRing, the same mark with an empty middle for the
friend's class crest; EdgeArrow, the gold arrow at the screen's edge that
points to a fallen friend (pointing up; the game turns it), and ReviveMark, the mark on the spot
where you revive them: a bright ring with a rising spirit, a teardrop flame over two upswept
wings. Both grey-white so the game tints them. BLP2 + PNG."""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
SS = 4
N = 64


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def grid():
    xs = (np.arange(N * SS) + 0.5) / (N * SS) * 2 - 1
    return np.meshgrid(xs, xs)


def down(a):
    return a.reshape(N, SS, N, SS).mean(axis=(1, 3))


def soft(m, k):
    return np.asarray(Image.fromarray(np.clip(m * 255, 0, 255).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(k * SS)), dtype=np.float64) / 255.0


def emboss(hgt, light=(-0.35, -0.75, 0.6), strength=2.0, power=16):
    gy, gx = np.gradient(hgt)
    nx, ny = -gx * strength * SS, -gy * strength * SS
    nz = np.ones_like(nx)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    L = np.array(light) / np.linalg.norm(light)
    diff = np.clip((nx * L[0] + ny * L[1] + nz * L[2]) / n, 0, 1)
    H = (L + np.array([0, 0, 1.0]))
    H = H / np.linalg.norm(H)
    sp = np.clip((nx * H[0] + ny * H[1] + nz * H[2]) / n, 0, 1) ** power
    return diff, sp


def finish(name, grey, alpha):
    pa, a = down(grey * alpha), down(alpha)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a > 1e-6, pa / a, 0)
    c = np.clip(c, 0, 1)
    write_blp(name, np.dstack([c, c, c, np.clip(a, 0, 1)]))


def make_arrow():
    x, y = grid()
    # a broad arrowhead pointing up, its back cut in a shallow V, a short shaft
    head = (y > -0.78) & (y < 0.18) & (np.abs(x) < (y + 0.78) * 0.78)
    notch = (y > 0.18 - 0.0) & (np.abs(x) < 0.0)
    cut = (y > -0.05) & (np.abs(x) < (y + 0.05) * 1.6 + 0.0) & (np.abs(x) > 0.16)
    shaft = (np.abs(x) < 0.15) & (y >= 0.0) & (y < 0.66)
    shape = ((head & ~cut) | shaft).astype(float)
    shape = np.clip((soft(shape, 0.3) - 0.5) * 5 + 0.5, 0, 1)
    body = np.clip(soft(shape, 1.4) * 1.6 - 0.3, 0, 1) * shape
    diff, sp = emboss(body)
    g = np.clip(0.45 + 0.65 * diff + 0.5 * sp, 0, 1.1)
    ridge = np.exp(-(x / 0.03) ** 2) * (y < 0.6) * (y > -0.7)
    g = np.clip(g + 0.25 * ridge * shape, 0, 1.15)
    rim = np.clip(soft(shape, 0.9) * 1.7, 0, 1)
    grey = np.where(shape > 0.02, g, 0.05)
    alpha = np.maximum(rim * 0.9, shape)
    grey = grey * shape + 0.05 * (1 - shape)
    finish("EdgeArrow", grey, alpha)


def make_revive():
    x, y = grid()
    r = np.hypot(x, y)
    ring = np.exp(-((r - 0.80) / 0.055) ** 2)
    halo = np.exp(-((r - 0.80) / 0.16) ** 2) * 0.35
    inner = np.clip(1 - r / 0.8, 0, 1) ** 1.5 * 0.22
    # the spirit: a teardrop flame rising from the middle, two wings swept up from its foot
    t = (y + 0.10)
    drop = (np.hypot(x, (y - 0.05) * 0.9) < 0.20) | ((y < 0.05) & (y > -0.52) & (np.abs(x) < 0.20 * np.clip((y + 0.52) / 0.57, 0, 1) ** 1.2))
    wings = np.zeros_like(x)
    for k in (-1, 1):
        u = k * x
        curve = 0.30 - 0.9 * (u - 0.18) ** 2
        w = (u > 0.12) & (u < 0.58) & (y < curve + 0.02) & (y > curve - 0.13 + 0.12 * (u - 0.12))
        wings = np.maximum(wings, w.astype(float))
    spirit = np.clip(soft(np.maximum(drop.astype(float), wings), 0.35) * 1.6, 0, 1)
    glyph_glow = soft(spirit, 2.0) * 0.5
    alpha = np.clip(ring + halo + inner + spirit + glyph_glow, 0, 1)
    grey = np.clip(0.75 + 0.25 * np.maximum(ring, spirit), 0, 1)
    finish("ReviveMark", grey, alpha)
    # the ring alone, its middle left clear (and a little darker) for the class crest
    alpha = np.clip(ring + halo + inner * 0.6, 0, 1)
    grey = np.clip(0.75 + 0.25 * ring, 0, 1)
    finish("ReviveRing", grey, alpha)


make_arrow()
make_revive()
print("EdgeArrow ReviveMark ReviveRing")
