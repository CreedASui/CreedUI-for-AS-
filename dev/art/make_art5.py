#!/usr/bin/env python3
"""Creed UI's shield stripes: 256x16, white diagonal stripes (one every 8 px, 3 px wide, 45
degrees) with soft edges, for an additive overlay. BLP2 (uncompressed BGRA) + PNG."""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    assert w & (w - 1) == 0 and h & (h - 1) == 0 and 8 <= w <= 512 and 8 <= h <= 512, (name, w, h)
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def make_stripes():
    W, H, SS, PERIOD, WIDTH = 256, 16, 8, 8.0, 3.0
    ys, xs = np.mgrid[0:H * SS, 0:W * SS]
    x = (xs + 0.5) / SS
    y = (ys + 0.5) / SS
    d = np.mod(x + y, PERIOD)  # 45 degrees, rising to the right
    inside = (d < WIDTH).astype(np.float64)
    a = inside.reshape(H, SS, W, SS).mean(axis=(1, 3))
    # a touch brighter along the top, as the bar's gloss
    rows = np.linspace(1.0, 0.75, H)[:, None]
    alpha = np.clip(a * rows, 0, 1)
    rgba = np.dstack([np.ones_like(alpha), np.ones_like(alpha), np.ones_like(alpha), alpha])
    write_blp("Stripes", rgba)


make_stripes()
