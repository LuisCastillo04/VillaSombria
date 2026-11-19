class_name PauseMenu
extends CanvasLayer
## Menú de pausa con guardado y carga de partidas, ajustes, controles y salida al menú principal.

const GAME_SCENE := "res://scenes/main/game.tscn"
const CONTROLS_TEXT := "WASD o flechas: moverse\nMayús: correr\nE: interactuar y avanzar el diálogo\nJ o Tab: expediente\nB: tablero de deducción\nT: dejar pasar una hora\nEsc: pausa"
const UNSAVED_WARNING := "Lo que hayas avanzado desde el último guardado se perderá. ¿Cargar esta partida?"

var is_open := false

@onready var _root: Control = $Root
@onready var _menu: VBoxContainer = $Root/Center/Panel/Box
@onready var _resume: Button = $Root/Center/Panel/Box/Resume
@onready var _save: Button = $Root/Center/Panel/Box/Save
@onready var _load: Button = $Root/Center/Panel/Box/Load
@onready var _settings_button: Button = $Root/Center/Panel/Box/Settings
@onready var _controls_button: Button = $Root/Center/Panel/Box/Controls
@onready var _quit: Button = $Root/Center/Panel/Box/Quit
@onready var _status: Label = $Root/Center/Panel/Box/Status
@onready var _slot_info: Label = $Root/Center/Panel/Box/SlotInfo
@onready var _panel: PanelContainer = $Root/Center/Panel
@onready var _settings: SettingsPanel = $Root/Center/SettingsPanel
@onready var _slots: SaveSlotsMenu = $Root/SaveSlotsMenu


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
	_refresh_slot_info()
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
	# Con la pregunta de salida en pantalla, Escape es suyo.
	if ExitManager.is_dialog_open():
		return
	if is_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
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


## Recuerda en qué ranura guardan los autoguardados, o que todavía no hay ninguna.
func _refresh_slot_info() -> void:
	var active := SaveSystem.get_active_slot()
	if active.is_empty():
		_slot_info.text = "Autoguardado en espera: guarda en una ranura para activarlo."
		_slot_info.add_theme_color_override("font_color", UiTheme.STAMP)
	else:
		_slot_info.text = "Ranura activa: %02d · los autoguardados van a ella" % SaveSystem.get_slot_number(active)
		_slot_info.add_theme_color_override("font_color", UiTheme.INK_SOFT)


func _on_slots_closed() -> void:
	_refresh_slot_info()
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


## Vuelve al menú principal por el mismo camino que el cierre del juego: guarda en la
## ranura activa y, si no puede, pregunta.
func _on_quit_pressed() -> void:
	AudioManager.play("click")
	ExitManager.request_exit(ExitManager.Target.MAIN_MENU)
