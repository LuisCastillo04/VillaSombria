extends TestCase
## El mapa dentro del juego, manejado como lo haría el jugador: con la tecla M, desde la pausa, con
## Escape, las flechas y los clics. Comprueba que el marcador está donde está el detective al
## empezar, al caminar, al entrar y salir de un edificio, al cargar una partida y al cambiar el
## tamaño de la pantalla, y que el mapa no choca con la pausa ni con los demás paneles.

const SETTLE_SECONDS := 0.7

var game: Game
var pause: PauseMenu
var map: MapScreen
var view: TownMapView


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()
	await _start_game()


func after_each() -> void:
	await _free_game()
	SaveSystem.take_pending_load()
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()


func _start_game() -> void:
	game = await make_game()
	pause = game.get_node("PauseMenu")
	map = pause.get_node("Root/MapScreen")
	view = map.get_view()


func _free_game() -> void:
	if game == null:
		return
	if pause.is_open:
		pause.close()
	get_tree().paused = false
	game.queue_free()
	game = null
	await get_tree().process_frame


## Una pulsación tal como llega del teclado o del mando.
func _press(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	get_viewport().push_input(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	get_viewport().push_input(release)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_fade() -> void:
	await _wait(MenuScreen.FADE_SECONDS + 0.1)


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


## Dónde debería estar el marcador según la posición real del detective ahora mismo.
func _expected_fix() -> Dictionary:
	return TownMap.locate(GameState.location_id, game.player.global_position, game.player.model.rotation.y)


func _marker_matches_player(context: String) -> void:
	var expected := _expected_fix()
	var marker := view.get_marker()
	check(bool(expected["known"]), "%s: el lugar figura en el mapa" % context)
	check(marker.visible, "%s: el marcador se ve" % context)
	check(marker.target_point.distance_to(expected["map_point"]) < 0.5, "%s: el marcador está donde el detective (%s, esperado %s)" % [context, marker.target_point, expected["map_point"]])
	check(marker.position.distance_to(view.map_to_local(expected["map_point"])) < 1.0, "%s: y se dibuja en ese punto de la pantalla" % context)
	check(view.get_parchment_rect().has_point(marker.position), "%s: dentro del pergamino" % context)


func _open_with_key() -> void:
	_press("open_map")
	await _wait_fade()


func test_new_game_shows_the_inspector_on_the_platform() -> void:
	await _open_with_key()
	check(map.is_open(), "M abre el mapa")
	check(pause.is_open and get_tree().paused, "con el juego en pausa detrás")
	check(GameState.is_player_locked(), "y el detective quieto")
	check(not pause.get_node("Root/Center/Panel").visible, "sin las opciones de la pausa")
	_marker_matches_player("al empezar")
	check_equal(view.get_fix()["place_id"], "estacion", "llega a la estación")
	check(bool(view.get_fix()["precise"]), "con su posición exacta en el andén")
	check(_focus_owner() == view.get_pin("estacion"), "el foco empieza en la chincheta del lugar actual")
	check_equal(map.get_place_card()[0], "Estación de tren", "la ficha muestra el lugar actual")


func test_marker_follows_the_inspector_across_the_plaza() -> void:
	await game.go_to("plaza", "desde_cafe")
	# Caminar de verdad, con el mismo sistema de movimiento que el jugador. En diagonal hacia la
	# plaza abierta: hacia el este, la terraza del café tiene mesas y taburetes sólidos.
	var start := game.player.global_position
	Input.action_press("move_back")
	await wait_physics_frames(45)
	Input.action_release("move_back")
	await wait_physics_frames(10)
	check(game.player.global_position.distance_to(start) > 2.0, "el detective se ha movido por la plaza")
	await _open_with_key()
	_marker_matches_player("tras caminar")
	_press("open_map")
	await _wait_fade()
	# De un extremo a otro de la plaza: el marcador recorre la distancia proporcional.
	game.player.teleport(Vector3(-7.0, 0.1, 3.0), 0.0)
	await _open_with_key()
	var west := view.get_marker().position
	_press("ui_cancel")
	await _wait_fade()
	game.player.teleport(Vector3(14.0, 0.1, 3.0), 0.0)
	await _open_with_key()
	var east := view.get_marker().position
	var region := TownMap.get_region("plaza")
	var expected := view.get_fit_transform().basis_xform(region.transform.basis_xform(Vector2(21.0, 0.0)))
	check((east - west).distance_to(expected) < 1.5, "cruzar la plaza mueve el marcador en proporción (%s, esperado %s)" % [east - west, expected])


func test_marker_glides_while_the_position_changes_with_the_map_open() -> void:
	await game.go_to("plaza", "inicio")
	await _open_with_key()
	var before := view.get_marker().position
	game.player.teleport(game.player.global_position + Vector3(3.0, 0.0, 0.0), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var during := view.get_marker().position
	var goal := view.map_to_local(_expected_fix()["map_point"])
	check(during.distance_to(before) > 0.5 and during.distance_to(goal) > 0.5, "se desliza en lugar de saltar")
	await _wait(SETTLE_SECONDS)
	check(view.get_marker().position.distance_to(goal) < 1.0, "y alcanza la posición real en menos de un segundo")


func test_entering_and_leaving_a_building() -> void:
	await game.go_to("archivo", "desde_plaza")
	await _open_with_key()
	var fix := view.get_fix()
	check_equal(fix["place_id"], "archivo", "dentro del archivo, el mapa lo sabe")
	check(not bool(fix["precise"]), "sin inventar una posición dentro del edificio")
	check(view.get_marker().position.distance_to(view.map_to_local(TownMap.get_place_point(TownMap.get_place("archivo")))) < 1.0, "el marcador señala el edificio")
	check(map.get_place_card()[1].begins_with("Estás dentro"), "la ficha lo explica")
	_press("open_map")
	await _wait_fade()
	await game.go_to("plaza", "desde_archivo")
	await _open_with_key()
	_marker_matches_player("al salir del archivo")
	check(bool(view.get_fix()["precise"]), "fuera vuelve la posición exacta")
	var door := TownMap.get_region("plaza").world_to_map(Vector2(9.5, -12.8))
	check(view.get_fix()["map_point"].distance_to(door) < 2.0 * 12.0, "delante de la puerta del archivo")


func test_changing_scenery_and_coming_back() -> void:
	await game.go_to("plaza", "desde_estacion")
	await _open_with_key()
	_marker_matches_player("en la plaza")
	_press("ui_cancel")
	await _wait_fade()
	await game.go_to("estacion", "desde_plaza")
	await _open_with_key()
	_marker_matches_player("de vuelta en la estación")
	check_equal(view.get_fix()["region_id"], "estacion", "en la zona de la estación")


func test_loaded_game_shows_the_restored_position() -> void:
	await game.go_to("plaza", "desde_cafe")
	game.player.teleport(Vector3(12.0, 0.1, 6.0), 2.0)
	await wait_physics_frames(2)
	var saved_at := game.player.global_position
	check(await save_and_wait("manual_1"), "se guarda la partida")
	await _free_game()
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	check(SaveSystem.request_load("manual_1")["ok"], "se prepara la carga")
	await _start_game()
	await _open_with_key()
	var expected := TownMap.locate("plaza", saved_at, 2.0)
	check(view.get_marker().target_point.distance_to(expected["map_point"]) < 0.5, "el marcador está en la posición guardada")
	_marker_matches_player("tras cargar")
	check_equal(TownMap.get_visited_ids(), PackedStringArray(["estacion", "plaza"]), "y se recuperan los lugares visitados")


func test_opening_and_closing_repeatedly_is_stable() -> void:
	var pins := view.get_node("Pins").get_child_count()
	for round_index in 6:
		_press("open_map")
		if round_index % 2 == 0:
			await _wait_fade()
		check(map.is_open(), "ronda %d: se abre" % round_index)
		_press("open_map" if round_index % 3 == 0 else "ui_cancel")
		if round_index % 2 == 1:
			await _wait_fade()
		check(not map.is_open(), "ronda %d: se cierra" % round_index)
		check(not pause.is_open and not get_tree().paused, "ronda %d: vuelve al juego" % round_index)
		check(not GameState.is_player_locked(), "ronda %d: con el control devuelto" % round_index)
	await _wait_fade()
	check_equal(view.get_node("Pins").get_child_count(), pins, "no se duplican chinchetas")
	check_equal(pause.get_node("Root").get_children().filter(func(node: Node) -> bool: return node is MapScreen).size(), 1, "ni pantallas de mapa")
	check(not map.visible, "al final queda oculto")


func test_markers_stay_aligned_at_any_size() -> void:
	await game.go_to("plaza", "inicio")
	await _open_with_key()
	var canvas := TownMap.canvas_size
	for screen: Vector2 in [Vector2(1920.0, 1080.0), Vector2(2560.0, 1080.0), Vector2(1920.0, 1440.0), Vector2(3840.0, 2160.0)]:
		map.size = screen
		await get_tree().process_frame
		await get_tree().process_frame
		var parchment := view.get_parchment_rect()
		check(absf(parchment.size.x / parchment.size.y - canvas.x / canvas.y) < 0.01, "%s: el mapa no se deforma" % screen)
		var frame := map.get_node("%Frame") as Control
		check(Rect2(Vector2.ZERO, screen).encloses(frame.get_global_rect().grow(-1.0)), "%s: el marco cabe en la pantalla" % screen)
		check(Rect2(Vector2.ZERO, screen).encloses(map.get_back_button().get_global_rect()), "%s: «Volver» se ve entero" % screen)
		_marker_matches_player("a %s" % screen)
		for pin in view.get_visible_pins():
			var tip := pin.position + pin.get_tip_offset()
			var place_point := TownMap.get_place_point(TownMap.get_place(pin.place_id))
			check(tip.distance_to(view.map_to_local(place_point)) < 1.0, "%s: la chincheta de %s sigue en su sitio" % [screen, pin.place_id])
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func test_map_respects_the_other_game_states() -> void:
	# Con un panel abierto o en una conversación, M no hace nada.
	var journal: JournalUi = game.get_node("JournalUi")
	journal.open()
	_press("open_map")
	check(not map.is_open() and journal.is_open, "con el expediente abierto, M no abre el mapa")
	journal.close()
	GameState.lock_player("dialogo")
	_press("open_map")
	check(not map.is_open(), "durante una conversación tampoco")
	GameState.unlock_player("dialogo")
	# Desde la pausa: la opción «Mapa» y la propia tecla; al cerrar se vuelve a la pausa.
	pause.open()
	var map_button: MenuOptionButton = pause.get_node("Root/Center/Panel/Box/Map")
	map_button.pressed.emit()
	check(map.is_open(), "la opción «Mapa» lo abre")
	check(not pause.get_node("Root/Center/Panel").visible, "en lugar de las opciones")
	_press("ui_cancel")
	check(not map.is_open(), "Escape lo cierra")
	check(pause.is_open and get_tree().paused, "sin salir de la pausa")
	check(_focus_owner() == map_button, "con el foco en «Mapa»")
	_press("open_map")
	check(map.is_open(), "M también lo abre desde la pausa")
	_press("open_map")
	check(not map.is_open() and pause.is_open, "y vuelve a la pausa al cerrarlo")
	pause.close()
	# Con el mapa abierto el detective no se mueve aunque se pulsen las direcciones.
	await _open_with_key()
	var still := game.player.global_position
	Input.action_press("move_right")
	await _wait(0.3)
	Input.action_release("move_right")
	check(game.player.global_position.distance_to(still) < 0.01, "el detective no camina con el mapa abierto")
	_press("pause")
	check(not map.is_open() and not get_tree().paused, "Esc cierra el mapa y vuelve directamente al juego")


func test_unmapped_scenery_hides_the_marker() -> void:
	await game.go_to("test_ground", "inicio")
	await _open_with_key()
	check(not view.get_marker().visible, "sin lugar en el mapa no hay marcador")
	check(not bool(view.get_fix()["known"]), "ni posición")
	check_equal(map.get_place_card()[0], "Fuera del mapa", "la ficha lo explica")
	check(_focus_owner() == map.get_back_button(), "el foco empieza en «Volver»")
	_press("ui_up")
	check(_focus_owner() is MapPlacePin, "y desde ahí se puede subir a las chinchetas")


func test_objectives_and_places_in_the_side_panel() -> void:
	await _open_with_key()
	check(view.get_pin("cafe").objective, "el café lleva el rombo de objetivo")
	for place_id: String in ["plaza", "archivo", "mansion", "estacion"]:
		check(not view.get_pin(place_id).objective, "%s no tiene objetivo pendiente" % place_id)
	check_equal(map.get_objective_texts(), PackedStringArray([StoryDirector.get_objectives()[0]["text"]]), "el panel muestra el objetivo real de la historia")
	_press("ui_cancel")
	await _wait_fade()
	GameState.set_flag("llamada_atendida")
	await _open_with_key()
	check(view.get_pin("mansion").objective and not view.get_pin("cafe").objective, "al avanzar, el rombo pasa a la mansión")
	check(map.get_objective_texts()[0].begins_with("Ve a la mansión"), "y el texto cambia con él")


func test_pins_work_with_keyboard_mouse_and_selection() -> void:
	await _open_with_key()
	var visible_pins := view.get_visible_pins()
	check_equal(visible_pins.size(), 5, "los cinco lugares reales tienen chincheta")
	# Con las flechas se llega a todas las chinchetas y a «Volver».
	var reached := {}
	var pending: Array[Control] = [_focus_owner()]
	while not pending.is_empty():
		var current: Control = pending.pop_back()
		if reached.has(current):
			continue
		reached[current] = true
		for property: String in ["focus_neighbor_top", "focus_neighbor_bottom", "focus_neighbor_left", "focus_neighbor_right"]:
			var path: NodePath = current.get(property)
			if path.is_empty():
				continue
			var neighbor := current.get_node_or_null(path) as Control
			if neighbor != null and neighbor.focus_mode != Control.FOCUS_NONE:
				pending.append(neighbor)
	for pin in visible_pins:
		check(reached.has(pin), "se llega a %s con las flechas" % pin.place_id)
	check(reached.has(map.get_back_button()), "y a «Volver»")
	# Las flechas mueven el foco de verdad.
	view.get_pin("plaza").grab_focus()
	_press("ui_up")
	check(_focus_owner() is MapPlacePin and _focus_owner() != view.get_pin("plaza"), "arriba pasa a otra chincheta")
	map.get_back_button().grab_focus()
	_press("ui_up")
	check(_focus_owner() is MapPlacePin, "desde «Volver», arriba vuelve al mapa")
	# Intro selecciona la chincheta señalada y la ficha muestra ese lugar.
	view.get_pin("mansion").grab_focus()
	check_equal(map.get_place_card()[0], "Mansión Valdés", "al señalarla, la ficha muestra el lugar")
	_press("ui_accept")
	check_equal(map.get_selected_place(), "mansion", "Intro la selecciona")
	check(view.get_pin("mansion").selected and not view.get_pin("cafe").selected, "sólo ella queda marcada")
	# Un clic (o un toque) en otra chincheta cambia la selección.
	var cafe := view.get_pin("cafe")
	var spot := cafe.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		get_viewport().push_input(click, true)
	check_equal(map.get_selected_place(), "cafe", "un clic selecciona el café")
	check(map.get_place_card()[1].contains("Pendiente"), "y su ficha recuerda el objetivo pendiente")
	map.get_back_button().pressed.emit()
	check(not map.is_open(), "«Volver» cierra el mapa")


func test_controls_screen_lists_the_map_key() -> void:
	var controls: ControlsMenu = pause.get_node("Root/ControlsMenu")
	controls.refresh()
	var row := controls.find_row("Abrir o cerrar el mapa")
	check(row != null, "la pantalla de controles incluye el mapa")
	if row != null:
		var groups: Array = []
		for group in row.get_key_groups():
			groups.append(Array(group))
		check_equal(groups, [["M"]], "con su tecla real del InputMap")
