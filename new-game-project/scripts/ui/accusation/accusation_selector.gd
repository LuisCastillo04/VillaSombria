class_name AccusationSelector
extends Button
## Selector de un campo de la acusación: un recuadro de papel claro con la elección (y el icono de
## su clase) o, si está vacío, un texto de ayuda en cursiva. A la derecha lleva una flecha: hacia
## abajo si despliega una lista debajo (el sospechoso) y hacia la derecha si abre el panel lateral
## (las pruebas).
##
## Pendiente y elegido se distinguen por el recuadro y la letra, nunca por si la elección es buena.
## Mientras su lista está abierta (`active`) lleva el filete burdeos.

enum Arrow { DOWN, SIDE }

const ICON_SIZE := 30.0
const ARROW_MARGIN := 26.0

var arrow := Arrow.DOWN:
	set(value):
		arrow = value
		queue_redraw()
var placeholder := "":
	set(value):
		placeholder = value
		_refresh()
var active := false:
	set(value):
		active = value
		_refresh()

var _value := ""
var _type_icon: Texture2D
var _content: HBoxContainer
var _icon: TextureRect
var _label: Label


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = AccusationStyle.SELECTOR_HEIGHT
	add_theme_stylebox_override("focus", AccusationStyle.focus_ring(4))
	_content = HBoxContainer.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 12)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.modulate = AccusationStyle.BURGUNDY_INK
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.hide()
	_content.add_child(_icon)
	_label = AccusationStyle.make_label("", AccusationStyle.body_font(), AccusationStyle.SELECTOR_SIZE, AccusationStyle.INK)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.clip_text = true
	_content.add_child(_label)
	add_child(_content)
	_refresh()


func _ready() -> void:
	resized.connect(_place_content)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	_place_content()


## Muestra una elección (`text` vacío deja el campo pendiente) con el icono de su clase, si lo tiene.
func set_value(text: String, type_icon: Texture2D = null) -> void:
	_value = text
	_type_icon = type_icon
	_refresh()


func get_value_text() -> String:
	return _value


## Lo que se lee en el recuadro: la elección o el texto de ayuda.
func get_display_text() -> String:
	return _label.text


func is_filled() -> bool:
	return not _value.is_empty()


func get_box_state() -> String:
	if active:
		return "active"
	return "filled" if is_filled() else "empty"


func _refresh() -> void:
	if _label == null:
		return
	var filled := is_filled()
	_label.text = _value if filled else placeholder
	_label.add_theme_font_override("font", AccusationStyle.body_font() if filled else AccusationStyle.italic_font())
	_label.add_theme_color_override("font_color", AccusationStyle.INK if filled else Color(AccusationStyle.INK_SOFT, 0.9))
	_icon.texture = _type_icon
	_icon.visible = filled and _type_icon != null
	var state := get_box_state()
	add_theme_stylebox_override("normal", AccusationStyle.selector_box(state))
	add_theme_stylebox_override("hover", AccusationStyle.selector_box("active" if active else "hover"))
	add_theme_stylebox_override("pressed", AccusationStyle.selector_box("active"))
	add_theme_stylebox_override("hover_pressed", AccusationStyle.selector_box("active"))
	tooltip_text = _value if filled else ""
	_place_content()
	queue_redraw()


func _place_content() -> void:
	if _content == null:
		return
	var box := get_theme_stylebox("normal")
	_content.position = Vector2(box.get_margin(SIDE_LEFT), box.get_margin(SIDE_TOP))
	_content.size = Vector2(maxf(size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT), 0.0), maxf(size.y - box.get_margin(SIDE_TOP) - box.get_margin(SIDE_BOTTOM), 0.0))


func _draw() -> void:
	var center := Vector2(size.x - ARROW_MARGIN, size.y * 0.5)
	var color := AccusationStyle.BURGUNDY if active or is_hovered() else AccusationStyle.INK
	var points: PackedVector2Array
	if arrow == Arrow.DOWN:
		points = PackedVector2Array([center + Vector2(-9.0, -5.0), center + Vector2(9.0, -5.0), center + Vector2(0.0, 6.0)])
	else:
		points = PackedVector2Array([center + Vector2(-5.0, -9.0), center + Vector2(6.0, 0.0), center + Vector2(-5.0, 9.0)])
	draw_colored_polygon(points, color)
	# Filete vertical que separa la flecha del texto.
	var x := size.x - ARROW_MARGIN * 2.0 + 4.0
	draw_line(Vector2(x, 12.0), Vector2(x, size.y - 12.0), Color(AccusationStyle.INK, 0.18), 1.0, true)
