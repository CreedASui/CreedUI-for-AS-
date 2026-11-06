#!/usr/bin/env python3
"""Creed UI's class emblems (original), standing on each end of the skill bar in a class's theme where
the bronze theme has its dragons (1.21.1, asked for). Each is drawn facing right (the bar's right end;
the left one is it mirrored), centred on the panel's end, in beveled metal of its class's color:

  Warrior  a round shield with a red gem boss over two crossed axes
  Paladin  a kite shield with a cross and a golden gem, a sunburst behind
  Hunter   a recurve bow drawn, its arrow pointing out, a feather hanging from the grip
  Rogue    two crossed daggers, a gold coin where they cross, a drop of poison
  Priest   a staff crowned by a ring round a star gem, two wings spread from it
  Shaman   a totem of three carved faces under a thunderbird, lightning behind
  Mage     an orb in a claw on a staff head, a rune ring round it, sparkles
  Warlock  a horned skull with fel-green eyes over a violet flame
  Druid    a crescent moon held in antlers, leaves and an amber gem

BLP2 + PNG, 256x256 (PanelEmblem<Class>).

    python3 make_art21.py <blp dir> <png dir>
"""
import math
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
N, SS = 256, 3
BIG = N * SS
# where the emblems stand: the panel's end is at x 0.60 of the picture, its middle at y 0.58
CX, CY = 0.58, 0.56


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def P(x, y):
    return (x * BIG, y * BIG)


def canvas_mask(fn):
    im = Image.new("L", (BIG, BIG), 0)
    fn(ImageDraw.Draw(im))
    return np.asarray(im, dtype=np.float64) / 255.0


def poly(pts):
    return canvas_mask(lambda d: d.polygon([P(*p) for p in pts], fill=255))


def ellipse(cx, cy, rx, ry):
    return canvas_mask(lambda d: d.ellipse([P(cx - rx, cy - ry), P(cx + rx, cy + ry)], fill=255))


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def ring(cx, cy, r0, r1):
    return circle(cx, cy, r1) * (1 - circle(cx, cy, r0))


def line(pts, w):
    def fn(d):
        q = [P(*p) for p in pts]
        d.line(q, fill=255, width=int(w * BIG), joint="curve")
        for x, y in q:
            r = w * BIG / 2
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return canvas_mask(fn)


def rot(pts, ang, cx, cy):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def arc_pts(cx, cy, rx, ry, a0, a1, n=48):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * i / n), cy + ry * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def blur(m, k):
    return ndimage.gaussian_filter(m, k * SS)


def grow(m, k):
    return np.clip(blur(m, k) * 3.0, 0, 1)


def U(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = np.maximum(out, m)
    return out


def cut(a, b):
    return a * (1 - b)


xs = (np.arange(BIG) + 0.5) / BIG
gx, gy = np.meshgrid(xs, xs)


class Pic:
    def __init__(self):
        self.col = np.zeros((BIG, BIG, 3))
        self.a = np.zeros((BIG, BIG))

    def over(self, c, m):
        c = np.broadcast_to(np.asarray(c, dtype=np.float64), (BIG, BIG, 3)) if np.ndim(c) == 1 else c
        m = np.clip(m, 0, 1)
        out = m + self.a * (1 - m)
        self.col = (c * m[..., None] + self.col * self.a[..., None] * (1 - m[..., None])) / np.maximum(out[..., None], 1e-6)
        self.a = out

    def shadow(self, m, k=2.0, strength=0.7):
        sh = blur(np.roll(np.roll(m, int(0.012 * BIG), 0), int(0.006 * BIG), 1), k)
        self.over([0.0, 0.0, 0.0], np.clip(sh * 1.4, 0, 1) * strength)

    def edge(self, m, k=0.8):
        """a dark outline round a shape, so it reads on any background"""
        self.over([0.04, 0.03, 0.03], np.clip(grow(m, k), 0, 1) * 0.92)

    def metal(self, m, base, bevel=1.6, dark=0.32, spec=0.55, engrave=None):
        base = np.asarray(base, dtype=np.float64)
        h = blur(m, bevel) * m
        if engrave is not None:
            h = h - engrave * 0.35
        dy, dx = np.gradient(h)
        k = 55.0 * SS
        nx, ny, nz = -dx * k, -dy * k, np.ones_like(h)
        n = np.sqrt(nx * nx + ny * ny + nz * nz)
        L = np.array([-0.5, -0.7, 0.55])
        L = L / np.linalg.norm(L)
        diff = np.clip((nx * L[0] + ny * L[1] + nz * L[2]) / n, 0, 1)
        H = L + np.array([0, 0, 1.0])
        H = H / np.linalg.norm(H)
        sp = np.clip((nx * H[0] + ny * H[1] + nz * H[2]) / n, 0, 1) ** 22
        t = np.clip(diff * 0.9 + 0.12, 0, 1)[..., None]
        c = base * dark * (1 - t) + base * t
        c = c + sp[..., None] * (0.55 + 0.45 * base) * spec
        # a little top-to-bottom sheen, as polished metal
        c = c * (1.08 - 0.18 * gy)[..., None]
        self.over(np.clip(c, 0, 1), m)

    def flat(self, m, c):
        self.over(c, m)

    def glow(self, m, c, k=6.0, strength=0.8):
        g = np.clip(blur(m, k) * 2.2, 0, 1) * strength
        self.over(c, g)

    def gem(self, cx, cy, r, c, glow=True):
        c = np.asarray(c, dtype=np.float64)
        if glow:
            self.glow(circle(cx, cy, r * 1.4), c, 5, 0.55)
        self.edge(circle(cx, cy, r * 1.08), 0.5)
        dx, dy = gx - cx, gy - cy
        m = circle(cx, cy, r)
        facet = np.where(dy < 0, np.where(dx < 0, 1.0, 0.78), np.where(dx < 0, 0.62, 0.42))
        ang = np.arctan2(dy, dx)
        facet = facet * (0.9 + 0.1 * np.cos(ang * 4))
        col = c[None, None, :] * facet[..., None]
        hl = np.exp(-((dx + r * 0.35) ** 2 + (dy + r * 0.4) ** 2) / (r * r * 0.06))
        col = col + hl[..., None] * np.array([1.0, 0.97, 0.92]) * 0.9
        self.over(np.clip(col, 0, 1), m)

    def finish(self, name, gem):
        """grown about the panel's end as big as its picture allows (up to 1.4x), then down to size;
        prints where its gem ends up, for Core's gemAt"""
        ys_, xs_ = np.nonzero(self.a > 0.03)
        l, r, t, b = xs_.min() / BIG, xs_.max() / BIG, ys_.min() / BIG, ys_.max() / BIG
        K = min(1.4, (CX - 0.01) / (CX - l), (0.99 - CX) / (r - CX), (CY - 0.01) / (CY - t), (0.99 - CY) / (b - CY))
        c0 = np.array([CY, CX]) * BIG

        def zoom(m):
            return ndimage.affine_transform(m, np.array([1 / K, 1 / K]), offset=c0 - c0 / K, order=1)
        pc0 = self.col * self.a[..., None]
        self.a = np.clip(zoom(self.a), 0, 1)
        pcz = np.dstack([zoom(pc0[..., i]) for i in range(3)])
        with np.errstate(invalid="ignore", divide="ignore"):
            self.col = np.where(self.a[..., None] > 1e-5, pcz / self.a[..., None], 0)
        print("%-8s x%.2f  gemAt = { %.3f, %.3f }" % (name[11:], K, CX + (gem[0] - CX) * K, CY + (gem[1] - CY) * K))
        pc = self.col * self.a[..., None]
        pc = pc.reshape(N, SS, N, SS, 3).mean(axis=(1, 3))
        a = self.a.reshape(N, SS, N, SS).mean(axis=(1, 3))
        with np.errstate(invalid="ignore", divide="ignore"):
            c = np.where(a[..., None] > 1e-5, pc / a[..., None], 0)
        write_blp(name, np.dstack([np.clip(c, 0, 1), np.clip(a, 0, 1)]))


def sparkle(p, cx, cy, s, c):
    star = U(poly([(cx - s, cy), (cx, cy - s * 0.18), (cx + s, cy), (cx, cy + s * 0.18)]),
             poly([(cx, cy - s), (cx + s * 0.18, cy), (cx, cy + s), (cx - s * 0.18, cy)]))
    p.glow(circle(cx, cy, s * 0.4), c, 3, 0.7)
    p.flat(star, [1.0, 1.0, 1.0])


# ---------------------------------------------------------------------------- warrior
def warrior():
    p = Pic()
    steel = [0.78, 0.74, 0.70]
    bronze = [0.86, 0.64, 0.42]
    wood = [0.45, 0.28, 0.16]
    cx, cy = CX, CY + 0.02
    axes = []
    for side in (-1, 1):
        a = side * 0.62
        handle = line(rot([(cx, cy + 0.30), (cx, cy - 0.33)], a, cx, cy), 0.035)
        head = poly(rot([(cx, cy - 0.34), (cx + 0.14, cy - 0.42), (cx + 0.165, cy - 0.32), (cx + 0.14, cy - 0.21), (cx, cy - 0.25)], a, cx, cy))
        back = poly(rot([(cx, cy - 0.33), (cx - 0.07, cy - 0.36), (cx - 0.07, cy - 0.27), (cx, cy - 0.28)], a, cx, cy))
        axes.append((handle, cut(U(head, back), handle * 0)))
    allaxes = U(*[U(h, hd) for h, hd in axes])
    p.shadow(allaxes)
    p.edge(allaxes)
    for h, hd in axes:
        p.metal(h, wood, bevel=0.8)
        p.metal(hd, steel, bevel=1.2)
    shield = circle(cx, cy, 0.25)
    p.shadow(shield, 3)
    p.edge(shield, 1.0)
    p.metal(shield, bronze, bevel=2.5)
    face = circle(cx, cy, 0.205)
    p.metal(face, [0.55, 0.14, 0.10], bevel=1.0, spec=0.3)
    # rivets round the rim, a cross band of steel
    band = U(poly([(cx - 0.205, cy - 0.03), (cx + 0.205, cy - 0.03), (cx + 0.205, cy + 0.03), (cx - 0.205, cy + 0.03)]),
             poly([(cx - 0.03, cy - 0.205), (cx + 0.03, cy - 0.205), (cx + 0.03, cy + 0.205), (cx - 0.03, cy + 0.205)])) * face
    p.metal(band, steel, bevel=0.6)
    for i in range(12):
        a = i * math.pi / 6 + math.pi / 12
        p.metal(circle(cx + math.cos(a) * 0.228, cy + math.sin(a) * 0.228, 0.012), steel, bevel=0.4)
    boss = circle(cx, cy, 0.075)
    p.edge(boss, 0.5)
    p.metal(boss, bronze, bevel=1.5)
    p.gem(cx, cy, 0.045, [0.95, 0.20, 0.14])
    p.finish("PanelEmblemWarrior", (cx, cy))


# ---------------------------------------------------------------------------- paladin
def paladin():
    p = Pic()
    gold = [1.0, 0.82, 0.50]
    rose = [0.96, 0.62, 0.78]
    cx, cy = CX, CY
    r = np.sqrt((gx - cx) ** 2 + (gy - cy + 0.04) ** 2)
    ang = np.arctan2(gy - cy + 0.04, gx - cx)
    rays = (np.abs(np.cos(ang * 6)) ** 8) * np.clip(1 - r / 0.36, 0, 1) + np.exp(-(r / 0.20) ** 2) * 0.6
    p.over([1.0, 0.86, 0.62], np.clip(rays, 0, 1) * 0.8)
    sh = poly([(cx - 0.20, cy - 0.27), (cx + 0.20, cy - 0.27), (cx + 0.20, cy + 0.02), (cx, cy + 0.34), (cx - 0.20, cy + 0.02)])
    sh = U(sh, ellipse(cx, cy - 0.27, 0.20, 0.04))
    p.shadow(sh, 3)
    p.edge(sh, 1.0)
    p.metal(sh, gold, bevel=2.5)
    inner = poly([(cx - 0.165, cy - 0.24), (cx + 0.165, cy - 0.24), (cx + 0.165, cy + 0.01), (cx, cy + 0.29), (cx - 0.165, cy + 0.01)])
    p.metal(inner, rose, bevel=1.0, spec=0.4)
    cross = U(poly([(cx - 0.035, cy - 0.21), (cx + 0.035, cy - 0.21), (cx + 0.035, cy + 0.22), (cx - 0.035, cy + 0.22)]),
              poly([(cx - 0.13, cy - 0.09), (cx + 0.13, cy - 0.09), (cx + 0.13, cy - 0.02), (cx - 0.13, cy - 0.02)])) * inner
    p.edge(cross, 0.4)
    p.metal(cross, gold, bevel=0.9)
    p.gem(cx, cy - 0.055, 0.045, [1.0, 0.80, 0.30])
    p.finish("PanelEmblemPaladin", (cx, cy - 0.055))


# ---------------------------------------------------------------------------- hunter
def hunter():
    p = Pic()
    wood = [0.62, 0.46, 0.26]
    green = [0.64, 0.82, 0.42]
    steel = [0.80, 0.80, 0.78]
    cx, cy = CX - 0.06, CY
    # the bow: a recurve arc bowed to the left, its tips curling out
    pts = arc_pts(cx + 0.20, cy, 0.30, 0.36, math.pi * 0.62, math.pi * 1.38)
    tip_t = [(pts[0][0] + 0.05, pts[0][1] + 0.02)]
    tip_b = [(pts[-1][0] + 0.05, pts[-1][1] - 0.02)]
    bow = line(tip_b[::-1] + pts[::-1] + tip_t, 0.04)
    string = line([tip_t[0], (cx + 0.12, cy), tip_b[0]], 0.008)
    arrow_shaft = line([(cx + 0.12, cy), (cx + 0.34, cy)], 0.018)
    arrow_head = poly([(cx + 0.32, cy - 0.05), (cx + 0.42, cy), (cx + 0.32, cy + 0.05), (cx + 0.335, cy)])
    fl = U(poly([(cx + 0.12, cy), (cx + 0.08, cy - 0.05), (cx + 0.17, cy - 0.05), (cx + 0.20, cy)]),
           poly([(cx + 0.12, cy), (cx + 0.08, cy + 0.05), (cx + 0.17, cy + 0.05), (cx + 0.20, cy)]))
    feather = poly([(cx - 0.09, cy + 0.05), (cx - 0.05, cy + 0.10), (cx - 0.07, cy + 0.30), (cx - 0.11, cy + 0.24), (cx - 0.12, cy + 0.10)])
    cord = line([(cx - 0.095, cy + 0.0), (cx - 0.085, cy + 0.07)], 0.008)
    allm = U(bow, string, arrow_shaft, arrow_head, fl, feather)
    p.shadow(allm)
    p.edge(allm, 0.6)
    p.metal(string, [0.85, 0.82, 0.72], bevel=0.3)
    p.metal(bow, wood, bevel=1.0)
    grip = line([(cx - 0.10, cy - 0.06), (cx - 0.10, cy + 0.06)], 0.06)
    p.metal(grip, green, bevel=1.0)
    p.metal(arrow_shaft, [0.70, 0.55, 0.34], bevel=0.5)
    p.metal(fl, green, bevel=0.6)
    p.metal(arrow_head, steel, bevel=0.8)
    p.metal(cord, [0.5, 0.4, 0.3], bevel=0.3)
    p.metal(feather, [0.55, 0.75, 0.35], bevel=1.0)
    vein = line([(cx - 0.09, cy + 0.08), (cx - 0.085, cy + 0.27)], 0.006) * feather
    p.flat(vein, [0.25, 0.35, 0.15])
    p.gem(cx - 0.10, cy, 0.03, [0.45, 0.90, 0.30])
    p.finish("PanelEmblemHunter", (cx - 0.10, cy))


# ---------------------------------------------------------------------------- rogue
def rogue():
    p = Pic()
    steel = [0.82, 0.82, 0.86]
    gold = [0.94, 0.86, 0.40]
    cx, cy = CX, CY + 0.02
    knives = []
    for side in (-1, 1):
        a = side * 0.62
        oy = cy + 0.13  # the daggers cross in the middle of their blades
        blade = poly(rot([(cx - 0.05, oy + 0.08), (cx - 0.04, oy - 0.22), (cx, oy - 0.38), (cx + 0.04, oy - 0.22), (cx + 0.05, oy + 0.08)], a, cx, cy))
        fuller = line(rot([(cx, oy + 0.06), (cx, oy - 0.28)], a, cx, cy), 0.01)
        guard = line(rot([(cx - 0.10, oy + 0.10), (cx - 0.05, oy + 0.085), (cx + 0.05, oy + 0.085), (cx + 0.10, oy + 0.10)], a, cx, cy), 0.03)
        hilt = line(rot([(cx, oy + 0.12), (cx, oy + 0.23)], a, cx, cy), 0.04)
        pommel = circle(*(rot([(cx, oy + 0.255)], a, cx, cy)[0] + (0.032,)))
        knives.append((blade, fuller, guard, hilt, pommel))
    allm = U(*[U(*k) for k in knives])
    p.shadow(allm)
    p.edge(allm, 0.7)
    for blade, fuller, guard, hilt, pommel in knives:
        p.metal(blade, steel, bevel=1.0, spec=0.8)
        p.flat(fuller * blade, [0.45, 0.47, 0.52])
        p.metal(hilt, [0.25, 0.20, 0.16], bevel=0.7)
        p.metal(guard, gold, bevel=0.7)
        p.metal(pommel, gold, bevel=0.7)
    coin = circle(cx, cy, 0.075)
    p.edge(coin, 0.5)
    p.metal(coin, gold, bevel=2.0)
    p.metal(ring(cx, cy, 0.052, 0.058), [0.7, 0.6, 0.25], bevel=0.3)
    p.gem(cx, cy, 0.032, [0.95, 0.85, 0.25])
    drop = U(circle(cx + 0.24, cy - 0.04, 0.035), poly([(cx + 0.208, cy - 0.052), (cx + 0.24, cy - 0.12), (cx + 0.272, cy - 0.052)]))
    p.glow(drop, [0.4, 1.0, 0.3], 3, 0.6)
    p.metal(drop, [0.45, 0.95, 0.35], bevel=0.8, spec=0.9)
    p.finish("PanelEmblemRogue", (cx, cy))


# ---------------------------------------------------------------------------- priest
def priest():
    p = Pic()
    silver = [0.88, 0.90, 0.96]
    gold = [1.0, 0.88, 0.60]
    cx, cy = CX, CY - 0.08
    wings = []
    for side in (-1, 1):
        fe = []
        for i in range(5):
            L = 0.30 - i * 0.04
            a0 = -0.55 + i * 0.30
            base = (cx + side * 0.07, cy + 0.02 + i * 0.025)
            tip = (base[0] + side * math.cos(a0) * L, base[1] + math.sin(a0) * L * 0.9)
            w = 0.035
            fe.append(poly([base, (base[0] + side * 0.02, base[1] - w), tip, (base[0] + side * 0.02, base[1] + w)]))
        wings.append(U(*fe))
    staff = line([(cx, cy + 0.10), (cx, cy + 0.40)], 0.035)
    halo = ring(cx, cy, 0.085, 0.12)
    allm = U(wings[0], wings[1], staff, halo)
    p.glow(circle(cx, cy, 0.16), [1.0, 0.97, 0.85], 8, 0.6)
    p.shadow(allm)
    p.edge(allm, 0.6)
    for w in wings:
        p.metal(w, silver, bevel=0.9, spec=0.7)
    p.metal(staff, gold, bevel=0.8)
    for t in (0.19, 0.28, 0.37):
        p.metal(line([(cx - 0.03, cy + t), (cx + 0.03, cy + t)], 0.018), silver, bevel=0.5)
    p.metal(halo, gold, bevel=1.4)
    star = U(poly([(cx - 0.07, cy), (cx, cy - 0.015), (cx + 0.07, cy), (cx, cy + 0.015)]),
             poly([(cx, cy - 0.07), (cx + 0.015, cy), (cx, cy + 0.07), (cx - 0.015, cy)]))
    p.glow(star, [1.0, 1.0, 0.9], 3, 0.8)
    p.gem(cx, cy, 0.035, [0.92, 0.95, 1.0], glow=False)
    p.flat(star * (1 - circle(cx, cy, 0.03)), [1.0, 1.0, 0.95])
    p.finish("PanelEmblemPriest", (cx, cy))


# ---------------------------------------------------------------------------- shaman
def shaman():
    p = Pic()
    wood = [0.55, 0.40, 0.26]
    blue = [0.35, 0.62, 0.98]
    cx, cy = CX, CY
    # lightning behind
    bolt = line([(cx + 0.24, cy - 0.40), (cx + 0.16, cy - 0.20), (cx + 0.26, cy - 0.16), (cx + 0.14, cy + 0.10)], 0.022)
    p.glow(bolt, [0.4, 0.7, 1.0], 6, 0.9)
    p.flat(bolt, [0.85, 0.95, 1.0])
    blocks = []
    for i, (w, h) in enumerate([(0.13, 0.11), (0.12, 0.11), (0.135, 0.12)]):
        y0 = cy - 0.12 + i * 0.13
        blocks.append((poly([(cx - w, y0), (cx + w, y0), (cx + w * 0.92, y0 + h), (cx - w * 0.92, y0 + h)]), y0, w, h))
    # the thunderbird on top
    head = poly([(cx - 0.06, cy - 0.12), (cx + 0.06, cy - 0.12), (cx + 0.05, cy - 0.20), (cx, cy - 0.24), (cx - 0.05, cy - 0.20)])
    beak = poly([(cx + 0.03, cy - 0.19), (cx + 0.11, cy - 0.17), (cx + 0.03, cy - 0.15)])
    wings = U(poly([(cx - 0.05, cy - 0.14), (cx - 0.30, cy - 0.30), (cx - 0.24, cy - 0.20), (cx - 0.28, cy - 0.18), (cx - 0.20, cy - 0.12), (cx - 0.22, cy - 0.09), (cx - 0.05, cy - 0.10)]),
              poly([(cx + 0.05, cy - 0.14), (cx + 0.30, cy - 0.30), (cx + 0.24, cy - 0.20), (cx + 0.28, cy - 0.18), (cx + 0.20, cy - 0.12), (cx + 0.22, cy - 0.09), (cx + 0.05, cy - 0.10)]))
    allm = U(*([b[0] for b in blocks] + [head, beak, wings]))
    p.shadow(allm)
    p.edge(allm, 0.7)
    p.metal(wings, blue, bevel=1.0)
    for i, (m, y0, w, h) in enumerate(blocks):
        p.metal(m, wood, bevel=1.2)
        # a carved face: brows, eyes, a mouth
        ey = y0 + h * 0.38
        for s in (-1, 1):
            eye = ellipse(cx + s * w * 0.42, ey, w * 0.18, h * 0.11)
            p.flat(eye, [0.08, 0.05, 0.03])
            p.glow(eye, [0.4, 0.75, 1.0], 1.5, 0.5)
            p.metal(line([(cx + s * w * 0.62, ey - h * 0.18), (cx + s * w * 0.18, ey - h * 0.24)], 0.012) * m, blue, bevel=0.3)
        mouth = poly([(cx - w * 0.45, y0 + h * 0.66), (cx + w * 0.45, y0 + h * 0.66), (cx + w * 0.3, y0 + h * 0.86), (cx - w * 0.3, y0 + h * 0.86)])
        p.flat(mouth, [0.10, 0.06, 0.04])
        teeth = U(*[poly([(cx + t * w, y0 + h * 0.66), (cx + (t + 0.12) * w, y0 + h * 0.66), (cx + (t + 0.06) * w, y0 + h * 0.76)]) for t in (-0.36, -0.12, 0.12)])
        p.flat(teeth, [0.88, 0.85, 0.75])
    p.metal(head, blue, bevel=1.0)
    p.metal(beak, [0.95, 0.78, 0.35], bevel=0.6)
    p.gem(cx, cy - 0.185, 0.02, [0.95, 0.95, 1.0], glow=False)
    p.finish("PanelEmblemShaman", (cx, cy - 0.185))


# ---------------------------------------------------------------------------- mage
def mage():
    p = Pic()
    silver = [0.75, 0.86, 0.95]
    gold = [0.95, 0.85, 0.60]
    cx, cy = CX, CY - 0.06
    staff = line([(cx, cy + 0.12), (cx, cy + 0.36)], 0.035)
    claws = U(*[line([(cx + s * 0.03, cy + 0.12), (cx + s * 0.10, cy + 0.05), (cx + s * 0.10, cy - 0.06), (cx + s * 0.05, cy - 0.12)], 0.022) for s in (-1, 1)])
    p.glow(circle(cx, cy - 0.01, 0.13), [0.5, 0.85, 1.0], 9, 0.7)
    # the rune ring: a tilted ellipse round the orb, its back half behind
    rr_out = ellipse(cx, cy, 0.25, 0.08)
    rr = cut(rr_out, ellipse(cx, cy, 0.225, 0.062))
    back = rr * (gy < cy)
    front = rr * (gy >= cy)
    allm = U(staff, claws, rr)
    p.shadow(allm)
    p.edge(back, 0.4)
    p.metal(back, gold, bevel=0.5)
    p.edge(U(staff, claws), 0.6)
    p.metal(staff, silver, bevel=0.8)
    orb = circle(cx, cy - 0.01, 0.085)
    dx, dy = gx - cx, gy - (cy - 0.01)
    oc = np.dstack([0.35 + 0.0 * gx, 0.75 + 0.0 * gx, 1.0 + 0.0 * gx])
    inner = np.exp(-((dx + 0.02) ** 2 + (dy + 0.02) ** 2) / 0.0025)
    oc = oc * (0.55 + 0.45 * inner[..., None]) + inner[..., None] * 0.5
    p.edge(orb, 0.5)
    p.over(np.clip(oc, 0, 1), orb)
    p.flat(circle(cx - 0.03, cy - 0.045, 0.018), [1, 1, 1])
    p.metal(claws, silver, bevel=0.8)
    p.edge(front, 0.4)
    p.metal(front, gold, bevel=0.5)
    for i in range(10):
        a = i * math.pi / 5 + 0.2
        x, y = cx + math.cos(a) * 0.237, cy + math.sin(a) * 0.071
        if y >= cy:
            p.flat(poly([(x - 0.008, y), (x, y - 0.008), (x + 0.008, y), (x, y + 0.008)]), [0.4, 0.9, 1.0])
    for (x, y, s) in ((cx + 0.20, cy - 0.20, 0.035), (cx - 0.19, cy - 0.16, 0.025), (cx + 0.15, cy + 0.15, 0.022), (cx - 0.12, cy - 0.30, 0.02)):
        sparkle(p, x, y, s, [0.5, 0.85, 1.0])
    p.finish("PanelEmblemMage", (cx, cy - 0.01))


# ---------------------------------------------------------------------------- warlock
def warlock():
    p = Pic()
    bone = [0.88, 0.84, 0.92]
    horn = [0.42, 0.32, 0.55]
    fel = [0.45, 1.0, 0.25]
    cx, cy = CX, CY - 0.02
    # the violet flame behind
    r = np.sqrt(((gx - cx) / 0.9) ** 2 + ((gy - cy - 0.05) / 1.25) ** 2)
    ang = np.arctan2(gy - cy, gx - cx)
    edge = 0.21 + 0.06 * np.abs(np.sin(ang * 5 + 0.4)) ** 2 + np.clip(-np.sin(ang), 0, 1) * 0.10
    flame = np.clip(1 - r / edge, 0, 1)
    fc = np.dstack([0.45 + 0.4 * flame, 0.15 + 0.35 * flame ** 2, 0.75 + 0.25 * flame])
    p.over(np.clip(fc, 0, 1), np.clip(flame * 2.2, 0, 1) * 0.9)
    skull = U(ellipse(cx, cy - 0.02, 0.13, 0.12), poly([(cx - 0.09, cy + 0.04), (cx + 0.09, cy + 0.04), (cx + 0.06, cy + 0.14), (cx - 0.06, cy + 0.14)]))
    horns = U(line(arc_pts(cx - 0.20, cy - 0.10, 0.11, 0.12, -0.2, -2.2, 24)[::-1], 0.035) * 0 + poly(arc_pts(cx - 0.19, cy - 0.04, 0.14, 0.20, -0.2, -2.1, 24) + arc_pts(cx - 0.21, cy - 0.06, 0.07, 0.10, -2.1, -0.5, 24)),
              poly(arc_pts(cx + 0.19, cy - 0.04, 0.14, 0.20, math.pi + 0.2, math.pi + 2.1, 24) + arc_pts(cx + 0.21, cy - 0.06, 0.07, 0.10, math.pi + 2.1, math.pi + 0.5, 24)))
    allm = U(skull, horns)
    p.shadow(allm)
    p.edge(allm, 0.7)
    p.metal(horns, horn, bevel=1.2, spec=0.6)
    p.metal(skull, bone, bevel=2.2)
    for s in (-1, 1):
        sock = ellipse(cx + s * 0.05, cy - 0.01, 0.038, 0.032)
        p.flat(sock, [0.05, 0.02, 0.06])
        p.glow(circle(cx + s * 0.05, cy - 0.01, 0.02), fel, 3, 0.9)
        p.flat(circle(cx + s * 0.05, cy - 0.01, 0.012), [0.85, 1.0, 0.7])
    nose = poly([(cx, cy + 0.03), (cx - 0.018, cy + 0.07), (cx + 0.018, cy + 0.07)])
    p.flat(nose, [0.08, 0.04, 0.08])
    for t in range(-2, 3):
        p.flat(poly([(cx + t * 0.022 - 0.006, cy + 0.10), (cx + t * 0.022 + 0.006, cy + 0.10), (cx + t * 0.022 + 0.004, cy + 0.135), (cx + t * 0.022 - 0.004, cy + 0.135)]), [0.12, 0.08, 0.12])
    p.gem(cx, cy - 0.10, 0.022, [0.70, 0.35, 1.0])
    p.finish("PanelEmblemWarlock", (cx, cy - 0.10))


# ---------------------------------------------------------------------------- druid
def druid():
    p = Pic()
    wood = [0.62, 0.44, 0.24]
    orange = [1.0, 0.62, 0.20]
    leafc = [0.55, 0.78, 0.30]
    cx, cy = CX, CY
    moon = cut(circle(cx, cy - 0.02, 0.17), circle(cx + 0.08, cy - 0.06, 0.15))
    antlers = []
    for s in (-1, 1):
        main = line([(cx + s * 0.06, cy + 0.12), (cx + s * 0.15, cy + 0.02), (cx + s * 0.22, cy - 0.12), (cx + s * 0.24, cy - 0.30)], 0.03)
        t1 = line([(cx + s * 0.15, cy + 0.02), (cx + s * 0.30, cy - 0.02)], 0.022)
        t2 = line([(cx + s * 0.21, cy - 0.10), (cx + s * 0.33, cy - 0.18)], 0.02)
        t3 = line([(cx + s * 0.23, cy - 0.22), (cx + s * 0.16, cy - 0.33)], 0.018)
        antlers.append(U(main, t1, t2, t3))
    leaves = []
    for (x, y, a, s) in ((cx - 0.10, cy + 0.16, 2.6, 0.07), (cx + 0.10, cy + 0.16, 0.5, 0.07), (cx, cy + 0.20, 1.57, 0.08), (cx - 0.17, cy + 0.10, 2.9, 0.055), (cx + 0.17, cy + 0.10, 0.25, 0.055)):
        tip = (x + math.cos(a) * s, y + math.sin(a) * s)
        back = (x - math.cos(a) * s * 0.4, y - math.sin(a) * s * 0.4)
        n = (-math.sin(a) * s * 0.42, math.cos(a) * s * 0.42)
        leaves.append(poly([back, (x + n[0], y + n[1]), tip, (x - n[0], y - n[1])]))
    medal = circle(cx, cy + 0.12, 0.06)
    allm = U(moon, antlers[0], antlers[1], medal, *leaves)
    p.shadow(allm)
    p.edge(allm, 0.7)
    for a in antlers:
        p.metal(a, wood, bevel=1.0)
    p.glow(moon, [1.0, 0.75, 0.40], 5, 0.5)
    p.metal(moon, orange, bevel=1.6, spec=0.7)
    for l in leaves:
        p.metal(l, leafc, bevel=0.8)
    p.metal(medal, wood, bevel=1.4)
    p.gem(cx, cy + 0.12, 0.035, [1.0, 0.60, 0.12])
    p.finish("PanelEmblemDruid", (cx, cy + 0.12))


warrior()
paladin()
hunter()
rogue()
priest()
shaman()
mage()
warlock()
druid()
print("wrote", OUT_BLP)
