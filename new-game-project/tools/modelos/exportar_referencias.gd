extends Node
## Vía A de la migración a Blender: construye cada pieza procedural aislada, en el origen, y
## guarda sus polígonos (color sin variación de tono y capa), sus colisiones, luces y rótulos en
## `blender/referencias/<id>.json`, fuera del proyecto. `blender/scripts/importar_referencia.py`
## lo convierte en el `.blend` editable.
##
## Uso (desde new-game-project/):
##   godot --headless --path . res://tools/modelos/exportar_referencias.tscn -- [--pieza=buzon,...]
## Sin --pieza exporta todas las de la tabla.

## Id → categoría, objeto de Blender y función de kit que la dibuja.
const PIECES := {
	"buzon": {"categoria": "atrezo", "objeto": "Buzon", "origen": "PropsKit.mailbox"},
}
const OUTPUT_DIR := "../blender/referencias"
const LAYER_NAMES := {
	MeshBatcher.Layer.OPAQUE: "opaco",
	MeshBatcher.Layer.GLOW: "brillo",
	MeshBatcher.Layer.GROUND: "suelo",
}


func _ready() -> void:
	var wanted: Array = PIECES.keys()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pieza="):
			wanted = Array(argument.trim_prefix("--pieza=").split(",", false))
	var failures := 0
	for id: String in wanted:
		if not PIECES.has(id):
			printerr("FALLO pieza desconocida: ", id)
			failures += 1
			continue
		var path := export_piece(id)
		print("Exportada ", id, " -> ", path)
	get_tree().quit(1 if failures > 0 else 0)


## Construye la pieza `id` y devuelve su descripción (lo que se guarda en el JSON).
static func describe(id: String) -> Dictionary:
	var info: Dictionary = PIECES[id]
	var location := LocationBase.new()
	location._body = StaticBody3D.new()
	location.batch.recording = true
	var was_enabled := ModelCatalog.enabled
	ModelCatalog.enabled = false
	build_procedural(id, location)
	ModelCatalog.enabled = was_enabled
	var faces: Array = []
	var triangles := 0
	var low := Vector3.INF
	var high := -Vector3.INF
	for entry: Dictionary in location.batch.recorded:
		var points: PackedVector3Array = entry["points"]
		var listed: Array = []
		for point in points:
			listed.append(_vector(point))
			low = low.min(point)
			high = high.max(point)
		triangles += points.size() - 2
		faces.append({
			"capa": LAYER_NAMES[entry["layer"]],
			"color": (entry["color"] as Color).to_html(true),
			"puntos": listed,
		})
	var colliders: Array = []
	for child in location._body.get_children():
		var shape := child as CollisionShape3D
		var box := shape.shape as BoxShape3D
		colliders.append({
			"centro": _vector(shape.transform.origin),
			"tamano": _vector(box.size),
			"giro_y": snappedf(rad_to_deg(shape.transform.basis.get_euler().y), 0.001),
		})
	var lights: Array = []
	var signs: Array = []
	for child in location.get_children():
		if child is OmniLight3D:
			lights.append({"posicion": _vector((child as OmniLight3D).position)})
		elif child is Label3D:
			signs.append({"texto": (child as Label3D).text, "posicion": _vector((child as Label3D).position)})
	location._body.free()
	location.free()
	return {
		"id": id,
		"categoria": info["categoria"],
		"objeto": info["objeto"],
		"origen": info["origen"],
		"ejes": "Godot: Y arriba, frente hacia +Z, metros",
		"godot": Engine.get_version_info()["string"],
		"triangulos": triangles,
		"caja": {"min": _vector(low), "max": _vector(high)},
		"caras": faces,
		"colisiones": colliders,
		"luces": lights,
		"rotulos": signs,
	}


static func export_piece(id: String) -> String:
	var directory := ProjectSettings.globalize_path("res://").path_join(OUTPUT_DIR).simplify_path()
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("%s.json" % id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(describe(id), "\t", false) + "\n")
	file.close()
	return path


## La parte procedural de cada pieza, en el origen y sin girar.
static func build_procedural(id: String, location: LocationBase) -> void:
	match id:
		"buzon":
			PropsKit.mailbox(location, Vector3.ZERO)


static func _vector(value: Vector3) -> Array:
	return [snappedf(value.x, 0.00001), snappedf(value.y, 0.00001), snappedf(value.z, 0.00001)]
