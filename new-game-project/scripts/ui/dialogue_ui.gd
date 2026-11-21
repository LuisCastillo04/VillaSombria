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
##
## Hay una sola ventana con dos modos: la lectura (texto, separador y «Continuar») y la elección
## (respuestas y ayuda). Al pasar de uno a otro el contenido se funde y el borde superior de la
## ventana, con la placa, sube o baja hasta su nueva altura; lo de dentro está anclado al pie, así
## que no se mueve bajo el cursor.

enum Mode { CLOSED, READING, CHOOSING }

## Recorrido de la ventana al entrar desde el pie de la pantalla.
const WINDOW_SLIDE := 70.0
const NARRATOR := "narrador"

var _mode := Mode.CLOSED
var _waiting_input := false
## La próxima intervención es la primera desde que se abrió la conversación.
var _first_line := false
var _npc_id := ""
## Última respuesta elegida: al volver al menú, el foco regresa a ella.
var _last_choice := ""
var _transition: Tween
var _height_tween: Tween
var _mode_tween: Tween
## 1 fuera de escena, 0 en su sitio. Todo el encuadre se calcula a partir de este valor
## y de márgenes relativos, de modo que sobrevive a un cambio de tamaño de ventana.
var _slide := 1.0
## Alto actual de la ventana (animado) y el que debe alcanzar.
var _panel_height := DialogueStyle.NARRATIVE_HEIGHT
var _target_height := DialogueStyle.NARRATIVE_HEIGHT

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _cast: DialogueCast = $Root/Cast
@onready var _screen_frame: CinematicFrame = $Root/ScreenFrame
@onready var _window: DialogueFrame = $Root/Window
@onready var _reading: Control = $Root/Window/Body/Reading
@onready var _choosing: Control = $Root/Window/Body/Choosing
@onready var _plate: DialogueSpeakerPlate = $Root/Window/Plate
@onready var _text: DialogueText = $Root/Window/Body/Reading/Text
@onready var _divider: GoldDivider = $Root/Window/Body/Reading/Divider
@onready var _continue: DialogueContinueButton = $Root/Window/Body/Reading/Continue
@onready var _choices: DialogueChoices = $Root/Window/Body/Choosing/Choices
@onready var _hint: DialogueChoiceHint = $Root/Window/Body/Choosing/Hint


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	# El texto descansa sobre el separador: su alto es el de las líneas que caben.
	_text.offset_bottom = -_reading_bottom()
	_text.offset_top = _text.offset_bottom - _text.get_area_height()
	_screen_frame.inset = DialogueStyle.SCREEN_FRAME_INSET
	_screen_frame.band_color = Color(DialogueStyle.CHARCOAL, 0.9)
	_screen_frame.emphasis = 2.4
	_root.resized.connect(_on_root_resized)
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
	return _mode == Mode.READING and _text.is_typing()


## Si el texto ya se lee entero y se espera la pulsación para continuar.
func is_waiting_for_input() -> bool:
	return _mode == Mode.READING and _waiting_input


## Si se están mostrando las respuestas.
func is_choosing() -> bool:
	return _mode == Mode.CHOOSING


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


func get_divider() -> GoldDivider:
	return _divider


## Ventana inferior (no confundir con `Node.get_window`, la ventana del sistema).
func get_dialogue_window() -> DialogueFrame:
	return _window


## Alto que tendrá la ventana cuando termine de ajustarse al modo actual.
func get_target_height() -> float:
	return _target_height


# --- Entradas ---

func _process(_delta: float) -> void:
	if not _root.visible:
		return
	_cast.talking = is_typing()
	_layout_window()


func _input(event: InputEvent) -> void:
	if _mode == Mode.CLOSED or not DialogueManager.active:
		return
	if _mode == Mode.CHOOSING:
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
	# Una escena que empieza justo al terminar otra (la confrontación y el epílogo) encuentra la
	# capa aún a la vista: se sigue desde ahí, sin apagarlo todo para volver a encenderlo.
	var continuing := _root.visible
	_npc_id = npc_id
	_first_line = true
	_last_choice = ""
	_waiting_input = false
	_text.clear_line()
	_choices.clear_options()
	_plate.set_text("", false)
	_continue.refresh()
	_continue.set_waiting(false)
	_cast.begin(npc_id)
	_set_interactive(true)
	_root.show()
	_enter_mode(Mode.READING, false)
	_set_height(_narrative_height(), continuing)
	_play_entrance(continuing)


func _on_line_shown(speaker_id: String, text: String) -> void:
	var animate := not _first_line
	_enter_mode(Mode.READING, animate)
	_set_height(_narrative_height(), animate)
	_cast.set_speaker(speaker_id)
	_plate.set_text(_speaker_name(speaker_id))
	_waiting_input = false
	_continue.set_waiting(false)
	var delay := DialogueStyle.FIRST_LINE_DELAY if _first_line else 0.0
	_first_line = false
	_text.show_line(text, speaker_id == NARRATOR, delay)


func _on_options_shown(options: Array) -> void:
	var animate := not _first_line
	_first_line = false
	_text.stop()
	_waiting_input = false
	_continue.set_waiting(false)
	_enter_mode(Mode.CHOOSING, animate)
	_hint.set_text(DialogueControls.choice_hint(options.size()))
	_choices.show_options(options)
	_plate.set_text(DialogueChoices.heading_for(options))
	var list_height := _choices_list_height()
	_choices.offset_bottom = -_choosing_bottom()
	_choices.offset_top = _choices.offset_bottom - list_height
	_set_height(list_height + _choices_chrome(), animate)
	if animate:
		_choices.play_entrance()
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
	DialogueManager.choose(option_id)


func _on_closed(_finished_npc: String) -> void:
	_mode = Mode.CLOSED
	_text.stop()
	_waiting_input = false
	_last_choice = ""
	_continue.set_waiting(false)
	_set_interactive(false)
	_play_exit()


func _on_text_completed() -> void:
	_waiting_input = true
	_continue.set_waiting(true)


## Mientras se desvanece, la conversación ya no acepta clics ni foco: el control vuelve al juego.
func _set_interactive(interactive: bool) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if not interactive and focus_owner != null and _root.is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	_root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if interactive else Control.MOUSE_BEHAVIOR_DISABLED
	_root.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if interactive else Control.FOCUS_BEHAVIOR_DISABLED


# --- Modos y alturas ---

## Pasa a leer o a elegir. El contenido que sale deja de aceptar el ratón y el foco en el acto y se
## desvanece; el que entra aparece justo después.
func _enter_mode(mode: Mode, animate: bool) -> void:
	var was := _mode
	_mode = mode
	var shown := _reading if mode == Mode.READING else _choosing
	var hidden := _choosing if mode == Mode.READING else _reading
	if mode == Mode.READING:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner != null and _choosing.is_ancestor_of(focus_owner):
			focus_owner.release_focus()
	_set_group_enabled(shown, true)
	_set_group_enabled(hidden, false)
	if was == mode and shown.visible and shown.modulate.a > 0.99:
		return
	if _mode_tween != null:
		_mode_tween.kill()
		_mode_tween = null
	if not animate:
		shown.modulate.a = 1.0
		shown.show()
		hidden.hide()
		return
	if not shown.visible:
		shown.modulate.a = 0.0
		shown.show()
	_mode_tween = create_tween().set_parallel()
	_mode_tween.tween_property(shown, "modulate:a", 1.0, DialogueStyle.MODE_IN_SECONDS).set_delay(DialogueStyle.MODE_OUT_SECONDS * 0.5)
	if hidden.visible:
		_mode_tween.tween_property(hidden, "modulate:a", 0.0, DialogueStyle.MODE_OUT_SECONDS)
		_mode_tween.tween_callback(hidden.hide).set_delay(DialogueStyle.MODE_OUT_SECONDS)


static func _set_group_enabled(group: Control, enabled: bool) -> void:
	group.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if enabled else Control.MOUSE_BEHAVIOR_DISABLED
	group.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if enabled else Control.FOCUS_BEHAVIOR_DISABLED


## Ajusta el alto de la ventana: el borde superior, con la placa, sube o baja hasta su sitio.
func _set_height(height: float, animate: bool) -> void:
	_target_height = height
	if _height_tween != null:
		_height_tween.kill()
		_height_tween = null
	if not animate or is_equal_approx(height, _panel_height):
		_panel_height = height
		_layout_window()
		return
	_height_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(self, "_panel_height", height, DialogueStyle.MODE_SECONDS)


## Del pie de la ventana a la base del texto: el separador y la pestaña de continuar.
static func _reading_bottom() -> float:
	return DialogueStyle.DIVIDER_TO_BOTTOM + DialogueStyle.DIVIDER_HEIGHT + DialogueStyle.TEXT_TO_DIVIDER


## Alto de la ventana mientras se lee: el sitio de la placa, el texto, el separador y la pestaña.
func _narrative_height() -> float:
	return DialogueStyle.TEXT_TOP + _text.get_area_height() + _reading_bottom()


## Del pie de la ventana a la última respuesta: el separador con la ayuda.
static func _choosing_bottom() -> float:
	return DialogueStyle.HINT_BOTTOM + DialogueStyle.HINT_HEIGHT + DialogueStyle.CHOICES_TO_HINT


## Lo que ocupa la ventana con las respuestas además de la lista: arriba, el sitio de la placa; abajo,
## el separador con la ayuda.
func _choices_chrome() -> float:
	return DialogueStyle.CHOICES_TOP + _choosing_bottom()


## Alto de la lista: el de todas las respuestas, sin que la ventana pase de su tope; si no caben, la
## lista se desplaza.
func _choices_list_height() -> float:
	var limit := _root.size.y * DialogueStyle.MAX_WINDOW_RATIO - _choices_chrome()
	var minimum := _choices.get_min_height()
	return clampf(_choices.get_content_height(), minimum, maxf(limit, minimum))


## Con otro tamaño de pantalla, la lista de respuestas puede necesitar otro alto.
func _on_root_resized() -> void:
	_layout_window()
	if _mode == Mode.CHOOSING:
		var list_height := _choices_list_height()
		_choices.offset_top = _choices.offset_bottom - list_height
		_set_height(list_height + _choices_chrome(), false)


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


# --- Entrada y salida ---

## El velo y el marco se funden, las siluetas llegan desde los lados y la ventana sube desde el pie.
## Con `continuing`, todo parte de como estaba en lugar de desde fuera de la pantalla.
func _play_entrance(continuing: bool = false) -> void:
	if _transition != null:
		_transition.kill()
	if not continuing:
		_slide = 1.0
		_dim.color.a = 0.0
		_window.modulate.a = 0.0
		_screen_frame.modulate.a = 0.0
	_layout_window()
	_cast.play_entrance(continuing)
	_transition = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(self, "_slide", 0.0, DialogueStyle.OPEN_SECONDS)
	_transition.tween_property(_dim, "color:a", DialogueStyle.DIM.a, 0.35)
	_transition.tween_property(_window, "modulate:a", 1.0, 0.3)
	_transition.tween_property(_screen_frame, "modulate:a", 1.0, 0.35)


## Todo se desvanece y la ventana baja un poco; al terminar, la capa se oculta.
func _play_exit() -> void:
	if _transition != null:
		_transition.kill()
	_cast.play_exit()
	_transition = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transition.tween_property(_dim, "color:a", 0.0, DialogueStyle.CLOSE_SECONDS)
	_transition.tween_property(_window, "modulate:a", 0.0, 0.2)
	_transition.tween_property(self, "_slide", DialogueStyle.CLOSE_SLIDE, DialogueStyle.CLOSE_SECONDS)
	_transition.tween_property(_screen_frame, "modulate:a", 0.0, 0.2)
	_transition.chain().tween_callback(_root.hide)
