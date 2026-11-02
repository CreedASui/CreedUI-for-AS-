#!/usr/bin/env python3
"""Creed UI's panel frame, in the timer's polished metal: grey so the addon tints it with the
map's metal. BLP2 (uncompressed BGRA) + PNG.
  PanelEdge   64x16  the top edge (a metal tube with a dark outline and a fine inner line);
                     flipped for the bottom
  PanelEdgeV  16x64  the left edge; flipped for the right
  PanelCorner 32x32  the top left corner: the tube turning round, a riveted diamond plate on it
  PanelCap    64x64  the left end's crest: a gem setting with swept blades; flipped for the right
  PanelFill   128x64 the brushed dark fill
  PanelDivider 8x64  a thin metal bar between groups"""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
SS = 8


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


def down(a, w, h):
    return a.reshape(h, SS, w, SS).mean(axis=(1, 3))


def finish(name, value, alpha, w, h):
    """value, alpha: supersampled arrays; premultiplied average down to w x h"""
    a = down(alpha, w, h)
    v = down(value * alpha, w, h)
    with np.errstate(invalid="ignore", divide="ignore"):
        v = np.where(a > 1e-6, v / a, 0)
    write_blp(name, np.clip(np.dstack([v, v, v, a]), 0, 1))


def grid(w, h):
    ys, xs = np.mgrid[0:h * SS, 0:w * SS]
    return (xs + 0.5) / SS, (ys + 0.5) / SS  # in final pixels


# the edge's profile, by depth from the outer edge in pixels: an outline, a polished tube with a
# streak of light, an outline, a dark gap and a fine light line, then a soft shadow inward
TUBE = 9.0


def profile(d):
    v = np.zeros_like(d)
    a = np.zeros_like(d)
    out = (d >= 0) & (d < 1.2)
    v[out], a[out] = 0.06, 0.92
    tube = (d >= 1.2) & (d < TUBE - 1.2)
    t = (d[tube] - 1.2) / (TUBE - 2.4)  # 0..1 across the tube
    shade = 0.5 + 0.42 * np.sqrt(np.clip(1 - (2 * t - 1) ** 2, 0, 1))
    streak = 0.22 * np.exp(-((t - 0.36) / 0.09) ** 2)
    v[tube], a[tube] = np.clip(shade + streak, 0, 1), 1.0
    inner = (d >= TUBE - 1.2) & (d < TUBE)
    v[inner], a[inner] = 0.06, 0.92
    gap = (d >= TUBE) & (d < TUBE + 1.0)
    v[gap], a[gap] = 0.05, 0.55
    fine = (d >= TUBE + 1.0) & (d < TUBE + 2.0)
    v[fine], a[fine] = 0.78, 0.75
    soft = (d >= TUBE + 2.0) & (d < 16)
    v[soft], a[soft] = 0.0, 0.42 * (1 - (d[soft] - TUBE - 2.0) / (16 - TUBE - 2.0)) ** 1.6
    return v, a


def make_edges():
    x, y = grid(64, 16)
    v, a = profile(y)
    finish("PanelEdge", v, a, 64, 16)
    x, y = grid(16, 64)
    v, a = profile(x)
    finish("PanelEdgeV", v, a, 16, 64)


def dome(dist, radius):
    """a radially lit metal dome: bright centre, dark rim (flips any way and stays lit)"""
    t = np.clip(dist / radius, 0, 1)
    return 0.45 + 0.52 * (1 - t ** 2) ** 0.7


def make_corner():
    x, y = grid(32, 32)
    r = 7.0
    qx, qy = r - x, r - y
    rounded = (qx > 0) & (qy > 0)
    d = np.where(rounded, r - np.hypot(qx, qy), np.minimum(x, y))
    v, a = profile(d)
    a = np.where(d < 0, 0, a)
    # a diamond plate riveted over the corner
    cx = cy = 6.5
    man = (np.abs(x - cx) + np.abs(y - cy))
    R = 7.5
    plate = man < R
    edge = (man >= R) & (man < R + 1.1)
    v = np.where(edge, 0.05, v)
    a = np.where(edge, np.maximum(a, 0.95), a)
    pv = 0.52 + 0.44 * np.clip(1 - man / R, 0, 1) ** 0.5
    v = np.where(plate, pv, v)
    a = np.where(plate, 1.0, a)
    # its rivet
    dist = np.hypot(x - cx, y - cy)
    rv = dist < 2.4
    ring = (dist >= 2.4) & (dist < 3.2)
    v = np.where(ring, 0.1, v)
    v = np.where(rv, dome(dist, 2.4) + 0.08, v)
    finish("PanelCorner", np.clip(v, 0, 1), np.clip(a, 0, 1), 32, 32)


def emboss(sd, bevel, light=(0.0, -0.75, 0.66)):
    """cast metal from a signed distance (negative inside, in pixels): a rounded bevel lit from above"""
    h = np.clip(-sd / bevel, 0, 1)
    h = np.sin(h * np.pi / 2)
    gy, gx = np.gradient(h * bevel * 0.9 * SS)  # per supersample, scaled to pixels
    nx, ny, nz = -gx, -gy, np.ones_like(h)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    lx, ly, lz = light
    diff = (nx * lx + ny * ly + nz * lz) / n
    v = 0.18 + 0.72 * np.clip(diff, 0, 1)
    spec = np.clip(diff, 0, 1) ** 18 * 0.35
    return np.clip(v + spec, 0, 1)


def seg_sd(x, y, x1, y1, x2, y2, r1, r2):
    """distance to a tapered capsule from (x1,y1) radius r1 to (x2,y2) radius r2"""
    dx, dy = x2 - x1, y2 - y1
    L2 = dx * dx + dy * dy
    t = np.clip(((x - x1) * dx + (y - y1) * dy) / L2, 0, 1)
    px, py = x1 + t * dx, y1 + t * dy
    return np.hypot(x - px, y - py) - (r1 + (r2 - r1) * t)


def make_cap():
    x, y = grid(64, 64)
    cx, cy = 44.0, 32.0
    # the setting: a pointed oval, upright
    ex = (x - cx) / 8.5
    ey = (y - cy) / 15.0
    oval = (np.sqrt(ex * ex + ey * ey) - 1) * 8.5
    pointy = (np.abs(x - cx) / 8.5 + np.abs(y - cy) / 19.0 - 1) * 8.0
    setting = np.maximum(oval, pointy) if False else np.minimum(oval, pointy * 0.0 + oval)
    setting = oval
    # swept blades toward the outside (left), curving out above and below, and a spike between
    blades = np.minimum(seg_sd(x, y, cx - 4, cy - 6, 9, cy - 22, 4.2, 0.6),
                        seg_sd(x, y, cx - 4, cy + 6, 9, cy + 22, 4.2, 0.6))
    blades2 = np.minimum(seg_sd(x, y, cx - 6, cy - 3, 14, cy - 11, 3.0, 0.5),
                         seg_sd(x, y, cx - 6, cy + 3, 14, cy + 11, 3.0, 0.5))
    spike = seg_sd(x, y, cx - 6, cy, 3, cy, 3.4, 0.5)
    # a bar into the panel's edge on the right
    bar = seg_sd(x, y, cx + 4, cy, 63, cy, 3.6, 3.6)
    shape = np.minimum(np.minimum(np.minimum(setting, blades), np.minimum(blades2, spike)), bar)
    v = emboss(shape, 2.6)
    outline = 1.3
    a = np.clip(0.5 - shape / (1.0 / SS * 4), 0, 1)  # soft inside edge
    ring = (shape >= 0) & (shape < outline)
    v = np.where(ring, 0.05, v)
    a = np.where(ring, 0.95, np.where(shape < 0, 1.0, 0.0))
    # the socket where the gem sits: dark, with a thin light lip
    sock = (np.sqrt(((x - cx) / 4.6) ** 2 + ((y - cy) / 7.6) ** 2) - 1) * 4.6
    v = np.where(sock < 0, 0.08 + 0.1 * np.clip(-sock / 4.6, 0, 1), v)
    lip = (sock >= 0) & (sock < 0.9)
    v = np.where(lip, 0.85, v)
    finish("PanelCap", np.clip(v, 0, 1), np.clip(a, 0, 1), 64, 64)


def make_fill():
    rng = np.random.default_rng(7)
    w, h = 128, 64
    noise = rng.normal(0, 1, (h, w))
    # brushed along x: smear the noise sideways
    k = np.ones(9) / 9
    brushed = np.apply_along_axis(lambda r: np.convolve(np.r_[r[-8:], r, r[:8]], k, mode="same")[8:-8], 1, noise)
    v = 0.22 + 0.035 * brushed + 0.012 * noise
    rows = np.linspace(1.08, 0.86, h)[:, None]  # a little lighter at the top
    v = np.clip(v * rows, 0, 1)
    write_blp("PanelFill", np.dstack([v, v, v, np.ones_like(v)]))


def make_divider():
    x, y = grid(8, 64)
    d = np.abs(x - 4.0)
    v = np.where(d < 1.6, 0.5 + 0.48 * np.sqrt(np.clip(1 - (d / 1.6) ** 2, 0, 1)), 0.05)
    a = np.where(d < 1.6, 1.0, np.where(d < 2.6, 0.85, 0.0))
    # fade at both ends
    fade = np.clip(np.minimum(y, 64 - y) / 10.0, 0, 1)
    finish("PanelDivider", v, a * fade, 8, 64)


make_edges()
make_corner()
make_cap()
make_fill()
make_divider()
