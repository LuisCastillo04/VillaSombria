extends TestCase
## El HUD de exploración con los sistemas reales. Lo que muestra (lugar, fecha, objetivo, teclas)
## sale del juego y se pone al día solo; la barra lee el InputMap, es contextual y se adapta al ancho;
## el HUD se retira en conversaciones, transiciones y pausa y vuelve después; cabe en pantallas de
## distintas proporciones; y nunca recibe el ratón ni el foco.

const REVEAL_SECONDS := Hud.FIRST_REVEAL_DELAY + HudStyle.FADE_IN + 0.2
const FADE_SECONDS := HudStyle.FADE_IN + 0.2
const ESSENTIAL_HINTS: Array[String] = ["move", "interact", "pause"]

var game: Game
var hud: Hud


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()
	game = await make_game()
	hud = game.get_node("Hud")


func after_each() -> void:
	await _free_game()
	SaveSystem.take_pending_load()
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()


func _free_game() -> void:
	if game == null:
		return
	if DialogueManager.active:
		DialogueManager.close()
	var pause: PauseMenu = game.get_node("PauseMenu")
	if pause.is_open:
		pause.close()
	get_tree().paused = false
	game.queue_free()
	game = null
	hud = null
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _first_pending_objective() -> String:
	for objective in StoryDirector.get_objectives():
		if not bool(objective["done"]):
			return objective["text"]
	return ""


static func _controls_in(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in node.get_children(true):
		if child is Control:
			found.append(child as Control)
		found.append_array(_controls_in(child))
	return found


# --- Datos reales ---

func test_every_place_has_an_existing_icon() -> void:
	for location_id: String in GameData.locations:
		var icon_name := HudInfo.location_icon(location_id)
		check(not icon_name.is_empty(), "lugar sin icono en locations.json: " + location_id)
		check(ResourceLoader.exists(CaseFileStyle.ICONS % icon_name), "el icono de %s no existe: %s" % [location_id, icon_name])
	check(HudStyle.icon("icono_que_no_existe") != null, "un icono desconocido cae en el de reserva")


func test_panels_show_the_real_place_date_and_objective() -> void:
	await _wait(REVEAL_SECONDS)
	check(hud.is_exploration_shown(), "al empezar a explorar, el HUD aparece")
	var location := hud.get_location_panel()
	check_equal(location.get_title(), GameData.locations[GameState.location_id]["name"], "nombre del escenario")
	check_equal(location.get_icon_name(), "tren", "icono de la estación")
	var expected_date := "%s — %s" % [StoryDirector.get_day_title(), GameClock.format_time()]
	check_equal(location.get_date(), expected_date, "fecha y hora del reloj narrativo")
	check_equal(hud.get_objective_panel().get_objective(), _first_pending_objective(), "objetivo pendiente de StoryDirector")


func test_time_and_objectives_follow_the_story() -> void:
	await _wait(REVEAL_SECONDS)
	GameClock.advance(45)
	check(hud.get_location_panel().get_date().ends_with("08:45"), "la hora avanza con el reloj: " + hud.get_location_panel().get_date())
	var before := hud.get_objective_panel().get_objective()
	GameState.set_flag("llamada_atendida")
	var after := hud.get_objective_panel().get_objective()
	check(after != before, "al cumplir el objetivo aparece el siguiente")
	check_equal(after, _first_pending_objective(), "el siguiente es el que dice StoryDirector")
	check(hud.get_objective_panel().is_flashing(), "un objetivo nuevo hace destellar la cinta")


func test_new_day_updates_the_date() -> void:
	await _wait(REVEAL_SECONDS)
	GameClock.start_next_day()
	check(hud.get_location_panel().get_date().begins_with(GameData.story["days"]["2"]["title"]), "fecha del segundo día")


# --- Aparición y desaparición ---

func test_changing_place_hides_and_brings_back_the_hud() -> void:
	await _wait(REVEAL_SECONDS)
	game.go_to("plaza", "")
	await _wait(0.15)
	check(not hud.is_exploration_shown(), "durante la transición el HUD se retira")
	await _wait(1.0 + FADE_SECONDS)
	check(hud.is_exploration_shown(), "tras la transición el HUD vuelve")
	check_equal(hud.get_location_panel().get_title(), "Plaza Mayor", "nombre del nuevo lugar")
	check_equal(hud.get_location_panel().get_icon_name(), "fuente", "icono del nuevo lugar")


func test_dialogue_hides_the_hud_and_announces_objectives_on_return() -> void:
	await _wait(REVEAL_SECONDS)
	DialogueManager.start("ortega")
	await get_tree().process_frame
	await get_tree().process_frame
	check(not hud.is_exploration_shown(), "en una conversación el HUD se retira")
	GameState.set_flag("llamada_atendida")
	EventBus.notification_requested.emit("Pista registrada", "Una prueba", "pista")
	check(not hud.get_toasts().is_empty(), "los avisos se siguen mostrando durante la conversación")
	DialogueManager.close()
	await _wait(FADE_SECONDS)
	check(hud.is_exploration_shown(), "al terminar la conversación el HUD vuelve")
	check(hud.get_objective_panel().is_flashing(), "el objetivo que cambió durante la conversación se anuncia al volver")


func test_pause_hides_the_hud_behind_its_screens() -> void:
	await _wait(REVEAL_SECONDS)
	var pause: PauseMenu = game.get_node("PauseMenu")
	pause.open()
	await _wait(FADE_SECONDS)
	check(not hud.is_exploration_shown(), "con la pausa el HUD se retira")
	check(not (hud.get_node("Root/Exploration") as Control).visible, "el fundido termina aunque el juego esté en pausa")
	pause.close()
	await _wait(FADE_SECONDS)
	check(hud.is_exploration_shown(), "al continuar el HUD vuelve")
	pause.open_map()
	await _wait(FADE_SECONDS)
	check(not (hud.get_node("Root/Exploration") as Control).visible, "el mapa abierto con su tecla no tiene el HUD detrás")


func test_lock_signal_fires_only_when_the_locks_change() -> void:
	var count: Array[int] = [0]
	var counter := func() -> void: count[0] += 1
	EventBus.player_locks_changed.connect(counter)
	GameState.lock_player("prueba")
	GameState.lock_player("prueba")
	GameState.unlock_player("prueba")
	GameState.unlock_player("prueba")
	GameState.clear_player_locks()
	EventBus.player_locks_changed.disconnect(counter)
	check_equal(count[0], 2, "una señal al bloquear y otra al desbloquear")


# --- Barra de teclas ---

func test_controls_bar_shows_the_input_map() -> void:
	var bar := hud.get_controls_bar()
	for definition: Dictionary in HudInfo.CONTROL_HINTS:
		var hint := bar.get_hint(definition["id"])
		check(hint != null, "falta la entrada " + definition["id"])
		if hint == null:
			continue
		check_equal(hint.get_keys(), HudInfo.hint_keys(definition), "teclas de " + definition["id"])
		check_equal(hint.get_label_text(), definition["label"], "texto de " + definition["id"])
	check_equal(bar.get_hint("move").get_cap_texts(), PackedStringArray(["WASD"]), "las cuatro direcciones en un recuadro")
	check_equal(bar.get_hint("map").get_keys()[0], InputLabels.keys_of("open_map")[0], "la tecla real del mapa")
	check_equal(bar.get_hint("pause").get_keys()[0], "Esc", "la pausa con su nombre en castellano")


func test_controls_bar_follows_a_changed_binding() -> void:
	var bar := hud.get_controls_bar()
	var original := InputMap.action_get_events("open_map")
	InputMap.action_erase_events("open_map")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	InputMap.action_add_event("open_map", key)
	hud.refresh_controls()
	var hint := bar.get_hint("map")
	check(hint != null and hint.get_keys() == PackedStringArray(["K"]), "la barra muestra la tecla nueva")
	InputMap.action_erase_events("open_map")
	hud.refresh_controls()
	check(bar.get_hint("map") == null, "una acción sin tecla no aparece en la barra")
	for event in original:
		InputMap.action_add_event("open_map", event)
	hud.refresh_controls()
	check(bar.get_hint("map") != null, "al recuperar la tecla vuelve la entrada")


func test_controls_bar_reacts_to_the_game_state() -> void:
	await _wait(REVEAL_SECONDS)
	var bar := hud.get_controls_bar()
	var prompt := hud.get_prompt()
	EventBus.interaction_focus_changed.emit("Hablar con Ortega")
	check(bar.get_hint("interact").is_lit(), "con algo al alcance se enciende la tecla de interactuar")
	check_equal(prompt.get_text(), "Hablar con Ortega", "texto del aviso")
	check_equal(prompt.get_key(), InputLabels.keys_of("interact")[0], "tecla real en el aviso")
	EventBus.interaction_focus_changed.emit("")
	check(not bar.get_hint("interact").is_lit(), "sin nada al alcance se apaga")
	check(not prompt.is_shown(), "y el aviso desaparece")
	check(not bar.get_hint("wait").is_dimmed(), "por la mañana se puede esperar")
	GameClock.minutes = GameClock.DAY_LIMIT - 1
	GameClock.advance(1)
	check(bar.get_hint("wait").is_dimmed(), "en el tope del reloj la tecla de esperar se apaga")


func test_controls_bar_compacts_and_keeps_the_essentials() -> void:
	var bar := hud.get_controls_bar()
	var all_hints := bar.get_hints().size()
	bar.fit_width(HudStyle.BAR_MAX_WIDTH)
	check(not bar.is_compact(), "a lo ancho, tamaño normal")
	check_equal(bar.get_visible_hint_ids().size(), all_hints, "a lo ancho caben todas las teclas")
	for width: float in [1250.0, 900.0, 640.0]:
		bar.fit_width(width)
		check(bar.get_combined_minimum_size().x <= width, "la barra cabe en %d px" % int(width))
		var shown := bar.get_visible_hint_ids()
		for hint_id in ESSENTIAL_HINTS:
			check(shown.has(hint_id), "%s se ve con %d px" % [hint_id, int(width)])
		for hint in bar.get_hints():
			if not shown.has(hint.hint_id):
				check(int(hint.get_meta("priority")) > 0, "sólo se ocultan teclas secundarias")
	check(bar.is_compact(), "con poco ancho, versión compacta")
	bar.fit_width(HudStyle.BAR_MAX_WIDTH)
	check_equal(bar.get_visible_hint_ids().size(), all_hints, "al volver a ensanchar reaparecen todas")


# --- Diseño adaptable ---

func test_layout_fits_every_screen_shape() -> void:
	await _wait(REVEAL_SECONDS)
	EventBus.interaction_focus_changed.emit("Salir a la plaza")
	EventBus.notification_requested.emit("Pista registrada", "Una prueba", "pista")
	var root: Control = hud.get_node("Root")
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# 16:9 (lo mismo a 1280 × 720, 1366 × 768, 1600 × 900 o 1920 × 1080), 4:3, 5:4, 16:10 y 21:9.
	for view: Vector2 in [Vector2(1920, 1080), Vector2(1440, 1080), Vector2(1350, 1080), Vector2(1920, 1200), Vector2(2560, 1080)]:
		root.size = view
		await get_tree().process_frame
		await get_tree().process_frame
		var screen := Rect2(Vector2.ZERO, view)
		var location := hud.get_location_panel().get_rect()
		var objective := hud.get_objective_panel().get_rect()
		var bar := hud.get_controls_bar().get_rect()
		var prompt := hud.get_prompt().get_rect()
		var toasts: Control = hud.get_node("Root/Toasts")
		var label := "%dx%d" % [int(view.x), int(view.y)]
		for rect: Rect2 in [location, objective, bar, prompt]:
			check(screen.encloses(rect), "%s: una pieza se sale de la pantalla %s" % [label, rect])
		check(not location.intersects(objective), label + ": el lugar y el objetivo no se pisan")
		check(prompt.end.y <= bar.position.y, label + ": el aviso queda sobre la barra")
		check(toasts.position.y >= objective.end.y, label + ": los avisos van bajo el objetivo")
		check(hud.get_controls_bar().get_combined_minimum_size().x <= bar.size.x + 0.5, label + ": las teclas caben en la barra")
		check(hud.get_objective_panel().is_text_complete(), label + ": el objetivo se lee entero")
		check(bar.size.x <= HudStyle.BAR_MAX_WIDTH + 0.5, label + ": la barra no pasa del ancho 16:9")
		check(is_equal_approx(location.position.x, bar.position.x), label + ": el lugar y la barra comparten borde izquierdo")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func test_long_place_names_shrink_instead_of_overflowing() -> void:
	var panel := hud.get_location_panel()
	panel.set_location("Antigua estación de ferrocarril del norte de Villa Sombría", "tren", false)
	await get_tree().process_frame
	check(panel.get_title_font_size() < HudStyle.TITLE_SIZE, "un nombre largo reduce la letra")
	check(panel.get_title_font_size() >= HudStyle.TITLE_MIN_SIZE, "sin bajar del mínimo legible")
	check(panel.get_combined_minimum_size().x <= HudStyle.LOCATION_TEXT_MAX + 180.0, "el panel no crece sin límite")


func test_longest_objective_is_read_in_full() -> void:
	var longest := ""
	for objective: Dictionary in GameData.story["objectives"]:
		if String(objective["text"]).length() > longest.length():
			longest = objective["text"]
	var panel := hud.get_objective_panel()
	# Con el HUD todavía oculto, como cuando el objetivo cambia en mitad de una conversación.
	panel.set_objective(longest, false)
	await _wait(REVEAL_SECONDS)
	check(panel.get_line_count() >= 3, "el objetivo más largo se parte en varias líneas")
	check(panel.is_text_complete(), "al aparecer el HUD se lee entero, sin líneas ocultas")
	# Y con el HUD a la vista: de un objetivo corto a uno largo.
	panel.set_objective("Descansa", false)
	await get_tree().process_frame
	await get_tree().process_frame
	panel.set_objective(longest, false)
	await get_tree().process_frame
	await get_tree().process_frame
	check(panel.is_text_complete(), "con el HUD visible el panel crece con el texto")


# --- Convivencia con el resto del juego ---

func test_hud_never_takes_the_mouse_or_the_focus() -> void:
	EventBus.notification_requested.emit("Pista registrada", "Una prueba", "pista")
	EventBus.interaction_focus_changed.emit("Hablar con Ortega")
	await get_tree().process_frame
	for control in _controls_in(hud):
		check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "recibe el ratón: %s" % hud.get_path_to(control))
		check(control.focus_mode == Control.FOCUS_NONE, "puede tomar el foco: %s" % hud.get_path_to(control))


func test_layers_keep_the_hud_below_full_screen_interfaces() -> void:
	for node_name: String in ["DialogueUi", "ClueInspector", "JournalUi", "BoardUi", "AccusationUi", "PauseMenu", "CaseClosedUi", "ScreenFade"]:
		var layer: CanvasLayer = game.get_node(node_name)
		check(layer.layer > hud.layer, "%s queda por encima del HUD" % node_name)


func test_notifications_never_pile_up() -> void:
	for index in 7:
		EventBus.notification_requested.emit("Pista %d" % index, "Detalle", "pista")
	var toasts := hud.get_toasts()
	check(toasts.size() <= HudStyle.TOAST_LIMIT, "como mucho %d avisos a la vez" % HudStyle.TOAST_LIMIT)
	check_equal(toasts[-1].get_title(), "Pista 6", "el último aviso es el más reciente")


func test_save_indicator_moves_above_the_bar_while_exploring() -> void:
	check(SaveIndicator.get_bottom_margin() >= HudStyle.BOTTOM_MARGIN + HudStyle.BAR_HEIGHT, "el aviso de guardado no tapa la barra")
	await _free_game()
	check_equal(SaveIndicator.get_bottom_margin(), SaveIndicator.DEFAULT_MARGIN, "fuera del juego vuelve a su esquina")
