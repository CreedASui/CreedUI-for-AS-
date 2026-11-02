#!/usr/bin/env python3
"""Creed UI's stat glyphs: a skull (kills), a coin (gold) and a chest (the next cache), 32x32,
white/grey with a dark outline so the addon can tint them. BLP2 (uncompressed BGRA) + PNG."""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
N, SS = 32, 8
PX = 2.0 / N  # one final pixel in -1..1 units


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


xs = (np.arange(N * SS) + 0.5) / (N * SS) * 2 - 1
X, Y = np.meshgrid(xs, xs)  # y grows downward


def down(a):
    return a.reshape(N, SS, N, SS).mean(axis=(1, 3))


def cover(sdf):
    return np.clip(0.5 - sdf / (PX / 1.0), 0, 1)


def circle(cx, cy, r):
    return np.hypot(X - cx, Y - cy) - r


def ellipse(cx, cy, rx, ry):
    return (np.hypot((X - cx) / rx, (Y - cy) / ry) - 1) * min(rx, ry)


def rrect(cx, cy, hx, hy, r):
    qx = np.abs(X - cx) - hx + r
    qy = np.abs(Y - cy) - hy + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def finish(name, shape, shade, outline=0.11):
    """shape: sdf (negative inside); shade: grey level 0..1 inside. Adds a dark outline."""
    fill = cover(shape)
    ring = cover(shape - outline)
    a_out = ring * 0.9
    a = fill + a_out * (1 - fill)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a > 1e-6, shade * fill / a, 0)
    col = down(c * a)
    al = down(a)
    with np.errstate(invalid="ignore", divide="ignore"):
        col = np.where(al > 1e-6, col / al, 0)
    img = np.dstack([col, col, col, al])
    write_blp(name, np.clip(img, 0, 1))


def make_skull():
    cranium = circle(0, -0.2, 0.64)
    jaw = rrect(0, 0.42, 0.36, 0.26, 0.12)
    head = np.minimum(cranium, jaw)
    eyes = np.minimum(ellipse(-0.27, -0.08, 0.18, 0.21), ellipse(0.27, -0.08, 0.18, 0.21))
    nose = ellipse(0, 0.23, 0.07, 0.11)
    gaps = np.minimum(rrect(-0.12, 0.6, 0.035, 0.12, 0.02), rrect(0.12, 0.6, 0.035, 0.12, 0.02))
    shape = np.maximum(head, -np.minimum(np.minimum(eyes, nose), gaps))
    shade = np.clip(0.80 - 0.22 * Y, 0.6, 1.0)
    finish("Skull", shape, shade)


def make_coin():
    r = np.hypot(X, Y)
    shape = circle(0, 0, 0.8)
    light = np.clip(0.86 - 0.16 * (X + Y) / 1.2, 0.6, 1.0)
    shade = np.where(r > 0.6, light, light * 0.84)
    groove = np.abs(r - 0.6) < 0.035
    shade = np.where(groove, light * 0.55, shade)
    diamond = (np.abs(X) + np.abs(Y)) < 0.27
    shade = np.where(diamond, np.clip(light * 1.12, 0, 1), shade)
    finish("Coin", shape, shade)


def make_chest():
    body = rrect(0, 0.33, 0.84, 0.38, 0.08)
    lid = np.maximum(ellipse(0, -0.05, 0.84, 0.62), Y + 0.05)
    shape = np.minimum(body, lid)
    shade = np.where(Y < -0.05, 0.95 - 0.12 * (Y + 0.6), 0.80 - 0.1 * Y)
    bands = (np.abs(np.abs(X) - 0.5) < 0.085)
    shade = np.where(bands, shade * 0.55, shade)
    seam = np.abs(Y + 0.05) < 0.04
    shade = np.where(seam, 0.3, shade)
    lock = rrect(0, 0.08, 0.12, 0.14, 0.035) < 0
    shade = np.where(lock, 1.0, shade)
    keyhole = ellipse(0, 0.08, 0.035, 0.06) < 0
    shade = np.where(keyhole, 0.25, shade)
    finish("Chest", shape, np.clip(shade, 0, 1))


def make_card():
    card = rrect(0, 0, 0.56, 0.8, 0.12)
    shade = np.clip(0.9 - 0.12 * Y, 0.6, 1.0)
    inner = np.abs(rrect(0, 0, 0.4, 0.64, 0.06)) < 0.045
    shade = np.where(inner, shade * 0.55, shade)
    star = (np.abs(X) + np.abs(Y) * 0.8) < 0.24
    shade = np.where(star, 1.0, shade)
    finish("Card", card, shade)


def make_crown():
    band = rrect(0, 0.42, 0.72, 0.17, 0.05)
    body = rrect(0, 0.2, 0.7, 0.24, 0.04)
    tips = np.minimum(np.minimum(circle(-0.62, -0.42, 0.13), circle(0.62, -0.42, 0.13)), circle(0, -0.62, 0.14))
    spikes = np.full_like(X, 9.0)
    for cx, top in ((-0.62, -0.38), (0.0, -0.58), (0.62, -0.38)):
        # a triangle from the band up to its tip
        t = np.clip((0.42 - Y) / (0.42 - top), 0, 1)
        half = 0.3 * (1 - t) + 0.02
        spikes = np.minimum(spikes, np.maximum(np.abs(X - cx) - half, np.maximum(Y - 0.42, top - Y)))
    shape = np.minimum(np.minimum(band, body), np.minimum(spikes, tips))
    shade = np.clip(0.95 - 0.15 * Y, 0.6, 1.0)
    jewels = np.minimum(np.minimum(circle(-0.4, 0.42, 0.07), circle(0, 0.42, 0.08)), circle(0.4, 0.42, 0.07)) < 0
    shade = np.where(jewels, 0.35, shade)
    finish("Crown", shape, shade)


make_skull()
make_coin()
make_chest()
make_card()
make_crown()
print("ok")
