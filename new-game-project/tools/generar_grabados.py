"""Genera los grabados sepia del expediente (assets/ui/expediente) y del tablero (assets/ui/tablero).

Uso:  python tools/generar_grabados.py

Son ilustraciones de línea, con tramas y sombreados, en la tinta y los pergaminos del grabado de la
mansión (`assets/ui/mansion_grabado.svg`). El fondo es transparente para que se asienten sobre
cualquier pergamino. Cada grabado es un SVG normal: para sustituirlo por arte propio basta con
reemplazar el archivo con el mismo nombre; el código del expediente no cambia.
"""

import math
import random
from pathlib import Path

OUTPUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "expediente"
BOARD_OUTPUT = OUTPUT.parent / "tablero"

INK = "#3d2a1b"
SEPIA = "#b89d72"
SEPIA_LIGHT = "#c3a77c"
SEPIA_PALE = "#d6bf96"
SEPIA_DARK = "#7f5f40"
GLOW = "#f4c86c"
PAPER = "#efe0bd"
STRING = "#8a2632"
BRASS = "#a8823f"


class Engraving:
    def __init__(self, width: int, height: int, seed: int) -> None:
        self.width = width
        self.height = height
        self.parts: list[str] = []
        self.defs: list[str] = []
        self.random = random.Random(seed)
        self._clip_count = 0

    # --- Primitivas ---

    def add(self, text: str) -> None:
        self.parts.append(text)

    @staticmethod
    def _style(fill, fill_opacity, stroke, width, opacity) -> str:
        style = f' fill="{fill or "none"}"'
        if fill and fill_opacity < 1.0:
            style += f' fill-opacity="{fill_opacity:.2f}"'
        if stroke:
            style += f' stroke="{stroke}" stroke-width="{width:.2f}" stroke-linecap="round" stroke-linejoin="round"'
            if opacity < 1.0:
                style += f' stroke-opacity="{opacity:.2f}"'
        return style

    def line(self, x1, y1, x2, y2, width=1.0, opacity=1.0, color=INK) -> None:
        self.add(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}"{self._style(None, 1, color, width, opacity)}/>')

    def rect(self, x, y, w, h, fill=None, fill_opacity=1.0, stroke=INK, width=1.2, opacity=1.0, rx=0.0) -> None:
        corner = f' rx="{rx:.1f}"' if rx else ""
        self.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}"{corner}{self._style(fill, fill_opacity, stroke, width, opacity)}/>')

    def path(self, d, fill=None, fill_opacity=1.0, stroke=INK, width=1.2, opacity=1.0, extra="") -> None:
        self.add(f'<path d="{d}"{self._style(fill, fill_opacity, stroke, width, opacity)}{extra}/>')

    def poly(self, points, fill=None, fill_opacity=1.0, stroke=INK, width=1.2, opacity=1.0, closed=True) -> None:
        d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in points) + (" Z" if closed else "")
        self.path(d, fill, fill_opacity, stroke, width, opacity)

    def circle(self, cx, cy, r, fill=None, fill_opacity=1.0, stroke=INK, width=1.2, opacity=1.0) -> None:
        self.add(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}"{self._style(fill, fill_opacity, stroke, width, opacity)}/>')

    def ellipse(self, cx, cy, rx, ry, fill=None, fill_opacity=1.0, stroke=INK, width=1.2, opacity=1.0) -> None:
        self.add(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}"{self._style(fill, fill_opacity, stroke, width, opacity)}/>')

    def begin_group(self, transform: str = "", clip: str = "") -> None:
        attributes = ""
        if transform:
            attributes += f' transform="{transform}"'
        if clip:
            attributes += f' clip-path="url(#{clip})"'
        self.add(f"<g{attributes}>")

    def end_group(self) -> None:
        self.add("</g>")

    def clip_polygon(self, points) -> str:
        self._clip_count += 1
        name = f"c{self._clip_count}"
        d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in points) + " Z"
        self.defs.append(f'<clipPath id="{name}"><path d="{d}"/></clipPath>')
        return name

    # --- Tramas ---

    def hatch(self, points, spacing=4.0, angle=60.0, width=0.8, opacity=0.45, color=INK) -> None:
        """Trama de líneas paralelas recortada al polígono `points`."""
        clip = self.clip_polygon(points)
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        cx = (min(xs) + max(xs)) * 0.5
        cy = (min(ys) + max(ys)) * 0.5
        reach = math.hypot(max(xs) - min(xs), max(ys) - min(ys)) * 0.5 + 2.0
        radians = math.radians(angle)
        direction = (math.cos(radians), math.sin(radians))
        normal = (-direction[1], direction[0])
        self.begin_group(clip=clip)
        offset = -reach
        while offset <= reach:
            px = cx + normal[0] * offset
            py = cy + normal[1] * offset
            self.line(px - direction[0] * reach, py - direction[1] * reach, px + direction[0] * reach, py + direction[1] * reach, width, opacity, color)
            offset += spacing
        self.end_group()

    def hatch_rect(self, x, y, w, h, **kwargs) -> None:
        self.hatch([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], **kwargs)

    # --- Elementos comunes ---

    def ground(self, y, x0=0.0, x1=None, fade=40.0) -> None:
        x1 = self.width if x1 is None else x1
        name = f"suelo{len(self.defs)}"
        self.defs.append(
            f'<linearGradient id="{name}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{SEPIA}" stop-opacity="0.5"/><stop offset="1" stop-color="{SEPIA}" stop-opacity="0"/></linearGradient>'
        )
        self.add(f'<rect x="{x0:.1f}" y="{y:.1f}" width="{x1 - x0:.1f}" height="{fade:.1f}" fill="url(#{name})"/>')
        self.path(f"M{x0:.1f},{y:.1f} Q{(x0 + x1) * 0.5:.1f},{y - 3:.1f} {x1:.1f},{y + 1:.1f}", width=1.3)
        for _ in range(int((x1 - x0) / 9)):
            gx = self.random.uniform(x0 + 6, x1 - 6)
            gy = self.random.uniform(y + 5, y + fade * 0.7)
            self.line(gx, gy, gx + self.random.uniform(-1.5, 1.5), gy - self.random.uniform(2.5, 5), 0.8, 0.45)

    def glow(self, cx, cy, r, opacity=0.8) -> None:
        name = f"luz{len(self.defs)}"
        self.defs.append(
            f'<radialGradient id="{name}"><stop offset="0" stop-color="#ffd88a" stop-opacity="{opacity:.2f}"/>'
            f'<stop offset="1" stop-color="#ffd88a" stop-opacity="0"/></radialGradient>'
        )
        self.add(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="url(#{name})"/>')

    def text_lines(self, x, y, w, rows, spacing=6.0, opacity=0.55, width=0.9) -> None:
        """Renglones de escritura: trazos cortos de longitud variable."""
        for row in range(rows):
            length = w * (0.55 + 0.45 * self.random.random()) if row < rows - 1 else w * 0.45
            cursor = x
            while cursor < x + length:
                word = min(self.random.uniform(6, 18), x + length - cursor)
                self.line(cursor, y + row * spacing, cursor + word, y + row * spacing, width, opacity)
                cursor += word + self.random.uniform(2.5, 4.5)

    def paper(self, cx, cy, w, h, angle, rows=6, fill=PAPER, fold=True) -> None:
        self.begin_group(f"rotate({angle:.1f} {cx:.1f} {cy:.1f})")
        x = cx - w * 0.5
        y = cy - h * 0.5
        self.rect(x + 2.5, y + 3, w, h, fill=SEPIA_DARK, fill_opacity=0.25, stroke=None)
        if fold:
            corner = min(w, h) * 0.16
            self.poly([(x, y), (x + w - corner, y), (x + w, y + corner), (x + w, y + h), (x, y + h)], fill=fill, width=1.1)
            self.poly([(x + w - corner, y), (x + w - corner, y + corner), (x + w, y + corner)], fill=SEPIA_LIGHT, width=0.9)
        else:
            self.rect(x, y, w, h, fill=fill, width=1.1)
        self.text_lines(x + w * 0.12, y + h * 0.2, w * 0.74, rows, spacing=(h * 0.66) / max(rows, 1))
        self.end_group()

    def book(self, x, y, w, h, fill=SEPIA_LIGHT, bands=2) -> None:
        """Libro tumbado visto de frente: lomo con nervios y el canto de las páginas."""
        self.rect(x, y, w, h, fill=fill, width=1.2, rx=1.5)
        self.rect(x + w - 10, y + 2, 8, h - 4, fill=PAPER, width=0.8)
        for page in range(1, 4):
            self.line(x + w - 10, y + 2 + page * (h - 4) / 4, x + w - 2, y + 2 + page * (h - 4) / 4, 0.6, 0.5)
        for band in range(bands):
            bx = x + 10 + band * 9
            self.line(bx, y + 1, bx, y + h - 1, 1.0, 0.8)
        self.hatch_rect(x + 1, y + h * 0.55, w - 12, h * 0.45 - 1, spacing=3.2, angle=0, opacity=0.3)

    def standing_book(self, x, y, w, h, fill=SEPIA_LIGHT, lean=0.0) -> None:
        cx = x + w * 0.5
        self.begin_group(f"rotate({lean:.1f} {cx:.1f} {y + h:.1f})")
        self.rect(x, y, w, h, fill=fill, width=1.2, rx=1.2)
        for band in (0.14, 0.22, 0.78, 0.86):
            self.line(x + 1.5, y + h * band, x + w - 1.5, y + h * band, 0.9, 0.75)
        self.rect(x + w * 0.22, y + h * 0.36, w * 0.56, h * 0.2, stroke=INK, width=0.8, opacity=0.7)
        self.hatch_rect(x + w * 0.6, y + 1, w * 0.4 - 1, h - 2, spacing=2.8, angle=90, opacity=0.35)
        self.end_group()

    def pin(self, x, y, color=STRING) -> None:
        self.ellipse(x + 1.5, y + 2.5, 5.5, 3.5, fill=SEPIA_DARK, fill_opacity=0.35, stroke=None)
        self.circle(x, y, 5.6, fill=color, width=1.0)
        self.circle(x - 1.6, y - 1.8, 1.6, fill="#f3d9b0", fill_opacity=0.8, stroke=None)

    def write(self, name: str, folder: Path = OUTPUT) -> None:
        folder.mkdir(parents=True, exist_ok=True)
        header = f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">\n'
        defs = "<defs>" + "".join(self.defs) + "</defs>\n" if self.defs else ""
        body = "\n".join(self.parts)
        (folder / name).write_text(header + defs + body + "\n</svg>\n", encoding="utf-8", newline="\n")


# --- Café La Luna, con su farola y sus veladores: la página de sospechosos ---

def cafe() -> None:
    art = Engraving(600, 430, 11)
    # Árboles del fondo, a la derecha.
    for cx, cy, r in [(548, 214, 30), (575, 190, 26), (530, 186, 24), (590, 230, 22), (556, 240, 20)]:
        art.circle(cx, cy, r, fill=SEPIA, fill_opacity=0.45, width=0.9, opacity=0.8)
        art.hatch([(cx - r, cy), (cx, cy - r * 0.2), (cx + r, cy + r * 0.2), (cx + r * 0.6, cy + r), (cx - r * 0.5, cy + r)], spacing=3.0, angle=50, opacity=0.3)
    art.path("M556,250 L552,368 M553,300 L572,268 M554,320 L536,292", width=2.2)
    # Fachada.
    art.rect(118, 52, 400, 316, fill=SEPIA_PALE, fill_opacity=0.75, width=1.5)
    for row in range(1, 22):
        y = 52 + row * 14
        if y < 368:
            art.line(119, y, 517, y, 0.6, 0.22)
    art.hatch_rect(470, 53, 47, 314, spacing=3.4, angle=90, opacity=0.35)
    # Cornisa y alero.
    art.rect(106, 36, 424, 18, fill=SEPIA_LIGHT, width=1.4)
    art.rect(112, 30, 412, 7, fill=SEPIA, fill_opacity=0.6, width=1.0)
    for x in range(118, 524, 14):
        art.line(x, 54, x, 60, 0.9, 0.7)
    art.line(118, 150, 518, 150, 1.4)
    art.rect(112, 146, 412, 6, fill=SEPIA_LIGHT, width=1.0)
    # Ventanas del piso de arriba, con contraventanas y balcón.
    for wx in (156, 296, 436):
        art.rect(wx - 8, 72, 8, 56, fill=SEPIA, fill_opacity=0.55, width=0.9)
        art.rect(wx + 44, 72, 8, 56, fill=SEPIA, fill_opacity=0.55, width=0.9)
        for slat in range(1, 8):
            art.line(wx - 8, 72 + slat * 7, wx, 72 + slat * 7, 0.6, 0.6)
            art.line(wx + 44, 72 + slat * 7, wx + 52, 72 + slat * 7, 0.6, 0.6)
        art.glow(wx + 22, 100, 34, 0.45)
        art.rect(wx, 70, 44, 60, fill=GLOW, fill_opacity=0.65, width=1.3)
        art.line(wx + 22, 70, wx + 22, 130, 1.0)
        art.line(wx, 96, wx + 44, 96, 1.0)
        art.rect(wx - 12, 130, 68, 5, fill=SEPIA_LIGHT, width=1.0)
        for bar in range(6):
            art.line(wx - 8 + bar * 12, 135, wx - 8 + bar * 12, 144, 0.8, 0.8)
    # Rótulo con la luna.
    art.rect(214, 160, 208, 32, fill=SEPIA_DARK, fill_opacity=0.85, width=1.4, rx=2)
    art.rect(219, 165, 198, 22, stroke=GLOW, width=0.9, opacity=0.8, rx=1.5)
    art.path("M322,166 A10,10 0 1 0 322,186 A7.5,7.5 0 1 1 322,166 Z", fill=GLOW, width=0.6)
    for side in (-1, 1):
        art.line(318 + side * 22, 176, 318 + side * 82, 176, 1.2, 0.85, GLOW)
        art.circle(318 + side * 88, 176, 2.6, fill=GLOW, stroke=None)
    # Toldo a rayas con el borde festoneado.
    awning = [(126, 198), (510, 198), (530, 236), (106, 236)]
    art.poly(awning, fill=PAPER, width=1.4)
    for stripe in range(12):
        x0 = 126 + stripe * 32
        x1 = x0 + 16
        art.poly([(x0, 198), (x1, 198), (106 + (x1 - 126) * (424 / 384), 236), (106 + (x0 - 126) * (424 / 384), 236)], fill=SEPIA, fill_opacity=0.75, width=0.6)
    scallops = "M106,236 " + " ".join(f"Q{106 + i * 26.5 + 13.25:.1f},{250} {106 + (i + 1) * 26.5:.1f},236" for i in range(16))
    art.path(scallops, fill=PAPER, width=1.2)
    art.hatch_rect(106, 237, 424, 14, spacing=3, angle=0, opacity=0.3)
    # Escaparates y puerta.
    for sx in (138, 384):
        art.glow(sx + 57, 300, 70, 0.55)
        art.rect(sx, 254, 114, 96, fill=GLOW, fill_opacity=0.6, width=1.5)
        art.line(sx + 57, 254, sx + 57, 350, 1.1)
        art.line(sx, 280, sx + 114, 280, 1.0)
        art.rect(sx - 4, 350, 122, 8, fill=SEPIA_LIGHT, width=1.0)
        for cup in range(3):
            art.path(f"M{sx + 18 + cup * 30},{328} h12 v6 a6,4 0 0 1 -12,0 z", fill=SEPIA_DARK, fill_opacity=0.6, width=0.8)
    art.rect(282, 252, 72, 116, fill=SEPIA_DARK, fill_opacity=0.75, width=1.5)
    art.rect(290, 262, 56, 46, fill=GLOW, fill_opacity=0.55, width=1.0)
    art.line(318, 262, 318, 308, 0.9)
    art.hatch_rect(290, 314, 56, 50, spacing=3, angle=90, opacity=0.4)
    art.circle(340, 318, 2.4, fill=GLOW, stroke=None)
    # Suelo y adoquines.
    art.ground(368, 0, 600, 56)
    for row in range(3):
        y = 376 + row * 12
        for x in range(10 + row * 9, 600, 26):
            art.path(f"M{x},{y} q6,-3 13,0", width=0.7, opacity=0.35)
    # Veladores con sillas.
    for tx in (178, 438):
        art.ellipse(tx, 334, 24, 6, fill=PAPER, width=1.2)
        art.line(tx, 340, tx, 380, 1.6)
        art.ellipse(tx, 382, 12, 3, fill=SEPIA, width=1.0)
        for side in (-1, 1):
            cx = tx + side * 40
            art.path(f"M{cx - side * 8},{388} L{cx - side * 6},{352} M{cx + side * 8},{388} L{cx + side * 6},{358} M{cx - side * 9},{358} L{cx + side * 9},{358}", width=1.3)
            art.path(f"M{cx - side * 6},{352} C{cx - side * 9},{334} {cx - side * 2},{324} {cx + side * 6},{328}", width=1.3)
            art.ellipse(cx, 358, 10, 3, fill=SEPIA_LIGHT, width=0.9)
    # Farola de forja a la izquierda.
    art.glow(62, 112, 64, 0.85)
    art.path("M52,386 L72,386 L68,376 L56,376 Z", fill=SEPIA_DARK, width=1.2)
    art.rect(58, 160, 8, 216, fill=SEPIA_DARK, fill_opacity=0.9, width=1.2)
    art.path("M62,166 C46,160 46,146 58,146 M62,166 C78,160 78,146 66,146", width=1.2)
    art.path("M48,136 L76,136 L72,96 L52,96 Z", fill=GLOW, fill_opacity=0.85, width=1.4)
    art.line(62, 96, 62, 136, 0.9, 0.7)
    art.path("M44,96 L80,96 L62,78 Z", fill=SEPIA_DARK, width=1.3)
    art.circle(62, 74, 3.5, fill=SEPIA_DARK, width=1.0)
    art.rect(50, 136, 24, 8, fill=SEPIA_DARK, width=1.1)
    art.write("cafe_la_luna.svg")


# --- Escritorio con libros, papeles y máquina de escribir: la página de pistas ---

def escritorio() -> None:
    art = Engraving(560, 320, 23)
    art.ground(282, 10, 550, 34)
    # Libros de pie y tumbados, a la izquierda.
    art.standing_book(40, 132, 30, 148, SEPIA_LIGHT, -2)
    art.standing_book(72, 120, 26, 160, SEPIA, 0)
    art.standing_book(99, 140, 34, 140, SEPIA_PALE, 0)
    art.standing_book(134, 150, 24, 130, SEPIA_LIGHT, 9)
    art.book(30, 262, 150, 20, SEPIA)
    art.book(42, 244, 130, 18, SEPIA_PALE)
    # Legajo y hojas sueltas.
    art.paper(232, 262, 120, 40, -4, rows=3)
    art.paper(214, 252, 100, 34, 8, rows=3)
    # Máquina de escribir.
    art.paper(392, 104, 120, 112, -2, rows=8, fold=False)
    art.rect(318, 150, 168, 22, fill=SEPIA_DARK, width=1.4, rx=10)
    art.hatch_rect(320, 152, 164, 18, spacing=3, angle=0, opacity=0.45)
    art.circle(312, 161, 9, fill=SEPIA_DARK, width=1.2)
    art.circle(492, 161, 9, fill=SEPIA_DARK, width=1.2)
    art.path("M492,150 C506,140 520,138 528,142", width=2.0)
    art.path("M308,174 L496,174 L520,250 L284,250 Z", fill=SEPIA, fill_opacity=0.85, width=1.5)
    art.hatch([(308, 174), (496, 174), (520, 250), (284, 250)], spacing=4, angle=75, opacity=0.25)
    art.path("M330,182 L474,182 L480,198 L324,198 Z", fill=SEPIA_DARK, fill_opacity=0.7, width=1.0)
    for row in range(4):
        y = 210 + row * 10
        inset = row * 6
        count = 11 - row
        span = (178 - inset * 2) / max(count - 1, 1)
        for key in range(count):
            art.circle(312 + inset + key * span + 8, y, 3.6, fill=PAPER, width=0.9)
    art.rect(350, 248, 104, 7, fill=PAPER, width=1.0, rx=3)
    art.path("M284,250 L520,250 L516,266 L288,266 Z", fill=SEPIA_DARK, width=1.4)
    art.line(300, 258, 504, 258, 0.8, 0.5, PAPER)
    # Pluma y tintero.
    art.path("M156,300 L222,286", width=2.4)
    art.path("M222,286 L230,284 L224,289 Z", fill=INK, width=0.8)
    art.ellipse(520, 286, 16, 5, fill=SEPIA_DARK, width=1.1)
    art.path("M506,286 L508,268 L532,268 L534,286", fill=SEPIA_DARK, fill_opacity=0.9, width=1.2)
    art.rect(514, 260, 12, 8, fill=SEPIA, width=1.0)
    art.write("escritorio.svg")


# --- Mesa de interrogatorio: micrófono, papeles, sombrero y cenicero ---

def interrogatorio() -> None:
    art = Engraving(560, 330, 37)
    # Lámpara colgante con su cono de luz.
    art.line(280, 0, 280, 40, 1.2)
    cone = "cono"
    art.defs.append(
        f'<linearGradient id="{cone}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd88a" stop-opacity="0.55"/>'
        '<stop offset="1" stop-color="#ffd88a" stop-opacity="0"/></linearGradient>'
    )
    art.add(f'<path d="M262,64 L298,64 L410,270 L150,270 Z" fill="url(#{cone})"/>')
    art.path("M252,64 L308,64 L292,40 L268,40 Z", fill=SEPIA_DARK, width=1.3)
    art.ellipse(280, 64, 28, 5, fill=GLOW, width=1.0)
    # Mesa.
    art.path("M30,262 L530,262 L548,282 L12,282 Z", fill=SEPIA, fill_opacity=0.8, width=1.5)
    art.hatch([(30, 262), (530, 262), (548, 282), (12, 282)], spacing=3, angle=0, opacity=0.3)
    art.rect(12, 282, 536, 10, fill=SEPIA_DARK, width=1.3)
    art.path("M30,292 L30,326 M530,292 L530,326", width=3.0)
    art.ground(324, 0, 560, 6)
    # Expediente con clip y hojas.
    art.paper(108, 244, 140, 30, -3, rows=2)
    art.paper(96, 232, 120, 26, 5, rows=2)
    art.path("M136,216 L136,206 C136,200 146,200 146,206 L146,226 C146,232 140,232 140,226 L140,210", stroke=BRASS, width=1.8)
    # Micrófono de cinta sobre su pie.
    art.ellipse(280, 258, 40, 7, fill=SEPIA_DARK, width=1.3)
    art.rect(276, 186, 8, 70, fill=SEPIA_DARK, width=1.1)
    art.path("M252,150 C252,190 308,190 308,150", width=3.2)
    art.path("M262,90 C262,76 298,76 298,90 L298,160 C298,174 262,174 262,160 Z", fill=SEPIA_LIGHT, width=1.6)
    for slot in range(10):
        y = 92 + slot * 7
        art.line(268, y, 292, y, 1.0, 0.75)
    art.hatch_rect(284, 82, 13, 88, spacing=2.6, angle=90, opacity=0.4)
    art.circle(252, 150, 4, fill=SEPIA_DARK, width=1.0)
    art.circle(308, 150, 4, fill=SEPIA_DARK, width=1.0)
    art.path("M280,258 C300,276 330,270 350,282", width=1.4, opacity=0.8)
    # Sombrero de fieltro a la derecha.
    art.ellipse(452, 254, 66, 12, fill=SEPIA_DARK, width=1.4)
    art.path("M410,252 C406,212 418,196 434,196 C442,196 446,204 452,204 C458,204 462,196 470,196 C486,196 498,212 494,252 Z", fill=SEPIA, width=1.5)
    art.hatch([(410, 252), (412, 214), (434, 196), (470, 196), (494, 214), (494, 252)], spacing=3.2, angle=70, opacity=0.35)
    art.path("M410,240 C430,248 474,248 494,240 L495,250 C474,258 430,258 409,250 Z", fill=SEPIA_DARK, width=1.1)
    art.line(452, 204, 452, 222, 1.0, 0.7)
    # Cenicero con un cigarrillo humeante.
    art.ellipse(196, 258, 22, 6, fill=SEPIA_LIGHT, width=1.2)
    art.ellipse(196, 256, 14, 3.5, fill=SEPIA_DARK, fill_opacity=0.6, width=0.8)
    art.line(206, 254, 232, 248, 2.6, 1.0, PAPER)
    art.line(206, 254, 232, 248, 0.8)
    art.circle(232, 248, 2, fill=GLOW, stroke=None)
    art.path("M234,244 C226,228 244,220 236,204 C230,192 242,184 238,170", width=1.2, opacity=0.4)
    art.write("interrogatorio.svg")


# --- Tablero de deducciones: fotografía con interrogante, notas, chinchetas e hilo rojo ---

def tablero() -> None:
    art = Engraving(560, 380, 53)
    # Notas y documentos clavados.
    notes = [
        (102, 92, 120, 92, -7, 5),
        (452, 88, 116, 100, 6, 6),
        (110, 282, 128, 84, 5, 4),
        (448, 286, 120, 86, -5, 4),
    ]
    for cx, cy, w, h, angle, rows in notes:
        art.paper(cx, cy, w, h, angle, rows=rows)
    # Recorte de prensa con su titular.
    art.paper(268, 330, 96, 52, -2, rows=3, fold=False)
    art.rect(232, 312, 72, 6, fill=INK, fill_opacity=0.55, stroke=None)
    # Fotografía central con el interrogante.
    art.begin_group("rotate(-3 280 180)")
    art.rect(212, 94, 136, 170, fill=SEPIA_DARK, fill_opacity=0.25, stroke=None)
    art.rect(206, 88, 136, 170, fill=PAPER, width=1.3)
    art.rect(218, 100, 112, 128, fill=SEPIA, fill_opacity=0.9, width=1.0)
    art.hatch_rect(219, 101, 110, 126, spacing=3, angle=45, opacity=0.25)
    art.path("M232,228 C232,200 248,188 274,188 C300,188 316,200 316,228 Z", fill=SEPIA_DARK, width=1.0)
    art.circle(274, 160, 20, fill=SEPIA_DARK, width=1.0)
    art.path("M262,148 C262,132 288,130 288,146 C288,158 274,158 274,170", stroke=PAPER, width=5.0)
    art.circle(274, 182, 3.4, fill=PAPER, stroke=None)
    art.text_lines(226, 240, 96, 1, opacity=0.6)
    art.end_group()
    # Hilos rojos entre chinchetas.
    pins = [(102, 56), (452, 50), (110, 250), (446, 252), (274, 90), (268, 306)]
    links = [(4, 0), (4, 1), (0, 2), (1, 3), (5, 2), (5, 3)]
    for a, b in links:
        (x1, y1), (x2, y2) = pins[a], pins[b]
        sag = math.hypot(x2 - x1, y2 - y1) * 0.06
        mx, my = (x1 + x2) * 0.5, (y1 + y2) * 0.5 + sag
        art.path(f"M{x1},{y1} Q{mx:.1f},{my:.1f} {x2},{y2}", stroke=STRING, width=1.8, opacity=0.9)
    for x, y in pins:
        art.pin(x, y)
    art.write("tablero.svg")


# --- Libros, lupa y papeles: el rincón de la página de deducciones ---

def libros_lupa() -> None:
    art = Engraving(420, 250, 71)
    art.ground(226, 0, 420, 24)
    art.book(20, 206, 200, 22, SEPIA)
    art.book(34, 186, 176, 20, SEPIA_PALE)
    art.book(28, 166, 168, 20, SEPIA_LIGHT)
    art.standing_book(212, 92, 28, 136, SEPIA_LIGHT, 0)
    art.standing_book(241, 104, 24, 124, SEPIA, 0)
    art.paper(330, 214, 130, 30, -3, rows=2)
    art.paper(318, 196, 104, 34, 6, rows=2)
    # Lupa apoyada sobre los libros.
    art.begin_group("rotate(-24 112 128)")
    art.rect(106, 150, 12, 70, fill=SEPIA_DARK, width=1.3, rx=5)
    for ring in range(4):
        art.line(106, 160 + ring * 14, 118, 160 + ring * 14, 0.8, 0.6, PAPER)
    art.rect(103, 140, 18, 12, fill=BRASS, width=1.1)
    art.circle(112, 102, 40, fill=PAPER, fill_opacity=0.45, stroke=BRASS, width=6.0)
    art.circle(112, 102, 40, width=1.2)
    art.circle(112, 102, 34, width=0.8, opacity=0.6)
    art.path("M90,84 C96,74 108,70 118,72", stroke="#fff6dc", width=3.0, opacity=0.8)
    art.end_group()
    art.write("libros_lupa.svg")


# --- Libros, tintero, pluma y cartas: el rincón del corcho del tablero de deducción ---

def rincon_tablero() -> None:
    art = Engraving(520, 300, 1948)
    art.ground(270, 0, 520, 26)
    # Pila de libros tumbados y dos de pie detrás.
    art.standing_book(150, 120, 28, 132, SEPIA, -3)
    art.standing_book(180, 134, 24, 118, SEPIA_PALE, 6)
    art.book(16, 248, 210, 24, SEPIA)
    art.book(30, 225, 184, 23, SEPIA_LIGHT)
    art.book(22, 203, 176, 22, SEPIA_PALE)
    art.book(40, 184, 140, 19, SEPIA)
    # Cartas y un sobre sobre la mesa, con la pluma encima.
    art.paper(330, 252, 150, 46, -5, rows=3)
    art.paper(300, 238, 124, 40, 7, rows=3)
    art.begin_group("rotate(-8 400 226)")
    art.rect(350, 206, 108, 52, fill=PAPER, width=1.1)
    art.poly([(350, 206), (404, 236), (458, 206)], fill=None, width=1.0, closed=False)
    art.circle(404, 236, 6, fill=STRING, width=0.9)
    art.end_group()
    # Pluma estilográfica cruzada sobre las cartas.
    art.path("M232,284 L392,250", width=5.0, stroke=SEPIA_DARK)
    art.path("M232,284 L392,250", width=1.0, stroke=INK)
    art.path("M392,250 L414,245 L398,253 Z", fill=BRASS, width=0.9)
    art.line(300, 270, 316, 266, 2.4, 1.0, BRASS)
    # Tintero de cristal con la pluma de ave.
    art.ellipse(462, 268, 34, 8, fill=SEPIA_DARK, fill_opacity=0.35, stroke=None)
    art.path("M434,266 C430,244 436,226 448,218 L476,218 C488,226 494,244 490,266 Z", fill=SEPIA_DARK, fill_opacity=0.85, width=1.4)
    art.hatch([(434, 266), (448, 218), (476, 218), (490, 266)], spacing=3.2, angle=80, opacity=0.3, color=PAPER)
    art.path("M440,250 C446,240 452,236 458,236", stroke=PAPER, width=1.6, opacity=0.6)
    art.rect(449, 204, 26, 15, fill=SEPIA, width=1.1, rx=2)
    art.ellipse(462, 204, 13, 3.5, fill=INK, width=0.9)
    art.path("M462,204 C470,170 492,120 512,86", width=1.6)
    art.path("M512,86 C500,104 486,132 476,160 C488,136 500,112 512,86 Z", fill=PAPER, width=0.9)
    art.path("M512,86 C506,110 496,138 482,166 C492,140 502,114 512,86", width=0.7, opacity=0.6)
    for step in range(9):
        t = step / 9
        x = 510 - t * 32
        y = 92 + t * 66
        art.line(x, y, x - 10 - step, y - 3, 0.7, 0.55)
    art.write("rincon_escritorio.svg", BOARD_OUTPUT)


if __name__ == "__main__":
    cafe()
    escritorio()
    interrogatorio()
    tablero()
    libros_lupa()
    rincon_tablero()
    print("Grabados escritos en", OUTPUT, "y", BOARD_OUTPUT)
