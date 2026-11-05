extends Node
## Ejecuta las pruebas de `tests/unit`. Se lanza como escena para que los autoloads
## estén disponibles:  godot --headless --path . res://tests/test_runner.tscn

const UNIT_DIR := "res://tests/unit"
const SCRIPT_ROOTS: Array[String] = ["res://scripts", "res://tests/unit"]

var _passed := 0
var _failed := 0


func _ready() -> void:
	# Las pruebas nunca deben tocar la partida guardada del jugador.
	SaveSystem.autosave_enabled = false
	SaveSystem.save_path = "user://prueba_partida.json"
	_check_scripts_load()
	var filter := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--filtro="):
			filter = argument.trim_prefix("--filtro=")
	for file_name in _sorted_files(UNIT_DIR):
		var matches_filter := filter.is_empty() or file_name.contains(filter)
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and matches_filter:
			await _run_file(UNIT_DIR.path_join(file_name))
	SaveSystem.delete_save()
	print("RESUMEN: %d correctas, %d con fallos" % [_passed, _failed])
	# Una ejecución sin pruebas también es un fallo: no demuestra nada.
	get_tree().quit(1 if _failed > 0 or _passed == 0 else 0)


## Carga todos los scripts para detectar errores de análisis en archivos que ninguna
## escena referencia todavía.
func _check_scripts_load() -> void:
	var count := 0
	for root in SCRIPT_ROOTS:
		for path in _collect_scripts(root):
			count += 1
			var script := load(path) as GDScript
			if script == null or not script.can_instantiate():
				_failed += 1
				print("FALLO carga de script: ", path)
	print("OK %d scripts cargados" % count)


func _collect_scripts(root: String) -> Array[String]:
	var found: Array[String] = []
	for directory in DirAccess.get_directories_at(root):
		found.append_array(_collect_scripts(root.path_join(directory)))
	for file_name in DirAccess.get_files_at(root):
		if file_name.ends_with(".gd"):
			found.append(root.path_join(file_name))
	return found


func _sorted_files(root: String) -> Array[String]:
	var files: Array[String] = []
	files.assign(DirAccess.get_files_at(root))
	files.sort()
	return files


func _run_file(path: String) -> void:
	var script: GDScript = load(path)
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("test_"):
			continue
		var test: TestCase = script.new()
		add_child(test)
		await test.before_each()
		await test.call(method_name)
		await test.after_each()
		var label := "%s.%s" % [path.get_file().get_basename(), method_name]
		if test.failures.is_empty():
			_passed += 1
			print("OK ", label)
		else:
			_failed += 1
			for failure in test.failures:
				print("FALLO ", label, ": ", failure)
		remove_child(test)
		test.queue_free()
