#!/usr/bin/env python3
"""Creed UI's panel rails, as the timer's: a thin round rail lit from the top left, darkish bronze
with one fine bright line along its lit side, a dark edge. Grey, tinted with the timer's gold.
  PanelRailT/B 64x8, PanelRailL/R 8x64, PanelCornerTL/TR/BL/BR 16x16, PanelDivider 8x64"""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
SS = 8
RAIL = 4.6  # the rail's width, outline to outline
LIGHT = np.array([-0.5, -0.62, 0.6])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1.0])
HALF = HALF / np.linalg.norm(HALF)


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


def grid(w, h):
    ys, xs = np.mgrid[0:h * SS, 0:w * SS]
    return (xs + 0.5) / SS, (ys + 0.5) / SS


def rail(d):
    """value, alpha of the rail by depth from its outer edge (pixels)"""
    t = (d - 0.6) / (RAIL - 1.1)
    inside = (t > 0) & (t < 1)
    hgt = np.where(inside, np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1)) * (RAIL - 1.1) * 0.5, 0)
    gy, gx = np.gradient(hgt * SS)
    n = np.dstack([-gx, -gy, np.ones_like(hgt)])
    n = n / np.linalg.norm(n, axis=2, keepdims=True)
    diff = np.clip(n @ LIGHT, 0, 1)
    spec = np.clip(n @ HALF, 0, 1) ** 14
    v = np.clip(0.2 + 0.5 * diff + 1.0 * spec, 0, 1)
    outer = (d >= 0) & (d <= 0.6)
    inner = (d >= RAIL - 0.5) & (d < RAIL)
    edge = outer | inner
    v = np.where(outer, 0.42, np.where(inner, 0.04, v))
    a = np.where(inside, 1.0, np.where(edge, 0.9, 0.0))
    a = np.where(d < 0, 0, a)
    return v, a


def finish(name, v, a, w, h):
    al = a.reshape(h, SS, w, SS).mean(axis=(1, 3))
    va = (v * a).reshape(h, SS, w, SS).mean(axis=(1, 3))
    with np.errstate(invalid="ignore", divide="ignore"):
        va = np.where(al > 1e-6, va / al, 0)
    write_blp(name, np.clip(np.dstack([va, va, va, al]), 0, 1))


x, y = grid(64, 8)
finish("PanelRailT", *rail(y), 64, 8)
finish("PanelRailB", *rail(8 - y), 64, 8)
x, y = grid(8, 64)
finish("PanelRailL", *rail(x), 8, 64)
finish("PanelRailR", *rail(8 - x), 8, 64)


def corner(xx, yy, r=5.0):
    qx, qy = r - xx, r - yy
    return np.where((qx > 0) & (qy > 0), r - np.hypot(qx, qy), np.minimum(xx, yy))


x, y = grid(16, 16)
finish("PanelCornerTL", *rail(corner(x, y)), 16, 16)
finish("PanelCornerTR", *rail(corner(16 - x, y)), 16, 16)
finish("PanelCornerBL", *rail(corner(x, 16 - y)), 16, 16)
finish("PanelCornerBR", *rail(corner(16 - x, 16 - y)), 16, 16)
# the divider: a short rail standing up, fading at its ends
x, y = grid(8, 64)
v, a = rail(np.abs(x - 4.0) * -1 + RAIL * 0.5 + 0.0 + (x - x))  # placeholder, replaced below
dd = x - (4.0 - RAIL / 2)
v, a = rail(dd)
a = a * np.clip(np.minimum(y, 64 - y) / 10.0, 0, 1)
finish("PanelDivider", v, a, 8, 64)
