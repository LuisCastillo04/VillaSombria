class_name OptionSelector
extends PanelContainer
## Fila de Configuración para elegir un valor de una lista cerrada: el nombre a la izquierda y
## «‹ valor ›» a la derecha, con la explicación debajo a todo el ancho. Con el estilo de las filas de los menús (`MenuStyle`): la
## señalada toma el fondo burdeos y el filete dorado, como las demás opciones.
##
## - Teclado y mando: con el foco en la fila, izquierda y derecha pasan al valor anterior o al
##   siguiente (sin dar la vuelta, como una barra de volumen) y aceptar avanza al siguiente, dando
##   la vuelta al final. Arriba y abajo recorren las filas.
## - Ratón: las flechas cambian el valor; un clic en el valor avanza al siguiente.
## - Desactivada (por ejemplo, la resolución en pantalla completa), se ve atenuada, no cambia y la
##   explicación dice por qué; sigue pudiendo recibir el foco para leerla.

signal value_changed(value: String)

const ARROW_WIDTH := 30.0
const ARROW_SIZE := 8.0
const VALUE_PADDING := 12.0
const TITLE_SIZE := 22
const DETAIL_SIZE := 18
const VALUE_SIZE := 20

var _values: Array[String] = []
var _labels: Array[String] = []
var _index := -1
var _disabled := false
var _hovered := false
var _title: Label
var _detail: Label
var _value: Label
var _previous: Control
var _next: Control
var _normal: StyleBoxFlat
var _highlighted: StyleBoxFlat


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_normal = MenuStyle.row_box()
	_highlighted = MenuStyle.row_box(true)
	add_theme_stylebox_override("panel", _normal)
	add_theme_stylebox_override("focus", CaseFileStyle.focus_ring(4))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	_title = MenuStyle.make_label("", TITLE_SIZE, MenuStyle.TEXT, CaseFileStyle.serif_bold())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_title)
	_detail = MenuStyle.make_label("", DETAIL_SIZE, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail)
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 0)
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picker)
	_previous = _make_arrow(-1)
	picker.add_child(_previous)
	_value = MenuStyle.make_label("", VALUE_SIZE, MenuStyle.TEXT, CaseFileStyle.serif_bold())
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.mouse_filter = Control.MOUSE_FILTER_STOP
	_value.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_value.gui_input.connect(_on_value_input)
	picker.add_child(_value)
	_next = _make_arrow(1)
	picker.add_child(_next)
	focus_entered.connect(_refresh_look)
	focus_exited.connect(_refresh_look)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


## Nombre de la fila y su explicación.
func setup(title: String, detail: String = "") -> void:
	_title.text = title
	set_detail(detail)


func set_detail(detail: String) -> void:
	_detail.text = detail
	_detail.visible = not detail.is_empty()


## Valores posibles y su nombre visible, en el orden en que se recorren. El hueco del valor toma el
## ancho del nombre más largo, para que las flechas no se muevan al cambiar.
func set_options(values: Array[String], labels: Array[String] = []) -> void:
	var current := get_value()
	_values = values.duplicate()
	_labels = labels.duplicate() if labels.size() == values.size() else values.duplicate()
	var font := _value.get_theme_font("font")
	var widest := 0.0
	for label in _labels:
		widest = maxf(widest, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_SIZE).x)
	_value.custom_minimum_size.x = ceilf(widest) + VALUE_PADDING * 2.0
	_index = _values.find(current)
	_show()


## Muestra un valor sin avisar (al leer los ajustes vigentes). Uno que no está en la lista no cambia nada.
func set_value_no_signal(value: String) -> void:
	var index := _values.find(value)
	if index >= 0:
		_index = index
		_show()


func get_value() -> String:
	return _values[_index] if _index >= 0 and _index < _values.size() else ""


func get_value_text() -> String:
	return _value.text


func get_title_text() -> String:
	return _title.text


func get_detail_text() -> String:
	return _detail.text if _detail.visible else ""


func get_options() -> Array[String]:
	return _values.duplicate()


func set_disabled(disabled: bool) -> void:
	_disabled = disabled
	_show()


func is_disabled() -> bool:
	return _disabled


## Pasa al valor anterior (-1) o al siguiente (1). `wrap` da la vuelta al llegar al final.
func step(direction: int, wrap: bool = false) -> void:
	if _disabled or _values.is_empty():
		return
	var target := _index + direction
	if wrap:
		target = posmod(target, _values.size())
	elif target < 0 or target >= _values.size():
		return
	if target == _index:
		return
	AudioManager.play("click")
	_index = target
	_show()
	value_changed.emit(get_value())


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		accept_event()
		step(-1)
	elif event.is_action_pressed("ui_right", true):
		accept_event()
		step(1)
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		step(1, true)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		grab_focus()


func _on_value_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		step(1, true)
		_value.accept_event()


func _on_arrow_input(event: InputEvent, direction: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		step(direction)
		(_previous if direction < 0 else _next).accept_event()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_refresh_look()


func _refresh_look() -> void:
	add_theme_stylebox_override("panel", _highlighted if (has_focus() or _hovered) and not _disabled else _normal)
	queue_redraw()
	_previous.queue_redraw()
	_next.queue_redraw()


func _show() -> void:
	_value.text = _labels[_index] if _index >= 0 and _index < _labels.size() else ""
	var color := MenuStyle.TEXT_MUTED if _disabled else MenuStyle.TEXT
	_value.add_theme_color_override("font_color", color)
	_title.add_theme_color_override("font_color", MenuStyle.TEXT_MUTED if _disabled else MenuStyle.TEXT)
	_previous.mouse_default_cursor_shape = Control.CURSOR_ARROW if _disabled else Control.CURSOR_POINTING_HAND
	_next.mouse_default_cursor_shape = _previous.mouse_default_cursor_shape
	_refresh_look()


## Flecha dibujada en código (un triángulo dorado), atenuada si no hay a dónde ir.
func _make_arrow(direction: int) -> Control:
	var arrow := Control.new()
	arrow.name = "Anterior" if direction < 0 else "Siguiente"
	arrow.custom_minimum_size = Vector2(ARROW_WIDTH, ARROW_WIDTH)
	arrow.mouse_filter = Control.MOUSE_FILTER_STOP
	arrow.gui_input.connect(_on_arrow_input.bind(direction))
	arrow.draw.connect(func() -> void:
		var can_move := not _disabled and (_index + direction >= 0 and _index + direction < _values.size())
		var color := MenuStyle.GOLD if can_move else Color(MenuStyle.GOLD, 0.25)
		if can_move and (has_focus() or _hovered):
			color = CaseFileStyle.GOLD_LIGHT
		var center := arrow.size * 0.5
		var tip := Vector2(ARROW_SIZE * direction, 0.0)
		var back := Vector2(-ARROW_SIZE * 0.6 * direction, 0.0)
		arrow.draw_colored_polygon(PackedVector2Array([
			center + tip,
			center + back + Vector2(0.0, -ARROW_SIZE),
			center + back + Vector2(0.0, ARROW_SIZE),
		]), color))
	return arrow


func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox("focus"), Rect2(Vector2.ZERO, size))
