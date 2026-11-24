class_name AccusationEvidencePanel
extends AccusationSheet
## Panel lateral para elegir la prueba o el testimonio de un campo de la acusación (motivo,
## oportunidad o medios). Es otra hoja del mismo papel y el mismo marco que el formulario, con:
##
## - un encabezado burdeos que dice qué campo se edita («Seleccionar prueba del motivo») y lleva su
##   medallón y un botón de cierre;
## - un buscador que filtra por nombre o por contenido, sin distinguir mayúsculas ni tildes;
## - la lista desplazable, agrupada en pruebas, testimonios y deducciones, con el icono de la clase
##   de cada elemento y la elección actual en burdeos;
## - una vista previa con la descripción de lo que se señala, para recordar qué dice sin salir;
## - las teclas para volver y para elegir, leídas del InputMap.
##
## Sólo enseña lo que `AccusationInfo.options` le da: lo descubierto que pertenece a la categoría,
## sin marcar nunca cuál es la respuesta buena. Elegir avisa con `item_chosen`; cerrar, con
## `close_requested`. Quien lo usa decide qué hacer.

signal item_chosen(item_id: String)
signal close_requested

const FOOTER_HEIGHT := 48.0
const PREVIEW_HEIGHT := 150.0
const PREVIEW_LINES := 4
const BODY_MARGIN := Vector4(22.0, 16.0, 16.0, 6.0)
const CLOSE_SIZE := 46.0

var field_key := ""

var _options: Array[Dictionary] = []
var _chosen_id := ""
var _preview_id := ""
var _layout: VBoxContainer
var _header: Control
var _title: Label
var _subtitle: Label
var _close: Button
var _search: LineEdit
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty: VBoxContainer
var _empty_title: Label
var _empty_hint: Label
var _preview: PanelContainer
var _preview_icon: TextureRect
var _preview_title: Label
var _preview_type: Label
var _preview_text: Label
var _footer: HBoxContainer


func _init() -> void:
	super()
	coffee_ring = false
	paper_seed = 2.6
	_layout = VBoxContainer.new()
	_layout.name = "Layout"
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_theme_constant_override("separation", 0)
	add_child(_layout)
	_build_header()
	_build_body()
	_build_footer()


func _fit() -> void:
	super._fit()
	if _layout == null:
		return
	var paper := get_paper_rect()
	_layout.position = paper.position
	_layout.size = paper.size


# --- Uso ---

## Prepara el panel para un campo: su título, sus opciones y la elección actual (`chosen_id`).
## El buscador empieza vacío.
func open_for(field: String, chosen_id: String) -> void:
	field_key = field
	_chosen_id = chosen_id
	_title.text = AccusationInfo.PANEL_TITLES.get(field, "Seleccionar prueba")
	_subtitle.text = AccusationInfo.QUESTIONS.get(field, "")
	_fit_title()
	_header.queue_redraw()
	_options = AccusationInfo.options(field)
	_search.text = ""
	_rebuild()
	_show_preview(chosen_id if get_row(chosen_id) != null else (_options[0]["id"] if not _options.is_empty() else ""))
	_scroll.scroll_vertical = 0


## Da el foco a la elección actual o, si no está a la vista, a la primera fila; sin filas, al
## buscador. Devuelve si algo recibió el foco.
func focus_list() -> bool:
	var target := get_row(_chosen_id)
	if target == null or not target.visible:
		var rows := get_visible_rows()
		target = rows[0] if not rows.is_empty() else null
	if target != null:
		target.grab_focus()
		_reveal(target)
		return true
	if _search.visible:
		_search.grab_focus()
		return true
	return false


func get_title() -> String:
	return _title.text


func get_subtitle() -> String:
	return _subtitle.text


func get_search() -> LineEdit:
	return _search


func get_scroll() -> ScrollContainer:
	return _scroll


func get_close_button() -> Button:
	return _close


## Identificadores de todas las opciones del campo, en el orden de la lista.
func get_option_ids() -> Array[String]:
	var ids: Array[String] = []
	for option in _options:
		ids.append(option["id"])
	return ids


func get_rows() -> Array[AccusationListRow]:
	var rows: Array[AccusationListRow] = []
	for child in _list.get_children():
		if child is AccusationListRow and not child.is_queued_for_deletion():
			rows.append(child)
	return rows


func get_visible_rows() -> Array[AccusationListRow]:
	var rows: Array[AccusationListRow] = []
	for row in get_rows():
		if row.visible:
			rows.append(row)
	return rows


func get_row(item_id: String) -> AccusationListRow:
	if item_id.is_empty():
		return null
	for row in get_rows():
		if row.item_id == item_id:
			return row
	return null


## Rótulos de los grupos que se ven ahora («Pruebas (4)»…).
func get_visible_groups() -> PackedStringArray:
	var titles := PackedStringArray()
	for child in _list.get_children():
		if child.has_meta("group") and (child as Control).visible:
			titles.append((child.get_node("Label") as Label).text)
	return titles


func is_showing_empty() -> bool:
	return _empty.visible


func get_empty_text() -> String:
	return ("%s %s" % [_empty_title.text, _empty_hint.text if _empty_hint.visible else ""]).strip_edges()


func get_preview_id() -> String:
	return _preview_id


func get_preview_text() -> String:
	return _preview_text.text


## Filtra la lista como si el jugador escribiera `text` en el buscador.
func set_query(text: String) -> void:
	_search.text = text
	_apply_filter()


## Si el jugador escribe una letra mientras recorre la lista, la letra va al buscador. Las teclas
## que el InputMap usa para moverse, aceptar o volver nunca se desvían. Devuelve si la atendió.
func handle_type_to_search(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not _search.visible or _search.has_focus():
		return false
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.unicode <= 32:
		return false
	for action: StringName in [&"ui_accept", &"ui_cancel", &"pause", &"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev", &"ui_page_up", &"ui_page_down", &"ui_select"]:
		if InputMap.has_action(action) and InputMap.event_is_action(key, action):
			return false
	_search.grab_focus()
	_search.insert_text_at_caret(char(key.unicode))
	return true


## Vuelve a leer las teclas del pie (por si se han reasignado o se juega con mando). Sin nada que
## elegir, sólo queda la de volver.
func refresh_keys() -> void:
	for child in _footer.get_children():
		_footer.remove_child(child)
		child.queue_free()
	_add_hint("ui_cancel", "Volver al formulario")
	if not _options.is_empty():
		_add_hint("ui_accept", "Elegir")


## Rótulos del pie, como se leen: «Esc Volver al formulario», «Intro Elegir».
func get_hint_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	var pending := ""
	for child in _footer.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is KeyCap:
			pending = (child as KeyCap).text
		elif child is Label:
			texts.append(("%s %s" % [pending, (child as Label).text]).strip_edges())
			pending = ""
	return texts


## El título del encabezado se reduce hasta que cabe entero.
func _fit_title() -> void:
	var available := AccusationStyle.PANEL_SIZE.x - AccusationStyle.FRAME_WIDTH * 2.0 - 92.0 - 18.0 - CLOSE_SIZE - 24.0
	var font := AccusationStyle.body_font()
	var font_size := AccusationStyle.PANEL_TITLE_SIZE
	while font_size > 20 and font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 1
	_title.add_theme_font_size_override("font_size", font_size)


# --- Construcción ---

func _build_header() -> void:
	_header = Control.new()
	_header.name = "Header"
	_header.custom_minimum_size.y = AccusationStyle.PANEL_HEADER_HEIGHT
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.draw.connect(_draw_header)
	_layout.add_child(_header)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 92.0
	row.offset_right = -18.0
	row.offset_top = 4.0
	row.offset_bottom = -10.0
	_header.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 1)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = AccusationStyle.make_label("", AccusationStyle.body_font(), AccusationStyle.PANEL_TITLE_SIZE, AccusationStyle.CREAM)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	texts.add_child(_title)
	_subtitle = AccusationStyle.make_label("", AccusationStyle.italic_font(), AccusationStyle.PANEL_SUBTITLE_SIZE, AccusationStyle.CREAM_SOFT)
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.clip_text = true
	texts.add_child(_subtitle)
	row.add_child(texts)
	_close = Button.new()
	_close.name = "Close"
	_close.focus_mode = Control.FOCUS_NONE
	_close.tooltip_text = "Volver al formulario"
	_close.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var plate := AccusationStyle.box(AccusationStyle.BURGUNDY, AccusationStyle.GOLD, 2, 4)
	var plate_hover := AccusationStyle.box(AccusationStyle.BURGUNDY_LIGHT, AccusationStyle.GOLD_LIGHT, 2, 4)
	_close.add_theme_stylebox_override("normal", plate)
	_close.add_theme_stylebox_override("hover", plate_hover)
	_close.add_theme_stylebox_override("pressed", AccusationStyle.box(AccusationStyle.BURGUNDY_DARK, AccusationStyle.GOLD, 2, 4))
	_close.add_theme_stylebox_override("hover_pressed", plate_hover)
	_close.draw.connect(_draw_close_cross)
	_close.mouse_entered.connect(_close.queue_redraw)
	_close.mouse_exited.connect(_close.queue_redraw)
	_close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(_close)


func _build_body() -> void:
	var margin := MarginContainer.new()
	margin.name = "Body"
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(BODY_MARGIN.x))
	margin.add_theme_constant_override("margin_top", int(BODY_MARGIN.y))
	margin.add_theme_constant_override("margin_right", int(BODY_MARGIN.z))
	margin.add_theme_constant_override("margin_bottom", int(BODY_MARGIN.w))
	_layout.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Buscar por nombre o contenido…"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(0.0, 48.0)
	_search.caret_blink = true
	AccusationStyle.apply_search(_search)
	var glass := AccusationStyle.make_icon("lupa", 24.0, Color(AccusationStyle.INK_SOFT, 0.85))
	glass.position = Vector2(14.0, 12.0)
	glass.size = Vector2(24.0, 24.0)
	_search.add_child(glass)
	_search.text_changed.connect(func(_text: String) -> void: _apply_filter())
	_search.text_submitted.connect(func(_text: String) -> void: focus_list())
	column.add_child(_search)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	AccusationStyle.style_scroll(_scroll)
	column.add_child(_scroll)
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_theme_constant_override("margin_right", 12)
	inset.add_theme_constant_override("margin_left", 4)
	inset.add_theme_constant_override("margin_top", 4)
	inset.add_theme_constant_override("margin_bottom", 4)
	_scroll.add_child(inset)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 2)
	inset.add_child(_list)
	_empty = VBoxContainer.new()
	_empty.name = "Empty"
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_theme_constant_override("separation", 14)
	var empty_icon := AccusationStyle.make_icon("carpeta_vacia", 64.0, Color(AccusationStyle.INK_SOFT, 0.7))
	empty_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty.add_child(empty_icon)
	_empty_title = AccusationStyle.make_label("", AccusationStyle.italic_font(), AccusationStyle.EMPTY_SIZE, AccusationStyle.INK, true)
	_empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(_empty_title)
	_empty_hint = AccusationStyle.make_label(AccusationInfo.EMPTY_HINT, AccusationStyle.body_font(), AccusationStyle.EMPTY_SIZE - 3, AccusationStyle.INK_SOFT, true)
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(_empty_hint)
	_empty.hide()
	column.add_child(_empty)
	_build_preview(column)


func _build_preview(column: VBoxContainer) -> void:
	_preview = PanelContainer.new()
	_preview.name = "Preview"
	_preview.custom_minimum_size.y = PREVIEW_HEIGHT
	_preview.clip_contents = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := AccusationStyle.box(Color(AccusationStyle.INK, 0.06), Color(AccusationStyle.INK, 0.24), 1, 4, Vector4(18.0, 10.0, 18.0, 10.0))
	inset.shadow_color = Color(1.0, 0.98, 0.9, 0.35)
	inset.shadow_size = 1
	inset.shadow_offset = Vector2(0.0, 1.0)
	_preview.add_theme_stylebox_override("panel", inset)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	_preview.add_child(rows)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 10)
	rows.add_child(heading)
	_preview_icon = AccusationStyle.make_icon("documento", 24.0, AccusationStyle.BURGUNDY_INK)
	heading.add_child(_preview_icon)
	_preview_title = AccusationStyle.make_label("", AccusationStyle.heading_font(), AccusationStyle.PREVIEW_TITLE_SIZE, AccusationStyle.INK)
	_preview_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_preview_title.clip_text = true
	heading.add_child(_preview_title)
	_preview_type = AccusationStyle.make_label("", AccusationStyle.italic_font(), AccusationStyle.PREVIEW_SIZE - 1, AccusationStyle.BURGUNDY_INK)
	heading.add_child(_preview_type)
	_preview_text = AccusationStyle.make_label("", AccusationStyle.italic_font(), AccusationStyle.PREVIEW_SIZE, AccusationStyle.INK_SOFT, true)
	_preview_text.max_lines_visible = PREVIEW_LINES
	_preview_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	# Con ajuste de línea y puntos suspensivos, una etiqueta pide 1 px de alto: se le da el de sus líneas.
	_preview_text.custom_minimum_size.y = AccusationStyle.italic_font().get_height(AccusationStyle.PREVIEW_SIZE) * PREVIEW_LINES
	rows.add_child(_preview_text)
	column.add_child(_preview)


func _build_footer() -> void:
	var bar := MarginContainer.new()
	bar.name = "Footer"
	bar.custom_minimum_size.y = FOOTER_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("margin_left", 22)
	bar.add_theme_constant_override("margin_right", 22)
	bar.add_theme_constant_override("margin_bottom", 8)
	_layout.add_child(bar)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_theme_constant_override("separation", 10)
	bar.add_child(_footer)


func _add_hint(action: String, label: String) -> void:
	var keys := InputLabels.keys_of(action, InputLabels.Device.CURRENT)
	if keys.is_empty():
		return
	if _footer.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.x = 16.0
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_footer.add_child(gap)
	_footer.add_child(KeyCap.new(keys[0]))
	var text := AccusationStyle.make_label(label, AccusationStyle.body_font(), AccusationStyle.HINT_SIZE, AccusationStyle.INK_SOFT)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(text)


# --- Lista ---

func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var current_group := ""
	for option in _options:
		var group: String = option.get("group", "pista")
		if group != current_group:
			current_group = group
			_list.add_child(_make_group_label(group))
		var row := AccusationListRow.new()
		row.setup(option)
		row.set_meta("row_group", group)
		row.chosen = row.item_id == _chosen_id
		row.pressed.connect(_on_row_pressed.bind(row))
		row.highlighted.connect(_show_preview)
		_list.add_child(row)
	_apply_filter()


func _make_group_label(group: String) -> Control:
	var holder := MarginContainer.new()
	holder.name = "Group_%s" % group
	holder.set_meta("group", group)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("margin_top", 8)
	holder.add_theme_constant_override("margin_left", 6)
	holder.add_theme_constant_override("margin_bottom", 2)
	var label := AccusationStyle.make_label("", JournalStyle.banner_font(), AccusationStyle.GROUP_SIZE, AccusationStyle.BURGUNDY_INK)
	label.name = "Label"
	holder.add_child(label)
	holder.draw.connect(func() -> void:
		var y := holder.size.y - 1.0
		holder.draw_line(Vector2(6.0, y), Vector2(holder.size.x - 6.0, y), Color(AccusationStyle.BURGUNDY_INK, 0.35), 1.0, true)
	)
	return holder


## Enseña sólo las filas que encajan con la búsqueda y, si no queda ninguna, el aviso adecuado.
func _apply_filter() -> void:
	var query := _search.text.strip_edges()
	var counts := {}
	for row in get_rows():
		var option := _option(row.item_id)
		row.visible = query.is_empty() or AccusationInfo.matches(option, query)
		if row.visible:
			var group: String = row.get_meta("row_group", "")
			counts[group] = int(counts.get(group, 0)) + 1
	for child in _list.get_children():
		if child.has_meta("group"):
			var group: String = child.get_meta("group")
			var count := int(counts.get(group, 0))
			(child as Control).visible = count > 0
			(child.get_node("Label") as Label).text = "%s (%d)" % [AccusationInfo.GROUP_TITLES.get(group, ""), count]
	var visible_rows := get_visible_rows()
	for index in visible_rows.size():
		visible_rows[index].show_separator = index < visible_rows.size() - 1
	var nothing_found := _options.is_empty()
	_search.visible = not nothing_found
	_scroll.visible = not nothing_found and not visible_rows.is_empty()
	_preview.visible = not visible_rows.is_empty()
	_empty.visible = nothing_found or visible_rows.is_empty()
	if nothing_found:
		_empty_title.text = AccusationInfo.EMPTY_TEXTS.get(field_key, "Todavía no has reunido pruebas para este campo.")
		_empty_hint.visible = true
	elif visible_rows.is_empty():
		_empty_title.text = "Nada de lo que has reunido coincide con «%s»." % query
		_empty_hint.visible = false
	_link_focus(visible_rows)
	if not visible_rows.is_empty() and (_preview_id.is_empty() or get_row(_preview_id) == null or not get_row(_preview_id).visible):
		_show_preview(visible_rows[0].item_id)


## Arriba desde la primera fila lleva al buscador, y abajo desde la última vuelve a él.
func _link_focus(rows: Array[AccusationListRow]) -> void:
	if rows.is_empty():
		_search.focus_neighbor_bottom = NodePath()
		return
	_search.focus_neighbor_bottom = _search.get_path_to(rows[0])
	_search.focus_neighbor_top = _search.get_path_to(rows[-1])
	for index in rows.size():
		var row := rows[index]
		row.focus_neighbor_top = row.get_path_to(rows[index - 1] if index > 0 else _search)
		row.focus_neighbor_bottom = row.get_path_to(rows[index + 1] if index < rows.size() - 1 else _search)
		row.focus_neighbor_left = row.get_path()
		row.focus_neighbor_right = row.get_path()


## Cuando la lista ya está ordenada, desplaza lo justo para ver la fila: arriba del todo si es la
## primera, para que se lea también el rótulo de su grupo.
func _reveal(row: AccusationListRow) -> void:
	await get_tree().process_frame
	if not is_instance_valid(row) or not row.visible:
		return
	var rows := get_visible_rows()
	if not rows.is_empty() and row == rows[0]:
		_scroll.scroll_vertical = 0
	else:
		_scroll.ensure_control_visible(row)


func _option(item_id: String) -> Dictionary:
	for option in _options:
		if option["id"] == item_id:
			return option
	return {}


func _show_preview(item_id: String) -> void:
	var option := _option(item_id)
	_preview_id = item_id if not option.is_empty() else ""
	if option.is_empty():
		_preview_title.text = ""
		_preview_type.text = ""
		_preview_text.text = ""
		return
	_preview_icon.texture = AccusationStyle.icon(option.get("icon", "documento"))
	_preview_title.text = option.get("full_title", option.get("title", ""))
	_preview_type.text = option.get("type_label", "")
	_preview_text.text = option.get("text", "")


func _on_row_pressed(row: AccusationListRow) -> void:
	item_chosen.emit(row.item_id)


# --- Dibujo ---

## Banda burdeos del encabezado con su filete dorado y el medallón del campo.
func _draw_header() -> void:
	var rect := Rect2(Vector2.ZERO, _header.size)
	DialogueOrnaments.draw_gradient_polygon(_header, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), AccusationStyle.BURGUNDY, AccusationStyle.BURGUNDY_DARK)
	_header.draw_line(Vector2(0.0, rect.end.y - 1.0), Vector2(rect.end.x, rect.end.y - 1.0), AccusationStyle.GOLD, 2.0, true)
	_header.draw_line(Vector2(10.0, rect.end.y - 6.0), Vector2(rect.end.x - 10.0, rect.end.y - 6.0), Color(AccusationStyle.GOLD, 0.4), 1.0, true)
	HudOrnaments.draw_diamond(_header, Vector2(rect.size.x * 0.5, rect.end.y - 1.0), 5.0, AccusationStyle.GOLD, AccusationStyle.BURGUNDY_DARK)
	var center := Vector2(50.0, rect.size.y * 0.5 - 3.0)
	var radius := 27.0
	_header.draw_circle(center, radius + 2.0, AccusationStyle.FRAME_DARK, true, -1.0, true)
	_header.draw_circle(center, radius, AccusationStyle.BURGUNDY_DARK, true, -1.0, true)
	_header.draw_arc(center, radius, 0.0, TAU, 48, AccusationStyle.GOLD, 2.0, true)
	_header.draw_arc(center, radius - 4.5, 0.0, TAU, 48, Color(AccusationStyle.GOLD, 0.45), 1.0, true)
	var glyph: String = AccusationInfo.FIELD_GLYPHS.get(field_key, "")
	if not glyph.is_empty():
		var font := AccusationStyle.heading_font()
		var glyph_size := 34
		var width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
		var baseline := center.y - font.get_height(glyph_size) * 0.5 + font.get_ascent(glyph_size)
		_header.draw_string(font, Vector2(center.x - width * 0.5, baseline), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, AccusationStyle.CREAM)
	else:
		var icon_name: String = AccusationInfo.FIELD_ICONS.get(field_key, "documento")
		var icon_size := 32.0
		_header.draw_texture_rect(AccusationStyle.icon(icon_name if not icon_name.is_empty() else "documento"), Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), false, AccusationStyle.CREAM)


func _draw_close_cross() -> void:
	var center := _close.size * 0.5
	var arm := 9.0
	var color := AccusationStyle.GOLD_LIGHT if _close.is_hovered() else AccusationStyle.CREAM
	_close.draw_line(center - Vector2(arm, arm), center + Vector2(arm, arm), color, 2.4, true)
	_close.draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), color, 2.4, true)
