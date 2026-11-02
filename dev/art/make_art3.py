#!/usr/bin/env python3
"""Creed UI's extra art, in the boss timer's metal style: the spell slot bezel, the jewelry
socket plate, the portrait ring and the level badge. BLP2 (uncompressed BGRA) + PNG copies."""
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


def make_slot():
    """Square bezel for a spell: metal frame, open middle with a recessed inner shadow."""
    x, y = grid(64, 64)
    px = 2.0 / (64 * SS)
    d_out = rrect(x, y, 0.97, 0.18)
    d_in = rrect(x, y, 0.80, 0.07)
    band, g, outer, hole = metal_ring(d_out, d_in, px, 1.0)
    groove = np.exp(-(rrect(x, y, 0.885, 0.12) / 0.012) ** 2)
    g = g * (1 - 0.3 * groove)
    c, a = np.zeros_like(x), np.zeros_like(x)
    drop = np.clip(1 - rrect(x, y - 0.03, 0.97, 0.18) / 0.06, 0, 1) ** 2 * 0.6 * (1 - outer)
    c, a = layer_over(c, a, np.zeros_like(x), drop)
    # the icon sits in a dark recess: shadow along the inner edge, heavier at the top
    inside = -d_in
    top = np.clip(-y * 0.6 + 0.5, 0.25, 1)
    sh = np.exp(-(np.clip(inside, 0, 1) / 0.07) ** 2) * 0.75 * top * hole
    c, a = layer_over(c, a, np.zeros_like(x), sh)
    c, a = layer_over(c, a, g, band)
    write_blp("Slot", premul_down(c, a))


def make_jewel():
    """Socket plate for jewelry: a rounded plate with a round opening and a raised ring."""
    x, y = grid(64, 64)
    px = 2.0 / (64 * SS)
    r = np.sqrt(x * x + y * y)
    d_plate = rrect(x, y, 0.96, 0.34)
    d_ring_out, d_hole = r - 0.86, r - 0.64
    plate = cover(d_plate, px)
    band, g, outer, hole = metal_ring(d_ring_out, d_hole, px, 1.4)
    c, a = np.zeros_like(x), np.zeros_like(x)
    drop = np.clip(1 - rrect(x, y - 0.03, 0.96, 0.34) / 0.07, 0, 1) ** 2 * 0.55 * (1 - plate)
    c, a = layer_over(c, a, np.zeros_like(x), drop)
    # the plate: dark metal with a soft bevel along its edge
    bevel = np.clip(-d_plate / 0.12, 0, 1)
    pl = 0.10 + 0.10 * (1 - bevel) * np.clip(-y + 0.3, 0, 1) + 0.05 * (1 - bevel)
    pl_edge = np.exp(-(d_plate / 0.02) ** 2)
    pl = pl * (1 - 0.6 * pl_edge)
    c, a = layer_over(c, a, pl, plate * (1 - hole))
    sh = np.exp(-(np.clip(-d_hole, 0, 1) / 0.08) ** 2) * 0.7 * np.clip(-y * 0.6 + 0.5, 0.3, 1) * hole
    c, a = layer_over(c, a, np.zeros_like(x), sh)
    c, a = layer_over(c, a, g, band)
    write_blp("Jewel", premul_down(c, a))


def make_portrait():
    """Round metal ring around the hero's portrait, with four small studs."""
    x, y = grid(128, 128)
    px = 2.0 / (128 * SS)
    r = np.sqrt(x * x + y * y)
    d_out, d_in = r - 0.97, r - 0.80
    band, g, outer, hole = metal_ring(d_out, d_in, px, 1.6)
    groove = np.exp(-((r - 0.885) / 0.008) ** 2)
    g = g * (1 - 0.3 * groove)
    c, a = np.zeros_like(x), np.zeros_like(x)
    drop = np.clip(1 - (np.sqrt(x * x + (y - 0.025) ** 2) - 0.97) / 0.05, 0, 1) ** 2 * 0.6 * (1 - outer)
    c, a = layer_over(c, a, np.zeros_like(x), drop)
    sh = np.exp(-(np.clip(-d_in, 0, 1) / 0.08) ** 2) * 0.6 * np.clip(-y * 0.6 + 0.5, 0.3, 1) * hole
    c, a = layer_over(c, a, np.zeros_like(x), sh)
    c, a = layer_over(c, a, g, band)
    for ang in (np.pi / 4, 3 * np.pi / 4, 5 * np.pi / 4, 7 * np.pi / 4):
        sx, sy = np.cos(ang) * 0.885, np.sin(ang) * 0.885
        d = np.sqrt((x - sx) ** 2 + (y - sy) ** 2) - 0.055
        stud = cover(d, px)
        sd, ssp = emboss(np.clip(-d / 0.055, 0, 1) * 0.5 + 0.5 * stud, strength=0.6)
        c, a = layer_over(c, a, np.clip(0.3 + 0.8 * sd + 0.5 * ssp, 0, 1.1), stud)
    write_blp("Portrait", premul_down(c, a))


def make_badge():
    """Small round badge (the hero's level): a dark disc in a metal ring."""
    x, y = grid(32, 32)
    px = 2.0 / (32 * SS)
    r = np.sqrt(x * x + y * y)
    d_out, d_in = r - 0.95, r - 0.70
    band, g, outer, hole = metal_ring(d_out, d_in, px, 0.9)
    c, a = np.zeros_like(x), np.zeros_like(x)
    drop = np.clip(1 - (np.sqrt(x * x + (y - 0.05) ** 2) - 0.95) / 0.1, 0, 1) ** 2 * 0.5 * (1 - outer)
    c, a = layer_over(c, a, np.zeros_like(x), drop)
    disc = 0.06 + 0.07 * np.clip(y / 0.7, 0, 1)
    c, a = layer_over(c, a, disc, hole)
    c, a = layer_over(c, a, g, band)
    write_blp("Badge", premul_down(c, a))




def make_map_ring():
    """The minimap's ring: a slimmer metal band than the portrait's, with eight studs and a
    small diamond plate at the top for the north mark."""
    x, y = grid(256, 256)
    px = 2.0 / (256 * SS)
    r = np.sqrt(x * x + y * y)
    d_out, d_in = r - 0.975, r - 0.875
    band, g, outer, hole = metal_ring(d_out, d_in, px, 2.6)
    groove = np.exp(-((r - 0.925) / 0.004) ** 2)
    g = g * (1 - 0.28 * groove)
    c, a = np.zeros_like(x), np.zeros_like(x)
    drop = np.clip(1 - (np.sqrt(x * x + (y - 0.012) ** 2) - 0.975) / 0.025, 0, 1) ** 2 * 0.6 * (1 - outer)
    c, a = layer_over(c, a, np.zeros_like(x), drop)
    sh = np.exp(-(np.clip(-d_in, 0, 1) / 0.035) ** 2) * 0.55 * np.clip(-y * 0.6 + 0.5, 0.3, 1) * hole
    c, a = layer_over(c, a, np.zeros_like(x), sh)
    c, a = layer_over(c, a, g, band)
    for k in range(8):
        if k == 6:
            continue  # the top one is the north plate
        ang = k * np.pi / 4
        sx, sy = np.cos(ang) * 0.925, np.sin(ang) * 0.925
        d = np.sqrt((x - sx) ** 2 + (y - sy) ** 2) - 0.03
        stud = cover(d, px)
        sd, ssp = emboss(np.clip(-d / 0.03, 0, 1) * 0.5 + 0.5 * stud, strength=1.0)
        c, a = layer_over(c, a, np.clip(0.3 + 0.8 * sd + 0.5 * ssp, 0, 1.1), stud)
    # north plate: a small diamond on the ring's top
    nx, ny = x, y + 0.925
    d = (np.abs(nx) / 0.075 + np.abs(ny) / 0.09 - 1) * 0.06
    plate = cover(d, px)
    pd = np.where(ny < 0, np.where(nx < 0, 1.0, 0.8), np.where(nx < 0, 0.6, 0.45))
    edge = np.exp(-(d / 0.004) ** 2)
    pd = pd * (1 - 0.6 * np.clip(edge, 0, 1))
    c, a = layer_over(c, a, pd, plate)
    write_blp("MapRing", premul_down(c, a))


make_map_ring()
print("ok")
