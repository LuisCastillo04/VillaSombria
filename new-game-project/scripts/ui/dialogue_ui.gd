class_name DialogueUi
extends CanvasLayer
## Interrogatorio visual. Atenúa la exploración, muestra la silueta de quien habla y
## escribe el texto gradualmente. Reutilizable con cualquier personaje: las siluetas
## se cargan del campo `portrait` de `characters.json`, que admite SVG o PNG.
##
## Sólo coordina: la conversación la lleva `DialogueManager`, que avisa con señales; el texto lo
## escribe `DialogueText`, el nombre lo lleva `DialogueSpeakerPlate`, las respuestas las presenta
## `DialogueChoices` y las teclas se leen con `DialogueControls`. La interfaz responde llamando a
## `DialogueManager.advance` y `choose`.

const FALLBACK_PORTRAIT := "res://assets/siluetas/detective.svg"
const ACTIVE_TINT := Color(1.0, 1.0, 1.0, 1.0)
const IDLE_TINT := Color(0.5, 0.5, 0.56, 1.0)
const PANEL_HEIGHT_OPTIONS := 430.0
## Recorrido de la ventana al entrar desde el pie de la pantalla.
const WINDOW_SLIDE := 70.0
const NARRATOR := "narrador"

var _waiting_input := false
## La próxima intervención es la primera desde que se abrió la conversación.
var _first_line := false
var _clock := 0.0
var _speaker := ""
var _npc_id := ""
var _portrait_cache: Dictionary = {}
var _transition: Tween
## 1 fuera de escena, 0 en su sitio. Todo el encuadre se calcula a partir de este valor
## y de márgenes relativos, de modo que sobrevive a un cambio de tamaño de ventana.
var _slide := 1.0
var _panel_height := DialogueStyle.NARRATIVE_HEIGHT
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
@onready var _screen_frame: CinematicFrame = $Root/ScreenFrame
@onready var _window: DialogueFrame = $Root/Window
@onready var _plate: DialogueSpeakerPlate = $Root/Window/Plate
@onready var _text: DialogueText = $Root/Window/Text
@onready var _divider: GoldDivider = $Root/Window/Divider
@onready var _continue: DialogueContinueButton = $Root/Window/Continue
@onready var _hint: Label = $Root/Window/Hint
@onready var _choices: DialogueChoices = $Root/Window/Choices


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	CaseFileStyle.style_label(_hint, DialogueStyle.hint_font(), DialogueStyle.HINT_SIZE, DialogueStyle.INK_SOFT)
	_text.offset_top = DialogueStyle.TEXT_TOP
	_text.offset_bottom = DialogueStyle.TEXT_TOP + _text.get_area_height()
	_screen_frame.inset = DialogueStyle.SCREEN_FRAME_INSET
	_screen_frame.band_color = Color(DialogueStyle.CHARCOAL, 0.9)
	_screen_frame.emphasis = 2.4
	_root.resized.connect(_apply_layout)
	_portrait_left = _portrait.offset_left
	_portrait_right = _portrait.offset_right
	_portrait_top = _portrait.offset_top
	_portrait_bottom = _portrait.offset_bottom
	_detective_left = _detective.offset_left
	_detective_right = _detective.offset_right
	_detective.texture = _load_portrait("detective")
	_root.hide()
	_text.completed.connect(_on_text_completed)
	_choices.chosen.connect(_choose)
	DialogueManager.opened.connect(_on_opened)
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.options_shown.connect(_on_options_shown)
	DialogueManager.closed.connect(_on_closed)


# --- Estado, para las pruebas y para otras pantallas ---

## Si la conversación está en pantalla (también mientras aparece o desaparece).
func is_open() -> bool:
	return _root.visible


## Si el texto de la intervención actual aún se está escribiendo.
func is_typing() -> bool:
	return _text.is_typing()


## Si el texto ya se lee entero y se espera la pulsación para continuar.
func is_waiting_for_input() -> bool:
	return _waiting_input


## Si se están mostrando las respuestas.
func is_choosing() -> bool:
	return _choices.visible


func get_option_ids() -> Array[String]:
	return _choices.get_option_ids()


## Personaje al que corresponde ahora la iluminación: quien habla o, con las respuestas en
## pantalla, el interlocutor que las escucha.
func get_speaker() -> String:
	return _speaker


## Silueta del interlocutor, a la derecha.
func get_portrait() -> TextureRect:
	return _portrait


func get_dialogue_text() -> DialogueText:
	return _text


func get_choices() -> DialogueChoices:
	return _choices


func get_speaker_plate() -> DialogueSpeakerPlate:
	return _plate


func get_continue_button() -> DialogueContinueButton:
	return _continue


## Ventana inferior (no confundir con `Node.get_window`, la ventana del sistema).
func get_dialogue_window() -> DialogueFrame:
	return _window


# --- Entradas ---

func _process(delta: float) -> void:
	if not _root.visible:
		return
	_clock += delta
	_apply_layout()


func _input(event: InputEvent) -> void:
	if not _root.visible or not DialogueManager.active:
		return
	if (_text.is_typing() or _waiting_input) and DialogueControls.is_advance(event):
		get_viewport().set_input_as_handled()
		_advance()
	elif _choices.visible:
		var index := DialogueControls.number_index(event)
		if index >= 0 and index < _choices.get_count():
			get_viewport().set_input_as_handled()
			_choices.choose_index(index)


## Una pulsación: termina de escribir la página, pasa a la siguiente o, leída la última, pide la
## siguiente intervención. Nunca hace dos cosas a la vez.
func _advance() -> void:
	if _text.is_typing():
		_text.complete()
		return
	_waiting_input = false
	_continue.set_waiting(false)
	if _text.has_next_page():
		_text.next_page()
	else:
		DialogueManager.advance()


# --- Señales de la conversación ---

func _on_opened(npc_id: String) -> void:
	_npc_id = npc_id
	_speaker = ""
	_first_line = true
	_root.show()
	_choices.hide()
	_hint.hide()
	_text.clear_line()
	_plate.set_text("", false)
	_continue.refresh()
	_continue.set_waiting(false)
	_panel_height = _narrative_height()
	if not npc_id.is_empty():
		_portrait.texture = _load_portrait(npc_id)
	_portrait.visible = not npc_id.is_empty()
	_backlight.visible = _portrait.visible
	_play_entrance()


func _on_line_shown(speaker_id: String, text: String) -> void:
	_choices.hide()
	_hint.hide()
	_text.show()
	_divider.show()
	_continue.show()
	_panel_height = _narrative_height()
	_set_speaker(speaker_id)
	_waiting_input = false
	_continue.set_waiting(false)
	var delay := DialogueStyle.FIRST_LINE_DELAY if _first_line else 0.0
	_first_line = false
	_text.show_line(text, speaker_id == NARRATOR, delay)


func _on_options_shown(options: Array) -> void:
	_text.stop()
	_waiting_input = false
	_first_line = false
	_continue.set_waiting(false)
	_hint.text = DialogueControls.choice_hint(options.size())
	_choices.show_options(options)
	_text.hide()
	_divider.hide()
	_continue.hide()
	_panel_height = PANEL_HEIGHT_OPTIONS
	_hint.show()
	_choices.show()
	_set_speaker(_npc_id if not _npc_id.is_empty() else "detective", false)
	await get_tree().process_frame
	if _choices.visible:
		_choices.focus_first()


func _choose(option_id: String) -> void:
	AudioManager.play("click")
	_choices.hide()
	DialogueManager.choose(option_id)


func _on_closed(_finished_npc: String) -> void:
	_text.stop()
	_waiting_input = false
	_continue.set_waiting(false)
	_play_exit()


func _on_text_completed() -> void:
	_waiting_input = true
	_continue.set_waiting(true)


## Alto de la ventana mientras se lee: el texto, el separador y la pestaña de continuar.
func _narrative_height() -> float:
	return DialogueStyle.TEXT_TOP + _text.get_area_height() + DialogueStyle.TEXT_TO_DIVIDER \
		+ DialogueStyle.DIVIDER_HEIGHT + DialogueStyle.DIVIDER_TO_BOTTOM


## Nombre de la placa: el del personaje, o ninguno para la narración.
static func _speaker_name(speaker_id: String) -> String:
	return "" if speaker_id == NARRATOR else GameData.get_character_name(speaker_id)


## Da protagonismo a quien habla. La narración apaga ambas siluetas.
func _set_speaker(speaker_id: String, show_name: bool = true) -> void:
	_speaker = speaker_id
	var is_narrator := speaker_id == NARRATOR
	var is_detective := speaker_id == "detective"
	if not is_narrator and not is_detective and speaker_id != _npc_id:
		# Escenas sin interlocutor fijo: la silueta cambia con cada voz.
		_portrait.texture = _load_portrait(speaker_id)
		_portrait.show()
		_backlight.show()
	if show_name:
		_plate.set_text(_speaker_name(speaker_id))
	var portrait_active := not is_narrator and not is_detective
	_tint(_portrait, ACTIVE_TINT if portrait_active else IDLE_TINT)
	_tint(_detective, ACTIVE_TINT if is_detective else IDLE_TINT)


func _tint(target: CanvasItem, color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", color, DialogueStyle.TINT_SECONDS)


## Aplica transición, respiración y el leve balanceo de la silueta que tiene la palabra.
func _apply_layout() -> void:
	var breath := sin(_clock * 1.6) * 5.0
	var speaking := _text.is_typing() and _speaker != "detective" and _speaker != NARRATOR
	var talk := sin(_clock * 11.0) * 2.5 if speaking else 0.0
	var offset_y := breath + talk
	var offset_x := _slide * 120.0
	_portrait.offset_left = _portrait_left + offset_x
	_portrait.offset_right = _portrait_right + offset_x
	_portrait.offset_top = _portrait_top + offset_y
	_portrait.offset_bottom = _portrait_bottom + offset_y
	_detective.offset_left = _detective_left - _slide * 90.0
	_detective.offset_right = _detective_right - _slide * 90.0
	_layout_window()


## La ventana ocupa el ancho de la pantalla menos los márgenes, sin pasar del de una pantalla 16:9,
## y descansa sobre el pie.
func _layout_window() -> void:
	var view := _root.size
	var width := minf(view.x - DialogueStyle.SCREEN_MARGIN * 2.0, DialogueStyle.MAX_WIDTH)
	var bottom := view.y - DialogueStyle.BOTTOM_MARGIN + _slide * WINDOW_SLIDE
	_window.position = Vector2((view.x - width) * 0.5, bottom - _panel_height)
	_window.size = Vector2(width, _panel_height)


func _play_entrance() -> void:
	if _transition != null:
		_transition.kill()
	_slide = 1.0
	_dim.color.a = 0.0
	_backlight.modulate.a = 0.0
	_window.modulate.a = 0.0
	_screen_frame.modulate.a = 0.0
	_portrait.modulate.a = 0.0
	_detective.modulate.a = 0.0
	_layout_window()
	_transition = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(self, "_slide", 0.0, DialogueStyle.OPEN_SECONDS)
	_transition.tween_property(_dim, "color:a", DialogueStyle.DIM.a, 0.35)
	_transition.tween_property(_backlight, "modulate:a", 1.0, 0.45)
	_transition.tween_property(_window, "modulate:a", 1.0, 0.3)
	_transition.tween_property(_screen_frame, "modulate:a", 1.0, 0.35)
	_transition.tween_property(_portrait, "modulate:a", 1.0, 0.4)
	_transition.tween_property(_detective, "modulate:a", 1.0, 0.4)


func _play_exit() -> void:
	if _transition != null:
		_transition.kill()
	_transition = create_tween().set_parallel()
	_transition.tween_property(_dim, "color:a", 0.0, DialogueStyle.CLOSE_SECONDS)
	_transition.tween_property(_backlight, "modulate:a", 0.0, 0.2)
	_transition.tween_property(_window, "modulate:a", 0.0, 0.2)
	_transition.tween_property(_screen_frame, "modulate:a", 0.0, 0.2)
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
