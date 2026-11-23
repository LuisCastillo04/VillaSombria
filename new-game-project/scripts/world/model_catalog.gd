class_name ModelCatalog
extends RefCounted
## Modelos hechos en Blender que sustituyen la parte visual de piezas procedurales.
##
## Un kit dibuja cada pieza migrada con `draw`: le pasa el id del modelo, la colocación y su código
## procedural como `Callable`. Si hay modelo, sus triángulos se fusionan en el lote del escenario
## (`MeshBatcher.add_surfaces`) con los mismos tres materiales: un escenario sigue siendo tres
## mallas. Si el modelo falta, no se puede leer, no tiene la variante pedida o se lanza el juego con
## `-- --modelos=procedural`, se ejecuta el código procedural de siempre. Colisiones, luces,
## rótulos e interacciones se quedan fuera de ese `Callable`, en el kit: no dependen del modelo.
##
## Contrato de los modelos, procedimiento y estado: docs/blender/README.md y 05-estandares.md.

## Modelos registrados (id → categoría, objeto y fidelidad). La tabla está en `ModelRegistry`.
const MODELS := ModelRegistry.MODELS
const MODELS_DIR := "res://assets/modelos"
## Argumento (después de `--`) que dibuja todo con el código procedural, para comparar.
const PROCEDURAL_ARG := "--modelos=procedural"
## Riesgo R4 (medido en la sesión 2): Godot guarda el color de vértice con 8 bits por canal. Si
## el GLB lo trajera en lineal, como define glTF, los oscuros de la paleta perderían hasta 4/255
## al pasarlos a sRGB. Por eso `blender/scripts/exportar_glb.py` escribe los colores ya en sRGB,
## como los usa el lote (`vertex_color_is_srgb`), y aquí no se convierten.
const LINEAR_VERTEX_COLORS := false
## Material de las caras que toman el color de la pieza (el parámetro `tint` de `draw`): su color
## de vértice es un factor que se multiplica por ese color.
const TINT_MATERIAL := "vs_tinte"
## Tinte de referencia de la segunda pasada de captura (para distinguir las caras teñidas).
const CAPTURE_PROBE := Color(0.5, 0.5, 0.5)
## Tolerancia para reconocer vértices iguales al agrupar triángulos en polígonos (0,1 mm).
const WELD_STEP := 10000.0

## Interruptor global: falso = todas las piezas procedurales, como antes de Blender.
static var enabled := not OS.get_cmdline_user_args().has(PROCEDURAL_ARG)
## Rutas en uso (las pruebas pueden apuntar un id a otra ruta para simular un GLB ausente).
static var paths: Dictionary = {}
## Ids que se dibujan con el código procedural aunque tengan modelo (pruebas y comparaciones).
static var excluded: Dictionary = {}
## Modo captura (herramienta de referencias): `draw` siempre dibuja la pieza procedural y anota
## sus caras en el espacio del modelo en `captures`.
static var capturing := false
static var captures: Array[Dictionary] = []

## Id → {nombre de objeto → superficies} (vacío si el GLB no se pudo leer).
static var _cache: Dictionary = {}
static var _warned: Dictionary = {}
## Profundidad de captura: una pieza no puede dibujar otra pieza migrada dentro de su `Callable`.
static var _capture_depth := 0


## Dibuja la pieza `id` en el lote del escenario. `transform` es relativa al `xform` activo del
## lote; `procedural` recibe el tinte y dibuja la pieza con `batch.*` (nunca colisiones, luces ni
## nodos). Devuelve verdadero si se usó el modelo.
static func draw(
	location: LocationBase,
	id: String,
	transform: Transform3D,
	procedural: Callable,
	variant: String = "",
	tint: Color = Color.WHITE
) -> bool:
	if capturing:
		_capture(location, id, transform, procedural, variant)
		procedural.call(tint)
		return false
	if place_in(location.batch, id, transform, variant, tint):
		return true
	procedural.call(tint)
	return false


## Igual que `draw`, sin escenario: para lotes propios (los pivotes de `CharacterModel`).
## `display` sólo sirve para la captura: dónde colocar el objeto en el .blend para verlo montado
## (cada pivote en su sitio); el juego no lo usa.
static func draw_in(
	batch: MeshBatcher,
	id: String,
	transform: Transform3D,
	procedural: Callable,
	variant: String = "",
	tint: Color = Color.WHITE,
	display: Vector3 = Vector3.ZERO
) -> bool:
	if capturing:
		var entry := _capture_batch(batch, id, transform, procedural, variant, "")
		entry["display"] = display
		procedural.call(tint)
		return false
	if place_in(batch, id, transform, variant, tint):
		return true
	procedural.call(tint)
	return false


## Fusiona el modelo en `batch`. Falso si no se ha dibujado.
static func place_in(
	batch: MeshBatcher, id: String, transform: Transform3D, variant: String = "", tint: Color = Color.WHITE
) -> bool:
	var surfaces := get_surfaces(id, variant)
	if surfaces.is_empty():
		return false
	batch.add_surfaces(surfaces, transform, tint)
	return true


## Superficies de una variante en el espacio del modelo, o vacío si no hay modelo utilizable.
static func get_surfaces(id: String, variant: String = "") -> Array:
	# Un id sin registrar es una pieza preparada pero aún sin modelo: código procedural, sin aviso.
	if not enabled or excluded.has(id) or path_for(id).is_empty():
		return []
	if not _cache.has(id):
		_cache[id] = _load(id)
	var objects: Dictionary = _cache[id]
	if objects.is_empty():
		return []
	var object_name := object_name_for(id, variant)
	if not objects.has(object_name):
		_warn_once("%s/%s" % [id, variant], "ModelCatalog: %s no tiene el objeto «%s»; se usa el código procedural." % [path_for(id), object_name])
		return []
	return objects[object_name]


static func has_model(id: String, variant: String = "") -> bool:
	return not get_surfaces(id, variant).is_empty()


## Nombres de los objetos (variantes) que trae el GLB de `id`.
static func get_objects(id: String) -> Array:
	if not enabled:
		return []
	if not _cache.has(id):
		_cache[id] = _load(id)
	return (_cache[id] as Dictionary).keys()


static func path_for(id: String) -> String:
	if paths.has(id):
		return paths[id]
	if not MODELS.has(id):
		return ""
	return "%s/%s/%s.glb" % [MODELS_DIR, MODELS[id]["categoria"], id]


static func object_name_for(id: String, variant: String = "") -> String:
	var base: String = MODELS[id]["objeto"] if MODELS.has(id) else id
	return base if variant.is_empty() else "%s_%s" % [base, variant]


## Clave de variante a partir de medidas en metros: Vector3(1.6, 0.76, 0.9) → «160x76x90».
static func size_key(size: Variant) -> String:
	var parts: Array[String] = []
	if size is Vector2 or size is Vector3:
		for axis in (2 if size is Vector2 else 3):
			parts.append(str(roundi(size[axis] * 100.0)))
	else:
		parts.append(str(roundi(float(size) * 100.0)))
	return "x".join(parts)


## Libera la caché (al cerrar el juego y entre pruebas).
static func clear() -> void:
	_cache.clear()
	_warned.clear()


static func _load(id: String) -> Dictionary:
	var path := path_for(id)
	if path.is_empty():
		_warn_once(id, "ModelCatalog: no hay ningún modelo con el id «%s»." % id)
		return {}
	if not ResourceLoader.exists(path):
		_warn_once(id, "ModelCatalog: falta %s; «%s» se dibuja con el código procedural." % [path, id])
		return {}
	var scene := load(path) as PackedScene
	if scene == null:
		_warn_once(id, "ModelCatalog: %s no es un modelo; «%s» se dibuja con el código procedural." % [path, id])
		return {}
	var root := scene.instantiate()
	var objects := objects_from_node(root)
	root.free()
	if objects.is_empty():
		_warn_once(id, "ModelCatalog: %s no tiene mallas; «%s» se dibuja con el código procedural." % [path, id])
	return objects


## Cada hijo directo de la raíz de un GLB es un objeto (una variante). Su origen es el punto de
## referencia de la pieza: su posición en el .blend sólo sirve para verlo y no se aplica.
static func objects_from_node(root: Node) -> Dictionary:
	var objects := {}
	for child in root.get_children():
		if child is Node3D:
			var placement := Transform3D((child as Node3D).basis, Vector3.ZERO)
			var surfaces := surfaces_from_node(child, LINEAR_VERTEX_COLORS, placement)
			if not surfaces.is_empty():
				objects[String(child.name)] = surfaces
	return objects


## Convierte las mallas bajo `root` en superficies para `MeshBatcher.add_surfaces`: triángulos sin
## índices en el espacio de `root` (más `root_transform`), color sRGB y capa según el material.
static func surfaces_from_node(root: Node, linear_colors: bool = LINEAR_VERTEX_COLORS, root_transform: Transform3D = Transform3D.IDENTITY) -> Array:
	var by_key: Dictionary = {}
	_collect(root, root_transform, linear_colors, by_key, true)
	var surfaces: Array = []
	var keys := by_key.keys()
	keys.sort()
	for key: String in keys:
		var surface: Dictionary = by_key[key]
		surface["centers"] = polygon_centers(surface["vertices"], surface["normals"], surface["colors"])
		surfaces.append(surface)
	return surfaces


static func _collect(node: Node, transform: Transform3D, linear_colors: bool, by_key: Dictionary, is_root: bool) -> void:
	var own := transform
	if node is Node3D and not is_root:
		own = transform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance := node as MeshInstance3D
		for index in instance.mesh.get_surface_count():
			_append_surface(instance, index, own, linear_colors, by_key)
	for child in node.get_children():
		_collect(child, own, linear_colors, by_key, false)


static func _append_surface(
	instance: MeshInstance3D, index: int, transform: Transform3D, linear_colors: bool, by_key: Dictionary
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
	var tinted := material_name == TINT_MATERIAL
	var key := "%d%s" % [layer, "t" if tinted else ""]
	if not by_key.has(key):
		by_key[key] = {
			"layer": layer,
			"tinted": tinted,
			"vertices": PackedVector3Array(),
			"normals": PackedVector3Array(),
			"colors": PackedColorArray(),
		}
	var target: Dictionary = by_key[key]
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


## Anota las caras de una pieza procedural en el espacio del modelo (herramienta de referencias).
## La pieza se dibuja dos veces, con tinte blanco y gris: las caras que cambian de color son las
## teñidas, y su color con tinte blanco es el factor que guarda el modelo.
static func _capture(location: LocationBase, id: String, transform: Transform3D, procedural: Callable, variant: String) -> void:
	var bodies := location._body.get_child_count() if location._body != null else 0
	var nodes := location.get_child_count()
	var entry := _capture_batch(location.batch, id, transform, procedural, variant, location.location_id)
	entry["colisiones_desde"] = bodies
	var body_now := location._body.get_child_count() if location._body != null else 0
	if body_now != bodies or location.get_child_count() != nodes:
		(entry["errores"] as Array).append("la parte procedural registra colisiones o nodos: deben quedar fuera de draw()")


static func _capture_batch(
	batch: MeshBatcher, id: String, transform: Transform3D, procedural: Callable, variant: String, where: String
) -> Dictionary:
	var placement := batch.xform * transform
	var inverse := placement.affine_inverse()
	var errors: Array[String] = []
	if _capture_depth > 0:
		errors.append("se dibuja dentro de la parte procedural de otra pieza migrada: sacarla fuera")
	_capture_depth += 1
	var was_recording := batch.recording
	batch.recording = true
	var start := batch.recorded.size()
	procedural.call(Color.WHITE)
	var middle := batch.recorded.size()
	procedural.call(CAPTURE_PROBE)
	var finish := batch.recorded.size()
	batch.recording = was_recording
	_capture_depth -= 1
	var faces: Array[Dictionary] = []
	if finish - middle != middle - start:
		errors.append("la pieza no dibuja lo mismo con dos tintes distintos")
	else:
		for offset in middle - start:
			var white: Dictionary = batch.recorded[start + offset]
			var probe: Dictionary = batch.recorded[middle + offset]
			var color: Color = white["color"]
			var probed: Color = probe["color"]
			var tinted := not color.is_equal_approx(probed)
			if tinted:
				var expected := Color(color.r * CAPTURE_PROBE.r, color.g * CAPTURE_PROBE.g, color.b * CAPTURE_PROBE.b, color.a)
				if absf(expected.r - probed.r) + absf(expected.g - probed.g) + absf(expected.b - probed.b) > 0.003:
					errors.append("una cara cambia con el tinte sin ser proporcional a él (¿lightened?)")
				if white["layer"] != MeshBatcher.Layer.OPAQUE:
					errors.append("una cara teñida no está en la capa opaca")
			var points := PackedVector3Array()
			for point: Vector3 in white["points"]:
				points.append(inverse * point)
			faces.append({"points": points, "color": color, "layer": white["layer"], "tinted": tinted})
	var entry := {
		"id": id,
		"variant": variant,
		"faces": faces,
		"where": where,
		"placement": placement,
		"errores": errors,
	}
	captures.append(entry)
	return entry


static func _warn_once(key: String, message: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(message)


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
