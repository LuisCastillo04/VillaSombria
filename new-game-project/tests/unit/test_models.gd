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


## Cada pieza dibujada con su modelo, en su sitio real y con su tinte, coincide con su código
## procedural (modelos «fieles»). Señala el modelo y la variante que fallan.
func test_each_model_matches_its_procedural_piece() -> void:
	_capture_everything()
	var checked := {}
	for capture: Dictionary in ModelCatalog.captures:
		var id: String = capture["id"]
		var fidelity: Variant = ModelCatalog.MODELS.get(id, {}).get("fiel", false)
		if not (fidelity is bool and fidelity):
			continue
		var label := "%s/%s en %s" % [id, capture["variant"], capture["where"]]
		var placement: Transform3D = capture["placement"]
		var tint: Color = capture.get("tint", Color.WHITE)
		# La pieza procedural, rehecha con las caras que grabó la captura (mismo resultado que su código).
		var expected := MeshBatcher.new()
		expected.xform = placement
		for face: Dictionary in capture["faces"]:
			var color: Color = face["color"]
			if face["tinted"]:
				color = Color(color.r * tint.r, color.g * tint.g, color.b * tint.b, color.a)
			expected.face(face["points"], color, Vector3.ZERO, face["layer"])
		var actual := MeshBatcher.new()
		check(ModelCatalog.place_in(actual, id, placement, capture["variant"], tint), "%s: sin modelo" % label)
		_check_same_triangles(actual, expected, label)
		checked[label] = true
	ModelCatalog.captures.clear()
	check(checked.size() > 0, "Hay piezas migradas que comprobar")


## Los modelos «optimizados» sólo pierden caras que la cámara (inclinación fija de -36°) no ve:
## todo lo que dibujan está en la pieza procedural con el mismo color, y lo que falta mira hacia
## abajo o es una trasera interior (no la trasera exterior del mueble).
func test_optimized_models_only_drop_hidden_faces() -> void:
	_capture_everything()
	var checked := 0
	for capture: Dictionary in ModelCatalog.captures:
		var id: String = capture["id"]
		var fidelity: Variant = ModelCatalog.MODELS.get(id, {}).get("fiel", true)
		if not (fidelity is String and fidelity == "optimizado"):
			continue
		var label := "%s/%s en %s" % [id, capture["variant"], capture["where"]]
		var placement: Transform3D = capture["placement"]
		var expected := MeshBatcher.new()
		expected.xform = placement
		for face: Dictionary in capture["faces"]:
			expected.face(face["points"], face["color"], Vector3.ZERO, face["layer"])
		var actual := MeshBatcher.new()
		check(ModelCatalog.place_in(actual, id, placement, capture["variant"]), "%s: sin modelo" % label)
		var model_triangles := _triangle_list(actual, MeshBatcher.Layer.OPAQUE)
		var procedural_triangles := _triangle_list(expected, MeshBatcher.Layer.OPAQUE)
		var procedural_grid := _grid(procedural_triangles)
		var model_grid := _grid(model_triangles)
		var worst := 0.0
		for triangle in model_triangles:
			var cover: Variant = _covering(procedural_grid, triangle)
			check(cover != null, "%s: el modelo dibuja algo que no está en la pieza procedural" % label)
			if cover != null:
				worst = maxf(worst, _color_distance((cover as Dictionary)["color"], triangle["color"]))
		check(worst <= 1.0 / 255.0 + 0.0001, "%s: diferencia de color %.4f" % [label, worst])
		var inverse := placement.affine_inverse()
		# La trasera del mueble: las caras que miran atrás más alejadas, y el rectángulo que tapan.
		var rear := INF
		for triangle in procedural_triangles:
			for point: Vector3 in triangle["points"]:
				rear = minf(rear, (inverse * point).z)
		var cover := AABB()
		var first := true
		for triangle in procedural_triangles:
			var normal: Vector3 = (inverse.basis * (triangle["normal"] as Vector3)).normalized()
			if normal.z < -0.99 and absf((inverse * (triangle["center"] as Vector3)).z - rear) < 0.001:
				for point: Vector3 in triangle["points"]:
					var local := inverse * point
					cover = AABB(local, Vector3.ZERO) if first else cover.expand(local)
					first = false
		var dropped := 0
		for triangle in procedural_triangles:
			if _covering(model_grid, triangle) != null:
				continue
			dropped += 1
			var normal: Vector3 = (inverse.basis * (triangle["normal"] as Vector3)).normalized()
			var behind := normal.z < -0.99
			for point: Vector3 in triangle["points"]:
				var local := inverse * point
				behind = behind and local.z > rear + 0.001 					and local.x >= cover.position.x - 0.001 and local.x <= cover.end.x + 0.001 					and local.y >= cover.position.y - 0.001 and local.y <= cover.end.y + 0.001
			check(normal.y < -0.99 or behind, "%s: falta una cara visible (normal %s)" % [label, normal])
		check(dropped > 0, "%s: un modelo «optimizado» debería tener menos caras" % label)
		checked += 1
	ModelCatalog.captures.clear()
	check(checked > 0, "Hay modelos optimizados que comprobar")


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


## Construye los escenarios y los personajes en modo captura: deja en `ModelCatalog.captures`
## cada pieza migrada tal como la dibuja el juego (como hace `exportar_referencias.tscn`).
func _capture_everything() -> void:
	ModelCatalog.captures.clear()
	ModelCatalog.capturing = true
	for location_id: String in LOCATIONS:
		var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
		location._body = StaticBody3D.new()
		location.build()
		location._body.free()
		location.free()
	var tool: Node = (load("res://tools/modelos/exportar_referencias.gd") as GDScript).new()
	for character: Array in tool.characters():
		var model := CharacterModel.new()
		model.build(character[1], character[0])
		model.free()
	tool.free()
	ModelCatalog.capturing = false


## Una medida que el GLB no trae (un mueble nuevo con otras medidas) se dibuja con el código y el
## resto del modelo sigue funcionando.
func test_missing_variant_falls_back() -> void:
	var batch := MeshBatcher.new()
	check(not ModelCatalog.place_in(batch, "mesa", Transform3D.IDENTITY, "999x99x99"), "Una medida que el GLB no trae no se dibuja con el modelo")
	check(ModelCatalog.place_in(batch, "mesa", Transform3D.IDENTITY, "120x76x80"), "Las demás medidas siguen usando el modelo")
	var location := LocationBase.new()
	location._body = StaticBody3D.new()
	InteriorKit.table(location, Vector3.ZERO, Vector3(9.99, 0.99, 0.99))
	check(not location.batch.is_empty(), "La mesa de medida nueva se dibuja con su código")
	check_equal(location._body.get_child_count(), 1, "Y conserva su colisión")
	location._body.free()
	location.free()


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


## Compara dos lotes por lo que cubren, sin importar el orden ni cómo se partió cada polígono en
## triángulos (Blender elige otras diagonales): el centro de cada triángulo de uno cae en un
## triángulo del otro con el mismo plano, el mismo color (1/255, el redondeo de 8 bits) y la cara
## frontal hacia fuera, en los dos sentidos, y el área total de cada capa es la misma.
func _check_same_triangles(actual: MeshBatcher, expected: MeshBatcher, label: String) -> void:
	for layer: MeshBatcher.Layer in [MeshBatcher.Layer.OPAQUE, MeshBatcher.Layer.GLOW, MeshBatcher.Layer.GROUND]:
		var a := _triangle_list(actual, layer)
		var b := _triangle_list(expected, layer)
		var area_a := 0.0
		var area_b := 0.0
		for triangle: Dictionary in a:
			area_a += triangle["area"]
			check(triangle["front"], "%s: cara frontal hacia dentro en %s" % [label, _point_key(triangle["center"])])
		for triangle: Dictionary in b:
			area_b += triangle["area"]
		check(absf(area_a - area_b) <= 0.0005 * maxf(1.0, area_b), "%s: área de la capa %d %.4f m² y la procedural %.4f m²" % [label, layer, area_a, area_b])
		var worst := 0.0
		for pair: Array in [[b, _grid(a), "que no tiene el modelo"], [a, _grid(b), "que no tiene la pieza procedural"]]:
			var missing := 0
			var example := ""
			for triangle: Dictionary in pair[0]:
				var match_found: Variant = _covering(pair[1], triangle)
				if match_found == null:
					missing += 1
					example = _point_key(triangle["center"])
				else:
					worst = maxf(worst, _color_distance((match_found as Dictionary)["color"], triangle["color"]))
			check(missing == 0, "%s: %d triángulos de la capa %d %s (p. ej. en %s)" % [label, missing, layer, pair[2], example])
		check(worst <= 1.0 / 255.0 + 0.0001, "%s: diferencia de color %.4f en la capa %d" % [label, worst, layer])


const GRID_CELL := 0.5


static func _triangle_list(batch: MeshBatcher, layer: MeshBatcher.Layer) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var mesh := batch.build_mesh(layer)
	if mesh == null:
		return found
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for start in range(0, vertices.size(), 3):
		var p0 := vertices[start]
		var p1 := vertices[start + 1]
		var p2 := vertices[start + 2]
		var cross := (p1 - p0).cross(p2 - p0)
		if cross.length() < 0.0000001:
			continue
		found.append({
			"points": [p0, p1, p2],
			# Punto interior que no cae en la diagonal de ningún rectángulo (el centroide sí cae
			# en la otra diagonal cuando el otro lote partió el rectángulo al revés).
			"center": p0 * 0.6 + p1 * 0.25 + p2 * 0.15,
			"normal": -cross.normalized(),
			"color": colors[start],
			"area": cross.length() * 0.5,
			"front": cross.dot(normals[start]) < 0.0,
		})
	return found


## Rejilla de 0,5 m con los triángulos que tocan cada celda, para buscar deprisa.
static func _grid(triangles: Array[Dictionary]) -> Dictionary:
	var grid := {}
	for triangle in triangles:
		var points: Array = triangle["points"]
		# Margen de 5 mm: una cara justo en el borde de una celda se registra en las dos.
		var low: Vector3 = (points[0] as Vector3).min(points[1]).min(points[2]) - Vector3.ONE * 0.005
		var high: Vector3 = (points[0] as Vector3).max(points[1]).max(points[2]) + Vector3.ONE * 0.005
		for x in range(floori(low.x / GRID_CELL), floori(high.x / GRID_CELL) + 1):
			for y in range(floori(low.y / GRID_CELL), floori(high.y / GRID_CELL) + 1):
				for z in range(floori(low.z / GRID_CELL), floori(high.z / GRID_CELL) + 1):
					var cell := Vector3i(x, y, z)
					if not grid.has(cell):
						grid[cell] = []
					(grid[cell] as Array).append(triangle)
	return grid


## Triángulo del otro lote en el mismo plano que contiene el punto de muestra de `triangle`, o
## null. Si hay varios (caras coplanarias superpuestas, que ya parpadean en la pieza original), el
## de color más parecido.
static func _covering(grid: Dictionary, triangle: Dictionary) -> Variant:
	var center: Vector3 = triangle["center"]
	var cell := Vector3i(floori(center.x / GRID_CELL), floori(center.y / GRID_CELL), floori(center.z / GRID_CELL))
	var best: Variant = null
	var best_distance := INF
	for candidate: Dictionary in grid.get(cell, []):
		var normal: Vector3 = candidate["normal"]
		if normal.dot(triangle["normal"]) < 0.999:
			continue
		var points: Array = candidate["points"]
		if absf(normal.dot(center - (points[0] as Vector3))) > 0.001:
			continue
		if _inside(center, points[0], points[1], points[2], normal):
			var distance := _color_distance(candidate["color"], triangle["color"])
			if distance < best_distance:
				best = candidate
				best_distance = distance
	return best


## Coordenadas baricéntricas: no dependen del tamaño del triángulo, así que la tolerancia vale
## igual para una baldosa que para una pared de 28 m.
static func _inside(point: Vector3, a: Vector3, b: Vector3, c: Vector3, _normal: Vector3) -> bool:
	var v0 := b - a
	var v1 := c - a
	var v2 := point - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denominator := d00 * d11 - d01 * d01
	if absf(denominator) < 1e-12:
		return false
	var v := (d11 * d20 - d01 * d21) / denominator
	var w := (d00 * d21 - d01 * d20) / denominator
	var tolerance := -0.0001
	return v >= tolerance and w >= tolerance and 1.0 - v - w >= tolerance


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
