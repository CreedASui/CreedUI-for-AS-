#!/usr/bin/env python3
"""Creed UI's luck art (original): a cast medallion with a milled edge and a clover sunk in its
dark face, a round cabochon gem with its own glint, the bezel that holds it, and a four-leaf
clover. Grey, tinted in the addon (the medal and bezel bronze, the gems by rarity, the clover green).
  LuckMedal 128x128, LuckOrb 64x64, LuckGlint 64x64, LuckBezel 64x64, LuckClover 64x64"""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
SS = 4
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


def grid(n):
    ys, xs = np.mgrid[0:n * SS, 0:n * SS]
    return (xs + 0.5) / SS, (ys + 0.5) / SS


def light(hgt):
    """diffuse and specular of a height field (in pixels)"""
    gy, gx = np.gradient(hgt * SS)
    nrm = np.dstack([-gx, -gy, np.ones_like(hgt)])
    nrm = nrm / np.linalg.norm(nrm, axis=2, keepdims=True)
    return np.clip(nrm @ LIGHT, 0, 1), np.clip(nrm @ HALF, 0, 1)


def blur(mask, px):
    im = Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(px * SS)), dtype=np.float64) / 255.0


def finish(name, v, a, n):
    al = a.reshape(n, SS, n, SS).mean(axis=(1, 3))
    va = (v * a).reshape(n, SS, n, SS).mean(axis=(1, 3))
    with np.errstate(invalid="ignore", divide="ignore"):
        va = np.where(al > 1e-6, va / al, 0)
    write_blp(name, np.clip(np.dstack([va, va, va, al]), 0, 1))


def dome(r, r0, r1):
    """a rounded band between radii r0 and r1, 0 outside"""
    t = (r - r0) / (r1 - r0)
    return np.where((t > 0) & (t < 1), np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1)), 0.0)


def clover_mask(x, y, cx, cy, L, stem=True, tilt=0.0):
    """four heart leaves round (cx, cy), each L long, as an X; a short stem down to the right"""
    m = np.zeros_like(x)
    for k in range(4):
        ang = np.radians(45 + 90 * k) + tilt
        ca, sa = np.cos(ang), np.sin(ang)
        u = (x - cx) * ca + (y - cy) * sa
        v = -(x - cx) * sa + (y - cy) * ca
        d1 = np.hypot(u - 0.60 * L, v - 0.29 * L) < 0.30 * L
        d2 = np.hypot(u - 0.60 * L, v + 0.29 * L) < 0.30 * L
        tri = (u > 0) & (np.abs(v) < u * 0.95) & (u < 0.66 * L)
        m = np.maximum(m, (d1 | d2 | tri).astype(np.float64))
    if stem:
        # a gentle curve from the middle down and to the right
        t = np.clip((y - cy) / (1.05 * L), 0, 1)
        sx = cx + 0.28 * L * t * t
        on = (y > cy) & (y < cy + 1.05 * L) & (np.abs(x - sx) < 0.07 * L + 0.02 * L * (1 - t))
        m = np.maximum(m, on.astype(np.float64))
    return m


# ---------------------------------------------------------------- the medallion
N = 128
x, y = grid(N)
cx = cy = N / 2
r = np.hypot(x - cx, y - cy)
th = np.arctan2(y - cy, x - cx)
R_OUT, R_MILL, R_RIM, R_FACE = 62.0, 55.5, 44.5, 42.0
milled = dome(r, R_MILL, R_OUT) * (0.72 + 0.28 * np.cos(th * 64)) * 2.2
rim = dome(r, R_RIM, R_MILL + 0.8) * 4.0
groove = (r >= R_FACE) & (r < R_RIM)
face = r < R_FACE
# the face: sunk, with a clover in low relief, lit faintly
leaf = blur(clover_mask(x, y, cx - 1, cy - 2, 25.0), 1.2) * 1.1
hgt = np.where(face, leaf, 0) + milled + rim
diff, half = light(hgt)
spec = half ** 16
metal = 0.22 + 0.52 * diff + 0.9 * spec
inner = 0.085 + 0.07 * (1 - r / R_FACE) + 0.16 * leaf * diff  # dark, the clover just catching the light
v = np.where(face, inner, np.where(groove, 0.05, metal))
a = (r <= R_OUT).astype(np.float64)
finish("LuckMedal", np.clip(v, 0, 1), a, N)

# ---------------------------------------------------------------- the cabochon and its glint
N = 64
x, y = grid(N)
cx = cy = N / 2
r = np.hypot(x - cx, y - cy)
R = 24.0
inside = r <= R
hgt = np.sqrt(np.clip(R * R - r * r, 0, None)) * 0.55
diff, half = light(hgt)
glow = np.exp(-(((x - cx - 6) ** 2 + (y - cy - 7) ** 2) / (2 * 8.5 ** 2)))  # light through the stone, low right
v = 0.30 + 0.42 * diff + 0.32 * glow + 0.25 * half ** 6
v = v * (0.72 + 0.28 * (1 - (r / R) ** 6))  # a darker girdle
finish("LuckOrb", np.clip(v, 0, 1), inside.astype(np.float64), N)

# the glint: a soft streak up left, a spark low right; white, laid over the gem untinted
u = (x - (cx - 7)) * np.cos(np.radians(-35)) + (y - (cy - 8)) * np.sin(np.radians(-35))
w = -(x - (cx - 7)) * np.sin(np.radians(-35)) + (y - (cy - 8)) * np.cos(np.radians(-35))
streak = np.exp(-((u / 6.5) ** 2 + (w / 2.6) ** 2) * 2.2)
spark = np.exp(-(((x - cx - 9) ** 2 + (y - cy - 10) ** 2) / (2 * 1.6 ** 2))) * 0.7
ga = np.clip(streak * 0.95 + spark, 0, 1) * inside
finish("LuckGlint", np.ones_like(ga), ga, N)

# ---------------------------------------------------------------- the bezel: a beaded ring
ring = dome(r, 23.0, 30.5) * 2.6
beads = np.zeros_like(r)
for k in range(8):
    ang = np.radians(22.5 + 45 * k)
    bx, by = cx + 26.8 * np.cos(ang), cy + 26.8 * np.sin(ang)
    d = np.hypot(x - bx, y - by)
    beads = np.maximum(beads, np.sqrt(np.clip(2.6 ** 2 - d * d, 0, None)) * 1.1)
hgt = np.maximum(ring, beads + ring * 0.6)
diff, half = light(hgt)
v = 0.22 + 0.52 * diff + 0.9 * half ** 16
lip = (r >= 22.0) & (r < 23.4)
v = np.where(lip, 0.05, v)
a = (((r >= 22.0) & (r <= 30.5)) | (beads > 0)).astype(np.float64)
finish("LuckBezel", np.clip(v, 0, 1), a, N)

# ---------------------------------------------------------------- the clover
m = clover_mask(x, y, cx - 1, cy - 3, 27.0)
# the leaves apart: a parting along each axis between them, so it reads as four even when small
rr = np.hypot(x - cx + 1, y - cy + 3)
ang = np.degrees(np.arctan2(y - cy + 3, x - cx + 1)) % 90
part = ((ang < 6) | (ang > 84)) & (rr > 3.5) & ~((y > cy - 3) & (np.abs(ang - 90) < 30) & (x > cx - 2) & (x < cx + 9) & (rr > 6))
m = np.where(part & (rr < 24), 0.0, m)
hgt = blur(m, 2.0) * 3.0
diff, half = light(hgt)
v = 0.34 + 0.56 * diff + 0.35 * half ** 12
edge = (m > 0) & (blur(m, 0.6) < 0.62)  # a dark line round it, for small sizes
v = np.where(edge, 0.12, v)
finish("LuckClover", np.clip(v, 0, 1), m, N)
print("ok")
