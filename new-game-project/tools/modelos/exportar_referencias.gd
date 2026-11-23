extends Node
## Vía A de la migración a Blender: construye los escenarios reales en modo captura
## (`ModelCatalog.capturing`) y guarda cada pieza registrada tal como la dibuja el juego, en el
## espacio del modelo: `blender/referencias/<id>.json` con sus variantes (polígonos con su color
## sin variación de tono, capa y si toman el tinte de la pieza), colisiones cercanas y usos.
## `blender/scripts/importar_referencia.py` lo convierte en el `.blend` editable.
##
## Uso (desde new-game-project/):
##   godot --headless --path . res://tools/modelos/exportar_referencias.tscn -- [--pieza=buzon,silla]
## Sin --pieza exporta todos los modelos registrados en `ModelCatalog.MODELS`. Falla (código 1) si
## una pieza no aparece en ningún escenario, si dos usos de la misma variante no coinciden o si
## su parte procedural registra colisiones o nodos.

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion", "test_ground"]
const OUTPUT_DIR := "../blender/referencias"
const LAYER_NAMES := {
	MeshBatcher.Layer.OPAQUE: "opaco",
	MeshBatcher.Layer.GLOW: "brillo",
	MeshBatcher.Layer.GROUND: "suelo",
}
## Distancia máxima (m) entre una colisión registrada tras la pieza y la caja de la pieza para
## mostrarla como suya en la colección Referencia de Blender.
const COLLIDER_MARGIN := 0.3


func _ready() -> void:
	var wanted: Array = ModelCatalog.MODELS.keys()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pieza="):
			wanted = Array(argument.trim_prefix("--pieza=").split(",", false))
	var references := collect()
	var failures := 0
	for id: String in wanted:
		if not ModelCatalog.MODELS.has(id):
			printerr("FALLO %s: no está en ModelCatalog.MODELS" % id)
			failures += 1
			continue
		if not references.has(id):
			printerr("FALLO %s: ningún escenario lo dibuja con ModelCatalog.draw" % id)
			failures += 1
			continue
		var reference: Dictionary = references[id]
		for problem: String in reference["errores"]:
			printerr("FALLO %s: %s" % [id, problem])
			failures += 1
		print("Exportada %s (%d variantes) -> %s" % [id, (reference["variantes"] as Dictionary).size(), write(reference)])
	get_tree().quit(1 if failures > 0 else 0)


## Construye todo en modo captura y devuelve id → referencia.
static func collect() -> Dictionary:
	ModelCatalog.captures.clear()
	ModelCatalog.capturing = true
	var colliders_by_capture := {}
	for location_id: String in LOCATIONS:
		var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
		location._body = StaticBody3D.new()
		var first := ModelCatalog.captures.size()
		location.build()
		_assign_colliders(location, first, colliders_by_capture)
		location._body.free()
		location.free()
	ModelCatalog.capturing = false
	var references := {}
	for index in ModelCatalog.captures.size():
		var capture: Dictionary = ModelCatalog.captures[index]
		var id: String = capture["id"]
		if not references.has(id):
			var info: Dictionary = ModelCatalog.MODELS.get(id, {})
			references[id] = {
				"id": id,
				"categoria": info.get("categoria", "sin_categoria"),
				"objeto": info.get("objeto", id),
				"fiel": info.get("fiel", true),
				"ejes": "Godot: Y arriba, frente hacia +Z (personajes: -Z), metros",
				"godot": Engine.get_version_info()["string"],
				"variantes": {},
				"errores": [],
			}
		var reference: Dictionary = references[id]
		for problem: String in capture["errores"]:
			if not (reference["errores"] as Array).has(problem):
				(reference["errores"] as Array).append(problem)
		var variants: Dictionary = reference["variantes"]
		var variant: String = capture["variant"]
		var faces := _faces_json(capture["faces"])
		var use := {"escenario": capture["where"], "posicion": _vector((capture["placement"] as Transform3D).origin)}
		if not variants.has(variant):
			variants[variant] = {
				"objeto": ModelCatalog.object_name_for(id, variant),
				"triangulos": _triangles(capture["faces"]),
				"caja": _box(capture["faces"]),
				"caras": faces,
				"colisiones": colliders_by_capture.get(index, []),
				"usos": [use],
			}
			if capture.has("display"):
				variants[variant]["muestra"] = _vector(capture["display"])
		else:
			var known: Dictionary = variants[variant]
			(known["usos"] as Array).append(use)
			if _signature(known["caras"]) != _signature(faces):
				var problem := "la variante «%s» se dibuja distinta en %s y en %s: falta un parámetro en la clave de variante" % [
					variant, (known["usos"] as Array)[0]["escenario"], capture["where"]]
				if not (reference["errores"] as Array).has(problem):
					(reference["errores"] as Array).append(problem)
	ModelCatalog.captures.clear()
	return references


static func write(reference: Dictionary) -> String:
	var directory := ProjectSettings.globalize_path("res://").path_join(OUTPUT_DIR).simplify_path()
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("%s.json" % reference["id"])
	var copy := reference.duplicate(true)
	copy.erase("errores")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(copy, "\t", false) + "\n")
	file.close()
	return path


## Las colisiones registradas entre una pieza y la siguiente que quedan junto a su caja.
static func _assign_colliders(location: LocationBase, first: int, result: Dictionary) -> void:
	var shapes := location._body.get_children()
	var last := ModelCatalog.captures.size()
	for index in range(first, last):
		var capture: Dictionary = ModelCatalog.captures[index]
		var start: int = capture.get("colisiones_desde", shapes.size())
		var finish: int = shapes.size()
		if index + 1 < last:
			finish = ModelCatalog.captures[index + 1].get("colisiones_desde", shapes.size())
		var inverse := (capture["placement"] as Transform3D).affine_inverse()
		var box := _box_aabb(capture["faces"]).grow(COLLIDER_MARGIN)
		var found: Array = []
		for shape_index in range(start, finish):
			var shape := shapes[shape_index] as CollisionShape3D
			var local := inverse * shape.transform
			if box.has_point(local.origin):
				found.append({
					"centro": _vector(local.origin),
					"tamano": _vector((shape.shape as BoxShape3D).size),
					"giro_y": snappedf(rad_to_deg(local.basis.get_euler().y), 0.001),
				})
		result[index] = found


static func _faces_json(faces: Array) -> Array:
	var listed: Array = []
	for face: Dictionary in faces:
		var points: Array = []
		for point: Vector3 in face["points"]:
			points.append(_vector(point))
		listed.append({
			"capa": "tinte" if face["tinted"] else LAYER_NAMES[face["layer"]],
			"color": (face["color"] as Color).to_html(true),
			"puntos": points,
		})
	return listed


static func _signature(faces: Array) -> String:
	var keys: Array[String] = []
	for face: Dictionary in faces:
		var points: Array[String] = []
		for point: Array in face["puntos"]:
			points.append("%d,%d,%d" % [roundi(point[0] * 1000.0), roundi(point[1] * 1000.0), roundi(point[2] * 1000.0)])
		points.sort()
		keys.append("%s|%s|%s" % [face["capa"], face["color"], ";".join(points)])
	keys.sort()
	return "\n".join(keys)


static func _triangles(faces: Array) -> int:
	var total := 0
	for face: Dictionary in faces:
		total += (face["points"] as PackedVector3Array).size() - 2
	return total


static func _box_aabb(faces: Array) -> AABB:
	var box := AABB()
	var first := true
	for face: Dictionary in faces:
		for point: Vector3 in face["points"]:
			if first:
				box = AABB(point, Vector3.ZERO)
				first = false
			else:
				box = box.expand(point)
	return box


static func _box(faces: Array) -> Dictionary:
	var box := _box_aabb(faces)
	return {"min": _vector(box.position), "max": _vector(box.end)}


static func _vector(value: Vector3) -> Array:
	return [snappedf(value.x, 0.00001), snappedf(value.y, 0.00001), snappedf(value.z, 0.00001)]
