"""Genera las ilustraciones de las evidencias (assets/ui/evidencias).

Uso:  python tools/generar_evidencias.py

- `flores_violetas.svg`: dos violetas prensadas, el adorno de la carta de Marcos.

Usa la misma tinta y las mismas primitivas que `generar_grabados.py`. Son SVG con fondo
transparente: para sustituirlos por arte propio basta con reemplazar el archivo con el mismo nombre.
"""

import math
import sys
from pathlib import Path

# Importar el otro generador no debe dejar una carpeta __pycache__ dentro de tools/.
sys.dont_write_bytecode = True
from generar_grabados import Engraving  # noqa: E402

OUTPUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "evidencias"


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
    flores_violetas()
    print("Ilustraciones escritas en", OUTPUT)
