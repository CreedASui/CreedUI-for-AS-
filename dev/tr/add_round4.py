# 1.11.0's phrases (Damage Taken, stored level-ups, the run summary, friends down): rows in Locale.lua
# (en fr de es pt) and the six generated languages. The end screen's words are the game's own.
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
TAKEN = ("Dégâts subis", "Erlittener Schaden", "Daño recibido", "Dano sofrido", "承受伤害", "Получено урона", "被ダメージ", "받은 피해", "Otrzymane obrażenia", "Alınan hasar")
P = [
 T("Damage Taken", *TAKEN),
 T("Taken", "Subis", "Erlitten", "Recibido", "Sofrido", "承受", "Получено", "被ダメ", "받은", "Otrzymane", "Alınan"),
 T("No damage taken yet.", "Aucun dégât subi pour l'instant.", "Noch kein Schaden erlitten.", "Aún no has recibido daño.",
   "Nenhum dano sofrido ainda.", "尚未承受伤害。", "Урона пока не получено.", "まだダメージを受けていません。", "아직 받은 피해가 없습니다.",
   "Brak otrzymanych obrażeń.", "Henüz hasar alınmadı."),
 T("Level Up!", "Niveau supérieur !", "Stufenaufstieg!", "¡Subes de nivel!", "Subiu de Nível!", "升级！", "Новый уровень!", "レベルアップ！",
   "레벨 업!", "Awans!", "Seviye Atladın!"),
 T("{1} level-ups wait. Click to pick their cards.", "{1} niveaux en attente. Cliquez pour choisir leurs cartes.",
   "{1} Stufenaufstiege warten. Klicken, um ihre Karten zu wählen.", "{1} subidas de nivel esperan. Haz clic para elegir sus cartas.",
   "{1} níveis esperando. Clique para escolher as cartas.", "{1} 次升级待领取。点击选择卡牌。", "Ждут повышений уровня: {1}. Нажмите, чтобы выбрать карты.",
   "{1} 回のレベルアップが待機中。クリックでカードを選択。", "레벨 업 {1}회 대기 중. 클릭해 카드를 고르세요.", "Czeka awansów: {1}. Kliknij, aby wybrać karty.",
   "{1} seviye atlama bekliyor. Kartlarını seçmek için tıkla."),
 T("the level-up button stopped after an error, so the game's own is back: ",
   "le bouton de niveau s'est arrêté après une erreur, celui du jeu est revenu : ",
   "der Stufenaufstieg-Knopf hat nach einem Fehler gestoppt, der des Spiels ist zurück: ",
   "el botón de subir de nivel se detuvo tras un error; vuelve el del juego: ", "o botão de subir de nível parou após um erro; o do jogo voltou: ",
   "升级按钮出错后已停止，游戏自带的已恢复：", "кнопка уровней остановилась после ошибки, кнопка игры вернулась: ",
   "レベルアップボタンはエラーで停止し、ゲームのものに戻りました：", "레벨 업 버튼이 오류로 멈춰 게임 버튼이 돌아왔습니다: ",
   "przycisk awansu zatrzymał się po błędzie, wrócił przycisk gry: ", "seviye düğmesi bir hatadan sonra durdu, oyununki geri geldi: "),
 T("Stored level-ups", "Niveaux en réserve", "Aufgehobene Stufen", "Subidas guardadas", "Níveis guardados", "储存的升级", "Отложенные уровни",
   "保留中のレベルアップ", "저장된 레벨 업", "Zachowane awanse", "Saklanan seviyeler"),
 T("With the game's Store Level-Ups on: a glowing Level Up! button over the skill bar with how many wait. Click it to pick their cards. Replaces the game's button.",
   "Avec les niveaux mis en réserve (option du jeu) : un bouton lumineux au-dessus de la barre de sorts, avec le nombre en attente. Cliquez pour choisir leurs cartes. Remplace le bouton du jeu.",
   "Mit der Spieloption Stufenaufstiege aufheben: ein leuchtender Knopf über der Leiste, mit der Zahl der wartenden. Klicken, um ihre Karten zu wählen. Ersetzt den Knopf des Spiels.",
   "Con la opción del juego de guardar subidas de nivel: un botón brillante sobre la barra con cuántas esperan. Haz clic para elegir sus cartas. Sustituye el botón del juego.",
   "Com a opção do jogo de guardar níveis: um botão brilhante sobre a barra com quantos esperam. Clique para escolher as cartas. Substitui o botão do jogo.",
   "开启游戏的“储存升级”时：技能栏上方一个发光的按钮，显示待领取的次数。点击即可选择卡牌。取代游戏的按钮。",
   "Если в игре включено сохранение уровней: светящаяся кнопка над панелью с числом ожидающих. Нажмите, чтобы выбрать карты. Заменяет кнопку игры.",
   "ゲームのレベルアップ保留がオンのとき：スキルバーの上に待機数付きの光るボタン。クリックでカードを選択。ゲームのボタンを置き換えます。",
   "게임의 레벨 업 저장이 켜져 있으면: 스킬 바 위에 대기 수가 표시된 빛나는 버튼. 클릭해 카드를 고르세요. 게임 버튼을 대체합니다.",
   "Gdy w grze włączone jest zachowywanie awansów: świecący przycisk nad paskiem z liczbą czekających. Kliknij, aby wybrać karty. Zastępuje przycisk gry.",
   "Oyunun seviye saklama ayarı açıkken: yetenek çubuğunun üstünde bekleyen sayısıyla parlayan bir düğme. Kartlarını seçmek için tıkla. Oyunun düğmesinin yerini alır."),
 T("Survived", "Survie", "Überlebt", "Sobrevivido", "Sobreviveu", "存活时间", "Продержались", "生存時間", "생존 시간", "Przetrwano", "Hayatta kalınan süre"),
 T("Level", "Niveau", "Stufe", "Nivel", "Nível", "等级", "Уровень", "レベル", "레벨", "Poziom", "Seviye"),
 T("Elites slain", "Élites tuées", "Elitegegner getötet", "Élites abatidos", "Elites mortos", "击杀精英", "Убито элитных", "エリート撃破", "정예 처치", "Zabite elity", "Öldürülen elitler"),
 T("Guardians slain", "Gardiens tués", "Wächter getötet", "Guardianes abatidos", "Guardiões mortos", "击杀守护者", "Убито стражей", "守護者撃破", "수호자 처치", "Zabici strażnicy", "Öldürülen muhafızlar"),
 T("Bosses slain", "Boss tués", "Bosse getötet", "Jefes abatidos", "Chefes mortos", "击杀首领", "Убито боссов", "ボス撃破", "우두머리 처치", "Zabici bossowie", "Öldürülen boss'lar"),
 T("Damage dealt", "Dégâts infligés", "Verursachter Schaden", "Daño infligido", "Dano causado", "造成伤害", "Нанесено урона", "与ダメージ", "입힌 피해", "Zadane obrażenia", "Verilen hasar"),
 T("Damage a second", "Dégâts par seconde", "Schaden pro Sekunde", "Daño por segundo", "Dano por segundo", "每秒伤害", "Урон в секунду", "秒間ダメージ", "초당 피해", "Obrażenia na sekundę", "Saniye başına hasar"),
 T("Damage taken", *TAKEN),
 T("Gold earned", "Or gagné", "Verdientes Gold", "Oro obtenido", "Ouro obtido", "获得金币", "Заработано золота", "獲得ゴールド", "얻은 골드", "Zdobyte złoto", "Kazanılan altın"),
 T("Caches opened", "Coffres ouverts", "Geöffnete Truhen", "Alijos abiertos", "Baús abertos", "开启宝箱", "Открыто тайников", "開けた宝箱", "연 보물상자", "Otwarte skrzynie", "Açılan sandıklar"),
 T("You have fallen", "Vous êtes mort", "Du bist gefallen", "Has caído", "Você caiu", "你倒下了", "Вы погибли", "あなたは倒れた", "쓰러졌습니다", "Poległeś", "Düştün"),
 T("You left the run", "Vous avez quitté la partie", "Du hast den Lauf verlassen", "Abandonaste la partida", "Você abandonou a partida", "你离开了冒险",
   "Вы покинули забег", "ランを離脱しました", "도전을 포기했습니다", "Opuszczasz wyprawę", "Oyundan ayrıldın"),
 T("Run over", "Partie terminée", "Lauf vorbei", "Partida terminada", "Partida encerrada", "冒险结束", "Забег окончен", "ラン終了", "도전 종료", "Koniec wyprawy", "Oyun bitti"),
 T("the run summary stopped after an error: ", "le résumé de partie s'est arrêté après une erreur : ", "die Laufübersicht hat nach einem Fehler gestoppt: ",
   "el resumen de la partida se detuvo tras un error: ", "o resumo da partida parou após um erro: ", "冒险总结出错后已停止：", "итоги забега остановились после ошибки: ",
   "ランのまとめはエラーで停止しました：", "도전 요약이 오류로 멈췄습니다: ", "podsumowanie wyprawy zatrzymało się po błędzie: ", "oyun özeti bir hatadan sonra durdu: "),
 T("Run summary", "Résumé de partie", "Laufübersicht", "Resumen de partida", "Resumo da partida", "冒险总结", "Итоги забега", "ランのまとめ", "도전 요약", "Podsumowanie wyprawy", "Oyun özeti"),
 T("When a run ends: your time, level, kills, elites, guardians and bosses slain, damage dealt and taken, gold and caches on one panel beside the game's end screen.",
   "À la fin d'une partie : votre temps, niveau, victimes, élites, gardiens et boss tués, dégâts infligés et subis, or et coffres, sur un panneau à côté de l'écran de fin du jeu.",
   "Am Ende eines Laufs: Zeit, Stufe, Kills, getötete Elitegegner, Wächter und Bosse, verursachter und erlittener Schaden, Gold und Truhen auf einer Tafel neben dem Endbildschirm des Spiels.",
   "Al terminar una partida: tu tiempo, nivel, muertes, élites, guardianes y jefes abatidos, daño infligido y recibido, oro y alijos en un panel junto a la pantalla final del juego.",
   "Ao fim de uma partida: seu tempo, nível, abates, elites, guardiões e chefes mortos, dano causado e sofrido, ouro e baús num painel ao lado da tela final do jogo.",
   "冒险结束时：时间、等级、击杀数、击杀的精英、守护者和首领、造成和承受的伤害、金币和宝箱，显示在游戏结算画面旁的面板上。",
   "В конце забега: время, уровень, убийства, убитые элитные, стражи и боссы, нанесённый и полученный урон, золото и тайники на панели рядом с итоговым экраном игры.",
   "ラン終了時：時間、レベル、撃破数、エリート・守護者・ボスの撃破、与ダメージと被ダメージ、ゴールドと宝箱を、ゲームの終了画面の横のパネルに。",
   "도전이 끝나면: 시간, 레벨, 처치 수, 처치한 정예·수호자·우두머리, 입힌 피해와 받은 피해, 골드와 보물상자를 게임 종료 화면 옆 패널에.",
   "Na koniec wyprawy: czas, poziom, zabójstwa, zabite elity, strażnicy i bossowie, zadane i otrzymane obrażenia, złoto i skrzynie na panelu obok ekranu końcowego gry.",
   "Bir oyun bittiğinde: süren, seviyen, öldürmeler, öldürülen elitler, muhafızlar ve boss'lar, verilen ve alınan hasar, altın ve sandıklar, oyunun bitiş ekranının yanındaki bir panelde."),
 T("{1} is down!", "{1} est à terre !", "{1} ist gefallen!", "¡{1} ha caído!", "{1} caiu!", "{1} 倒下了！", "{1} пал!", "{1} が倒れた！", "{1} 쓰러짐!", "{1} padł!", "{1} düştü!"),
 T("{1} are down!", "{1} sont à terre !", "{1} sind gefallen!", "¡{1} han caído!", "{1} caíram!", "{1} 倒下了！", "{1} пали!", "{1} が倒れた！", "{1} 쓰러짐!", "{1} padli!", "{1} düştü!"),
 T("Reviving {1}", "Réanimation {1}", "Wiederbelebung {1}", "Reviviendo {1}", "Reanimando {1}", "复活中 {1}", "Воскрешение {1}", "蘇生中 {1}", "부활 중 {1}", "Wskrzeszanie {1}", "Diriltiliyor {1}"),
 T("{1} yd", "{1} m", "{1} m", "{1} m", "{1} m", "{1} 码", "{1} м", "{1} ヤード", "{1}미터", "{1} m", "{1} m"),
 T("Stand on them to bring them back.", "Tenez-vous dessus pour le ramener.", "Stell dich darauf, um sie zurückzuholen.", "Ponte encima para revivirlo.",
   "Fique sobre eles para trazê-los de volta.", "站在其身上即可将其复活。", "Встаньте на них, чтобы вернуть их.", "上に立つと復活させられます。",
   "그 위에 서면 되살릴 수 있습니다.", "Stań na nich, aby ich przywrócić.", "Geri getirmek için üstlerinde dur."),
 T("the downed friends' marks stopped after an error: ", "les marques des alliés à terre se sont arrêtées après une erreur : ",
   "die Markierungen gefallener Freunde haben nach einem Fehler gestoppt: ", "las marcas de aliados caídos se detuvieron tras un error: ",
   "as marcas de aliados caídos pararam após um erro: ", "倒地队友标记出错后已停止：", "метки павших союзников остановились после ошибки: ",
   "倒れた仲間の印はエラーで停止しました：", "쓰러진 동료 표시가 오류로 멈췄습니다: ", "znaczniki powalonych sojuszników zatrzymały się po błędzie: ",
   "düşen dost işaretleri bir hatadan sonra durdu: "),
 T("Downed friends", "Alliés à terre", "Gefallene Freunde", "Aliados caídos", "Aliados caídos", "倒地队友", "Павшие союзники", "倒れた仲間", "쓰러진 동료",
   "Powaleni sojusznicy", "Düşen dostlar"),
 T("In a party: a warning and a sound when a friend goes down, a glowing mark where they lie (stand on it to bring them back), and an arrow at the screen's edge with the distance while they're off it.",
   "En groupe : une alerte et un son quand un allié tombe, une marque lumineuse là où il gît (tenez-vous dessus pour le ramener), et une flèche au bord de l'écran avec la distance quand il est hors champ.",
   "In einer Gruppe: eine Warnung und ein Ton, wenn ein Freund fällt, eine leuchtende Markierung, wo er liegt (stell dich darauf, um ihn zurückzuholen), und ein Pfeil am Bildschirmrand mit der Entfernung, solange er außer Sicht ist.",
   "En grupo: un aviso y un sonido cuando cae un aliado, una marca brillante donde yace (ponte encima para revivirlo) y una flecha en el borde de la pantalla con la distancia mientras no se ve.",
   "Em grupo: um aviso e um som quando um aliado cai, uma marca brilhante onde ele está (fique sobre ela para trazê-lo de volta) e uma seta na borda da tela com a distância enquanto ele está fora dela.",
   "组队时：队友倒下时发出警告和声音，在其倒地处显示发光标记（站上去即可复活），不在屏幕内时在屏幕边缘显示箭头和距离。",
   "В группе: предупреждение и звук, когда союзник падает, светящаяся метка на месте (встаньте на неё, чтобы вернуть его) и стрелка у края экрана с расстоянием, пока он не виден.",
   "パーティー中：仲間が倒れると警告と音、倒れた場所に光る印（上に立つと復活）、画面外にいる間は画面端に距離付きの矢印。",
   "파티에서: 동료가 쓰러지면 경고와 소리, 쓰러진 자리에 빛나는 표시(그 위에 서면 되살림), 화면 밖에 있으면 화면 가장자리에 거리와 함께 화살표.",
   "W drużynie: ostrzeżenie i dźwięk, gdy sojusznik padnie, świecący znak w miejscu, gdzie leży (stań na nim, aby go przywrócić), i strzałka na krawędzi ekranu z odległością, gdy jest poza nim.",
   "Grupta: bir dost düştüğünde uyarı ve ses, yattığı yerde parlayan bir işaret (geri getirmek için üstünde dur) ve ekran dışındayken ekran kenarında mesafeyle bir ok."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Downed friends",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- Damage Taken, stored level-ups, the run's summary, friends down\n" + "".join(row(en, t) for en, t in P)
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
