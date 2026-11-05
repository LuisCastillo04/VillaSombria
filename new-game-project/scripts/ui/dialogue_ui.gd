class_name DialogueUi
extends CanvasLayer
## Interrogatorio visual. Atenúa la exploración, muestra la silueta de quien habla y
## escribe el texto gradualmente. Reutilizable con cualquier personaje: las siluetas
## se cargan del campo `portrait` de `characters.json`, que admite SVG o PNG.

const CHARACTERS_PER_SECOND := 48.0
const FALLBACK_PORTRAIT := "res://assets/siluetas/detective.svg"
const DIM_ALPHA := 0.62
const ACTIVE_TINT := Color(1.0, 1.0, 1.0, 1.0)
const IDLE_TINT := Color(0.5, 0.5, 0.56, 1.0)
const PANEL_BOTTOM := -30.0
const PANEL_HEIGHT_TEXT := 250.0
const PANEL_HEIGHT_OPTIONS := 430.0

var _typing := false
var _waiting_input := false
var _visible_progress := 0.0
var _clock := 0.0
var _speaker := ""
var _npc_id := ""
var _portrait_cache: Dictionary = {}
var _option_ids: Array[String] = []
var _transition: Tween
## 1 fuera de escena, 0 en su sitio. Todo el encuadre se calcula a partir de este valor
## y de márgenes relativos, de modo que sobrevive a un cambio de tamaño de ventana.
var _slide := 1.0
var _panel_height := PANEL_HEIGHT_TEXT
var _portrait_left := 0.0
var _portrait_right := 0.0
var _portrait_top := 0.0
var _portrait_bottom := 0.0
var _detective_left := 0.0
var _detective_right := 0.0

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _backlight: ColorRect = $Root/Backlight
@onready var _portrait: TextureRect = $Root/Portrait
@onready var _detective: TextureRect = $Root/Detective
@onready var _panel: PanelContainer = $Root/Panel
@onready var _name_label: Label = $Root/Panel/Margin/Box/Name
@onready var _text: RichTextLabel = $Root/Panel/Margin/Box/Text
@onready var _hint: Label = $Root/Panel/Margin/Box/Hint
@onready var _options_scroll: ScrollContainer = $Root/Panel/Margin/Box/OptionsScroll
@onready var _options: VBoxContainer = $Root/Panel/Margin/Box/OptionsScroll/Options


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_name_label.add_theme_font_override("font", UiTheme.serif())
	_name_label.add_theme_color_override("font_color", UiTheme.STAMP)
	_name_label.add_theme_font_size_override("font_size", 30)
	_hint.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	_hint.add_theme_font_size_override("font_size", 18)
	_text.add_theme_font_size_override("normal_font_size", 25)
	_portrait_left = _portrait.offset_left
	_portrait_right = _portrait.offset_right
	_portrait_top = _portrait.offset_top
	_portrait_bottom = _portrait.offset_bottom
	_detective_left = _detective.offset_left
	_detective_right = _detective.offset_right
	_detective.texture = _load_portrait("detective")
	_root.hide()
	DialogueManager.opened.connect(_on_opened)
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.options_shown.connect(_on_options_shown)
	DialogueManager.closed.connect(_on_closed)


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_clock += delta
	_apply_layout()
	if not _typing:
		return
	_visible_progress += delta * CHARACTERS_PER_SECOND
	if int(_visible_progress) / 3 > _text.visible_characters / 3:
		AudioManager.play("tecla")
	_text.visible_characters = int(_visible_progress)
	if _text.visible_characters >= _text.get_total_character_count():
		_finish_typing()


func _input(event: InputEvent) -> void:
	if not _root.visible or not DialogueManager.active:
		return
	if _is_advance_event(event):
		get_viewport().set_input_as_handled()
		if _typing:
			_finish_typing()
		elif _waiting_input:
			_waiting_input = false
			DialogueManager.advance()
	elif event is InputEventKey and event.pressed and not event.echo:
		_try_number_shortcut(event as InputEventKey)


func _is_advance_event(event: InputEvent) -> bool:
	if not (_typing or _waiting_input):
		return false
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		return true
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _try_number_shortcut(event: InputEventKey) -> void:
	var index := event.keycode - KEY_1
	if _options_scroll.visible and index >= 0 and index < _option_ids.size():
		get_viewport().set_input_as_handled()
		_choose(_option_ids[index])


func _on_opened(npc_id: String) -> void:
	_npc_id = npc_id
	_speaker = ""
	_root.show()
	_options_scroll.hide()
	_text.text = ""
	_name_label.text = ""
	_hint.text = ""
	_panel_height = PANEL_HEIGHT_TEXT
	if not npc_id.is_empty():
		_portrait.texture = _load_portrait(npc_id)
	_portrait.visible = not npc_id.is_empty()
	_backlight.visible = _portrait.visible
	_play_entrance()


func _on_line_shown(speaker_id: String, text: String) -> void:
	_options_scroll.hide()
	_text.show()
	_panel_height = PANEL_HEIGHT_TEXT
	_set_speaker(speaker_id)
	_text.text = text
	_text.visible_characters = 0
	_visible_progress = 0.0
	_hint.text = ""
	_typing = true
	_waiting_input = false


func _on_options_shown(options: Array) -> void:
	_typing = false
	_waiting_input = false
	_hint.text = "Elige con el ratón o con las teclas numéricas"
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	_option_ids.clear()
	var number := 1
	for option: Dictionary in options:
		var button := Button.new()
		var mark := "" if bool(option["asked"]) else "●  "
		button.text = "%d. %s%s" % [number, mark, option["label"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_choose.bind(option["id"]))
		_options.add_child(button)
		_option_ids.append(option["id"])
		number += 1
	_text.hide()
	_panel_height = PANEL_HEIGHT_OPTIONS
	_options_scroll.show()
	_set_speaker(_npc_id if not _npc_id.is_empty() else "detective", false)
	await get_tree().process_frame
	if _options.get_child_count() > 0:
		(_options.get_child(0) as Button).grab_focus()


func _choose(option_id: String) -> void:
	AudioManager.play("click")
	_options_scroll.hide()
	DialogueManager.choose(option_id)


func _on_closed(_finished_npc: String) -> void:
	_typing = false
	_waiting_input = false
	_play_exit()


func _finish_typing() -> void:
	_typing = false
	_waiting_input = true
	_text.visible_characters = -1
	_hint.text = "[E] Continuar"


## Da protagonismo a quien habla. La narración apaga ambas siluetas.
func _set_speaker(speaker_id: String, show_name: bool = true) -> void:
	_speaker = speaker_id
	var is_narrator := speaker_id == "narrador"
	var is_detective := speaker_id == "detective"
	if not is_narrator and not is_detective and speaker_id != _npc_id:
		# Escenas sin interlocutor fijo: la silueta cambia con cada voz.
		_portrait.texture = _load_portrait(speaker_id)
		_portrait.show()
		_backlight.show()
	if show_name:
		_name_label.text = "" if is_narrator else GameData.get_character_name(speaker_id)
	var portrait_active := not is_narrator and not is_detective
	_tint(_portrait, ACTIVE_TINT if portrait_active else IDLE_TINT)
	_tint(_detective, ACTIVE_TINT if is_detective else IDLE_TINT)


func _tint(target: CanvasItem, color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", color, 0.2)


## Aplica transición, respiración y el leve balanceo de la silueta que tiene la palabra.
func _apply_layout() -> void:
	var breath := sin(_clock * 1.6) * 5.0
	var speaking := _typing and _speaker != "detective" and _speaker != "narrador"
	var talk := sin(_clock * 11.0) * 2.5 if speaking else 0.0
	var offset_y := breath + talk
	var offset_x := _slide * 120.0
	_portrait.offset_left = _portrait_left + offset_x
	_portrait.offset_right = _portrait_right + offset_x
	_portrait.offset_top = _portrait_top + offset_y
	_portrait.offset_bottom = _portrait_bottom + offset_y
	_detective.offset_left = _detective_left - _slide * 90.0
	_detective.offset_right = _detective_right - _slide * 90.0
	_panel.offset_bottom = PANEL_BOTTOM + _slide * 70.0
	_panel.offset_top = _panel.offset_bottom - _panel_height


func _play_entrance() -> void:
	if _transition != null:
		_transition.kill()
	_slide = 1.0
	_dim.color.a = 0.0
	_backlight.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_portrait.modulate.a = 0.0
	_detective.modulate.a = 0.0
	_transition = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(self, "_slide", 0.0, 0.45)
	_transition.tween_property(_dim, "color:a", DIM_ALPHA, 0.35)
	_transition.tween_property(_backlight, "modulate:a", 1.0, 0.45)
	_transition.tween_property(_panel, "modulate:a", 1.0, 0.3)
	_transition.tween_property(_portrait, "modulate:a", 1.0, 0.4)
	_transition.tween_property(_detective, "modulate:a", 1.0, 0.4)


func _play_exit() -> void:
	if _transition != null:
		_transition.kill()
	_transition = create_tween().set_parallel()
	_transition.tween_property(_dim, "color:a", 0.0, 0.25)
	_transition.tween_property(_backlight, "modulate:a", 0.0, 0.2)
	_transition.tween_property(_panel, "modulate:a", 0.0, 0.2)
	_transition.tween_property(_portrait, "modulate:a", 0.0, 0.2)
	_transition.tween_property(_detective, "modulate:a", 0.0, 0.2)
	_transition.chain().tween_callback(_root.hide)


func _load_portrait(character_id: String) -> Texture2D:
	if _portrait_cache.has(character_id):
		return _portrait_cache[character_id]
	var data: Dictionary = GameData.characters.get(character_id, {})
	var path: String = data.get("portrait", FALLBACK_PORTRAIT)
	var texture := load(path) as Texture2D
	if texture == null:
		texture = load(FALLBACK_PORTRAIT)
	_portrait_cache[character_id] = texture
	return texture
