#!/usr/bin/env python3
"""Creed UI's crests for the minimap's edge buttons (original), in the C's raised-metal style: a
four-leaf clover for the luck window (grey, tinted green in game) and two crossed swords for the
damage meter (in their own colors: steel blades, gold guards, red grips). BLP2 + PNG."""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
SS = 4


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


def premul_down(col, alpha):
    pa, a = down(col * alpha), down(alpha)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a > 1e-6, pa / a, 0)
    c = np.clip(c, 0, 1)
    return np.dstack([c, c, c, np.clip(a, 0, 1)])


def cover(sdf, px):
    return np.clip(0.5 - sdf / px, 0, 1)


def emboss(t, light=(-0.35, -0.75, 0.6), strength=2.2, spec=0.55, power=18):
    hgt = np.sin(np.pi * np.clip(t, 0, 1)) ** 0.85
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


def rrect(x, y, half, r):
    """Signed distance to a rounded square (negative inside)."""
    qx, qy = np.abs(x) - (half - r), np.abs(y) - (half - r)
    out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    return out + np.minimum(np.maximum(qx, qy), 0) - r


def layer_over(c, a, col, al):
    na = al + a * (1 - al)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(na > 1e-6, (col * al + c * a * (1 - al)) / na, 0)
    return c, na


def metal_ring(d_out, d_in, px, strength=1.2):
    """Coverage and shade of an embossed band between two shapes."""
    outer, hole = cover(d_out, px), cover(d_in, px)
    band = np.clip(outer - hole, 0, 1)
    with np.errstate(invalid="ignore", divide="ignore"):
        t = np.clip(d_in / np.minimum(d_in - d_out, -1e-4) * -1, 0, 1)
        t = np.clip(d_in / np.maximum(d_in - d_out, 1e-4), 0, 1)
    diff, sp = emboss(t, strength=strength)
    g = 0.16 + 0.80 * diff + 0.55 * sp
    edge = np.exp(-(d_out / 0.02) ** 2) + np.exp(-(d_in / 0.018) ** 2)
    g = np.clip(g * (1 - 0.68 * np.clip(edge, 0, 1)), 0, 1.15)
    return band, g, outer, hole


from PIL import ImageFilter

N = 64


def soft(m, k):
    return np.asarray(Image.fromarray(np.clip(m * 255, 0, 255).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(k * SS)), dtype=np.float64) / 255.0


def shadow_of(shape):
    """the dark halo under a crest, a little down and right, so it reads on the dark face"""
    s = soft(np.roll(np.roll(shape, int(0.9 * SS), axis=0), int(0.5 * SS), axis=1), 1.0)
    return np.clip(s * 1.4, 0, 0.85)


def premul_rgb(col, alpha):
    pa = np.dstack([down(col[:, :, i] * alpha) for i in range(3)])
    a = down(alpha)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a[:, :, None] > 1e-6, pa / a[:, :, None], 0)
    return np.dstack([np.clip(c, 0, 1), np.clip(a, 0, 1)])


def clover_mask(x, y, cx, cy, L, tilt=0.0):
    """four heart leaves round (cx, cy), each L long, as an X, and a short stem curling down right"""
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
    t = np.clip((y - cy) / (1.05 * L), 0, 1)
    sx = cx + 0.28 * L * t * t
    on = (y > cy) & (y < cy + 1.05 * L) & (np.abs(x - sx) < 0.07 * L + 0.02 * L * (1 - t))
    return np.maximum(m, on.astype(np.float64))


def make_map_clover():
    x, y = grid(N, N)
    # leaves split by a fine dark vein each, so the four read at 16 px
    shape = clover_mask(x, y, -0.03, -0.07, 0.50)
    shape = soft(shape, 0.25)
    shape = np.clip((shape - 0.5) * 6 + 0.5, 0, 1)
    t = np.clip(soft(shape, 0.9) * 1.6 - 0.3, 0, 1) * shape
    diff, sp = emboss(t * 0.5 + 0.5 * shape, strength=1.3)
    g = np.clip(0.38 + 0.72 * diff + 0.5 * sp, 0, 1.1)
    ang = np.arctan2(y + 0.07, x + 0.03)
    vein = np.zeros_like(x)
    for k in range(4):
        a = np.radians(45 + 90 * k)
        u = (x + 0.03) * np.cos(a) + (y + 0.07) * np.sin(a)
        v = -(x + 0.03) * np.sin(a) + (y + 0.07) * np.cos(a)
        vein = np.maximum(vein, np.exp(-(v / 0.018) ** 2) * ((u > 0.05) & (u < 0.36)))
    g = g * (1 - 0.45 * vein)
    c, a = np.zeros_like(x), np.zeros_like(x)
    c, a = layer_over(c, a, np.zeros_like(x), shadow_of(shape))
    c, a = layer_over(c, a, g, shape)
    write_blp("MapClover", premul_down(c, a))


def sword(x, y, ang, half=0.68):
    """one sword along `ang` (the tip that way), its middle at the origin: masks of its blade, its
    guard and pommel, its grip, and the blade's ridge height"""
    ca, sa = np.cos(ang), np.sin(ang)
    t = x * ca + y * sa       # along, toward the tip
    v = -x * sa + y * ca      # across
    guard_t = -0.30
    # the blade: straight, then to a point over its last 0.2
    bw = 0.085 * np.clip((half - t) / 0.22, 0, 1)
    blade = (t > guard_t) & (t < half) & (np.abs(v) < bw)
    ridge = np.where(blade, 1 - np.abs(v) / np.maximum(bw, 1e-4), 0)
    guard = (np.abs(t - (guard_t - 0.035)) < 0.04) & (np.abs(v) < 0.19)
    guard = guard | ((np.hypot(t - (guard_t - 0.035), np.abs(v) - 0.19) < 0.05))
    grip = (t < guard_t - 0.07) & (t > -half + 0.09) & (np.abs(v) < 0.042)
    pommel = np.hypot(t - (-half + 0.055), v) < 0.065
    return blade.astype(float), (guard | pommel).astype(float), grip.astype(float), ridge


def make_map_swords():
    x, y = grid(N, N)
    col = np.zeros(x.shape + (3,))
    a = np.zeros_like(x)
    STEEL, GOLD, GRIP = np.array([0.90, 0.93, 0.98]), np.array([1.0, 0.80, 0.38]), np.array([0.78, 0.22, 0.14])

    def over(col, a, rgb, al):
        na = al + a * (1 - al)
        with np.errstate(invalid="ignore", divide="ignore"):
            c = np.where(na[:, :, None] > 1e-6, (rgb * al[:, :, None] + col * (a * (1 - al))[:, :, None]) / na[:, :, None], 0)
        return c, na

    # the one behind (tip up left), then the one in front (tip up right) with a shadow on the first
    shapes = []
    for ang in (np.radians(-135), np.radians(-45)):
        shapes.append(sword(x, y + 0.06, ang))
    all_shape = np.zeros_like(x)
    for blade, metal, grip, _ in shapes:
        all_shape = np.maximum(all_shape, np.maximum(np.maximum(blade, metal), grip))
    col, a = over(col, a, np.zeros(3), shadow_of(soft(all_shape, 0.2)))
    for i, (blade, metal, grip, ridge) in enumerate(shapes):
        blade_s, metal_s, grip_s = soft(blade, 0.2), soft(metal, 0.2), soft(grip, 0.2)
        if i == 1:
            # its own shadow on the sword behind
            sh = soft(np.roll(np.roll(np.maximum(np.maximum(blade, metal), grip), int(0.7 * SS), axis=0), int(0.4 * SS), axis=1), 0.6)
            col, a = over(col, a, np.zeros(3), np.clip(sh * 1.2, 0, 0.7) * (a > 0.5))
        # the blade: two facets either side of its ridge, lit from the top left
        d, s = emboss(ridge * 0.9, strength=1.6)
        bv = np.clip(0.30 + 0.75 * d + 0.7 * s, 0, 1.15)
        col, a = over(col, a, STEEL * bv[:, :, None], blade_s)
        tm = np.clip(soft(metal, 0.5) * 1.6 - 0.3, 0, 1) * metal
        d, s = emboss(tm * 0.5 + 0.5 * metal, strength=1.2)
        mv = np.clip(0.35 + 0.7 * d + 0.6 * s, 0, 1.1)
        tg = np.clip(soft(grip, 0.4) * 1.6 - 0.3, 0, 1) * grip
        d, s = emboss(tg * 0.5 + 0.5 * grip, strength=1.0)
        gv = np.clip(0.35 + 0.7 * d + 0.35 * s, 0, 1.05)
        col, a = over(col, a, GRIP * gv[:, :, None], grip_s)
        col, a = over(col, a, GOLD * mv[:, :, None], metal_s)
    write_blp("MapSwords", premul_rgb(col, a))


make_map_clover()
make_map_swords()
