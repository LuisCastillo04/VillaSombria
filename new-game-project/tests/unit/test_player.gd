extends TestCase
## Movimiento, colisiones e interacción del detective con entradas simuladas.

var game: Game


func before_each() -> void:
	game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await wait_physics_frames(3)
	await game.go_to("test_ground", "inicio")
	await wait_physics_frames(3)
	GameState.clear_player_locks()


func after_each() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)
	GameState.clear_player_locks()
	game.queue_free()
	await get_tree().process_frame


func test_w_moves_up_the_screen() -> void:
	var start := game.player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(30)
	Input.action_release("move_forward")
	var moved := game.player.global_position - start
	check(moved.length() > 1.0, "el detective debe desplazarse")
	# Con la cámara a 45 grados, "arriba" en pantalla es hacia -X y -Z a la vez.
	var camera_forward := -game.camera.camera.global_basis.z
	camera_forward.y = 0.0
	check(moved.normalized().dot(camera_forward.normalized()) > 0.98, "W debe seguir la orientación de la cámara")


func test_d_moves_right_of_the_camera() -> void:
	var start := game.player.global_position
	Input.action_press("move_right")
	await wait_physics_frames(30)
	Input.action_release("move_right")
	var moved := game.player.global_position - start
	var camera_right := game.camera.camera.global_basis.x
	check(moved.normalized().dot(camera_right.normalized()) > 0.98, "D debe mover hacia la derecha de la cámara")


func test_walls_stop_the_player() -> void:
	# La caja de ladrillo ocupa X en [-6.5, -3.5]; se camina hacia ella en línea recta.
	game.player.teleport(Vector3(-5.0, 0.1, 2.0))
	var yaw := game.player.camera_yaw
	# Dirección de entrada que produce movimiento exacto hacia -Z en el mundo.
	var input := Vector2(0.0, -1.0).rotated(yaw)
	for frame in 120:
		game.player._move(input, false, 1.0 / 60.0)
		await get_tree().physics_frame
	check(game.player.global_position.z > -2.0 + 0.2, "la caja debe detener al detective en Z=-2")


func test_locked_player_ignores_input() -> void:
	GameState.lock_player("prueba")
	var start := game.player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(20)
	Input.action_release("move_forward")
	check(game.player.global_position.distance_to(start) < 0.05, "el jugador bloqueado no debe moverse")
	GameState.unlock_player("prueba")


func test_unlock_requires_every_reason_released() -> void:
	GameState.lock_player("a")
	GameState.lock_player("b")
	GameState.unlock_player("a")
	check(GameState.is_player_locked(), "debe seguir bloqueado mientras quede un motivo")
	GameState.unlock_player("b")
	check(not GameState.is_player_locked(), "sin motivos debe quedar libre")


func test_interaction_reaches_nearby_object() -> void:
	var received: Array[String] = []
	var listener := func(title: String, _body: String, _kind: String) -> void:
		received.append(title)
	EventBus.notification_requested.connect(listener)
	game.player.teleport(Vector3(2.0, 0.1, 3.0))
	await wait_physics_frames(6)
	check(game.player.detector.get_focused() != null, "el poste cercano debe quedar enfocado")
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics_frames(3)
	EventBus.notification_requested.disconnect(listener)
	check_equal(received.size(), 1, "pulsar E debe disparar la interacción una vez")


func test_far_object_is_not_focused() -> void:
	game.player.teleport(Vector3(-8.0, 0.1, 8.0))
	await wait_physics_frames(6)
	check(game.player.detector.get_focused() == null, "un objeto lejano no debe enfocarse")
