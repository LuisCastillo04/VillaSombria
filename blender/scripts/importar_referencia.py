"""Crea el .blend editable de un modelo a partir de su referencia exportada desde Godot.

Uso (desde la raíz del repositorio):
  blender --background --factory-startup --python blender/scripts/importar_referencia.py -- --id buzon

Lee blender/referencias/<id>.json (tools/modelos/exportar_referencias.tscn) y guarda
blender/fuentes/<categoría>/<id>.blend con dos colecciones:
  Exportar    un objeto editable por variante («Silla», «Mesa_160x76x90»...): lo único que llega
              al juego. El origen de cada objeto es el punto de referencia de la pieza; los
              objetos se reparten a lo largo de X sólo para verlos (el juego no usa su posición)
  Referencia  la pieza original en alambre y sus cajas de colisión; nunca se exporta
Caras con material vs_tinte: toman el color de la pieza en el juego; su color es un factor (blanco
= el color tal cual, gris = más oscuro).
Si el .blend ya existe no se sobrescribe salvo con --forzar (podría tener retoques a mano).
"""

import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vs_comun as vs  # noqa: E402


def escena_vacia():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    escena = bpy.context.scene
    escena.unit_settings.system = "METRIC"
    escena.unit_settings.scale_length = 1.0
    bpy.context.preferences.filepaths.save_version = 0
    return escena


def material(nombre):
    """Material de vista previa: el juego sólo lee el nombre (la capa del lote)."""
    existente = bpy.data.materials.get(nombre)
    if existente is not None:
        return existente
    mat = bpy.data.materials.new(nombre)
    try:
        mat.use_nodes = True
    except AttributeError:
        pass
    arbol = mat.node_tree
    principled = next(n for n in arbol.nodes if n.type == "BSDF_PRINCIPLED")
    color = arbol.nodes.new("ShaderNodeVertexColor")
    color.layer_name = vs.ATRIBUTO_COLOR
    color.location = (principled.location.x - 300, principled.location.y)
    arbol.links.new(color.outputs["Color"], principled.inputs["Base Color"])
    principled.inputs["Roughness"].default_value = 0.82
    if nombre == "vs_brillo":
        arbol.links.new(color.outputs["Color"], principled.inputs["Emission Color"])
        principled.inputs["Emission Strength"].default_value = 1.0
    return mat


def malla_desde_caras(nombre, caras, fusionar=True):
    """Malla de Blender con un polígono por cara de Godot, color por esquina y sombreado plano."""
    vertices = []
    poligonos = []
    colores = []
    capas = []
    for cara in caras:
        indices = []
        for punto in cara["puntos"]:
            indices.append(len(vertices))
            vertices.append(vs.godot_a_blender(punto))
        poligonos.append(indices)
        srgb = vs.color_html(cara["color"])
        colores.append(tuple(vs.srgb_a_lineal(c) for c in srgb[:3]) + (srgb[3],))
        capas.append(vs.CAPAS[cara["capa"]])
    malla = bpy.data.meshes.new(nombre)
    malla.from_pydata(vertices, [], poligonos)
    nombres_material = sorted(set(capas), key=list(vs.CAPAS.values()).index)
    for nombre_material in nombres_material:
        malla.materials.append(material(nombre_material))
    for indice, poligono in enumerate(malla.polygons):
        poligono.material_index = nombres_material.index(capas[indice])
        poligono.use_smooth = False
    atributo = malla.color_attributes.new(vs.ATRIBUTO_COLOR, "FLOAT_COLOR", "CORNER")
    for poligono in malla.polygons:
        for bucle in poligono.loop_indices:
            atributo.data[bucle].color = colores[poligono.index]
    malla.color_attributes.active_color = atributo
    malla.color_attributes.render_color_index = malla.color_attributes.find(vs.ATRIBUTO_COLOR)
    if fusionar:
        # Une los vértices coincidentes para poder editar la malla como una sola pieza; los
        # colores van por esquina y el sombreado es plano, así que el aspecto no cambia.
        bm = bmesh.new()
        bm.from_mesh(malla)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00001)
        bm.to_mesh(malla)
        bm.free()
    malla.validate()
    return malla


def caja_colision(nombre, colision, coleccion):
    centro = vs.godot_a_blender(colision["centro"])
    x, y, z = colision["tamano"]
    malla = bpy.data.meshes.new(nombre)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.to_mesh(malla)
    bm.free()
    objeto = bpy.data.objects.new(nombre, malla)
    objeto.location = centro
    objeto.scale = (x, z, y)
    import math
    objeto.rotation_euler = (0.0, 0.0, math.radians(colision.get("giro_y", 0.0)))
    objeto.display_type = "WIRE"
    objeto.hide_render = True
    coleccion.objects.link(objeto)
    return objeto


def construir(datos):
    escena = escena_vacia()
    exportar = bpy.data.collections.new(vs.COLECCION_EXPORTAR)
    referencia = bpy.data.collections.new(vs.COLECCION_REFERENCIA)
    escena.collection.children.link(exportar)
    escena.collection.children.link(referencia)
    referencia.hide_render = True
    referencia.color_tag = "COLOR_01"
    objetos = []
    desplazamiento = 0.0
    for clave in sorted(datos["variantes"]):
        variante = datos["variantes"][clave]
        nombre = variante["objeto"]
        caja = variante["caja"]
        if "muestra" in variante:
            # Piezas que se ven montadas (los pivotes de un personaje): cada una en su sitio.
            posicion = vs.godot_a_blender(variante["muestra"])
        else:
            if objetos:
                desplazamiento += -caja["min"][0] + 0.5
            posicion = (desplazamiento, 0.0, 0.0)
        objeto = bpy.data.objects.new(nombre, malla_desde_caras(nombre, variante["caras"]))
        objeto.location = posicion
        objeto["vs_usos"] = len(variante.get("usos", []))
        exportar.objects.link(objeto)
        objetos.append(objeto)
        original = bpy.data.objects.new(nombre + "_Original", malla_desde_caras(nombre + "_Original", variante["caras"], False))
        original.display_type = "WIRE"
        original.hide_render = True
        original.location = posicion
        referencia.objects.link(original)
        for indice, colision in enumerate(variante.get("colisiones", [])):
            caja_col = caja_colision("%s_Colision_%02d" % (nombre, indice), colision, referencia)
            caja_col.location = tuple(a + b for a, b in zip(caja_col.location, posicion))
        if "muestra" not in variante:
            desplazamiento += caja["max"][0]
    # Notas para quien abra el archivo: de dónde sale y qué no se debe tocar.
    escena["vs_id"] = datos["id"]
    escena["vs_nota"] = (
        "Exportar con blender/scripts/exportar_glb.py. Frente del atrezo hacia -Y (vista Front). "
        "El origen de cada objeto es el punto de referencia de la pieza; su posición no se exporta. "
        "Las colisiones de Referencia son las del juego: no se exportan."
    )
    capa_vista = bpy.context.view_layer.layer_collection.children[vs.COLECCION_EXPORTAR]
    bpy.context.view_layer.active_layer_collection = capa_vista
    return objetos


def main():
    args = vs.argumentos()
    id_modelo = args.get("id")
    if not id_modelo:
        vs.fallar("falta --id")
    ruta = vs.ruta_referencia(id_modelo)
    if not os.path.exists(ruta):
        vs.fallar("no existe la referencia %s: expórtala antes desde Godot" % ruta)
    datos = vs.leer_json(ruta)
    destino = vs.ruta_blend(datos["categoria"], id_modelo)
    if os.path.exists(destino) and not args.get("forzar"):
        print("VillaSombria: %s ya existe; se conserva (usa --forzar para rehacerlo)" % destino)
        return
    objetos = construir(datos)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=destino, compress=True)
    for objeto in objetos:
        triangulos = sum(len(p.vertices) - 2 for p in objeto.data.polygons)
        print("VillaSombria: %s -> %s: %s (%d polígonos, %d triángulos)" % (
            id_modelo, destino, objeto.name, len(objeto.data.polygons), triangulos))


main()
