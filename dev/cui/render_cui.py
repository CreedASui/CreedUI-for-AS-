#!/usr/bin/env python3
"""Render a Creed UI mock dump (M.Dump) to a picture. Put a 1920x1080 game screenshot at
dev/cui/shot.png (or name one in CREEDUI_SHOT) to draw over it, its old HUD painted out and its
action bar icons standing in for the game's; without one, a plain dark backdrop and placeholder icons.

usage: render_cui.py dump.txt out.png [scale] [crop l b r t]"""
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "bt"))
import render_bt  # noqa: E402

SHOT = os.environ.get("CREEDUI_SHOT", os.path.join(HERE, "shot.png"))
shot = Image.open(SHOT).convert("RGB") if os.path.exists(SHOT) else None


def swirl(color):
    s = 64
    yy, xx = np.mgrid[0:s, 0:s] / (s - 1.0) * 2 - 1
    r = np.hypot(xx, yy)
    ang = np.arctan2(yy, xx)
    v = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(ang * 3 + r * 9)) * np.clip(1.2 - r, 0, 1)
    c = np.array(color)[None, None, :] * v[..., None]
    return np.dstack([np.clip(c, 0, 1), np.ones((s, s))]).astype(np.float32)


def crop_icon(box, inset=3):
    if shot is None:
        return swirl((0.55, 0.5, 0.45))
    l, t, r, b = box
    im = shot.crop((l + inset, t + inset, r - inset, b - inset)).resize((64, 64), Image.LANCZOS)
    arr = np.asarray(im, dtype=np.float32) / 255.0
    return np.dstack([arr, np.ones(arr.shape[:2], dtype=np.float32)])


def round_crop(box, size=64):
    l, t, r, b = box
    im = shot.crop(box).resize((size, size), Image.LANCZOS)
    arr = np.asarray(im, dtype=np.float32) / 255.0
    yy, xx = np.mgrid[0:size, 0:size]
    rr = np.hypot(xx - size / 2 + 0.5, yy - size / 2 + 0.5) / (size / 2)
    a = np.clip((1 - rr) * 12, 0, 1)
    return np.dstack([arr, a.astype(np.float32)])


ICONS = {
    "Spell_Shadow_RitualOfSacrifice": crop_icon((715, 1022, 757, 1065)),
    "Ability_Warrior_PunishingBlow": crop_icon((766, 1022, 809, 1065)),
    "Ability_BackStab": crop_icon((818, 1022, 860, 1065)),
    "Ability_Warrior_Challange": crop_icon((869, 1022, 912, 1065)),
    "Ability_Ambush": crop_icon((1057, 1020, 1102, 1066)),
    "INV_Jewelry_Necklace_07": crop_icon((1127, 1026, 1155, 1060), 2),
    "INV_Jewelry_Ring_03": crop_icon((1160, 1026, 1187, 1060), 2),
    "Spell_Shadow_AbominationExplosion": swirl((0.62, 0.30, 0.95)),
}
def face(c1, c2):
    s = 64
    yy, xx = np.mgrid[0:s, 0:s] / (s - 1.0) * 2 - 1
    r = np.hypot(xx, yy * 1.05 + 0.1)
    head = np.clip((0.62 - np.hypot(xx * 1.15, yy + 0.18)) * 9, 0, 1)
    body = np.clip((0.95 - np.hypot(xx * 0.8, (yy - 0.95) * 1.2)) * 6, 0, 1)
    sil = np.maximum(head, body)
    bg = np.array(c1)[None, None, :] * (1 - 0.6 * r[..., None])
    fg = np.array(c2)[None, None, :] * (0.7 + 0.3 * (-yy[..., None]))
    col = bg * (1 - sil[..., None]) + fg * sil[..., None]
    a = np.clip((1 - np.hypot(xx, yy)) * 14, 0, 1)
    return np.dstack([np.clip(col, 0, 1), a]).astype(np.float32)


PORTRAITS = {
    "player": face((0.10, 0.30, 0.28), (0.55, 0.85, 0.45)),
    "target": face((0.25, 0.06, 0.08), (0.62, 0.70, 0.55)),
}

base_load = render_bt.load_tex


def load_tex(path):
    if path in render_bt._tex_cache:
        return render_bt._tex_cache[path]
    name = path.split("\\")[-1]
    if path.startswith("Portrait:"):
        arr = PORTRAITS.get(path.split(":")[1], PORTRAITS["target"])
    elif name in ICONS:
        arr = ICONS[name]
    elif "Paperdoll" in path:
        arr = np.zeros((32, 32, 4), dtype=np.float32)
        arr[..., :3] = 0.35
        arr[..., 3] = 0.6
    elif "Icons" in path:
        arr = swirl((0.6, 0.6, 0.6))
    else:
        return base_load(path)
    render_bt._tex_cache[path] = arr
    return arr


render_bt.load_tex = load_tex


def background(W, H, path):
    if os.path.exists(path):
        return path
    if shot is None:
        y = np.linspace(0, 1, H)[:, None, None]
        im = (np.array([0.10, 0.12, 0.16]) * (1 - 0.5 * y) * np.ones((H, W, 3)) * 255).astype(np.uint8)
        Image.fromarray(im, "RGB").save(path)
        return path
    img = cv2.imread(SHOT)
    mask = np.zeros(img.shape[:2], np.uint8)
    for (l, t, r, b) in [(8, 8, 272, 106), (588, 8, 1322, 104), (870, 372, 1090, 664), (572, 968, 1264, 1071)]:
        mask[t:b, l:r] = 255
    clean = cv2.inpaint(img, mask, 9, cv2.INPAINT_TELEA)
    clean = cv2.cvtColor(clean, cv2.COLOR_BGR2RGB)
    im = Image.fromarray(clean).resize((W, H), Image.LANCZOS)
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    im.save(path)
    return path


if __name__ == "__main__":
    dump, out = sys.argv[1], sys.argv[2]
    S = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5
    crop = tuple(float(x) for x in sys.argv[4:8]) if len(sys.argv) > 7 else (0, 0, 1280, 720)
    W, H = int(1280 * S), int(720 * S)
    bg_full = background(W, H, os.path.join(HERE, f"bg_{W}.png"))
    if crop != (0, 0, 1280, 720):
        l, b, r, t = crop
        im = Image.open(bg_full).crop((int(l * S), int((720 - t) * S), int(r * S), int((720 - b) * S)))
        bg_crop = os.path.join(HERE, "bg_crop.png")
        im.save(bg_crop)
        render_bt.render(dump, out, crop, S, bg_crop)
    else:
        render_bt.render(dump, out, crop, S, bg_full)
    print(out)
