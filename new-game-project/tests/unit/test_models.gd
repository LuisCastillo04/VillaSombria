extends TestCase
## Modelos de Blender fusionados en el lote (`ModelCatalog`, `MeshBatcher.add_surfaces`).

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion"]
const QUAD := [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]


func after_each() -> void:
	ModelCatalog.enabled = true
	ModelCatalog.paths = {}
	ModelCatalog.excluded = {}
	ModelCatalog.capturing = false
	ModelCatalog.clear()


## Un polígono importado como dos triángulos recibe el mismo tono que la cara procedural.
func test_imported_polygon_matches_procedural_face() -> void:
	var procedural := MeshBatcher.new()
	procedural.face(PackedVector3Array(QUAD), Palette.WINE, Vector3.UP)
	var recorder := MeshBatcher.new()
	recorder.recording = true
	recorder.face(PackedVector3Array(QUAD), Palette.WINE, Vector3.UP)
	var node := _node_from_recorded(recorder.recorded)
	var surfaces := ModelCatalog.surfaces_from_node(node, false)
	node.free()
	var imported := MeshBatcher.new()
	imported.add_surfaces(surfaces)
	var expected := procedural.build_mesh().surface_get_arrays(0)
	var actual := imported.build_mesh().surface_get_arrays(0)
	check_equal(actual[Mesh.ARRAY_VERTEX], expected[Mesh.ARRAY_VERTEX], "Mismos vértices y en el mismo orden de caras")
	check_equal(actual[Mesh.ARRAY_COLOR], expected[Mesh.ARRAY_COLOR], "Mismo tono por polígono")


func test_surfaces_follow_transform_and_layers() -> void:
	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.position = Vector3(0.0, 1.0, 0.0)
	instance.mesh = _mesh_with_layers()
	root.add_child(instance)
	var surfaces := ModelCatalog.surfaces_from_node(root, false)
	root.free()
	check_equal(surfaces.size(), 2, "Una superficie por capa")
	var layers := surfaces.map(func(surface: Dictionary) -> int: return surface["layer"])
	check(layers.has(MeshBatcher.Layer.OPAQUE) and layers.has(MeshBatcher.Layer.GLOW), "Capas por nombre de material: %s" % str(layers))
	var batch := MeshBatcher.new()
	var place := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(5.0, 0.0, -2.0))
	batch.add_surfaces(surfaces, place)
	var opaque := batch.build_mesh(MeshBatcher.Layer.OPAQUE).surface_get_arrays(0)
	var first: Vector3 = (opaque[Mesh.ARRAY_VERTEX] as PackedVector3Array)[0]
	check(first.is_equal_approx(place * Vector3(0.0, 1.0, 0.0)), "El vértice sigue la transformación del nodo y la de colocación (%s)" % first)
	var normal: Vector3 = (opaque[Mesh.ARRAY_NORMAL] as PackedVector3Array)[0]
	check(normal.dot(Vector3.UP) > 0.9999, "La normal hacia arriba sigue hacia arriba tras girar (%s)" % normal)
	check(batch.build_mesh(MeshBatcher.Layer.GLOW) != null, "La parte de brillo va a la capa de brillo")


func test_linear_colors_are_converted_to_srgb() -> void:
	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	# Un color claro: la malla guarda 8 bits por canal y en lineal los oscuros pierden precisión.
	instance.mesh = _mesh_with_layers(Palette.PAPER.srgb_to_linear())
	root.add_child(instance)
	var surfaces := ModelCatalog.surfaces_from_node(root, true)
	root.free()
	var color: Color = (surfaces[0]["colors"] as PackedColorArray)[0]
	var error := maxf(absf(color.r - Palette.PAPER.r), maxf(absf(color.g - Palette.PAPER.g), absf(color.b - Palette.PAPER.b)))
	check(error <= 1.0 / 255.0, "Lineal → sRGB devuelve el color de la paleta (%s, error %.4f)" % [color, error])


func test_missing_or_disabled_model_falls_back() -> void:
	var batch := MeshBatcher.new()
	check(not ModelCatalog.place_in(batch, "no_existe", Transform3D.IDENTITY), "Un id desconocido no se dibuja")
	ModelCatalog.paths["ausente"] = "res://assets/modelos/no_existe.glb"
	check(not ModelCatalog.place_in(batch, "ausente", Transform3D.IDENTITY), "Un GLB ausente no se dibuja")
	check(batch.is_empty(), "Sin modelo, el lote queda intacto para el código procedural")
	ModelCatalog.enabled = false
	for id: String in ModelCatalog.MODELS:
		check(not ModelCatalog.place_in(batch, id, Transform3D.IDENTITY), "Modo procedural: «%s» no usa el modelo" % id)


func test_mirrored_placement_keeps_faces_outward() -> void:
	var recorder := MeshBatcher.new()
	recorder.recording = true
	recorder.face(PackedVector3Array(QUAD), Palette.STONE, Vector3.UP)
	var node := _node_from_recorded(recorder.recorded)
	var surfaces := ModelCatalog.surfaces_from_node(node, false)
	node.free()
	var batch := MeshBatcher.new()
	batch.add_surfaces(surfaces, Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO))
	var arrays := batch.build_mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normal: Vector3 = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)[0]
	# Godot dibuja como frontales los triángulos en sentido horario vistos desde la normal.
	var winding := (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
	check(winding.dot(normal) < 0.0, "El espejo invierte el recorrido para que la cara siga mirando afuera")


## El GLB del buzón reproduce la pieza procedural: mismos triángulos, colores y orientación.
func test_mailbox_model_matches_procedural() -> void:
	var where := Transform3D(Basis.IDENTITY, Vector3(-2.2, 0.0, -12.1))
	var procedural := _procedural_batch(func(location: LocationBase) -> void: PropsKit.mailbox(location, where.origin))
	var model := MeshBatcher.new()
	check(ModelCatalog.place_in(model, "buzon", where), "El buzón tiene modelo")
	_check_same_triangles(model, procedural, "buzon")


func test_mailbox_model_orientation() -> void:
	var surfaces := ModelCatalog.get_surfaces("buzon")
	check(not surfaces.is_empty(), "El buzón tiene modelo")
	if surfaces.is_empty():
		return
	var slot := Vector3.ZERO
	var count := 0
	var colors: PackedColorArray = surfaces[0]["colors"]
	var vertices: PackedVector3Array = surfaces[0]["vertices"]
	for index in colors.size():
		if _color_distance(colors[index], Palette.IRON) < 0.01:
			slot += vertices[index]
			count += 1
	check(count > 0, "La ranura (hierro) está en el modelo")
	if count > 0:
		slot /= float(count)
		check(slot.z > 0.2 and absf(slot.x) < 0.05, "La ranura mira hacia +Z, como la procedural (%s)" % slot)


## Cada escenario se ve igual con modelos que sin ellos (salvo el redondeo de color de 8 bits) y
## tiene exactamente las mismas colisiones: migrar una pieza sólo cambia de dónde sale su malla.
func test_locations_match_with_and_without_models() -> void:
	for location_id: String in LOCATIONS:
		var with_models := _built_location(location_id, true)
		var procedural := _built_location(location_id, false)
		_check_same_triangles(with_models["batch"], procedural["batch"], location_id)
		check_equal(with_models["colliders"], procedural["colliders"], "%s: mismas colisiones con y sin modelos" % location_id)


func test_mailbox_falls_back_when_model_is_missing() -> void:
	var expected := _procedural_batch(func(location: LocationBase) -> void: PropsKit.mailbox(location, Vector3(1.0, 0.0, 2.0)))
	ModelCatalog.paths["buzon"] = "res://assets/modelos/atrezo/no_existe.glb"
	ModelCatalog.clear()
	var location := LocationBase.new()
	location._body = StaticBody3D.new()
	PropsKit.mailbox(location, Vector3(1.0, 0.0, 2.0))
	_check_same_triangles(location.batch, expected, "buzón sin GLB")
	check_equal(location._body.get_child_count(), 1, "Sin GLB, el buzón conserva su colisión")
	location._body.free()
	location.free()


## La plaza con el buzón migrado sigue siendo tres mallas y una sola colisión estática.
func test_plaza_keeps_its_batches() -> void:
	check(ModelCatalog.has_model("buzon"), "El buzón usa su modelo")
	var plaza: LocationBase = (load("res://scenes/world/locations/plaza.tscn") as PackedScene).instantiate()
	add_child(plaza)
	var meshes := 0
	var bodies: Array[String] = []
	for node in plaza.find_children("*", "", true, false):
		if node is Npc or _has_ancestor_of(node, plaza):
			continue
		if node is MeshInstance3D and node.get_parent() == plaza:
			meshes += 1
		if node is StaticBody3D:
			bodies.append(String(node.name))
	check(meshes <= 3, "La plaza se dibuja con un máximo de 3 mallas, tiene %d" % meshes)
	check_equal(bodies, ["Colisiones"], "Las únicas colisiones estáticas son las de «Colisiones»")
	plaza.queue_free()


## Construye un escenario sin añadirlo al árbol (sin NPC ni navegación) y devuelve su lote y la
## lista de colisiones (centro, tamaño y giro).
static func _built_location(location_id: String, use_models: bool) -> Dictionary:
	var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
	location._body = StaticBody3D.new()
	var was_enabled := ModelCatalog.enabled
	ModelCatalog.enabled = use_models
	# Los modelos retocados u optimizados no son copia exacta: tienen su propia prueba.
	for id: String in ModelCatalog.MODELS:
		if not (ModelCatalog.MODELS[id]["fiel"] is bool and ModelCatalog.MODELS[id]["fiel"]):
			ModelCatalog.excluded[id] = true
	location.build()
	ModelCatalog.excluded = {}
	ModelCatalog.enabled = was_enabled
	var colliders: Array[String] = []
	for child in location._body.get_children():
		var shape := child as CollisionShape3D
		colliders.append("%s %s %s" % [shape.transform.origin, (shape.shape as BoxShape3D).size, shape.transform.basis.get_euler()])
	var batch := location.batch
	location._body.free()
	location.free()
	return {"batch": batch, "colliders": colliders}


## Nodos que pertenecen a un NPC o al detective (tienen su propio modelo).
static func _has_ancestor_of(node: Node, stop: Node) -> bool:
	var current := node.get_parent()
	while current != null and current != stop:
		if current is Npc or current is PlayerController:
			return true
		current = current.get_parent()
	return false


## Cada modelo registrado tiene su GLB, todas las variantes que piden los escenarios y su
## referencia con usos (es decir, un código procedural de respaldo).
func test_registered_models_are_complete() -> void:
	for id: String in ModelCatalog.MODELS:
		var info: Dictionary = ModelCatalog.MODELS[id]
		for key: String in ["categoria", "objeto", "fiel"]:
			check(info.has(key), "%s: falta «%s» en MODELS" % [id, key])
		check(ResourceLoader.exists(ModelCatalog.path_for(id)), "%s: falta %s" % [id, ModelCatalog.path_for(id)])
		var reference := _reference(id)
		check(not reference.is_empty(), "%s: falta su referencia en blender/referencias" % id)
		var objects := ModelCatalog.get_objects(id)
		var variants: Dictionary = reference.get("variantes", {})
		for variant: String in variants:
			var entry: Dictionary = variants[variant]
			check(objects.has(entry["objeto"]), "%s: el GLB no trae el objeto %s" % [id, entry["objeto"]])
			check(not (entry.get("usos", []) as Array).is_empty(), "%s/%s: sin usos ni código de respaldo" % [id, variant])


func test_variants_and_tint() -> void:
	var root := Node3D.new()
	for object_name: String in ["Caja_70", "Caja_90"]:
		var holder := MeshInstance3D.new()
		holder.name = object_name
		holder.position = Vector3(5.0, 0.0, 0.0)
		holder.mesh = _mesh_with_material("vs_tinte", Color(0.5, 0.5, 0.5))
		root.add_child(holder)
	var objects := ModelCatalog.objects_from_node(root)
	root.free()
	check_equal(objects.keys().size(), 2, "Un objeto por variante")
	var surfaces: Array = objects.get("Caja_90", [])
	check(not surfaces.is_empty() and surfaces[0]["tinted"], "El material vs_tinte marca la superficie como teñida")
	var batch := MeshBatcher.new()
	batch.color_jitter = 0.0
	batch.add_surfaces(surfaces, Transform3D.IDENTITY, Color(0.8, 0.4, 0.2))
	var arrays := batch.build_mesh().surface_get_arrays(0)
	var first: Vector3 = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[0]
	check(absf(first.x) < 0.001, "La posición del objeto en el .blend no se aplica: su origen es la referencia (%s)" % first)
	var color: Color = (arrays[Mesh.ARRAY_COLOR] as PackedColorArray)[0]
	check(_color_distance(color, Color(0.4, 0.2, 0.1)) <= 1.0 / 255.0, "Color = factor × tinte (%s)" % color)


func test_invalid_model_falls_back() -> void:
	ModelCatalog.paths["buzon"] = "res://icon.svg"
	ModelCatalog.clear()
	var batch := MeshBatcher.new()
	check(not ModelCatalog.place_in(batch, "buzon", Transform3D.IDENTITY), "Un archivo que no es un modelo no se usa")
	var location := LocationBase.new()
	location._body = StaticBody3D.new()
	PropsKit.mailbox(location, Vector3.ZERO)
	check(not location.batch.is_empty(), "Con un modelo inválido la pieza se dibuja con su código")
	location._body.free()
	location.free()


## La captura distingue las caras teñidas y rechaza piezas que registran colisiones dentro de draw.
func test_capture_checks_procedural_parts() -> void:
	ModelCatalog.captures.clear()
	ModelCatalog.capturing = true
	var location := LocationBase.new()
	location._body = StaticBody3D.new()
	ModelCatalog.draw(location, "prueba", Transform3D(Basis.IDENTITY, Vector3(3.0, 0.0, 0.0)), func(tint: Color) -> void:
		location.batch.box(Vector3(3.0, 0.5, 0.0), Vector3.ONE, tint.darkened(0.3))
		location.batch.box(Vector3(3.0, 1.5, 0.0), Vector3.ONE, Palette.IRON)
	, "", Palette.WINE)
	ModelCatalog.draw(location, "mala", Transform3D.IDENTITY, func(_tint: Color) -> void:
		location.collider(Vector3.ZERO, Vector3.ONE)
	)
	ModelCatalog.capturing = false
	check_equal(ModelCatalog.captures.size(), 2, "Una captura por pieza")
	var good: Dictionary = ModelCatalog.captures[0]
	check((good["errores"] as Array).is_empty(), "Pieza correcta sin errores: %s" % str(good["errores"]))
	var tinted := 0
	for face: Dictionary in good["faces"]:
		if face["tinted"]:
			tinted += 1
			check(_color_distance(face["color"], Color(0.7, 0.7, 0.7)) < 0.001, "El factor de una cara teñida es su color con tinte blanco")
		var center := Vector3.ZERO
		for point: Vector3 in face["points"]:
			center += point
		check(absf(center.x / float((face["points"] as PackedVector3Array).size())) < 0.51, "Caras en el espacio del modelo")
	check_equal(tinted, 6, "Las seis caras de la caja teñida")
	check(not (ModelCatalog.captures[1]["errores"] as Array).is_empty(), "Registrar una colisión dentro de draw es un error")
	ModelCatalog.captures.clear()
	location._body.free()
	location.free()


static func _reference(id: String) -> Dictionary:
	var path := ProjectSettings.globalize_path("res://").path_join("../blender/referencias/%s.json" % id).simplify_path()
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func _mesh_with_material(material_name: String, color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([color, color, color])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	mesh.surface_set_material(0, material)
	return mesh


## Construye una pieza con su código procedural en un escenario sin árbol.
static func _procedural_batch(build: Callable) -> MeshBatcher:
	var location := LocationBase.new()
	location._body = StaticBody3D.new()
	var was_enabled := ModelCatalog.enabled
	ModelCatalog.enabled = false
	build.call(location)
	ModelCatalog.enabled = was_enabled
	var batch := location.batch
	location._body.free()
	location.free()
	return batch


## Compara dos lotes polígono a polígono, sin importar el orden ni cómo se partió cada polígono
## en triángulos (Blender elige otras diagonales en los octógonos): mismos vértices (1 mm), misma
## área, mismo color (1/255, el redondeo de 8 bits) y cara frontal hacia fuera.
func _check_same_triangles(actual: MeshBatcher, expected: MeshBatcher, label: String) -> void:
	for layer: MeshBatcher.Layer in [MeshBatcher.Layer.OPAQUE, MeshBatcher.Layer.GLOW, MeshBatcher.Layer.GROUND]:
		var a := _polygons(actual, layer)
		var b := _polygons(expected, layer)
		check_equal(a.size(), b.size(), "%s: polígonos de la capa %d" % [label, layer])
		var worst := 0.0
		var missing := 0
		for key: String in b:
			if not a.has(key):
				missing += 1
				continue
			worst = maxf(worst, _color_distance(a[key]["color"], b[key]["color"]))
			check(absf(a[key]["area"] - b[key]["area"]) < 0.0001, "%s: área distinta en %s" % [label, key])
			check(a[key]["front"] and b[key]["front"], "%s: cara frontal hacia fuera en %s" % [label, key])
		check_equal(missing, 0, "%s: polígonos de la capa %d que no coinciden" % [label, layer])
		check(worst <= 1.0 / 255.0 + 0.0001, "%s: diferencia de color %.4f en la capa %d" % [label, worst, layer])


static func _polygons(batch: MeshBatcher, layer: MeshBatcher.Layer) -> Dictionary:
	var found := {}
	var mesh := batch.build_mesh(layer)
	if mesh == null:
		return found
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var centers := ModelCatalog.polygon_centers(vertices, normals, colors)
	var groups := {}
	for start in range(0, vertices.size(), 3):
		var group := _point_key(centers[start])
		if not groups.has(group):
			groups[group] = {"corners": {}, "area": 0.0, "color": colors[start], "front": true}
		var entry: Dictionary = groups[group]
		var winding := (vertices[start + 1] - vertices[start]).cross(vertices[start + 2] - vertices[start])
		entry["area"] = float(entry["area"]) + winding.length() * 0.5
		entry["front"] = entry["front"] and winding.dot(normals[start]) < 0.0
		for corner in 3:
			(entry["corners"] as Dictionary)[_point_key(vertices[start + corner])] = true
	for group: String in groups:
		var entry: Dictionary = groups[group]
		var corners: Array = (entry["corners"] as Dictionary).keys()
		corners.sort()
		found["|".join(corners)] = entry
	return found


static func _point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0)]


static func _color_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


## Monta un nodo con la malla de unas caras grabadas, como haría un GLB importado.
static func _node_from_recorded(recorded: Array[Dictionary]) -> Node3D:
	var replay := MeshBatcher.new()
	replay.color_jitter = 0.0
	for entry in recorded:
		replay.face(entry["points"], entry["color"], Vector3.ZERO, entry["layer"])
	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	var mesh := replay.build_mesh()
	var material := StandardMaterial3D.new()
	material.resource_name = "vs_opaco"
	mesh.surface_set_material(0, material)
	instance.mesh = mesh
	root.add_child(instance)
	return root


static func _mesh_with_layers(color: Color = Palette.WINE) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material_name: String in ["vs_opaco", "vs_brillo"]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray([color, color, color, color])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.resource_name = material_name
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh
