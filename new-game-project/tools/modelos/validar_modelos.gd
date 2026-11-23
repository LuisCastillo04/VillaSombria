extends Node
## Comprueba los modelos registrados en `ModelCatalog.MODELS` contra su referencia de Blender
## (`blender/referencias/<id>.json`) y su registro de exportación (`blender/registro/<id>.json`).
##
## Uso (desde new-game-project/):
##   godot --headless --path . res://tools/modelos/validar_modelos.tscn -- [--pieza=buzon,silla]
## Escribe «OK», «AVISO» o «ERROR» por modelo y termina con código 1 si hay algún error.

const BLENDER_DIR := "../blender"
const VALID_MATERIALS := ["vs_opaco", "vs_brillo", "vs_suelo", "vs_tinte"]
## Tolerancia de la caja del modelo frente a la de la pieza procedural (05-estandares.md).
const BOX_TOLERANCE := 0.05
const IMPORT_SETTINGS := [
	"meshes/generate_lods=false",
	"meshes/create_shadow_meshes=false",
	"meshes/ensure_tangents=false",
	"meshes/force_disable_compression=true",
]

var _errors := 0
var _warnings := 0


func _ready() -> void:
	var wanted: Array = ModelCatalog.MODELS.keys()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pieza="):
			wanted = Array(argument.trim_prefix("--pieza=").split(",", false))
	for id: String in wanted:
		validate(id)
	_check_orphans()
	print("RESUMEN validación: %d modelos, %d errores, %d avisos" % [wanted.size(), _errors, _warnings])
	get_tree().quit(1 if _errors > 0 else 0)


func validate(id: String) -> void:
	var problems: Array[String] = []
	var notes: Array[String] = []
	if not ModelCatalog.MODELS.has(id):
		_report(id, ["no está en ModelCatalog.MODELS"], [])
		return
	var info: Dictionary = ModelCatalog.MODELS[id]
	for key: String in ["categoria", "objeto", "fiel"]:
		if not info.has(key):
			problems.append("a su entrada de MODELS le falta «%s»" % key)
	var path := ModelCatalog.path_for(id)
	var reference := _read_json(BLENDER_DIR.path_join("referencias/%s.json" % id))
	var record := _read_json(BLENDER_DIR.path_join("registro/%s.json" % id))
	if reference.is_empty():
		problems.append("no hay referencia: exportarla con tools/modelos/exportar_referencias.tscn")
	if not FileAccess.file_exists(path):
		problems.append("falta %s: el juego usa el código procedural" % path)
		_report(id, problems, notes)
		return
	if not FileAccess.file_exists(path + ".import"):
		problems.append("falta %s.import: importar el proyecto en Godot" % path)
	else:
		var import_text := FileAccess.get_file_as_string(path + ".import")
		for setting: String in IMPORT_SETTINGS:
			if not import_text.contains(setting):
				notes.append("%s.import sin «%s» (python blender/scripts/migrar.py lo ajusta)" % [path.get_file(), setting])
	if record.is_empty():
		notes.append("sin registro de exportación: exportar con blender/scripts/exportar_glb.py")
	elif record.get("sha256", "") != FileAccess.get_sha256(path):
		notes.append("el GLB no es el que escribió exportar_glb.py (huella distinta)")
	var scene := load(path) as PackedScene
	if scene == null:
		problems.append("%s no se puede cargar como escena" % path)
		_report(id, problems, notes)
		return
	var root := scene.instantiate()
	_check_nodes(root, root, problems)
	var objects := ModelCatalog.objects_from_node(root)
	for child in root.get_children():
		if child is Node3D and not (child as Node3D).basis.is_equal_approx(Basis.IDENTITY):
			problems.append("el objeto %s tiene giro o escala sin aplicar" % child.name)
	root.free()
	if objects.is_empty():
		problems.append("el GLB no tiene mallas")
	var variants: Dictionary = reference.get("variantes", {})
	# «fiel» puede ser true, false u "optimizado" (le faltan caras que no se ven).
	var fidelity: Variant = info.get("fiel", true)
	var faithful: bool = fidelity is bool and fidelity
	var total := 0
	for variant: String in variants:
		var expected: Dictionary = variants[variant]
		var object_name: String = expected["objeto"]
		if (expected.get("usos", []) as Array).is_empty():
			problems.append("la variante «%s» no tiene usos: no hay código procedural de respaldo" % variant)
		if not objects.has(object_name):
			problems.append("falta el objeto %s (variante «%s»): se dibuja con el código procedural" % [object_name, variant])
			continue
		var surfaces: Array = objects[object_name]
		var triangles := _triangles(surfaces)
		total += triangles
		if faithful and triangles != int(expected["triangulos"]):
			problems.append("%s: %d triángulos y la pieza procedural %d (el modelo es «fiel»)" % [object_name, triangles, expected["triangulos"]])
		elif triangles != int(expected["triangulos"]):
			notes.append("%s: %d triángulos (procedural %d)" % [object_name, triangles, expected["triangulos"]])
		var box := _box(surfaces)
		var low := _vector(expected["caja"]["min"])
		var high := _vector(expected["caja"]["max"])
		if not _within(box.position, low) or not _within(box.end, high):
			problems.append("%s: caja %s–%s y la procedural %s–%s (tolerancia %.2f m)" % [object_name, box.position, box.end, low, high, BOX_TOLERANCE])
		for surface: Dictionary in surfaces:
			if (surface["colors"] as PackedColorArray).is_empty():
				problems.append("%s: sin color de vértice" % object_name)
	for object_name: String in objects:
		var used := false
		for variant: String in variants:
			used = used or variants[variant]["objeto"] == object_name
		if not used:
			notes.append("el objeto %s no lo pide ningún escenario" % object_name)
	if problems.is_empty():
		var note := "" if faithful else (" (optimizado)" if fidelity is String else " (retocado en Blender)")
		print("OK %s: %d objetos, %d triángulos%s" % [id, objects.size(), total, note])
	_report(id, problems, notes)


func _check_nodes(node: Node, root: Node, problems: Array[String]) -> void:
	if node != root and not (node is MeshInstance3D or node.get_class() == "Node3D"):
		problems.append("nodo %s de tipo %s: un modelo sólo puede tener mallas (sin luces, cámaras, esqueletos ni animaciones)" % [node.name, node.get_class()])
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		for index in mesh.get_surface_count():
			var material := mesh.surface_get_material(index)
			var material_name := material.resource_name if material != null else "(sin material)"
			if not VALID_MATERIALS.has(material_name):
				problems.append("%s usa el material «%s»; válidos: %s" % [node.name, material_name, ", ".join(VALID_MATERIALS)])
			if mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES:
				problems.append("%s tiene una superficie que no es de triángulos" % node.name)
	for child in node.get_children():
		_check_nodes(child, root, problems)


func _check_orphans() -> void:
	var directory := ProjectSettings.globalize_path("res://").path_join(BLENDER_DIR).path_join("referencias").simplify_path()
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file_name in DirAccess.get_files_at(directory):
		var id := file_name.get_basename()
		if file_name.ends_with(".json") and not ModelCatalog.MODELS.has(id):
			_warnings += 1
			print("AVISO %s: hay referencia pero no está registrado en ModelCatalog.MODELS" % id)


func _report(id: String, problems: Array[String], notes: Array[String]) -> void:
	for problem in problems:
		_errors += 1
		print("ERROR %s: %s" % [id, problem])
	for note in notes:
		_warnings += 1
		print("AVISO %s: %s" % [id, note])


static func _read_json(relative: String) -> Dictionary:
	var path := ProjectSettings.globalize_path("res://").path_join(relative).simplify_path()
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func _triangles(surfaces: Array) -> int:
	var total := 0
	for surface: Dictionary in surfaces:
		total += (surface["vertices"] as PackedVector3Array).size() / 3
	return total


static func _box(surfaces: Array) -> AABB:
	var box := AABB()
	var first := true
	for surface: Dictionary in surfaces:
		for point: Vector3 in surface["vertices"]:
			if first:
				box = AABB(point, Vector3.ZERO)
				first = false
			else:
				box = box.expand(point)
	return box


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func _within(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) <= BOX_TOLERANCE and absf(a.y - b.y) <= BOX_TOLERANCE and absf(a.z - b.z) <= BOX_TOLERANCE
