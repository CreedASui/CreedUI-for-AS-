#!/usr/bin/env python3
"""Generate the Smooth Boss Timer art as BLP2 (uncompressed BGRA) plus PNG copies.

Every texture is drawn white/grayscale so the addon can tint it per zone with
SetVertexColor / SetGradientAlpha. Shapes are rendered with supersampling.
"""
import os
import struct
import sys

import numpy as np
from PIL import Image

OUT_BLP = sys.argv[1]
OUT_PNG = sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)

SS = 4  # supersampling


def write_blp(name, rgba):
    """rgba: float array (h, w, 4) in 0..1, top-down."""
    h, w, _ = rgba.shape
    assert w & (w - 1) == 0 and h & (h - 1) == 0, (name, w, h)
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    bgra = a8[:, :, [2, 1, 0, 3]].tobytes()
    offsets = [1172] + [0] * 15
    sizes = [w * h * 4] + [0] * 15
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes)
    head += bytes(1024)
    assert len(head) == 1172
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + bgra)
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def grid(w, h, ss=SS):
    """Pixel-centre coordinates of a supersampled grid, normalised to -1..1."""
    xs = (np.arange(w * ss) + 0.5) / (w * ss) * 2 - 1
    ys = (np.arange(h * ss) + 0.5) / (h * ss) * 2 - 1
    return np.meshgrid(xs, ys)


def down(a, ss=SS):
    h, w = a.shape[0] // ss, a.shape[1] // ss
    if a.ndim == 2:
        return a.reshape(h, ss, w, ss).mean(axis=(1, 3))
    return a.reshape(h, ss, w, ss, a.shape[2]).mean(axis=(1, 3))


def premul_down(rgb, alpha, ss=SS):
    """Downsample colour weighted by alpha so edges don't go dark."""
    pa = down(rgb * alpha[..., None], ss)
    a = down(alpha, ss)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a[..., None] > 1e-6, pa / a[..., None], 0)
    return np.dstack([np.clip(c, 0, 1), np.clip(a, 0, 1)])


def smooth01(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def cover(sdf, px):
    """Anti-aliased coverage from a signed distance (negative inside); px = one supersample."""
    return np.clip(0.5 - sdf / px, 0, 1)


def emboss(t, light=(-0.35, -0.75, 0.6), strength=2.2, spec=0.55, power=18):
    """Lighting for a ridge whose cross-section parameter t runs 0..1."""
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


# --------------------------------------------------------------------------- glows
def make_glow():
    x, y = grid(64, 64)
    r = np.sqrt(x * x + y * y)
    a = np.exp(-(r / 0.42) ** 2) * smooth01((1 - r) / 0.25)
    rgb = np.ones(a.shape + (3,))
    write_blp("Glow", premul_down(rgb, a))


def make_ring():
    x, y = grid(64, 64)
    r = np.sqrt(x * x + y * y)
    a = np.exp(-((r - 0.66) / 0.13) ** 2) * smooth01((1 - r) / 0.12)
    rgb = np.ones(a.shape + (3,))
    write_blp("Ring", premul_down(rgb, a))


def make_spark():
    x, y = grid(32, 64)
    a = np.exp(-(x / 0.30) ** 2) * np.exp(-(y / 0.62) ** 2)
    core = np.exp(-(x / 0.10) ** 2) * np.exp(-(y / 0.45) ** 2)
    a = np.clip(a * 0.8 + core * 0.6, 0, 1) * smooth01((1 - np.abs(y)) / 0.2) * smooth01((1 - np.abs(x)) / 0.2)
    rgb = np.ones(a.shape + (3,))
    write_blp("Spark", premul_down(rgb, a))


def make_twinkle():
    x, y = grid(32, 32)
    ax, ay = np.abs(x), np.abs(y)
    a = np.maximum(np.exp(-ax / 0.07) * np.exp(-ay / 0.55), np.exp(-ay / 0.07) * np.exp(-ax / 0.55))
    a = a + 0.7 * np.exp(-((x * x + y * y) / 0.06))
    a = np.clip(a, 0, 1) * smooth01((1 - np.maximum(ax, ay)) / 0.15)
    rgb = np.ones(a.shape + (3,))
    write_blp("Twinkle", premul_down(rgb, a))


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    qx, qy = ax + t * dx - px, ay + t * dy - py
    return np.sqrt(qx * qx + qy * qy)


def make_flake():
    x, y = grid(32, 32)
    d = np.full(x.shape, 9.0)
    for k in range(6):
        ang = k * np.pi / 3 + np.pi / 2
        cx, cy = np.cos(ang), np.sin(ang)
        d = np.minimum(d, seg_dist(x, y, 0, 0, cx * 0.82, cy * 0.82))
        for frac, ln in ((0.45, 0.26), (0.68, 0.17)):
            bx, by = cx * frac, cy * frac
            for side in (-1, 1):
                a2 = ang + side * np.pi / 3
                d = np.minimum(d, seg_dist(x, y, bx, by, bx + np.cos(a2) * ln, by + np.sin(a2) * ln))
    core = cover(d - 0.075, 2.0 / (32 * SS))
    glow = np.exp(-(d / 0.16) ** 2) * 0.45
    a = np.clip(np.maximum(core, glow), 0, 1)
    rgb = np.ones(a.shape + (3,))
    write_blp("Flake", premul_down(rgb, a))


def make_leaf():
    x, y = grid(32, 32)
    # rotate 35 degrees so the leaf lies diagonally
    c, s = np.cos(0.6), np.sin(0.6)
    u, v = c * x + s * y, -s * x + c * y
    # leaf: two arcs meeting at points (pointed ellipse)
    w = 0.42 * (1 - (u / 0.86) ** 2)
    w = np.where(np.abs(u) < 0.86, w, -1)
    inside = np.abs(v) - np.maximum(w, 0)
    sdf = np.where(w > 0, inside, 1)
    a = cover(sdf, 2.0 / (32 * SS))
    # shading: lighter towards the top edge, a darker midrib and veins
    shade = 0.78 + 0.22 * np.clip(-v / 0.42, -1, 1)
    vein = np.exp(-(v / 0.035) ** 2) * (np.abs(u) < 0.8)
    side_veins = np.exp(-((np.mod(u * 5 + np.abs(v) * 4, 1.0) - 0.5) / 0.08) ** 2) * 0.18
    g = np.clip(shade - vein * 0.35 - side_veins, 0, 1)
    stem = cover(seg_dist(u, v, -1.0, 0.0, -0.8, 0.0) - 0.04, 2.0 / (32 * SS))
    a = np.maximum(a, stem)
    g = np.where(stem > a - 1e-6, np.maximum(g, 0.6), g)
    rgb = np.dstack([g, g, g])
    write_blp("Leaf", premul_down(rgb, a))


def make_mote():
    """A soft blob with a brighter core, for spores and blood motes."""
    x, y = grid(32, 32)
    r = np.sqrt(x * x + y * y)
    a = np.exp(-(r / 0.55) ** 2) * 0.55 + np.exp(-(r / 0.22) ** 2) * 0.7
    a = np.clip(a, 0, 1) * smooth01((1 - r) / 0.2)
    rgb = np.ones(a.shape + (3,))
    write_blp("Mote", premul_down(rgb, a))


# --------------------------------------------------------------------------- bar
FRAME_UI = 22.0  # the frame textures are 64 texels for 22 UI units


def frame_pixels(x_ui, y_ui):
    """Rim colour/alpha at UI coordinates (left cap; the pill runs on to the right)."""
    px = FRAME_UI / (64 * SS) * 1.0  # one supersample in UI units
    cy = 11.0
    # distance to the pill's centre line, which starts at x = 17
    dx = np.minimum(x_ui - 17.0, 0)
    dy = y_ui - cy
    dist = np.sqrt(dx * dx + dy * dy)
    R_OUT, R_IN = 9.0, 6.0
    outer = cover(dist - R_OUT, px)
    hole = cover(dist - R_IN, px)
    rim_a = np.clip(outer - hole, 0, 1)
    t = np.clip((dist - R_IN) / (R_OUT - R_IN), 0, 1)
    diff, sp = emboss(t, strength=1.6)
    g = 0.16 + 0.80 * diff + 0.55 * sp
    # dark lines at both rim edges
    edge = np.exp(-((dist - R_OUT) / 0.45) ** 2) + np.exp(-((dist - R_IN) / 0.40) ** 2)
    g = np.clip(g * (1 - 0.65 * np.clip(edge, 0, 1)), 0, 1.15)
    # engraved groove along the middle of the rim
    groove = np.exp(-((dist - (R_IN + R_OUT) / 2) / 0.22) ** 2)
    g = g * (1 - 0.25 * groove)
    # inner shadow cast into the trough (mostly at the top)
    inside = 1 - hole
    sh_d = R_IN - dist
    top = np.clip(-dy / R_IN * 0.7 + 0.45, 0, 1)
    inner_sh = np.exp(-(np.clip(sh_d, 0, 9) / 1.6) ** 2) * 0.55 * top * (sh_d > -0.5) * (1 - inside) * 0
    inner_sh = np.exp(-(np.clip(sh_d, 0, 9) / 1.5) ** 2) * (0.25 + 0.4 * top) * hole
    # drop shadow outside the pill
    dist_s = np.sqrt(dx * dx + (dy - 0.8) ** 2)
    drop = np.clip(1 - (dist_s - R_OUT) / 2.6, 0, 1) ** 2 * 0.6 * (1 - outer)
    # finial: a diamond at x = 5
    fx, fy = x_ui - 5.2, y_ui - cy
    fa, fb = 4.9, 5.4
    fsd = (np.abs(fx) / fa + np.abs(fy) / fb - 1) * min(fa, fb) * 0.75
    fin = cover(fsd, px)
    fin_drop = np.clip(1 - ((np.abs(fx) / fa + np.abs(fy - 0.8) / fb - 1) * 4.0), 0, 1) ** 2 * 0.5
    # facets
    facet = np.where(fy < 0, np.where(fx < 0, 1.0, 0.78), np.where(fx < 0, 0.58, 0.40))
    inner_d = np.abs(fx) / (fa * 0.45) + np.abs(fy) / (fb * 0.45)
    inlay = cover((inner_d - 1) * 1.6, px)
    facet = facet * (1 - inlay) + inlay * np.where(fy < 0, 0.45, 0.25)
    fline = np.exp(-(fsd / 0.32) ** 2) + np.exp(-((inner_d - 1) * 1.6 / 0.3) ** 2) * 0.6
    fin_g = np.clip(facet * (1 - 0.7 * np.clip(fline, 0, 1)) + 0.2 * np.exp(-((fx + 1.4) ** 2 + (fy + 1.8) ** 2) / 1.2), 0, 1.1)

    # composite: drop shadow < inner shadow < rim < finial drop < finial
    a = np.zeros_like(x_ui)
    c = np.zeros_like(x_ui)

    def over(col, al):
        nonlocal a, c
        na = al + a * (1 - al)
        with np.errstate(invalid="ignore", divide="ignore"):
            c = np.where(na > 1e-6, (col * al + c * a * (1 - al)) / na, 0)
        a = na

    over(np.zeros_like(c), np.maximum(drop, 0))
    over(np.zeros_like(c), inner_sh)
    over(g, rim_a)
    over(np.zeros_like(c), fin_drop * (1 - fin) * (x_ui < 12))
    over(fin_g, fin)
    return c, a


def make_frame():
    w, h = 64, 64
    xs = (np.arange(w * SS) + 0.5) / (w * SS) * FRAME_UI
    ys = (np.arange(h * SS) + 0.5) / (h * SS) * FRAME_UI
    X, Y = np.meshgrid(xs, ys)
    c, a = frame_pixels(X, Y)
    left = premul_down(np.dstack([c, c, c]), a)
    write_blp("FrameL", left)
    write_blp("FrameR", left[:, ::-1, :].copy())
    # middle: a uniform column from the straight part
    w2 = 16
    xs = np.full(w2 * SS, 40.0)
    X, Y = np.meshgrid(xs, ys)
    c, a = frame_pixels(X, Y)
    write_blp("FrameM", premul_down(np.dstack([c, c, c]), a))


def make_fill():
    h = 32
    y = (np.arange(h) + 0.5) / h
    v = np.interp(y, [0.0, 0.07, 0.13, 0.24, 0.50, 0.80, 0.92, 1.0],
                  [0.78, 1.00, 1.00, 0.93, 0.84, 0.68, 0.55, 0.46])
    img = np.zeros((h, 16, 4))
    img[:, :, 0] = v[:, None]
    img[:, :, 1] = v[:, None]
    img[:, :, 2] = v[:, None]
    img[:, :, 3] = 1
    write_blp("Fill", img)


def make_flow():
    W, H, P = 1024, 32, 128
    rng = np.random.default_rng(7)
    x = np.arange(W)[None, :].astype(float)
    y = ((np.arange(H) + 0.5) / H)[:, None]
    two_pi = 2 * np.pi / P
    pat = np.zeros((H, W))
    for k in range(7):
        n = rng.integers(1, 3)
        m = rng.integers(1, 4)
        phase, phase2 = rng.uniform(0, 2 * np.pi, 2)
        centre = 0.5 + rng.uniform(0.12, 0.30) * np.sin(two_pi * n * x + phase)
        width = rng.uniform(0.05, 0.11)
        bright = 0.5 + 0.5 * np.sin(two_pi * m * x + phase2)
        pat += np.exp(-((y - centre) / width) ** 2) * bright ** 1.6 * rng.uniform(0.5, 1.0)
    # fine periodic sparkle
    for k in range(5):
        f = rng.integers(3, 9)
        g = rng.integers(1, 3)
        ph = rng.uniform(0, 2 * np.pi, 2)
        pat += 0.10 * (0.5 + 0.5 * np.sin(two_pi * f * x + ph[0] + 6 * y * g)) ** 6
    pat = pat / pat.max()
    env = np.sin(np.pi * np.clip(y, 0, 1)) ** 0.7
    a = np.clip(pat * env * 1.25, 0, 1) ** 1.15
    img = np.ones((H, W, 4))
    img[:, :, 3] = a
    # The game (0.139.0 on) shows any texture side over 512 as solid green: store the 1024-wide
    # pattern at half its width. Texture coordinates are fractions, so the addons map it the same.
    img = img.reshape(H, W // 2, 2, 4).mean(axis=2)
    write_blp("Flow", img)


def make_shine():
    x, y = grid(64, 32)
    d = x - 0.45 * y
    a = np.exp(-(d / 0.22) ** 2) * 0.9 + np.exp(-(d / 0.6) ** 2) * 0.25
    a = np.clip(a, 0, 1) * smooth01((1 - np.abs(x)) / 0.3)
    rgb = np.ones(a.shape + (3,))
    write_blp("Shine", premul_down(rgb, a))


# --------------------------------------------------------------------------- markers
def rhombus(u, v, r):
    return (np.abs(u) + np.abs(v) - r) * 0.7071


def make_socket(name, star):
    x, y = grid(64, 64)
    px = 2.0 / (64 * SS)
    HOLE = 0.60 if star else 0.64
    if star:
        d_rh = rhombus(x, y, 0.97)
        d_sq = np.maximum(np.abs(x), np.abs(y)) - 0.60
        d_out = np.minimum(d_rh, d_sq)
    else:
        d_out = rhombus(x, y, 0.95)
    d_in = rhombus(x, y, HOLE)
    outer = cover(d_out, px)
    hole = cover(d_in, px)
    rim = np.clip(outer - hole, 0, 1)
    with np.errstate(invalid="ignore", divide="ignore"):
        t = np.clip(d_in / np.maximum(d_in - d_out, 1e-4), 0, 1)
    diff, sp = emboss(t, strength=0.9)
    g = 0.15 + 0.8 * diff + 0.6 * sp
    edge = np.exp(-(d_out / 0.022) ** 2) + np.exp(-(d_in / 0.02) ** 2)
    g = np.clip(g * (1 - 0.7 * np.clip(edge, 0, 1)), 0, 1.1)
    if star:
        # inner ring line that follows the diamond, for an ornate look
        ring_d = rhombus(x, y, 0.80)
        g = g * (1 - 0.35 * np.exp(-(ring_d / 0.018) ** 2) * (d_rh < 0))
    # the empty socket: dark, with an inner shadow at the top
    inner = 0.07 + 0.10 * np.clip(y / HOLE, 0, 1)
    sh = np.exp(-(np.clip(-d_in, 0, 1) / 0.06) ** 2) * 0.6 * np.clip(-y / HOLE + 0.5, 0, 1)
    inner = inner * (1 - sh)
    col = np.where(hole > 0, inner, g)
    col = g * rim + inner * hole
    a = np.clip(rim + hole, 0, 1)
    # outer soft shadow
    drop = np.clip(1 - d_out / 0.09, 0, 1) ** 2 * 0.55 * (1 - outer)
    tot = a + drop * (1 - a)
    with np.errstate(invalid="ignore", divide="ignore"):
        col = np.where(tot > 1e-6, col * a / tot, 0)
    write_blp(name, premul_down(np.dstack([col, col, col]), tot))


def make_gem():
    x, y = grid(64, 64)
    px = 2.0 / (64 * SS)
    R = 0.64
    d = rhombus(x, y, R)
    a = cover(d + 0.004, px)
    q = np.abs(x) + np.abs(y)
    table = q < R * 0.42
    facet = np.where(y < 0, np.where(x < 0, 1.00, 0.80), np.where(x < 0, 0.62, 0.44))
    # a gentle gradient across each facet, lighter towards the centre
    facet = facet * (0.82 + 0.18 * (1 - q / R))
    tab = 0.86 - 0.18 * (y / (R * 0.42))
    g = np.where(table, tab, facet)
    lines = np.exp(-((q - R * 0.42) / 0.012) ** 2) * 0.5
    lines += np.exp(-(np.abs(x) / 0.010) ** 2) * (q > R * 0.42) * 0.35
    lines += np.exp(-(np.abs(y) / 0.010) ** 2) * (q > R * 0.42) * 0.35
    rim = np.exp(-(d / 0.018) ** 2) * 0.6
    g = np.clip(g * (1 - np.clip(lines + rim, 0, 0.8)), 0, 1)
    write_blp("Gem", premul_down(np.dstack([g, g, g]), a))

    # highlights only (white), drawn on top additively
    hl = np.exp(-(((x + 0.14) / 0.12) ** 2 + ((y + 0.22) / 0.08) ** 2)) * 0.95
    hl += np.exp(-(((x + 0.30) / 0.05) ** 2 + ((y + 0.06) / 0.05) ** 2)) * 0.7
    # bright line along the upper-left edge
    hl += np.exp(-(rhombus(x, y, R - 0.06) / 0.016) ** 2) * (x < 0) * (y < 0) * 0.55
    # sparkle cross
    sx, sy = x + 0.16, y + 0.24
    hl += (np.exp(-np.abs(sx) / 0.012) * np.exp(-np.abs(sy) / 0.10) +
           np.exp(-np.abs(sy) / 0.012) * np.exp(-np.abs(sx) / 0.10)) * 0.5
    hl = np.clip(hl, 0, 1) * a
    rgb = np.ones(hl.shape + (3,))
    write_blp("GemShine", premul_down(rgb, hl))


def make_check():
    x, y = grid(32, 32)
    px = 2.0 / (32 * SS)
    d = np.minimum(seg_dist(x, y, -0.55, 0.02, -0.16, 0.42), seg_dist(x, y, -0.16, 0.42, 0.58, -0.50))
    core = cover(d - 0.13, px)
    out = cover(d - 0.25, px)
    g = core
    a = out
    write_blp("Check", premul_down(np.dstack([g, g, g]), a))


def make_caret():
    x, y = grid(16, 16)
    px = 2.0 / (16 * SS)
    # upward triangle with a soft dark outline
    d = np.maximum(np.abs(x) * 0.894 - y * 0.447 - 0.36, y - 0.5) * 0.9
    core = cover(d + 0.05, px)
    out = cover(d - 0.12, px)
    write_blp("Caret", premul_down(np.dstack([core, core, core]), out))


def make_diamond():
    """Small ornament for the title flourishes."""
    x, y = grid(32, 32)
    px = 2.0 / (32 * SS)
    d = rhombus(x, y, 0.80)
    a = cover(d, px)
    q = np.abs(x) + np.abs(y)
    g = np.where(y < 0, np.where(x < 0, 1.0, 0.82), np.where(x < 0, 0.66, 0.5))
    inner = cover(rhombus(x, y, 0.42), px)
    g = g * (1 - inner) + inner * np.where(y < 0, 0.62, 0.42)
    edge = np.exp(-(d / 0.03) ** 2) + np.exp(-(rhombus(x, y, 0.42) / 0.03) ** 2) * 0.6
    g = np.clip(g * (1 - 0.7 * np.clip(edge, 0, 1)), 0, 1)
    out = cover(d - 0.06, px)
    col = g * a
    write_blp("Diamond", premul_down(np.dstack([col, col, col]), out))


make_glow()
make_ring()
make_spark()
make_twinkle()
make_flake()
make_leaf()
make_mote()
make_frame()
make_fill()
make_flow()
make_shine()
make_socket("Socket", False)
make_socket("SocketFinal", True)
make_gem()
make_check()
make_caret()
make_diamond()
print("ok")
