"""Extrae las ilustraciones de las evidencias de las imágenes de referencia del propietario.

Uso:  uv run --no-project --with pillow --with numpy --with scipy python tools/extraer_ilustraciones.py

Lee las referencias de `../referencias/evidencias/` (fuera del proyecto de Godot: no se importan ni
se exportan) y escribe PNG con fondo transparente en `assets/ui/evidencias/`. Cada referencia es una
captura de la ficha de evidencia con la ilustración sobre el pergamino; aquí sólo se conserva la
ilustración, sin el papel, los textos ni el marco de la interfaz, que el juego dibuja por su cuenta.

Cómo separa la ilustración del papel:

1. Modela el pergamino que hay debajo del objeto: rellena la zona del objeto con el papel de
   alrededor (relleno piramidal «push-pull»), así conserva manchas y degradados grandes.
2. La opacidad de cada píxel crece con su diferencia de color con ese papel. Lo que apenas difiere
   (la textura y las motas del papel) queda transparente; las sombras y el cristal, semitransparentes;
   el objeto, opaco.
3. El color se despeja de la mezcla (I = a·F + (1 − a)·B), de modo que sobre el pergamino del juego
   la ilustración se ve igual que en la referencia, con su sombra.
4. Si el objeto es macizo (billete, libro, fotografía), los huecos interiores del contorno se
   rellenan para que el papel del juego no se transparente a través de él.

Para la lista de invitados además se borra la zona de los nombres: el juego escribe esa lista con
los datos de `clues.json` (ver `EvidenceGuestList`), porque los nombres de la referencia no casaban
con la historia.

No usa nada descargado de terceros: sólo las referencias del propietario.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
REFERENCES = ROOT.parent / "referencias" / "evidencias"
OUTPUT = ROOT / "assets" / "ui" / "evidencias"

# Recuadro de cada ilustración en su referencia (x0, y0, x1, y1), en píxeles de la captura.
# t0/t1: diferencia con el papel a partir de la cual el píxel empieza a verse y es opaco.
# solid: rellenar los huecos del contorno; keep: huecos que deben seguir transparentes (x, y).
# min_area: manchas sueltas más pequeñas que esto se descartan (motas del papel).
# reach: lo tenue (sombras, cercos) sólo se conserva hasta esa distancia de lo bien marcado; así
# las manchas del papel de la referencia no se cuelan pegadas a la sombra del objeto.
# rough: diferencia que marca qué no es papel al modelar el pergamino.
# exclude: rectángulos (x0, y0, x1, y1) de la interfaz que asoman en el recuadro (el final del
# título, su subrayado rojo, letras de la descripción) y nunca forman parte de la ilustración.
ITEMS = {
    "huellas_betun": {
        "ref": "huellas_betun.png", "box": (975, 160, 1425, 590),
        "t0": 7.0, "t1": 46.0, "solid": False, "min_area": 220, "rough": 16.0,
        # Las huellas apenas se distinguen del papel: silueta limpia y tinta uniforme translúcida.
        "flat": {"threshold": 11.0, "ink": (78.0, 66.0, 52.0), "strength": 1.6},
    },
    "foto_clara": {
        "ref": "foto_clara.png", "box": (790, 180, 1450, 805),
        "t0": 9.0, "t1": 34.0, "solid": True, "min_area": 120,
        "exclude": [(780, 296, 886, 326)],
    },
    "lista_invitados": {
        "ref": "lista_invitados.png", "box": (860, 0, 1488, 760),
        "t0": 12.0, "t1": 36.0, "solid": True, "min_area": 160, "reach": 34,
        "exclude": [(850, 140, 938, 172)],
        # Zona de casillas, nombres y renglones (polígono en píxeles de la captura): se borra.
        "erase": [(948, 252), (1408, 282), (1404, 640), (940, 612)],
    },
    "billete_tren": {
        "ref": "billete_tren.png", "box": (815, 250, 1455, 755),
        "t0": 12.0, "t1": 40.0, "solid": True, "min_area": 160, "reach": 16,
        "exclude": [(800, 240, 972, 332), (800, 332, 852, 640)],
    },
    "libro_bodega": {
        "ref": "libro_bodega.png", "box": (865, 230, 1425, 805),
        "t0": 9.0, "t1": 34.0, "solid": True, "min_area": 120,
        "exclude": [(850, 296, 954, 326)],
    },
    "llave_reloj": {
        "ref": "llave_reloj.png", "box": (835, 190, 1495, 740),
        "t0": 9.0, "t1": 36.0, "solid": True, "min_area": 150,
        "exclude": [(820, 180, 1002, 308), (820, 308, 884, 560)],
        # El ojo de la llave: ahí se ve el pergamino.
        "keep": [(1335, 295), (1385, 300)],
    },
    "copa_lavada": {
        "ref": "copa_lavada.png", "box": (910, 245, 1485, 775),
        "t0": 7.0, "t1": 40.0, "solid": False, "min_area": 60,
        "exclude": [(895, 230, 995, 302)],
    },
}

MARGIN = 48


def push_pull(color: np.ndarray, weight: np.ndarray) -> np.ndarray:
    """Rellena lo desconocido (peso 0) con lo conocido de alrededor, a varias escalas."""
    levels = [(color * weight[..., None], weight)]
    while min(levels[-1][1].shape) > 4:
        acc, w = levels[-1]
        h, wd = w.shape
        h2, w2 = h - h % 2, wd - wd % 2
        acc = acc[:h2, :w2]
        w = w[:h2, :w2]
        acc = (acc[0::2, 0::2] + acc[1::2, 0::2] + acc[0::2, 1::2] + acc[1::2, 1::2]) / 4.0
        w = (w[0::2, 0::2] + w[1::2, 0::2] + w[0::2, 1::2] + w[1::2, 1::2]) / 4.0
        levels.append((acc, w))
    acc, w = levels[-1]
    result = acc / np.maximum(w, 1e-6)[..., None]
    # Si en el nivel más grueso aún hay huecos, toman la media de lo conocido.
    mean = (color * weight[..., None]).sum(axis=(0, 1)) / max(weight.sum(), 1e-6)
    result = np.where((w > 1e-6)[..., None], result, mean)
    for acc, w in reversed(levels[:-1]):
        zoom = (w.shape[0] / result.shape[0], w.shape[1] / result.shape[1], 1)
        up = ndimage.zoom(result, zoom, order=1)
        up = _fit(up, w.shape)
        trust = np.clip(w * 2.0, 0.0, 1.0)[..., None]
        own = acc / np.maximum(w, 1e-6)[..., None]
        result = trust * own + (1.0 - trust) * up
    return result


def _fit(image: np.ndarray, shape: tuple) -> np.ndarray:
    out = np.zeros((shape[0], shape[1], image.shape[2]))
    h, w = min(shape[0], image.shape[0]), min(shape[1], image.shape[1])
    out[:h, :w] = image[:h, :w]
    if h < shape[0]:
        out[h:, :w] = image[h - 1:h, :w]
    if w < shape[1]:
        out[:, w:] = out[:, w - 1:w]
    return out


def smooth_paper(color: np.ndarray, known: np.ndarray, sigma: float) -> np.ndarray:
    """Papel suavizado sólo con píxeles conocidos, y relleno donde no hay ninguno."""
    weight = ndimage.gaussian_filter(known.astype(float), sigma)
    acc = np.stack([ndimage.gaussian_filter(color[..., c] * known, sigma) for c in range(3)], axis=-1)
    defined = weight > 0.05
    blurred = acc / np.maximum(weight, 1e-6)[..., None]
    return push_pull(np.where(defined[..., None], blurred, 0.0), defined.astype(float))


def difference(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.sqrt(((a - b) ** 2).sum(axis=-1) / 3.0)


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def polygon_mask(shape: tuple, points: list) -> np.ndarray:
    """Máscara de un polígono convexo, en coordenadas del recorte."""
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    inside = np.ones(shape, bool)
    n = len(points)
    for i in range(n):
        (x0, y0), (x1, y1) = points[i], points[(i + 1) % n]
        inside &= (x1 - x0) * (yy - y0) - (y1 - y0) * (xx - x0) >= 0
    return inside


def erase_writing(color: np.ndarray, zone: np.ndarray) -> np.ndarray:
    """Borra la tinta de `zone` y la sustituye por el papel de alrededor, con su grano."""
    lum = color.mean(axis=-1)
    local = ndimage.median_filter(lum, size=31)
    red = color[..., 0] - color[..., 2]
    ink = zone & ((lum < local - 12.0) | (red > np.median(red[zone]) + 28.0))
    ink = ndimage.binary_dilation(ink, iterations=3)
    known = ~ink
    paper = smooth_paper(color, known, 5.0)
    # El grano fino del papel: el de un trozo limpio de la misma hoja, desplazado.
    grain = color - ndimage.gaussian_filter(color, (3, 3, 0))
    clean_grain = np.where(known[..., None], grain, 0.0)
    filled = paper + 0.6 * np.roll(clean_grain, 37, axis=1)
    return np.where(ink[..., None], filled, color)


def flat_ink(image: np.ndarray, paper: np.ndarray, diff: np.ndarray, inner: np.ndarray, cfg: dict) -> tuple:
    """Manchas de tinta tenue (huellas): silueta limpia y una sola tinta, con la opacidad que
    reproduce el tono de la referencia sobre su papel."""
    flat = cfg["flat"]
    shape = (ndimage.gaussian_filter(diff, 1.5) > flat["threshold"]) & inner
    shape = ndimage.binary_opening(shape, iterations=2)
    shape = ndimage.binary_fill_holes(ndimage.binary_closing(shape, iterations=3))
    labels, count = ndimage.label(shape)
    if count:
        areas = ndimage.sum(np.ones(shape.shape), labels, index=np.arange(1, count + 1))
        shape &= ~np.isin(labels, np.where(areas < cfg["min_area"])[0] + 1)
    ink = np.array(flat["ink"])
    amount = ((paper - image) / np.maximum(paper - ink, 1.0)).mean(axis=-1)
    amount = np.clip(ndimage.gaussian_filter(amount, 2.0), 0.18, 0.6)
    inside = ndimage.binary_erosion(shape, iterations=2)
    typical = float(np.median(amount[inside])) if inside.any() else 0.35
    amount = np.where(shape, amount, typical)
    # El papel del juego es algo más claro que el de la referencia: un punto más de tinta.
    amount = np.clip(amount * flat.get("strength", 1.0), 0.0, 0.75)
    alpha = ndimage.gaussian_filter(shape.astype(float), 1.0) * amount
    colour = paper * 0.0 + ink
    # La mezcla final reproduce I = a·tinta + (1 − a)·papel.
    return alpha, alpha[..., None] * colour + (1.0 - alpha[..., None]) * paper


def extract(item_id: str, cfg: dict) -> None:
    source = np.asarray(Image.open(REFERENCES / cfg["ref"]).convert("RGB")).astype(float)
    h, w, _ = source.shape
    x0, y0, x1, y1 = cfg["box"]
    cx0, cy0 = max(0, x0 - MARGIN), max(0, y0 - MARGIN)
    cx1, cy1 = min(w, x1 + MARGIN), min(h, y1 + MARGIN)
    image = source[cy0:cy1, cx0:cx1].copy()
    shape = image.shape[:2]
    inner = np.zeros(shape, bool)
    inner[y0 - cy0:y1 - cy0, x0 - cx0:x1 - cx0] = True

    if "erase" in cfg:
        zone = polygon_mask(shape, [(x - cx0, y - cy0) for x, y in cfg["erase"]])
        image = erase_writing(image, zone)

    # 1. Papel aproximado: el de fuera del recuadro, extendido hacia dentro.
    paper = push_pull(image, (~inner).astype(float))
    paper = ndimage.gaussian_filter(paper, (6, 6, 0))
    rough = difference(image, paper) > cfg.get("rough", 20.0)
    rough = ndimage.binary_opening(rough, iterations=1)
    rough = ndimage.binary_dilation(rough, iterations=6) & inner
    # 2. Papel fino: el de alrededor del objeto, sin el objeto.
    paper = smooth_paper(image, ~rough, 4.0)
    diff = difference(image, paper)
    if "flat" in cfg:
        alpha, image = flat_ink(image, paper, diff, inner, cfg)
    else:
        alpha = smoothstep(cfg["t0"], cfg["t1"], diff)
        if "reach" in cfg:
            strong = ndimage.binary_opening(diff > 48.0, iterations=1)
            near = ndimage.binary_dilation(strong, iterations=cfg["reach"])
            alpha *= ndimage.gaussian_filter(near.astype(float), 4.0)

    # Motas sueltas fuera.
    labels, count = ndimage.label(alpha > 0.12)
    if count:
        areas = ndimage.sum(np.ones(shape), labels, index=np.arange(1, count + 1))
        small = np.isin(labels, np.where(areas < cfg["min_area"])[0] + 1)
        alpha[small] = 0.0

    if cfg.get("solid"):
        body = ndimage.binary_closing(alpha > 0.45, iterations=3)
        filled = ndimage.binary_fill_holes(body)
        holes = filled & ~body
        hole_labels, _ = ndimage.label(holes)
        for kx, ky in cfg.get("keep", []):
            keep_id = hole_labels[ky - cy0, kx - cx0]
            if keep_id:
                filled &= hole_labels != keep_id
        filled = ndimage.binary_erosion(filled, iterations=1)
        alpha = np.maximum(alpha, ndimage.gaussian_filter(filled.astype(float), 0.8))

    # El recuadro corta con un borde suave, nunca seco; lo excluido no se ve.
    keep = ndimage.binary_erosion(inner, iterations=10)
    for ex0, ey0, ex1, ey1 in cfg.get("exclude", []):
        keep[max(0, ey0 - cy0):max(0, ey1 - cy0), max(0, ex0 - cx0):max(0, ex1 - cx0)] = False
    soft = ndimage.gaussian_filter(keep.astype(float), 1.5 if cfg.get("exclude") else 5.0)
    soft = np.minimum(soft, ndimage.gaussian_filter(ndimage.binary_erosion(inner, iterations=10).astype(float), 5.0))
    alpha *= soft

    safe = np.maximum(alpha, 1e-3)[..., None]
    fore = np.clip((image - (1.0 - alpha[..., None]) * paper) / safe, 0.0, 255.0)
    fore = np.where(alpha[..., None] > 0.004, fore, paper)

    ys, xs = np.where(alpha > 0.01)
    pad = 4
    by0, by1 = max(0, ys.min() - pad), min(shape[0], ys.max() + pad + 1)
    bx0, bx1 = max(0, xs.min() - pad), min(shape[1], xs.max() + pad + 1)
    rgba = np.dstack([fore, alpha * 255.0])[by0:by1, bx0:bx1]
    out = Image.fromarray(np.clip(rgba + 0.5, 0, 255).astype(np.uint8), "RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"{item_id}.png"
    out.save(path, optimize=True)
    print(f"{path.name}: {out.width}x{out.height} (desde x={cx0 + bx0}, y={cy0 + by0} de la referencia)")


def main() -> None:
    wanted = sys.argv[1:] or list(ITEMS)
    for item_id in wanted:
        extract(item_id, ITEMS[item_id])


if __name__ == "__main__":
    main()
