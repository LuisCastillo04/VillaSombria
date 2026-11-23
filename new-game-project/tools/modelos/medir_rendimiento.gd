extends Node
## Mide, para cada escenario y cada personaje, triángulos por capa y tiempo de construcción con los
## modelos de Blender y con el código procedural. Escribe una tabla Markdown.
##
## Uso (desde new-game-project/):
##   godot --headless --path . res://tools/modelos/medir_rendimiento.tscn -- [--repeticiones=5] [--salida=ruta.md]
## «En frío» = la primera construcción tras vaciar la caché de modelos (incluye leer los GLB);
## «en caliente» = la media de las siguientes. Sin ventana: no mide el dibujado (para eso, las
## capturas con --stats de tests/visual/captura.tscn).

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion"]


func _ready() -> void:
	var repetitions := 5
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--repeticiones="):
			repetitions = maxi(2, int(argument.trim_prefix("--repeticiones=")))
		elif argument.begins_with("--salida="):
			output = argument.trim_prefix("--salida=")
	var lines: Array[String] = [
		"| Escenario | Modo | Triángulos opacos | Brillo | Suelo | Construcción en frío (ms) | En caliente (ms) |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	]
	for location_id: String in LOCATIONS:
		for use_models: bool in [false, true]:
			lines.append(_measure_location(location_id, use_models, repetitions))
	lines.append("")
	lines.append("| Personajes (los diez) | Modo | Triángulos | Construcción en frío (ms) | En caliente (ms) |")
	lines.append("| --- | --- | --- | --- | --- |")
	for use_models: bool in [false, true]:
		lines.append(_measure_characters(use_models, repetitions))
	var text := "\n".join(lines) + "\n"
	print(text)
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	get_tree().quit(0)


func _measure_location(location_id: String, use_models: bool, repetitions: int) -> String:
	ModelCatalog.enabled = use_models
	ModelCatalog.clear()
	var times: Array[float] = []
	var counts := [0, 0, 0]
	for run in repetitions:
		var scene := load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene
		var start := Time.get_ticks_usec()
		var location: LocationBase = scene.instantiate()
		location._body = StaticBody3D.new()
		location.build()
		var meshes := []
		for layer: MeshBatcher.Layer in [MeshBatcher.Layer.OPAQUE, MeshBatcher.Layer.GLOW, MeshBatcher.Layer.GROUND]:
			meshes.append(location.batch.build_mesh(layer))
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
		for index in 3:
			var mesh: ArrayMesh = meshes[index]
			counts[index] = 0 if mesh == null else (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		location._body.free()
		location.free()
	ModelCatalog.enabled = true
	return "| %s | %s | %d | %d | %d | %.1f | %.1f |" % [
		location_id, "modelos" if use_models else "procedural", counts[0], counts[1], counts[2], times[0], _mean(times.slice(1))]


func _measure_characters(use_models: bool, repetitions: int) -> String:
	ModelCatalog.enabled = use_models
	ModelCatalog.clear()
	var tool: Node = (load("res://tools/modelos/exportar_referencias.gd") as GDScript).new()
	var characters: Array = tool.characters()
	tool.free()
	var times: Array[float] = []
	var triangles := 0
	for run in repetitions:
		var start := Time.get_ticks_usec()
		var total := 0
		for character: Array in characters:
			var model := CharacterModel.new()
			model.build(character[1], character[0])
			for node in model.find_children("*", "MeshInstance3D", true, false):
				var mesh := (node as MeshInstance3D).mesh
				total += (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			model.free()
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
		triangles = total
	ModelCatalog.enabled = true
	return "| %d personajes | %s | %d | %.1f | %.1f |" % [characters.size(), "modelos" if use_models else "procedural", triangles, times[0], _mean(times.slice(1))]


static func _mean(values: Array) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(maxi(1, values.size()))
