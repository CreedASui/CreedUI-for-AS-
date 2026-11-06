#!/usr/bin/env python3
"""Creed UI's music button crests (original, 1.23.0, asked for): a play triangle and a pause pair,
raised and beveled like the Creed C on the minimap button, in grey (tinted in game in the class's
metal). BLP2 + PNG, 64x64: MusicPlay, MusicPause.

    python3 make_art23.py <blp dir> <png dir>
"""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
N, SS = 64, 4
BIG = N * SS


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def shape(draw_fn):
    im = Image.new("L", (BIG, BIG), 0)
    draw_fn(ImageDraw.Draw(im))
    return np.asarray(im, dtype=np.float64) / 255


def crest(name, mask):
    # a soft dark outline, then the shape raised: lit from the top left, a fine bright edge
    h = ndimage.gaussian_filter(mask, 2.2 * SS) * mask
    gy, gx = np.gradient(h)
    k = 40.0 * SS
    nx, ny, nz = -gx * k, -gy * k, np.ones_like(h)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    L = np.array([-0.5, -0.7, 0.55]) / np.linalg.norm([-0.5, -0.7, 0.55])
    diff = np.clip((nx * L[0] + ny * L[1] + nz * L[2]) / n, 0, 1)
    v = np.clip(0.35 + 0.75 * diff, 0, 1)
    outline = np.clip(ndimage.gaussian_filter(mask, 1.6 * SS) * 2.2, 0, 1)
    col = v * mask
    a = np.maximum(mask, outline * 0.85)
    c = np.where(a > 1e-4, col / np.maximum(a, 1e-4), 0)
    c = c.reshape(N, SS, N, SS).mean(axis=(1, 3))
    a = a.reshape(N, SS, N, SS).mean(axis=(1, 3))
    write_blp(name, np.dstack([c, c, c, a]))


P = lambda x, y: (x * BIG, y * BIG)
play = shape(lambda d: d.polygon([P(0.36, 0.27), P(0.36, 0.73), P(0.74, 0.50)], fill=255))
pause = shape(lambda d: (d.rounded_rectangle([P(0.32, 0.28), P(0.45, 0.72)], radius=0.03 * BIG, fill=255),
                         d.rounded_rectangle([P(0.55, 0.28), P(0.68, 0.72)], radius=0.03 * BIG, fill=255)))
crest("MusicPlay", play)
crest("MusicPause", pause)
print("wrote", OUT_BLP)
