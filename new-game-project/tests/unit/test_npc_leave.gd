extends TestCase
## Salida de los NPC cuando su rutina los lleva a otro lugar mientras el detective está delante:
## caminan hasta la salida y la cruzan desvaneciéndose, en lugar de desaparecer de golpe. No se
## duplican, no se quedan atascados y, si su rutina los vuelve a traer, se quedan.

var location: LocationBase


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	# La mansión sólo se visita después de la llamada del café.
	GameState.set_flag("llamada_atendida")


func after_each() -> void:
	if is_instance_valid(location):
		location.queue_free()
	GameClock.reset()
	GameState.reset()
	await get_tree().process_frame


func _load(location_id: String, time: String) -> void:
	GameClock.minutes = GameClock.parse_time(time)
	location = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
	add_child(location)
	for frame in 120:
		if location.navigation.is_map_ready():
			return
		await get_tree().physics_frame
	failures.append("la navegación de %s no llega a estar lista" % location_id)


## A las 16:00 del domingo Irene deja la mansión por el café: cruza la casa andando y sale por la
## puerta de la calle.
func test_npc_walks_out_through_the_street_door() -> void:
	await _load("mansion", "15:50")
	var irene := location.get_npc("irene")
	check(irene != null, "Irene está en la mansión antes de las cuatro")
	if irene == null:
		return
	irene.profile.walk_speed = 2.5
	irene.agent.max_speed = 2.5
	GameClock.advance(10)
	await wait_physics_frames(2)
	check(irene.is_leaving(), "a las cuatro se va")
	check_equal(irene.state, Npc.State.LEAVE, "caminando hacia la salida")
	check(not irene.interaction.can_interact() and not irene.interaction.wants_attention(), "sin aviso ni conversación mientras se va")
	check(location.get_npc("irene") == irene, "sigue en el escenario hasta salir: nunca hay dos Irene")
	var last: Array[Vector3] = [irene.global_position]
	irene.left.connect(func(npc: Npc) -> void: last[0] = npc.global_position)
	var biggest_step := 0.0
	var previous := irene.global_position
	var bad_spots: Array[Vector3] = []
	var gone := false
	for frame in 900:
		await get_tree().physics_frame
		if not is_instance_valid(irene):
			gone = true
			break
		biggest_step = maxf(biggest_step, _flat(previous, irene.global_position))
		previous = irene.global_position
		if not irene._exiting and frame % 10 == 0 and not location.is_standing_point(irene.global_position, 0.22):
			bad_spots.append(irene.global_position)
	check(gone, "al cruzar la puerta se va del escenario")
	check(location.get_npc("irene") == null, "y deja de contar entre los presentes")
	check(biggest_step < 0.25, "camina, no salta (paso máximo %.2f m)" % biggest_step)
	check(bad_spots.is_empty(), "nunca atraviesa paredes ni muebles: %s" % str(bad_spots.slice(0, 3)))
	# La puerta de la calle de la mansión: hueco de 2,4 m centrado en x = 0,5, en la pared z = 9.
	check(last[0].z > 8.5 and absf(last[0].x - 0.5) < 1.2, "sale por la puerta de la calle (%s)" % str(last[0].snapped(Vector3.ONE * 0.01)))


## Si su rutina lo vuelve a traer antes de salir, se queda: visible, con colisión y se le puede
## volver a hablar. Sigue habiendo uno solo.
func test_npc_called_back_before_leaving_stays() -> void:
	await _load("mansion", "09:00")
	var irene := location.get_npc("irene")
	location._send_away(irene)
	check(irene.is_leaving(), "se va")
	await wait_physics_frames(45)
	check(irene.global_position.distance_to(irene.home) > 0.4, "ha echado a andar hacia la salida")
	location.refresh_npcs()
	await wait_physics_frames(2)
	check(not irene.is_leaving(), "su rutina la vuelve a traer: se queda")
	check(irene.interaction.can_interact(), "se le puede volver a hablar")
	check(irene.visible and irene.collision_layer != 0, "visible y con colisión")
	var copies := 0
	for npc: Npc in location.get_npcs():
		if npc.npc_id == "irene":
			copies += 1
	check_equal(copies, 1, "una sola Irene")
	check_equal(irene.state, Npc.State.RETURN, "vuelve a su puesto")


## Con el paso a la salida cortado (aquí, una caja sobre el umbral que la navegación no conocía),
## no se queda esperando para siempre: cerca de la puerta la cruza igualmente.
func test_blocked_exit_is_crossed_anyway() -> void:
	await _load("mansion", "15:50")
	var irene := location.get_npc("irene")
	check(irene != null, "Irene está en la mansión antes de las cuatro")
	if irene == null:
		return
	irene.profile.walk_speed = 2.5
	irene.agent.max_speed = 2.5
	var box := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var size := BoxShape3D.new()
	size.size = Vector3(2.6, 2.0, 0.9)
	shape.shape = size
	box.add_child(shape)
	location.add_child(box)
	box.global_position = Vector3(0.5, 1.0, 8.5)
	GameClock.advance(10)
	await wait_physics_frames(2)
	check(irene.is_leaving(), "a las cuatro se va")
	var gone := false
	for frame in 1200:
		await get_tree().physics_frame
		if not is_instance_valid(irene):
			gone = true
			break
	check(gone, "aunque algo tape el umbral, acaba saliendo")


## En un escenario sin salidas (el campo de pruebas), quien se va desaparece como antes.
func test_location_without_exits_removes_at_once() -> void:
	await _load("test_ground", "09:00")
	location._spawn_npc("hilario", {"marker": "", "behavior": "stay"})
	var hilario := location.get_npc("hilario")
	check(hilario != null, "aparece")
	location._send_away(hilario)
	check(location.get_npc("hilario") == null, "sin salida, deja de estar al instante")


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
