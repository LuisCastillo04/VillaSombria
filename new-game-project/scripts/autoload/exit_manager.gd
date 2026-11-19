extends CanvasLayer
## Cierre controlado del juego. La X de la ventana y Alt + F4 llegan como
## `NOTIFICATION_WM_CLOSE_REQUEST`; los botones «Salir» y «Guardar y volver al menú» llaman a
## `request_exit`. Todos siguen el mismo camino: guardar en la ranura activa con
## `SaveSystem.save_for_exit`, comprobar el resultado y sólo entonces salir.
##
## Si no se puede guardar (la partida no tiene ranura o la escritura falla) no se sale: se
## pregunta al jugador. Un cierre forzado por el sistema operativo, un fallo grave o un corte
## de corriente no pasan por aquí y no se pueden garantizar.

enum Target { QUIT, MAIN_MENU }

const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"

## Sustituye la salida real; las pruebas lo usan para no cerrar el ejecutor.
var finish_override: Callable

var _exiting := false
var _target := Target.QUIT
var _paused_before := false
var _choosing_slot := false
var _retry_after_failure := false

@onready var _root: Control = $Root
@onready var _dialog: PanelContainer = $Root/Center/Dialog
@onready var _title: Label = $Root/Center/Dialog/Box/Title
@onready var _message: Label = $Root/Center/Dialog/Box/Message
@onready var _primary: Button = $Root/Center/Dialog/Box/Buttons/Primary
@onready var _leave: Button = $Root/Center/Dialog/Box/Buttons/Leave
@onready var _cancel: Button = $Root/Center/Dialog/Box/Buttons/Cancel
@onready var _slots: SaveSlotsMenu = $Root/SaveSlotsMenu


func _ready() -> void:
	# Sin esto Godot cerraría la ventana sin dar ocasión de guardar.
	get_tree().auto_accept_quit = false
	_root.theme = UiTheme.get_theme()
	_title.add_theme_font_override("font", UiTheme.serif())
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", UiTheme.STAMP)
	_root.hide()
	_slots.hide()
	_primary.pressed.connect(_on_primary_pressed)
	_leave.pressed.connect(_on_leave_pressed)
	_cancel.pressed.connect(_on_cancel_pressed)
	_slots.closed.connect(_on_slots_closed)
	SaveSystem.save_finished.connect(_on_save_finished)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_exit(Target.QUIT)


func _input(event: InputEvent) -> void:
	if not is_dialog_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _slots.visible:
			_slots.cancel()
		else:
			_on_cancel_pressed()


## Única entrada para salir del juego o volver al menú principal. Las peticiones repetidas
## mientras hay una en curso se ignoran.
func request_exit(target: Target = Target.QUIT) -> void:
	if _exiting:
		return
	_exiting = true
	_target = target
	var outcome: Dictionary = await SaveSystem.save_for_exit()
	match outcome["status"]:
		"saved", "nothing":
			_finish()
		"no_slot":
			_ask("PARTIDA SIN RANURA", outcome["message"] + " Elige una ranura para guardarla antes de salir.", "Elegir ranura", false)
		_:
			_ask("ERROR AL GUARDAR", "No se pudo guardar la partida antes de salir. " + outcome["message"], "Reintentar", true)


func is_exiting() -> bool:
	return _exiting


## Hay una pregunta o una lista de ranuras del cierre en pantalla.
func is_dialog_open() -> bool:
	return _root.visible


func _ask(title: String, message: String, primary_label: String, retry: bool) -> void:
	_retry_after_failure = retry
	_title.text = title
	_message.text = message
	_primary.text = primary_label
	_leave.text = "Salir sin guardar" if _target == Target.QUIT else "Volver sin guardar"
	if not _root.visible:
		_paused_before = get_tree().paused
		get_tree().paused = true
	_root.show()
	$Root/Dim.show()
	_dialog.show()
	_slots.hide()
	_cancel.grab_focus()


func _on_primary_pressed() -> void:
	AudioManager.play("click")
	if _retry_after_failure:
		_close_dialog()
		_exiting = false
		request_exit(_target)
		return
	_choosing_slot = true
	_dialog.hide()
	$Root/Dim.hide()
	_slots.for_exit = true
	_slots.open(SaveSlotsMenu.Mode.SAVE)


func _on_leave_pressed() -> void:
	AudioManager.play("click")
	_finish()


func _on_cancel_pressed() -> void:
	AudioManager.play("click")
	_close_dialog()
	get_tree().paused = _paused_before
	_exiting = false


func _on_slots_closed() -> void:
	if not _choosing_slot:
		return
	_choosing_slot = false
	_slots.for_exit = false
	$Root/Dim.show()
	_dialog.show()
	_primary.grab_focus()


## Tras elegir ranura, se sale en cuanto el guardado termina bien.
func _on_save_finished(_slot_id: String, ok: bool, _message: String) -> void:
	if _choosing_slot and ok:
		_choosing_slot = false
		_slots.for_exit = false
		_finish()


func _close_dialog() -> void:
	_choosing_slot = false
	_slots.for_exit = false
	_slots.hide()
	_root.hide()


func _finish() -> void:
	_close_dialog()
	if finish_override.is_valid():
		_exiting = false
		finish_override.call(_target)
		return
	match _target:
		Target.QUIT:
			# Queda en estado de salida: ninguna petición más puede empezar otro guardado.
			get_tree().quit()
		Target.MAIN_MENU:
			get_tree().paused = false
			GameState.clear_player_locks()
			_exiting = false
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
