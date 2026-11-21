class_name BoardHypothesisEditor
extends Control
## Panel de hipótesis sobre un sospechoso, que aparece encima del corcho al pulsar su ficha: marco de
## cuero, pergamino, el título en burdeos con el icono de persona, el selector de valoración, el
## cuaderno donde se escribe y «Guardar hipótesis». Una cruz (o Esc) lo cierra sin cerrar el tablero.
##
## No guarda nada por sí mismo: avisa con `save_requested` y quien lo usa anota la hipótesis con
## `Investigation.set_hypothesis`. Si el jugador lo cierra con cambios sin guardar, quien lo usa
## conserva el borrador y se lo devuelve al reabrirlo; entonces el panel lo dice y ofrece
## «Descartar cambios» para volver a lo guardado.

signal save_requested(status: String, note: String)
signal close_requested
signal discard_requested

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const LEATHER_SHADER := preload("res://assets/shaders/leather.gdshader")
const BORDER := 12.0
const PLACEHOLDER := "Escribe aquí tu hipótesis..."
const DRAFT_TEXT := "Borrador sin guardar."
## Avisa del largo cuando la nota se acerca al máximo que admiten las partidas.
const COUNTER_WARNING := 0.9

var suspect_id := ""
var is_open := false

var _saved := {"status": "", "note": ""}
var _leather: ColorRect
var _paper: ColorRect
var _box: VBoxContainer
var _title: Label
var _close: Button
var _status: OptionButton
var _draft_row: HBoxContainer
var _discard: Button
var _text: TextEdit
var _counter: Label
var _save: Button
var _tween: Tween


func _init() -> void:
	name = "Editor"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_leather = _shader_rect("Leather", LEATHER_SHADER)
	var leather_material := _leather.material as ShaderMaterial
	leather_material.set_shader_parameter("base_color", BoardStyle.LEATHER)
	leather_material.set_shader_parameter("dark_color", BoardStyle.LEATHER_DARK)
	leather_material.set_shader_parameter("sheen_color", BoardStyle.LEATHER_SHEEN)
	leather_material.set_shader_parameter("corner_radius", 8.0)
	leather_material.set_shader_parameter("edge_width", 16.0)
	_paper = _shader_rect("Paper", PARCHMENT_SHADER)
	var paper_material := _paper.material as ShaderMaterial
	paper_material.set_shader_parameter("base_color", BoardStyle.PARCHMENT)
	paper_material.set_shader_parameter("stain_color", BoardStyle.PARCHMENT_STAIN)
	paper_material.set_shader_parameter("edge_color", BoardStyle.PARCHMENT_EDGE)
	paper_material.set_shader_parameter("corner_radius", 3.0)
	paper_material.set_shader_parameter("edge_width", 40.0)
	paper_material.set_shader_parameter("seed", 12.4)
	_box = VBoxContainer.new()
	_box.name = "Box"
	_box.add_theme_constant_override("separation", 12)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_heading()
	_box.add_child(BoardStyle.make_rule())
	_status = OptionButton.new()
	_status.name = "Status"
	_status.custom_minimum_size.y = 54.0
	for label in BoardInfo.status_labels():
		_status.add_item(label)
	BoardStyle.apply_option_button(_status)
	_box.add_child(_status)
	_build_draft_row()
	_text = TextEdit.new()
	_text.name = "Text"
	_text.placeholder_text = PLACEHOLDER
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size.y = 120.0
	# Tab pasa al siguiente control en lugar de escribir un tabulador.
	_text.tab_input_mode = false
	BoardStyle.apply_text_edit(_text)
	_text.text_changed.connect(_on_text_changed)
	_box.add_child(_text)
	_counter = BoardStyle.make_label("", BoardStyle.italic_font(), BoardStyle.SMALL_SIZE, BoardStyle.INK_SOFT)
	_counter.name = "Counter"
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box.add_child(_counter)
	_save = Button.new()
	_save.name = "Save"
	_save.text = "Guardar hipótesis"
	_save.custom_minimum_size.y = 58.0
	BoardStyle.apply_primary_button(_save)
	_save.pressed.connect(func() -> void: save_requested.emit(get_values()["status"], get_values()["note"]))
	_box.add_child(_save)
	add_child(_box)
	resized.connect(_layout)


## Muestra la hipótesis de un sospechoso (una entrada de `BoardInfo.suspects()`). `saved` es lo que
## dice la partida; `draft`, un borrador que el jugador dejó sin guardar (vacío si no hay).
func open_for(entry: Dictionary, saved: Dictionary, draft: Dictionary = {}, animate: bool = true) -> void:
	suspect_id = entry.get("id", "")
	_saved = {"status": str(saved.get("status", "")), "note": str(saved.get("note", ""))}
	_title.text = "Hipótesis sobre %s" % entry.get("name", "")
	var values := draft if not draft.is_empty() else _saved
	_select_status(values.get("status", ""))
	_text.text = values.get("note", "")
	_text.set_caret_line(_text.get_line_count() - 1)
	_text.set_caret_column(_text.get_line(_text.get_line_count() - 1).length())
	_text.scroll_vertical = 0
	_draft_row.visible = not draft.is_empty()
	_update_counter()
	is_open = true
	show()
	_status.grab_focus()
	if _tween != null:
		_tween.kill()
	if animate and is_inside_tree():
		modulate.a = 0.0
		_box.position.y = _content_rect().position.y + 12.0
		_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, BoardStyle.EDITOR_SECONDS)
		_tween.tween_property(_box, "position:y", _content_rect().position.y, BoardStyle.EDITOR_SECONDS)
	else:
		modulate.a = 1.0
		_layout()


## Lo cierra. Lo que hubiera escrito sigue en `get_values()` hasta el siguiente `open_for()`.
func close(animate: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if _status.get_popup().visible:
		_status.get_popup().hide()
	if _tween != null:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "modulate:a", 0.0, BoardStyle.CLOSE_SECONDS)
		_tween.tween_callback(_finish_close)
	else:
		_finish_close()


## Valoración y nota que hay ahora en el panel.
func get_values() -> Dictionary:
	var index := maxi(_status.selected, 0)
	return {"status": Investigation.HYPOTHESIS_STATUSES[index], "note": _text.text}


## Si lo escrito difiere de lo guardado en la partida.
func is_dirty() -> bool:
	var values := get_values()
	return values["status"] != _saved["status"] or str(values["note"]).strip_edges() != _saved["note"]


## Vuelve a lo guardado en la partida y olvida el borrador.
func discard() -> void:
	_select_status(_saved["status"])
	_text.text = _saved["note"]
	_draft_row.hide()
	_update_counter()


func is_draft_shown() -> bool:
	return _draft_row.visible


func get_title() -> String:
	return _title.text


func get_status_option() -> OptionButton:
	return _status


func get_text_edit() -> TextEdit:
	return _text


func get_save_button() -> Button:
	return _save


func get_close_button() -> Button:
	return _close


func get_discard_button() -> Button:
	return _discard


func get_counter_text() -> String:
	return _counter.text


func _finish_close() -> void:
	if is_open:
		return
	hide()
	modulate.a = 1.0


func _select_status(status: String) -> void:
	_status.select(maxi(Investigation.HYPOTHESIS_STATUSES.find(status), 0))


func _build_heading() -> void:
	var heading := HBoxContainer.new()
	heading.name = "Heading"
	heading.add_theme_constant_override("separation", 16)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.custom_minimum_size = Vector2(54.0, 54.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", JournalStyle.badge_box())
	var icon := BoardStyle.make_icon("persona", 30.0, BoardStyle.CREAM)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_child(icon)
	heading.add_child(badge)
	_title = BoardStyle.make_label("", BoardStyle.heading_font(), BoardStyle.EDITOR_TITLE_SIZE, BoardStyle.BURGUNDY_INK)
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	heading.add_child(_title)
	_close = Button.new()
	_close.name = "Close"
	_close.text = "×"
	_close.tooltip_text = "Cerrar sin cerrar el tablero"
	_close.focus_mode = Control.FOCUS_NONE
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	BoardStyle.apply_text_button(_close, BoardStyle.heading_font(), 40, BoardStyle.INK_SOFT)
	_close.pressed.connect(func() -> void: close_requested.emit())
	heading.add_child(_close)
	_box.add_child(heading)


func _build_draft_row() -> void:
	_draft_row = HBoxContainer.new()
	_draft_row.name = "Draft"
	_draft_row.add_theme_constant_override("separation", 10)
	_draft_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draft_row.add_child(BoardStyle.make_icon("nota", 22.0, BoardStyle.BURGUNDY_INK))
	var text := BoardStyle.make_label(DRAFT_TEXT, BoardStyle.italic_font(), BoardStyle.SMALL_SIZE + 1, BoardStyle.BURGUNDY_INK)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draft_row.add_child(text)
	_discard = Button.new()
	_discard.name = "Discard"
	_discard.text = "Descartar cambios"
	BoardStyle.apply_text_button(_discard, BoardStyle.body_font(), BoardStyle.SMALL_SIZE + 1, BoardStyle.INK)
	_discard.pressed.connect(func() -> void:
		discard()
		discard_requested.emit())
	_draft_row.add_child(_discard)
	_draft_row.hide()
	_box.add_child(_draft_row)


## La nota no pasa del largo que admiten las partidas guardadas.
func _on_text_changed() -> void:
	var limit := SaveFormat.MAX_NOTE_LENGTH
	if _text.text.length() > limit:
		var line := _text.get_caret_line()
		var column := _text.get_caret_column()
		_text.text = _text.text.left(limit)
		_text.set_caret_line(mini(line, _text.get_line_count() - 1))
		_text.set_caret_column(mini(column, _text.get_line(_text.get_caret_line()).length()))
	_update_counter()


func _update_counter() -> void:
	var length := _text.text.length()
	var limit := SaveFormat.MAX_NOTE_LENGTH
	_counter.text = "%d / %d caracteres" % [length, limit]
	_counter.add_theme_color_override("font_color", BoardStyle.BURGUNDY if length >= limit * COUNTER_WARNING else Color(BoardStyle.INK_SOFT, 0.8))


func _content_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-(BORDER + 22.0))


func _layout() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_fit(_leather, rect)
	_fit(_paper, rect.grow(-BORDER))
	var content := _content_rect()
	_box.position = content.position
	_box.size = content.size
	queue_redraw()


func _shader_rect(node_name: String, shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	rect.show_behind_parent = true
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect, false, Node.INTERNAL_MODE_FRONT)
	return rect


static func _fit(rect: ColorRect, area: Rect2) -> void:
	rect.position = area.position
	rect.size = area.size
	(rect.material as ShaderMaterial).set_shader_parameter("rect_size", area.size)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Sombra sobre el corcho, por detrás del cuero.
	var shadow := StyleBoxFlat.new()
	shadow.draw_center = false
	shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	shadow.shadow_size = 22
	shadow.shadow_offset = Vector2(0.0, 8.0)
	draw_style_box(shadow, rect)
	draw_rect(rect.grow(-1.0), Color(BoardStyle.GOLD_DARK, 0.9), false, 2.0, true)
	draw_rect(rect.grow(-4.5), Color(BoardStyle.GOLD, 0.7), false, 1.2, true)
	var paper := rect.grow(-BORDER)
	draw_rect(paper.grow(1.0), BoardStyle.FRAME, false, 2.0, true)
	draw_rect(paper.grow(-6.0), Color(BoardStyle.GOLD_DARK, 0.75), false, 1.2, true)
	HudOrnaments.draw_corner_brackets(self, paper.grow(-10.0), 18.0, Color(BoardStyle.GOLD_DARK, 0.9))
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var inward := Vector2(signf(rect.get_center().x - corner.x), signf(rect.get_center().y - corner.y))
		HudOrnaments.draw_diamond(self, corner + inward * 6.0, 4.0, BoardStyle.GOLD, BoardStyle.LEATHER_DARK)
