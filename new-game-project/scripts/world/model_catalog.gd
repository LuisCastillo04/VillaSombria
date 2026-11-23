class_name ModelCatalog
extends RefCounted
## Modelos hechos en Blender que sustituyen la parte visual de piezas procedurales.
##
## Un modelo no se instancia como nodo: sus triángulos se fusionan en el lote del escenario
## (`MeshBatcher.add_surfaces`), con los mismos tres materiales, así que el escenario sigue
## dibujándose con tres mallas. Colisiones, luces, rótulos e interacciones siguen en el kit, sin
## cambios. Si el modelo falta, no se puede leer o se pide el modo procedural, `place` devuelve
## falso y el kit dibuja la pieza con su código de siempre.
##
## Origen de los modelos y procedimiento: docs/blender/README.md.

## Id del modelo → GLB. Única tabla de rutas: renombrar o mover un modelo se hace aquí.
const MODELS := {
	"buzon": "res://assets/modelos/atrezo/buzon.glb",
}
## Argumento (después de `--`) que dibuja todo con el código procedural, para comparar.
const PROCEDURAL_ARG := "--modelos=procedural"
## glTF define los colores de vértice en espacio lineal y el lote los usa en sRGB
## (`vertex_color_is_srgb`): se convierten al leer (riesgo R4, medido en la sesión 2).
const LINEAR_VERTEX_COLORS := true
## Tolerancia para reconocer vértices iguales al agrupar triángulos en polígonos (0,1 mm).
const WELD_STEP := 10000.0

## Interruptor global: falso = todas las piezas procedurales, como antes de Blender.
static var enabled := not OS.get_cmdline_user_args().has(PROCEDURAL_ARG)
## Tabla en uso (las pruebas pueden apuntar un id a otra ruta para simular un modelo ausente).
static var paths: Dictionary = MODELS.duplicate()

## Id → superficies ya convertidas (vacío si el modelo no se pudo leer).
static var _cache: Dictionary = {}


## Fusiona el modelo `id` en el lote del escenario, en `transform` (relativa al `xform` activo
## del lote). Devuelve falso si no se ha dibujado: entonces el kit dibuja la pieza procedural.
static func place(location: LocationBase, id: String, transform: Transform3D) -> bool:
	return place_in(location.batch, id, transform)


static func place_in(batch: MeshBatcher, id: String, transform: Transform3D) -> bool:
	var surfaces := get_surfaces(id)
	if surfaces.is_empty():
		return false
	batch.add_surfaces(surfaces, transform)
	return true


## Superficies del modelo en su propio espacio, o vacío si no hay modelo utilizable.
static func get_surfaces(id: String) -> Array:
	if not enabled:
		return []
	if not _cache.has(id):
		_cache[id] = _load(id)
	return _cache[id]


static func has_model(id: String) -> bool:
	return not get_surfaces(id).is_empty()


## Libera la caché (al cerrar el juego y entre pruebas).
static func clear() -> void:
	_cache.clear()


static func _load(id: String) -> Array:
	if not paths.has(id):
		push_warning("ModelCatalog: no hay ningún modelo con el id «%s»." % id)
		return []
	var path: String = paths[id]
	if not ResourceLoader.exists(path):
		push_warning("ModelCatalog: falta %s; «%s» se dibuja con el código procedural." % [path, id])
		return []
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("ModelCatalog: %s no es una escena; «%s» se dibuja con el código procedural." % [path, id])
		return []
	var root := scene.instantiate()
	var surfaces := surfaces_from_node(root)
	root.free()
	if surfaces.is_empty():
		push_warning("ModelCatalog: %s no tiene mallas; «%s» se dibuja con el código procedural." % [path, id])
	return surfaces


## Convierte todas las mallas bajo `root` en superficies para `MeshBatcher.add_surfaces`, en el
## espacio de `root`: triángulos sin índices, color sRGB y capa según el nombre del material.
static func surfaces_from_node(root: Node, linear_colors: bool = LINEAR_VERTEX_COLORS) -> Array:
	var by_layer: Dictionary = {}
	_collect(root, Transform3D.IDENTITY, linear_colors, by_layer)
	var surfaces: Array = []
	for layer: MeshBatcher.Layer in [MeshBatcher.Layer.OPAQUE, MeshBatcher.Layer.GLOW, MeshBatcher.Layer.GROUND]:
		if by_layer.has(layer):
			var surface: Dictionary = by_layer[layer]
			surface["centers"] = polygon_centers(surface["vertices"], surface["normals"], surface["colors"])
			surfaces.append(surface)
	return surfaces


static func _collect(node: Node, parent: Transform3D, linear_colors: bool, by_layer: Dictionary) -> void:
	var transform := parent
	if node is Node3D:
		transform = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance := node as MeshInstance3D
		for index in instance.mesh.get_surface_count():
			_append_surface(instance, index, transform, linear_colors, by_layer)
	for child in node.get_children():
		_collect(child, transform, linear_colors, by_layer)


static func _append_surface(
	instance: MeshInstance3D, index: int, transform: Transform3D, linear_colors: bool, by_layer: Dictionary
) -> void:
	var mesh := instance.mesh
	if mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES:
		return
	var arrays := mesh.surface_get_arrays(index)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
	var colors: Variant = arrays[Mesh.ARRAY_COLOR]
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	var material := instance.get_surface_override_material(index)
	if material == null:
		material = mesh.surface_get_material(index)
	var material_name: String = material.resource_name if material != null else mesh.surface_get_name(index)
	var fallback := Color.WHITE
	if material is BaseMaterial3D:
		fallback = (material as BaseMaterial3D).albedo_color
	var layer := MeshBatcher.layer_for_material(material_name)
	if not by_layer.has(layer):
		by_layer[layer] = {
			"layer": layer,
			"vertices": PackedVector3Array(),
			"normals": PackedVector3Array(),
			"colors": PackedColorArray(),
		}
	var target: Dictionary = by_layer[layer]
	var normal_basis := transform.basis.inverse().transposed()
	var order := PackedInt32Array()
	if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty():
		order = indices
	else:
		order.resize(positions.size())
		for vertex in positions.size():
			order[vertex] = vertex
	var out_vertices: PackedVector3Array = target["vertices"]
	var out_normals: PackedVector3Array = target["normals"]
	var out_colors: PackedColorArray = target["colors"]
	var has_normals := normals is PackedVector3Array and not (normals as PackedVector3Array).is_empty()
	var has_colors := colors is PackedColorArray and not (colors as PackedColorArray).is_empty()
	for vertex: int in order:
		out_vertices.append(transform * positions[vertex])
		var normal := Vector3.UP
		if has_normals:
			normal = (normal_basis * (normals as PackedVector3Array)[vertex]).normalized()
		out_normals.append(normal)
		var color := fallback
		if has_colors:
			color = (colors as PackedColorArray)[vertex]
			if linear_colors:
				color = color.linear_to_srgb()
		out_colors.append(color)
	target["vertices"] = out_vertices
	target["normals"] = out_normals
	target["colors"] = out_colors


## Centro del polígono al que pertenece cada vértice. Los exportadores parten cada polígono en
## triángulos; aquí se vuelven a unir los que comparten arista, normal y color, para que la
## variación de tono sea por polígono, como la de `MeshBatcher.face`.
static func polygon_centers(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray) -> PackedVector3Array:
	var triangles := vertices.size() / 3
	var parent: Array[int] = []
	parent.resize(triangles)
	for triangle in triangles:
		parent[triangle] = triangle
	var edges: Dictionary = {}
	for triangle in triangles:
		for corner in 3:
			var a := _weld(vertices[triangle * 3 + corner])
			var b := _weld(vertices[triangle * 3 + (corner + 1) % 3])
			var key := [a, b] if _less(a, b) else [b, a]
			if edges.has(key):
				var other: int = edges[key]
				if _same_face(normals, colors, triangle * 3, other * 3):
					_union(parent, triangle, other)
			else:
				edges[key] = triangle
	var points_by_group: Dictionary = {}
	for triangle in triangles:
		var group := _find(parent, triangle)
		if not points_by_group.has(group):
			points_by_group[group] = {}
		for corner in 3:
			var point := vertices[triangle * 3 + corner]
			(points_by_group[group] as Dictionary)[_weld(point)] = point
	var center_by_group: Dictionary = {}
	for group: int in points_by_group:
		var unique: Dictionary = points_by_group[group]
		var sum := Vector3.ZERO
		for point: Vector3 in unique.values():
			sum += point
		center_by_group[group] = sum / float(unique.size())
	var centers := PackedVector3Array()
	centers.resize(vertices.size())
	for triangle in triangles:
		var center: Vector3 = center_by_group[_find(parent, triangle)]
		for corner in 3:
			centers[triangle * 3 + corner] = center
	return centers


static func _weld(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * WELD_STEP), roundi(point.y * WELD_STEP), roundi(point.z * WELD_STEP))


static func _less(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z


static func _same_face(normals: PackedVector3Array, colors: PackedColorArray, a: int, b: int) -> bool:
	if normals[a].dot(normals[b]) < 0.999:
		return false
	var difference := colors[a] - colors[b]
	return absf(difference.r) + absf(difference.g) + absf(difference.b) < 0.004


static func _find(parent: Array[int], item: int) -> int:
	while parent[item] != item:
		parent[item] = parent[parent[item]]
		item = parent[item]
	return item


static func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a != root_b:
		parent[maxi(root_a, root_b)] = mini(root_a, root_b)
