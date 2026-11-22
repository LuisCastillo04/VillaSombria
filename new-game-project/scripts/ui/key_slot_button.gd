class_name KeySlotButton
extends Button
## Hueco de una tecla en la pantalla de reasignación: la principal o la alternativa de una acción,
## con el recuadro oscuro y el filete dorado de `KeyCap`. Pulsarlo (Intro, el botón de aceptar del
## mando o un clic) pide la tecla nueva; el clic derecho pide quitar la alternativa. Señalado, toma el
## burdeos de la selección de los menús, y mientras espera una tecla lo dice dentro del recuadro.

## El jugador pide quitar la tecla de este hueco (clic derecho).
signal clear_requested

const WIDTH := 172.0
const FONT_SIZE := 19
const WAITING_TEXT := "Pulsa una tecla…"
const EMPTY_TEXT := "—"

## Acción y hueco (0, la principal; 1, la alternativa) que representa.
var action := ""
var slot := 0

var _code: Key = KEY_NONE
var _waiting := false


func _init(slot_action: String = "", slot_index: int = 0) -> void:
	action = slot_action
	slot = slot_index
	name = "%s_%d" % [slot_action, slot_index]
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(WIDTH, KeyCap.HEIGHT + 4.0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = EMPTY_TEXT


func _ready() -> void:
	add_theme_font_override("font", CaseFileStyle.serif_bold())
	add_theme_font_size_override("font_size", FONT_SIZE)
	focus_entered.connect(_refresh_look)
	focus_exited.connect(_refresh_look)
	# Como en el resto de menús, señalar con el ratón también da el foco.
	mouse_entered.connect(func() -> void:
		if is_visible_in_tree() and not disabled:
			grab_focus())
	_refresh_look()


## Muestra la tecla del hueco, o una raya si está vacío.
func set_key(code: Key) -> void:
	_code = code
	_refresh_look()


func get_key() -> Key:
	return _code


func get_key_text() -> String:
	return InputLabels.code_name(_code) if _code != KEY_NONE else ""


## Mientras espera la tecla nueva, el recuadro lo dice y se queda encendido.
func set_waiting(waiting: bool) -> void:
	_waiting = waiting
	_refresh_look()


func is_waiting() -> bool:
	return _waiting


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		grab_focus()
		clear_requested.emit()


func _refresh_look() -> void:
	var lit := _waiting or has_focus()
	if _waiting:
		text = WAITING_TEXT
	else:
		text = get_key_text() if _code != KEY_NONE else EMPTY_TEXT
	var box := MenuStyle.keycap_box()
	if lit:
		box.bg_color = MenuStyle.SELECTION if not _waiting else MenuStyle.SELECTION.darkened(0.25)
		box.border_color = CaseFileStyle.GOLD_LIGHT
		box.set_border_width_all(2)
		box.border_width_bottom = 3
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, box)
	var color := MenuStyle.TEXT
	if _waiting:
		color = CaseFileStyle.GOLD_LIGHT
	elif _code == KEY_NONE:
		color = MenuStyle.TEXT_MUTED
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, color)
	add_theme_font_override("font", CaseFileStyle.serif_italic() if _waiting else CaseFileStyle.serif_bold())
