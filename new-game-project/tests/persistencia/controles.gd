extends Node
## Teclas personalizadas y restauradas al cerrar y volver a abrir el juego, en procesos distintos:
##   godot --headless --path . res://tests/persistencia/controles.tscn -- --fase=personalizar
##   godot --headless --path . res://tests/persistencia/controles.tscn -- --fase=comprobar
##   godot --headless --path . res://tests/persistencia/controles.tscn -- --fase=restaurados
## La primera cambia varias teclas (con un intercambio) y termina. La segunda, en un proceso nuevo,
## comprueba que el InputMap ya las usa al leer el archivo y restaura las de fábrica. La tercera, en
## otro proceso, comprueba que siguen las de fábrica y que las demás preferencias no se tocaron. Usa
## un archivo propio: nunca toca los ajustes del jugador.

const FILE := "user://pruebas_guardado/controles_reinicio.cfg"
const MUSIC := 0.4

var _failures := 0


func _ready() -> void:
	var phase := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fase="):
			phase = argument.trim_prefix("--fase=")
	match phase:
		"personalizar":
			_customize()
		"comprobar":
			_check_custom_and_restore()
		"restaurados":
			_check_restored()
		_:
			print("FALLO falta --fase=personalizar, comprobar o restaurados")
			_failures += 1
	print("RESUMEN: %s" % ("todo correcto" if _failures == 0 else "%d fallos" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _customize() -> void:
	DirAccess.make_dir_recursive_absolute(FILE.get_base_dir())
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	Settings.use_file(FILE)
	_check(Settings.set_value("audio/Musica", MUSIC), "se cambia también una preferencia de audio")
	_check(Controls.assign("interact", 0, KEY_F), "interactuar pasa a F")
	_check(Controls.swap("open_map", 0, KEY_B), "el mapa toma la B del tablero")
	_check(Controls.assign("move_forward", 1, KEY_I), "avanzar recibe I como alternativa")
	_check(FileAccess.file_exists(FILE), "las teclas quedan escritas")


func _check_custom_and_restore() -> void:
	_check(FileAccess.file_exists(FILE), "el archivo de la fase anterior existe")
	Settings.use_file(FILE)
	_check(_pressed(KEY_F, "interact"), "F interactúa nada más arrancar")
	_check(not _pressed(KEY_E, "interact"), "E ya no")
	_check(_pressed(KEY_B, "open_map"), "B abre el mapa")
	_check(_pressed(KEY_M, "open_board"), "M abre el tablero")
	_check(_pressed(KEY_I, "move_forward") and _pressed(KEY_W, "move_forward"), "avanzar con W o con I")
	Controls.restore_defaults()
	_check(Controls.customized_actions().is_empty(), "se restauran las de fábrica")


func _check_restored() -> void:
	_check(FileAccess.file_exists(FILE), "el archivo sigue existiendo")
	Settings.use_file(FILE)
	for action in InputBindings.action_ids():
		_check(Controls.get_keys(action) == InputBindings.default_keys(action), "%s sigue con su tecla de fábrica" % action)
	_check(_pressed(KEY_E, "interact") and not _pressed(KEY_F, "interact"), "E vuelve a interactuar")
	var config := ConfigFile.new()
	config.load(FILE)
	_check(not config.has_section("controles"), "no queda nada personalizado en el archivo")
	_check(is_equal_approx(float(Settings.get_value("audio/Musica")), MUSIC), "y el volumen de la música no cambió")
	DirAccess.remove_absolute(FILE)
	TestCase.reset_test_settings()


static func _pressed(code: Key, action: String) -> bool:
	var press := InputEventKey.new()
	press.physical_keycode = code
	press.pressed = true
	return press.is_action_pressed(action)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK ", message)
	else:
		_failures += 1
		print("FALLO ", message)
