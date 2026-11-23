"""Utilidades compartidas por los scripts de Blender de Villa Sombría.

Convenciones (docs/blender/05-estandares.md):
- Godot usa Y arriba y Blender Z arriba: un punto de Godot (x, y, z) es (x, -z, y) en Blender.
  El exportador glTF (export_yup=True) deshace el cambio.
- El atrezo mira a +Z en Godot, es decir, a -Y en Blender (vista Front).
- Colores: el juego trabaja en sRGB; los atributos de color de Blender y glTF son lineales.
"""

import json
import os
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BLENDER = os.path.join(RAIZ, "blender")
PROYECTO = os.path.join(RAIZ, "new-game-project")

CAPAS = {"opaco": "vs_opaco", "brillo": "vs_brillo", "suelo": "vs_suelo"}
COLECCION_EXPORTAR = "Exportar"
COLECCION_REFERENCIA = "Referencia"
ATRIBUTO_COLOR = "Color"


def argumentos():
    """Argumentos después de `--` como diccionario: --id buzon --categoria atrezo."""
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    datos = {}
    clave = None
    for arg in args:
        if arg.startswith("--"):
            clave = arg[2:]
            datos[clave] = True
        elif clave is not None:
            datos[clave] = arg
            clave = None
    return datos


def ruta_referencia(id_modelo):
    return os.path.join(BLENDER, "referencias", id_modelo + ".json")


def ruta_blend(categoria, id_modelo):
    return os.path.join(BLENDER, "fuentes", categoria, id_modelo + ".blend")


def ruta_glb(categoria, id_modelo):
    return os.path.join(PROYECTO, "assets", "modelos", categoria, id_modelo + ".glb")


def ruta_registro(id_modelo):
    return os.path.join(BLENDER, "registro", id_modelo + ".json")


def leer_json(ruta):
    with open(ruta, encoding="utf-8") as archivo:
        return json.load(archivo)


def escribir_json(ruta, datos):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    with open(ruta, "w", encoding="utf-8", newline="\n") as archivo:
        json.dump(datos, archivo, ensure_ascii=False, indent="\t")
        archivo.write("\n")


def godot_a_blender(punto):
    x, y, z = punto
    return (x, -z, y)


def blender_a_godot(punto):
    x, y, z = punto
    return (x, z, -y)


def srgb_a_lineal(valor):
    if valor <= 0.04045:
        return valor / 12.92
    return ((valor + 0.055) / 1.055) ** 2.4


def lineal_a_srgb(valor):
    if valor <= 0.0031308:
        return valor * 12.92
    return 1.055 * (valor ** (1.0 / 2.4)) - 0.055


def color_html(texto):
    """'rrggbbaa' o 'rrggbb' (sRGB) -> tupla de cuatro floats sRGB."""
    texto = texto.lstrip("#")
    canales = [int(texto[i:i + 2], 16) / 255.0 for i in range(0, len(texto), 2)]
    if len(canales) == 3:
        canales.append(1.0)
    return tuple(canales)


def fallar(mensaje):
    print("ERROR VillaSombria: " + mensaje)
    sys.exit(1)
