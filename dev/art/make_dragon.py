#!/usr/bin/env python3
"""Creed UI's panel dragon (original): a heavy dragon sitting on its haunches, facing out, its folded
wing raised behind it and laid over the panel's end so dragon and frame meet with no gap. Painted
from shapes: each part a rounded relief with its own scales or plates, lit from the top left, with
contact shadows where parts overlap and a dark line round each. Grey; tinted the panel's gold in
game. 256x256, shown 128 across: the panel's left edge falls at x 216, its foot at y 248."""
import os, struct, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
N, SS = 256, 4
G = N * SS
ys, xs = np.mgrid[0:G, 0:G].astype(np.float32)
X, Y = (xs + 0.5) / SS, (ys + 0.5) / SS          # canvas px
LIGHT = np.array([-0.55, -0.65, 0.52]); LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1.0]); HALF /= np.linalg.norm(HALF)


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


# ------------------------------------------------------------------ shapes (masks at SS)
def poly(points):
    im = Image.new("L", (G, G), 0)
    ImageDraw.Draw(im).polygon([(x * SS, y * SS) for x, y in points], fill=255)
    return np.asarray(im, dtype=np.float32) / 255.0


def ellipse(cx, cy, rx, ry, ang=0.0):
    a = np.radians(ang)
    u = (X - cx) * np.cos(a) + (Y - cy) * np.sin(a)
    v = -(X - cx) * np.sin(a) + (Y - cy) * np.cos(a)
    return ((u / rx) ** 2 + (v / ry) ** 2 <= 1).astype(np.float32)


def bez(p, n=48):
    p = np.array(p, dtype=float)
    t = np.linspace(0, 1, n)[:, None]
    if len(p) == 2:
        return (1 - t) * p[0] + t * p[1]
    if len(p) == 3:
        return (1 - t) ** 2 * p[0] + 2 * (1 - t) * t * p[1] + t ** 2 * p[2]
    return (1 - t) ** 3 * p[0] + 3 * (1 - t) ** 2 * t * p[1] + 3 * (1 - t) * t ** 2 * p[2] + t ** 3 * p[3]


def tube(pts, r0, r1, power=1.0):
    """a tapering tube along points: union of round cones, drawn as discs and hull quads"""
    im = Image.new("L", (G, G), 0)
    d = ImageDraw.Draw(im)
    n = len(pts)
    rs = [r0 + (r1 - r0) * (i / (n - 1)) ** power for i in range(n)]
    for i in range(n):
        x, y = pts[i]
        r = rs[i]
        d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=255)
        if i:
            x0, y0 = pts[i - 1]; r0_ = rs[i - 1]
            dx, dy = x - x0, y - y0
            L = max(np.hypot(dx, dy), 1e-6)
            nx, ny = -dy / L, dx / L
            d.polygon([((x0 + nx * r0_) * SS, (y0 + ny * r0_) * SS), ((x + nx * r) * SS, (y + ny * r) * SS),
                       ((x - nx * r) * SS, (y - ny * r) * SS), ((x0 - nx * r0_) * SS, (y0 - ny * r0_) * SS)], fill=255)
    return np.asarray(im, dtype=np.float32) / 255.0


def soft(m, px):
    return ndimage.gaussian_filter(m, px * SS)


# ------------------------------------------------------------------ relief and light
def dome(mask, R):
    """a rounded edge of radius R canvas px, flat beyond"""
    d = ndimage.distance_transform_edt(mask > 0.5).astype(np.float32) / SS
    t = np.clip(d / R, 0, 1)
    return R * np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)), d


def scales(size, squash=0.78, ang=0.0):
    a = np.radians(ang)
    u = (X * np.cos(a) + Y * np.sin(a)) / size
    v = (-X * np.sin(a) + Y * np.cos(a)) / (size * squash)
    row = np.floor(v)
    u = u + 0.5 * (np.mod(row, 2))
    fu, fv = u - np.floor(u) - 0.5, v - row
    # each scale a rounded tongue, its free edge low (overlapping the next row)
    r = np.hypot(fu * 1.15, (fv - 0.15) * 1.0)
    return np.clip(1 - r * 1.55, 0, 1) ** 0.7


def shade(h, d, amb=0.17, dif=0.78, spec=0.55, power=22, line=1.0, value=1.0):
    gy, gx = np.gradient(h * SS)
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    diff = np.clip(n @ LIGHT, 0, 1)
    sp = np.clip(n @ HALF, 0, 1) ** power
    g = (amb + dif * diff) * value + spec * sp
    # a dark line round the part, as an engraver's
    g = g * (1 - 0.85 * np.exp(-(d / (0.75 * line)) ** 2))
    return g


canvas = np.zeros((G, G), np.float32)
alpha = np.zeros((G, G), np.float32)


def put(mask, g, shadow=0.55, reach=2.2):
    """lay a part over what's there: its shadow first (down right), then the part"""
    global canvas, alpha
    sh = soft(np.roll(np.roll(mask, int(1.6 * SS), axis=0), int(1.0 * SS), axis=1), reach)
    canvas = canvas * (1 - shadow * np.clip(sh * 1.6, 0, 1) * (1 - mask))
    a = mask
    na = a + alpha * (1 - a)
    with np.errstate(invalid="ignore", divide="ignore"):
        canvas = np.where(na > 1e-6, (g * a + canvas * alpha * (1 - a)) / na, 0)
    alpha = na


def part(mask, R, tex=None, texk=0.0, **kw):
    h, d = dome(mask, R)
    if tex is not None:
        h = h + texk * tex * np.clip(d / 2.0, 0, 1)
    return shade(h, d, **kw)


# ------------------------------------------------------------------ the dragon
SC = scales(5.2)
SB = scales(7.5, 0.72, 10)

# the wings, folded and raised, bat-like: an arm up to a high wrist with a hooked thumb, four long
# finger bones fanning down to the panel's end, the membrane sagging between them with folds
# radiating from the wrist and its trailing edge scalloped. The far wing peeks behind, darker.
def wing(shoulder, elbow, wrist, tips, body, value, far=False, bends=None):
    # the membrane: arm, wrist, then round the finger tips with an inward scallop between each
    out = [shoulder, elbow, wrist]
    prev = wrist
    for k, tip in enumerate(tips):
        if k:
            mx, my = (prev[0] + tip[0]) / 2, (prev[1] + tip[1]) / 2
            vx, vy = mx - wrist[0], my - wrist[1]
            L = np.hypot(vx, vy)
            depth = 0.16 * np.hypot(tip[0] - prev[0], tip[1] - prev[1])
            for t in (0.25, 0.5, 0.75):   # the scallop: an arc bowing toward the wrist
                bx = prev[0] + (tip[0] - prev[0]) * t
                by = prev[1] + (tip[1] - prev[1]) * t
                dd = depth * np.sin(np.pi * t)
                out.append((bx - vx / L * dd, by - vy / L * dd))
        out.append(tip)
        prev = tip
    out += body
    membrane = poly(out)
    # the bones: the finger bones bowing outward a little, each with a knuckle
    bones = np.zeros_like(X)
    for k, tip in enumerate(tips):
        mid = bends[k] if bends and bends[k] else ((wrist[0] + tip[0]) / 2 + (tip[1] - wrist[1]) * 0.06, (wrist[1] + tip[1]) / 2 - (tip[0] - wrist[0]) * 0.06)
        pts = list(bez([wrist, mid, tip], 28))
        bones = np.maximum(bones, tube(pts, 4.2, 1.6, power=0.9))
        kx, ky = pts[12]
        bones = np.maximum(bones, ellipse(kx, ky, 3.6, 3.6))
    # the membrane sags away from the bones; folds run out from the wrist; its edge is a lip
    dist_b = ndimage.distance_transform_edt(bones < 0.5).astype(np.float32) / SS
    mh, md = dome(membrane, 2.5)
    sag = -2.6 * np.clip(dist_b / 11.0, 0, 1) ** 0.8
    ang = np.arctan2(Y - wrist[1], X - wrist[0])
    rad = np.hypot(X - wrist[0], Y - wrist[1])
    folds = 0.5 * np.sin(ang * 24) * np.clip(rad / 50, 0, 1)
    g = shade(mh + sag + folds, md, value=value * 0.56, spec=0.18, power=10, line=0.9)
    g = g * (0.82 + 0.18 * np.clip(1 - rad / 220, 0, 1))  # darker toward the trailing edge
    lip = np.exp(-(md / 0.9) ** 2) * membrane
    g = g + 0.18 * lip * value
    put(membrane, g, shadow=0.0 if far else 0.35, reach=2.0)
    bh, bd = dome(bones, 3.0)
    put(bones, shade(bh + 0.6, bd, value=value * 1.08, spec=0.65), shadow=0.35, reach=0.9)
    # a claw at each finger's end, past the membrane
    for k, tip in enumerate(tips):
        frm = bends[k] if bends and bends[k] else wrist
        vx, vy = tip[0] - frm[0], tip[1] - frm[1]
        L = np.hypot(vx, vy)
        c = tube([tip, (tip[0] + vx / L * 7, tip[1] + vy / L * 7)], 2.2, 0.4)
        put(c, part(c, 1.2, value=value * 1.1, line=0.6), shadow=0.3, reach=0.8)
    # the arm: upper arm to the elbow, forearm to the wrist, knuckles at both
    arm = np.maximum(tube(list(bez([shoulder, elbow], 10)), 10.0, 7.5), tube(list(bez([elbow, wrist], 14)), 7.5, 5.5))
    arm = np.maximum(arm, np.maximum(ellipse(elbow[0], elbow[1], 8.5, 8.5), ellipse(wrist[0], wrist[1], 7.0, 7.0)))
    put(arm, part(arm, 5.5, SC, 0.7, value=value), shadow=0.45)
    # the thumb: a hooked claw off the wrist, forward
    if not far:
        th = tube(list(bez([wrist, (wrist[0] - 5, wrist[1] - 9), (wrist[0] - 14, wrist[1] - 10)], 14)), 4.2, 0.6)
        put(th, part(th, 2.0, value=value * 1.12), shadow=0.35, reach=1.0)


# the far wing first, behind and a little higher, mostly hidden
wing((174, 104), (160, 60), (174, 13), [(206, 34), (222, 72), (226, 110)], [(200, 124), (180, 120)], value=0.6, far=True)

# the tail: from behind the haunch round the front along the ground, its tip curling up
tailpts = list(bez([(228, 232), (170, 243), (96, 241), (50, 228)], 40)) + list(bez([(50, 228), (31, 219), (30, 204)], 14))[1:]
tail = tube(tailpts, 11.5, 5.0, power=0.8)
put(tail, part(tail, 7.0, SC, 1.0), shadow=0.4)
spade = poly([(30, 174), (40, 188), (45, 202), (38, 208), (30, 202), (22, 208), (15, 202), (20, 188)])  # a spade, its point up
put(spade, part(spade, 4.0), shadow=0.4)

# the haunch, big and round, and the hind foot flat on the ground, toes forward
haunch = ellipse(180, 196, 46, 42, -20)
put(haunch, part(haunch, 26.0, SB, 0.9), shadow=0.5)
# the body: a deep chest leaning back over the haunch
torso = ellipse(146, 150, 44, 60, 12)
put(torso, part(torso, 28.0, SB, 0.9), shadow=0.5)

# the near wing, folded round the dragon like a cloak: over the panel's end rail from its top,
# its lower fingers sweeping down and forward round the haunch; the hind foot steps out over it
wing((166, 112), (188, 68), (214, 15), [(245, 58), (245, 124), (236, 196), (178, 234)],
     [(162, 204), (160, 160), (164, 124)], value=1.0, bends=[None, None, (252, 120), (248, 192)])
foot = tube(list(bez([(176, 224), (150, 235), (118, 239)], 20)), 11.0, 7.5)
put(foot, part(foot, 6.0, SC, 0.8), shadow=0.5)
for i, (x0, y0) in enumerate([(116, 233), (112, 239), (114, 244)]):
    c = tube(list(bez([(x0 + 4, y0), (x0 - 6, y0 - 1), (x0 - 12, y0 + 4)], 10)), 3.0, 0.5)
    put(c, part(c, 1.6, value=1.15), shadow=0.35, reach=1.0)


# the neck: thick, curving up and out to the head, with spines along its back
neckpts = list(bez([(150, 124), (140, 84), (110, 64), (86, 52)], 36))
spines = np.zeros_like(X)
for i in range(3, 33, 4):
    x, y = neckpts[i]
    x2, y2 = neckpts[min(i + 2, len(neckpts) - 1)]
    dx, dy = x2 - x, y2 - y
    L = np.hypot(dx, dy); nx, ny = -dy / L, dx / L      # outward: the neck's back (up right)
    r = 24 - 9 * i / 36
    bx, by = x + nx * r * 0.82, y + ny * r * 0.82
    k = 13 - 4 * i / 36
    spines = np.maximum(spines, poly([(bx - dx / L * 6, by - dy / L * 6), (bx + nx * k - dx / L * 4, by + ny * k - dy / L * 4), (bx + dx / L * 5, by + dy / L * 5)]))
put(spines, part(spines, 2.0, value=1.05), shadow=0.35, reach=1.2)
neck = tube(neckpts, 25.0, 15.0)
put(neck, part(neck, 13.0, SC, 1.0), shadow=0.5)

# the belly plates, from under the jaw down the front of the neck and chest
bellypts = list(bez([(78, 66), (104, 98), (110, 150), (138, 202)], 40))
belly = tube(bellypts, 8.0, 15.0) * np.clip(neck + torso, 0, 1)
bh, bd = dome(belly, 6.0)
plates = np.mod((Y + 0.45 * X) / 7.0, 1.0)
groove = np.exp(-((plates - 0.5) / 0.09) ** 2)
put(belly, shade(bh - 1.4 * groove, bd, value=1.12, spec=0.65), shadow=0.25, reach=1.0)

# the foreleg, planted in front: a big shoulder, the forearm down to a clawed paw
upper = tube(list(bez([(138, 138), (126, 168), (118, 190)], 20)), 19.0, 12.0)
put(upper, part(upper, 11.0, SC, 1.0), shadow=0.55)
fore = tube(list(bez([(118, 188), (110, 214), (104, 236)], 20)), 11.0, 9.0)
put(fore, part(fore, 7.0, SC, 0.9), shadow=0.5)
paw = ellipse(96, 238, 15, 9, -8)
put(paw, part(paw, 6.0, SC, 0.6), shadow=0.5)
for x0, y0 in [(86, 234), (82, 240), (86, 245)]:
    c = tube(list(bez([(x0 + 4, y0), (x0 - 6, y0 - 1), (x0 - 11, y0 + 4)], 10)), 3.0, 0.5)
    put(c, part(c, 1.6, value=1.15), shadow=0.35, reach=1.0)

# the head, facing out: a heavy skull, the snout long, the jaw open on its teeth
skull = ellipse(86, 46, 27, 21, -8)
snout = tube(list(bez([(80, 46), (52, 50), (24, 56)], 20)), 16.0, 10.0)
jaw = tube(list(bez([(86, 60), (60, 68), (34, 74)], 20)), 10.0, 5.0)
mouth = poly([(28, 64), (78, 58), (60, 66), (32, 70)])
put(jaw, part(jaw, 5.0, SC, 0.5), shadow=0.4)
put(mouth * (1 - jaw) * 0 + mouth, np.full_like(X, 0.05), shadow=0.0)
teeth = np.zeros_like(X)
for x0 in range(34, 72, 7):
    teeth = np.maximum(teeth, poly([(x0, 61 - (x0 - 30) * 0.08), (x0 + 3, 67), (x0 + 6, 60 - (x0 - 30) * 0.08)]))
    teeth = np.maximum(teeth, poly([(x0 + 2, 70 - (x0 - 30) * 0.06), (x0 + 5, 64.5), (x0 + 8, 69.5 - (x0 - 30) * 0.06)]))
put(teeth, part(teeth, 1.0, value=1.25, line=0.6), shadow=0.2, reach=0.8)
head = np.clip(skull + snout, 0, 1)
put(head, part(head, 10.0, SC, 0.7), shadow=0.5)
# a brow ridge over the eye, the nostril, the cheek's spike
brow = tube(list(bez([(58, 38), (68, 33), (80, 34)], 12)), 4.5, 3.0)
put(brow, part(brow, 3.0, value=1.1), shadow=0.45, reach=1.0)
nostril = ellipse(32, 50, 3.0, 2.0, -10)
put(nostril, np.full_like(X, 0.08), shadow=0.0)
eye = ellipse(68, 43, 5.0, 3.6, -10)
put(eye, np.full_like(X, 0.06), shadow=0.0)
cheek = poly([(96, 56), (124, 66), (100, 46)])
put(cheek, part(cheek, 2.5, value=1.0), shadow=0.4, reach=1.0)

# the horns, swept back: a long pair and a shorter one under it
for pts, r0 in (([(96, 36), (118, 14), (156, 8)], 9.0), ([(106, 48), (132, 50), (154, 40)], 6.5)):
    hpts = list(bez(pts, 24))
    horn = tube(hpts, r0, 1.0, power=1.8)  # thick most of the way, then to a point
    hh, hd = dome(horn, r0 * 0.8)
    far = np.clip((np.hypot(X - pts[0][0], Y - pts[0][1]) - r0 * 1.2) / 6, 0, 1)
    rings = np.sin(np.hypot(X - pts[0][0], Y - pts[0][1]) * 1.1) * 0.25 * far
    put(horn, shade(hh + rings * np.clip(hd / 1.5, 0, 1), hd, value=1.08), shadow=0.45, reach=1.2)

# ------------------------------------------------------------------ out
def down(a):
    return a.reshape(N, SS, N, SS).mean(axis=(1, 3))

pa, a = down(canvas * alpha), down(alpha)
with np.errstate(invalid="ignore", divide="ignore"):
    c = np.where(a > 1e-6, pa / a, 0)
c = np.clip(c, 0, 1)
write_blp("PanelDragon", np.dstack([c, c, c, np.clip(a, 0, 1)]))
print("eye at", 68 / 256, 43 / 256)
