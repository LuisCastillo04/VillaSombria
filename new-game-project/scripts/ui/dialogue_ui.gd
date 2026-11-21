class_name DialogueUi
extends CanvasLayer
## Interrogatorio visual. Atenúa la exploración, muestra la silueta de quien habla y
## escribe el texto gradualmente. Reutilizable con cualquier personaje: las siluetas
## se cargan del campo `portrait` de `characters.json`, que admite SVG o PNG.
##
## Sólo coordina: la conversación la lleva `DialogueManager`, que avisa con señales; las siluetas
## y su iluminación son de `DialogueCast`, el texto lo escribe `DialogueText`, el nombre lo lleva
## `DialogueSpeakerPlate`, las respuestas las presenta `DialogueChoices` y las teclas se leen con
## `DialogueControls`. La interfaz responde llamando a `DialogueManager.advance` y `choose`.

## Recorrido de la ventana al entrar desde el pie de la pantalla.
const WINDOW_SLIDE := 70.0
const NARRATOR := "narrador"

var _waiting_input := false
## La próxima intervención es la primera desde que se abrió la conversación.
var _first_line := false
var _npc_id := ""
## Última respuesta elegida: al volver al menú, el foco regresa a ella.
var _last_choice := ""
var _transition: Tween
## 1 fuera de escena, 0 en su sitio. Todo el encuadre se calcula a partir de este valor
## y de márgenes relativos, de modo que sobrevive a un cambio de tamaño de ventana.
var _slide := 1.0
var _panel_height := DialogueStyle.NARRATIVE_HEIGHT

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _cast: DialogueCast = $Root/Cast
@onready var _screen_frame: CinematicFrame = $Root/ScreenFrame
@onready var _window: DialogueFrame = $Root/Window
@onready var _plate: DialogueSpeakerPlate = $Root/Window/Plate
@onready var _text: DialogueText = $Root/Window/Text
@onready var _divider: GoldDivider = $Root/Window/Divider
@onready var _continue: DialogueContinueButton = $Root/Window/Continue
@onready var _hint: DialogueChoiceHint = $Root/Window/Hint
@onready var _choices: DialogueChoices = $Root/Window/Choices


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_text.offset_top = DialogueStyle.TEXT_TOP
	_text.offset_bottom = DialogueStyle.TEXT_TOP + _text.get_area_height()
	_screen_frame.inset = DialogueStyle.SCREEN_FRAME_INSET
	_screen_frame.band_color = Color(DialogueStyle.CHARCOAL, 0.9)
	_screen_frame.emphasis = 2.4
	_root.resized.connect(_layout_window)
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
	return _cast.get_speaker()


## Silueta del interlocutor, a la derecha.
func get_portrait() -> TextureRect:
	return _cast.get_portrait()


func get_cast() -> DialogueCast:
	return _cast


func get_dialogue_text() -> DialogueText:
	return _text


func get_choices() -> DialogueChoices:
	return _choices


func get_speaker_plate() -> DialogueSpeakerPlate:
	return _plate


func get_continue_button() -> DialogueContinueButton:
	return _continue


func get_choice_hint() -> DialogueChoiceHint:
	return _hint


## Ventana inferior (no confundir con `Node.get_window`, la ventana del sistema).
func get_dialogue_window() -> DialogueFrame:
	return _window


# --- Entradas ---

func _process(_delta: float) -> void:
	if not _root.visible:
		return
	_cast.talking = _text.is_typing()
	_layout_window()


func _input(event: InputEvent) -> void:
	if not _root.visible or not DialogueManager.active:
		return
	if _choices.visible:
		_choices_input(event)
	elif (_text.is_typing() or _waiting_input) and DialogueControls.is_advance(event):
		get_viewport().set_input_as_handled()
		_advance()


## Con las respuestas en pantalla: su número las elige, arriba y abajo las recorren y la tecla de
## interactuar o la de aceptar confirman la señalada. Se consumen aquí para que ninguna llegue al
## juego (la tecla de interactuar volvería a abrir la conversación recién cerrada) ni a otra pantalla.
func _choices_input(event: InputEvent) -> void:
	var index := DialogueControls.number_index(event)
	if index >= 0:
		get_viewport().set_input_as_handled()
		_choices.choose_index(index)
	elif event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_choices.move_selection(1)
	elif event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_choices.move_selection(-1)
	elif DialogueControls.is_confirm(event):
		get_viewport().set_input_as_handled()
		_choices.confirm_selected()


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
	_first_line = true
	_last_choice = ""
	_set_interactive(true)
	_root.show()
	_choices.hide()
	_hint.hide()
	_text.clear_line()
	_plate.set_text("", false)
	_continue.refresh()
	_continue.set_waiting(false)
	_panel_height = _narrative_height()
	_cast.begin(npc_id)
	_play_entrance()


func _on_line_shown(speaker_id: String, text: String) -> void:
	_choices.hide()
	_hint.hide()
	_text.show()
	_divider.show()
	_continue.show()
	_panel_height = _narrative_height()
	_cast.set_speaker(speaker_id)
	_plate.set_text(_speaker_name(speaker_id))
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
	_hint.set_text(DialogueControls.choice_hint(options.size()))
	_choices.show_options(options)
	_plate.set_text(DialogueChoices.heading_for(options))
	_text.hide()
	_divider.hide()
	_continue.hide()
	var list_height := _choices_list_height()
	_choices.offset_top = DialogueStyle.CHOICES_TOP
	_choices.offset_bottom = DialogueStyle.CHOICES_TOP + list_height
	_panel_height = list_height + _choices_chrome()
	_hint.show()
	_choices.show()
	# Mientras se elige, la luz sigue en el interlocutor que escucha (en una escena, el detective).
	_cast.set_speaker(_npc_id if not _npc_id.is_empty() else DialogueCast.DETECTIVE)
	# El foco vuelve a la última respuesta elegida si sigue en el menú; si no, a la primera.
	_choices.focus_option(_last_choice)
	_choices.hold_confirmation(DialogueStyle.CONFIRM_GUARD_SECONDS)


## Se elige una respuesta: su consecuencia la decide `DialogueManager`, que contesta enseguida con
## la siguiente intervención, otro menú o el cierre.
func _choose(option_id: String) -> void:
	AudioManager.play("click")
	_last_choice = option_id
	_choices.hide()
	DialogueManager.choose(option_id)


func _on_closed(_finished_npc: String) -> void:
	_text.stop()
	_waiting_input = false
	_last_choice = ""
	_continue.set_waiting(false)
	_set_interactive(false)
	_play_exit()


## Mientras se desvanece, la conversación ya no acepta clics ni foco: el control vuelve al juego.
func _set_interactive(interactive: bool) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if not interactive and focus_owner != null and _root.is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	_root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if interactive else Control.MOUSE_BEHAVIOR_DISABLED
	_root.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if interactive else Control.FOCUS_BEHAVIOR_DISABLED


func _on_text_completed() -> void:
	_waiting_input = true
	_continue.set_waiting(true)


## Alto de la ventana mientras se lee: el texto, el separador y la pestaña de continuar.
func _narrative_height() -> float:
	return DialogueStyle.TEXT_TOP + _text.get_area_height() + DialogueStyle.TEXT_TO_DIVIDER \
		+ DialogueStyle.DIVIDER_HEIGHT + DialogueStyle.DIVIDER_TO_BOTTOM


## Lo que ocupa la ventana con las respuestas además de la lista: arriba, el sitio de la placa; abajo,
## el separador con la ayuda.
func _choices_chrome() -> float:
	return DialogueStyle.CHOICES_TOP + DialogueStyle.CHOICES_TO_HINT + DialogueStyle.HINT_HEIGHT + DialogueStyle.HINT_BOTTOM


## Alto de la lista: el de todas las respuestas, sin que la ventana pase de su tope; si no caben, la
## lista se desplaza.
func _choices_list_height() -> float:
	var limit := _root.size.y * DialogueStyle.MAX_WINDOW_RATIO - _choices_chrome()
	var minimum := _choices.get_min_height()
	return clampf(_choices.get_content_height(), minimum, maxf(limit, minimum))


## Nombre de la placa: el del personaje, o ninguno para la narración.
static func _speaker_name(speaker_id: String) -> String:
	return "" if speaker_id == NARRATOR else GameData.get_character_name(speaker_id)


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
	_window.modulate.a = 0.0
	_screen_frame.modulate.a = 0.0
	_layout_window()
	_cast.play_entrance()
	_transition = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(self, "_slide", 0.0, DialogueStyle.OPEN_SECONDS)
	_transition.tween_property(_dim, "color:a", DialogueStyle.DIM.a, 0.35)
	_transition.tween_property(_window, "modulate:a", 1.0, 0.3)
	_transition.tween_property(_screen_frame, "modulate:a", 1.0, 0.35)


func _play_exit() -> void:
	if _transition != null:
		_transition.kill()
	_cast.play_exit()
	_transition = create_tween().set_parallel()
	_transition.tween_property(_dim, "color:a", 0.0, DialogueStyle.CLOSE_SECONDS)
	_transition.tween_property(_window, "modulate:a", 0.0, 0.2)
	_transition.tween_property(_screen_frame, "modulate:a", 0.0, 0.2)
	_transition.chain().tween_callback(_root.hide)
