#!/usr/bin/env python3
"""Creed UI's face for Russian, Polish and Turkish: Lora (SIL OFL 1.1) at semibold, its Latin,
Latin Extended-A and Cyrillic letters, renamed (Lora is a Reserved Font Name).
usage: build_latin.py <out.ttf>"""
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

OUT = sys.argv[1]
font = TTFont(os.environ.get("LORA_VARIABLE", "/usr/share/fonts/truetype/google-fonts/Lora-Variable.ttf"))
font = instancer.instantiateVariableFont(font, {"wght": 620})
chars = set()
for lo, hi in ((0x20, 0x7E), (0xA0, 0x17F), (0x400, 0x45F), (0x2010, 0x2027), (0x2030, 0x203A), (0x2116, 0x2116),
               (0x2122, 0x2122), (0x2190, 0x2193)):
    chars.update(range(lo, hi + 1))
opts = subset.Options()
opts.layout_features = ["kern", "liga"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
sub = subset.Subsetter(opts)
sub.populate(unicodes=sorted(chars))
sub.subset(font)
NAME = "Creed UI Letters"
name = font["name"]
for rec in list(name.names):
    if rec.nameID in (1, 3, 4, 6, 16, 17, 21, 22, 25):
        name.removeNames(nameID=rec.nameID)
for nid, val in ((1, NAME), (2, "Regular"), (3, NAME + "; subset of Lora SemiBold"), (4, NAME), (6, "CreedUILetters")):
    name.setName(val, nid, 3, 1, 0x409)
    name.setName(val, nid, 1, 0, 0)
for t in ("STAT", "fvar", "gvar", "avar", "HVAR", "MVAR"):
    if t in font:
        del font[t]
font.save(OUT)
print(len(font.getGlyphOrder()), "glyphs,", os.path.getsize(OUT) // 1024, "KB")
