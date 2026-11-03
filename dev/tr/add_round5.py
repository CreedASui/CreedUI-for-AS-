# 1.13.0's phrases (the talent window): rows in Locale.lua (en fr de es pt) and the six generated
# languages. The talent trees' names are the game's own, read from its client.
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
# the game's tree names: en, fr, de, es, pt, zh, ru, ja, ko, pl, tr
TREES = [
 ("Arms", "Armes", "Waffen", "Armas", "Armas", "武器", "Оружие", "武器", "무기", "Broń", "Silah"),
 ("Fury", "Fureur", "Furor", "Furia", "Fúria", "狂怒", "Неистовство", "激怒", "분노", "Furia", "Öfke"),
 ("Protection", "Protection", "Schutz", "Protección", "Proteção", "防护", "Защита", "防御", "방어", "Ochrona", "Koruma"),
 ("Holy", "Sacré", "Heilig", "Sagrado", "Sagrado", "神圣", "Свет", "神聖", "신성", "Świętość", "Kutsal"),
 ("Retribution", "Vindicte", "Vergeltung", "Reprensión", "Retribuição", "惩戒", "Воздаяние", "報復", "징벌", "Odpłata", "İntikam"),
 ("Shadow", "Ombre", "Schatten", "Sombras", "Sombra", "暗影", "Тьма", "闇", "암흑", "Cień", "Gölge"),
 ("Discipline", "Discipline", "Disziplin", "Disciplina", "Disciplina", "戒律", "Послушание", "規律", "수양", "Dyscyplina", "Disiplin"),
 ("Fire", "Feu", "Feuer", "Fuego", "Fogo", "火焰", "Огонь", "火", "화염", "Ogień", "Ateş"),
 ("Frost", "Givre", "Frost", "Escarcha", "Gelo", "冰霜", "Лёд", "冷気", "냉기", "Mróz", "Buz"),
 ("Arcane", "Arcanes", "Arkan", "Arcano", "Arcano", "奥术", "Тайная магия", "秘術", "비전", "Tajemna magia", "Arkan"),
 ("Affliction", "Affliction", "Gebrechen", "Aflicción", "Suplício", "痛苦", "Колдовство", "苦痛", "고통", "Udręka", "Eziyet"),
 ("Demonology", "Démonologie", "Dämonologie", "Demonología", "Demonologia", "恶魔学识", "Демонология", "悪魔学", "악마", "Demonologia", "İblisbilim"),
 ("Destruction", "Destruction", "Zerstörung", "Destrucción", "Destruição", "毁灭", "Разрушение", "破壊", "파괴", "Zniszczenie", "Yıkım"),
 ("Assassination", "Assassinat", "Attentate", "Asesinato", "Assassinato", "刺杀", "Ликвидация", "暗殺", "암살", "Skrytobójstwo", "Suikast"),
 ("Combat", "Combat", "Kampf", "Combate", "Combate", "战斗", "Бой", "戦闘", "전투", "Walka", "Dövüş"),
 ("Subtlety", "Finesse", "Täuschung", "Sutileza", "Subterfúgio", "敏锐", "Скрытность", "隠密", "잠행", "Subtelność", "Sinsilik"),
 ("Beast Mastery", "Maîtrise des bêtes", "Tierherrschaft", "Dominio de bestias", "Domínio das Feras", "野兽控制", "Чувство зверя", "獣の支配", "야수 조련", "Władanie Bestiami", "Hayvan Ustalığı"),
 ("Marksmanship", "Précision", "Treffsicherheit", "Puntería", "Precisão", "射击", "Стрельба", "射撃", "사격술", "Strzelectwo", "Nişancılık"),
 ("Survival", "Survie", "Überleben", "Supervivencia", "Sobrevivência", "生存技能", "Выживание", "生存", "생존", "Przetrwanie", "Hayatta Kalma"),
 ("Elemental", "Élémentaire", "Elementar", "Elemental", "Elemental", "元素", "Стихии", "エレメンタル", "정기", "Żywioły", "Elementel"),
 ("Enhancement", "Amélioration", "Verstärkung", "Mejora", "Aperfeiçoamento", "增强", "Совершенствование", "強化", "고양", "Wzmocnienie", "Güçlendirme"),
 ("Restoration", "Restauration", "Wiederherstellung", "Restauración", "Restauração", "恢复", "Исцеление", "回復", "복원", "Odnowa", "Onarım"),
 ("Balance", "Équilibre", "Gleichgewicht", "Equilibrio", "Equilíbrio", "平衡", "Баланс", "バランス", "조화", "Równowaga", "Denge"),
 ("Feral Combat", "Combat farouche", "Wilder Kampf", "Combate feral", "Combate Feral", "野性战斗", "Сила зверя", "野生の戦闘", "야성", "Dzika Walka", "Vahşi Dövüş"),
]
P = [T(*row) for row in TREES] + [
 T("{1} points", "{1} points", "{1} Punkte", "{1} puntos", "{1} pontos", "{1} 点", "{1} очк.", "{1} ポイント", "{1}포인트", "{1} pkt", "{1} puan"),
 T("{1} points spent", "{1} points dépensés", "{1} Punkte verteilt", "{1} puntos gastados", "{1} pontos gastos", "已投入 {1} 点",
   "Потрачено очков: {1}", "{1} ポイント使用", "{1}포인트 사용", "Wydano {1} pkt", "{1} puan harcandı"),
 T("What this run plays with", "Ce que joue cette partie", "Womit dieser Lauf spielt", "Con lo que juega esta partida",
   "Com o que esta partida joga", "本次冒险使用的天赋", "С чем играет этот забег", "このランで使うもの", "이번 도전에서 쓰는 것",
   "Z czym gra ta wyprawa", "Bu oyunda kullanılanlar"),
 T("Your talents show here during a run.", "Vos talents s'affichent ici pendant une partie.", "Deine Talente erscheinen hier während eines Laufs.",
   "Tus talentos aparecen aquí durante una partida.", "Seus talentos aparecem aqui durante uma partida.", "冒险中你的天赋会显示在这里。",
   "Таланты видны здесь во время забега.", "ラン中はここにタレントが表示されます。", "도전 중에 특성이 여기에 표시됩니다.",
   "Talenty pojawiają się tu podczas wyprawy.", "Yeteneklerin oyun sırasında burada görünür."),
 T("No talents learned yet.", "Aucun talent appris pour l'instant.", "Noch keine Talente gelernt.", "Aún no has aprendido talentos.",
   "Nenhum talento aprendido ainda.", "尚未学习天赋。", "Таланты ещё не изучены.", "まだタレントを習得していません。", "아직 배운 특성이 없습니다.",
   "Brak poznanych talentów.", "Henüz yetenek öğrenilmedi."),
 T("the talent window stopped after an error: ", "la fenêtre des talents s'est arrêtée après une erreur : ",
   "das Talentfenster hat nach einem Fehler gestoppt: ", "la ventana de talentos se detuvo tras un error: ",
   "a janela de talentos parou após um erro: ", "天赋窗口出错后已停止：", "окно талантов остановилось после ошибки: ",
   "タレントウィンドウはエラーで停止しました：", "특성 창이 오류로 멈췄습니다: ", "okno talentów zatrzymało się po błędzie: ",
   "yetenek penceresi bir hatadan sonra durdu: "),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
kp = HERE + "/../en_keys.txt"
keys = open(kp, encoding="utf-8").read().split("\n")
# a phrase Creed UI already has keeps its translation
P = [(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc and en not in keys]
if P and '{ "What this run plays with",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the talent window, and the talent trees by the game's own names\n" + "".join(row(en, t) for en, t in P)
    anchor = "\n\t-- what stops after an error says so\n"
    assert loc.count(anchor) == 1
    loc = loc.replace(anchor, "\n" + rows + anchor)
    open(D + "/Locale.lua", "w", encoding="utf-8").write(loc)
new = [en for en, _ in P]
start = len(keys) + 1
if new:
    open(kp, "w", encoding="utf-8").write("\n".join(keys + new))
    for code in ("zh", "ru", "ja", "ko", "pl", "tr"):
        p = HERE + "/" + code + ".py"
        s = open(p, encoding="utf-8").read().rstrip()
        assert s.endswith("}")
        add = "".join("%d: %s,\n" % (start + n, q(dict(P)[en][code])) for n, en in enumerate(new))
        open(p, "w", encoding="utf-8").write(s[:-1] + add + "}\n")
print("added", len(new), "from", start, "skipped as already there:", 30 - len(new))
