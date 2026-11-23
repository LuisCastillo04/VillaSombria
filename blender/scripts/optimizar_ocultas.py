"""Quita de los objetos de un .blend las caras que la cámara del juego nunca ve.

Uso (desde la raíz del repositorio):
  blender --background --factory-startup --python blender/scripts/optimizar_ocultas.py -- --id estanteria --categoria mobiliario --quitar abajo,detras_interior

La cámara de exploración de Villa Sombría tiene una inclinación fija de -36° (mira desde arriba;
`exploration_camera.gd`), así que no ve:
  abajo            caras que miran hacia abajo (normal con z < -0,99 en Blender): bases apoyadas
                   en una balda o en el suelo
  detras_interior  caras que miran hacia atrás (normal con y > 0,99 en Blender, -Z en Godot), no
                   son la trasera del propio mueble y quedan enteras detrás de ella (dentro de su
                   anchura y su altura): las de los libros, las baldas y los laterales que dan
                   contra el fondo. Se conservan la trasera exterior (dos estanterías espalda con
                   espalda dejan ver una franja desde arriba) y lo que asoma por encima o por los
                   lados (los libros más altos de la última balda, el canto de los laterales)
Sólo se aplica a la colección «Exportar» y se guarda el .blend (con copia en el registro de la
operación). Después hay que exportar el GLB y marcar el modelo como «optimizado» en ModelCatalog.
"""

import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vs_comun as vs  # noqa: E402

def _tapada_por_el_fondo(cara, fondo):
    if cara.normal.y <= 0.99 or cara.calc_center_median().y >= fondo["y"] - 0.001:
        return False
    return all(
        fondo["x0"] - 0.0005 <= v.co.x <= fondo["x1"] + 0.0005 and fondo["z0"] - 0.0005 <= v.co.z <= fondo["z1"] + 0.0005
        for v in cara.verts
    )


CRITERIOS = {
    "abajo": lambda cara, fondo: cara.normal.z < -0.99,
    "detras_interior": _tapada_por_el_fondo,
}


def medir_fondo(bm):
    """Rectángulo (x, z en Blender) de las caras traseras más alejadas: la trasera del mueble."""
    y = max(v.co.y for v in bm.verts)
    traseras = [f for f in bm.faces if f.normal.y > 0.99 and abs(f.calc_center_median().y - y) < 0.001]
    puntos = [v.co for f in traseras for v in f.verts]
    if not puntos:
        return {"y": y, "x0": 0.0, "x1": -1.0, "z0": 0.0, "z1": -1.0}
    return {
        "y": y,
        "x0": min(p.x for p in puntos), "x1": max(p.x for p in puntos),
        "z0": min(p.z for p in puntos), "z1": max(p.z for p in puntos),
    }


def main():
    args = vs.argumentos()
    id_modelo = args.get("id")
    categoria = args.get("categoria")
    if not id_modelo or not categoria:
        vs.fallar("faltan --id y --categoria")
    criterios = [c for c in str(args.get("quitar", "")).split(",") if c]
    for criterio in criterios:
        if criterio not in CRITERIOS:
            vs.fallar("criterio desconocido %s; válidos: %s" % (criterio, ", ".join(CRITERIOS)))
    blend = vs.ruta_blend(categoria, id_modelo)
    bpy.ops.wm.open_mainfile(filepath=blend)
    bpy.context.preferences.filepaths.save_version = 0
    coleccion = bpy.data.collections.get(vs.COLECCION_EXPORTAR)
    if coleccion is None:
        vs.fallar("%s no tiene la colección Exportar" % blend)
    resumen = {}
    for objeto in coleccion.all_objects:
        if objeto.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(objeto.data)
        antes = sum(len(f.verts) - 2 for f in bm.faces)
        fondo = medir_fondo(bm)
        quitar = [f for f in bm.faces if any(CRITERIOS[c](f, fondo) for c in criterios)]
        bmesh.ops.delete(bm, geom=quitar, context="FACES_ONLY")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        despues = sum(len(f.verts) - 2 for f in bm.faces)
        bm.to_mesh(objeto.data)
        bm.free()
        objeto.data.update()
        objeto["vs_optimizado"] = ",".join(criterios)
        resumen[objeto.name] = (antes, despues)
        print("VillaSombria: %s: %d -> %d triángulos" % (objeto.name, antes, despues))
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    total_antes = sum(a for a, _ in resumen.values())
    total_despues = sum(d for _, d in resumen.values())
    print("VillaSombria: %s optimizado (%s): %d -> %d triángulos" % (id_modelo, ",".join(criterios), total_antes, total_despues))


main()
