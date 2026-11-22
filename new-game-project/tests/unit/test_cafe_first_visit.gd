extends TestCase
## Primera visita al Café La Luna, con la escena de juego real. Al entrar, Rosa y el sargento
## Ortega están en la sala, a la vista (fuera de lo que tapa la interfaz de la conversación) y de
## cara al inspector mientras le hablan. Al terminar, Ortega sale por la puerta de la calle y le
## espera en la mansión, y Rosa vuelve a la barra. Ni copias de nadie ni la escena repetida.

const DOOR := Vector3(0.0, 0.0, 6.0)

var game: Game


func before_each() -> void:
	game = await make_game()
	await game.go_to("cafe", "desde_plaza")
	# El fundido de entrada ya ha terminado: que las siluetas de la conversación lleguen a su sitio.
	await wait_physics_frames(45)


func after_each() -> void:
	DialogueManager.close()
	GameState.clear_player_locks()
	SaveSystem.take_pending_load()
	if game != null:
		game.queue_free()
	await get_tree().process_frame


func test_routines_put_both_in_the_cafe_until_the_call() -> void:
	for minutes in range(GameClock.DAY_START, GameClock.DAY_LIMIT, 30):
		var cafe := NpcSchedule.get_npcs_at("cafe", 1, minutes)
		check(cafe.has("rosa") and cafe.has("ortega"), "a las %d, antes de la llamada, Rosa y Ortega están en el café" % minutes)
		check(not NpcSchedule.get_npcs_at("mansion", 1, minutes).has("ortega"), "y Ortega no está a la vez en la mansión")
	GameState.set_flag("llamada_atendida")
	for minutes in range(GameClock.DAY_START, GameClock.DAY_LIMIT, 30):
		check(not NpcSchedule.get_npcs_at("cafe", 1, minutes).has("ortega"), "tras la llamada Ortega ya no está en el café")
		check(NpcSchedule.get_npcs_at("mansion", 1, minutes).has("ortega"), "sino en la mansión")
		check_equal(NpcSchedule.get_slot("rosa", 1, minutes).get("marker", ""), "barra", "y Rosa vuelve a la barra")


## Todo tramo con condición tiene detrás otro sin ella que cubre las mismas horas: cuando la
## condición deja de cumplirse, el personaje sigue teniendo rutina.
func test_conditional_slots_have_a_fallback() -> void:
	for npc_id: String in GameData.schedules:
		var slots: Array = GameData.schedules[npc_id]
		for index in slots.size():
			var slot: Dictionary = slots[index]
			if not slot.has("if"):
				continue
			var covered := false
			for later in range(index + 1, slots.size()):
				var other: Dictionary = slots[later]
				if other.has("if") or int(other["day"]) != int(slot["day"]):
					continue
				if GameClock.parse_time(other["from"]) <= GameClock.parse_time(slot["from"]) and GameClock.parse_time(other["to"]) >= GameClock.parse_time(slot["to"]):
					covered = true
			check(covered, "%s: el tramo condicionado del día %d necesita detrás uno sin condición" % [npc_id, int(slot["day"])])


func test_first_entry_has_rosa_and_ortega_in_the_room() -> void:
	check(DialogueManager.active and DialogueManager.scene_id == "llamada", "al entrar por primera vez empieza la escena")
	var rosa := game.current_location.get_npc("rosa")
	var ortega := game.current_location.get_npc("ortega")
	check(rosa != null and ortega != null, "Rosa y el sargento están en el café")
	if rosa == null or ortega == null:
		return
	check_equal(_count_in_tree("rosa"), 1, "una sola Rosa")
	check_equal(_count_in_tree("ortega"), 1, "un solo Ortega")
	var detective := game.player.global_position
	check(_flat(ortega.global_position, DOOR) < 2.5, "el sargento espera junto a la puerta")
	check(_flat(ortega.global_position, detective) < 2.5, "a un paso de quien entra")
	check(rosa.global_position.z > -3.0, "Rosa ha salido de detrás de la barra")
	check(_flat(rosa.global_position, detective) < 3.0, "y está cerca del inspector")
	check(_flat(rosa.global_position, ortega.global_position) >= LocationBase.NPC_SPACING, "sin pisarse entre ellos")
	for npc: Npc in [rosa, ortega]:
		check(game.current_location.is_standing_point(npc.global_position, 0.3), "%s está en suelo libre" % npc.npc_id)
		check(npc.visible, "%s se ve" % npc.npc_id)
		for height: float in [1.0, 1.6]:
			var point := game.camera.camera.unproject_position(npc.global_position + Vector3.UP * height)
			check(get_viewport().get_visible_rect().has_point(point), "%s queda dentro de la pantalla" % npc.npc_id)
			check(not _hidden_by_dialogue(point), "la interfaz de la conversación no tapa a %s (%s)" % [npc.npc_id, str(point.round())])


func test_both_stop_and_face_the_inspector() -> void:
	var rosa := game.current_location.get_npc("rosa")
	var ortega := game.current_location.get_npc("ortega")
	for npc: Npc in [rosa, ortega]:
		check_equal(npc.state, Npc.State.DIALOGUE, "%s se detiene durante la escena" % npc.npc_id)
		check(npc.is_in_scene(), "%s interviene en ella" % npc.npc_id)
		check(_faces(npc, game.player.global_position), "%s mira al inspector" % npc.npc_id)
	var rosa_at := rosa.global_position
	var ortega_at := ortega.global_position
	await wait_physics_frames(60)
	check(_flat(rosa.global_position, rosa_at) < 0.05 and _flat(ortega.global_position, ortega_at) < 0.05, "no se mueven mientras hablan")


## Gesticula sólo quien tiene la palabra, y el inspector se vuelve hacia quien le habla.
func test_speakers_take_turns() -> void:
	var rosa := game.current_location.get_npc("rosa")
	var ortega := game.current_location.get_npc("ortega")
	var lines: Array = GameData.scenes["llamada"]["lines"]
	check_equal(lines[0]["s"], "rosa", "la escena la abre Rosa")
	check(rosa.model.is_talking() and not ortega.model.is_talking(), "habla Rosa y el sargento escucha")
	check(_faces_model(game.player.model, game.player.global_position, rosa.global_position), "el inspector mira a Rosa")
	var index := 0
	while index < lines.size() - 1 and lines[index]["s"] != "ortega":
		DialogueManager.advance()
		index += 1
	await wait_physics_frames(2)
	check_equal(lines[index]["s"], "ortega", "después habla el sargento")
	check(ortega.model.is_talking() and not rosa.model.is_talking(), "ahora gesticula él y Rosa escucha")
	check(_faces_model(game.player.model, game.player.global_position, ortega.global_position), "el inspector se vuelve hacia el sargento")


## La escena ya no habla de un teléfono: el sargento está en la sala, y en la mansión no se vuelve
## a presentar.
func test_dialogue_matches_what_is_on_screen() -> void:
	var text := ""
	for line: Dictionary in GameData.scenes["llamada"]["lines"]:
		text += line["t"] + " "
	check(not text.contains("auricular"), "nadie tiende un auricular: el sargento está en persona")
	check(text.contains("Le espero allí"), "el sargento explica que se adelanta a la mansión")
	var intro: Dictionary = GameData.get_dialogue("ortega")["intro"][0]
	for line: Dictionary in intro["lines"]:
		check(not (line["t"] as String).contains("Soy el sargento"), "en la mansión no se presenta otra vez")


func test_after_the_scene_ortega_leaves_through_the_door() -> void:
	var rosa := game.current_location.get_npc("rosa")
	var ortega := game.current_location.get_npc("ortega")
	var minutes := GameClock.minutes
	_read_scene_to_the_end()
	check(not DialogueManager.active, "la escena termina")
	check(GameState.has_flag("llamada_atendida"), "y la llamada queda atendida")
	check_equal(GameClock.minutes, minutes + 10, "con sus diez minutos")
	check(game.current_location.get_npc("ortega") == ortega, "el sargento no desaparece al acabar")
	check(ortega.is_leaving(), "se va hacia la mansión")
	check(not ortega.interaction.can_interact(), "mientras se va no se le puede hablar")
	# Las lambdas copian las variables locales: la última posición va en un array compartido.
	var last: Array[Vector3] = [ortega.global_position]
	ortega.left.connect(func(npc: Npc) -> void: last[0] = npc.global_position)
	var biggest_step := 0.0
	var previous := ortega.global_position
	var bad_spots: Array[Vector3] = []
	var gone := false
	for frame in 900:
		await get_tree().physics_frame
		if not is_instance_valid(ortega) or game.current_location.get_npc("ortega") == null:
			gone = true
			break
		biggest_step = maxf(biggest_step, _flat(previous, ortega.global_position))
		previous = ortega.global_position
		if not ortega._exiting and frame % 10 == 0 and not game.current_location.is_standing_point(ortega.global_position, 0.22):
			bad_spots.append(ortega.global_position)
	check(gone, "al cruzar la puerta deja el café")
	check(biggest_step < 0.25, "camina, no salta (paso máximo %.2f m)" % biggest_step)
	check(bad_spots.is_empty(), "nunca atraviesa nada: %s" % str(bad_spots.slice(0, 3)))
	check(last[0].z > 5.6 and absf(last[0].x) < 1.1, "sale por el hueco de la puerta de la calle (%s)" % str(last[0].snapped(Vector3.ONE * 0.01)))
	check(rosa.state != Npc.State.DIALOGUE, "Rosa retoma lo suyo")
	check_equal(rosa.current_slot.get("marker", ""), "barra", "su sitio vuelve a ser la barra")
	var behind_the_bar := false
	for frame in 1500:
		await get_tree().physics_frame
		if rosa.global_position.z < -4.3 and not rosa.is_walking():
			behind_the_bar = true
			break
	check(behind_the_bar, "Rosa vuelve andando detrás de la barra (%s)" % str(rosa.global_position.snapped(Vector3.ONE * 0.01)))


## Volver al café no repite la escena ni trae al sargento; en la mansión hay un solo Ortega.
func test_later_visits_stay_coherent() -> void:
	_read_scene_to_the_end()
	await game.go_to("plaza", "desde_cafe")
	await game.go_to("cafe", "desde_plaza")
	check(not DialogueManager.active, "la escena de la llamada no se repite")
	check(game.current_location.get_npc("ortega") == null, "el sargento ya no está en el café")
	check(game.current_location.get_npc("rosa") != null, "Rosa sigue en su café")
	check_equal(game.current_location.get_npc("rosa").current_slot.get("marker", ""), "barra", "detrás de la barra")
	await game.go_to("plaza", "desde_cafe")
	await game.go_to("mansion", "desde_plaza")
	check(game.current_location.get_npc("ortega") != null, "Ortega espera en la mansión")
	check_equal(_count_in_tree("ortega"), 1, "un solo Ortega")
	var spoken: Array[String] = []
	var listener := func(_speaker: String, text: String) -> void: spoken.append(text)
	DialogueManager.line_shown.connect(listener)
	DialogueManager.start("ortega")
	for step in 4:
		DialogueManager.advance()
	DialogueManager.line_shown.disconnect(listener)
	check(spoken.size() >= 2, "la presentación completa sigue ahí (%d líneas)" % spoken.size())
	for line in spoken:
		check(not line.contains("Soy el sargento"), "no se presenta por segunda vez: «%s»" % line)
	check(GameState.has_flag("ortega_conocido"), "y queda marcada como siempre")


## Si la escena se cierra sin terminar (como en algunas pruebas), los dos siguen esperando hasta
## que la llamada se atiende.
func test_closing_early_keeps_them_until_the_call_is_answered() -> void:
	var ortega := game.current_location.get_npc("ortega")
	var rosa := game.current_location.get_npc("rosa")
	DialogueManager.close()
	await wait_physics_frames(2)
	check(not ortega.is_in_scene() and not rosa.is_in_scene(), "dejan la escena")
	check(not ortega.is_leaving(), "sin la llamada atendida el sargento sigue esperando")
	GameState.set_flag("llamada_atendida")
	await wait_physics_frames(2)
	check(ortega.is_leaving(), "al atenderla se va")
	check_equal(rosa.current_slot.get("marker", ""), "barra", "y Rosa vuelve a la barra")


## Guardar mientras el sargento sale y cargar después: no vuelve a aparecer en el café.
func test_saving_while_he_leaves_does_not_bring_him_back() -> void:
	TestCase.clear_save_storage()
	_read_scene_to_the_end()
	await wait_physics_frames(10)
	check(game.current_location.get_npc("ortega") != null and game.current_location.get_npc("ortega").is_leaving(), "el sargento se está yendo")
	check(await save_and_wait("manual_1"), "se guarda la partida")
	game.queue_free()
	game = null
	await get_tree().process_frame
	check(SaveSystem.request_load("manual_1")["ok"], "se prepara la carga")
	game = await make_game()
	await wait_physics_frames(30)
	check_equal(game.current_location.location_id, "cafe", "reanuda en el café")
	check(not DialogueManager.active, "sin repetir la escena")
	check(game.current_location.get_npc("ortega") == null, "sin el sargento")
	check(game.current_location.get_npc("rosa") != null, "con Rosa")
	TestCase.clear_save_storage()


func _read_scene_to_the_end() -> void:
	for step in 20:
		if not DialogueManager.active:
			return
		DialogueManager.advance()


## La interfaz de la conversación tapa la franja de abajo (la ventana) y los lados (las siluetas).
func _hidden_by_dialogue(point: Vector2) -> bool:
	var ui: DialogueUi = game.get_node("DialogueUi")
	var cast := ui.get_cast()
	for control: Control in [ui.get_dialogue_window(), cast.get_detective(), cast.get_portrait()]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false


## Copias vivas de un personaje en toda la escena (no sólo en la lista del escenario).
func _count_in_tree(npc_id: String) -> int:
	var count := 0
	for node in get_tree().root.find_children("Npc_%s" % npc_id, "", true, false):
		if node is Npc and not node.is_queued_for_deletion():
			count += 1
	return count


func _faces(npc: Npc, point: Vector3) -> bool:
	return _faces_model(npc.model, npc.global_position, point)


func _faces_model(model: Node3D, from: Vector3, point: Vector3) -> bool:
	var looking := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, model.rotation.y)
	var toward := point - from
	toward.y = 0.0
	return toward.length() > 0.01 and looking.dot(toward.normalized()) > 0.9


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
