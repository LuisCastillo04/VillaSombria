"""Genera las siluetas SVG de los interrogatorios en assets/siluetas.

Uso:  python tools/generar_siluetas.py

Cada figura se dibuja dos veces: una copia ámbar desplazada que hace de luz de contorno
y la silueta oscura encima. Los detalles claros (perlas, gafas, delantal) se añaden al
final. Para sustituir una silueta por arte propio basta con cambiar el campo `portrait`
del personaje en data/characters.json; no hace falta tocar este script ni el código.
"""

from pathlib import Path

OUTPUT = Path(__file__).resolve().parent.parent / "assets" / "siluetas"

TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 800 1100" width="800" height="1100">
<defs><g id="f">{body}</g></defs>
<use xlink:href="#f" fill="#e8a33d" fill-opacity="0.75" transform="translate(9,-6)"/>
<use xlink:href="#f" fill="#090b10"/>
{detail}
</svg>
"""


def pearls() -> str:
    parts = []
    for index in range(10):
        offset = (index - 4.5) / 4.5
        y = 628 + int(46 * (1 - offset * offset))
        parts.append(f'<circle cx="{310 + index * 20}" cy="{y}" r="10" fill="#e8dcc0"/>')
    return "".join(parts)


def ruffle() -> str:
    parts = []
    for index in range(6):
        offset = (index - 2.5) / 2.5
        y = 268 - int(30 * (1 - offset * offset))
        parts.append(f'<circle cx="{320 + index * 32}" cy="{y}" r="26" fill="#e6e0d2"/>')
    return "".join(parts)


def fur_stole() -> str:
    parts = []
    for index in range(7):
        offset = (index - 3) / 3
        y = 670 + int(70 * offset * offset)
        parts.append(f'<circle cx="{190 + index * 70}" cy="{y}" r="46"/>')
    return "".join(parts)


def veil() -> str:
    parts = []
    for index in range(7):
        parts.append(
            f'<path d="M{310 + index * 30},330 L{330 + index * 22},520" '
            'stroke="#c9c5b8" stroke-opacity="0.22" stroke-width="3"/>'
        )
        parts.append(
            f'<path d="M300,{340 + index * 28} L500,{322 + index * 28}" '
            'stroke="#c9c5b8" stroke-opacity="0.22" stroke-width="3"/>'
        )
    return "".join(parts)


def curls() -> str:
    circles = [
        (300, 290, 70), (376, 236, 78), (470, 250, 74), (534, 330, 66), (270, 380, 62),
        (544, 420, 58), (258, 470, 50), (300, 240, 48), (520, 500, 44), (280, 540, 42),
    ]
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in circles)


FIGURES = {
    "detective": (
        """
<path d="M40,1100 C50,860 110,730 245,668 L330,625 L330,540 L470,540 L470,625 L555,668 C690,730 750,860 760,1100 Z"/>
<path d="M322,640 L232,508 L350,566 L402,716 Z"/>
<path d="M478,640 L568,508 L450,566 L398,716 Z"/>
<ellipse cx="400" cy="415" rx="98" ry="125"/>
<path d="M292,430 L270,462 L300,470 Z"/>
<path d="M118,345 C230,292 560,284 688,322 C640,372 240,392 118,345 Z"/>
<path d="M258,328 C252,226 286,160 352,168 C372,186 420,186 446,166 C520,158 548,226 544,318 Z"/>
""",
        """
<path d="M258,312 C350,288 460,284 544,298 L544,322 C460,306 350,312 258,338 Z" fill="#c0862c"/>
<path d="M336,716 L330,1100 M470,716 L476,1100" stroke="#1d2129" stroke-width="10" fill="none"/>
""",
    ),
    "elena": (
        """
<path d="M120,1100 C140,830 190,680 300,612 C350,590 450,590 500,612 C610,680 660,830 680,1100 Z"/>
<path d="M352,440 C354,520 340,566 296,606 L504,606 C460,566 446,520 448,440 Z"/>
<ellipse cx="400" cy="350" rx="86" ry="110"/>
<path d="M300,352 C276,206 520,186 508,350 C516,270 430,240 352,268 C322,282 308,316 300,352 Z"/>
<circle cx="440" cy="200" r="72"/>
<path d="M420,140 C470,120 530,160 516,216 C500,170 460,150 420,140 Z"/>
""",
        """
<path d="M312,398 L312,438" stroke="#e8dcc0" stroke-width="5"/>
<circle cx="312" cy="446" r="11" fill="#e8dcc0"/>
<path d="M488,398 L488,438" stroke="#e8dcc0" stroke-width="5"/>
<circle cx="488" cy="446" r="11" fill="#e8dcc0"/>
"""
        + pearls(),
    ),
    "marcos": (
        """
<path d="M60,1100 C76,880 130,740 262,680 L340,640 L340,500 L462,500 L462,640 L540,680 C672,740 726,880 742,1100 Z"/>
<ellipse cx="402" cy="410" rx="96" ry="124"/>
<path d="M300,380 C270,226 396,150 520,214 C572,242 548,286 512,316 C490,262 400,262 344,304 C322,320 310,350 300,380 Z"/>
<path d="M500,206 C560,196 600,232 572,270 C556,240 530,224 500,206 Z"/>
<path d="M304,470 L194,508 L198,524 L312,496 Z"/>
<path d="M60,1100 L150,820 L232,760 L290,590 L330,600 L262,810 L190,1100 Z"/>
""",
        """
<path d="M340,640 L402,740 L462,640 L438,1100 L364,1100 Z" fill="#24272f"/>
<path d="M384,690 L422,690 L436,960 L404,1000 L372,960 Z" fill="#7a2a2a"/>
<path d="M210,508 L306,476" stroke="#e8dcc0" stroke-width="9"/>
<circle cx="204" cy="512" r="9" fill="#e8a33d"/>
<path d="M198,496 C170,440 226,410 190,350 C170,312 206,280 186,232" stroke="#9aa3b0" stroke-opacity="0.55" stroke-width="8" fill="none"/>
""",
    ),
    "lucia": (
        """
<path d="M140,1100 C150,880 170,760 250,690 C290,650 340,630 350,626 L350,490 L450,490 L450,626 C460,630 510,650 550,690 C630,760 650,880 660,1100 Z"/>
<circle cx="214" cy="760" r="92"/>
<circle cx="586" cy="760" r="92"/>
<ellipse cx="400" cy="400" rx="88" ry="112"/>
<path d="M308,404 C290,270 510,270 492,404 C470,340 330,340 308,404 Z"/>
<path d="M296,350 C262,430 276,520 300,600 C318,660 312,720 296,790 L344,782 C358,700 352,620 330,540 C312,470 316,410 330,366 Z"/>
<circle cx="316" cy="808" r="26"/>
""",
        ruffle()
        + """
<path d="M322,278 C360,262 440,262 478,278 L470,318 C430,300 370,300 330,318 Z" fill="#e6e0d2"/>
<path d="M348,640 L452,640 L470,1100 L330,1100 Z" fill="#d6d0c2" fill-opacity="0.85"/>
<path d="M348,640 L300,690 M452,640 L500,690" stroke="#d6d0c2" stroke-width="22"/>
<path d="M340,612 L400,664 L460,612 L430,600 L400,624 L370,600 Z" fill="#e6e0d2"/>
""",
    ),
    "anselmo": (
        """
<path d="M110,1100 C124,900 160,760 262,696 L342,652 L342,510 L458,510 L458,652 L538,696 C640,760 676,900 690,1100 Z"/>
<ellipse cx="400" cy="400" rx="92" ry="138"/>
<path d="M312,380 C284,396 288,470 322,500 Z"/>
<path d="M488,380 C516,396 512,470 478,500 Z"/>
<path d="M540,700 L640,676 L676,700 L668,744 L560,790 Z"/>
<ellipse cx="682" cy="668" rx="118" ry="16"/>
<path d="M650,650 L660,588 L694,588 L704,650 Z"/>
<path d="M660,588 L668,540 L686,540 L694,588 Z"/>
""",
        """
<path d="M342,640 L400,720 L458,640 L446,596 L354,596 Z" fill="#dcd6c8"/>
<path d="M342,596 L304,640 L376,676 L400,650 Z" fill="#dcd6c8"/>
<path d="M458,596 L496,640 L424,676 L400,650 Z" fill="#dcd6c8"/>
<path d="M336,638 L400,664 L464,638 L464,696 L400,670 L336,696 Z" fill="#050608"/>
<path d="M380,720 L420,720 L438,1100 L362,1100 Z" fill="#dcd6c8" fill-opacity="0.9"/>
<circle cx="400" cy="800" r="7" fill="#050608"/>
<circle cx="402" cy="900" r="7" fill="#050608"/>
<path d="M560,676 L676,652" stroke="#9aa0aa" stroke-width="8"/>
""",
    ),
    "irene": (
        """
<path d="M90,1100 C110,870 160,740 280,684 L346,646 L346,500 L454,500 L454,646 L520,684 C640,740 690,870 710,1100 Z"/>
<ellipse cx="400" cy="420" rx="86" ry="114"/>
<path d="M312,430 C280,540 306,590 348,600 L352,470 Z"/>
<path d="M488,430 C520,540 494,590 452,600 L448,470 Z"/>
<path d="M60,356 C200,250 560,214 742,246 C708,316 250,410 60,356 Z"/>
<path d="M286,300 C280,200 340,150 410,160 C480,168 520,214 516,272 Z"/>
<path d="M506,250 C560,150 640,100 700,120 C664,170 590,230 530,270 Z"/>
"""
        + fur_stole(),
        """
<path d="M286,268 C350,246 440,232 516,240 L518,268 C440,262 350,274 288,296 Z" fill="#7a2a2a"/>
"""
        + veil()
        + """
<path d="M196,560 L332,508" stroke="#c9c5b8" stroke-width="8"/>
<circle cx="188" cy="563" r="8" fill="#e8a33d"/>
<path d="M186,548 C168,496 216,462 188,404" stroke="#9aa3b0" stroke-opacity="0.5" stroke-width="7" fill="none"/>
""",
    ),
    "ortega": (
        """
<path d="M30,1100 C40,880 96,740 240,680 L326,640 L326,556 L474,556 L474,640 L560,680 C704,740 760,880 770,1100 Z"/>
<ellipse cx="400" cy="430" rx="112" ry="126"/>
<path d="M270,496 C222,500 196,478 186,446 C230,478 300,462 400,462 C500,462 570,478 614,446 C604,478 578,500 530,496 Z"/>
<path d="M286,330 L268,186 C330,160 470,160 532,186 L514,330 Z"/>
<path d="M254,330 L546,330 L584,372 C460,352 340,352 216,372 Z"/>
<path d="M128,676 L286,650 L300,696 L150,732 Z"/>
<path d="M672,676 L514,650 L500,696 L650,732 Z"/>
""",
        """
<path d="M268,300 L532,300 L528,330 L272,330 Z" fill="#c9a24d"/>
<path d="M380,206 L420,206 L428,250 L400,274 L372,250 Z" fill="#c9a24d"/>
<path d="M150,690 L286,668 M150,712 L286,690" stroke="#c9a24d" stroke-width="6"/>
<path d="M514,668 L650,690 M514,690 L650,712" stroke="#c9a24d" stroke-width="6"/>
<path d="M400,640 L400,1100" stroke="#20283a" stroke-width="12"/>
<circle cx="400" cy="760" r="11" fill="#c9a24d"/>
<circle cx="400" cy="870" r="11" fill="#c9a24d"/>
<circle cx="400" cy="980" r="11" fill="#c9a24d"/>
<path d="M254,780 L322,780 L322,850 L288,872 L254,850 Z" fill="#c9a24d"/>
""",
    ),
    "rosa": (
        """
<path d="M70,1100 C86,890 130,760 250,700 C300,670 340,650 348,640 L348,520 L452,520 L452,640 C460,650 500,670 550,700 C670,760 714,890 730,1100 Z"/>
<ellipse cx="400" cy="430" rx="96" ry="116"/>
"""
        + curls(),
        """
<circle cx="296" cy="520" r="26" fill="none" stroke="#c9a24d" stroke-width="8"/>
<circle cx="504" cy="520" r="26" fill="none" stroke="#c9a24d" stroke-width="8"/>
<path d="M340,700 L460,700 L510,1100 L290,1100 Z" fill="#d6d0c2" fill-opacity="0.85"/>
<path d="M340,700 L322,640 M460,700 L478,640" stroke="#d6d0c2" stroke-width="20"/>
<path d="M470,200 L590,150" stroke="#e8a33d" stroke-width="12"/>
""",
    ),
    "eusebio": (
        """
<path d="M60,1100 C74,900 120,760 250,700 L330,660 L330,530 L470,530 L470,660 L550,700 C680,760 726,900 740,1100 Z"/>
<ellipse cx="400" cy="440" rx="106" ry="122"/>
<path d="M280,520 C290,470 340,486 400,486 C460,486 510,470 520,520 C520,580 470,560 400,560 C330,560 280,580 280,520 Z"/>
<path d="M256,350 C230,230 300,196 400,196 C500,196 570,230 544,350 Z"/>
<path d="M270,346 L530,346 L566,396 C460,376 340,376 234,396 Z"/>
""",
        """
<path d="M270,312 L530,312 L532,346 L268,346 Z" fill="#c9a24d"/>
<path d="M376,236 L424,236 L424,284 L376,284 Z" fill="#c9a24d"/>
<circle cx="352" cy="440" r="42" fill="#cdd8e6" fill-opacity="0.3" stroke="#cdd8e6" stroke-width="8"/>
<circle cx="448" cy="440" r="42" fill="#cdd8e6" fill-opacity="0.3" stroke="#cdd8e6" stroke-width="8"/>
<path d="M392,436 L408,436" stroke="#cdd8e6" stroke-width="8"/>
<path d="M300,690 C340,810 460,840 520,760" stroke="#c9a24d" stroke-width="7" fill="none"/>
<path d="M520,756 L556,742 L566,772 L530,786 Z" fill="#c9a24d"/>
<path d="M400,660 L400,1100" stroke="#1d2129" stroke-width="10"/>
""",
    ),
    "hilario": (
        """
<path d="M160,1100 C170,910 200,770 280,716 L352,676 L352,500 L448,500 L448,676 L520,716 C600,770 630,910 640,1100 Z"/>
<ellipse cx="400" cy="400" rx="96" ry="130"/>
<ellipse cx="298" cy="420" rx="22" ry="40"/>
<ellipse cx="502" cy="420" rx="22" ry="40"/>
<path d="M300,330 C330,262 470,262 500,330 C460,290 420,300 380,280 C352,296 322,300 300,330 Z"/>
<path d="M60,780 L300,740 L330,1000 L90,1040 Z"/>
<path d="M90,740 L320,706 L342,960 L110,996 Z"/>
""",
        """
<circle cx="356" cy="404" r="40" fill="#cdd8e6" fill-opacity="0.32" stroke="#cdd8e6" stroke-width="7"/>
<circle cx="444" cy="404" r="40" fill="#cdd8e6" fill-opacity="0.32" stroke="#cdd8e6" stroke-width="7"/>
<path d="M396,400 L404,400" stroke="#cdd8e6" stroke-width="7"/>
<path d="M352,660 L400,690 L448,660 L448,716 L400,694 L352,716 Z" fill="#7a2a2a"/>
<path d="M110,760 L320,726 M114,790 L324,756 M118,820 L328,786 M122,850 L332,816" stroke="#b5a482" stroke-opacity="0.65" stroke-width="7"/>
""",
    ),
}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, (body, detail) in FIGURES.items():
        svg = TEMPLATE.format(body=body.strip(), detail=detail.strip())
        (OUTPUT / f"{name}.svg").write_text(svg, encoding="utf-8", newline="\n")
    print(f"{len(FIGURES)} siluetas escritas en {OUTPUT}")


if __name__ == "__main__":
    main()
