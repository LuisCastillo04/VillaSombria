extends TestCase
## Red de seguridad contra caídas: si una colisión fallase, el detective vuelve al último suelo
## válido sin bucles y sin perder el estado de la partida.

const SAFE_SPOT := Vector3(0.0, 0.1, 0.0)

var game: Game
var _recovered: Array = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	GameState.set_flag("llamada_atendida")
	game = await make_game()
	await game.go_to("cafe", "desde_plaza")
	await wait_physics_frames(3)
	GameState.clear_player_locks()
	_recovered.clear()
	game.player.guard.recovered.connect(_on_recovered)
	game.player.teleport(SAFE_SPOT)
	await wait_physics_frames(20)


func after_each() -> void:
	DialogueManager.close()
	GameState.clear_player_locks()
	game.queue_free()
	await get_tree().process_frame


func _on_recovered(from: Vector3, to: Vector3) -> void:
	_recovered.append([from, to])


func test_safe_point_follows_the_player_on_valid_ground() -> void:
	var guard := game.player.guard
	check(_flat_distance(guard.get_safe_position(), SAFE_SPOT) < 0.1, "el punto de partida es seguro")
	var next_spot := Vector3(2.0, 0.1, 1.0)
	game.player.global_position = next_spot
	await wait_physics_frames(25)
	check(_flat_distance(guard.get_safe_position(), next_spot) < 0.1, "pisando suelo firme, el punto seguro se actualiza")


func test_safe_point_is_not_updated_in_the_air() -> void:
	var guard := game.player.guard
	game.player.global_position = Vector3(2.0, 4.0, 1.0)
	await wait_physics_frames(5)
	check(not game.player.is_on_floor(), "el detective está en el aire")
	check(_flat_distance(guard.get_safe_position(), SAFE_SPOT) < 0.1, "en el aire no se recuerda ningún punto")
	await wait_physics_frames(60)
	check(game.player.is_on_floor(), "aterriza")
	check(_flat_distance(guard.get_safe_position(), Vector3(2.0, 0.0, 1.0)) < 0.1, "tras aterrizar en suelo válido sí")


func test_falling_below_the_floor_returns_to_the_last_safe_point() -> void:
	var clues_before := GameState.clues.duplicate()
	game.player.global_position = Vector3(3.0, -6.0, 3.0)
	game.player.velocity = Vector3(0.0, -15.0, 0.0)
	await wait_physics_frames(3)
	check_equal(_recovered.size(), 1, "se detecta la caída una vez")
	check(_flat_distance(game.player.global_position, SAFE_SPOT) < 0.1, "vuelve al último suelo válido")
	check(game.player.global_position.y > -0.1, "a la altura del suelo")
	check(game.player.velocity.length() < 1.0, "sin la velocidad de la caída")
	await wait_physics_frames(10)
	check(game.player.is_on_floor(), "y de pie")
	check_equal(GameState.location_id, "cafe", "la partida sigue en el mismo lugar")
	check_equal(GameState.clues, clues_before, "sin tocar la investigación")
	check(not GameState.is_player_locked(), "el detective puede seguir moviéndose")


func test_leaving_the_play_area_returns_to_the_last_safe_point() -> void:
	# Fuera de las paredes del café el suelo de colisión continúa: sin la red, el detective
	# caminaría por la oscuridad hasta caer por el borde.
	game.player.global_position = Vector3(0.0, 0.1, 9.0)
	await wait_physics_frames(3)
	check_equal(_recovered.size(), 1, "se detecta la salida del área")
	check(_flat_distance(game.player.global_position, SAFE_SPOT) < 0.1, "vuelve dentro del café")


func test_movement_works_after_a_recovery() -> void:
	game.player.global_position = Vector3(0.0, -6.0, 0.0)
	await wait_physics_frames(20)
	var start := game.player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(30)
	Input.action_release("move_forward")
	check(game.player.global_position.distance_to(start) > 1.0, "tras el rescate el detective camina con normalidad")


func test_a_bad_safe_point_does_not_cause_a_loop() -> void:
	var guard := game.player.guard
	# Se fuerza un punto «seguro» en el vacío y se deja caer allí al detective: cada rescate
	# llevaría de nuevo a la caída.
	var bad_spot := Vector3(30.0, -10.0, 30.0)
	guard.reset(bad_spot)
	game.player.global_position = bad_spot
	await wait_physics_frames(150)
	check(_recovered.size() <= FallGuard.LOOP_LIMIT + 1, "el bucle se corta tras %d rescates (hubo %d)" % [FallGuard.LOOP_LIMIT + 1, _recovered.size()])
	check(_flat_distance(game.player.global_position, guard.fallback) < 0.2, "acaba en la entrada del escenario")
	check(game.player.is_on_floor(), "de pie en suelo firme")
	var settled := _recovered.size()
	await wait_physics_frames(60)
	check_equal(_recovered.size(), settled, "y no hay más rescates")


func test_saving_mid_fall_stores_the_last_safe_point() -> void:
	game.player.global_position = Vector3(3.0, 5.0, 3.0)
	await wait_physics_frames(2)
	var pose := game._capture_player()
	var stored: Array = pose["position"]
	check(_flat_distance(Vector3(stored[0], stored[1], stored[2]), SAFE_SPOT) < 0.1, "se guarda el último suelo válido, no el aire")


func test_loading_a_position_outside_the_scene_uses_the_entrance() -> void:
	var entrance: Vector3 = game.current_location.get_spawn("desde_plaza")["position"]
	game.player.teleport(entrance)
	game._restore_player({"location_id": "cafe", "position": [0.0, 0.0, 10.0], "yaw": 0.0})
	game._apply_saved_pose()
	check(_flat_distance(game.player.global_position, entrance) < 0.1, "una posición fuera del café no se aplica")
	game._restore_player({"location_id": "cafe", "position": [2.0, 0.0, 1.0], "yaw": 0.0})
	game._apply_saved_pose()
	check(_flat_distance(game.player.global_position, Vector3(2.0, 0.0, 1.0)) < 0.1, "una posición válida sí")


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
