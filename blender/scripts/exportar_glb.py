"""Exporta la colección «Exportar» de un .blend a GLB con opciones fijas y deja un registro.

Uso (desde la raíz del repositorio):
  blender --background --factory-startup --python blender/scripts/exportar_glb.py -- --id buzon --categoria atrezo
Opcionales: --blend <ruta> --destino <ruta.glb>

Comprueba antes de exportar que la colección sólo tiene mallas con transformaciones aplicadas,
atributo de color «Color» y materiales de capa (vs_opaco, vs_brillo, vs_suelo). Si una opción
del exportador no existe en esta versión de Blender, se detiene en lugar de exportar distinto.
Escribe blender/registro/<id>.json con versiones, triángulos, caja (en ejes de Godot) y huella.

Color (riesgo R4): el .blend guarda los colores en lineal, como espera Blender, pero el GLB se
escribe con los valores codificados en sRGB. Godot guarda el color de vértice con 8 bits por
canal y el lote lo usa como sRGB: en lineal, los colores oscuros de la paleta perderían hasta
4/255 al volver a sRGB. La conversión se hace en memoria; el .blend no se guarda.
"""

import datetime
import hashlib
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vs_comun as vs  # noqa: E402

OPCIONES = {
    "export_format": "GLB",
    "use_active_collection": True,
    "use_active_collection_with_nested": True,
    "export_yup": True,
    "export_apply": True,
    "export_normals": True,
    "export_vertex_color": "ACTIVE",
    "export_all_vertex_colors": False,
    "export_materials": "EXPORT",
    "export_image_format": "NONE",
    "export_lights": False,
    "export_cameras": False,
    "export_extras": False,
    "export_animations": False,
    "export_skins": False,
    "export_morph": False,
}
MATERIALES_VALIDOS = set(vs.CAPAS.values()) | {"vs_tinte"}


def comprobar_opciones():
    propiedades = bpy.ops.export_scene.gltf.get_rna_type().properties
    for nombre, valor in OPCIONES.items():
        if nombre not in propiedades.keys():
            vs.fallar("el exportador glTF no tiene la opción %s (¿cambió Blender?)" % nombre)
        prop = propiedades[nombre]
        validos = [i.identifier for i in prop.enum_items] if prop.type == "ENUM" else []
        # Algunas listas (export_format) se calculan al usarlas y aquí salen vacías.
        if validos and valor not in validos:
            vs.fallar("la opción %s no admite %s en esta versión" % (nombre, valor))


def version_exportador():
    import addon_utils
    for modulo in addon_utils.modules():
        if modulo.__name__.endswith("io_scene_gltf2"):
            return ".".join(str(v) for v in modulo.bl_info.get("version", ()))
    return "desconocida"


def comprobar_coleccion(coleccion):
    problemas = []
    objetos = list(coleccion.all_objects)
    if not objetos:
        problemas.append("la colección «%s» está vacía" % coleccion.name)
    for objeto in objetos:
        if objeto.type != "MESH":
            problemas.append("%s no es una malla (%s): sin luces, cámaras ni esqueletos" % (objeto.name, objeto.type))
            continue
        if objeto.parent is None:
            if any(abs(v) > 1e-6 for v in objeto.rotation_euler) or any(abs(v - 1.0) > 1e-6 for v in objeto.scale):
                problemas.append("%s tiene giro o escala sin aplicar (Ctrl + A)" % objeto.name)
        if any(v < 0 for v in objeto.scale):
            problemas.append("%s tiene escala negativa" % objeto.name)
        malla = objeto.data
        if malla.color_attributes.get(vs.ATRIBUTO_COLOR) is None:
            problemas.append("%s no tiene atributo de color «%s»" % (objeto.name, vs.ATRIBUTO_COLOR))
        for mat in malla.materials:
            if mat is None or mat.name.split(".")[0] not in MATERIALES_VALIDOS:
                problemas.append("%s usa el material %s; válidos: %s" % (
                    objeto.name, mat.name if mat else "vacío", ", ".join(sorted(MATERIALES_VALIDOS))))
    if problemas:
        vs.fallar("no se exporta:\n  - " + "\n  - ".join(problemas))
    return objetos


def colores_a_srgb(objetos):
    """Recodifica en sRGB el atributo de color de cada malla (sólo en memoria, para el GLB)."""
    mallas = {objeto.data for objeto in objetos}
    for malla in mallas:
        atributo = malla.color_attributes.get(vs.ATRIBUTO_COLOR)
        for dato in atributo.data:
            r, g, b, a = dato.color
            dato.color = (vs.lineal_a_srgb(r), vs.lineal_a_srgb(g), vs.lineal_a_srgb(b), a)


def medir(objetos):
    deps = bpy.context.evaluated_depsgraph_get()
    triangulos = 0
    bajo = [float("inf")] * 3
    alto = [float("-inf")] * 3
    por_objeto = {}
    for objeto in objetos:
        evaluado = objeto.evaluated_get(deps)
        malla = evaluado.to_mesh()
        malla.calc_loop_triangles()
        por_objeto[objeto.name] = len(malla.loop_triangles)
        triangulos += len(malla.loop_triangles)
        for vertice in malla.vertices:
            punto = vs.blender_a_godot(tuple(objeto.matrix_world @ vertice.co))
            for eje in range(3):
                bajo[eje] = min(bajo[eje], punto[eje])
                alto[eje] = max(alto[eje], punto[eje])
        evaluado.to_mesh_clear()
    redondear = lambda v: [round(x, 5) for x in v]  # noqa: E731
    return triangulos, por_objeto, {"min": redondear(bajo), "max": redondear(alto)}


def main():
    args = vs.argumentos()
    id_modelo = args.get("id")
    if not id_modelo:
        vs.fallar("falta --id")
    categoria = args.get("categoria")
    blend = args.get("blend") or (vs.ruta_blend(categoria, id_modelo) if categoria else None)
    if not blend or not os.path.exists(blend):
        vs.fallar("no existe el .blend (%s); indica --categoria o --blend" % blend)
    destino = args.get("destino") or vs.ruta_glb(categoria, id_modelo)
    bpy.ops.wm.open_mainfile(filepath=blend)
    comprobar_opciones()
    capas = bpy.context.view_layer.layer_collection.children
    if vs.COLECCION_EXPORTAR not in capas.keys():
        vs.fallar("%s no tiene la colección «%s»" % (blend, vs.COLECCION_EXPORTAR))
    capa = capas[vs.COLECCION_EXPORTAR]
    capa.exclude = False
    bpy.context.view_layer.active_layer_collection = capa
    objetos = comprobar_coleccion(capa.collection)
    triangulos, por_objeto, caja = medir(objetos)
    colores_a_srgb(objetos)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=destino, **OPCIONES)
    with open(destino, "rb") as archivo:
        huella = hashlib.sha256(archivo.read()).hexdigest()
    registro = {
        "id": id_modelo,
        "blend": os.path.relpath(blend, vs.RAIZ).replace("\\", "/"),
        "glb": os.path.relpath(destino, vs.RAIZ).replace("\\", "/"),
        "fecha": datetime.datetime.now().isoformat(timespec="seconds"),
        "blender": bpy.app.version_string,
        "exportador_gltf": version_exportador(),
        "triangulos": triangulos,
        "triangulos_por_objeto": por_objeto,
        "caja_godot": caja,
        "sha256": huella,
        "color_de_vertice": "sRGB (codificado al exportar; el .blend lo guarda en lineal)",
        "opciones": OPCIONES,
    }
    vs.escribir_json(vs.ruta_registro(id_modelo), registro)
    print("VillaSombria: %s -> %s (%d triángulos, sha256 %s)" % (id_modelo, destino, triangulos, huella[:12]))


main()
