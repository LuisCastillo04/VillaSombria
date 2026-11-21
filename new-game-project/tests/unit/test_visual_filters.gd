extends TestCase
## Filtros de color de Configuración → Filtros: el catálogo, la preferencia única y su validación; con
## la escena de juego real, que el filtro cambia el mundo en el acto sin tocar la interfaz, las luces
## ni la lluvia, que hay uno solo a la vez y que sobrevive a los cambios de lugar, a la carga de una
## partida y al menú principal; y la página de Configuración con ratón, teclado y mando.

const OLD_FILE := "user://pruebas_guardado/ajustes_filtros.cfg"

var game: Game


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.reset_test_settings()


func after_each() -> void:
	if DialogueManager.active:
		DialogueManager.close()
	if game != null and is_instance_valid(game):
		var pause: PauseMenu = game.get_node("PauseMenu")
		if pause.is_open:
			pause.close()
		get_tree().paused = false
		game.queue_free()
		await get_tree().process_frame
	game = null
	if FileAccess.file_exists(OLD_FILE):
		DirAccess.remove_absolute(OLD_FILE)
	TestCase.reset_test_settings()
	GameState.reset()
	GameClock.reset()


func _start() -> void:
	game = await make_game()
	await game.go_to("plaza", "")


func _post() -> PostFx:
	return game.get_node("PostFx")


func _material() -> ShaderMaterial:
	return _post().get_node("Rect").material as ShaderMaterial


func _check_parameters(id: String, message: String) -> void:
	var values := VisualFilters.parameters(id)
	for parameter: String in values:
		check_equal(_material().get_shader_parameter(parameter), values[parameter], "%s: %s" % [message, parameter])


# --- Catálogo y preferencia ---

func test_catalog_offers_the_four_filters_in_order() -> void:
	check_equal(VisualFilters.ids(), ["noir", "sepia", "cold_night", "original"] as Array[String], "identificadores estables, en el orden de la pantalla")
	var labels := VisualFilters.IDS.map(func(id: String) -> String: return VisualFilters.label_of(id))
	check_equal(labels, ["Modo noir", "Sepia", "Frío nocturno", "Colores originales"], "con sus nombres")
	check_equal(VisualFilters.description_of("noir"), "Blanco y negro con alto contraste para una atmósfera detectivesca.", "y sus descripciones")
	check_equal(VisualFilters.description_of("original"), "La paleta de colores estándar del juego, sin filtros.", "también la de los colores originales")
	check_equal(SettingsSchema.options(VisualFilters.SETTING_KEY), VisualFilters.IDS, "la preferencia admite exactamente esos filtros")


func test_original_colors_are_the_default_and_neutral() -> void:
	check_equal(SettingsSchema.default_value(VisualFilters.SETTING_KEY), VisualFilters.ORIGINAL, "sin preferencia guardada, colores originales")
	check_equal(VisualFilters.current(), VisualFilters.ORIGINAL, "y es el filtro vigente")
	check_equal(VisualFilters.parameters(VisualFilters.ORIGINAL), VisualFilters.NEUTRAL, "los colores originales no cambian nada")
	for id in VisualFilters.IDS:
		var values := VisualFilters.parameters(id)
		check_equal(values.keys(), VisualFilters.NEUTRAL.keys(), "%s define todos los parámetros: no deja restos del anterior" % id)
		if id != VisualFilters.ORIGINAL:
			check(values != VisualFilters.NEUTRAL and float(values["grade_amount"]) > 0.0, "%s cambia los colores de verdad" % id)


func test_unknown_identifiers_fall_back_to_original_colors() -> void:
	check_equal(VisualFilters.sanitize("vhs"), VisualFilters.ORIGINAL, "un identificador desconocido")
	check_equal(VisualFilters.sanitize(3), VisualFilters.ORIGINAL, "un tipo equivocado")
	check_equal(VisualFilters.sanitize("Modo noir"), VisualFilters.ORIGINAL, "el texto visible no es un identificador")
	check_equal(VisualFilters.sanitize(&"sepia"), "sepia", "uno válido se conserva")
	check(not Settings.set_value(VisualFilters.SETTING_KEY, "vhs"), "Settings rechaza un filtro que no existe")
	check_equal(VisualFilters.current(), VisualFilters.ORIGINAL, "y deja el que había")


func test_a_material_takes_one_filter_at_a_time() -> void:
	var material := ShaderMaterial.new()
	check_equal(VisualFilters.applied_to(material), VisualFilters.ORIGINAL, "un material sin tocar está en colores originales")
	check(VisualFilters.apply_to_material(material, "noir"), "aplicar el noir escribe sus parámetros")
	check_equal(material.get_shader_parameter("grade_saturation"), 0.0, "sin color")
	check(not VisualFilters.apply_to_material(material, "noir"), "repetirlo no vuelve a escribir nada")
	check(VisualFilters.apply_to_material(material, "sepia"), "pasar a sepia")
	for parameter: String in VisualFilters.NEUTRAL:
		check_equal(material.get_shader_parameter(parameter), VisualFilters.parameters("sepia")[parameter], "%s es el de sepia, sin restos del noir" % parameter)
	check(VisualFilters.apply_to_material(material, "original"), "volver a los colores originales")
	for parameter: String in VisualFilters.NEUTRAL:
		check_equal(material.get_shader_parameter(parameter), VisualFilters.NEUTRAL[parameter], "%s vuelve a su valor neutro" % parameter)
	check_equal(VisualFilters.applied_to(material), VisualFilters.ORIGINAL, "y el material lo sabe")


func test_old_or_damaged_preferences_recover_original_colors() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SettingsSchema.VERSION)
	config.set_value("graficos", "calidad_efectos", "medio")
	config.save(OLD_FILE)
	Settings.use_file(OLD_FILE)
	check_equal(VisualFilters.current(), VisualFilters.ORIGINAL, "un archivo de antes de los filtros empieza en colores originales")
	check_equal(Settings.get_value("graficos/calidad_efectos"), "medio", "sin perder lo demás")
	config.set_value("filtros", "activo", "vhs")
	config.save(OLD_FILE)
	Settings.use_file(OLD_FILE)
	check_equal(VisualFilters.current(), VisualFilters.ORIGINAL, "un filtro desconocido vuelve a los colores originales")
	check(VisualFilters.SETTING_KEY in (Settings.get_load_report()["rejected"] as Array), "y se anota como rechazado")
	var stored := ConfigFile.new()
	stored.load(OLD_FILE)
	check_equal(stored.get_value("filtros", "activo", ""), VisualFilters.ORIGINAL, "el archivo queda corregido")
	config.set_value("filtros", "activo", 2)
	config.save(OLD_FILE)
	Settings.use_file(OLD_FILE)
	check_equal(VisualFilters.current(), VisualFilters.ORIGINAL, "un número en lugar del identificador, también")


# --- Con la escena de juego ---

func test_one_filter_at_a_time_changes_the_world_at_once() -> void:
	await _start()
	check_equal(_post().get_visual_filter(), VisualFilters.ORIGINAL, "la partida empieza con los colores originales")
	check_equal(_material().get_shader_parameter("grade_amount") if _material().get_shader_parameter("grade_amount") != null else 0.0, 0.0, "sin ninguna corrección")
	for id: String in ["noir", "sepia", "cold_night", "sepia", "noir", "original"]:
		check(Settings.set_value(VisualFilters.SETTING_KEY, id), "se elige %s" % id)
		check_equal(_post().get_visual_filter(), id, "el mundo muestra %s en el acto" % id)
		_check_parameters(id, "%s sin restos del anterior" % id)
		check_equal(Settings.get_value(VisualFilters.SETTING_KEY), id, "y es el único filtro guardado")
	check_equal(get_tree().get_nodes_in_group(VisualFilters.GROUP).size(), 1, "un solo postproceso con filtro: nunca se acumulan")


func test_choosing_the_active_filter_again_touches_nothing() -> void:
	await _start()
	Settings.set_value(VisualFilters.SETTING_KEY, "noir")
	var material := _material()
	var announced: Array[String] = []
	var listener := func(key: String, _value: Variant) -> void: announced.append(key)
	Settings.changed.connect(listener)
	check(Settings.set_value(VisualFilters.SETTING_KEY, "noir"), "repetir el filtro activo se acepta")
	Settings.changed.disconnect(listener)
	check(announced.is_empty(), "pero no se guarda ni se avisa otra vez")
	check(not VisualFilters.apply_to_material(material, "noir"), "y el material no se vuelve a escribir")
	check(_material() == material, "es el mismo material: no se crea ninguno")
	check_equal(get_tree().get_nodes_in_group(VisualFilters.GROUP).size(), 1, "ni otro postproceso")


func test_every_interface_is_drawn_above_the_filter() -> void:
	await _start()
	Settings.set_value(VisualFilters.SETTING_KEY, "noir")
	var pause: PauseMenu = game.get_node("PauseMenu")
	pause.open()
	pause.get_node("Root/Center/Panel/Box/Settings").pressed.emit()
	await get_tree().process_frame
	check_equal(_post().layer, PostFx.LAYER, "el postproceso está en su capa")
	var filtered: Array[String] = []
	_collect_controls_under_filter(get_tree().root, filtered)
	check(filtered.is_empty(), "ningún menú, HUD, diálogo ni aviso queda debajo del filtro: %s" % ", ".join(filtered))
	for layer: CanvasLayer in _canvas_layers(get_tree().root):
		if not layer is PostFx:
			check(layer.layer > PostFx.LAYER, "%s (capa %d) se dibuja encima del filtro" % [layer.name, layer.layer])


## Controles que se dibujarían antes que el postproceso, y por tanto con el filtro: los que no están en
## ninguna capa o están en una que no queda por encima de la suya.
func _collect_controls_under_filter(node: Node, found: Array[String]) -> void:
	for child in node.get_children():
		var control := child as Control
		if control != null and control.visible:
			var layer := _layer_of(control)
			if not layer is PostFx and (layer == null or layer.layer <= PostFx.LAYER):
				found.append(str(control.get_path()))
				continue
		_collect_controls_under_filter(child, found)


func _layer_of(node: Node) -> CanvasLayer:
	var parent := node.get_parent()
	while parent != null:
		if parent is CanvasLayer:
			return parent
		parent = parent.get_parent()
	return null


func _canvas_layers(node: Node) -> Array[CanvasLayer]:
	var found: Array[CanvasLayer] = []
	for child in node.get_children():
		if child is CanvasLayer:
			found.append(child as CanvasLayer)
		found.append_array(_canvas_layers(child))
	return found


func test_filters_leave_lights_rain_and_quality_alone() -> void:
	await _start()
	var lights: Array[Light3D] = []
	for node in get_tree().get_nodes_in_group(GraphicsQuality.LIGHT_GROUP):
		if game.is_ancestor_of(node):
			lights.append(node as Light3D)
	var energies := lights.map(func(light: Light3D) -> float: return light.light_energy)
	var colors := lights.map(func(light: Light3D) -> Color: return light.light_color)
	var environment := (game.current_location.get_node("Ambiente") as WorldEnvironment).environment
	var rain: RainEffect = get_tree().get_nodes_in_group(GraphicsQuality.RAIN_GROUP).filter(func(node: Node) -> bool: return game.is_ancestor_of(node))[0]
	var minutes := GameClock.minutes
	var player_position := game.player.global_position
	for id in VisualFilters.IDS:
		Settings.set_value(VisualFilters.SETTING_KEY, id)
		for index in lights.size():
			check(lights[index].visible and lights[index].light_energy == energies[index] and lights[index].light_color == colors[index], "%s no toca la intensidad ni el color de las luces" % id)
		check(is_equal_approx(environment.adjustment_contrast, 1.1) and is_equal_approx(environment.adjustment_saturation, 0.88), "%s no toca el entorno del escenario" % id)
		check(rain.emitting and rain.amount == RainEffect.FULL_AMOUNT, "%s no toca la lluvia" % id)
	check_equal(GameClock.minutes, minutes, "ni el reloj")
	check_equal(game.player.global_position, player_position, "ni al detective")
	Settings.set_value(VisualFilters.SETTING_KEY, "sepia")
	Settings.set_value("graficos/calidad_efectos", "bajo")
	Settings.set_value("graficos/calidad_iluminacion", "bajo")
	check_equal(_post().get_fog_octaves(), 2, "la calidad de efectos sigue cambiando la niebla")
	check(not environment.glow_enabled, "y la de iluminación el resplandor")
	check_equal(_post().get_visual_filter(), "sepia", "con el filtro intacto")
	_check_parameters("sepia", "la calidad no altera el filtro")


func test_the_filter_survives_places_loading_and_the_main_menu() -> void:
	Settings.set_value(VisualFilters.SETTING_KEY, "cold_night")
	await _start()
	check_equal(_post().get_visual_filter(), "cold_night", "una partida nueva empieza con el filtro elegido")
	var post := _post()
	await game.go_to("cafe", "")
	check(_post() == post and post.get_visual_filter() == "cold_night", "dentro del café sigue el mismo")
	check(not DialogueManager.active or _post().get_visual_filter() == "cold_night", "también durante la escena que empieza al entrar")
	if DialogueManager.active:
		DialogueManager.close()
	await game.go_to("plaza", "")
	check_equal(post.get_visual_filter(), "cold_night", "y al salir")
	if DialogueManager.active:
		DialogueManager.close()
	check(await save_and_wait("manual_1"), "se guarda la partida")
	var stored := FileAccess.get_file_as_string(SaveSystem.get_slot_path("manual_1"))
	check(not stored.contains("cold_night") and not stored.contains(VisualFilters.SETTING_KEY), "el filtro no viaja en la partida")
	Settings.set_value(VisualFilters.SETTING_KEY, "noir")
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()
	GameClock.reset()
	check(SaveSystem.request_load("manual_1")["ok"], "se prepara la carga")
	game = await make_game()
	check_equal(_post().get_visual_filter(), "noir", "al cargar se mantiene el filtro vigente, no el de cuando se guardó")
	_check_parameters("noir", "al cargar")
	var menu: Node = (load("res://scenes/main/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	check_equal((menu.get_node("PostFx") as PostFx).get_visual_filter(), "noir", "el menú principal muestra la plaza con el mismo filtro")
	menu.queue_free()
	await get_tree().process_frame


func test_reading_the_preferences_again_applies_the_saved_filter() -> void:
	await _start()
	var config := ConfigFile.new()
	config.set_value("meta", "version", SettingsSchema.VERSION)
	config.set_value("filtros", "activo", "sepia")
	config.save(OLD_FILE)
	Settings.use_file(OLD_FILE)
	check_equal(_post().get_visual_filter(), "sepia", "al leer las preferencias, la partida en marcha toma el filtro guardado")
	Settings.use_file(TestCase.SETTINGS_FILE)
	check_equal(_post().get_visual_filter(), VisualFilters.ORIGINAL, "y sin preferencia, vuelve a los colores originales sin restos")
	_check_parameters(VisualFilters.ORIGINAL, "sin preferencia")


# --- Configuración → Filtros ---

func _open_filters() -> SettingsMenu:
	await _start()
	var pause: PauseMenu = game.get_node("PauseMenu")
	var settings: SettingsMenu = pause.get_node("Root/SettingsMenu")
	pause.open()
	pause.get_node("Root/Center/Panel/Box/Settings").pressed.emit()
	await get_tree().process_frame
	settings.select_category(Array(settings.get_category_titles()).find("Filtros"))
	await get_tree().process_frame
	return settings


func _cards(settings: SettingsMenu) -> Array[FilterCard]:
	var found: Array[FilterCard] = []
	for id in VisualFilters.IDS:
		found.append(settings.get_filter_card(id))
	return found


func _active_cards(settings: SettingsMenu) -> Array[String]:
	var found: Array[String] = []
	for card in _cards(settings):
		if card.is_active():
			found.append(card.filter_id)
	return found


func _click(control: Control) -> void:
	var spot := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		get_viewport().push_input(click, true)
	await get_tree().process_frame


func _navigate(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame


func _pad_button(index: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = index
		event.pressed = pressed
		Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	await wait_physics_frames(2)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_the_page_shows_four_cards_and_one_active() -> void:
	var settings := await _open_filters()
	var titles: Array[String] = []
	for card in _cards(settings):
		check(card != null and card.is_visible_in_tree(), "cada filtro tiene su tarjeta visible")
		titles.append(card.get_title_text())
	check_equal(titles, ["Modo noir", "Sepia", "Frío nocturno", "Colores originales"] as Array[String], "en el orden de la referencia")
	check_equal(settings.get_filter_card("cold_night").get_detail_text(), "Tonos azulados y desaturados que refuerzan el ambiente nocturno.", "con su descripción")
	check_equal(_active_cards(settings), ["original"] as Array[String], "sólo los colores originales están activos")
	check_equal(settings.get_filter_card("original").get_badge_text(), "ACTIVO", "su botón dice «ACTIVO»")
	check_equal(settings.get_filter_card("noir").get_badge_text(), "SELECCIONAR", "y los demás, «SELECCIONAR»")
	var page := settings.get_page(settings.get_selected_category())
	var intro := page.get_child(0) as Label
	check(intro != null and intro.text == "Activa filtros de pantalla que solo cambian los colores del juego.", "con la explicación de la referencia")


func test_the_mouse_chooses_a_filter_and_the_menu_stays_open() -> void:
	var settings := await _open_filters()
	await _click(settings.get_filter_card("sepia"))
	check_equal(Settings.get_value(VisualFilters.SETTING_KEY), "sepia", "un clic en la tarjeta elige el sepia")
	check_equal(_post().get_visual_filter(), "sepia", "el mundo cambia en el acto")
	check_equal(_active_cards(settings), ["sepia"] as Array[String], "sólo su tarjeta está activa")
	check_equal(settings.get_filter_card("original").get_badge_text(), "SELECCIONAR", "la anterior vuelve a «SELECCIONAR»")
	check(settings.is_open(), "y Configuración sigue abierta para comparar")
	await _click(settings.get_filter_card("noir"))
	check_equal(_active_cards(settings), ["noir"] as Array[String], "otro clic cambia al noir, sin acumular")
	await _click(settings.get_filter_card("noir"))
	check_equal(_active_cards(settings), ["noir"] as Array[String], "repetirlo no cambia nada")
	settings.get_back_button().pressed.emit()
	await get_tree().process_frame
	settings.open()
	await get_tree().process_frame
	check_equal(_active_cards(settings), ["noir"] as Array[String], "al volver a entrar sigue elegido")


func test_keyboard_and_gamepad_navigate_and_choose() -> void:
	var settings := await _open_filters()
	var tab := settings.get_tab(settings.get_selected_category())
	tab.grab_focus()
	await _navigate("ui_right")
	check(_focus() == settings.get_filter_card("noir"), "a la derecha de la pestaña, la primera tarjeta")
	await _navigate("ui_down")
	check(_focus() == settings.get_filter_card("sepia"), "abajo, la siguiente")
	await _navigate("ui_accept")
	check_equal(Settings.get_value(VisualFilters.SETTING_KEY), "sepia", "aceptar la elige")
	check(_focus() == settings.get_filter_card("sepia"), "y el foco se queda en ella")
	await _navigate("ui_down")
	await _navigate("ui_down")
	check(_focus() == settings.get_filter_card("original"), "las cuatro se recorren")
	await _navigate("ui_left")
	check(_focus() == tab, "a la izquierda se vuelve a la pestaña de Filtros")
	settings.get_filter_card("cold_night").grab_focus()
	await _pad_button(JOY_BUTTON_A)
	check_equal(Settings.get_value(VisualFilters.SETTING_KEY), "cold_night", "con el mando, A elige la señalada")
	await _pad_button(JOY_BUTTON_DPAD_UP)
	check(_focus() == settings.get_filter_card("sepia"), "la cruceta sube a la anterior")
	check_equal(_active_cards(settings), ["cold_night"] as Array[String], "y sólo hay una activa")
