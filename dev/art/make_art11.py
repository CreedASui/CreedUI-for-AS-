#!/usr/bin/env python3
"""Creed UI's panel frame, lit as the timer's rim: a polished tube lit from above (a bright streak
along its top, darker below), a dark outline, a fine inner line, a soft shadow onto the glass.
Grey, tinted with the map's metal. BLP2 + PNG.
  PanelEdgeT 64x16, PanelEdgeB 64x16, PanelEdgeV 16x64 (left; flipped for the right),
  PanelCornerT 32x32 (top left), PanelCornerB 32x32 (bottom left; both flipped for the right),
  PanelDivider 8x64"""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
SS = 8
TUBE = 9.0
LIGHT = np.array([-0.18, -0.78, 0.6])
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


def lit(height):
    """light a height field (pixels) from above, with a tight bright streak"""
    gy, gx = np.gradient(height * SS)
    n = np.dstack([-gx, -gy, np.ones_like(height)])
    n = n / np.linalg.norm(n, axis=2, keepdims=True)
    diff = np.clip(n @ LIGHT, 0, 1)
    spec = np.clip(n @ HALF, 0, 1) ** 28
    return np.clip(0.2 + 0.58 * diff + 0.7 * spec, 0, 1)


def frame_piece(d, shadow=True):
    """value, alpha from a depth field d (pixels inward from the outer edge)"""
    t = (d - 1.1) / (TUBE - 2.2)
    inside = (t > 0) & (t < 1)
    h = np.where(inside, np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1)) * (TUBE - 2.2) * 0.5, 0)
    v = lit(h)
    a = np.zeros_like(d)
    a = np.where(inside, 1.0, a)
    outline = ((d >= 0) & (d <= 1.1)) | ((d >= TUBE - 1.1) & (d < TUBE))
    v = np.where(outline, 0.05, v)
    a = np.where(outline, 0.95, a)
    gap = (d >= TUBE) & (d < TUBE + 1.0)
    v, a = np.where(gap, 0.05, v), np.where(gap, 0.55, a)
    fine = (d >= TUBE + 1.0) & (d < TUBE + 2.0)
    v, a = np.where(fine, 0.85, v), np.where(fine, 0.7, a)
    if shadow:
        soft = (d >= TUBE + 2.0) & (d < 16)
        v = np.where(soft, 0.0, v)
        fade = np.clip(1 - (d - TUBE - 2.0) / (16 - TUBE - 2.0), 0, 1)
        a = np.where(soft, 0.4 * fade ** 1.6, a)
    a = np.where(d < 0, 0, a)
    return v, a


def finish(name, v, a, w, h):
    al = a.reshape(h, SS, w, SS).mean(axis=(1, 3))
    va = (v * a).reshape(h, SS, w, SS).mean(axis=(1, 3))
    with np.errstate(invalid="ignore", divide="ignore"):
        va = np.where(al > 1e-6, va / al, 0)
    write_blp(name, np.clip(np.dstack([va, va, va, al]), 0, 1))


def corner_depth(x, y, r=7.0):
    qx, qy = r - x, r - y
    return np.where((qx > 0) & (qy > 0), r - np.hypot(qx, qy), np.minimum(x, y))


def plate(v, a, x, y, cx, cy):
    """a riveted diamond plate, domed so it reads lit from above whichever corner it's on"""
    man = np.abs(x - cx) + np.abs(y - cy)
    R = 7.5
    edge = (man >= R) & (man < R + 1.1)
    v = np.where(edge, 0.05, v)
    a = np.where(edge, np.maximum(a, 0.95), a)
    dome = np.where(man < R, np.sqrt(np.clip(1 - (man / R) ** 2, 0, 1)) * 3.0, 0)
    pv = lit(dome)
    v = np.where(man < R, pv, v)
    a = np.where(man < R, 1.0, a)
    dist = np.hypot(x - cx, y - cy)
    ring = (dist >= 2.3) & (dist < 3.1)
    v = np.where(ring, 0.1, v)
    rivet = np.where(dist < 2.3, np.sqrt(np.clip(1 - (dist / 2.3) ** 2, 0, 1)) * 2.0, 0)
    v = np.where(dist < 2.3, lit(rivet), v)
    return v, a


x, y = grid(64, 16)
finish("PanelEdgeT", *frame_piece(y), 64, 16)
finish("PanelEdgeB", *frame_piece(16 - y, shadow=False), 64, 16)
x, y = grid(16, 64)
finish("PanelEdgeV", *frame_piece(x), 16, 64)
x, y = grid(32, 32)
v, a = frame_piece(corner_depth(x, y))
finish("PanelCornerT", *plate(v, a, x, y, 6.5, 6.5), 32, 32)
yb = 32 - y
d = corner_depth(x, yb)
v, a = frame_piece(d, shadow=False)
finish("PanelCornerB", *plate(v, a, x, y, 6.5, 32 - 6.5), 32, 32)
# a thin bar between groups, lit as the rest
x, y = grid(8, 64)
dd = np.abs(x - 4.0)
h = np.where(dd < 1.7, np.sqrt(np.clip(1 - (dd / 1.7) ** 2, 0, 1)) * 1.7, 0)
v = np.where(dd < 1.7, lit(h), 0.05)
a = np.where(dd < 1.7, 1.0, np.where(dd < 2.6, 0.85, 0.0)) * np.clip(np.minimum(y, 64 - y) / 10.0, 0, 1)
finish("PanelDivider", v, a, 8, 64)
