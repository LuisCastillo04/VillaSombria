extends TestCase
## Accesibilidad con la escena de juego real: el tamaño de letra agranda la interfaz sin que nada
## se salga de la pantalla; el contraste aumentado realza el texto y el foco, llega a lo que se crea
## después y se deshace sin dejar rastro; los subtítulos opcionales se muestran u ocultan sin tocar
## el texto obligatorio de las conversaciones; y el movimiento reducido quita los deslizamientos y
## latidos decorativos.

const OPEN_SECONDS := DialogueStyle.OPEN_SECONDS + 0.15

var game: Game


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.reset_test_settings()
	game = await make_game()


func after_each() -> void:
	if DialogueManager.active:
		DialogueManager.close()
	if ConfirmDialog.is_open():
		ConfirmDialog.cancel()
	var pause: PauseMenu = game.get_node("PauseMenu")
	if pause.is_open:
		pause.close()
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	TestCase.reset_test_settings()
	GameState.reset()
	GameClock.reset()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _screen() -> Rect2:
	return Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size).grow(0.5)


func _fits(control: Control, label: String) -> void:
	check(_screen().encloses(control.get_global_rect()), "%s cabe en la pantalla (%s en %s)" % [label, control.get_global_rect(), _screen().size])


# --- Tamaño de letra ---

func test_text_size_scales_the_whole_interface() -> void:
	var normal := get_tree().root.get_visible_rect().size
	for size_id: String in ["grande", "muy_grande"]:
		Settings.set_value("accesibilidad/tamano_letra", size_id)
		var factor: float = UiAccessibility.TEXT_SCALES[size_id]
		check(is_equal_approx(get_tree().root.content_scale_factor, factor), "«%s» amplía la interfaz ×%.2f" % [size_id, factor])
		var view := get_tree().root.get_visible_rect().size
		check(absf(view.x - normal.x / factor) < 1.5 and absf(view.y - normal.y / factor) < 1.5, "el lienzo lógico se reduce en la misma proporción: todo se ve más grande")
	Settings.set_value("accesibilidad/tamano_letra", "normal")
	check(is_equal_approx(get_tree().root.content_scale_factor, 1.0), "«Normal» deja la escala original")
	check(get_tree().root.get_visible_rect().size.is_equal_approx(normal), "y el lienzo de siempre")


func test_very_large_text_keeps_every_screen_inside() -> void:
	Settings.set_value("accesibilidad/tamano_letra", "muy_grande")
	await wait_physics_frames(3)
	var pause: PauseMenu = game.get_node("PauseMenu")
	pause.open()
	await _wait(0.3)
	_fits(pause.get_node("Root/Center/Panel"), "la pausa")
	var settings: SettingsMenu = pause.get_node("Root/SettingsMenu")
	pause.get_node("Root/Center/Panel/Box/Settings").pressed.emit()
	await _wait(0.3)
	for index in settings.get_category_titles().size():
		settings.select_category(index)
		await wait_physics_frames(2)
		_fits(settings.get_node("%Frame"), "la configuración, categoría %d" % index)
		_fits(settings.get_back_button(), "«Volver», categoría %d" % index)
	settings.close()
	await _wait(0.3)
	pause.close()
	await _wait(0.3)
	# La ventana de confirmación.
	ConfirmDialog.ask("PRUEBA", "¿Quieres dejar pasar una hora?\nSon las 08:00; pasarán a ser las 09:00.")
	await wait_physics_frames(3)
	_fits(ConfirmDialog.get_node("Root/Center/Card") if ConfirmDialog.has_node("Root/Center/Card") else ConfirmDialog.get_confirm_button(), "la confirmación")
	_fits(ConfirmDialog.get_confirm_button(), "su botón de confirmar")
	_fits(ConfirmDialog.get_cancel_button(), "y el de cancelar")
	ConfirmDialog.cancel()
	# Las conversaciones, al leer y al elegir.
	var dialogue: DialogueUi = game.get_node("DialogueUi")
	DialogueManager.start("eusebio")
	await _wait(OPEN_SECONDS)
	_fits(dialogue.get_dialogue_window(), "la ventana de la conversación")
	_fits(dialogue.get_continue_button(), "«Continuar»")
	for attempt in 10:
		if dialogue.is_choosing():
			break
		var press := InputEventAction.new()
		press.action = "interact"
		press.pressed = true
		get_viewport().push_input(press)
		await wait_physics_frames(3)
	await _wait(0.4)
	check(dialogue.is_choosing(), "se llega a las preguntas")
	_fits(dialogue.get_dialogue_window(), "la ventana con las preguntas")
	DialogueManager.close()
	await _wait(0.4)
	# El expediente y el tablero.
	var journal: JournalUi = game.get_node("JournalUi")
	journal.open(0)
	await _wait(0.6)
	_fits(journal.get_folder(), "el expediente")
	journal.close()
	await _wait(0.4)
	var board: BoardUi = game.get_node("BoardUi")
	board.open()
	await _wait(0.6)
	for card in board.find_children("Suspect_*", "BoardSuspectCard", true, false):
		var suspect := card as BoardSuspectCard
		_fits(suspect, "la ficha de %s" % suspect.suspect_id)
		check(suspect.is_status_complete(), "la valoración de %s se lee entera" % suspect.suspect_id)
	board.close()


# --- Contraste aumentado ---

func test_high_contrast_sharpens_text_and_focus_and_can_be_undone() -> void:
	var pause: PauseMenu = game.get_node("PauseMenu")
	var info: Label = pause.get_node("Root/Center/Panel/Box/SlotInfo")
	var resume: Button = pause.get_node("Root/Center/Panel/Box/Resume")
	pause.open()
	var original_color := info.get_theme_color("font_color")
	var original_focus := resume.get_theme_stylebox("focus")
	check(not Settings.is_high_contrast_applied(), "por defecto el aspecto es el de siempre")
	check(not info.has_meta(ContrastFilter.ORIGINAL), "sin tocar ningún control")
	Settings.set_value("accesibilidad/contraste_alto", true)
	check(Settings.is_high_contrast_applied(), "al activarlo se aplica en el acto")
	var boosted := info.get_theme_color("font_color")
	check(boosted != original_color and is_equal_approx(boosted.a, 1.0), "el texto secundario se vuelve opaco y más nítido")
	check(boosted.get_luminance() > original_color.get_luminance(), "un texto claro sobre fondo oscuro se aclara")
	var ring := resume.get_theme_stylebox("focus") as StyleBoxFlat
	check(ring != null and ring.border_width_left >= ContrastFilter.FOCUS_WIDTH, "el foco pasa a ser un filete grueso")
	check(ring.border_color.get_luminance() > 0.85, "y casi blanco")
	# Una pantalla que cambia un color mientras está activo: se realza el color nuevo.
	pause.close()
	await save_and_wait("manual_2")
	pause.open()
	check(info.get_theme_color("font_color").a == 1.0 and info.get_theme_color("font_color") != MenuStyle.TEXT_SECONDARY, "un color cambiado después también se realza")
	# Lo que se crea después, también.
	var late := MenuStyle.make_label("Nuevo", 20, MenuStyle.TEXT_MUTED)
	pause.get_node("Root").add_child(late)
	await get_tree().process_frame
	check(is_equal_approx(late.get_theme_color("font_color").a, 1.0), "un control nuevo nace con contraste aumentado")
	# La tinta sobre pergamino se oscurece.
	var ink := Label.new()
	CaseFileStyle.style_label(ink, CaseFileStyle.serif(), 20, CaseFileStyle.INK_SOFT)
	pause.get_node("Root").add_child(ink)
	await get_tree().process_frame
	check(ink.get_theme_color("font_color").get_luminance() < CaseFileStyle.INK_SOFT.get_luminance(), "la tinta clara sobre papel se oscurece")
	Settings.set_value("accesibilidad/contraste_alto", false)
	check(not Settings.is_high_contrast_applied(), "al desactivarlo se retira")
	check_equal(late.get_theme_color("font_color"), MenuStyle.TEXT_MUTED, "y cada control vuelve a su color")
	check(resume.get_theme_stylebox("focus") == original_focus, "y a su foco original")
	check(not resume.has_meta(ContrastFilter.ORIGINAL), "sin dejar rastro")
	late.queue_free()
	ink.queue_free()


func test_disabled_text_keeps_looking_disabled() -> void:
	var button := Button.new()
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4, 0.5))
	add_child(button)
	Settings.set_value("accesibilidad/contraste_alto", true)
	check_equal(button.get_theme_color("font_disabled_color"), Color(0.4, 0.4, 0.4, 0.5), "lo desactivado no se realza")
	button.queue_free()


# --- Subtítulos ---

func test_subtitles_show_or_hide_without_touching_the_dialogue_text() -> void:
	var bar: SubtitleBar = game.get_node("Subtitles")
	check(UiAccessibility.subtitles_enabled(), "por defecto se muestran")
	EventBus.subtitle_requested.emit("rosa", "Buenas noches, inspector.", 2.0)
	check(bar.is_showing(), "una voz con subtítulos se muestra")
	check_equal(bar.get_text(), "Buenas noches, inspector.", "con su texto")
	check_equal(bar.get_speaker_text(), GameData.get_character_name("rosa"), "y el nombre de quien habla")
	Settings.set_value("accesibilidad/subtitulos", false)
	check(not bar.is_showing(), "al desactivarlos desaparece en el acto")
	EventBus.subtitle_requested.emit("rosa", "Otra frase.", 2.0)
	check(not bar.is_showing(), "y no se muestran más")
	# El texto de las conversaciones es obligatorio y no depende de los subtítulos.
	var dialogue: DialogueUi = game.get_node("DialogueUi")
	DialogueManager.play_scene("llamada")
	await _wait(OPEN_SECONDS)
	check(dialogue.is_open() and not dialogue.get_dialogue_text().get_full_text().is_empty(), "la conversación se sigue leyendo entera")
	DialogueManager.close()
	Settings.set_value("accesibilidad/subtitulos", true)
	check(bar.show_subtitle("", "Truena a lo lejos.", 0.5), "un sonido narrado, sin hablante")
	check(bar.get_speaker_text().is_empty(), "no lleva nombre")
	await _wait(0.8)
	check(not bar.is_showing(), "y se retira al acabar su tiempo")


# --- Movimiento reducido ---

func test_reduced_motion_removes_decorative_movement() -> void:
	Settings.set_value("accesibilidad/movimiento_reducido", true)
	check_equal(UiAccessibility.motion(), 0.0, "los desplazamientos decorativos valen cero")
	var dialogue: DialogueUi = game.get_node("DialogueUi")
	DialogueManager.play_scene("llamada")
	await get_tree().process_frame
	await get_tree().process_frame
	var start := dialogue.get_dialogue_window().position.y
	await _wait(OPEN_SECONDS)
	check(absf(dialogue.get_dialogue_window().position.y - start) < 0.5, "la ventana aparece en su sitio, sin subir")
	var portrait := dialogue.get_portrait()
	var before := portrait.position
	await _wait(0.6)
	check(portrait.position.is_equal_approx(before), "las siluetas no respiran ni se balancean")
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	get_viewport().push_input(press)
	await _wait(0.3)
	var continue_button := dialogue.get_continue_button()
	var pulse_a: float = continue_button._pulse
	await _wait(0.4)
	check(is_equal_approx(continue_button._pulse, pulse_a), "«Continuar» no late")
	DialogueManager.close()
	await _wait(0.4)
	Settings.set_value("accesibilidad/movimiento_reducido", false)
	check_equal(UiAccessibility.motion(), 1.0, "al desactivarlo vuelve el movimiento")


func test_accessibility_settings_persist() -> void:
	Settings.set_value("accesibilidad/tamano_letra", "grande")
	Settings.set_value("accesibilidad/contraste_alto", true)
	Settings.set_value("accesibilidad/subtitulos", false)
	Settings.set_value("accesibilidad/movimiento_reducido", true)
	Settings.use_file(Settings.settings_path)
	check(is_equal_approx(get_tree().root.content_scale_factor, UiAccessibility.TEXT_SCALES["grande"]), "el tamaño de letra se aplica al leerlo")
	check(Settings.is_high_contrast_applied(), "el contraste también")
	check(not UiAccessibility.subtitles_enabled(), "los subtítulos siguen ocultos")
	check(UiAccessibility.reduced_motion(), "y el movimiento reducido")
