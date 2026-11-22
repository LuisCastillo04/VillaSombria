extends Node
## Graba la salida real de audio del juego durante un recorrido guionizado, para escucharla y
## analizarla sin jugar. No es una prueba: produce un WAV y una lista de marcas de tiempo.
##
## Uso:  godot --headless --path . res://tests/visual/escucha.tscn -- --out=C:/ruta/escucha.wav
## (sin ventana Godot usa el controlador «Dummy», que mezcla en tiempo real; con ventana se oye
## además por los altavoces).
##
## Recorrido (unos cuatro minutos): menú principal y navegación; introducción en el andén, sin
## música; llegada de la música del pueblo; pasos hasta la plaza y campanadas de la torre; la llamada
## del café con el teléfono; jazz y murmullo; una conversación (la música se aparta); la puerta de la
## mansión, el reloj de pie y la chimenea; una pista y un suceso inquietante; la pausa amortiguada;
## el archivo; la acusación, la confrontación y el epílogo.

const STEP_SECONDS := 2.2

var _record: AudioEffectRecord
var _marks: PackedStringArray = []
var _start_ms := 0
var _game: Game
var _choices_pending := false


func _ready() -> void:
	var out := _argument("--out", "user://escucha_audio.wav")
	SaveSystem.autosave_enabled = false
	SaveSystem.use_storage("user://pruebas_guardado/escucha")
	# Volúmenes por defecto, sin tocar ni leer las preferencias del jugador.
	var settings_file := "user://pruebas_guardado/escucha/ajustes.cfg"
	DirAccess.make_dir_recursive_absolute(settings_file.get_base_dir())
	if FileAccess.file_exists(settings_file):
		DirAccess.remove_absolute(settings_file)
	Settings.use_file(settings_file)
	_record = AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _record)
	_record.set_recording_active(true)
	_start_ms = Time.get_ticks_msec()
	DialogueManager.options_shown.connect(func(_options: Array) -> void: _choices_pending = true)
	DialogueManager.line_shown.connect(func(_speaker: String, _text: String) -> void: _choices_pending = false)
	await _tour()
	_record.set_recording_active(false)
	var recording := _record.get_recording()
	var error := recording.save_to_wav(out) if recording != null else ERR_CANT_CREATE
	var marks := FileAccess.open(out.get_basename() + ".txt", FileAccess.WRITE)
	if marks != null:
		marks.store_string("\n".join(_marks) + "\n")
	print("Grabación: %s (%s), %d marcas" % [out, error_string(error), _marks.size()])
	if is_instance_valid(_game):
		_game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if error == OK else 1)


func _tour() -> void:
	# Menú principal.
	var menu: Node = (load("res://scenes/main/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	_mark("Menú principal: tema «Villa Sombría», lluvia y viento")
	await _wait(9.0)
	_mark("Navegación por el menú (ui_mover)")
	for index in 4:
		_press("ui_down")
		await _wait(0.45)
	await _wait(2.0)
	_mark("Nueva partida: el tema se retira")
	menu.queue_free()
	await get_tree().process_frame

	# Partida nueva con la introducción.
	Game.play_intro = true
	_game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(_game)
	await _wait(1.0)
	_mark("Introducción en el andén: sin música, lluvia y locomotora")
	await _play_dialogue(30.0)
	_mark("Fin de la introducción: entra la música del pueblo (pista de la carta)")
	await _wait(9.0)

	_mark("Pasos hacia la plaza")
	EventBus.location_change_requested.emit("plaza", "desde_estacion")
	await _wait(8.0)
	_mark("La torre da las nueve (pasa la hora)")
	GameClock.minutes = 8 * 60 + 55
	EventBus.time_changed.emit(GameClock.day, GameClock.minutes)
	GameClock.advance(10)
	await _wait(6.0)

	_mark("Puerta del café con campanilla; la llamada (silencio y teléfono)")
	EventBus.location_change_requested.emit("cafe", "desde_plaza")
	await _wait(1.5)
	await _play_dialogue(30.0)
	_mark("Café: jazz de gramófono, murmullo y vajilla")
	await _wait(12.0)
	_mark("Conversación con Rosa: la música y el ambiente se apartan")
	DialogueManager.start("rosa")
	await _wait(6.0)
	DialogueManager.close()
	_mark("Fin de la conversación: vuelven")
	await _wait(5.0)

	_mark("Salida a la calle")
	EventBus.location_change_requested.emit("plaza", "desde_cafe")
	await _wait(5.0)
	_mark("Puerta de la mansión: casa grande, reloj de pie y chimenea")
	EventBus.location_change_requested.emit("mansion", "desde_plaza")
	await _wait(12.0)
	_mark("Pista descubierta")
	Investigation.discover_clue("reloj_despacho")
	await _wait(6.0)
	_mark("Suceso inquietante: sube la tensión")
	EventBus.notification_requested.emit("Rumores en el pueblo", "Algo ha pasado.", "historia")
	await _wait(10.0)
	_mark("Pausa: todo se amortigua")
	(_game.get_node("PauseMenu") as PauseMenu).open()
	await _wait(5.0)
	(_game.get_node("PauseMenu") as PauseMenu).close()
	_mark("Fin de la pausa")
	await _wait(4.0)

	_mark("Archivo municipal: legajos y mecanismo de la torre")
	EventBus.location_change_requested.emit("plaza", "desde_mansion")
	await _wait(3.0)
	EventBus.location_change_requested.emit("archivo", "desde_plaza")
	await _wait(12.0)

	_mark("Tercer día en la mansión: más tensión de fondo")
	GameClock.day = 3
	GameState.set_flag("hora_real_conocida")
	EventBus.location_change_requested.emit("plaza", "desde_archivo")
	await _wait(3.0)
	EventBus.location_change_requested.emit("mansion", "desde_plaza")
	await _wait(10.0)
	_mark("Acusación")
	(_game.get_node("AccusationUi") as AccusationUi).open()
	await _wait(7.0)
	_mark("Acusación fallida")
	AudioManager.play("acusacion_fallida")
	await _wait(4.0)
	(_game.get_node("AccusationUi") as AccusationUi).close()
	_mark("Confrontación: la misma pieza, a plena tensión")
	DialogueManager.play_scene("confrontacion")
	await _play_dialogue(40.0)
	_mark("Epílogo y caso cerrado")
	await _play_dialogue(30.0)
	await _wait(10.0)
	_mark("Fin")


## Avanza la conversación en curso como un jugador que lee: una intervención cada pocos segundos
## y la primera respuesta cuando hay que elegir.
func _play_dialogue(limit: float) -> void:
	var elapsed := 0.0
	await _wait(0.5)
	while DialogueManager.active and elapsed < limit:
		await _wait(STEP_SECONDS)
		elapsed += STEP_SECONDS
		if not DialogueManager.active:
			break
		if _choices_pending:
			_choices_pending = false
			DialogueManager.choose("0")
		else:
			DialogueManager.advance()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func _mark(text: String) -> void:
	var seconds := (Time.get_ticks_msec() - _start_ms) / 1000.0
	_marks.append("%6.1f s  %s" % [seconds, text])
	print(_marks[-1])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


static func _argument(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(key + "="):
			return argument.trim_prefix(key + "=")
	return fallback
