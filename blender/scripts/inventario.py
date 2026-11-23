"""Inventario de los modelos migrados, generado a partir de los archivos del repositorio.

Uso (desde la raíz del repositorio, con el Python del sistema):
  python blender/scripts/inventario.py > new-game-project/docs/blender/INVENTARIO_MODELOS.md

Lee el registro de modelos (scripts/world/model_registry.gd), las referencias capturadas
(blender/referencias/<id>.json) y los registros de exportación (blender/registro/<id>.json), y
comprueba que existen el .blend, el GLB y su .import. No necesita Godot ni Blender.
"""

import json
import os
import re
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PROYECTO = os.path.join(RAIZ, "new-game-project")
REGISTRO_GD = os.path.join(PROYECTO, "scripts", "world", "model_registry.gd")
ENTRADA = re.compile(r'^\s*"(?P<id>[a-z0-9_]+)":\s*\{"categoria":\s*"(?P<cat>[a-z_]+)",\s*"objeto":\s*"(?P<obj>\w+)",\s*"fiel":\s*(?P<fiel>true|false|"\w+")\}', re.M)


def leer(ruta):
    if not os.path.exists(ruta):
        return None
    with open(ruta, encoding="utf-8") as archivo:
        return json.load(archivo)


def modelos():
    with open(REGISTRO_GD, encoding="utf-8") as archivo:
        texto = archivo.read()
    return [m.groupdict() for m in ENTRADA.finditer(texto)]


def main():
    filas = []
    total_tri = 0
    total_usos = 0
    for modelo in modelos():
        id_modelo, categoria = modelo["id"], modelo["cat"]
        referencia = leer(os.path.join(RAIZ, "blender", "referencias", id_modelo + ".json")) or {}
        registro = leer(os.path.join(RAIZ, "blender", "registro", id_modelo + ".json")) or {}
        blend = os.path.join("blender", "fuentes", categoria, id_modelo + ".blend")
        glb = os.path.join("new-game-project", "assets", "modelos", categoria, id_modelo + ".glb")
        variantes = referencia.get("variantes", {})
        usos = sum(len(v.get("usos", [])) for v in variantes.values())
        escenarios = sorted({u["escenario"] or "personaje" for v in variantes.values() for u in v.get("usos", [])})
        triangulos = registro.get("triangulos", 0)
        tinte = any(c["capa"] == "tinte" for v in variantes.values() for c in v.get("caras", []))
        colisiones = sum(len(v.get("colisiones", [])) for v in variantes.values())
        brillo = any(c["capa"] == "brillo" for v in variantes.values() for c in v.get("caras", []))
        estado = "migrado"
        faltan = [n for n, r in (("blend", blend), ("glb", glb), ("import", glb + ".import")) if not os.path.exists(os.path.join(RAIZ, r))]
        if faltan:
            estado = "incompleto (falta " + ", ".join(faltan) + ")"
        fiel = modelo["fiel"].strip('"')
        filas.append((categoria, id_modelo, len(variantes), usos, ", ".join(escenarios), triangulos, colisiones,
                      "sí" if tinte else "—", "sí" if brillo else "—", {"true": "exacto", "false": "retocado"}.get(fiel, fiel), estado))
        total_tri += triangulos
        total_usos += usos
    filas.sort()
    print("# Inventario de modelos migrados")
    print()
    print("Generado con `python blender/scripts/inventario.py` a partir del registro de modelos, las")
    print("referencias y los registros de exportación. No editar a mano: volver a generarlo.")
    print()
    print("Cada modelo tiene su fuente en `blender/fuentes/<categoría>/<id>.blend`, su GLB en")
    print("`new-game-project/assets/modelos/<categoría>/<id>.glb` y su respaldo procedural en el kit o")
    print("el escenario que lo dibuja (`ModelCatalog.draw`). Triángulos: de todas las variantes, una vez.")
    print()
    print("| Categoría | Id | Variantes | Usos | Dónde | Triángulos | Colisiones (kit) | Tinte | Brillo | Fidelidad | Estado |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for fila in filas:
        print("| " + " | ".join(str(c) for c in fila) + " |")
    print()
    print("**Total:** %d modelos, %d usos en el juego, %d triángulos en los GLB." % (len(filas), total_usos, total_tri))


if __name__ == "__main__":
    sys.exit(main())
