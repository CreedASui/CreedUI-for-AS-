# the character panel's phrases: rows in Locale.lua (en fr de es pt) and the six generated languages
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Character panel", "Fenêtre du personnage", "Charakterfenster", "Panel del personaje", "Painel do personagem", "角色面板", "Панель персонажа", "キャラクター画面", "캐릭터 창", "Panel postaci", "Karakter paneli"),
 T("The game's character window in Creed UI's panel: each gear slot in metal, lit in its item's rarity color; your run's stats grouped beside it (the ones at nothing dimmed, a change since your last look flashing by its number); the talents you hold at its foot.",
   "La fenêtre du personnage du jeu dans le panneau de Creed UI : chaque emplacement d'équipement en métal, éclairé de la couleur de rareté de l'objet ; les stats de la partie groupées à côté (celles à zéro atténuées, un changement depuis votre dernier coup d'œil qui clignote) ; vos talents en bas.",
   "Das Charakterfenster des Spiels im Creed-UI-Stil: jeder Ausrüstungsplatz in Metall, in der Seltenheitsfarbe des Gegenstands beleuchtet; deine Laufwerte gruppiert daneben (Werte bei null gedimmt, eine Änderung seit dem letzten Blick blinkt); deine Talente unten.",
   "La ventana del personaje del juego en el panel de Creed UI: cada ranura de equipo en metal, iluminada con el color de rareza del objeto; las estadísticas de la partida agrupadas al lado (las que están en cero atenuadas, un cambio desde tu último vistazo parpadea); tus talentos abajo.",
   "A janela do personagem do jogo no painel do Creed UI: cada espaço de equipamento em metal, aceso na cor da raridade do item; os atributos da partida agrupados ao lado (os zerados esmaecidos, uma mudança desde a última olhada pisca); seus talentos embaixo.",
   "以 Creed UI 面板呈现的游戏角色窗口：每个装备栏都镶上金属边框，并按物品稀有度发光；旁边分组显示本局属性（为零的变暗，自上次查看以来的变化会闪烁显示）；底部显示你的天赋。",
   "Окно персонажа игры в стиле Creed UI: каждая ячейка снаряжения в металле, подсвечена цветом редкости предмета; показатели забега сгруппированы рядом (нулевые приглушены, изменение с прошлого взгляда мигает); ваши таланты внизу.",
   "ゲームのキャラクター画面をCreed UIのパネルに：装備スロットは金属の枠で、アイテムのレア度の色に光ります。横にはランの能力値をまとめて表示（0のものは暗く、前回見た時からの変化は点滅）。下にはあなたのタレント。",
   "Creed UI 패널로 꾸민 게임 캐릭터 창: 장비 칸마다 금속 테두리와 아이템 희귀도 색의 빛; 옆에는 진행 능력치를 묶어서 표시(0인 것은 흐리게, 지난번에 본 뒤의 변화는 깜박임); 아래에는 보유한 특성.",
   "Okno postaci gry w panelu Creed UI: każde miejsce na ekwipunek w metalu, podświetlone kolorem rzadkości przedmiotu; statystyki rozgrywki pogrupowane obok (zerowe przygaszone, zmiana od ostatniego spojrzenia miga); twoje talenty na dole.",
   "Oyunun karakter penceresi Creed UI panelinde: her ekipman yuvası metal çerçeveli, eşyanın nadirlik rengiyle parlar; oyun değerleri yanında gruplanmış (sıfır olanlar soluk, son bakıştan beri değişen yanıp söner); yeteneklerin altta."),
 T("Run stats", "Stats de la partie", "Laufwerte", "Estadísticas", "Atributos da partida", "本局属性", "Показатели забега", "ランの能力値", "진행 능력치", "Statystyki rozgrywki", "Oyun değerleri"),
 T("The game hasn't shown its stats yet.", "Le jeu n'a pas encore affiché ses stats.", "Das Spiel hat seine Werte noch nicht gezeigt.", "El juego aún no ha mostrado sus estadísticas.", "O jogo ainda não mostrou os atributos.", "游戏尚未显示属性。", "Игра ещё не показала показатели.", "ゲームがまだ能力値を表示していません。", "게임이 아직 능력치를 보여 주지 않았습니다.", "Gra jeszcze nie pokazała statystyk.", "Oyun henüz değerleri göstermedi."),
 T("TALENTS", "TALENTS", "TALENTE", "TALENTOS", "TALENTOS", "天赋", "ТАЛАНТЫ", "タレント", "특성", "TALENTY", "YETENEKLER"),
 T("None yet: they show here as you pick them.", "Aucun : ils s'affichent ici une fois choisis.", "Noch keine: Sie erscheinen hier, wenn gewählt.", "Ninguno aún: aparecen aquí al elegirlos.", "Nenhum ainda: aparecem aqui ao escolher.", "暂无：选择后会显示在这里。", "Пока нет: появятся здесь по мере выбора.", "まだありません：選ぶとここに表示されます。", "아직 없음: 고르면 여기에 표시됩니다.", "Brak: pojawią się tu, gdy je wybierzesz.", "Henüz yok: seçtikçe burada görünür."),
 T("Rank {1}/{2}", "Rang {1}/{2}", "Rang {1}/{2}", "Rango {1}/{2}", "Grau {1}/{2}", "等级 {1}/{2}", "Ранг {1}/{2}", "ランク {1}/{2}", "{1}/{2}단계", "Ranga {1}/{2}", "Seviye {1}/{2}"),
 T("Rank {1}", "Rang {1}", "Rang {1}", "Rango {1}", "Grau {1}", "等级 {1}", "Ранг {1}", "ランク {1}", "{1}단계", "Ranga {1}", "Seviye {1}"),
 T("OFFENSE", "OFFENSIVE", "ANGRIFF", "OFENSIVA", "OFENSIVA", "进攻", "АТАКА", "攻撃", "공격", "ATAK", "SALDIRI"),
 T("SURVIVAL", "SURVIE", "ÜBERLEBEN", "SUPERVIVENCIA", "SOBREVIVÊNCIA", "生存", "ВЫЖИВАНИЕ", "生存", "생존", "PRZETRWANIE", "HAYATTA KALMA"),
 T("AREA AND DOTS", "ZONE ET DOT", "FLÄCHE UND DOTS", "ÁREA Y DOTS", "ÁREA E DOTS", "范围与持续伤害", "ОБЛАСТЬ И DOT", "範囲とDoT", "범위와 DoT", "OBSZAR I DOT", "ALAN VE DOT"),
 T("RUN", "PARTIE", "LAUF", "PARTIDA", "PARTIDA", "本局", "ЗАБЕГ", "ラン", "진행", "ROZGRYWKA", "OYUN"),
 T("OTHER", "AUTRES", "SONSTIGES", "OTROS", "OUTROS", "其他", "ПРОЧЕЕ", "その他", "기타", "INNE", "DİĞER"),
 T("Health", "Vie", "Gesundheit", "Salud", "Vida", "生命", "Здоровье", "体力", "생명력", "Zdrowie", "Can"),
 T("Haste", "Hâte", "Tempo", "Celeridad", "Aceleração", "急速", "Ускорение", "ヘイスト", "가속", "Przyspieszenie", "Çabukluk"),
 T("Crit", "Critique", "Krit", "Crítico", "Crítico", "暴击", "Крит", "クリティカル", "치명타", "Kryt.", "Kritik"),
 T("Crit Dmg", "Dégâts crit.", "Krit-Schaden", "Daño crítico", "Dano crítico", "暴击伤害", "Урон крита", "クリティカル威力", "치명타 피해", "Obr. kryt.", "Kritik hasar"),
 T("Armor", "Armure", "Rüstung", "Armadura", "Armadura", "护甲", "Броня", "アーマー", "방어도", "Pancerz", "Zırh"),
 T("Area", "Zone", "Fläche", "Área", "Área", "范围", "Область", "範囲", "범위", "Obszar", "Alan"),
 T("Targets", "Cibles", "Ziele", "Objetivos", "Alvos", "目标数", "Цели", "対象数", "대상 수", "Cele", "Hedef"),
 T("Echo", "Écho", "Echo", "Eco", "Eco", "回响", "Эхо", "エコー", "메아리", "Echo", "Yankı"),
 T("Speed", "Vitesse", "Bewegung", "Velocidad", "Velocidade", "移动速度", "Скорость", "移動速度", "이동 속도", "Szybkość", "Hareket hızı"),
 T("Regen", "Régén.", "Regeneration", "Regeneración", "Regeneração", "生命恢复", "Регенерация", "自然回復", "재생", "Regeneracja", "Yenilenme"),
 T("Pickup", "Ramassage", "Aufsammeln", "Recogida", "Coleta", "拾取范围", "Подбор", "回収範囲", "획득 범위", "Zbieranie", "Toplama"),
 T("Lifesteal", "Vol de vie", "Lebensraub", "Robo de vida", "Roubo de vida", "吸血", "Вампиризм", "吸収", "생명력 흡수", "Kradzież życia", "Can çalma"),
 T("Kill Heal", "Soin par victime", "Heilung pro Kill", "Cura por muerte", "Cura por abate", "击杀治疗", "Лечение за убийство", "撃破回復", "처치 시 치유", "Leczenie za zabójstwo", "Öldürünce iyileşme"),
 T("Thorns", "Épines", "Dornen", "Espinas", "Espinhos", "荆棘", "Шипы", "トゲ", "가시", "Ciernie", "Dikenler"),
 T("Lives", "Vies", "Leben", "Vidas", "Vidas", "生命数", "Жизни", "残機", "목숨", "Życia", "Ek can"),
 T("Experience", "Expérience", "Erfahrung", "Experiencia", "Experiência", "经验", "Опыт", "経験値", "경험치", "Doświadczenie", "Deneyim"),
 T("Buff Power", "Puissance des buffs", "Buff-Stärke", "Poder de mejoras", "Poder dos bônus", "增益强度", "Сила баффов", "バフ効果", "강화 효과", "Moc wzmocnień", "Güçlendirme gücü"),
 T("DoT Stacks", "Cumuls de DoT", "DoT-Stapel", "Acumulaciones de DoT", "Acúmulos de DoT", "持续伤害层数", "Стаки DoT", "DoTスタック", "DoT 중첩", "Kumulacje DoT", "DoT yığını"),
 T("DoT Haste", "Hâte des DoT", "DoT-Tempo", "Celeridad de DoT", "Aceleração de DoT", "持续伤害急速", "Ускорение DoT", "DoTヘイスト", "DoT 가속", "Przysp. DoT", "DoT çabukluğu"),
 T("Execute", "Exécution", "Hinrichten", "Ejecutar", "Executar", "斩杀", "Казнь", "処刑", "처형", "Egzekucja", "İnfaz"),
 T("Vs Afflicted", "Contre affligés", "Gegen Betroffene", "Contra afligidos", "Contra afligidos", "对受折磨者", "Против поражённых", "状態異常の敵へ", "고통받는 적에게", "Na dotkniętych", "Etkilenene karşı"),
 T("the character panel stopped after an error, so the game's own is back: ",
   "le panneau du personnage s'est arrêté après une erreur, celui du jeu est revenu : ", "das Charakterfenster hat nach einem Fehler gestoppt, das des Spiels ist zurück: ",
   "el panel del personaje se detuvo tras un error; vuelve el del juego: ", "o painel do personagem parou após um erro; o do jogo voltou: ",
   "角色面板出错后已停止，游戏自带的已恢复：", "панель персонажа остановлена после ошибки, вернулась панель игры: ", "キャラクター画面がエラーで止まり、ゲームのものに戻りました：",
   "캐릭터 창이 오류로 멈춰 게임의 것으로 돌아갔습니다: ", "panel postaci zatrzymał się po błędzie, wrócił panel gry: ", "karakter paneli bir hatadan sonra durdu, oyununki geri döndü: "),
 T("what the game tells addons:", "ce que le jeu donne aux addons :", "was das Spiel Addons mitteilt:", "lo que el juego da a los addons:", "o que o jogo passa aos addons:",
   "游戏提供给插件的信息：", "что игра сообщает аддонам:", "ゲームがアドオンに渡す情報：", "게임이 애드온에 알려 주는 것:", "co gra przekazuje dodatkom:", "oyunun eklentilere verdikleri:"),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Character panel"' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the character panel\n" + "".join(row(en, t) for en, t in P if not en.startswith("the character panel stopped"))
    anchor = "\n\t-- what stops after an error says so\n"
    assert loc.count(anchor) == 1
    loc = loc.replace(anchor, "\n" + rows + anchor)
    err = [p for p in P if p[0].startswith("the character panel stopped")][0]
    last = '\t{ "unit frames stopped after an error'
    i = loc.index(last); j = loc.index("\n", loc.index("},", i)) + 1
    loc = loc[:j] + row(*err) + loc[j:]
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
