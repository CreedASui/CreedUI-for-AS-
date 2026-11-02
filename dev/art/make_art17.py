#!/usr/bin/env python3
"""Creed UI's boss skull (original): the marker floating over each boss, a carved bone skull in the
crests' raised style, 64 px so it stays sharp when a near boss draws it large. Bone colored, with
deep sockets that read at 20 px; the game tints its glow, not the bone. BLP2 + PNG."""
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
    assert w & (w - 1) == 0 and h & (h - 1) == 0, (name, w, h)
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def grid(w, h):
    xs = (np.arange(w * SS) + 0.5) / (w * SS) * 2 - 1
    ys = (np.arange(h * SS) + 0.5) / (h * SS) * 2 - 1
    return np.meshgrid(xs, ys)


def down(a):
    h, w = a.shape[0] // SS, a.shape[1] // SS
    return a.reshape(h, SS, w, SS).mean(axis=(1, 3))


def soft(m, k):
    return np.asarray(Image.fromarray(np.clip(m * 255, 0, 255).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(k * SS)), dtype=np.float64) / 255.0


def emboss(hgt, light=(-0.35, -0.75, 0.6), strength=2.0, power=16):
    gy, gx = np.gradient(hgt)
    nx, ny = -gx * strength * SS, -gy * strength * SS
    nz = np.ones_like(nx)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / n, ny / n, nz / n
    L = np.array(light, dtype=float)
    L = L / np.linalg.norm(L)
    diff = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    H = L + np.array([0, 0, 1.0])
    H = H / np.linalg.norm(H)
    sp = np.clip(nx * H[0] + ny * H[1] + nz * H[2], 0, 1) ** power
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


def make_boss_skull():
    x, y = grid(N, N)
    # the head: a broad dome, cheekbones, and a jaw narrowing to a square chin
    dome = ell(x, y, 0, -0.18, 0.70, 0.62)
    cheeks = ell(x, y, 0, 0.12, 0.62, 0.34)
    jaw = (np.abs(x) < 0.40 - 0.10 * np.clip((y - 0.30) / 0.42, 0, 1)) & (y > 0.05) & (y < 0.74)
    chin = ell(x, y, 0, 0.62, 0.36, 0.14)
    head = (dome | cheeks | jaw | chin).astype(float)
    head = np.clip((soft(head, 0.35) - 0.5) * 5 + 0.5, 0, 1)
    # the sockets, angled down toward the nose so it glares, the nose, and the teeth's gaps
    eyes = (ell(x, y, -0.30, -0.02, 0.22, 0.17, np.radians(18)) | ell(x, y, 0.30, -0.02, 0.22, 0.17, np.radians(-18))).astype(float)
    nose = ((y > 0.18) & (y < 0.36) & (np.abs(x) < 0.075 * (y - 0.16) / 0.20 + 0.012)).astype(float)
    mouth_band = (y > 0.44) & (y < 0.66) & (np.abs(x) < 0.34)
    gaps = np.zeros_like(x)
    for k in range(-3, 4):
        gaps = np.maximum(gaps, ((np.abs(x - k * 0.095) < 0.014) & mouth_band).astype(float))
    seam = ((np.abs(y - 0.55) < 0.016) & (np.abs(x) < 0.33)).astype(float)
    holes = np.clip(soft(np.maximum(eyes, nose), 0.25) * 1.6 - 0.2, 0, 1)
    cuts = np.clip(soft(np.maximum(gaps, seam), 0.12) * 1.8, 0, 1)
    # a raised face: high in the middle of the bone, falling into the holes and at the rim
    body = np.clip(soft(head, 1.6) * 1.5 - 0.25, 0, 1) * head
    hgt = body * (1 - 0.95 * soft(holes, 0.9)) * (1 - 0.35 * cuts)
    diff, sp = emboss(hgt)
    g = np.clip(0.40 + 0.70 * diff + 0.45 * sp, 0, 1.15)
    bone = np.dstack([g * 0.98, g * 0.93, g * 0.82])
    # the holes go deep and dark, with an ember of red at the back of each socket
    deep = np.clip(holes, 0, 1)
    ember = soft(eyes, 0.6) * np.exp(-((y + 0.02) / 0.10) ** 2)
    hole_rgb = np.dstack([0.05 + 0.55 * ember, 0.02 + 0.06 * ember, 0.02 + 0.03 * ember])
    rgb = bone * (1 - deep[:, :, None]) + hole_rgb * deep[:, :, None]
    rgb = rgb * (1 - 0.6 * cuts[:, :, None])
    # a dark outline and a soft shadow under it, so it reads over grass and snow alike
    rim = np.clip(soft(head, 0.9) * 1.6, 0, 1)
    shadow = np.clip(soft(np.roll(head, int(1.2 * SS), axis=0), 1.6) * 1.1, 0, 0.8)
    col, a = np.zeros(x.shape + (3,)), np.zeros_like(x)
    col, a = over(col, a, np.zeros(3), shadow)
    col, a = over(col, a, np.array([0.06, 0.03, 0.02]), rim * 0.95)
    col, a = over(col, a, rgb, head)
    pa = np.dstack([down(col[:, :, i] * a) for i in range(3)])
    da = down(a)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(da[:, :, None] > 1e-6, pa / da[:, :, None], 0)
    write_blp("BossSkull", np.dstack([np.clip(c, 0, 1), np.clip(da, 0, 1)]))


make_boss_skull()
print("BossSkull")
