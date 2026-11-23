extends Node
## Huella de la geometría de los escenarios: cada polígono (vértices a 1 mm, color y capa) y cada
## colisión, ordenados. Sirve para demostrar que una refactorización de un kit no cambia lo que se
## dibuja: se toma la huella antes y después y se comparan los archivos.
##
## Uso (desde new-game-project/):
##   godot --headless --path . res://tools/modelos/huella_escenarios.tscn -- --salida=C:/ruta/huella.txt [--modelos]
## Sin --modelos todo se dibuja con el código procedural (`ModelCatalog.enabled = false`).

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion", "test_ground"]


func _ready() -> void:
	var output := ""
	var use_models := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--salida="):
			output = argument.trim_prefix("--salida=")
		elif argument == "--modelos":
			use_models = true
	if output.is_empty():
		printerr("FALLO falta --salida=ruta")
		get_tree().quit(1)
		return
	ModelCatalog.enabled = use_models
	var lines: Array[String] = []
	var counts := {}
	for location_id: String in LOCATIONS:
		var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
		location._body = StaticBody3D.new()
		location.build()
		var before := lines.size()
		_polygons(location_id, location.batch, lines)
		for child in location._body.get_children():
			var shape := child as CollisionShape3D
			lines.append("%s|colision|%s|%s|%s" % [location_id, _key(shape.transform.origin), _key((shape.shape as BoxShape3D).size), _key(shape.transform.basis.get_euler())])
		counts[location_id] = lines.size() - before
		location._body.free()
		location.free()
	lines.sort()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("Huella: %d líneas %s -> %s" % [lines.size(), counts, output])
	get_tree().quit(0)


static func _polygons(location_id: String, batch: MeshBatcher, lines: Array[String]) -> void:
	for layer: MeshBatcher.Layer in [MeshBatcher.Layer.OPAQUE, MeshBatcher.Layer.GLOW, MeshBatcher.Layer.GROUND]:
		if not batch._buffers.has(layer):
			continue
		var buffers: MeshBatcher.Buffers = batch._buffers[layer]
		var centers := ModelCatalog.polygon_centers(buffers.vertices, buffers.normals, buffers.colors)
		var groups := {}
		for start in range(0, buffers.vertices.size(), 3):
			var group := _key(centers[start]) + "|" + buffers.colors[start].to_html(false)
			if not groups.has(group):
				groups[group] = {}
			for corner in 3:
				(groups[group] as Dictionary)[_key(buffers.vertices[start + corner])] = true
		for group: String in groups:
			var corners: Array = (groups[group] as Dictionary).keys()
			corners.sort()
			lines.append("%s|%d|%s|%s" % [location_id, layer, group.split("|")[1], ";".join(corners)])


static func _key(value: Vector3) -> String:
	return "%d,%d,%d" % [roundi(value.x * 1000.0), roundi(value.y * 1000.0), roundi(value.z * 1000.0)]
