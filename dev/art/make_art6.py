#!/usr/bin/env python3
"""Creed UI's sizing arrows: a 64x64 sheet of four 32x32 double-headed arrows, white with a dark
outline so the addon can tint them: across (top left), up and down (top right), and the two
diagonals (bottom: top-left to bottom-right, then top-right to bottom-left). BLP2 + PNG."""
import os
import struct
import sys

import cv2
import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
N, SS = 32, 8


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


def arrow(angle):
    """one cell: a double-headed arrow along `angle` (radians, 0 = across), supersampled mask"""
    n = N * SS
    c = (np.arange(n) + 0.5) / n * 2 - 1
    X, Y = np.meshgrid(c, c)
    ca, sa = np.cos(angle), np.sin(angle)
    u = X * ca + Y * sa        # along the arrow
    v = -X * sa + Y * ca       # across it
    shaft = (np.abs(u) <= 0.5) & (np.abs(v) <= 0.085)
    tip, base, half = 0.80, 0.36, 0.32
    au = np.abs(u)
    head = (au >= base) & (au <= tip) & (np.abs(v) <= half * (tip - au) / (tip - base))
    mask = (shaft | head).astype(np.uint8)
    # a dark outline about a pixel and a quarter wide
    r = int(round(1.25 * SS))
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    ring = cv2.dilate(mask, k)
    fill = mask.astype(np.float64)
    out = ring.astype(np.float64)
    a = np.maximum(fill, out * 0.92)
    col = np.where(fill > 0, 1.0 - 0.18 * (Y + 1) / 2, 0.08)   # a touch of shading, dark rim
    a_d = a.reshape(N, SS, N, SS).mean(axis=(1, 3))
    c_d = (col * a).reshape(N, SS, N, SS).mean(axis=(1, 3))
    with np.errstate(invalid="ignore", divide="ignore"):
        c_d = np.where(a_d > 1e-6, c_d / a_d, 0)
    return np.dstack([c_d, c_d, c_d, a_d])


sheet = np.zeros((64, 64, 4))
sheet[0:32, 0:32] = arrow(0)                 # across
sheet[0:32, 32:64] = arrow(np.pi / 2)        # up and down
sheet[32:64, 0:32] = arrow(np.pi / 4)        # top left to bottom right (y grows down)
sheet[32:64, 32:64] = arrow(-np.pi / 4)      # top right to bottom left
write_blp("Resize", np.clip(sheet, 0, 1))
