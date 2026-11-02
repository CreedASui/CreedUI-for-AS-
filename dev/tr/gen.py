#!/usr/bin/env python3
"""Make CreedUI/Locale_<code>.lua from the numbered translations (tr/<code>.py) and the English
phrases in Locale.lua's order (en_keys.txt)."""
import importlib.util
import os
import sys

D = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
keys = open(os.path.join(HERE, "..", "en_keys.txt"), encoding="utf-8").read().split("\n")
FACES = {"zh": "CreedUI.FACE_CJK", "ja": "CreedUI.FACE_CJK", "ko": "CreedUI.FACE_CJK",
         "ru": "CreedUI.FACE_LETTERS", "pl": "CreedUI.FACE_LETTERS", "tr": "CreedUI.FACE_LETTERS"}
TITLES = {"zh": "Simplified Chinese", "ru": "Russian", "ja": "Japanese", "ko": "Korean", "pl": "Polish", "tr": "Turkish"}


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


for code in ("zh", "ru", "ja", "ko", "pl", "tr"):
    spec = importlib.util.spec_from_file_location(code, os.path.join(HERE, code + ".py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    assert sorted(m.T) == list(range(1, len(keys) + 1)), (code, len(m.T), len(keys))
    lines = ["-- Creed UI in " + TITLES[code] + ": the English phrases (Locale.lua) and their words here.",
             "-- Drawn in a face of Creed UI's own (Core, the Fonts folder): Friz Quadrata lacks these letters.",
             "CreedUI.AddLanguage(" + q(m.CODE) + ", " + q(m.NAME) + ", " + FACES[code] + ", {"]
    for i, k in enumerate(keys, 1):
        lines.append("\t[" + q(k) + "] = " + q(m.T[i]) + ",")
    lines.append("})")
    open(os.path.join(D, "Locale_" + code + ".lua"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(code, len(m.T))
