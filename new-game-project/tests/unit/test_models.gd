extends TestCase
## Modelos de Blender fusionados en el lote (`ModelCatalog`, `MeshBatcher.add_surfaces`).

const QUAD := [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]


func after_each() -> void:
	ModelCatalog.enabled = true
	ModelCatalog.paths = ModelCatalog.MODELS.duplicate()
	ModelCatalog.clear()


## Un polígono importado como dos triángulos recibe el mismo tono que la cara procedural.
func test_imported_polygon_matches_procedural_face() -> void:
	var procedural := MeshBatcher.new()
	procedural.face(PackedVector3Array(QUAD), Palette.WINE, Vector3.UP)
	var recorder := MeshBatcher.new()
	recorder.recording = true
	recorder.face(PackedVector3Array(QUAD), Palette.WINE, Vector3.UP)
	var surfaces := ModelCatalog.surfaces_from_node(_node_from_recorded(recorder.recorded), false)
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
	var surfaces := ModelCatalog.surfaces_from_node(_node_from_recorded(recorder.recorded), false)
	var batch := MeshBatcher.new()
	batch.add_surfaces(surfaces, Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO))
	var arrays := batch.build_mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normal: Vector3 = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)[0]
	# Godot dibuja como frontales los triángulos en sentido horario vistos desde la normal.
	var winding := (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
	check(winding.dot(normal) < 0.0, "El espejo invierte el recorrido para que la cara siga mirando afuera")


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
