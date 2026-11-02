#!/usr/bin/env python3
"""Creed UI's panel crest (an original design): a gem setting on the panel's end, with a wing of
cast-metal feathers sweeping up and out and a smaller one sweeping down, a scroll under them.
128x128, grey so the addon tints it with the map's metal; flipped for the right end."""
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
LIGHT = np.array([-0.25, -0.7, 0.67])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def emboss(sd, bevel, ridge=None):
    h = np.sin(np.clip(-sd / bevel, 0, 1) * np.pi / 2)
    if ridge is not None:
        h = h - ridge
    gy, gx = np.gradient(h * bevel * SS * 0.8)
    n = np.sqrt(gx * gx + gy * gy + 1)
    diff = (-gx * LIGHT[0] - gy * LIGHT[1] + LIGHT[2]) / n
    v = 0.16 + 0.7 * np.clip(diff, 0, 1) + 0.3 * np.clip(diff, 0, 1) ** 16
    return np.clip(v, 0, 1)


def layer(sd, bevel, ridge=None, outline=1.3):
    """value and alpha of one cast piece with a dark outline"""
    v = emboss(sd, bevel, ridge)
    inside = sd < 0
    ring = (sd >= 0) & (sd < outline)
    val = np.where(ring, 0.05, v)
    a = np.where(inside, 1.0, np.where(ring, 0.95, 0.0))
    return val, a


def over(dst, src):
    dv, da = dst
    sv, sa = src
    a = sa + da * (1 - sa)
    with np.errstate(invalid="ignore", divide="ignore"):
        v = np.where(a > 1e-6, (sv * sa + dv * da * (1 - sa)) / a, 0)
    return v, a


def feather(bx, by, angle, length, width, bend=0.0):
    """a feather from (bx, by) toward `angle` (radians, y down): a pointed leaf, gently bent;
    returns its distance and a groove along its quill"""
    ca, sa = np.cos(angle), np.sin(angle)
    u = (X - bx) * ca + (Y - by) * sa
    v = -(X - bx) * sa + (Y - by) * ca
    t = np.clip(u / length, 0, 1)
    v = v - bend * length * t * t  # curls toward its tip
    w = width * np.where(t < 0.18, 0.55 + 0.45 * t / 0.18, (1 - (t - 0.18) / 0.82) ** 0.8)
    w = np.maximum(w, 0.01)
    inside_len = (u >= -1.5) & (u <= length)
    sd = np.where(inside_len, np.abs(v) - w, np.hypot(np.minimum(u + 1.5, 0) + np.maximum(u - length, 0), np.maximum(np.abs(v) - width * 0.4, 0)))
    groove = 0.22 * np.exp(-(v / 0.9) ** 2) * (t > 0.05) * (t < 0.9)
    return sd, groove


def capsule(x1, y1, x2, y2, r1, r2):
    dx, dy = x2 - x1, y2 - y1
    L2 = dx * dx + dy * dy
    t = np.clip(((X - x1) * dx + (Y - y1) * dy) / L2, 0, 1)
    return np.hypot(X - (x1 + t * dx), Y - (y1 + t * dy)) - (r1 + (r2 - r1) * t)


img = (np.zeros_like(X), np.zeros_like(X))
cx, cy = 96.0, 64.0  # the setting, on the panel's end (the right side of this picture)

# the lower wing, behind: three feathers sweeping down and out
for i, (ang, ln, wd) in enumerate([(2.45, 44, 6.0), (2.72, 52, 6.4), (2.98, 56, 6.6)]):
    sd, gr = feather(cx - 6, cy + 8, ang, ln * 0.78, wd * 0.85, bend=-0.10)
    img = over(img, layer(sd, 3.2, gr))

# the upper wing: five long feathers fanning from up to out, the outer ones behind
for ang, ln, wd, bend in [(3.45, 66, 7.4, 0.10), (3.75, 70, 7.6, 0.12), (4.05, 66, 7.4, 0.14),
                          (4.33, 56, 7.0, 0.16), (4.58, 44, 6.4, 0.18)]:
    sd, gr = feather(cx - 6, cy - 8, ang, ln, wd, bend=bend)
    img = over(img, layer(sd, 3.4, gr))

# a covert of short feathers over the wing's root
for ang, ln, wd in [(3.55, 30, 6.0), (3.95, 28, 5.8), (4.3, 24, 5.4)]:
    sd, gr = feather(cx - 4, cy - 4, ang, ln, wd, bend=0.08)
    img = over(img, layer(sd, 3.0, gr))

# a scroll curling under the wings
ang = np.arctan2(Y - (cy + 20), X - (cx - 30))
rr = np.hypot(X - (cx - 30), Y - (cy + 20))
spiral = np.abs(rr - (9 + 2.2 * ((ang + np.pi) % (2 * np.pi)))) - 2.2
scroll_mask = (X > cx - 52) & (X < cx - 6) & (Y > cy + 4) & (Y < cy + 44)
sd = np.where(scroll_mask, spiral, 99)
sd = np.minimum(sd, capsule(cx - 30, cy + 12, cx - 4, cy + 10, 2.4, 3.4))
img = over(img, layer(sd, 2.2))

# the mount into the panel's edge, and the setting over everything
img = over(img, layer(capsule(cx, cy, 127.5, cy, 5.0, 5.0), 2.6))
ex, ey = (X - cx) / 12.0, (Y - cy) / 18.0
setting = (np.sqrt(ex * ex + ey * ey) - 1) * 12.0
point = capsule(cx, cy - 26, cx, cy + 26, 0.6, 0.6)
img = over(img, layer(np.minimum(setting, point + 2.0), 3.0))
v, a = img
# the socket: dark, a thin light lip; the gem itself is a texture of its own over it
sock = (np.sqrt(((X - cx) / 7.0) ** 2 + ((Y - cy) / 11.0) ** 2) - 1) * 7.0
v = np.where(sock < 0, 0.07 + 0.08 * np.clip(-sock / 7.0, 0, 1), v)
v = np.where((sock >= 0) & (sock < 1.0), 0.9, v)

al = a.reshape(N, SS, N, SS).mean(axis=(1, 3))
va = (v * a).reshape(N, SS, N, SS).mean(axis=(1, 3))
with np.errstate(invalid="ignore", divide="ignore"):
    va = np.where(al > 1e-6, va / al, 0)
write_blp("PanelCrest", np.clip(np.dstack([va, va, va, al]), 0, 1))
