class_name PauseMenu
extends CanvasLayer
## Menú de pausa con guardado manual, ajustes, controles y salida al menú principal.

const MAIN_MENU := "res://scenes/main/main_menu.tscn"
const CONTROLS_TEXT := "WASD o flechas: moverse\nMayús: correr\nE: interactuar y avanzar el diálogo\nJ o Tab: expediente\nB: tablero de deducción\nT: dejar pasar una hora\nEsc: pausa"

var is_open := false

@onready var _root: Control = $Root
@onready var _menu: VBoxContainer = $Root/Center/Panel/Box
@onready var _resume: Button = $Root/Center/Panel/Box/Resume
@onready var _save: Button = $Root/Center/Panel/Box/Save
@onready var _settings_button: Button = $Root/Center/Panel/Box/Settings
@onready var _controls_button: Button = $Root/Center/Panel/Box/Controls
@onready var _quit: Button = $Root/Center/Panel/Box/Quit
@onready var _status: Label = $Root/Center/Panel/Box/Status
@onready var _panel: PanelContainer = $Root/Center/Panel
@onready var _settings: SettingsPanel = $Root/Center/SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.theme = UiTheme.get_theme()
	_root.hide()
	_settings.hide()
	_resume.pressed.connect(close)
	_save.pressed.connect(_on_save_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_controls_button.pressed.connect(_on_controls_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_settings.closed.connect(func() -> void: _panel.show())


func open() -> void:
	is_open = true
	_status.text = ""
	_panel.show()
	_settings.hide()
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
		if _settings.visible:
			_settings.hide()
			_panel.show()
		else:
			close()


func _on_save_pressed() -> void:
	AudioManager.play("click")
	var slot_id: String = SaveSystem.get_manual_slots()[0]
	var result := SaveSystem.save_to_slot(slot_id)
	if not result["ok"]:
		_status.text = result["error"]
		return
	_status.text = "Guardando la partida…"
	var outcome: Array = await SaveSystem.save_finished
	_status.text = "Partida guardada." if outcome[1] else outcome[2]


func _on_settings_pressed() -> void:
	AudioManager.play("click")
	_panel.hide()
	_settings.show()


func _on_controls_pressed() -> void:
	AudioManager.play("click")
	_status.text = CONTROLS_TEXT


func _on_quit_pressed() -> void:
	AudioManager.play("click")
	_quit.disabled = true
	if SaveSystem.autosave("salida")["ok"]:
		await SaveSystem.save_finished
	get_tree().paused = false
	GameState.clear_player_locks()
	get_tree().change_scene_to_file(MAIN_MENU)
