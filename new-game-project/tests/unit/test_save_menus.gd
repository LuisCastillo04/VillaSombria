extends TestCase
## Menús de guardado y carga manejados como lo haría el jugador.

var game: Game
var pause: PauseMenu
var slots: SaveSlotsMenu


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	game = await make_game()
	pause = game.get_node("PauseMenu")
	slots = pause.get_node("Root/SaveSlotsMenu")


func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(game):
		game.queue_free()
	await get_tree().process_frame
	SaveSystem.take_pending_load()
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _open_save_menu() -> void:
	pause.open()
	(pause.get_node("Root/Center/Panel/Box/Save") as Button).pressed.emit()


func _open_load_menu() -> void:
	pause.open()
	(pause.get_node("Root/Center/Panel/Box/Load") as Button).pressed.emit()


func _save_into(slot_id: String) -> bool:
	slots.select_slot(slot_id)
	slots.get_action_button().pressed.emit()
	if slots.is_confirming():
		slots.get_confirm_accept().pressed.emit()
	if not SaveSystem.is_busy():
		failures.append("el guardado no empezó: %s" % slots.get_status_text())
		return false
	var outcome: Array = await SaveSystem.save_finished
	return outcome[1]


func test_pause_save_shows_the_five_slots() -> void:
	_open_save_menu()
	check(slots.visible, "Guardar partida abre el expediente")
	check(not (pause.get_node("Root/Center/Panel") as Control).visible, "el panel de pausa se oculta")
	for slot_id in SaveSystem.get_slots():
		check(slots.get_row(slot_id) != null, "fila de %s" % slot_id)
	check_equal(slots.get_selected_slot(), "manual_1", "sin ranura activa se propone la primera libre")
	check(not slots.get_action_button().disabled, "y se puede guardar en ella")


func test_manual_save_from_the_pause_menu() -> void:
	game.player.teleport(game.player.global_position + Vector3(1.0, 0.0, 0.0), 0.0)
	_open_save_menu()
	check(await _save_into("manual_2"), "la partida se guarda")
	check(slots.get_status_text().contains("guardada"), "el menú confirma el resultado")
	check_equal(SaveSystem.get_slot_info("manual_2")["status"], SaveFormat.Status.OK, "la ranura queda ocupada")
	check(get_tree().paused, "el juego sigue en pausa")


func test_overwriting_asks_for_confirmation() -> void:
	_open_save_menu()
	await _save_into("manual_1")
	GameClock.minutes = 15 * 60
	slots.select_slot("manual_1")
	slots.get_action_button().pressed.emit()
	check(slots.is_confirming(), "una ranura ocupada pide confirmación")
	slots.get_confirm_cancel().pressed.emit()
	check(not slots.is_confirming(), "cancelar cierra la confirmación")
	check(not SaveSystem.is_busy(), "cancelar no guarda nada")
	check(await _save_into("manual_1"), "aceptar sobrescribe")
	check_equal(SaveSystem.get_slot_info("manual_1")["summary"]["minutes"], 15 * 60, "con el estado nuevo")


func test_deleting_asks_for_confirmation() -> void:
	_open_save_menu()
	await _save_into("manual_3")
	slots.select_slot("manual_3")
	slots.get_delete_button().pressed.emit()
	check(slots.is_confirming(), "eliminar pide confirmación")
	slots.get_confirm_cancel().pressed.emit()
	check_equal(SaveSystem.get_slot_info("manual_3")["status"], SaveFormat.Status.OK, "cancelar conserva la partida")
	slots.get_delete_button().pressed.emit()
	slots.get_confirm_accept().pressed.emit()
	check_equal(SaveSystem.get_slot_info("manual_3")["status"], SaveFormat.Status.EMPTY, "aceptar la elimina")


func test_escape_closes_confirmation_then_menu() -> void:
	_open_save_menu()
	await _save_into("manual_1")
	slots.select_slot("manual_1")
	slots.get_action_button().pressed.emit()
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	pause._input(escape)
	check(not slots.is_confirming() and slots.visible, "Esc cancela la confirmación")
	pause._input(escape)
	check(not slots.visible, "Esc cierra el expediente")
	check((pause.get_node("Root/Center/Panel") as Control).visible, "y vuelve a la pausa")
	check(pause.is_open, "sin cerrar la pausa")


## La salida real se sustituye: cambiar de escena eliminaría al ejecutor de pruebas.
func test_quit_to_menu_saves_automatically() -> void:
	await save_and_wait("manual_2")
	GameState.set_flag("progreso_antes_de_salir")
	pause.open()
	var targets: Array = []
	ExitManager.finish_override = func(target: int) -> void: targets.append(target)
	(pause.get_node("Root/Center/Panel/Box/Quit") as Button).pressed.emit()
	for frame in 120:
		if not targets.is_empty():
			break
		await get_tree().process_frame
	ExitManager.finish_override = Callable()
	check_equal(targets, [ExitManager.Target.MAIN_MENU], "vuelve al menú tras guardar")
	var latest := SaveSystem.find_latest_slot()
	check_equal(latest, "manual_2", "en la ranura activa")
	check_equal(SaveSystem.get_slot_info(latest)["summary"]["reason"], "salida", "con el motivo de salida")
	check(SaveSystem.read_slot(latest)["document"]["sections"].has("player"), "con la posición del detective")


func _open_main_menu() -> Node:
	var menu: Node = (load("res://scenes/main/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	return menu


## Partidas de ejemplo: dos válidas y un archivo dañado.
func _seed_slots() -> void:
	game.player.teleport(game.player.global_position + Vector3(1.0, 0.0, 0.5), 0.6)
	Investigation.discover_clue("carta_valdes")
	await save_and_wait("manual_2")
	await save_and_wait("manual_3")
	write_slot_file("manual_4", "{dañado")


func test_pause_load_warns_about_unsaved_progress() -> void:
	await _seed_slots()
	GameState.set_flag("progreso_sin_guardar")
	slots.load_ready.disconnect(pause._on_load_ready)
	_open_load_menu()
	check(slots.visible and slots.mode == SaveSlotsMenu.Mode.LOAD, "Cargar partida abre el expediente en modo carga")
	var loaded: Array[String] = []
	slots.load_ready.connect(func(slot_id: String) -> void: loaded.append(slot_id))
	slots.select_slot("manual_2")
	slots.get_action_button().pressed.emit()
	check(slots.is_confirming(), "avisa de que se perderá el progreso sin guardar")
	check(loaded.is_empty(), "no carga sin confirmar")
	slots.get_confirm_accept().pressed.emit()
	check_equal(loaded, ["manual_2"] as Array[String], "carga tras confirmar")
	check(SaveSystem.has_pending_load(), "la partida queda lista para la escena de juego")


func test_pause_load_without_progress_does_not_ask() -> void:
	await _seed_slots()
	slots.load_ready.disconnect(pause._on_load_ready)
	_open_load_menu()
	slots.select_slot("manual_3")
	slots.get_action_button().pressed.emit()
	check(not slots.is_confirming(), "sin progreso nuevo no hay nada que perder")
	check(SaveSystem.has_pending_load(), "carga directamente")


func test_empty_and_damaged_slots_cannot_be_loaded() -> void:
	await _seed_slots()
	_open_load_menu()
	slots.select_slot("manual_1")
	check_equal(slots.get_selected_slot(), "manual_1", "una ranura vacía se puede señalar")
	check(slots.get_action_button().disabled, "pero no cargar")
	check(slots.get_delete_button().disabled, "ni eliminar")
	slots.select_slot("manual_4")
	check(slots.get_action_button().disabled, "una dañada no se puede cargar")
	check(not slots.get_delete_button().disabled, "pero sí eliminar")
	check(not SaveSystem.request_load("manual_1")["ok"], "y el gestor también lo rechaza")


func test_main_menu_load_restores_the_saved_game() -> void:
	await _seed_slots()
	var saved_position := game.player.global_position
	game.queue_free()
	game = null
	await get_tree().process_frame
	GameState.reset()
	GameClock.reset()
	var menu := await _open_main_menu()
	var menu_slots: SaveSlotsMenu = menu.get_node("%SaveSlotsMenu")
	menu_slots.load_ready.disconnect(menu._on_load_ready)
	(menu.get_node("%Load") as Button).pressed.emit()
	check(menu_slots.visible, "el menú principal abre el expediente")
	check(not (menu.get_node("%Layout") as Control).visible, "ocultando el menú")
	menu_slots.select_slot("manual_2")
	menu_slots.get_action_button().pressed.emit()
	check(SaveSystem.has_pending_load(), "la carga queda preparada")
	menu.queue_free()
	await get_tree().process_frame
	game = await make_game()
	check(GameState.clues.has("carta_valdes"), "recupera las pistas")
	check(game.player.global_position.distance_to(saved_position) < 0.2, "y la posición del detective")
	check_equal(SaveSystem.get_active_slot(), "manual_2", "y la ranura cargada pasa a ser la activa")


func test_main_menu_without_saves_explains_and_lets_go_back() -> void:
	var menu := await _open_main_menu()
	var menu_slots: SaveSlotsMenu = menu.get_node("%SaveSlotsMenu")
	(menu.get_node("%Load") as Button).pressed.emit()
	check(menu_slots.get_hint_text().begins_with("Todavía no hay partidas"), "explica que no hay partidas")
	check(menu_slots.get_action_button().disabled, "no hay nada que cargar")
	check(not menu_slots.get_back_button().disabled, "Volver sigue disponible")
	menu_slots.get_back_button().pressed.emit()
	check((menu.get_node("%Menu") as Control).visible, "vuelve al menú principal")
	menu.queue_free()
	await get_tree().process_frame
