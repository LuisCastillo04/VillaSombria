extends Node
## Herramienta de captura para revisar el juego renderizado sin intervención manual.
## Uso:  godot --path . --resolution 1280x720 res://tests/visual/captura.tscn -- --out=C:/ruta/img.png
## Argumentos:
##   --out=ruta            archivo de salida
##   --frames=N            fotogramas de espera antes de capturar
##   --location=id         escenario inicial        --spawn=id  punto de aparición
##   --pos=x,y,z           coloca al detective
##   --shots=x,y,z;x,y,z   guarda una imagen numerada por cada posición
##   --day=N --time=HH:MM  fija el calendario
##   --seed=todo           concede todas las pistas y testimonios
##   --pistas=a,b          concede sólo esas pistas, testimonios o deducciones (en ese orden)
##   --hipotesis=id=valoración[=nota],...   anota hipótesis antes de abrir el tablero
##   --flags=a,b           marca esos hechos de la historia antes de entrar en el escenario
##                         (llamada_atendida: el café sin la escena de la primera visita)
##   --dialogue-shots=A,B  abre una conversación con cada NPC y la captura
##   --escena=id           reproduce una escena narrativa de escenas.json y la captura
##   --pasos=a,a,2         con --dialogue-shots o --escena, antes de capturar: «a» avanza una
##                         intervención y un número elige esa respuesta (1 la primera)
##   --open=clue:id | journal:n[:ficha] | board | accusation | pause | closed | save | load | confirm
##                         | exit | saving | saved | settings:n | controls:n | map[:lugar] | esperar
##                         | reasignar:n | mando:n | restaurar
##                         (settings y controls se abren desde la pausa; n es la categoría;
##                         map abre el mapa con la tecla M y, con un lugar, señala su chincheta;
##                         esperar pulsa la tecla de dejar pasar una hora; reasignar abre la
##                         pantalla de reasignar teclas en la categoría n; mando, la del esquema
##                         del mando; las dos, con su fila de Controles; restaurar pide restaurar
##                         las teclas de fábrica)
##                         (clue:id examina la prueba como el jugador: si es nueva aparece
##                         «Evidencia obtenida», que se ve entre los fotogramas 10 y 180; con
##                         --pistas=id ya está registrada y se relee sin aviso)
##   --mando[=estilo]      rótulos del mando en lugar de los del teclado; estilo: xbox (por
##                         defecto), playstation o nintendo
##   --esperar-tecla=accion[:hueco]
##                         con --open=reasignar, elige ese hueco (0 principal, 1 alternativa) y
##                         lo deja esperando la tecla nueva
##   --seleccion=a,b       con --open=board, elige esos elementos para compararlos
##   --relacionar          con --open=board y --seleccion, pulsa «Relacionar»
##   --editar=id           con --open=board, abre la hipótesis de ese sospechoso
##   --desplegar           con --editar, despliega el selector de valoración
##   --menu                captura el menú principal en lugar de la partida
##                         (con --open=load, la lista de partidas con ejemplos;
##                         con --open=settings:n o --open=credits, esos paneles)
##   --focus=Nombre        en el menú, señala esa opción (NewGame, Continue, Load...)
##   --press=Nombre        en el menú, deja el ratón pulsado sobre esa opción
##   --sin-partidas        en el menú, vacía las ranuras de las capturas
##   --intro               reproduce la introducción narrativa
##   --stats               mide fotogramas por segundo y llamadas de dibujado
##   --ajustes=clave=valor;clave=valor
##                         preferencias de Configuración antes de capturar, con las claves de
##                         SettingsSchema (graficos/calidad_iluminacion=bajo;accesibilidad/tamano_letra=grande).
##                         Las capturas parten siempre de los valores por defecto.

const GAME_SCENE := "res://scenes/main/game.tscn"
const MENU_SCENE := "res://scenes/main/main_menu.tscn"


func _ready() -> void:
	var args := _parse_args()
	SaveSystem.autosave_enabled = false
	SaveSystem.use_storage("user://pruebas_guardado/capturas")
	_apply_settings(args)
	if args.has("mando"):
		Controls.style_override = String(args["mando"]) if String(args["mando"]) in InputLabels.STYLE_NAMES else "xbox"
		Controls.set_using_gamepad(true)
	if args.has("menu"):
		await _capture_menu(args)
		get_tree().quit()
		return
	Game.play_intro = args.has("intro")
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await _wait_seconds(0.2)
	if args.has("day"):
		GameClock.day = int(args["day"])
	if args.has("time"):
		GameClock.minutes = GameClock.parse_time(args["time"])
		GameClock.advance(1)
	if args.get("seed", "") == "todo":
		_grant_everything()
	if args.has("pistas"):
		_grant_items((args["pistas"] as String).split(","))
	if args.has("hipotesis"):
		for entry: String in (args["hipotesis"] as String).split(","):
			var parts := entry.split("=")
			Investigation.set_hypothesis(parts[0], parts[1], parts[2] if parts.size() > 2 else "")
	if args.has("flags"):
		for flag: String in (args["flags"] as String).split(","):
			GameState.set_flag(flag)
	if args.has("location"):
		await game.go_to(args["location"], args.get("spawn", ""))
	var out: String = args.get("out", "user://captura.png")
	var frames := int(args.get("frames", "60"))
	if args.has("dialogue-shots"):
		for npc_id: String in (args["dialogue-shots"] as String).split(","):
			DialogueManager.start(npc_id)
			await _follow_steps(game, args)
			await _save_frame(out.get_basename() + "_%s.png" % npc_id, frames)
			DialogueManager.close()
			await _wait_seconds(0.4)
	elif args.has("escena"):
		DialogueManager.play_scene(args["escena"])
		await _follow_steps(game, args)
		await _save_frame(out, frames)
	elif args.has("shots"):
		var index := 1
		for shot: String in (args["shots"] as String).split(";"):
			_place_player(game, shot)
			await _save_frame(out.get_basename() + "_%d.png" % index, frames)
			index += 1
	else:
		if args.has("pos"):
			_place_player(game, args["pos"])
		if args.has("open"):
			await _open_panel(game, args["open"])
		await _save_frame(out, frames)
	get_tree().quit()


## Recorre la conversación como el jugador: «a» avanza una intervención y un número elige esa
## respuesta de las que muestra la interfaz.
func _follow_steps(game: Game, args: Dictionary) -> void:
	if not args.has("pasos"):
		return
	var ui: DialogueUi = game.get_node("DialogueUi")
	for step: String in (args["pasos"] as String).split(","):
		await _wait_seconds(0.5)
		if step == "a":
			DialogueManager.advance()
		elif step.is_valid_int() and int(step) >= 1 and int(step) <= ui.get_option_ids().size():
			DialogueManager.choose(ui.get_option_ids()[int(step) - 1])


func _capture_menu(args: Dictionary) -> void:
	var opened: String = args.get("open", "")
	if opened == "load":
		await _seed_slots()
	elif args.has("sin-partidas"):
		_remove_slots()
	var menu := (load(MENU_SCENE) as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var parts := opened.split(":")
	match parts[0]:
		"load":
			(menu.get_node("%Load") as Button).pressed.emit()
			(menu.get_node("%SaveSlotsMenu") as SaveSlotsMenu).select_slot("manual_1")
		"settings":
			(menu.get_node("%Settings") as Button).pressed.emit()
			if parts.size() > 1:
				(menu.get_node("%SettingsMenu") as CategoryMenu).select_category(int(parts[1]))
		"credits":
			(menu.get_node("%Credits") as Button).pressed.emit()
	if args.has("focus"):
		(menu.get_node("%" + args["focus"]) as Control).grab_focus()
	if args.has("press"):
		_hold_mouse_on(menu.get_node("%" + args["press"]) as Control)
	await _save_frame(args.get("out", "user://menu.png"), int(args.get("frames", "120")))


## Lleva el ratón al centro del control y deja el botón izquierdo pulsado, como a mitad de un clic.
func _hold_mouse_on(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	get_viewport().push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = center
	click.global_position = center
	get_viewport().push_input(click, true)


func _remove_slots() -> void:
	for slot_id: String in SaveSystem.get_slots():
		SaveFile.remove(SaveSystem.get_slot_path(slot_id))


func _open_panel(game: Game, what: String) -> void:
	var parts := what.split(":")
	match parts[0]:
		"clue":
			EventBus.clue_inspection_requested.emit(parts[1])
		"journal":
			var journal: JournalUi = game.get_node("JournalUi")
			journal.open(int(parts[1]))
			if parts.size() > 2:
				journal.get_section(int(parts[1])).get_list().select(parts[2])
		"board":
			var board: BoardUi = game.get_node("BoardUi")
			board.open()
			await _wait_seconds(0.4)
			var args := _parse_args()
			if args.has("seleccion"):
				for item_id: String in (args["seleccion"] as String).split(","):
					board.select_item(item_id)
			if args.has("relacionar"):
				board.link_selected()
			if args.has("editar"):
				board.open_hypothesis(args["editar"])
				if args.has("desplegar"):
					await _wait_seconds(0.3)
					var option := board.get_viewport().gui_get_focus_owner() as OptionButton
					if option != null:
						option.show_popup()
		"accusation":
			game.get_node("AccusationUi").open()
		"pause":
			game.get_node("PauseMenu").open()
		"settings", "controls":
			# La pausa congelaría el fundido de entrada a medias.
			await _wait_seconds(0.6)
			var pause: PauseMenu = game.get_node("PauseMenu")
			pause.open()
			var button := "Settings" if parts[0] == "settings" else "Controls"
			(pause.get_node("Root/Center/Panel/Box/" + button) as Button).pressed.emit()
			if parts.size() > 1:
				var screen: CategoryMenu = pause.get_node("Root/SettingsMenu" if parts[0] == "settings" else "Root/ControlsMenu")
				screen.select_category(int(parts[1]))
		"save":
			await _seed_slots()
			# La pausa congelaría el fundido de entrada a medias.
			await _wait_seconds(0.6)
			var pause: PauseMenu = game.get_node("PauseMenu")
			pause.open()
			(pause.get_node("Root/Center/Panel/Box/Save") as Button).pressed.emit()
			var slots: SaveSlotsMenu = pause.get_node("Root/SaveSlotsMenu")
			slots.select_slot("manual_1")
		"load", "confirm":
			await _seed_slots()
			await _wait_seconds(0.6)
			var pause: PauseMenu = game.get_node("PauseMenu")
			pause.open()
			var button := "Load" if what == "load" else "Save"
			(pause.get_node("Root/Center/Panel/Box/" + button) as Button).pressed.emit()
			var slots: SaveSlotsMenu = pause.get_node("Root/SaveSlotsMenu")
			slots.select_slot("manual_2")
			if what == "confirm":
				slots.get_action_button().pressed.emit()
		"mando", "reasignar", "restaurar":
			# Como el jugador: la pausa, Controles, «Otros» y la fila de la herramienta.
			await _wait_seconds(0.6)
			var pause: PauseMenu = game.get_node("PauseMenu")
			pause.open()
			(pause.get_node("Root/Center/Panel/Box/Controls") as Button).pressed.emit()
			var controls: ControlsMenu = pause.get_node("Root/ControlsMenu")
			controls.select_category(ControlsMenu.CATEGORIES.size() - 1)
			await get_tree().process_frame
			controls.get_tool(parts[0]).pressed.emit()
			await get_tree().process_frame
			var screen: CategoryMenu = controls.get_gamepad_menu() if parts[0] == "mando" else controls.get_rebind_menu()
			if parts[0] != "restaurar" and parts.size() > 1:
				screen.select_category(int(parts[1]))
			var rebind := controls.get_rebind_menu()
			var args := _parse_args()
			if args.has("esperar-tecla"):
				var target := String(args["esperar-tecla"]).split(":")
				await get_tree().process_frame
				var slot := rebind.get_row(target[0]).get_slot(int(target[1]) if target.size() > 1 else 0)
				slot.grab_focus()
				slot.pressed.emit()
		"esperar":
			# La tecla de dejar pasar una hora, con las confirmaciones activadas.
			await _wait_seconds(0.6)
			for pressed: bool in [true, false]:
				var event := InputEventAction.new()
				event.action = "wait_time"
				event.pressed = pressed
				game.get_viewport().push_input(event)
		"exit":
			await _wait_seconds(0.6)
			GameState.set_flag("captura_sin_ranura")
			ExitManager.finish_override = func(_target: int) -> void: pass
			ExitManager.request_exit(ExitManager.Target.QUIT)
		"saving":
			SaveIndicator.min_saving_seconds = 30.0
			SaveSystem.save_to_slot("manual_1")
		"saved":
			SaveIndicator.saved_seconds = 30.0
			if SaveSystem.save_to_slot("manual_1")["ok"]:
				await SaveSystem.save_finished
			await _wait_seconds(SaveIndicator.min_saving_seconds + 0.3)
		"closed":
			game.get_node("CaseClosedUi").open()
		"map":
			# La pausa congelaría el fundido de entrada a medias.
			await _wait_seconds(0.6)
			var pause: PauseMenu = game.get_node("PauseMenu")
			pause.open_map()
			if parts.size() > 1:
				var map: MapScreen = pause.get_node("Root/MapScreen")
				map.get_view().get_pin(parts[1]).grab_focus()


## Partidas de ejemplo en la carpeta de las capturas, nunca en la del jugador.
func _seed_slots() -> void:
	var own_session := not SaveSystem.has_session()
	if own_session:
		GameState.location_id = "mansion"
		GameClock.day = 2
		GameClock.minutes = 14 * 60 + 30
		GameState.play_seconds = 3900.0
		for clue_id: String in ["reloj_despacho", "lista_invitados", "carta_valdes"]:
			Investigation.discover_clue(clue_id)
		SaveSystem.begin_session(self)
	_remove_slots()
	for slot_id: String in ["manual_1", "manual_2"]:
		if SaveSystem.save_to_slot(slot_id)["ok"]:
			await SaveSystem.save_finished
	if SaveSystem.autosave("lugar")["ok"]:
		await SaveSystem.save_finished
	if own_session:
		SaveSystem.end_session(self)
	var damaged := FileAccess.open(SaveSystem.get_slot_path("manual_3"), FileAccess.WRITE)
	damaged.store_string("{dañado")
	damaged.close()


func _grant_everything() -> void:
	for clue_id: String in GameData.clues:
		Investigation.discover_clue(clue_id)
	for testimony_id: String in GameData.testimonies:
		Investigation.record_testimony(testimony_id)
	# Dos pasadas: algunas deducciones dependen de otras.
	for pass_index in 2:
		for deduction_id: String in GameData.deductions:
			var pair: Array = GameData.deductions[deduction_id]["pairs"][0]
			Investigation.try_link(pair[0], pair[1])


## Pistas, testimonios o deducciones concretos, como los tendría el jugador a mitad del caso.
func _grant_items(ids: PackedStringArray) -> void:
	for item_id in ids:
		if GameData.clues.has(item_id):
			Investigation.discover_clue(item_id)
		elif GameData.testimonies.has(item_id):
			Investigation.record_testimony(item_id)
		elif GameData.deductions.has(item_id) and not GameState.deductions.has(item_id):
			GameState.deductions.append(item_id)


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _place_player(game: Game, text: String) -> void:
	var parts := text.split(",")
	game.player.teleport(Vector3(float(parts[0]), float(parts[1]), float(parts[2])), 0.0)
	game.camera.snap()


func _save_frame(path: String, frames: int) -> void:
	for frame in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if OS.get_cmdline_user_args().has("--stats"):
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var primitives := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("ESTADISTICAS fps=%d dibujados=%d primitivas=%d" % [Engine.get_frames_per_second(), draws, primitives])
	var image := get_viewport().get_texture().get_image()
	print("Captura ", path, " código ", image.save_png(path))


## Las capturas usan los ajustes de las pruebas, con lo que pida `--ajustes`.
func _apply_settings(args: Dictionary) -> void:
	TestCase.reset_test_settings()
	for entry: String in String(args.get("ajustes", "")).split(";", false):
		var pair := entry.split("=", true, 1)
		var key := pair[0].strip_edges()
		var value: Variant = pair[1].strip_edges() if pair.size() > 1 else ""
		if SettingsSchema.has_key(key) and typeof(SettingsSchema.default_value(key)) == TYPE_BOOL:
			value = value in ["1", "true", "si", "sí"]
		if not Settings.set_value(key, value):
			push_warning("Ajuste de captura no válido: %s" % entry)


func _parse_args() -> Dictionary:
	var result := {}
	for raw in OS.get_cmdline_user_args():
		var pair := raw.trim_prefix("--").split("=", true, 1)
		result[pair[0]] = pair[1] if pair.size() > 1 else "1"
	return result
