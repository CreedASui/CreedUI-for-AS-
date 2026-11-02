#!/usr/bin/env python3
"""Creed UI's panel dragon (an original design): a little dragon rearing on the panel's end,
facing out, a bat wing raised over the panel's corner, its tail curled round the base. Cast
metal, grey so the addon tints it gold. 128x128; flipped for the right end."""
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
X, Y = (xs + 0.5) / SS, (ys + 0.5) / SS
L = np.array([-0.35, -0.7, 0.62])
L = L / np.linalg.norm(L)


def shade(sd, bevel, groove=None):
    h = np.sin(np.clip(-sd / bevel, 0, 1) * np.pi / 2)
    if groove is not None:
        h = h - groove
    gy, gx = np.gradient(h * bevel * SS * 0.85)
    n = np.sqrt(gx * gx + gy * gy + 1)
    d = np.clip((-gx * L[0] - gy * L[1] + L[2]) / n, 0, 1)
    hx, hy, hz = L[0], L[1], L[2] + 1.0  # polished: a bright streak where the light glances
    hn = np.sqrt(hx * hx + hy * hy + hz * hz)
    spec = np.clip((-gx * hx - gy * hy + hz) / (n * hn), 0, 1) ** 26
    return np.clip(0.1 + 0.46 * d + 0.95 * spec, 0, 1)  # bronze, with bright glints as the timer's rail


def scales(size=3.0, depth=0.22):
    """rows of overlapping scales: little arcs, each row offset by half a scale"""
    row = np.floor(Y / size)
    xo = X / size + 0.5 * (row % 2)
    fx = xo - np.floor(xo) - 0.5
    fy = Y / size - row
    # the scale's lower rim: an arc
    arc = np.abs(fy - (0.15 + 0.85 * (1 - (2 * fx) ** 2)))
    return depth * np.exp(-(arc / 0.16) ** 2)


HIDE = scales()


def piece(sd, bevel, groove=None, outline=1.2, dim=1.0):
    v = shade(sd, bevel, groove) * dim
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
    t = np.clip(((X - x1) * dx + (Y - y1) * dy) / (dx * dx + dy * dy + 1e-9), 0, 1)
    return np.hypot(X - (x1 + t * dx), Y - (y1 + t * dy)) - (r1 + (r2 - r1) * t)


def bezier(p0, p1, p2, n=24):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2 = map(np.array, (p0, p1, p2))
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2


def chain(pts, r0, r1):
    sd = np.full_like(X, 99.0)
    k = len(pts) - 1
    for i in range(k):
        ra = r0 + (r1 - r0) * i / k
        rb = r0 + (r1 - r0) * (i + 1) / k
        sd = np.minimum(sd, capsule(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], ra, rb))
    return sd


def ellipse(cx, cy, rx, ry, ang=0.0):
    ca, sa = np.cos(ang), np.sin(ang)
    u = (X - cx) * ca + (Y - cy) * sa
    v = -(X - cx) * sa + (Y - cy) * ca
    return (np.sqrt((u / rx) ** 2 + (v / ry) ** 2) - 1) * min(rx, ry)


def polygon(pts):
    """signed distance to a polygon (negative inside)"""
    pts = np.array(pts, dtype=float)
    d = np.full_like(X, 1e9)
    inside = np.zeros_like(X, dtype=bool)
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        t = np.clip(((X - x1) * dx + (Y - y1) * dy) / (dx * dx + dy * dy), 0, 1)
        d = np.minimum(d, np.hypot(X - (x1 + t * dx), Y - (y1 + t * dy)))
        cond = ((y1 > Y) != (y2 > Y)) & (X < (x2 - x1) * (Y - y1) / (y2 - y1 + 1e-12) + x1)
        inside ^= cond
    return np.where(inside, -d, d)


img = (np.zeros_like(X), np.zeros_like(X))

# the wing, raised behind it and over the panel's corner: a membrane between finger bones,
# scalloped between their tips
shoulder, wrist = (70.0, 56.0), (86.0, 20.0)
tips = [(108.0, 6.0), (120.0, 26.0), (114.0, 46.0), (96.0, 58.0)]
membrane = polygon([shoulder, wrist, tips[0], tips[1], tips[2], tips[3]])
for a, b in zip(tips[:-1], tips[1:]):
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    # a bite out of the edge between two tips, toward the wrist
    vx, vy = wrist[0] - mx, wrist[1] - my
    k = 7.0 / np.hypot(vx, vy)
    membrane = np.maximum(membrane, -(np.hypot(X - (mx - vx * k * 0.6), Y - (my - vy * k * 0.6)) - 8.5))
ribs = np.zeros_like(X)
for t in tips:
    # faint ridges across the membrane toward each tip
    dx, dy = t[0] - wrist[0], t[1] - wrist[1]
    across = (-(X - wrist[0]) * dy + (Y - wrist[1]) * dx) / np.hypot(dx, dy)
    ribs = np.maximum(ribs, 0.18 * np.exp(-(across / 1.1) ** 2))
img = over(img, piece(membrane, 2.0, -ribs * 1.4, dim=0.72))
bones = capsule(shoulder[0], shoulder[1], wrist[0], wrist[1], 4.0, 2.8)
for t in tips:
    bones = np.minimum(bones, capsule(wrist[0], wrist[1], t[0], t[1], 2.2, 0.7))
img = over(img, piece(bones, 1.6))
img = over(img, piece(ellipse(wrist[0], wrist[1], 3.4, 3.4), 1.4))  # the wrist's knuckle

# the tail, curling round behind the feet, a spade at its tip
tail = chain(bezier((84, 104), (108, 122), (120, 102), 28), 6.0, 1.6)
spade = polygon([(120, 100), (126, 92), (116, 94)])
img = over(img, piece(np.minimum(tail, spade), 2.2, HIDE))

# the hind leg: a strong haunch, the foot forward, three claws
foot = np.minimum(capsule(76, 101, 71, 112, 5.4, 4.0), capsule(71, 112, 57, 115, 4.0, 2.8))
for cx, cy in ((50, 112), (51, 118), (56, 121)):
    foot = np.minimum(foot, capsule(57, 115, cx, cy, 2.0, 0.3))
img = over(img, piece(foot, 2.0))
img = over(img, piece(ellipse(79, 94, 14, 11.5, -0.45), 3.0, HIDE))

# the body, rising to the chest, its belly in plates and spines along its back
body = np.minimum(chain(bezier((83, 94), (84, 76), (68, 62), 14), 11.5, 10.0), ellipse(66, 67, 10.5, 12.5, 0.3))
belly = (X < 70) & (X > 54) & (Y > 56)
plates = np.zeros_like(X)
for i in range(8):
    cy = 58 + i * 5
    plates = np.maximum(plates, 0.26 * np.exp(-((Y - cy) / 0.75) ** 2))
img = over(img, piece(body, 3.2, np.where(belly, plates, HIDE)))
spines = np.full_like(X, 99.0)
for (sx, sy), ang in zip(bezier((92, 92), (93, 68), (76, 50), 9)[1:-1], np.linspace(-0.2, -1.3, 7)):
    ex, ey = sx + np.cos(ang) * 7.5, sy + np.sin(ang) * 7.5
    spines = np.minimum(spines, capsule(sx - 1.5, sy, ex, ey, 2.4, 0.3))
for (sx, sy) in bezier((96, 110), (110, 118), (118, 104), 6)[1:-1]:
    spines = np.minimum(spines, capsule(sx, sy, sx + 2, sy - 5, 1.6, 0.3))
img = over(img, piece(spines, 1.2))

# the neck, curving up and out to the head
neck = np.minimum(chain(bezier((66, 62), (50, 58), (50, 44), 12), 9.2, 7.2),
                  chain(bezier((50, 44), (50, 31), (41, 26), 10), 7.2, 5.8))
front = chain(bezier((60, 66), (44, 60), (45, 44), 12), 3.6, 3.0)
front = np.minimum(front, chain(bezier((45, 44), (45, 33), (38, 29), 10), 3.0, 2.4))
neckplates = np.zeros_like(X)
for i in range(9):
    cy = 30 + i * 4.2
    neckplates = np.maximum(neckplates, 0.24 * np.exp(-((Y - cy) / 0.7) ** 2))
img = over(img, piece(neck, 2.6, np.where(front < 0, neckplates, HIDE)))

# horns swept back, the head with its snout and open jaw
horns = np.minimum(capsule(42, 16, 58, 4, 2.6, 0.5), capsule(44, 20, 60, 14, 2.2, 0.5))
rings = 0.28 * np.exp(-((((X - 42) * 0.8 + (Y - 16) * -0.6) % 2.2) - 1.1) ** 2 / 0.08)
img = over(img, piece(horns, 1.2, rings))
jaw = capsule(36, 30, 20, 35, 3.4, 2.0)
img = over(img, piece(jaw, 1.6))
mouth_in = polygon([(35, 26.5), (19, 27.5), (21, 32.5), (35, 30)])
img = (np.where(mouth_in < 0, 0.06, img[0]), np.where(mouth_in < 0, 1.0, img[1]))
teeth = np.full_like(X, 99.0)
for tx in (23, 26.5, 30, 33):
    teeth = np.minimum(teeth, polygon([(tx - 1.1, 27.2), (tx + 1.1, 27.2), (tx, 30.0)]))
    teeth = np.minimum(teeth, polygon([(tx + 0.6, 32.6), (tx + 2.6, 32.2), (tx + 1.6, 29.8)]))
img = (np.where(teeth < 0, 0.95, img[0]), np.where(teeth < 0, 1.0, img[1]))
head = np.minimum(ellipse(38, 21, 10.5, 7.6, -0.15), capsule(36, 21.5, 18, 25, 6.2, 3.4))
img = over(img, piece(head, 2.4, np.where(X > 34, HIDE * 0.7, 0)))
img = over(img, piece(capsule(42, 15.5, 30, 16.5, 2.3, 1.3), 1.0))
# a frill of short spikes behind the jaw
frill = np.minimum(capsule(44, 26, 52, 30, 2.0, 0.4), capsule(45, 23, 54, 24, 1.8, 0.4))
img = over(img, piece(frill, 1.0))
v, a = img
# the mouth's line, the eye and its glint, a nostril
mouth = capsule(34, 27.5, 20, 29.2, 0.9, 0.7)
v = np.where(mouth < 0, 0.06, v)
eye = ellipse(34, 19.5, 2.8, 2.0, -0.2)
v = np.where(eye < 0, 0.04, v)
v = np.where(ellipse(34.2, 19.6, 1.7, 1.1, -0.2) < 0, 1.0, v)
v = np.where(np.hypot(X - 34.5, Y - 19.6) < 0.45, 0.05, v)  # the pupil, a slit
v = np.where(np.hypot(X - 21.5, Y - 23.5) < 0.9, 0.12, v)
img = (v, a)

# the front leg, reaching forward, claws up
arm = np.minimum(capsule(64, 68, 60, 81, 5.0, 4.0), capsule(60, 81, 47, 79, 4.0, 3.2))
for cx, cy in ((40, 75), (39, 80), (41, 85)):
    arm = np.minimum(arm, capsule(47, 79, cx, cy, 1.9, 0.3))
img = over(img, piece(arm, 2.0, HIDE * 0.8))

v, a = img
al = a.reshape(N, SS, N, SS).mean(axis=(1, 3))
va = (v * a).reshape(N, SS, N, SS).mean(axis=(1, 3))
with np.errstate(invalid="ignore", divide="ignore"):
    va = np.where(al > 1e-6, va / al, 0)
write_blp("PanelDragon", np.clip(np.dstack([va, va, va, al]), 0, 1))
