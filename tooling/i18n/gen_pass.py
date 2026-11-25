#!/usr/bin/env python3
from gen_ui import row

PASS = {
"freestyle.learn": row("Lernen", "Impara", "Aprender", "Aprender", "Leren", "Lär dig", "Lær", "Nauka", "Učit se", "学ぶ", "배우기", "学习"),
"freestyle.watch": row("Tutorial ansehen", "Guarda un tutorial", "Ver un tutorial", "Ver um tutorial", "Tutorial kijken", "Se en tutorial", "Se en veiledning", "Zobacz tutorial", "Pustit návod", "チュートリアルを見る", "튜토리얼 보기", "看教程"),
"freestyle.mistakes": row("Häufige Fehler", "Errori frequenti", "Errores frecuentes", "Erros frequentes", "Veelgemaakte fouten", "Vanliga misstag", "Vanlige feil", "Częste błędy", "Časté chyby", "よくある失敗", "흔한 실수", "常见错误"),
"freestyle.course.beginner": row("Anfänger", "Principiante", "Principiante", "Iniciante", "Beginner", "Nybörjare", "Nybegynner", "Początkujący", "Začátečník", "初級", "초급", "入门"),
"freestyle.course.park": row("Park", "Park", "Park", "Park", "Park", "Park", "Park", "Park", "Park", "パーク", "파크", "公园"),
"freestyle.course.advanced": row("Fortgeschritten", "Avanzato", "Avanzado", "Avançado", "Gevorderd", "Avancerat", "Avansert", "Zaawansowany", "Pokročilý", "上級", "고급", "进阶"),
"tab.map": row("Karte", "Mappa", "Mapa", "Mapa", "Kaart", "Karta", "Kart", "Mapa", "Mapa", "地図", "지도", "地图"),
"map.title": row("Wo du gefahren bist", "Dove hai sciato", "Dónde has esquiado", "Onde esquiast", "Waar je skiede", "Där du åkt", "Der du har kjørt", "Gdzie jeździłaś", "Kde jsi lyžoval", "滑った場所", "탄 곳", "你滑过的地方"),
"map.empty": row("Noch kein Tag. Eine Nadel erscheint, wenn du eine Spur speicherst.", "Nessuna giornata. Un pin compare quando salvi una traccia.", "Aún no hay días. Un pin aparece al guardar un track.", "Ainda sem dias. Um alfinete aparece quando guardas um traçado.", "Nog geen dag. Een speld verschijnt als je een spoor opslaat.", "Ingen dag än. En nål syns när du sparar ett spår.", "Ingen dag ennå. En nål vises når du lagrer et spor.", "Jeszcze bez dnia. Pinezka pojawi się, gdy zapiszesz ślad.", "Zatím žádný den. Špendlík se objeví, až uložíš stopu.", "まだ日がない。トラックを保存するとピンが出る。", "아직 기록이 없어. 트랙을 저장하면 핀이 생겨.", "还没有记录。保存一条轨迹后这里会出现图钉。"),
"map.cluster": row("%d Tage", "%d giorni", "%d días", "%d dias", "%d dagen", "%d dagar", "%d dager", "%d dni", "%d dny", "%d日", "%d일", "%d 天"),
}
print("pass", len(PASS))
