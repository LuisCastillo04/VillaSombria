class_name JournalObjectiveCard
extends PanelContainer
## Tarjeta de un objetivo: una casilla con su estado, el texto y una etiqueta en cursiva. Activo (el
## que se persigue ahora, el mismo del HUD), pendiente o cumplido; el estado sale de `StoryDirector`
## a través de `JournalInfo`, nunca de la tarjeta.

const STATE_LABELS := {
	JournalInfo.ObjectiveState.ACTIVE: "En curso",
	JournalInfo.ObjectiveState.PENDING: "Pendiente",
	JournalInfo.ObjectiveState.DONE: "Cumplido",
}
const MARK_SIZE := 30.0

var objective_id := ""
var state := JournalInfo.ObjectiveState.PENDING

var _mark: Control
var _text: Label
var _state_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark = Control.new()
	_mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
	_mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.draw.connect(_draw_mark)
	row.add_child(_mark)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = JournalStyle.make_label("", JournalStyle.body_font(), JournalStyle.ROW_SIZE - 2, JournalStyle.INK, true)
	texts.add_child(_text)
	_state_label = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.ROW_SUBTITLE_SIZE - 1, JournalStyle.INK_SOFT)
	texts.add_child(_state_label)
	row.add_child(texts)
	add_child(row)


func setup(objective: Dictionary) -> void:
	objective_id = objective.get("id", "")
	state = objective.get("state", JournalInfo.ObjectiveState.PENDING)
	_text.text = objective.get("text", "")
	_state_label.text = STATE_LABELS[state]
	var box := JournalStyle.card_box()
	match state:
		JournalInfo.ObjectiveState.ACTIVE:
			box = JournalStyle.row_box("selected")
			box.content_margin_top = 10.0
			box.content_margin_bottom = 10.0
			_text.add_theme_color_override("font_color", JournalStyle.INK)
			_state_label.add_theme_color_override("font_color", JournalStyle.BURGUNDY_INK)
		JournalInfo.ObjectiveState.DONE:
			box.bg_color = Color(JournalStyle.PARCHMENT_LIGHT, 0.25)
			_text.add_theme_color_override("font_color", Color(JournalStyle.INK_SOFT, 0.8))
			_state_label.add_theme_color_override("font_color", Color(JournalStyle.INK_SOFT, 0.8))
		_:
			_text.add_theme_color_override("font_color", JournalStyle.INK)
			_state_label.add_theme_color_override("font_color", JournalStyle.INK_SOFT)
	add_theme_stylebox_override("panel", box)
	_mark.queue_redraw()


func get_text() -> String:
	return _text.text


func get_state_label() -> String:
	return _state_label.text


## Casilla de tinta: vacía si está pendiente, con un rombo burdeos si está en curso y con una marca
## si se ha cumplido.
func _draw_mark() -> void:
	var rect := Rect2(Vector2(3.0, 3.0), _mark.size - Vector2(6.0, 6.0))
	_mark.draw_rect(rect, Color(JournalStyle.PARCHMENT_LIGHT, 0.7))
	_mark.draw_rect(rect, Color(JournalStyle.INK, 0.75), false, 1.6, true)
	var center := rect.get_center()
	match state:
		JournalInfo.ObjectiveState.ACTIVE:
			HudOrnaments.draw_diamond(_mark, center, rect.size.x * 0.3, JournalStyle.BURGUNDY)
		JournalInfo.ObjectiveState.DONE:
			var check := PackedVector2Array([
				center + Vector2(-rect.size.x * 0.32, 0.0),
				center + Vector2(-rect.size.x * 0.08, rect.size.y * 0.26),
				center + Vector2(rect.size.x * 0.42, -rect.size.y * 0.42),
			])
			_mark.draw_polyline(check, JournalStyle.BURGUNDY_INK, 3.4, true)
