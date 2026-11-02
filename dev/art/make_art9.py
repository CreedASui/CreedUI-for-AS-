#!/usr/bin/env python3
"""Creed UI's panel crest (an original design): a gem setting on the panel's end with a cast-metal
wing: an arched arm rising up and out, long feathers fanning down from it, coverts over their
roots. 128x128, grey so the addon tints it with the map's metal; flipped for the right end."""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
N, SS = 128, 4


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


ys, xs = np.mgrid[0:N * SS, 0:N * SS]
X, Y = (xs + 0.5) / SS, (ys + 0.5) / SS  # final pixels, y down
L = np.array([-0.3, -0.7, 0.65])
L = L / np.linalg.norm(L)


def shade(sd, bevel, groove=None):
    h = np.sin(np.clip(-sd / bevel, 0, 1) * np.pi / 2)
    if groove is not None:
        h = h - groove
    gy, gx = np.gradient(h * bevel * SS * 0.85)
    n = np.sqrt(gx * gx + gy * gy + 1)
    d = np.clip((-gx * L[0] - gy * L[1] + L[2]) / n, 0, 1)
    return np.clip(0.34 + 0.58 * d + 0.25 * d ** 14, 0, 1)


def piece(sd, bevel, groove=None, outline=1.25):
    v = shade(sd, bevel, groove)
    ring = (sd >= 0) & (sd < outline)
    return np.where(ring, 0.05, v), np.where(sd < 0, 1.0, np.where(ring, 0.95, 0.0))


def over(dst, src):
    dv, da = dst
    sv, sa = src
    a = sa + da * (1 - sa)
    with np.errstate(invalid="ignore", divide="ignore"):
        v = np.where(a > 1e-6, (sv * sa + dv * da * (1 - sa)) / a, 0)
    return v, a


def capsule(x1, y1, x2, y2, r1, r2):
    dx, dy = x2 - x1, y2 - y1
    t = np.clip(((X - x1) * dx + (Y - y1) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(X - (x1 + t * dx), Y - (y1 + t * dy)) - (r1 + (r2 - r1) * t), t


def feather(x1, y1, ang, length, r1, r2):
    x2, y2 = x1 + np.cos(ang) * length, y1 + np.sin(ang) * length
    sd, t = capsule(x1, y1, x2, y2, r1, r2)
    # its quill: a fine groove down the middle, fading toward the tip
    ca, sa = np.cos(ang), np.sin(ang)
    across = -(X - x1) * sa + (Y - y1) * ca
    groove = 0.25 * np.exp(-(across / 0.8) ** 2) * np.clip((1 - t) * 1.4, 0, 1) * (t > 0.04)
    return sd, groove


def arc(t):
    """the arm, from the setting (t=0) up and out to the wing's tip (t=1)"""
    x = 93 - 52 * t
    y = 57 - 40 * np.sin(np.pi * 0.55 * t) + 8 * t * t
    return x, y


img = (np.zeros_like(X), np.zeros_like(X))
# long feathers hanging from the arm, the outer ones behind, longer toward the tip
roots = np.linspace(0.12, 1.0, 11)
for i in range(len(roots) - 1, -1, -1):
    t = roots[i]
    x1, y1 = arc(t)
    ang = np.radians(96 + 54 * t)  # y down: 90 points down, 180 points out
    length = 18 + 20 * t
    sd, g = feather(x1, y1, ang, length, 6.2 - 1.4 * t, 2.3)
    img = over(img, piece(sd, 3.0, g))
# coverts: a row of short feathers over the long ones' roots
for t in np.linspace(0.08, 0.88, 7)[::-1]:
    x1, y1 = arc(t)
    ang = np.radians(100 + 50 * t)
    sd, g = feather(x1, y1, ang, 11 + 7 * t, 5.2 - t, 2.5)
    img = over(img, piece(sd, 2.6, g))
# the arm itself: a run of beads along the arc, smooth
arm = np.full_like(X, 99.0)
ts = np.linspace(0, 1, 60)
for i in range(len(ts) - 1):
    xa, ya = arc(ts[i])
    xb, yb = arc(ts[i + 1])
    r = 5.2 - 2.8 * ts[i]
    sd, _ = capsule(xa, ya, xb, yb, r, 5.2 - 2.8 * ts[i + 1])
    arm = np.minimum(arm, sd)
img = over(img, piece(arm, 2.8))
# the mount into the panel's edge, and the setting
mount, _ = capsule(96, 64, 127.5, 64, 4.6, 4.6)
img = over(img, piece(mount, 2.4))
cx, cy = 96.0, 64.0
setting = (np.sqrt(((X - cx) / 12.0) ** 2 + ((Y - cy) / 17.0) ** 2) - 1) * 12.0
img = over(img, piece(setting, 3.0))
v, a = img
sock = (np.sqrt(((X - cx) / 7.2) ** 2 + ((Y - cy) / 10.5) ** 2) - 1) * 7.2
v = np.where(sock < 0, 0.06 + 0.08 * np.clip(-sock / 7.2, 0, 1), v)
v = np.where((sock >= 0) & (sock < 1.0), 0.9, v)

al = a.reshape(N, SS, N, SS).mean(axis=(1, 3))
va = (v * a).reshape(N, SS, N, SS).mean(axis=(1, 3))
with np.errstate(invalid="ignore", divide="ignore"):
    va = np.where(al > 1e-6, va / al, 0)
write_blp("PanelCrest", np.clip(np.dstack([va, va, va, al]), 0, 1))
