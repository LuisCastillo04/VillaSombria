class_name AccusationListRow
extends Button
## Fila de una lista de la acusación: una prueba del panel lateral o un sospechoso de la lista
## desplegable. Lleva una miniatura (el icono de su clase o un retrato), el título y, si lo hay, un
## subtítulo en cursiva. La que está elegida en el campo (`chosen`) va en burdeos con filete dorado;
## al pasar el ratón se aclara y con el teclado o el mando lleva el contorno dorado del foco.

## Se señala con el ratón o recibe el foco: el panel muestra entonces su descripción.
signal highlighted(item_id: String)

var item_id := ""
var chosen := false:
	set(value):
		chosen = value
		_restyle()
## Filete de tinta bajo la fila, para separarla de la siguiente.
var show_separator := true:
	set(value):
		show_separator = value
		queue_redraw()

var _content: HBoxContainer
var _thumb: JournalThumb
var _title: Label
var _subtitle: Label
var _icon_name := ""
var _row_height := AccusationStyle.ROW_HEIGHT


func _init(row_height: float = AccusationStyle.ROW_HEIGHT, thumb_size: float = 34.0) -> void:
	_row_height = row_height
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = row_height
	add_theme_stylebox_override("focus", AccusationStyle.focus_ring(3))
	_content = HBoxContainer.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 14)
	_thumb = JournalThumb.new(thumb_size)
	_content.add_child(_thumb)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", -3)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = AccusationStyle.make_label("", AccusationStyle.body_font(), AccusationStyle.ROW_SIZE, AccusationStyle.INK)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	texts.add_child(_title)
	_subtitle = AccusationStyle.make_label("", AccusationStyle.italic_font(), AccusationStyle.SUSPECT_ROLE_SIZE, AccusationStyle.INK_SOFT)
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.clip_text = true
	_subtitle.hide()
	texts.add_child(_subtitle)
	_content.add_child(texts)
	add_child(_content)
	mouse_entered.connect(_on_highlight)
	focus_entered.connect(_on_highlight)
	resized.connect(_place_content)
	_restyle()


## Rellena la fila con `{id, title, subtitle, icon | portrait}`.
func setup(entry: Dictionary) -> void:
	item_id = entry.get("id", "")
	name = "Row_%s" % item_id
	_title.text = entry.get("title", "")
	var subtitle: String = entry.get("subtitle", "")
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	var portrait: Texture2D = entry.get("portrait")
	if portrait != null:
		_icon_name = ""
		_thumb.set_portrait(portrait)
	else:
		_icon_name = entry.get("icon", "documento")
	tooltip_text = entry.get("tooltip", "")
	_restyle()


func get_title() -> String:
	return _title.text


func get_subtitle() -> String:
	return _subtitle.text if _subtitle.visible else ""


func get_icon_name() -> String:
	return _icon_name


func _restyle() -> void:
	add_theme_stylebox_override("normal", AccusationStyle.row_box("selected" if chosen else "normal"))
	add_theme_stylebox_override("hover", AccusationStyle.row_box("selected_hover" if chosen else "hover"))
	add_theme_stylebox_override("pressed", AccusationStyle.row_box("selected_hover" if chosen else "hover"))
	add_theme_stylebox_override("hover_pressed", AccusationStyle.row_box("selected_hover" if chosen else "hover"))
	if _title == null:
		return
	_title.add_theme_color_override("font_color", AccusationStyle.CREAM if chosen else AccusationStyle.INK)
	_subtitle.add_theme_color_override("font_color", AccusationStyle.CREAM_SOFT if chosen else AccusationStyle.INK_SOFT)
	if not _icon_name.is_empty():
		_thumb.set_icon(_icon_name, AccusationStyle.CREAM if chosen else AccusationStyle.BURGUNDY_INK)
	_place_content()
	queue_redraw()


func _place_content() -> void:
	var box := get_theme_stylebox("normal")
	_content.position = Vector2(box.get_margin(SIDE_LEFT), box.get_margin(SIDE_TOP))
	_content.size = Vector2(maxf(size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT), 0.0), maxf(size.y - box.get_margin(SIDE_TOP) - box.get_margin(SIDE_BOTTOM), 0.0))


func _on_highlight() -> void:
	highlighted.emit(item_id)


func _draw() -> void:
	if chosen:
		# Rombo dorado a la derecha: la elección actual del campo.
		HudOrnaments.draw_diamond(self, Vector2(size.x - 18.0, size.y * 0.5), 5.0, AccusationStyle.GOLD_LIGHT)
	elif show_separator:
		draw_line(Vector2(8.0, size.y - 0.5), Vector2(size.x - 8.0, size.y - 0.5), Color(AccusationStyle.INK, 0.16), 1.0, true)
