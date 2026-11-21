class_name EvidenceCloseButton
extends Button
## Único control de la inspección: «[E] Cerrar», montado sobre el filete inferior del marco. La
## tecla sale del InputMap (la de interactuar, o su botón del mando), así que una reasignación se
## ve aquí sin tocar nada. También se pulsa con el ratón; no toma el foco, para que el botón de
## aceptar del mando nunca lo active por su cuenta.

const CUT := 8.0
const GAP := 18.0

var _content: HBoxContainer
var _key: KeyCap
var _label: Label
var _hovered := false


func _init() -> void:
	name = "Close"
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", GAP)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key = KeyCap.new()
	_content.add_child(_key)
	_label = EvidenceStyle.make_label("Cerrar", EvidenceStyle.plate_font(), EvidenceStyle.CLOSE_SIZE_TEXT, EvidenceStyle.CREAM)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.add_child(_label)
	add_child(_content)
	custom_minimum_size = EvidenceStyle.CLOSE_SIZE
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(_center_content)
	_content.minimum_size_changed.connect(_center_content)


func _ready() -> void:
	refresh_keys()


## Vuelve a leer la tecla de cerrar del InputMap (o el botón del mando que se esté usando).
func refresh_keys() -> void:
	_key.text = key_name()
	_key.visible = not _key.text.is_empty()
	_center_content()


## Texto completo del botón, como lo lee el jugador: «E Cerrar».
func get_label_text() -> String:
	return ("%s %s" % [_key.text, _label.text]).strip_edges()


func get_key_text() -> String:
	return _key.text


## La primera tecla de interactuar; si no tiene, la de aceptar.
static func key_name() -> String:
	for action: String in ClueInspector.CLOSE_ACTIONS:
		var keys := InputLabels.keys_of(action, InputLabels.Device.CURRENT)
		if not keys.is_empty():
			return keys[0]
	return ""


func _set_hovered(value: bool) -> void:
	_hovered = value
	_label.add_theme_color_override("font_color", EvidenceStyle.GOLD_LIGHT if value else EvidenceStyle.CREAM)
	queue_redraw()


func _center_content() -> void:
	var needed := _content.get_combined_minimum_size()
	_content.size = needed
	_content.position = ((size - needed) * 0.5).round()


func _draw() -> void:
	var border := EvidenceStyle.GOLD_LIGHT if _hovered else EvidenceStyle.GOLD
	var top := EvidenceStyle.CHARCOAL_LIGHT.lightened(0.06 if _hovered else 0.0)
	EvidenceOrnaments.draw_plate(self, Rect2(Vector2.ZERO, size), CUT, top, EvidenceStyle.CHARCOAL, border, Color(EvidenceStyle.GOLD, 0.35))
