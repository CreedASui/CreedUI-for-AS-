#!/usr/bin/env python3
"""Creed UI's face for the languages Friz Quadrata has no letters for: a subset of Noto Sans CJK
(SIL OFL 1.1), renamed, with TrueType outlines (the client measures off glyf).
usage: build_font.py <out.ttf> <set: words|common|wide> <locale files...>"""
import os
import re
import sys

from fontTools import subset
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTCollection, newTable

OUT, WHICH, FILES = sys.argv[1], sys.argv[2], sys.argv[3:]
SRC = os.environ.get("NOTO_CJK", "/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc")

chars = set()
for lo, hi in ((0x20, 0x7E), (0xA0, 0x17F), (0x400, 0x45F), (0x2010, 0x2027), (0x2030, 0x203A), (0x2190, 0x2193),
               (0x3000, 0x303F), (0x3040, 0x30FF), (0xFF01, 0xFF5E), (0x2116, 0x2116), (0x2122, 0x2122)):
    chars.update(range(lo, hi + 1))
for f in FILES:  # every letter the translations use
    for s in re.findall(r'"((?:[^"\\]|\\.)*)"', open(f, encoding="utf-8").read()):
        chars.update(ord(c) for c in s)


def codec_range(codec, b1s, b2s):
    out = set()
    for b1 in b1s:
        for b2 in b2s:
            try:
                out.update(ord(c) for c in bytes([b1, b2]).decode(codec))
            except UnicodeDecodeError:
                pass
    return out


if WHICH in ("common", "wide"):
    chars |= codec_range("gb2312", range(0xB0, 0xD8), range(0xA1, 0xFF))  # GB2312 level 1: the 3755 common hanzi
    chars |= codec_range("euc_kr", range(0xB0, 0xC9), range(0xA1, 0xFF))  # KS X 1001: the 2350 Hangul syllables
if WHICH == "wide":
    chars |= codec_range("shift_jis", range(0x88, 0x99), list(range(0x40, 0x7F)) + list(range(0x80, 0xFD)))  # JIS level 1 kanji

font = TTCollection(SRC).fonts[2]  # Noto Sans CJK SC
opts = subset.Options()
opts.layout_features = ["kern", "palt", "vert"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
opts.drop_tables += ["VORG", "vhea", "vmtx", "GPOS", "GSUB", "BASE", "DSIG"]
sub = subset.Subsetter(opts)
sub.populate(unicodes=sorted(chars))
sub.subset(font)

# CFF outlines to TrueType quadratics
glyphset = font.getGlyphSet()
order = font.getGlyphOrder()
glyf = newTable("glyf")
glyf.glyphOrder = order
glyf.glyphs = {}
for name in order:
    pen = TTGlyphPen(glyphset)
    glyphset[name].draw(Cu2QuPen(pen, max_err=1.0, reverse_direction=True))
    glyf.glyphs[name] = pen.glyph()
font["glyf"] = glyf
font["loca"] = newTable("loca")
del font["CFF "]
font["maxp"].tableVersion = 0x00010000
for attr in ("maxZones", "maxTwilightPoints", "maxStorage", "maxFunctionDefs", "maxInstructionDefs", "maxStackElements",
             "maxSizeOfInstructions", "maxComponentElements"):
    setattr(font["maxp"], attr, 0)
font["maxp"].maxZones = 1
font["head"].indexToLocFormat = 0
font["head"].glyphDataFormat = 0
font["post"].formatType = 3.0
font.sfntVersion = "\x00\x01\x00\x00"
if "hhea" in font:
    pass

# renamed: a modified version of an OFL font takes a name of its own
NAME = "Creed UI Letters CJK"
name = font["name"]
for rec in list(name.names):
    if rec.nameID in (1, 3, 4, 6, 16, 17, 21, 22):
        name.removeNames(nameID=rec.nameID)
for nid, val in ((1, NAME), (2, "Medium"), (3, NAME + " Medium; subset of Noto Sans CJK SC Medium"),
                 (4, NAME + " Medium"), (6, "CreedUILettersCJK-Medium")):
    name.setName(val, nid, 3, 1, 0x409)
    name.setName(val, nid, 1, 0, 0)
font.save(OUT)
print(WHICH, len(chars), "letters,", len(order), "glyphs,", os.path.getsize(OUT) // 1024, "KB")
