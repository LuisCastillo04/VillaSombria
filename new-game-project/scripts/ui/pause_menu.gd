class_name PauseMenu
extends CanvasLayer
## Menú de pausa con el mapa del pueblo, guardado y carga de partidas, configuración, controles y
## salida al menú principal. El escenario sigue visible detrás, congelado por la pausa del árbol;
## las pantallas del mapa, configuración, controles y partidas se abren encima y, al volver, el foco
## regresa a la opción que las abrió. Todo aparece y desaparece con un fundido que funciona en pausa.
##
## El mapa también se abre solo, con su tecla, desde la exploración (`open_map`): la pausa congela
## el juego detrás sin mostrar sus opciones, y al cerrar el mapa se vuelve directamente al juego.

const GAME_SCENE := "res://scenes/main/game.tscn"
const UNSAVED_WARNING := "Lo que hayas avanzado desde el último guardado se perderá. ¿Cargar esta partida?"
const FADE_SECONDS := 0.16

var is_open := false

var _tween: Tween
## El mapa se abrió con su tecla, sin pasar por las opciones de la pausa.
var _map_only := false
var _panel_tween: Tween

@onready var _root: Control = $Root
@onready var _panel: MenuFrame = $Root/Center/Panel
@onready var _resume: MenuOptionButton = $Root/Center/Panel/Box/Resume
@onready var _map_button: MenuOptionButton = $Root/Center/Panel/Box/Map
@onready var _save: MenuOptionButton = $Root/Center/Panel/Box/Save
@onready var _load: MenuOptionButton = $Root/Center/Panel/Box/Load
@onready var _settings_button: MenuOptionButton = $Root/Center/Panel/Box/Settings
@onready var _controls_button: MenuOptionButton = $Root/Center/Panel/Box/Controls
@onready var _quit: MenuOptionButton = $Root/Center/Panel/Box/Quit
@onready var _slot_info: Label = $Root/Center/Panel/Box/SlotInfo
@onready var _settings: SettingsMenu = $Root/SettingsMenu
@onready var _controls: ControlsMenu = $Root/ControlsMenu
@onready var _map: MapScreen = $Root/MapScreen
@onready var _slots: SaveSlotsMenu = $Root/SaveSlotsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.theme = UiTheme.get_theme()
	_root.hide()
	_settings.hide()
	_controls.hide()
	_map.hide()
	_slots.hide()
	MenuStyle.style_label(_slot_info, 19, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	_resume.pressed.connect(close)
	_map_button.pressed.connect(_open_screen.bind(_map))
	_save.pressed.connect(_on_save_pressed)
	_load.pressed.connect(_on_load_pressed)
	_settings_button.pressed.connect(_open_screen.bind(_settings))
	_controls_button.pressed.connect(_open_screen.bind(_controls))
	_quit.pressed.connect(_on_quit_pressed)
	_settings.closed.connect(_return_to_panel.bind(_settings_button))
	_controls.closed.connect(_return_to_panel.bind(_controls_button))
	_map.closed.connect(_on_map_closed)
	_slots.closed.connect(_on_slots_closed)
	_slots.load_ready.connect(_on_load_ready)


func open() -> void:
	_begin_pause(false)
	_panel.show()
	_panel.modulate.a = 1.0
	_resume.grab_focus()


## Abre el mapa directamente, con el juego en pausa detrás y sin las opciones de la pausa.
func open_map() -> void:
	_begin_pause(true)
	_panel.hide()
	_map.open()


## Detective cuya posición muestra el mapa.
func set_map_target(player: PlayerController) -> void:
	_map.target = player


func _begin_pause(map_only: bool) -> void:
	is_open = true
	_map_only = map_only
	_refresh_slot_info()
	_settings.hide()
	_controls.hide()
	_map.hide()
	_slots.hide()
	_fade_root(true)
	get_tree().paused = true
	GameState.lock_player("pausa")


func close() -> void:
	is_open = false
	get_tree().paused = false
	GameState.unlock_player("pausa")
	_fade_root(false)


func _input(event: InputEvent) -> void:
	# Con la pregunta de salida en pantalla, Escape es suyo.
	if ExitManager.is_dialog_open() or not is_open:
		return
	if not (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		return
	if _slots.visible:
		get_viewport().set_input_as_handled()
		_slots.cancel()
	elif _settings.is_open() or _controls.is_open() or _map.is_open():
		# Cada pantalla gestiona su propio Escape y vuelve aquí.
		return
	elif _panel.visible:
		get_viewport().set_input_as_handled()
		close()


## La tecla del mapa también lo abre desde las opciones de la pausa.
func _unhandled_input(event: InputEvent) -> void:
	if is_open and _panel.visible and not ExitManager.is_dialog_open() and event.is_action_pressed("open_map"):
		get_viewport().set_input_as_handled()
		_open_screen(_map)


## Aparece o desaparece con un fundido. Mientras se desvanece no acepta clics ni foco, y al
## terminar se oculta del todo.
func _fade_root(visible_now: bool) -> void:
	if _tween != null:
		_tween.kill()
	var behavior_mouse := Control.MOUSE_BEHAVIOR_INHERITED if visible_now else Control.MOUSE_BEHAVIOR_DISABLED
	var behavior_focus := Control.FOCUS_BEHAVIOR_INHERITED if visible_now else Control.FOCUS_BEHAVIOR_DISABLED
	_root.mouse_behavior_recursive = behavior_mouse
	_root.focus_behavior_recursive = behavior_focus
	if visible_now:
		_root.modulate.a = 0.0
		_root.show()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0 if visible_now else 0.0, FADE_SECONDS)
	if not visible_now:
		_tween.tween_callback(_root.hide)


## Oculta las opciones y abre encima la pantalla de configuración o de controles.
func _open_screen(screen: MenuScreen) -> void:
	AudioManager.play("click")
	_panel.hide()
	screen.open()


## Desde la exploración, cerrar el mapa devuelve al juego; desde la pausa, a sus opciones.
func _on_map_closed() -> void:
	if _map_only:
		close()
	else:
		_return_to_panel(_map_button)


func _return_to_panel(opener: Control) -> void:
	_show_panel()
	opener.grab_focus()


func _show_panel() -> void:
	_panel.show()
	_panel.modulate.a = 0.0
	if _panel_tween != null:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_panel, "modulate:a", 1.0, FADE_SECONDS)


func _on_save_pressed() -> void:
	AudioManager.play("click")
	_panel.hide()
	_slots.open(SaveSlotsMenu.Mode.SAVE)


## Cargar sustituye la partida en curso: si ha avanzado desde el último guardado, se avisa.
func _on_load_pressed() -> void:
	AudioManager.play("click")
	_panel.hide()
	_slots.load_warning = UNSAVED_WARNING if SaveSystem.has_unsaved_progress() else ""
	_slots.open(SaveSlotsMenu.Mode.LOAD)


## Recuerda en qué ranura guardan los autoguardados, o que todavía no hay ninguna.
func _refresh_slot_info() -> void:
	var active := SaveSystem.get_active_slot()
	if active.is_empty():
		_slot_info.text = "Autoguardado en espera: guarda en una ranura para activarlo."
		_slot_info.add_theme_color_override("font_color", MenuStyle.SELECTION_LIGHT)
	else:
		_slot_info.text = "Ranura activa: %02d · Los autoguardados van a ella" % SaveSystem.get_slot_number(active)
		_slot_info.add_theme_color_override("font_color", MenuStyle.TEXT_SECONDARY)


func get_slot_info_text() -> String:
	return _slot_info.text


func _on_slots_closed() -> void:
	_refresh_slot_info()
	_show_panel()
	(_load if _slots.mode == SaveSlotsMenu.Mode.LOAD else _save).grab_focus()


## La escena de juego se vuelve a crear y recoge la partida pendiente al arrancar.
func _on_load_ready(_slot_id: String) -> void:
	get_tree().paused = false
	GameState.clear_player_locks()
	get_tree().change_scene_to_file(GAME_SCENE)


## Vuelve al menú principal por el mismo camino que el cierre del juego: guarda en la
## ranura activa y, si no puede, pregunta.
func _on_quit_pressed() -> void:
	AudioManager.play("click")
	ExitManager.request_exit(ExitManager.Target.MAIN_MENU)
