extends TestCase
## Comportamiento de los NPC y sincronización con sus rutinas.

var location: LocationBase


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	location = (load("res://scenes/world/locations/plaza.tscn") as PackedScene).instantiate()
	add_child(location)
	await wait_physics_frames(2)


func after_each() -> void:
	DialogueManager.close()
	location.queue_free()
	GameClock.reset()
	await get_tree().process_frame


func test_schedule_places_npc_at_marker() -> void:
	var hilario := location.get_npc("hilario")
	check(hilario != null, "Hilario pasea por la plaza el domingo")
	if hilario != null:
		var distance := hilario.global_position.distance_to(location.get_marker("fuente_este"))
		check(distance < 0.5, "debe aparecer en su marcador")
		check_equal(hilario.display_name, "Don Hilario Luna", "nombre cargado de los datos")
		check(not hilario.personality.is_empty(), "personalidad cargada de los datos")


func test_time_change_moves_npcs_between_locations() -> void:
	GameClock.start_next_day()
	await wait_physics_frames(2)
	check(location.get_npc("hilario") == null, "el lunes Hilario está en el archivo")
	check(location.get_npc("ortega") != null, "el lunes por la mañana Ortega hace la ronda")
	check(location.get_npc("lucia") != null, "el lunes por la mañana Lucía hace recados")


func test_npc_walks_between_points_and_waits() -> void:
	var hilario := location.get_npc("hilario")
	hilario.wait_seconds = 0.2
	var start := hilario.global_position
	var points: Array[Vector3] = [start + Vector3(1.0, 0.0, 0.0), start]
	hilario.set_route(points)
	check_equal(hilario.state, Npc.State.WALKING, "con ruta debe caminar")
	var reached_wait := false
	for frame in 90:
		await get_tree().physics_frame
		if hilario.state == Npc.State.WAITING:
			reached_wait = true
			break
	check(reached_wait, "al llegar debe esperar")
	var distance := Vector2(hilario.global_position.x, hilario.global_position.z).distance_to(Vector2(points[0].x, points[0].z))
	check(distance < 0.3, "debe llegar al primer punto")
	await wait_physics_frames(20)
	check_equal(hilario.state, Npc.State.WALKING, "tras esperar reanuda la ruta")


func test_conversation_pauses_and_resumes_route() -> void:
	var hilario := location.get_npc("hilario")
	var start := hilario.global_position
	var points: Array[Vector3] = [start + Vector3(3.0, 0.0, 0.0), start]
	hilario.set_route(points)
	await wait_physics_frames(5)
	var watcher := Node3D.new()
	add_child(watcher)
	watcher.global_position = start + Vector3(0.0, 0.0, 2.0)
	hilario.begin_talk(watcher)
	DialogueManager.start("hilario")
	check_equal(hilario.state, Npc.State.TALKING, "debe detenerse a hablar")
	var frozen := hilario.global_position
	await wait_physics_frames(10)
	check(hilario.global_position.distance_to(frozen) < 0.05, "no debe moverse mientras habla")
	DialogueManager.close()
	await wait_physics_frames(3)
	check_equal(hilario.state, Npc.State.WALKING, "al terminar retoma lo que hacía")
	watcher.queue_free()
