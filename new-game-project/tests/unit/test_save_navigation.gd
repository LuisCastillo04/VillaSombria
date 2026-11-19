extends TestCase
## Navegación del expediente con teclado, mando y ratón, y gestión del foco.

var game: Game
var pause: PauseMenu
var slots: SaveSlotsMenu
var _loaded: Array[String] = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	game = await make_game()
	pause = game.get_node("PauseMenu")
	slots = pause.get_node("Root/SaveSlotsMenu")
	slots.load_ready.disconnect(pause._on_load_ready)
	_loaded.clear()
	slots.load_ready.connect(_on_load_ready)
	# Dos partidas válidas (la 3 queda activa) y un archivo dañado en la 4.
	await save_and_wait("manual_2")
	await save_and_wait("manual_3")
	write_slot_file("manual_4", "{dañado")


func after_each() -> void:
	slots.load_ready.disconnect(_on_load_ready)
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	SaveSystem.take_pending_load()
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _on_load_ready(slot_id: String) -> void:
	_loaded.append(slot_id)


func _open(menu_mode: SaveSlotsMenu.Mode) -> void:
	pause.open()
	var button := "Save" if menu_mode == SaveSlotsMenu.Mode.SAVE else "Load"
	(pause.get_node("Root/Center/Panel/Box/" + button) as Button).pressed.emit()


func _send(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	slots._input(event)


func _focused() -> Control:
	return slots.get_focused_control()


func test_opens_on_the_active_slot_with_focus() -> void:
	_open(SaveSlotsMenu.Mode.LOAD)
	check_equal(slots.get_selected_slot(), "manual_3", "se abre en la ranura activa")
	check(_focused() == slots.get_row("manual_3"), "con el foco en ella")


func test_arrows_move_through_the_five_slots() -> void:
	_open(SaveSlotsMenu.Mode.LOAD)
	for step in 4:
		_send("ui_up")
	check_equal(slots.get_selected_slot(), "manual_1", "arriba llega a la primera y se queda")
	_send("ui_down")
	_send("ui_down")
	check_equal(slots.get_selected_slot(), "manual_3", "abajo avanza una ranura cada vez")
	check(_focused() == slots.get_row("manual_3"), "y el foco acompaña a la selección")
	for step in 6:
		_send("ui_down")
	check_equal(slots.get_selected_slot(), "manual_5", "y se detiene en la última")


func test_tab_follows_a_fixed_order_and_skips_disabled_buttons() -> void:
	_open(SaveSlotsMenu.Mode.LOAD)
	slots.select_slot("manual_2")
	_send("ui_focus_next")
	check(_focused() == slots.get_action_button(), "ranura → Cargar")
	_send("ui_focus_next")
	check(_focused() == slots.get_delete_button(), "Cargar → Eliminar")
	_send("ui_focus_next")
	check(_focused() == slots.get_back_button(), "Eliminar → Volver")
	_send("ui_focus_next")
	check(_focused() == slots.get_row("manual_2"), "Volver → la ranura seleccionada")
	_send("ui_focus_prev")
	check(_focused() == slots.get_back_button(), "Mayús + Tab recorre al revés")
	slots.select_slot("manual_5")
	check_equal(slots.get_action_button().focus_mode, Control.FOCUS_NONE, "Cargar desactivado no acepta el foco")
	_send("ui_focus_next")
	check(_focused() == slots.get_back_button(), "con una ranura vacía, Tab salta a Volver")


func test_enter_on_a_slot_runs_the_main_action() -> void:
	_open(SaveSlotsMenu.Mode.LOAD)
	slots.select_slot("manual_5")
	_send("ui_accept")
	check(_loaded.is_empty(), "una ranura vacía no se carga")
	check(slots.get_status_text().contains("vacía"), "y se explica por qué")
	slots.select_slot("manual_2")
	_send("ui_accept")
	check_equal(_loaded, ["manual_2"] as Array[String], "Intro carga la ranura enfocada")


func test_double_click_loads_only_valid_games() -> void:
	_open(SaveSlotsMenu.Mode.LOAD)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	slots.get_row("manual_4").gui_input.emit(click)
	slots.get_row("manual_5").gui_input.emit(click)
	check(_loaded.is_empty(), "ni las dañadas ni las vacías")
	slots.get_row("manual_2").gui_input.emit(click)
	check_equal(_loaded, ["manual_2"] as Array[String], "doble clic sobre una partida válida la carga")


func test_double_click_never_saves() -> void:
	_open(SaveSlotsMenu.Mode.SAVE)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	slots.get_row("manual_5").gui_input.emit(click)
	check(not SaveSystem.is_busy(), "en la pantalla de guardar el doble clic no guarda")


func test_focus_returns_after_closing_a_confirmation() -> void:
	_open(SaveSlotsMenu.Mode.SAVE)
	slots.select_slot("manual_2")
	_send("ui_focus_next")
	slots.get_action_button().pressed.emit()
	check(slots.is_confirming(), "sobrescribir pide confirmación")
	check(_focused() == slots.get_confirm_cancel(), "el foco empieza en Cancelar")
	_send("ui_left")
	check(_focused() == slots.get_confirm_accept(), "izquierda va a Sobrescribir")
	_send("ui_up")
	_send("ui_focus_next")
	check(_focused() == slots.get_confirm_cancel(), "el foco no sale de la confirmación")
	_send("ui_cancel")
	check(not slots.is_confirming(), "Escape cancela")
	check(_focused() == slots.get_action_button(), "y el foco vuelve a Guardar")
	check(not SaveSystem.is_busy(), "sin guardar nada")
	_send("ui_cancel")
	check(not slots.visible, "un segundo Escape cierra el expediente")


func test_navigation_never_changes_the_active_slot() -> void:
	_open(SaveSlotsMenu.Mode.LOAD)
	for action: String in ["ui_up", "ui_up", "ui_down", "ui_focus_next", "ui_focus_prev", "ui_down"]:
		_send(action)
	var hover := slots.get_row("manual_5")
	hover.mouse_entered.emit()
	_send("ui_cancel")
	check_equal(SaveSystem.get_active_slot(), "manual_3", "recorrer y cerrar no cambia la ranura activa")


func test_reopening_starts_again_on_the_active_slot() -> void:
	_open(SaveSlotsMenu.Mode.LOAD)
	slots.select_slot("manual_2")
	_send("ui_cancel")
	(pause.get_node("Root/Center/Panel/Box/Load") as Button).pressed.emit()
	check_equal(slots.get_selected_slot(), "manual_3", "al volver a abrir se parte de la ranura activa")
	check(_focused() == slots.get_row("manual_3"), "con el foco en ella")
