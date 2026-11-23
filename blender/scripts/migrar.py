"""Proceso completo de migración de modelos, de principio a fin, con una sola orden.

Uso (desde la raíz del repositorio, con el Python del sistema):
  python blender/scripts/migrar.py                    todos los modelos de ModelCatalog.MODELS
  python blender/scripts/migrar.py --ids silla,mesa   sólo esos
  python blender/scripts/migrar.py --forzar           rehace también los .blend existentes
  python blender/scripts/migrar.py --solo-validar     sólo la validación final

Pasos:
  1. Godot captura las referencias desde los escenarios (tools/modelos/exportar_referencias.tscn).
  2. Blender crea el .blend de cada modelo que aún no lo tenga (importar_referencia.py) y exporta
     todos a GLB (exportar_glb.py). Un .blend existente nunca se sobrescribe sin --forzar.
  3. Godot importa los GLB; los .import nuevos se ajustan (sin LOD, mallas de sombra ni
     tangentes: el juego sólo lee los triángulos) y se vuelven a importar.
  4. Godot valida los modelos (tools/modelos/validar_modelos.tscn).
Las rutas de los programas se pueden cambiar con GODOT_BIN y BLENDER_BIN.
"""

import argparse
import os
import subprocess
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PROYECTO = os.path.join(RAIZ, "new-game-project")
GODOT = os.environ.get(
    "GODOT_BIN", r"D:\Program Files (x86)\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
BLENDER = os.environ.get("BLENDER_BIN", r"D:\Program Files (x86)\steam\steamapps\common\Blender\blender.exe")
AJUSTES_IMPORTACION = {
    "meshes/ensure_tangents": "false",
    "meshes/generate_lods": "false",
    "meshes/create_shadow_meshes": "false",
}


def ejecutar(titulo, orden, cwd):
    print("== %s ==" % titulo, flush=True)
    resultado = subprocess.run(orden, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    salida = (resultado.stdout or "") + (resultado.stderr or "")
    interesantes = [l for l in salida.splitlines() if l.startswith(("VillaSombria", "ERROR", "FALLO", "OK ", "Exportada", "AVISO", "RESUMEN"))]
    for linea in interesantes:
        print("   " + linea)
    if resultado.returncode != 0:
        print("   -> FALLÓ (código %d)" % resultado.returncode)
        if not interesantes:
            print(salida[-3000:])
        sys.exit(resultado.returncode or 1)
    return salida


def referencias(ids):
    orden = [GODOT, "--headless", "--path", PROYECTO, "res://tools/modelos/exportar_referencias.tscn", "--"]
    if ids:
        orden.append("--pieza=" + ",".join(ids))
    salida = ejecutar("Referencias desde Godot", orden, PROYECTO)
    exportadas = []
    for linea in salida.splitlines():
        if linea.startswith("Exportada "):
            exportadas.append(linea.split()[1])
    return exportadas


def leer_categoria(id_modelo):
    import json
    with open(os.path.join(RAIZ, "blender", "referencias", id_modelo + ".json"), encoding="utf-8") as archivo:
        return json.load(archivo)["categoria"]


def blender(script, *args):
    return [BLENDER, "--background", "--factory-startup", "--python", os.path.join(RAIZ, "blender", "scripts", script), "--", *args]


def ajustar_importaciones():
    cambiados = 0
    carpeta = os.path.join(PROYECTO, "assets", "modelos")
    for raiz, _, archivos in os.walk(carpeta):
        for nombre in archivos:
            if not nombre.endswith(".glb.import"):
                continue
            ruta = os.path.join(raiz, nombre)
            with open(ruta, encoding="utf-8") as archivo:
                texto = archivo.read()
            nuevo = texto
            for clave, valor in AJUSTES_IMPORTACION.items():
                for actual in ("true", "false"):
                    nuevo = nuevo.replace("%s=%s" % (clave, actual), "%s=%s" % (clave, valor))
            if nuevo != texto:
                with open(ruta, "w", encoding="utf-8", newline="\n") as archivo:
                    archivo.write(nuevo)
                cambiados += 1
    return cambiados


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ids", default="")
    parser.add_argument("--forzar", action="store_true")
    parser.add_argument("--solo-validar", action="store_true")
    args = parser.parse_args()
    ids = [i for i in args.ids.split(",") if i]
    if not args.solo_validar:
        for id_modelo in referencias(ids):
            categoria = leer_categoria(id_modelo)
            blend = os.path.join(RAIZ, "blender", "fuentes", categoria, id_modelo + ".blend")
            if args.forzar or not os.path.exists(blend):
                extra = ["--forzar"] if args.forzar else []
                ejecutar("Blender: .blend de %s" % id_modelo, blender("importar_referencia.py", "--id", id_modelo, *extra), RAIZ)
            ejecutar("Blender: GLB de %s" % id_modelo, blender("exportar_glb.py", "--id", id_modelo, "--categoria", categoria), RAIZ)
        ejecutar("Importación en Godot", [GODOT, "--headless", "--path", PROYECTO, "--import"], PROYECTO)
        if ajustar_importaciones():
            ejecutar("Reimportación con los ajustes de modelos", [GODOT, "--headless", "--path", PROYECTO, "--import"], PROYECTO)
    orden = [GODOT, "--headless", "--path", PROYECTO, "res://tools/modelos/validar_modelos.tscn", "--"]
    if ids:
        orden.append("--pieza=" + ",".join(ids))
    ejecutar("Validación de los modelos", orden, PROYECTO)
    print("Todo correcto.")


if __name__ == "__main__":
    main()
