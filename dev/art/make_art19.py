#!/usr/bin/env python3
"""Creed UI's fierce boss skull (original): the marker over a boss, heavier and meaner than the
guardians' skull: a scowling brow ridge, short horns swept back from the temples, a crack down the
cranium, a broad jaw with two fangs, and deep angled sockets. BossSkullFierce is the bone;
BossSkullEyes is the light in the sockets alone (grey-white), laid over it in the game with ADD and
tinted ember red, so the eyes can smoulder. BLP2 + PNG, 64 px."""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
SS = 4
N = 64


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def grid():
    xs = (np.arange(N * SS) + 0.5) / (N * SS) * 2 - 1
    return np.meshgrid(xs, xs)


def down(a):
    return a.reshape(N, SS, N, SS).mean(axis=(1, 3))


def soft(m, k):
    return np.asarray(Image.fromarray(np.clip(m * 255, 0, 255).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(k * SS)), dtype=np.float64) / 255.0


def emboss(hgt, light=(-0.35, -0.75, 0.6), strength=2.2, power=18):
    gy, gx = np.gradient(hgt)
    nx, ny = -gx * strength * SS, -gy * strength * SS
    nz = np.ones_like(nx)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    L = np.array(light) / np.linalg.norm(light)
    diff = np.clip((nx * L[0] + ny * L[1] + nz * L[2]) / n, 0, 1)
    H = L + np.array([0, 0, 1.0])
    H = H / np.linalg.norm(H)
    sp = np.clip((nx * H[0] + ny * H[1] + nz * H[2]) / n, 0, 1) ** power
    return diff, sp


def ell(x, y, cx, cy, rx, ry, ang=0.0):
    ca, sa = np.cos(ang), np.sin(ang)
    u = ((x - cx) * ca + (y - cy) * sa) / rx
    v = (-(x - cx) * sa + (y - cy) * ca) / ry
    return (u * u + v * v) < 1


def over(col, a, rgb, al):
    na = al + a * (1 - al)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(na[:, :, None] > 1e-6, (rgb * al[:, :, None] + col * (a * (1 - al))[:, :, None]) / na[:, :, None], 0)
    return c, na


def finish_rgb(col, a):
    pa = np.dstack([down(col[:, :, i] * a) for i in range(3)])
    da = down(a)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(da[:, :, None] > 1e-6, pa / da[:, :, None], 0)
    return np.dstack([np.clip(c, 0, 1), np.clip(da, 0, 1)])


def horn(x, y, k):
    """a short horn from the temple (k = -1 left, 1 right), curving out and back up"""
    m = np.zeros_like(x)
    for i in range(40):
        t = i / 39.0
        cx = k * (0.52 + 0.34 * t + 0.06 * t * t)
        cy = -0.42 - 0.40 * t + 0.10 * t * t
        r = 0.11 * (1 - t) + 0.015
        m = np.maximum(m, (np.hypot(x - cx, y - cy) < r).astype(float))
    return m


def make():
    x, y = grid()
    y = y * 1.04 + 0.04  # a touch more room at the top for the horns
    # the head: a broad, heavy dome with flat-topped temples, wide cheekbones, a square jaw
    dome = ell(x, y, 0, -0.16, 0.66, 0.58)
    cheeks = ell(x, y, 0, 0.14, 0.66, 0.30)
    jaw = (np.abs(x) < 0.46 - 0.08 * np.clip((y - 0.30) / 0.42, 0, 1)) & (y > 0.05) & (y < 0.76)
    chin = ell(x, y, 0, 0.66, 0.42, 0.13)
    head = np.maximum((dome | cheeks | jaw | chin).astype(float), np.maximum(horn(x, y, -1), horn(x, y, 1)))
    head = np.clip((soft(head, 0.35) - 0.5) * 5 + 0.5, 0, 1)
    # the sockets: angled hard down toward the nose under a heavy brow, a scowl
    # the brow: low over the nose, rising to the temples (a scowl); it cuts each socket's top
    def brow(xx):
        return 0.02 - (np.abs(xx) - 0.08) * 0.55
    eyes = np.zeros_like(x)
    for k in (-1, 1):
        e = ell(x, y, k * 0.27, 0.05, 0.22, 0.16, k * np.radians(22))
        eyes = np.maximum(eyes, (e & (y > brow(x))).astype(float))
    nose = ((y > 0.18) & (y < 0.37) & (np.abs(x) < 0.085 * (y - 0.16) / 0.21 + 0.012)).astype(float)
    # teeth: a band with gaps, two longer fangs at its corners
    band = (y > 0.45) & (y < 0.67) & (np.abs(x) < 0.38)
    gaps = np.zeros_like(x)
    for k in range(-3, 4):
        gaps = np.maximum(gaps, ((np.abs(x - k * 0.105) < 0.016) & band).astype(float))
    seam = ((np.abs(y - 0.56) < 0.018) & (np.abs(x) < 0.37) & ~(np.abs(np.abs(x) - 0.26) < 0.05)).astype(float)
    # a crack running down from the crown
    crack = np.zeros_like(x)
    pts = [(0.10, -0.80), (0.05, -0.64), (0.14, -0.52), (0.06, -0.38), (0.11, -0.28)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        t = np.clip(((x - x0) * (x1 - x0) + (y - y0) * (y1 - y0)) / ((x1 - x0) ** 2 + (y1 - y0) ** 2), 0, 1)
        d = np.hypot(x - (x0 + t * (x1 - x0)), y - (y0 + t * (y1 - y0)))
        crack = np.maximum(crack, (d < 0.016).astype(float))
    holes = np.clip(soft(np.maximum(eyes, nose), 0.25) * 1.7 - 0.2, 0, 1)
    cuts = np.clip(soft(np.maximum(np.maximum(gaps, seam), crack), 0.12) * 1.8, 0, 1)
    # the bone: raised in the middle, a ridge over the brow, falling into the holes and at the rim
    body = np.clip(soft(head, 1.6) * 1.5 - 0.25, 0, 1) * head
    ridge = np.zeros_like(x)
    for k in (-1, 1):
        ridge = np.maximum(ridge, np.exp(-((y - (brow(x) - 0.06)) / 0.05) ** 2) * (np.abs(x) < 0.52) * (k * x > 0))
    hgt = (body + 0.35 * ridge * head) * (1 - 0.95 * soft(holes, 0.9)) * (1 - 0.4 * cuts)
    diff, sp = emboss(hgt)
    g = np.clip(0.30 + 0.72 * diff + 0.45 * sp, 0, 1.15)
    # old, darker bone than the guardians' skull, toward ash at the horns' tips
    bone = np.dstack([g * 0.90, g * 0.84, g * 0.72])
    deep = np.clip(holes, 0, 1)
    rgb = bone * (1 - deep[:, :, None]) + np.dstack([0.03 + 0 * x, 0.01 + 0 * x, 0.01 + 0 * x]) * deep[:, :, None]
    rgb = rgb * (1 - 0.65 * cuts[:, :, None])
    rim = np.clip(soft(head, 0.9) * 1.6, 0, 1)
    shadow = np.clip(soft(np.roll(head, int(1.2 * SS), axis=0), 1.6) * 1.1, 0, 0.8)
    col, a = np.zeros(x.shape + (3,)), np.zeros_like(x)
    col, a = over(col, a, np.zeros(3), shadow)
    col, a = over(col, a, np.array([0.05, 0.02, 0.02]), rim * 0.95)
    col, a = over(col, a, rgb, head)
    write_blp("BossSkullFierce", finish_rgb(col, a))
    # the eyes' light alone: a hot core low in each socket, a soft spill
    core = np.zeros_like(x)
    for k in (-1, 1):
        core = np.maximum(core, np.exp(-(((x - k * 0.22) / 0.09) ** 2 + ((y - 0.10) / 0.05) ** 2)))
    light = np.clip(core * 1.2 * soft(eyes, 0.5) * 1.6 + soft(core, 1.4) * 0.5, 0, 1)
    write_blp("BossSkullEyes", np.dstack([light, light, light, light]))


make()
print("BossSkullFierce BossSkullEyes")
