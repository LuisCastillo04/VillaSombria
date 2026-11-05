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
