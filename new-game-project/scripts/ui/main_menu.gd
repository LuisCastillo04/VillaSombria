
extends Node
## Menú principal. La plaza real, bajo la lluvia, hace de fondo: la interfaz es sólo una capa
## encima y nunca la sustituye por una imagen.

const GAME_SCENE := "res://scenes/main/game.tscn"
const PLAZA_SCENE := "res://scenes/world/locations/plaza.tscn"
const CREDITS_TEXT := """[b]VILLA SOMBRÍA[/b]
Proyecto final de Diseño de Videojuegos

[b]Creado y desarrollado por[/b]
Juan Camilo Miño Castillo
Luis Eduardo Miño Castillo

Diseño, programación, narrativa y dirección: trabajo conjunto de ambos autores.

[b]Motor[/b]
Godot Engine 4.7, © sus colaboradores, licencia MIT

[b]Recursos[/b]
Geometría, siluetas, materiales y sonido generados para este proyecto.
El juego no incluye recursos de terceros."""
const SUBTITLE_GOLD := Color("d3b679")

@onready var _backdrop: Node3D = $Backdrop
@onready var _camera: Camera3D = $Backdrop/Camera3D
@onready var _post_fx: PostFx = $PostFx
@onready var _root: Control = %Root
@onready var _layout: VBoxContainer = %Layout
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _menu: VBoxContainer = %Menu
@onready var _new_game: MenuOptionButton = %NewGame
@onready var _continue: MenuOptionButton = %Continue
@onready var _load: MenuOptionButton = %Load
@onready var _settings_button: MenuOptionButton = %Settings
@onready var _credits_button: MenuOptionButton = %Credits
@onready var _quit: MenuOptionButton = %Quit
@onready var _settings: SettingsMenu = %SettingsMenu
@onready var _credits: VBoxContainer = %CreditsPanel
@onready var _credits_text: RichTextLabel = %CreditsText
@onready var _credits_close: MenuOptionButton = %CreditsClose
@onready var _slots: SaveSlotsMenu = %SaveSlotsMenu
@onready var _fade: ScreenFade = $ScreenFade

## Opción que abrió el panel o la pantalla visibles: recupera el foco al volver.
var _return_focus: Control
var _layout_tween: Tween


func _ready() -> void:
	GameState.reset()
	GameClock.reset()
	_root.theme = UiTheme.get_theme()
	_build_look()
	_build_backdrop()
	_refresh_continue()
	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_load.pressed.connect(_open_load_menu)
	_settings_button.pressed.connect(_open_settings)
	_credits_button.pressed.connect(_show_panel.bind(_credits, _credits_button))
	_quit.pressed.connect(_on_quit)
	_credits_close.pressed.connect(_show_menu)
	_settings.closed.connect(_show_menu)
	_slots.closed.connect(_show_menu)
	_slots.load_ready.connect(_on_load_ready)
	_credits_text.text = "[center]%s[/center]" % CREDITS_TEXT
	_settings.hide()
	_credits.hide()
	_slots.hide()
	_new_game.grab_focus()
	AudioManager.enter_location("menu")
	_fade.fade_in(0.9)


func _input(event: InputEvent) -> void:
	if ExitManager.is_dialog_open() or ConfirmDialog.is_open():
		return
	if not (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		return
	if _slots.visible:
		get_viewport().set_input_as_handled()
		_slots.cancel()
	elif _settings.is_open():
		# La configuración gestiona su propio Escape y vuelve aquí.
		return
	elif not _menu.visible:
		get_viewport().set_input_as_handled()
		_show_menu()


## Tipografía del título, el subtítulo y los créditos. Las opciones y el panel se dibujan solos.
func _build_look() -> void:
	CaseFileStyle.style_label(_title, CaseFileStyle.display_serif(), 118, CaseFileStyle.CREAM)
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 5)
	_title.add_theme_constant_override("shadow_outline_size", 14)
	CaseFileStyle.style_label(_subtitle, CaseFileStyle.serif_italic(), 28, SUBTITLE_GOLD)
	_subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_subtitle.add_theme_constant_override("shadow_offset_x", 0)
	_subtitle.add_theme_constant_override("shadow_offset_y", 2)
	_subtitle.add_theme_constant_override("shadow_outline_size", 6)
	_credits_text.add_theme_color_override("default_color", CaseFileStyle.CREAM)
	_credits_text.add_theme_font_override("normal_font", CaseFileStyle.serif())
	_credits_text.add_theme_font_override("bold_font", CaseFileStyle.serif_bold())
	_credits_text.add_theme_font_size_override("normal_font_size", 21)
	_credits_text.add_theme_font_size_override("bold_font_size", 24)
	_credits_text.add_theme_constant_override("line_separation", 4)


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


func _show_panel(panel: Control, opener: Control) -> void:
	AudioManager.play("click")
	_return_focus = opener
	_menu.hide()
	panel.show()
	# El foco pasa al panel: si no, el teclado y el mando se quedarían sin nada que manejar.
	var first := panel.find_next_valid_focus()
	if first != null and panel.is_ancestor_of(first):
		first.grab_focus()


## La configuración se abre encima de la plaza, en lugar del título y las opciones.
func _open_settings() -> void:
	AudioManager.play("click")
	_return_focus = _settings_button
	_layout.hide()
	_settings.open()


func _show_menu() -> void:
	_credits.hide()
	_slots.hide()
	_menu.show()
	if not _layout.visible:
		_fade_in_layout()
	_refresh_continue()
	var target := _return_focus
	_return_focus = null
	if target == null or target.focus_mode == Control.FOCUS_NONE or not target.is_visible_in_tree():
		target = _new_game
	target.grab_focus()


## Al volver de otra pantalla, el título y las opciones aparecen con un fundido.
func _fade_in_layout() -> void:
	_layout.show()
	_layout.modulate.a = 0.0
	if _layout_tween != null:
		_layout_tween.kill()
	_layout_tween = create_tween()
	_layout_tween.tween_property(_layout, "modulate:a", 1.0, MenuScreen.FADE_SECONDS)


## «Continuar» retoma la ranura activa de la última sesión o, si ya no es válida, la más reciente.
func _refresh_continue() -> void:
	var latest := SaveSystem.get_continue_slot()
	_continue.set_available(not latest.is_empty())
	_continue.detail_text = ""
	if not latest.is_empty():
		var summary: Dictionary = SaveSystem.get_slot_info(latest)["summary"]
		_continue.detail_text = "(Día %d · %s)" % [int(summary["day"]), SaveSlotsMenu.format_clock(int(summary["minutes"]))]


func _open_load_menu(opener: Control = null) -> void:
	AudioManager.play("click")
	_return_focus = opener if opener != null else _load
	_layout.hide()
	_slots.load_warning = ""
	_slots.open(SaveSlotsMenu.Mode.LOAD)


func _on_new_game() -> void:
	AudioManager.play("click")
	SaveSystem.take_pending_load()
	await _fade.fade_out(0.6)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	AudioManager.play("click")
	var result := SaveSystem.request_load(SaveSystem.get_continue_slot())
	if not result["ok"]:
		_open_load_menu(_continue)
		_slots.show_message("No se pudo continuar: %s" % result["error"], true)
		return
	await _fade.fade_out(0.6)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_load_ready(_slot_id: String) -> void:
	await _fade.fade_out(0.6)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit() -> void:
	AudioManager.play("click")
	ExitManager.request_exit(ExitManager.Target.QUIT)
