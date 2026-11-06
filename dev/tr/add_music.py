# 1.23.0: the music button
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Music", "Musique", "Musik", "Música", "Música", "音乐", "Музыка", "音楽", "음악", "Muzyka", "Müzik"),
 T("Song {1} of {2}", "Chanson {1} sur {2}", "Lied {1} von {2}", "Canción {1} de {2}", "Música {1} de {2}", "第 {1} 首，共 {2} 首", "Песня {1} из {2}", "{2} 曲中 {1} 曲目", "{2}곡 중 {1}번째", "Utwór {1} z {2}", "{2} şarkıdan {1}."),
 T("Click: play", "Clic : lecture", "Klick: abspielen", "Clic: reproducir", "Clique: tocar", "点击：播放", "Щелчок: играть", "クリック：再生", "클릭: 재생", "Klik: odtwórz", "Tıkla: çal"),
 T("Click: pause (the song starts over)", "Clic : pause (la chanson reprend du début)", "Klick: Pause (das Lied beginnt von vorn)", "Clic: pausa (la canción vuelve a empezar)", "Clique: pausar (a música recomeça)", "点击：暂停（歌曲会从头开始）", "Щелчок: пауза (песня начнётся сначала)", "クリック：一時停止（曲は最初からになります）", "클릭: 일시정지 (곡은 처음부터 다시)", "Klik: pauza (utwór zacznie się od nowa)", "Tıkla: duraklat (şarkı baştan başlar)"),
 T("Right-click: next song", "Clic droit : chanson suivante", "Rechtsklick: nächstes Lied", "Clic derecho: siguiente canción", "Clique direito: próxima música", "右键：下一首", "ПКМ: следующая песня", "右クリック：次の曲", "우클릭: 다음 곡", "Prawy klik: następny utwór", "Sağ tık: sonraki şarkı"),
 T("Put your songs in Interface\\AddOns\\CreedUI\\Music, named 1.mp3, 2.mp3 and so on", "Mettez vos chansons dans Interface\\AddOns\\CreedUI\\Music, nommées 1.mp3, 2.mp3 et ainsi de suite", "Lege deine Lieder in Interface\\AddOns\\CreedUI\\Music, benannt 1.mp3, 2.mp3 und so weiter", "Pon tus canciones en Interface\\AddOns\\CreedUI\\Music, llamadas 1.mp3, 2.mp3, etc.", "Coloque suas músicas em Interface\\AddOns\\CreedUI\\Music, chamadas 1.mp3, 2.mp3 e assim por diante", "把你的歌曲放进 Interface\\AddOns\\CreedUI\\Music，命名为 1.mp3、2.mp3 等", "Положите свои песни в Interface\\AddOns\\CreedUI\\Music с именами 1.mp3, 2.mp3 и так далее", "曲を Interface\\AddOns\\CreedUI\\Music に 1.mp3、2.mp3 … の名前で入れてください", "곡을 Interface\\AddOns\\CreedUI\\Music 에 1.mp3, 2.mp3 … 이름으로 넣으세요", "Umieść swoje utwory w Interface\\AddOns\\CreedUI\\Music, nazwane 1.mp3, 2.mp3 i tak dalej", "Şarkılarını Interface\\AddOns\\CreedUI\\Music içine 1.mp3, 2.mp3 diye adlandırıp koy"),
 T("Music volume: {1}", "Volume de la musique : {1}", "Musiklautstärke: {1}", "Volumen de la música: {1}", "Volume da música: {1}", "音乐音量：{1}", "Громкость музыки: {1}", "音楽の音量：{1}", "음악 음량: {1}", "Głośność muzyki: {1}", "Müzik sesi: {1}"),
 T("music: {1} songs", "musique : {1} chansons", "Musik: {1} Lieder", "música: {1} canciones", "música: {1} músicas", "音乐：{1} 首", "музыка: песен {1}", "音楽：{1} 曲", "음악: {1}곡", "muzyka: {1} utworów", "müzik: {1} şarkı"),
 T("/creed music followed by how many songs there are (now {1})", "/creed music suivi du nombre de chansons (actuellement {1})", "/creed music gefolgt von der Anzahl der Lieder (jetzt {1})", "/creed music seguido de cuántas canciones hay (ahora {1})", "/creed music seguido de quantas músicas há (agora {1})", "/creed music 后接歌曲数量（当前 {1}）", "/creed music и число песен (сейчас {1})", "/creed music の後に曲の数（今は {1}）", "/creed music 뒤에 곡 수 (지금 {1})", "/creed music, a po nim liczba utworów (teraz {1})", "/creed music ardından şarkı sayısı (şu an {1})"),
 T("Music button", "Bouton musique", "Musikknopf", "Botón de música", "Botão de música", "音乐按钮", "Кнопка музыки", "音楽ボタン", "음악 버튼", "Przycisk muzyki", "Müzik düğmesi"),
 T("A play button on the minimap's edge for your own songs: click to play or pause, right-click for the next one. Put them in Interface\\AddOns\\CreedUI\\Music named 1.mp3, 2.mp3...; /creed music <number> says how many. The volume is beside the language.",
   "Un bouton lecture au bord de la minicarte pour vos propres chansons : clic pour lire ou mettre en pause, clic droit pour la suivante. Mettez-les dans Interface\\AddOns\\CreedUI\\Music nommées 1.mp3, 2.mp3... ; /creed music <nombre> indique combien. Le volume est à côté de la langue.",
   "Ein Abspielknopf am Rand der Minikarte für deine eigenen Lieder: Klick spielt oder pausiert, Rechtsklick nimmt das nächste. Lege sie in Interface\\AddOns\\CreedUI\\Music als 1.mp3, 2.mp3...; /creed music <Zahl> sagt, wie viele. Die Lautstärke steht neben der Sprache.",
   "Un botón de reproducción en el borde del minimapa para tus propias canciones: clic para reproducir o pausar, clic derecho para la siguiente. Ponlas en Interface\\AddOns\\CreedUI\\Music llamadas 1.mp3, 2.mp3...; /creed music <número> indica cuántas. El volumen está junto al idioma.",
   "Um botão de tocar na borda do minimapa para as suas próprias músicas: clique para tocar ou pausar, clique direito para a próxima. Coloque-as em Interface\\AddOns\\CreedUI\\Music chamadas 1.mp3, 2.mp3...; /creed music <número> diz quantas. O volume fica ao lado do idioma.",
   "小地图边缘的播放按钮，播放你自己的歌曲：点击播放或暂停，右键下一首。把歌曲放进 Interface\\AddOns\\CreedUI\\Music，命名为 1.mp3、2.mp3…；/creed music <数字> 设定数量。音量在语言旁边。",
   "Кнопка воспроизведения на краю мини-карты для ваших песен: щелчок — играть или пауза, ПКМ — следующая. Положите их в Interface\\AddOns\\CreedUI\\Music с именами 1.mp3, 2.mp3...; /creed music <число> задаёт их количество. Громкость — рядом с языком.",
   "ミニマップの縁にある自分の曲の再生ボタン：クリックで再生・一時停止、右クリックで次の曲。Interface\\AddOns\\CreedUI\\Music に 1.mp3、2.mp3… の名前で入れ、/creed music <数> で曲数を指定。音量は言語の隣です。",
   "미니맵 가장자리의 내 곡 재생 버튼: 클릭으로 재생·일시정지, 우클릭으로 다음 곡. Interface\\AddOns\\CreedUI\\Music 에 1.mp3, 2.mp3… 이름으로 넣고 /creed music <수> 로 곡 수를 정하세요. 음량은 언어 옆에 있습니다.",
   "Przycisk odtwarzania na krawędzi minimapy dla twoich utworów: klik odtwarza lub pauzuje, prawy klik — następny. Umieść je w Interface\\AddOns\\CreedUI\\Music jako 1.mp3, 2.mp3...; /creed music <liczba> mówi ile. Głośność jest obok języka.",
   "Mini haritanın kenarında kendi şarkıların için çal düğmesi: tıkla çal ya da duraklat, sağ tıkla sonraki. Onları Interface\\AddOns\\CreedUI\\Music içine 1.mp3, 2.mp3... diye koy; /creed music <sayı> kaç tane olduğunu söyler. Ses düzeyi dilin yanında."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if "{ \"Right-click: next song\"," not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the music button (1.23.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
