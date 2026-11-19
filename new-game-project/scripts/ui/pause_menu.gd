class_name PauseMenu
extends CanvasLayer
## Menú de pausa con guardado y carga de partidas, ajustes, controles y salida al menú principal.

const MAIN_MENU := "res://scenes/main/main_menu.tscn"
const GAME_SCENE := "res://scenes/main/game.tscn"
const CONTROLS_TEXT := "WASD o flechas: moverse\nMayús: correr\nE: interactuar y avanzar el diálogo\nJ o Tab: expediente\nB: tablero de deducción\nT: dejar pasar una hora\nEsc: pausa"
const QUIT_TEXT := "Guardar y volver al menú"
const UNSAVED_WARNING := "Lo que hayas avanzado desde el último guardado se perderá. ¿Cargar esta partida?"

var is_open := false
## Tras un guardado fallido, la siguiente pulsación sale sin guardar.
var _quit_without_saving := false

@onready var _root: Control = $Root
@onready var _menu: VBoxContainer = $Root/Center/Panel/Box
@onready var _resume: Button = $Root/Center/Panel/Box/Resume
@onready var _save: Button = $Root/Center/Panel/Box/Save
@onready var _load: Button = $Root/Center/Panel/Box/Load
@onready var _settings_button: Button = $Root/Center/Panel/Box/Settings
@onready var _controls_button: Button = $Root/Center/Panel/Box/Controls
@onready var _quit: Button = $Root/Center/Panel/Box/Quit
@onready var _status: Label = $Root/Center/Panel/Box/Status
@onready var _panel: PanelContainer = $Root/Center/Panel
@onready var _settings: SettingsPanel = $Root/Center/SettingsPanel
@onready var _slots: SaveSlotsMenu = $Root/Center/SaveSlotsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.theme = UiTheme.get_theme()
	_root.hide()
	_settings.hide()
	_slots.hide()
	_resume.pressed.connect(close)
	_save.pressed.connect(_on_save_pressed)
	_load.pressed.connect(_on_load_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_controls_button.pressed.connect(_on_controls_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_settings.closed.connect(func() -> void: _panel.show())
	_slots.closed.connect(_on_slots_closed)
	_slots.load_ready.connect(_on_load_ready)


func open() -> void:
	is_open = true
	_status.text = ""
	_quit_without_saving = false
	_quit.text = QUIT_TEXT
	_quit.disabled = false
	_panel.show()
	_settings.hide()
	_slots.hide()
	_root.show()
	get_tree().paused = true
	GameState.lock_player("pausa")
	_resume.grab_focus()


func close() -> void:
	is_open = false
	_root.hide()
	get_tree().paused = false
	GameState.unlock_player("pausa")


func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _slots.visible:
			_slots.cancel()
		elif _settings.visible:
			_settings.hide()
			_panel.show()
		else:
			close()


func _on_save_pressed() -> void:
	AudioManager.play("click")
	_status.text = ""
	_panel.hide()
	_slots.open(SaveSlotsMenu.Mode.SAVE)


## Cargar sustituye la partida en curso: si ha avanzado desde el último guardado, se avisa.
func _on_load_pressed() -> void:
	AudioManager.play("click")
	_status.text = ""
	_panel.hide()
	_slots.load_warning = UNSAVED_WARNING if SaveSystem.has_unsaved_progress() else ""
	_slots.open(SaveSlotsMenu.Mode.LOAD)


func _on_slots_closed() -> void:
	_panel.show()
	(_load if _slots.mode == SaveSlotsMenu.Mode.LOAD else _save).grab_focus()


## La escena de juego se vuelve a crear y recoge la partida pendiente al arrancar.
func _on_load_ready(_slot_id: String) -> void:
	get_tree().paused = false
	GameState.clear_player_locks()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	AudioManager.play("click")
	_panel.hide()
	_settings.show()


func _on_controls_pressed() -> void:
	AudioManager.play("click")
	_status.text = CONTROLS_TEXT


## Sale al menú principal con un autoguardado. Si la escritura falla no sale: avisa y
## deja que el jugador decida salir sin guardar con una segunda pulsación.
func _on_quit_pressed() -> void:
	AudioManager.play("click")
	if not _quit_without_saving:
		_quit.disabled = true
		var saved := await _save_before_leaving()
		_quit.disabled = false
		if not saved:
			_status.text = "No se pudo guardar la partida. Pulsa otra vez para salir sin guardar."
			_quit.text = "Salir sin guardar"
			_quit_without_saving = true
			return
	get_tree().paused = false
	GameState.clear_player_locks()
	get_tree().change_scene_to_file(MAIN_MENU)


## Devuelve false sólo si se intentó escribir y falló. Si no hay nada que guardar, como
## con el caso ya cerrado, se puede salir igualmente.
func _save_before_leaving() -> bool:
	if SaveSystem.is_busy():
		await SaveSystem.save_finished
	if not SaveSystem.autosave("salida")["ok"]:
		return true
	var outcome: Array = await SaveSystem.save_finished
	return outcome[1]
