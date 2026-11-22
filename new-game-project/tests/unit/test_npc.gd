extends TestCase
## Comportamiento de los NPC: rutinas, orientación en su puesto, rondas y paseos con navegación
## (sin atravesar nada ni alejarse), convivencia entre ellos, caminos bloqueados, caídas y coste.

var location: LocationBase


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	location = _instantiate("plaza")
	await _wait_navigation(location)


func after_each() -> void:
	DialogueManager.close()
	if is_instance_valid(location):
		location.queue_free()
	GameClock.reset()
	GameState.reset()
	await get_tree().process_frame


func _instantiate(location_id: String) -> LocationBase:
	var instance: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
	add_child(instance)
	return instance


func _wait_navigation(where: LocationBase) -> bool:
	for frame in 120:
		if where.navigation.is_map_ready():
			return true
		await get_tree().physics_frame
	failures.append("la navegación de %s no llega a estar lista" % where.location_id)
	return false


func test_schedule_places_npc_at_marker() -> void:
	var hilario := location.get_npc("hilario")
	check(hilario != null, "Hilario pasea por la plaza el domingo")
	if hilario != null:
		var distance := hilario.global_position.distance_to(location.get_marker("fuente_este"))
		check(distance < 0.5, "debe aparecer en su marcador")
		check_equal(hilario.display_name, "Don Hilario Luna", "nombre cargado de los datos")
		check(not hilario.personality.is_empty(), "personalidad cargada de los datos")
		check_equal(hilario.profile.mode, NpcProfile.Mode.WANDER, "el domingo pasea")


func test_time_change_moves_npcs_between_locations() -> void:
	GameClock.start_next_day()
	await wait_physics_frames(2)
	check(location.get_npc("hilario") == null, "el lunes Hilario está en el archivo")
	check(location.get_npc("ortega") != null, "el lunes por la mañana Ortega hace la ronda")
	check(location.get_npc("lucia") != null, "el lunes por la mañana Lucía hace recados")
	check_equal(location.get_npc("ortega").profile.mode, NpcProfile.Mode.PATROL, "la ronda de Ortega es una patrulla")


## Ronda con navegación: rodea la fuente en lugar de atravesarla y espera en cada punto.
func test_patrol_walks_around_obstacles_and_waits() -> void:
	var hilario := location.get_npc("hilario")
	hilario.place(location, {"marker": "fuente_este", "patrol": ["fuente_este", "fuente_oeste"], "speed": 2.0, "pause": [0.3, 0.4]})
	var fountain := Vector3(3.5, 0.0, 3.0)
	var target := location.get_marker("fuente_oeste")
	var walked := false
	var arrived := false
	var closest_to_fountain := INF
	for frame in 720:
		await get_tree().physics_frame
		closest_to_fountain = minf(closest_to_fountain, _flat(hilario.global_position, fountain))
		if hilario.state == Npc.State.PATROL:
			walked = true
		if walked and hilario.state == Npc.State.IDLE and _flat(hilario.global_position, target) < 0.4:
			arrived = true
			break
	check(walked, "con ronda debe echar a andar")
	check(arrived, "debe llegar al otro lado de la fuente y detenerse")
	# La colisión de la fuente es un octógono de 1,7 m de apotema; más el radio del cuerpo, 2 m.
	check(closest_to_fountain > 1.95, "nunca atraviesa la fuente (llegó a %.2f m del centro)" % closest_to_fountain)
	check(hilario.is_on_floor(), "sigue en el suelo")


## Paseo ambiental: se mueve, pero siempre cerca de su puesto, en el suelo y sin meterse en nada.
func test_wandering_stays_near_home_on_free_ground() -> void:
	var hilario := location.get_npc("hilario")
	hilario.place(location, {"marker": "fuente_este", "behavior": "wander", "radius": 2.5, "wander_chance": 1.0, "pause": [0.2, 0.4], "speed": 1.8})
	var home := hilario.home
	var travelled := 0.0
	var previous := hilario.global_position
	var farthest := 0.0
	var bad_spots: Array[Vector3] = []
	for frame in 900:
		await get_tree().physics_frame
		travelled += _flat(previous, hilario.global_position)
		previous = hilario.global_position
		farthest = maxf(farthest, _flat(home, hilario.global_position))
		if frame % 15 == 0 and not location.is_standing_point(hilario.global_position, 0.22):
			bad_spots.append(hilario.global_position)
	check(travelled > 3.0, "debe pasear (recorrió %.1f m)" % travelled)
	check(farthest <= 2.5 + 0.6, "no se aleja de su puesto (llegó a %.1f m)" % farthest)
	check(bad_spots.is_empty(), "nunca está dentro de un obstáculo ni fuera del suelo: %s" % str(bad_spots.slice(0, 3)))


## El fallo original: Lucía iba hasta el sitio de Irene y los NPC se atravesaban entre sí.
func test_npcs_never_overlap_while_moving() -> void:
	location.queue_free()
	GameClock.minutes = GameClock.parse_time("09:00")
	location = _instantiate("mansion")
	await _wait_navigation(location)
	var npcs: Array[Npc] = []
	for npc_id: String in ["ortega", "elena", "marcos", "lucia", "anselmo", "irene"]:
		var npc := location.get_npc(npc_id)
		check(npc != null, "%s está en la mansión el domingo a las 9" % npc_id)
		if npc != null:
			npc.profile.pause_range = Vector2(0.3, 0.8)
			npc.profile.wander_chance = 1.0
			npc.profile.walk_speed = 1.8
			npcs.append(npc)
	var closest := INF
	var pair := ""
	for frame in 1200:
		await get_tree().physics_frame
		if frame % 5 != 0:
			continue
		for a in npcs.size():
			for b in range(a + 1, npcs.size()):
				var gap := _flat(npcs[a].global_position, npcs[b].global_position)
				if gap < closest:
					closest = gap
					pair = "%s y %s" % [npcs[a].npc_id, npcs[b].npc_id]
	check(closest > 0.5, "dos NPC se superponen: %s a %.2f m" % [pair, closest])
	var lucia := location.get_npc("lucia")
	check(lucia.path_requests > 1, "Lucía hace su ronda")


## Si el paso se corta (aquí, una caja que tapa la puerta del salón y que la navegación no conocía),
## el NPC se detiene y vuelve a decidir; nunca salta al destino atravesando el obstáculo.
func test_blocked_path_is_recalculated_without_teleporting() -> void:
	location.queue_free()
	GameClock.minutes = GameClock.parse_time("09:00")
	location = _instantiate("mansion")
	await _wait_navigation(location)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 3.0, 0.6)
	shape.shape = box
	wall.add_child(shape)
	location.add_child(wall)
	wall.global_position = Vector3(0.5, 1.5, -1.0)
	var lucia := location.get_npc("lucia")
	lucia.profile.pause_range = Vector2(0.2, 0.3)
	lucia.profile.walk_speed = 1.6
	var biggest_jump := 0.0
	var previous := lucia.global_position
	var gave_up := false
	var walked := false
	for frame in 600:
		await get_tree().physics_frame
		biggest_jump = maxf(biggest_jump, _flat(previous, lucia.global_position))
		previous = lucia.global_position
		walked = walked or lucia.state == Npc.State.PATROL
		var target := location.get_marker("salon_este")
		if walked and lucia.state == Npc.State.IDLE and _flat(lucia.global_position, lucia.home) > 0.6 and _flat(lucia.global_position, target) > 0.6:
			gave_up = true
		check(lucia.global_position.z > -0.75, "no atraviesa la caja que tapa la puerta")
		if lucia.global_position.z <= -0.75:
			break
	check(walked, "Lucía echa a andar hacia el salón")
	check(gave_up, "con el paso cortado se detiene a recalcular")
	check(biggest_jump < 0.5, "no se teletransporta (salto de %.2f m)" % biggest_jump)


func test_npc_that_falls_returns_to_its_post() -> void:
	var hilario := location.get_npc("hilario")
	hilario.global_position = Vector3(hilario.home.x, -6.0, hilario.home.z)
	await wait_physics_frames(3)
	check(hilario.guard.recoveries == 1, "la red de seguridad lo recoge")
	check(_flat(hilario.global_position, hilario.home) < 0.6 and hilario.global_position.y > -0.2, "vuelve a su puesto")
	await wait_physics_frames(10)
	check(hilario.is_on_floor(), "de pie")


## Con preguntas pendientes, la investigación lo necesita a mano: no se va de visita.
func test_npc_needed_by_the_story_skips_visits() -> void:
	location.queue_free()
	GameState.set_flag("llamada_atendida")
	GameClock.minutes = GameClock.parse_time("17:00")
	location = _instantiate("cafe")
	await _wait_navigation(location)
	var irene := location.get_npc("irene")
	check(DialogueManager.has_new_topics("irene"), "Irene tiene preguntas pendientes")
	irene.place(location, {"marker": "mesa_ventana", "behavior": "wander", "visits": ["barra_cliente"], "visit_chance": 1.0, "wander_chance": 0.0, "pause": [0.2, 0.3]})
	var visited := false
	for frame in 240:
		await get_tree().physics_frame
		visited = visited or _flat(irene.global_position, location.get_marker("barra_cliente")) < 1.0
	check(not visited, "con preguntas pendientes no se aleja de su mesa")
	for topic in DialogueManager.get_available_topics("irene"):
		GameState.asked_topics["irene/%s" % topic["id"]] = true
	check(not DialogueManager.has_new_topics("irene"), "ya no le quedan preguntas")
	for frame in 600:
		await get_tree().physics_frame
		if _flat(irene.global_position, location.get_marker("barra_cliente")) < 0.5:
			visited = true
			break
	check(visited, "sin preguntas pendientes sí se acerca a la barra")


## Las decisiones de movimiento se toman en las pausas: nada de pedir rutas en cada fotograma.
func test_navigation_is_not_queried_every_frame() -> void:
	location.queue_free()
	GameClock.minutes = GameClock.parse_time("09:00")
	location = _instantiate("mansion")
	await _wait_navigation(location)
	var frames := 600
	await wait_physics_frames(frames)
	for npc: Npc in location.get_npcs():
		check(npc.path_requests <= frames / 20, "%s pidió %d rutas en %d fotogramas" % [npc.npc_id, npc.path_requests, frames])


## Al hablarle se detiene y lo mira; mientras dura la conversación no se mueve; al terminar hace
## una pausa y retoma su ronda hacia el mismo punto. Con la ronda real de Ortega del lunes.
func test_conversation_pauses_and_resumes_activity() -> void:
	GameClock.start_next_day()
	await wait_physics_frames(2)
	var ortega := location.get_npc("ortega")
	check(ortega != null, "el lunes Ortega hace la ronda por la plaza")
	if ortega == null:
		return
	ortega.profile.pause_range = Vector2(0.2, 0.3)
	ortega.profile.talk_pause_range = Vector2(0.4, 0.5)
	for frame in 600:
		await get_tree().physics_frame
		if ortega.state == Npc.State.PATROL:
			break
	check_equal(ortega.state, Npc.State.PATROL, "camina hacia el siguiente punto de su ronda")
	await wait_physics_frames(20)
	var heading := ortega.get_target()
	var watcher := Node3D.new()
	add_child(watcher)
	watcher.global_position = ortega.global_position + Vector3(1.5, 0.0, 0.0)
	ortega.begin_talk(watcher)
	DialogueManager.start("ortega")
	check_equal(ortega.state, Npc.State.DIALOGUE, "se detiene a hablar")
	var frozen := ortega.global_position
	await wait_physics_frames(30)
	check(_flat(ortega.global_position, frozen) < 0.05, "no se mueve mientras habla")
	var looking := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, ortega.model.rotation.y)
	check(looking.dot(Vector3.RIGHT) > 0.9, "mira a su interlocutor")
	DialogueManager.close()
	await wait_physics_frames(2)
	check_equal(ortega.state, Npc.State.IDLE, "al terminar hace una pausa antes de seguir")
	for frame in 90:
		await get_tree().physics_frame
		if ortega.state == Npc.State.PATROL:
			break
	check_equal(ortega.state, Npc.State.PATROL, "y retoma su ronda")
	check(_flat(ortega.get_target(), heading) < 0.1, "hacia el mismo punto")
	watcher.queue_free()

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
