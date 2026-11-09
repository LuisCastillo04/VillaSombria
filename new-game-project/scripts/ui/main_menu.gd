extends Node
## Menú principal. La plaza real, bajo la lluvia, hace de fondo.

const GAME_SCENE := "res://scenes/main/game.tscn"
const PLAZA_SCENE := "res://scenes/world/locations/plaza.tscn"
const CREDITS_TEXT := """[b]VILLA SOMBRÍA[/b]
Proyecto final de Diseño de Videojuegos

[b]Creado y desarrollado por[/b]
Luis Castillo
Juan Camilo Miño Castillo

Diseño, programación, narrativa y dirección: trabajo conjunto de ambos autores.

[b]Motor[/b]
Godot Engine 4.7, © sus colaboradores, licencia MIT

[b]Recursos[/b]
Geometría, siluetas, materiales y sonido generados para este proyecto.
El juego no incluye recursos de terceros."""

@onready var _backdrop: Node3D = $Backdrop
@onready var _camera: Camera3D = $Backdrop/Camera3D
@onready var _post_fx: PostFx = $PostFx
@onready var _root: Control = $Ui/Root
@onready var _title: Label = $Ui/Root/Layout/Title
@onready var _subtitle: Label = $Ui/Root/Layout/Subtitle
@onready var _menu: VBoxContainer = $Ui/Root/Layout/Menu
@onready var _new_game: Button = $Ui/Root/Layout/Menu/NewGame
@onready var _continue: Button = $Ui/Root/Layout/Menu/Continue
@onready var _settings_button: Button = $Ui/Root/Layout/Menu/Settings
@onready var _credits_button: Button = $Ui/Root/Layout/Menu/Credits
@onready var _quit: Button = $Ui/Root/Layout/Menu/Quit
@onready var _settings: SettingsPanel = $Ui/Root/Layout/SettingsPanel
@onready var _credits: PanelContainer = $Ui/Root/Layout/CreditsPanel
@onready var _credits_text: RichTextLabel = $Ui/Root/Layout/CreditsPanel/Box/Text
@onready var _credits_close: Button = $Ui/Root/Layout/CreditsPanel/Box/Close
@onready var _fade: ScreenFade = $ScreenFade


func _ready() -> void:
	GameState.reset()
	GameClock.reset()
	_root.theme = UiTheme.get_theme()
	_title.add_theme_font_override("font", UiTheme.serif())
	_title.add_theme_font_size_override("font_size", 104)
	_title.add_theme_color_override("font_color", UiTheme.PAPER_LIGHT)
	_subtitle.add_theme_color_override("font_color", UiTheme.AMBER)
	_build_backdrop()
	_continue.disabled = not SaveSystem.has_save()
	if SaveSystem.has_save():
		_continue.text = "Continuar partida (%s)" % SaveSystem.describe_save()
	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_settings_button.pressed.connect(_show_panel.bind(_settings))
	_credits_button.pressed.connect(_show_panel.bind(_credits))
	_quit.pressed.connect(_on_quit)
	_credits_close.pressed.connect(_show_menu)
	_settings.closed.connect(_show_menu)
	_credits_text.text = CREDITS_TEXT
	_settings.hide()
	_credits.hide()
	_new_game.grab_focus()
	AudioManager.set_rain(true)
	_fade.fade_in(0.9)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _menu.visible:
		get_viewport().set_input_as_handled()
		_show_menu()


func _build_backdrop() -> void:
	var plaza: LocationBase = (load(PLAZA_SCENE) as PackedScene).instantiate()
	_backdrop.add_child(plaza)
	_post_fx.set_outdoor(true)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 15.0
	_camera.near = 0.5
	_camera.far = 100.0
	_camera.rotation_degrees = Vector3(-36.0, 45.0, 0.0)
	var focus := Vector3(4.0, 1.0, -4.0)
	_camera.position = focus + _camera.basis.z * 40.0
	var rain := RainEffect.new()
	rain.position = focus + Vector3.UP * RainEffect.HEIGHT
	_backdrop.add_child(rain)


func _show_panel(panel: Control) -> void:
	AudioManager.play("click")
	_menu.hide()
	panel.show()


func _show_menu() -> void:
	_settings.hide()
	_credits.hide()
	_menu.show()
	_new_game.grab_focus()


func _on_new_game() -> void:
	AudioManager.play("click")
	SaveSystem.load_requested = false
	await _fade.fade_out(0.6)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	AudioManager.play("click")
	SaveSystem.load_requested = true
	await _fade.fade_out(0.6)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit() -> void:
	get_tree().quit()
