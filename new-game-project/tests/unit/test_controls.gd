extends TestCase
## Teclas del jugador: las de fábrica salen de project.godot, los cambios llegan al InputMap sin tocar
## el mando, los conflictos se detectan y se resuelven intercambiando, ninguna acción se queda sin
## tecla, las teclas fijas de los menús no se pueden quitar y todo se guarda en `ajustes.cfg` (aparte
## de las partidas) y se recupera al volver a abrir el juego.


func before_each() -> void:
	Controls.restore_defaults()


func after_each() -> void:
	Controls.restore_defaults()


static func _key_codes(action: String) -> Array[Key]:
	var codes: Array[Key] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			codes.append(InputBindings.code_of(event))
	return codes


static func _joypad_events(action: String) -> int:
	var count := 0
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			count += 1
	return count


func test_defaults_come_from_the_project_input_map() -> void:
	check_equal(InputBindings.default_keys("move_forward"), [KEY_W, KEY_UP] as Array[Key], "avanzar: W y ↑, como en project.godot")
	check_equal(InputBindings.default_keys("interact"), [KEY_E] as Array[Key], "interactuar: E")
	check_equal(InputBindings.default_keys("open_journal"), [KEY_J, KEY_TAB] as Array[Key], "expediente: J y Tab")
	check_equal(InputBindings.default_keys("sprint"), [KEY_SHIFT] as Array[Key], "correr: Mayús")
	for action in InputBindings.action_ids():
		check(InputMap.has_action(action), "%s existe en el InputMap" % action)
		check_equal(Controls.get_keys(action), _key_codes(action), "%s: lo vigente es lo del InputMap" % action)
		check(not Controls.is_customized(action), "%s empieza sin personalizar" % action)
	check_equal(InputBindings.validate_map(InputBindings.defaults()), "", "las teclas de fábrica son un juego válido")


func test_every_input_map_action_of_the_game_is_rebindable_or_fixed() -> void:
	# Ninguna acción propia del juego queda fuera: o se reasigna o es una tecla fija de los menús.
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		check(InputBindings.has_action(action) or InputBindings.RESERVED_ACTIONS.has(action),
			"la acción %s es reasignable o fija" % action)


func test_assign_changes_the_input_map_and_keeps_the_gamepad() -> void:
	var pad_before := _joypad_events("interact")
	check(Controls.assign("interact", 0, KEY_F), "se acepta F para interactuar")
	check_equal(_key_codes("interact"), [KEY_F] as Array[Key], "el InputMap usa F")
	check_equal(_joypad_events("interact"), pad_before, "los botones del mando siguen")
	check(Controls.is_customized("interact"), "queda personalizada")
	check_equal(Controls.customized_actions(), PackedStringArray(["interact"]), "y es la única")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_F
	press.pressed = true
	check(press.is_action_pressed("interact"), "pulsar F es interactuar")
	press.physical_keycode = KEY_E
	check(not press.is_action_pressed("interact"), "y E ya no")


func test_an_alternative_can_be_added_and_removed() -> void:
	check(Controls.assign("interact", 1, KEY_R), "se añade R como alternativa")
	check_equal(Controls.get_keys("interact"), [KEY_E, KEY_R] as Array[Key], "E principal y R alternativa")
	check(Controls.clear_slot("interact", 1), "la alternativa se quita")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "queda sólo E")
	check(not Controls.clear_slot("interact", 0), "la principal no se puede quitar")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "y sigue E")


func test_bindings_changed_reports_the_actions() -> void:
	var seen: Array = []
	Controls.bindings_changed.connect(func(actions: PackedStringArray) -> void: seen.append(actions))
	Controls.assign("wait_time", 0, KEY_Y)
	check_equal(seen.size(), 1, "un aviso por cambio")
	check_equal(seen[0] if not seen.is_empty() else PackedStringArray(), PackedStringArray(["wait_time"]), "con la acción cambiada")
	Controls.assign("wait_time", 0, KEY_Y)
	check_equal(seen.size(), 1, "repetir la misma tecla no avisa")


func test_a_key_of_another_action_is_a_conflict() -> void:
	var outcome := Controls.check("open_map", 0, KEY_E)
	check_equal(outcome["result"], "conflict", "E ya es de interactuar")
	check_equal(outcome.get("action"), "interact", "dice qué acción la usa")
	check(outcome.get("swap_ok", false), "y que se pueden intercambiar")
	check(not Controls.assign("open_map", 0, KEY_E), "assign no pisa a la otra acción")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "interactuar conserva E")


func test_swapping_resolves_the_conflict() -> void:
	check(Controls.swap("open_map", 0, KEY_E), "se intercambian")
	check_equal(Controls.get_keys("open_map"), [KEY_E] as Array[Key], "el mapa pasa a E")
	check_equal(Controls.get_keys("interact"), [KEY_M] as Array[Key], "e interactuar recibe M")
	check_equal(InputBindings.validate_map(_current_map()), "", "sin teclas repetidas")


func test_a_swap_never_leaves_an_action_without_keys() -> void:
	# La alternativa del tablero está vacía: darle la E dejaría a interactuar sin nada.
	var outcome := Controls.check("open_board", 1, KEY_E)
	check_equal(outcome["result"], "conflict", "E es de interactuar")
	check(not outcome["swap_ok"], "no se puede intercambiar")
	check(not Controls.swap("open_board", 1, KEY_E), "y swap lo rechaza")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "interactuar sigue con E")
	# En cambio, quitarle la alternativa a otra acción sí se puede: conserva la principal.
	check(Controls.swap("open_board", 1, KEY_TAB), "Tab pasa del expediente al tablero")
	check_equal(Controls.get_keys("open_journal"), [KEY_J] as Array[Key], "el expediente se queda con J")
	check_equal(Controls.get_keys("open_board"), [KEY_B, KEY_TAB] as Array[Key], "y el tablero tiene B y Tab")


func test_the_other_key_of_the_same_action_reorders() -> void:
	check_equal(Controls.check("move_forward", 0, KEY_UP)["result"], "reorder", "↑ ya es la alternativa de avanzar")
	check(Controls.assign("move_forward", 0, KEY_UP), "se intercambian los huecos")
	check_equal(Controls.get_keys("move_forward"), [KEY_UP, KEY_W] as Array[Key], "↑ principal y W alternativa")
	check_equal(Controls.check("interact", 1, KEY_E)["result"], "unchanged", "la principal como alternativa no cambia nada")


func test_fixed_and_system_keys_are_refused() -> void:
	for code: Key in [KEY_ESCAPE, KEY_1, KEY_KP_5]:
		var outcome := Controls.check("interact", 0, code)
		check_equal(outcome["result"], "blocked", "%s está reservada" % OS.get_keycode_string(code))
		check_equal(outcome.get("reason"), "reservada", "por el juego")
	for code: Key in [KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_PRINT]:
		check_equal(Controls.check("sprint", 0, code).get("reason"), "sistema", "%s es del sistema" % OS.get_keycode_string(code))
	check(not Controls.assign("interact", 0, KEY_ESCAPE), "Esc nunca se asigna")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "interactuar sigue igual")


func test_menu_keys_only_go_where_they_do_not_get_in_the_way() -> void:
	check_equal(Controls.check("open_journal", 0, KEY_DOWN).get("reason"), "menu", "el expediente no puede usar ↓: lo recorre")
	check_equal(Controls.check("open_board", 0, KEY_ENTER).get("reason"), "menu", "ni el tablero Intro: confirma dentro")
	check_equal(Controls.check("interact", 0, KEY_LEFT).get("reason"), "menu", "interactuar no puede usar ←: recorre las respuestas")
	check_equal(Controls.check("interact", 0, KEY_SPACE)["result"], "ok", "pero sí Espacio, que también avanza el diálogo")
	check_equal(Controls.check("wait_time", 0, KEY_PAGEDOWN)["result"], "ok", "esperar sólo sirve explorando: puede usar Av Pág")
	check(Controls.assign("sprint", 0, KEY_CTRL), "Ctrl sola se puede asignar")


func test_a_swap_does_not_give_a_menu_key_to_a_screen_action() -> void:
	# Avanzar tiene ↑ de alternativa; dárselo al expediente a cambio de J estorbaría en su pantalla.
	var outcome := Controls.check("move_forward", 1, KEY_J)
	check_equal(outcome["result"], "conflict", "J es del expediente")
	check(not outcome["swap_ok"], "no se intercambia por ↑")


func test_restore_defaults_brings_back_every_key() -> void:
	Controls.assign("interact", 0, KEY_F)
	Controls.swap("open_map", 0, KEY_B)
	Controls.assign("move_left", 1, KEY_Q)
	check(Controls.customized_actions().size() >= 3, "hay varias acciones personalizadas")
	Controls.restore_defaults()
	check(Controls.customized_actions().is_empty(), "restaurar las devuelve todas")
	for action in InputBindings.action_ids():
		check_equal(_key_codes(action), InputBindings.default_keys(action), "%s vuelve a su tecla de fábrica" % action)


func test_invalid_maps_are_detected() -> void:
	var map := InputBindings.defaults()
	map["open_map"] = [KEY_E] as Array[Key]
	check(not InputBindings.validate_map(map).is_empty(), "dos acciones con la misma tecla")
	map = InputBindings.defaults()
	map["interact"] = [] as Array[Key]
	check(not InputBindings.validate_map(map).is_empty(), "una acción sin tecla")
	map = InputBindings.defaults()
	map["open_board"] = [KEY_ESCAPE] as Array[Key]
	check(not InputBindings.validate_map(map).is_empty(), "una tecla reservada")


# --- Persistencia ---

static func _stored() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(Settings.settings_path)
	return config


## Lo que hace un arranque nuevo: el InputMap de project.godot y los ajustes leídos del archivo.
static func _restart() -> void:
	InputMap.load_from_project_settings()
	Settings.load_settings()


func test_custom_keys_are_saved_in_the_settings_file() -> void:
	Settings.set_value("audio/Master", 0.55)
	Controls.assign("interact", 0, KEY_F)
	Controls.assign("move_forward", 1, KEY_I)
	var stored := _stored()
	check(stored.has_section("controles"), "las teclas van a la sección controles de ajustes.cfg")
	check_equal(stored.get_value("controles", "interact", []), ["F"], "interactuar con su nombre de tecla")
	check_equal(stored.get_value("controles", "move_forward", []), ["W", "I"], "avanzar con sus dos teclas")
	check(not stored.has_section_key("controles", "open_map"), "lo que no cambió no se escribe")
	check(is_equal_approx(float(stored.get_value("audio", "Master", -1.0)), 0.55), "y el resto de preferencias sigue en el archivo")
	check(not Settings.settings_path.begins_with(SaveSystem.get_storage_dir()), "nada de esto va a las ranuras de partida")
	Settings.set_value("audio/Master", SettingsSchema.DEFAULT_VOLUME)


func test_custom_keys_survive_a_restart() -> void:
	Controls.assign("interact", 0, KEY_F)
	Controls.swap("open_map", 0, KEY_B)
	Controls.assign("sprint", 0, KEY_CTRL)
	_restart()
	check_equal(Controls.get_keys("interact"), [KEY_F] as Array[Key], "interactuar sigue en F")
	check_equal(Controls.get_keys("open_map"), [KEY_B] as Array[Key], "el mapa en B")
	check_equal(Controls.get_keys("open_board"), [KEY_M] as Array[Key], "el tablero recibió la M del intercambio")
	check_equal(_key_codes("sprint"), [KEY_CTRL] as Array[Key], "y el InputMap ya usa Ctrl para correr")
	check(Controls.get_load_report()["rejected"].is_empty(), "sin descartar nada")


func test_restoring_removes_the_keys_and_keeps_other_preferences() -> void:
	Settings.set_value("audio/Musica", 0.3)
	Settings.set_value("jugabilidad/velocidad_texto", "rapido")
	Controls.assign("interact", 0, KEY_F)
	Controls.assign("wait_time", 0, KEY_Y)
	Controls.restore_defaults()
	check(not _stored().has_section("controles"), "la sección de teclas desaparece del archivo")
	check(is_equal_approx(float(Settings.get_value("audio/Musica")), 0.3), "el volumen no cambia")
	check_equal(Settings.get_value("jugabilidad/velocidad_texto"), "rapido", "ni la velocidad del texto")
	_restart()
	check(Controls.customized_actions().is_empty(), "tras reiniciar siguen las teclas de fábrica")
	check_equal(_key_codes("interact"), [KEY_E] as Array[Key], "interactuar vuelve a E")
	Settings.restore_defaults()


func test_damaged_stored_keys_are_discarded() -> void:
	Settings.write_section("controles", {"interact": ["Escape"], "open_map": ["Zzz"], "wait_time": "Y", "sprint": 7})
	Settings.load_settings()
	var report := Controls.get_load_report()
	check(report["rejected"].has("interact"), "Esc no se acepta para interactuar")
	check(report["rejected"].has("open_map"), "una tecla desconocida tampoco")
	check(report["rejected"].has("sprint"), "ni un valor que no es una tecla")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "interactuar se queda con la de fábrica")
	check_equal(Controls.get_keys("wait_time"), [KEY_Y] as Array[Key], "lo válido sí se aplica")
	var stored := _stored()
	check(not stored.has_section_key("controles", "interact"), "el archivo se corrige")
	check_equal(stored.get_value("controles", "wait_time", []), ["Y"], "conservando lo válido")


func test_an_incoherent_stored_set_falls_back_to_the_defaults() -> void:
	# Cada entrada es válida por sí sola, pero juntas dejan la E en dos acciones.
	Settings.write_section("controles", {"open_board": ["E"], "wait_time": ["Y"]})
	Settings.load_settings()
	check(Controls.customized_actions().is_empty(), "no se aplica a medias: vuelven las de fábrica")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "interactuar conserva su tecla")
	check(not _stored().has_section("controles"), "y el archivo queda limpio")


func test_settings_sections_of_other_systems_are_kept_apart() -> void:
	check(not Settings.write_section("audio", {"Master": 0.1}), "una sección de preferencias no se escribe a mano")
	check(is_equal_approx(float(_stored().get_value("audio", "Master", SettingsSchema.DEFAULT_VOLUME)), float(Settings.get_value("audio/Master"))), "y no cambia")
	Controls.assign("interact", 0, KEY_F)
	Settings.set_value("graficos/vsync", not Settings.vsync)
	check_equal(_stored().get_value("controles", "interact", []), ["F"], "guardar otra preferencia conserva las teclas")
	Settings.restore_defaults()
	check_equal(_stored().get_value("controles", "interact", []), ["F"], "y restaurar la configuración no las toca")


static func _current_map() -> Dictionary:
	var map := {}
	for action in InputBindings.action_ids():
		map[action] = Controls.get_keys(action)
	return map
