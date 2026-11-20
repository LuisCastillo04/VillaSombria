class_name JournalListItem
extends Button
## Ficha de una lista del expediente: miniatura (retrato o icono), título y, si lo hay, un subtítulo
## en cursiva. La elegida se ilumina con un borde dorado y lleva una esquina burdeos, como la de la
## carpeta. Recibir el foco con el teclado o el mando también la elige.

const MAX_TITLE_LINES := 2
const CORNER := 13.0

var entry_id := ""

var _content: HBoxContainer
var _thumb: JournalThumb
var _title: Label
var _subtitle: Label


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = JournalStyle.ROW_HEIGHT
	add_theme_stylebox_override("normal", JournalStyle.row_box("normal"))
	add_theme_stylebox_override("hover", JournalStyle.row_box("hover"))
	add_theme_stylebox_override("pressed", JournalStyle.row_box("selected"))
	add_theme_stylebox_override("hover_pressed", JournalStyle.row_box("selected"))
	add_theme_stylebox_override("focus", JournalStyle.focus_ring(4))
	_content = HBoxContainer.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 16)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_thumb = JournalThumb.new()
	_content.add_child(_thumb)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", -2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = JournalStyle.make_label("", JournalStyle.heading_font(), JournalStyle.ROW_SIZE - 1, JournalStyle.INK, true)
	_title.max_lines_visible = MAX_TITLE_LINES
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_title)
	_subtitle = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.ROW_SUBTITLE_SIZE, JournalStyle.INK_SOFT)
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.hide()
	texts.add_child(_subtitle)
	_content.add_child(texts)
	add_child(_content)
	_content.minimum_size_changed.connect(_fit_height)
	focus_entered.connect(_on_focus_entered)
	toggled.connect(func(_pressed: bool) -> void: queue_redraw())


## Rellena la ficha con `{id, title, subtitle, portrait | icon}`.
func setup(entry: Dictionary) -> void:
	entry_id = entry.get("id", "")
	name = "Item_%s" % entry_id
	_title.text = entry.get("title", "")
	var subtitle: String = entry.get("subtitle", "")
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	var portrait: Texture2D = entry.get("portrait")
	if portrait != null:
		_thumb.set_portrait(portrait)
	else:
		_thumb.set_icon(entry.get("icon", "lupa"), JournalStyle.BURGUNDY_INK)
	tooltip_text = ""
	_fit_height()


func get_title() -> String:
	return _title.text


func get_subtitle() -> String:
	return _subtitle.text if _subtitle.visible else ""


func get_thumb() -> JournalThumb:
	return _thumb


## Si el título se ve entero, sin puntos suspensivos.
func is_title_complete() -> bool:
	return _title.get_line_count() <= MAX_TITLE_LINES


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		_place_content()


## El botón no crece con sus hijos: la altura sigue al contenido, con los márgenes del recuadro.
func _fit_height() -> void:
	var box := get_theme_stylebox("normal")
	var needed := _content.get_combined_minimum_size().y + box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM)
	custom_minimum_size.y = maxf(JournalStyle.ROW_HEIGHT, needed)


func _place_content() -> void:
	var box := get_theme_stylebox("normal")
	_content.offset_left = box.get_margin(SIDE_LEFT)
	_content.offset_top = box.get_margin(SIDE_TOP)
	_content.offset_right = -box.get_margin(SIDE_RIGHT)
	_content.offset_bottom = -box.get_margin(SIDE_BOTTOM)


func _on_focus_entered() -> void:
	if not button_pressed:
		button_pressed = true


func _draw() -> void:
	if not button_pressed:
		return
	var corner := Vector2(size.x - 5.0, size.y - 5.0)
	draw_colored_polygon(PackedVector2Array([corner, corner - Vector2(CORNER, 0.0), corner - Vector2(0.0, CORNER)]), JournalStyle.BURGUNDY)
