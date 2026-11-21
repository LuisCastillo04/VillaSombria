"""Genera las ilustraciones de las evidencias (assets/ui/evidencias).

Uso:  python tools/generar_evidencias.py

- `reloj_sobremesa.svg`: grabado sepia del reloj de bronce del despacho, caído y con la esfera rota.
  Las agujas se dibujan a partir de `HORA_DEL_RELOJ`, la hora de `data/clues.json` (22:15, que en
  una esfera de doce horas son las 10:15).
- `flores_violetas.svg`: dos violetas prensadas, el adorno de la carta de Marcos.

Usa la misma tinta y las mismas primitivas que `generar_grabados.py`. Son SVG con fondo
transparente: para sustituirlos por arte propio basta con reemplazar el archivo con el mismo nombre.
"""

import math
import sys
from pathlib import Path

# Importar el otro generador no debe dejar una carpeta __pycache__ dentro de tools/.
sys.dont_write_bytecode = True
from generar_grabados import INK, SEPIA_DARK, Engraving  # noqa: E402

OUTPUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "evidencias"

HORA_DEL_RELOJ = (22, 15)

BRONZE = "#a77d43"
BRONZE_LIGHT = "#d6b06e"
BRONZE_DARK = "#6b4b27"
DIAL = "#f1e5c8"
DIAL_EDGE = "#d6c095"
GLASS_DARK = "#2b1d12"
SHARD = "#e9dcc0"


def polar(cx, cy, radius, degrees):
    """Punto de una esfera: 0 grados son las doce y el ángulo crece en el sentido del reloj."""
    radians = math.radians(degrees)
    return cx + radius * math.sin(radians), cy - radius * math.cos(radians)


def gradient(art: Engraving, name: str, stops, x2=1.0, y2=1.0, radial=False) -> str:
    """Añade un degradado lineal (o radial) a las definiciones y devuelve su referencia."""
    body = "".join(f'<stop offset="{offset}" stop-color="{color}"/>' for offset, color in stops)
    if radial:
        art.defs.append(f'<radialGradient id="{name}" cx="0.45" cy="0.4" r="0.65">{body}</radialGradient>')
    else:
        art.defs.append(f'<linearGradient id="{name}" x1="0" y1="0" x2="{x2}" y2="{y2}">{body}</linearGradient>')
    return f"url(#{name})"


# --- Reloj de sobremesa ---

def numeral(art: Engraving, text: str, cx: float, cy: float, angle: float, height: float = 17.0) -> None:
    """Número romano trazado a pluma, con los pies hacia el centro de la esfera."""
    advance = {"I": 4.8, "V": 10.0, "X": 10.0}
    total = sum(advance[letter] for letter in text)
    half = height * 0.5
    art.begin_group(f"translate({cx:.1f} {cy:.1f}) rotate({angle:.1f})")
    cursor = -total * 0.5
    for letter in text:
        middle = cursor + advance[letter] * 0.5
        if letter == "I":
            art.line(middle, -half + 1.0, middle, half - 1.0, 2.6)
        elif letter == "V":
            art.line(middle - 4.0, -half + 1.0, middle, half - 1.0, 2.5)
            art.line(middle + 4.0, -half + 1.0, middle, half - 1.0, 1.0)
        else:
            art.line(middle - 4.0, -half + 1.0, middle + 4.0, half - 1.0, 2.5)
            art.line(middle + 4.0, -half + 1.0, middle - 4.0, half - 1.0, 1.0)
        cursor += advance[letter]
    art.line(-total * 0.5 - 1.0, -half, total * 0.5 + 1.0, -half, 0.9)
    art.line(-total * 0.5 - 1.0, half, total * 0.5 + 1.0, half, 0.9)
    art.end_group()


def hand(art: Engraving, cx, cy, degrees, length, width, tail, spade) -> None:
    """Aguja de acero pavonado con su contrapeso; `spade` añade la pala de la aguja de las horas."""
    art.begin_group(f"rotate({degrees:.2f} {cx:.1f} {cy:.1f})")
    art.poly([
        (cx - width * 0.5, cy + tail), (cx - width * 0.5, cy), (cx - width * 0.18, cy - length + 6.0),
        (cx, cy - length), (cx + width * 0.18, cy - length + 6.0), (cx + width * 0.5, cy), (cx + width * 0.5, cy + tail),
    ], fill=INK, width=0.8)
    art.circle(cx, cy + tail, width * 0.9, fill=INK, width=0.6)
    if spade:
        tip = cy - length * 0.72
        art.path(
            f"M{cx:.1f},{tip - 13:.1f} C{cx + 11:.1f},{tip - 4:.1f} {cx + 9:.1f},{tip + 9:.1f} {cx:.1f},{tip + 6:.1f} "
            f"C{cx - 9:.1f},{tip + 9:.1f} {cx - 11:.1f},{tip - 4:.1f} {cx:.1f},{tip - 13:.1f} Z",
            fill=INK, width=0.8,
        )
        art.circle(cx, tip - 1.0, 2.6, fill=DIAL, stroke=None)
    art.end_group()


def scroll(art: Engraving, cx, cy, radius, direction, turns=1.6, width=1.6) -> None:
    """Voluta del bronce: una espiral que se cierra hacia dentro."""
    points = []
    steps = 40
    for step in range(steps + 1):
        t = step / steps
        angle = direction * (math.pi * 0.5 + t * turns * 2.0 * math.pi)
        r = radius * (1.0 - 0.78 * t)
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    art.poly(points, width=width, closed=False)
    art.circle(points[-1][0], points[-1][1], 2.2, fill=INK, stroke=None)


def leaf_spray(art: Engraving, x, y, direction, scale=1.0) -> None:
    """Hojas de acanto grabadas en los hombros de la caja."""
    for index in range(3):
        sx = x + direction * index * 13 * scale
        sy = y + index * 7 * scale
        tip = (sx + direction * 16 * scale, sy - 12 * scale)
        art.path(
            f"M{sx:.1f},{sy:.1f} Q{sx + direction * 3 * scale:.1f},{sy - 13 * scale:.1f} {tip[0]:.1f},{tip[1]:.1f} "
            f"Q{sx + direction * 14 * scale:.1f},{sy - 2 * scale:.1f} {sx:.1f},{sy:.1f} Z",
            fill=BRONZE_LIGHT, fill_opacity=0.8, width=1.0,
        )
        art.line(sx, sy, tip[0] - direction * 3 * scale, tip[1] + 3 * scale, 0.6, 0.7)


def reloj_sobremesa() -> None:
    art = Engraving(640, 700, seed=1948)
    cx = 320.0
    dial_y = 352.0
    hour, minute = HORA_DEL_RELOJ
    bronze = gradient(art, "bronce", [(0, BRONZE_LIGHT), (0.45, BRONZE), (1, BRONZE_DARK)], 1.0, 0.6)
    bezel = gradient(art, "bisel", [(0, "#ecc988"), (0.5, BRONZE), (1, BRONZE_DARK)], 0.9, 1.0)
    face = gradient(art, "esfera", [(0, "#f7edd5"), (0.75, DIAL), (1, DIAL_EDGE)], radial=True)

    # Suelo: la alfombra a plumilla y la sombra del reloj.
    art.ellipse(cx + 18, 622, 290, 34, fill=SEPIA_DARK, fill_opacity=0.28, stroke=None)
    for _ in range(70):
        gx = art.random.uniform(40, 610)
        gy = art.random.uniform(600, 668)
        length = art.random.uniform(10, 28)
        art.line(gx, gy, gx + length, gy - length * 0.28, 0.9, art.random.uniform(0.25, 0.55))
    art.hatch([(60, 610), (600, 600), (620, 660), (40, 668)], spacing=6.5, angle=-16, opacity=0.18)

    # Esquirlas de cristal sobre la alfombra, todas pegadas al reloj.
    for sx, sy, size, turn in [(214, 626, 9, 10), (246, 640, 6, 70), (392, 637, 8, 140), (428, 628, 5, 30), (300, 646, 7, 200)]:
        art.begin_group(f"rotate({turn} {sx} {sy})")
        art.poly([(sx - size, sy + size * 0.4), (sx + size * 0.2, sy - size), (sx + size, sy + size * 0.6)], fill=SHARD, width=0.9)
        art.line(sx - size * 0.3, sy, sx + size * 0.4, sy - size * 0.3, 0.6, 0.6)
        art.end_group()

    # Todo el reloj, ladeado al caer.
    art.begin_group(f"rotate(6 {cx} 600)")

    # Peana con dos pies de bola y molduras.
    for fx in (162, 478):
        art.ellipse(fx, 603, 26, 13, fill=bronze, width=1.4)
        art.hatch_rect(fx - 24, 603, 48, 12, spacing=3.0, angle=0, opacity=0.35)
    art.rect(120, 560, 400, 36, fill=bronze, width=1.6, rx=3)
    art.line(124, 571, 516, 571, 0.9, 0.7)
    art.hatch_rect(122, 578, 396, 16, spacing=3.2, angle=60, opacity=0.35)
    art.rect(140, 532, 360, 30, fill=bronze, width=1.5, rx=2)
    for bead in range(16):
        art.circle(156 + bead * 21.5, 547, 3.4, fill=BRONZE_LIGHT, width=0.7)

    # Caja con el remate de sombrero y dos volutas a los lados.
    body = (
        f"M178,534 L178,300 C178,244 206,218 248,206 C282,197 304,172 {cx},146 "
        f"C336,172 358,197 392,206 C434,218 462,244 462,300 L462,534 Z"
    )
    art.path(body, fill=bronze, width=1.8)
    art.hatch([(420, 230), (462, 280), (462, 534), (420, 534)], spacing=3.4, angle=70, opacity=0.45)
    art.hatch([(178, 300), (200, 240), (230, 225), (205, 300), (205, 534), (178, 534)], spacing=4.0, angle=110, opacity=0.25)
    art.rect(168, 508, 304, 26, fill=bronze, width=1.4, rx=2)
    art.hatch_rect(170, 522, 300, 11, spacing=3.0, angle=0, opacity=0.3)
    for side in (-1, 1):
        x = cx + side * 160
        art.circle(x + side * 6, 482, 26, fill=BRONZE_LIGHT, fill_opacity=0.85, width=1.4)
        scroll(art, x + side * 6, 482, 24, side)
        art.path(f"M{x:.1f},430 C{x + side * 20:.1f},440 {x + side * 34:.1f},458 {x + side * 30:.1f},482", width=1.4)
        leaf_spray(art, cx + side * 66, 214, side, 1.1)
    # Remate: bola y llama.
    art.rect(cx - 16, 138, 32, 12, fill=bronze, width=1.2, rx=2)
    art.circle(cx, 124, 13, fill=bronze, width=1.4)
    art.path(f"M{cx - 9},114 C{cx - 10},100 {cx - 3},92 {cx},80 C{cx + 3},92 {cx + 10},100 {cx + 9},114 Z", fill=BRONZE_LIGHT, width=1.2)
    art.line(cx, 112, cx, 88, 0.7, 0.7)

    # Bisel con cuentas, esfera y pista de minutos.
    art.circle(cx, dial_y, 124, fill=bezel, width=2.0)
    for bead in range(36):
        bx, by = polar(cx, dial_y, 118, bead * 10)
        art.circle(bx, by, 2.4, fill=BRONZE_LIGHT, width=0.6)
    art.circle(cx, dial_y, 111, fill=BRONZE_DARK, width=1.2)
    art.circle(cx, dial_y, 106, fill=face, width=1.2)
    art.circle(cx, dial_y, 97, width=0.8)
    art.circle(cx, dial_y, 90, width=0.8)
    for tick in range(60):
        inner = 90 if tick % 5 else 87
        x1, y1 = polar(cx, dial_y, inner, tick * 6)
        x2, y2 = polar(cx, dial_y, 97, tick * 6)
        art.line(x1, y1, x2, y2, 1.6 if tick % 5 == 0 else 0.7)
    numerals = ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
    for index, text in enumerate(numerals):
        nx, ny = polar(cx, dial_y, 74, index * 30)
        numeral(art, text, nx, ny, index * 30)

    # Agujas paradas en la hora del reloj: la de las horas avanza con los minutos.
    hand(art, cx, dial_y, (hour % 12 + minute / 60.0) * 30.0, 56, 6.0, 12, True)
    hand(art, cx, dial_y, minute * 6.0, 84, 4.6, 18, False)
    art.circle(cx, dial_y, 6.5, fill=bronze, width=1.2)
    art.circle(cx, dial_y, 2.2, fill=INK, stroke=None)

    # Cristal roto: un hueco abajo, grietas en estrella desde el golpe y anillos de telaraña.
    impact = (cx - 22, dial_y + 62)
    hole = [(cx - 44, dial_y + 98), (cx - 30, dial_y + 70), (cx - 14, dial_y + 78), (cx - 4, dial_y + 66), (cx + 12, dial_y + 84), (cx + 22, dial_y + 101)]
    art.poly(hole, fill=GLASS_DARK, fill_opacity=0.88, width=1.2)
    art.poly([(cx - 36, dial_y + 95), (cx - 28, dial_y + 78), (cx - 16, dial_y + 86)], fill=SHARD, fill_opacity=0.5, width=0.6)
    rays = [200, 235, 268, 300, 330, 2, 35, 70, 120, 160]
    for index, ray in enumerate(rays):
        length = 150 if index % 2 == 0 else 110
        points = [impact]
        for step in range(1, 5):
            px, py = polar(impact[0], impact[1], length * step / 4, ray + art.random.uniform(-6, 6))
            if math.hypot(px - cx, py - dial_y) > 105:
                break
            points.append((px, py))
        if len(points) > 1:
            art.poly(points, width=1.0, opacity=0.85, closed=False)
    for ring in (22, 46):
        arc = []
        for ray in range(200, 380, 12):
            px, py = polar(impact[0], impact[1], ring + art.random.uniform(-3, 3), ray)
            if math.hypot(px - cx, py - dial_y) < 104:
                arc.append((px, py))
        if len(arc) > 2:
            art.poly(arc, width=0.7, opacity=0.7, closed=False)
    # Brillo del cristal arriba a la izquierda.
    art.path(f"M{cx - 78},{dial_y - 44} C{cx - 66},{dial_y - 78} {cx - 34},{dial_y - 94} {cx - 4},{dial_y - 96}", stroke="#ffffff", width=5.0, opacity=0.35)
    art.end_group()
    art.write("reloj_sobremesa.svg", OUTPUT)


# --- Violetas prensadas ---

PETAL = "#8c76b4"
PETAL_LIGHT = "#b7a3d6"
PETAL_DARK = "#5b4683"
STEM = "#6c7140"
LEAF = "#7d8448"
LEAF_DARK = "#4c5229"
POLLEN = "#e2b23e"


def violet(art: Engraving, cx, cy, radius, turn, petal_fill) -> None:
    """Flor de cinco pétalos con la punta escotada, sus nervios y el corazón amarillo."""
    for index in range(5):
        angle = turn + index * 72
        art.begin_group(f"rotate({angle:.1f} {cx:.1f} {cy:.1f})")
        tip = cy - radius
        art.path(
            f"M{cx:.1f},{cy:.1f} C{cx - radius * 0.55:.1f},{cy - radius * 0.35:.1f} {cx - radius * 0.62:.1f},{tip + radius * 0.05:.1f} "
            f"{cx - radius * 0.22:.1f},{tip:.1f} Q{cx:.1f},{tip + radius * 0.12:.1f} {cx + radius * 0.22:.1f},{tip:.1f} "
            f"C{cx + radius * 0.62:.1f},{tip + radius * 0.05:.1f} {cx + radius * 0.55:.1f},{cy - radius * 0.35:.1f} {cx:.1f},{cy:.1f} Z",
            fill=petal_fill, width=1.0, stroke=PETAL_DARK,
        )
        for vein in (-0.18, 0.0, 0.18):
            art.path(
                f"M{cx:.1f},{cy - radius * 0.18:.1f} Q{cx + radius * vein:.1f},{cy - radius * 0.55:.1f} {cx + radius * vein * 1.4:.1f},{cy - radius * 0.8:.1f}",
                stroke=PETAL_DARK, width=0.7, opacity=0.55,
            )
        art.end_group()
    art.circle(cx, cy, radius * 0.2, fill=POLLEN, stroke="#9c6f1c", width=0.8)
    for index in range(6):
        px, py = polar(cx, cy, radius * 0.12, index * 60 + turn)
        art.circle(px, py, 1.3, fill="#8a5a12", stroke=None)


def leaf(art: Engraving, x, y, length, width, angle) -> None:
    art.begin_group(f"rotate({angle:.1f} {x:.1f} {y:.1f})")
    art.path(
        f"M{x:.1f},{y:.1f} C{x + width:.1f},{y - length * 0.3:.1f} {x + width * 0.6:.1f},{y - length * 0.8:.1f} {x:.1f},{y - length:.1f} "
        f"C{x - width * 0.6:.1f},{y - length * 0.8:.1f} {x - width:.1f},{y - length * 0.3:.1f} {x:.1f},{y:.1f} Z",
        fill=LEAF, fill_opacity=0.92, stroke=LEAF_DARK, width=1.0,
    )
    art.line(x, y, x, y - length * 0.92, 0.8, 0.8, LEAF_DARK)
    for step in range(1, 5):
        vy = y - length * step / 5.5
        art.line(x, vy, x + width * 0.45, vy - length * 0.08, 0.5, 0.6, LEAF_DARK)
        art.line(x, vy, x - width * 0.45, vy - length * 0.08, 0.5, 0.6, LEAF_DARK)
    art.end_group()


def flores_violetas() -> None:
    art = Engraving(300, 360, seed=14)
    petal = gradient(art, "petalo", [(0, PETAL_LIGHT), (0.55, PETAL), (1, PETAL_DARK)], radial=True)
    # Tallos que se cruzan, como al quedar prensados entre dos hojas.
    art.path("M96,104 C92,170 74,250 32,342", stroke=STEM, width=3.2)
    art.path("M206,158 C176,214 120,262 58,330", stroke=STEM, width=2.8)
    art.path("M120,238 C140,232 160,236 176,248", stroke=STEM, width=1.8)
    leaf(art, 76, 236, 70, 17, -34)
    leaf(art, 92, 280, 62, 15, 28)
    leaf(art, 150, 236, 54, 13, 62)
    leaf(art, 60, 318, 44, 11, -60)
    violet(art, 96, 98, 44, 8, petal)
    violet(art, 206, 156, 38, -14, petal)
    # Un capullo cerrado.
    art.path("M176,248 C186,236 196,234 200,222 C188,226 178,236 176,248 Z", fill=PETAL, stroke=PETAL_DARK, width=0.9)
    art.write("flores_violetas.svg", OUTPUT)


if __name__ == "__main__":
    reloj_sobremesa()
    flores_violetas()
    print("Ilustraciones escritas en", OUTPUT)
