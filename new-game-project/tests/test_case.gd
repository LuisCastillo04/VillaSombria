class_name TestCase
extends Node
## Base de las pruebas. Cada método `test_*` de una subclase se ejecuta por separado.

var failures: Array[String] = []


## Se ejecuta antes de cada prueba.
func before_each() -> void:
	pass


## Se ejecuta después de cada prueba.
func after_each() -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])


## Crea la escena de juego sin la introducción narrativa.
func make_game() -> Game:
	Game.play_intro = false
	var instance: Game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(instance)
	await wait_physics_frames(3)
	return instance


func wait_physics_frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


## Vacía la carpeta de partidas de las pruebas, incluidas las marcas y los temporales.
static func clear_save_storage() -> void:
	var directory := SaveSystem.get_storage_dir()
	if not directory.begins_with("user://pruebas"):
		push_error("Las pruebas sólo pueden vaciar su propia carpeta de partidas.")
		return
	if DirAccess.dir_exists_absolute(directory):
		for file_name in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file_name))
	SaveSystem.use_storage(directory)


## Guarda en una ranura y espera a que termine la escritura. Devuelve si salió bien.
func save_and_wait(slot_id: String, reason: String = "manual") -> bool:
	var started := SaveSystem.save_to_slot(slot_id, reason)
	if not started["ok"]:
		failures.append("no se pudo iniciar el guardado en %s: %s" % [slot_id, started["error"]])
		return false
	var outcome: Array = await SaveSystem.save_finished
	return outcome[0] == slot_id and outcome[1]


## Escribe un contenido cualquiera en el archivo de una ranura, sin validarlo.
func write_slot_file(slot_id: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.get_storage_dir())
	var file := FileAccess.open(SaveSystem.get_slot_path(slot_id), FileAccess.WRITE)
	file.store_string(text)
	file.close()
