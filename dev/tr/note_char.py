# the character panel's note without its talents (they come later)
import importlib.util, sys
D = sys.argv[1]
HERE = sys.path[0]
OLD = "The game's character window in Creed UI's panel: each gear slot in metal, lit in its item's rarity color; your run's stats grouped beside it (the ones at nothing dimmed, a change since your last look flashing by its number); the talents you hold at its foot."
NEW = OLD.replace("); the talents you hold at its foot.", ").")
CUT = {"fr": (") ; vos talents en bas.", ")."), "de": ("); deine Talente unten.", ")."), "es": ("); tus talentos abajo.", ")."),
       "pt": ("); seus talentos embaixo.", ")."), "zh": ("）；底部显示你的天赋。", "）。"), "ru": ("); ваши таланты внизу.", ")."),
       "ja": ("）。下にはあなたのタレント。", "）。"), "ko": ("); 아래에는 보유한 특성.", ")."), "pl": ("); twoje talenty na dole.", ")."),
       "tr": ("); yeteneklerin altta.", ").")}
def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if q(OLD) in loc:
    i = loc.index(q(OLD)); j = loc.index("},", i)
    row = loc[i:j].replace(q(OLD), q(NEW), 1)
    for c in ("fr", "de", "es", "pt"):
        a, b = CUT[c]
        assert row.count(a) == 1, (c, a)
        row = row.replace(a, b)
    loc = loc[:i] + row + loc[j:]
    open(D + "/Locale.lua", "w", encoding="utf-8").write(loc)
kp = HERE + "/../en_keys.txt"
keys = open(kp, encoding="utf-8").read().split("\n")
if OLD in keys:
    keys[keys.index(OLD)] = NEW
    open(kp, "w", encoding="utf-8").write("\n".join(keys))
n = keys.index(NEW) + 1
for code in ("zh", "ru", "ja", "ko", "pl", "tr"):
    p = HERE + "/" + code + ".py"
    spec = importlib.util.spec_from_file_location(code, p); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    cur = m.T[n]
    a, b = CUT[code]
    if a not in cur:
        assert cur.endswith(b), (code, cur)
        continue
    s = open(p, encoding="utf-8").read()
    old = "%d: %s" % (n, q(cur))
    assert s.count(old) == 1, code
    s = s.replace(old, "%d: %s" % (n, q(cur.replace(a, b))))
    open(p, "w", encoding="utf-8").write(s)
print("ok", n)
