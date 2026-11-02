# the boss skulls' phrases: rows in Locale.lua (en fr de es pt) and the six generated languages
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Boss skulls", "Crânes des boss", "Boss-Schädel", "Calaveras de jefes", "Caveiras de chefes",
   "首领骷髅", "Черепа боссов", "ボスのドクロ", "보스 해골", "Czaszki bossów", "Boss kafatasları"),
 T("A skull over each boss, wherever it is on the screen: large when it is near, small when it is far. Not over mini-bosses.",
   "Un crâne au-dessus de chaque boss, où qu'il soit à l'écran : grand quand il est près, petit quand il est loin. Pas sur les mini-boss.",
   "Ein Schädel über jedem Boss, wo er auch auf dem Bildschirm ist: groß, wenn er nah ist, klein, wenn er fern ist. Nicht über Mini-Bossen.",
   "Una calavera sobre cada jefe, esté donde esté en la pantalla: grande cuando está cerca, pequeña cuando está lejos. No sobre los minijefes.",
   "Uma caveira sobre cada chefe, onde quer que esteja na tela: grande quando está perto, pequena quando está longe. Não sobre os minichefes.",
   "每个首领头上一个骷髅，无论它在屏幕何处：近时大，远时小。小首领没有。",
   "Череп над каждым боссом, где бы он ни был на экране: большой, когда он близко, маленький, когда далеко. Не над мини-боссами.",
   "画面のどこにいても各ボスの頭上にドクロ：近いと大きく、遠いと小さく。ミニボスには出ません。",
   "화면 어디에 있든 각 보스 위에 해골: 가까우면 크게, 멀면 작게. 미니 보스에는 없습니다.",
   "Czaszka nad każdym bossem, gdziekolwiek jest na ekranie: duża, gdy jest blisko, mała, gdy daleko. Nie nad minibossami.",
   "Ekranın neresinde olursa olsun her boss'un üstünde bir kafatası: yakınken büyük, uzaktayken küçük. Mini boss'ların üstünde değil."),
 T("the boss skulls stopped after an error: ", "les crânes des boss se sont arrêtés après une erreur : ",
   "die Boss-Schädel haben nach einem Fehler gestoppt: ", "las calaveras de jefes se detuvieron tras un error: ",
   "as caveiras de chefes pararam após um erro: ", "首领骷髅出错后已停止：", "черепа боссов остановились после ошибки: ",
   "ボスのドクロはエラーで停止しました：", "보스 해골이 오류로 멈췄습니다: ", "czaszki bossów zatrzymały się po błędzie: ",
   "boss kafatasları bir hatadan sonra durdu: "),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Boss skulls",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the boss skulls\n" + "".join(row(en, t) for en, t in P)
    anchor = "\n\t-- what stops after an error says so\n"
    assert loc.count(anchor) == 1
    loc = loc.replace(anchor, "\n" + rows + anchor)
    open(D + "/Locale.lua", "w", encoding="utf-8").write(loc)

kp = HERE + "/../en_keys.txt"
keys = open(kp, encoding="utf-8").read().split("\n")
new = [en for en, _ in P if en not in keys]
start = len(keys) + 1
if new:
    open(kp, "w", encoding="utf-8").write("\n".join(keys + new))
    for code in ("zh", "ru", "ja", "ko", "pl", "tr"):
        p = HERE + "/" + code + ".py"
        s = open(p, encoding="utf-8").read().rstrip()
        assert s.endswith("}")
        add = "".join("%d: %s,\n" % (start + n, q(dict(P)[en][code])) for n, en in enumerate(new))
        open(p, "w", encoding="utf-8").write(s[:-1] + add + "}\n")
print("added", len(new), "from", start)
