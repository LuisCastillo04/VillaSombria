class_name MenuActionRow
extends PanelContainer
## Fila de una lista de menú que abre algo: su nombre y una explicación a la izquierda y, a la
## derecha, una flecha dorada. Tiene el aspecto de las filas de controles y de las opciones previstas,
## pero activa: se señala con el ratón, el teclado o el mando (fondo burdeos y filete dorado, como el
## resto de filas) y se pulsa con aceptar o con un clic.

signal pressed

const TITLE_SIZE := 20
const DETAIL_SIZE := 17
const ARROW_SIZE := 7.0

var _title: Label
var _detail: Label
var _arrow: Control
var _hovered := false


func _init(title_text: String = "", detail_text: String = "") -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = MenuStyle.make_label(title_text, TITLE_SIZE, MenuStyle.TEXT, CaseFileStyle.serif_bold())
	texts.add_child(_title)
	_detail = MenuStyle.make_label(detail_text, DETAIL_SIZE, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_detail)
	box.add_child(texts)
	_arrow = Control.new()
	_arrow.custom_minimum_size = Vector2(22.0, 22.0)
	_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	box.add_child(_arrow)
	add_child(box)


func _ready() -> void:
	focus_entered.connect(_refresh_look)
	focus_exited.connect(_refresh_look)
	mouse_entered.connect(func() -> void:
		_hovered = true
		if is_visible_in_tree():
			grab_focus()
		_refresh_look())
	mouse_exited.connect(func() -> void:
		_hovered = false
		_refresh_look())
	_refresh_look()


func get_title() -> String:
	return _title.text


func get_detail() -> String:
	return _detail.text


func set_detail(text: String) -> void:
	_detail.text = text


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if event.is_action_pressed("ui_accept") or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		accept_event()
		grab_focus()
		pressed.emit()


func _refresh_look() -> void:
	add_theme_stylebox_override("panel", MenuStyle.row_box(has_focus() or _hovered))
	_arrow.queue_redraw()


func _draw_arrow() -> void:
	var color := CaseFileStyle.GOLD_LIGHT if has_focus() or _hovered else MenuStyle.GOLD
	var center := _arrow.size * 0.5
	_arrow.draw_colored_polygon(PackedVector2Array([
		center + Vector2(ARROW_SIZE, 0.0),
		center + Vector2(-ARROW_SIZE * 0.6, -ARROW_SIZE),
		center + Vector2(-ARROW_SIZE * 0.6, ARROW_SIZE),
	]), color)
