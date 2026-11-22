extends TestCase
## Interacciones con NPC en movimiento, con la escena de juego real en la mansión: se detienen y
## miran al detective que los enfoca, conversan sin moverse, retoman lo suyo después y nunca le
## cierran el paso para siempre.

var game: Game
## Destino de Lucía justo antes de que el detective le salga al paso.
var _lucia_heading := Vector3.ZERO


func before_each() -> void:
	game = await make_game()
	await game.go_to("mansion", "desde_plaza")
	GameState.clear_player_locks()
	for frame in 120:
		if game.current_location.navigation.is_map_ready():
			break
		await get_tree().physics_frame


func after_each() -> void:
	DialogueManager.close()
	GameState.clear_player_locks()
	SaveSystem.take_pending_load()
	if game != null:
		game.queue_free()
	await get_tree().process_frame


## Espera a que Lucía vaya andando por su ronda y planta al detective unos pasos por delante.
func _meet_lucia_on_her_way() -> Npc:
	var lucia := game.current_location.get_npc("lucia")
	lucia.profile.pause_range = Vector2(0.2, 0.3)
	await _wait_state(lucia, Npc.State.PATROL, 600)
	await wait_physics_frames(30)
	_lucia_heading = lucia.get_target()
	var ahead := lucia.global_position + (lucia.get_target() - lucia.global_position).normalized() * 1.6
	game.player.teleport(Vector3(ahead.x, 0.1, ahead.z))
	await wait_physics_frames(6)
	return lucia


func test_npc_stops_and_faces_the_player_who_focuses_it() -> void:
	var lucia := await _meet_lucia_on_her_way()
	check(game.player.detector.get_focused() == lucia.interaction, "Lucía queda enfocada")
	check_equal(lucia.state, Npc.State.INTERACT, "se detiene al verse enfocada")
	var stopped_at := lucia.global_position
	await wait_physics_frames(60)
	check(_flat(lucia.global_position, stopped_at) < 0.1, "no se aleja mientras el detective quiere hablarle")
	var looking := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, lucia.model.rotation.y)
	var toward := game.player.global_position - lucia.global_position
	toward.y = 0.0
	check(looking.dot(toward.normalized()) > 0.9, "se vuelve hacia el detective")


func test_npc_resumes_when_the_player_walks_away() -> void:
	var lucia := await _meet_lucia_on_her_way()
	check_equal(lucia.state, Npc.State.INTERACT, "se detiene")
	var heading := _lucia_heading
	# Al cuarto de Lucía, vacío el domingo: lejos de todos.
	game.player.teleport(Vector3(-10.0, 0.1, 2.5))
	await wait_physics_frames(6)
	check_equal(lucia.state, Npc.State.PATROL, "al irse el detective sigue con su ronda")
	check(_flat(lucia.get_target(), heading) < 0.1, "hacia el mismo punto")


## Si el detective la enfoca sin hablarle, al cabo de un rato sigue: no le cierra el paso.
func test_attention_has_a_time_limit() -> void:
	var lucia := game.current_location.get_npc("lucia")
	lucia.profile.attend_seconds = 0.5
	lucia = await _meet_lucia_on_her_way()
	check_equal(lucia.state, Npc.State.INTERACT, "se detiene")
	await _wait_until(func() -> bool: return lucia.state != Npc.State.INTERACT, 90)
	check(lucia.is_walking(), "pasado el rato sigue con su ronda")
	await wait_physics_frames(20)
	check(lucia.state != Npc.State.INTERACT, "y no vuelve a pararse enseguida")


## Hablarle con E: se detiene, lo mira, no se mueve durante la conversación y la retoma después.
func test_talking_with_e_freezes_and_then_resumes() -> void:
	var lucia := await _meet_lucia_on_her_way()
	lucia.profile.talk_pause_range = Vector2(0.3, 0.4)
	var heading := _lucia_heading
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics_frames(3)
	check(DialogueManager.active, "se abre la conversación")
	check_equal(lucia.state, Npc.State.DIALOGUE, "Lucía conversa")
	check(GameState.is_player_locked(), "el detective queda quieto")
	var frozen := lucia.global_position
	await wait_physics_frames(60)
	check(_flat(lucia.global_position, frozen) < 0.05, "no se desplaza durante la conversación")
	DialogueManager.close()
	await wait_physics_frames(2)
	check_equal(lucia.state, Npc.State.IDLE, "al terminar se toma un momento")
	await _wait_state(lucia, Npc.State.PATROL, 120)
	check_equal(lucia.state, Npc.State.PATROL, "y retoma su ronda")
	check(_flat(lucia.get_target(), heading) < 0.1, "hacia donde iba")


## Un NPC que espera en su sitio también se vuelve hacia quien se le acerca a hablar.
func test_standing_npc_turns_to_the_player() -> void:
	var elena := game.current_location.get_npc("elena")
	# Por detrás de ella, del lado contrario a la chimenea hacia la que mira.
	var behind := elena.global_position + Vector3(-1.2, 0.0, 1.2)
	game.player.teleport(Vector3(behind.x, 0.1, behind.z))
	await wait_physics_frames(6)
	check_equal(elena.state, Npc.State.INTERACT, "Elena atiende al detective")
	await wait_physics_frames(60)
	var looking := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, elena.model.rotation.y)
	var toward := game.player.global_position - elena.global_position
	toward.y = 0.0
	check(looking.dot(toward.normalized()) > 0.9, "se vuelve hacia él")


## El detective plantado en medio de una ronda no la detiene para siempre: el NPC lo rodea.
func test_npc_walks_around_a_player_in_the_way() -> void:
	var ortega := game.current_location.get_npc("ortega")
	ortega.profile.pause_range = Vector2(0.2, 0.3)
	ortega.profile.attend_seconds = 0.5
	var north := game.current_location.get_marker("vestibulo_norte")
	var south := game.current_location.get_marker("vestibulo")
	game.player.teleport((north + south) * 0.5 + Vector3.UP * 0.1)
	var reached_north := false
	var reached_south_again := false
	var closest := INF
	for frame in 1500:
		await get_tree().physics_frame
		closest = minf(closest, _flat(ortega.global_position, game.player.global_position))
		if not reached_north and _flat(ortega.global_position, north) < 0.4:
			reached_north = true
		elif reached_north and _flat(ortega.global_position, south) < 0.4:
			reached_south_again = true
			break
	check(reached_north, "Ortega llega al otro extremo de su ronda")
	check(reached_south_again, "y vuelve: el detective no lo bloquea")
	check(closest > 0.55, "sin atravesar al detective (%.2f m)" % closest)


## El sargento, imprescindible el primer día, siempre está a la vista de la entrada.
func test_quest_npc_stays_within_reach() -> void:
	var ortega := game.current_location.get_npc("ortega")
	var entrance: Vector3 = game.current_location.get_spawn("desde_plaza")["position"]
	var farthest := 0.0
	for frame in 900:
		await get_tree().physics_frame
		farthest = maxf(farthest, _flat(ortega.global_position, ortega.home))
	check(farthest < 4.0, "no se aleja de su puesto (%.1f m)" % farthest)
	var path := game.current_location.navigation.find_path(entrance, ortega.global_position)
	check(not path.is_empty() and _flat(path[path.size() - 1], ortega.global_position) < 0.6, "hay camino desde la entrada hasta él")
	check(LocationNavigation.path_length(path) < 8.0, "y es corto")


## Guardar con los NPC a medio camino y cargar en otra escena de juego: el detective vuelve a su
## sitio y cada NPC aparece en un punto válido de su rutina, sin solaparse.
func test_save_and_load_keep_valid_positions() -> void:
	TestCase.clear_save_storage()
	await wait_physics_frames(240)
	var spot := Vector3(2.0, 0.1, 6.0)
	game.player.teleport(spot)
	await wait_physics_frames(20)
	check(await save_and_wait("manual_1"), "se guarda la partida")
	game.queue_free()
	game = null
	await get_tree().process_frame
	check(SaveSystem.request_load("manual_1")["ok"], "se prepara la carga")
	game = await make_game()
	for frame in 120:
		if game.current_location.navigation.is_map_ready():
			break
		await get_tree().physics_frame
	check_equal(game.current_location.location_id, "mansion", "reanuda en la mansión")
	check(_flat(game.player.global_position, spot) < 0.1, "el detective vuelve a su sitio")
	var npcs: Array = game.current_location.get_npcs()
	check_equal(npcs.size(), 6, "los seis personajes de la mañana del domingo")
	for npc: Npc in npcs:
		check(game.current_location.is_standing_point(npc.global_position, 0.25), "%s aparece en un punto válido" % npc.npc_id)
		check(_flat(npc.global_position, npc.home) < 0.6, "%s, en su puesto" % npc.npc_id)
	await wait_physics_frames(120)
	for npc: Npc in npcs:
		check(npc.is_on_floor(), "%s sigue en el suelo tras cargar" % npc.npc_id)
	TestCase.clear_save_storage()

func _wait_state(npc: Npc, wanted: Npc.State, frames: int) -> void:
	await _wait_until(func() -> bool: return npc.state == wanted, frames)


func _wait_until(condition: Callable, frames: int) -> void:
	for frame in frames:
		if condition.call():
			return
		await get_tree().physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
