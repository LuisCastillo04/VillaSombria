extends Node
## Lista las caras visibles que comparten plano y superficie (z-fighting) en cada escenario, con
## los modelos de Blender fusionados como en el juego.
##
## Uso (desde new-game-project/):
##   godot --headless --path . res://tools/modelos/detectar_coplanares.tscn -- [--escenario=plaza] [--ocultos] [--modelos=procedural]
## Por defecto sólo lista los que la cámara llega a ver; con --ocultos, también los tapados.
## Sale con código 1 si encuentra alguno visible.

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion"]
const CoplanarFaces := preload("res://tests/unit/coplanar_faces.gd")
const PROBE_LAYER := 1 << 19


func _ready() -> void:
	var wanted: Array = LOCATIONS
	var hidden := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--escenario="):
			wanted = Array(argument.trim_prefix("--escenario=").split(",", false))
		elif argument == "--ocultos":
			hidden = true
	var total := 0
	for location_id: String in wanted:
		var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
		location._body = StaticBody3D.new()
		location.build()
		var overlaps := CoplanarFaces.find(location.batch)
		var probe := CoplanarFaces.add_probe(self, location.batch, PROBE_LAYER)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var shown := CoplanarFaces.visible(overlaps, get_viewport().world_3d.direct_space_state, PROBE_LAYER)
		probe.free()
		var zones := CoplanarFaces.summarize(overlaps if hidden else shown)
		print("%s: %d zonas visibles (%d solapes, %d visibles)" % [location_id, zones.size(), overlaps.size(), shown.size()])
		for zone in zones:
			print("  ", CoplanarFaces.describe(zone))
		total += zones.size()
		location._body.free()
		location.free()
	get_tree().quit(1 if total > 0 else 0)
