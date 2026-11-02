# the gems by the minimap became buttons on its edge (crossed swords, a clover): their phrases say so
import importlib.util, sys
D = sys.argv[1]
HERE = sys.path[0]
LUCK_OLD = "Your luck on a bronze medallion, and the chance of a Rare, Epic or Legendary card as three gems (1 in N); luck you gain shows on the medallion. Drag its sides to widen it, its corners to size it; the green gem by the minimap shows or hides it."
CH = [
 (LUCK_OLD, LUCK_OLD.replace("the green gem by the minimap shows or hides it.", "the clover on the minimap's edge shows or hides it."), "sub", dict(
   fr=("la gemme verte près de la minicarte l'affiche ou le cache.", "le trèfle au bord de la minicarte l'affiche ou le cache."),
   de=("der grüne Stein an der Minikarte zeigt oder verbirgt es.", "das Kleeblatt am Rand der Minikarte zeigt oder verbirgt es."),
   es=("la gema verde del minimapa lo muestra u oculta.", "el trébol en el borde del minimapa lo muestra u oculta."),
   pt=("a gema verde no minimapa mostra ou esconde.", "o trevo na borda do minimapa mostra ou esconde."),
   zh=("小地图旁的绿色宝石可显示或隐藏。", "小地图边缘的四叶草可显示或隐藏。"),
   ru=("зелёный камень у миникарты показывает или скрывает окно.", "клевер на краю миникарты показывает или скрывает окно."),
   ja=("ミニマップ横の緑の宝石で表示切替。", "ミニマップの縁のクローバーで表示切替。"),
   ko=("미니맵 옆 초록 보석으로 표시/숨기기.", "미니맵 가장자리의 클로버로 표시/숨기기."),
   pl=("zielony klejnot przy minimapie pokazuje lub ukrywa okno.", "koniczyna na brzegu minimapy pokazuje lub ukrywa okno."),
   tr=("mini haritadaki yeşil taş gösterir ya da gizler.", "mini haritanın kenarındaki yonca gösterir ya da gizler."))),
 ("Hide the meter (the gem by the minimap brings it back)", "Hide the meter (the swords on the minimap's edge bring it back)", "all", dict(
   fr="Cacher le compteur (les épées au bord de la minicarte le ramènent)",
   de="Messer ausblenden (die Schwerter am Rand der Minikarte holen ihn zurück)",
   es="Ocultar el medidor (las espadas en el borde del minimapa lo traen de vuelta)",
   pt="Esconder o medidor (as espadas na borda do minimapa trazem de volta)",
   zh="隐藏统计（小地图边缘的双剑可找回）", ru="Скрыть счётчик (мечи на краю миникарты вернут его)",
   ja="メーターを隠す（ミニマップの縁の剣で戻せます）", ko="측정기 숨기기 (미니맵 가장자리의 검으로 되돌림)",
   pl="Ukryj licznik (miecze na brzegu minimapy go przywrócą)", tr="Ölçeri gizle (mini haritanın kenarındaki kılıçlar geri getirir)")),
 ("Hide the luck window (the gem by the minimap brings it back)", "Hide the luck window (the clover on the minimap's edge brings it back)", "all", dict(
   fr="Cacher la fenêtre de chance (le trèfle au bord de la minicarte la ramène)",
   de="Glücksfenster ausblenden (das Kleeblatt am Rand der Minikarte holt es zurück)",
   es="Ocultar la ventana de suerte (el trébol en el borde del minimapa la trae de vuelta)",
   pt="Esconder a janela de sorte (o trevo na borda do minimapa traz de volta)",
   zh="隐藏幸运窗口（小地图边缘的四叶草可找回）", ru="Скрыть окно удачи (клевер на краю миникарты вернёт его)",
   ja="運の窓を隠す（ミニマップの縁のクローバーで戻せます）", ko="행운 창 숨기기 (미니맵 가장자리의 클로버로 되돌림)",
   pl="Ukryj okno szczęścia (koniczyna na brzegu minimapy je przywróci)", tr="Şans penceresini gizle (mini haritanın kenarındaki yonca geri getirir)")),
]
def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

loc = open(D + "/Locale.lua", encoding="utf-8").read()
for old, new, mode, t in CH:
    i = loc.find(q(old))
    if i < 0:
        assert q(new) in loc, old
        continue
    j = loc.index("},", i)
    row = loc[i:j]
    row2 = row.replace(q(old), q(new), 1)
    for c in ("fr", "de", "es", "pt"):
        if mode == "sub":
            a, b = t[c]
            assert row2.count(a) == 1, (c, a)
            row2 = row2.replace(a, b)
        else:
            cur = row2.split('", ')  # replace by position: the row's 2nd..5th strings
    if mode == "all":
        row2 = "{ " + ", ".join(q(x) for x in [new] + [t[c] for c in ("fr", "de", "es", "pt")]) + " "
        row2 = row2[2:]  # the row starts at the key's quote
    loc = loc[:i] + row2 + loc[j:]
open(D + "/Locale.lua", "w", encoding="utf-8").write(loc)

kp = HERE + "/../en_keys.txt"
keys = open(kp, encoding="utf-8").read().split("\n")
idx = {}
for old, new, mode, t in CH:
    if old in keys:
        k = keys.index(old); keys[k] = new
    idx[new] = keys.index(new) + 1
open(kp, "w", encoding="utf-8").write("\n".join(keys))

for code in ("zh", "ru", "ja", "ko", "pl", "tr"):
    p = HERE + "/" + code + ".py"
    spec = importlib.util.spec_from_file_location(code, p); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    s = open(p, encoding="utf-8").read()
    for old, new, mode, t in CH:
        n = idx[new]
        cur = m.T[n]
        want = cur.replace(t[code][0], t[code][1]) if mode == "sub" else t[code]
        if mode == "sub" and t[code][0] not in cur:
            assert t[code][1] in cur, (code, n, cur)
            continue
        assert s.count(q(cur)) >= 1, (code, n)
        s = s.replace("%d: %s" % (n, q(cur)), "%d: %s" % (n, q(want)))
        assert "%d: %s" % (n, q(want)) in s, (code, n, "not placed")
    open(p, "w", encoding="utf-8").write(s)
print("ok", idx)
