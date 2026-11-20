class_name JournalEmptyState
extends VBoxContainer
## Estado vacío de una página del expediente: un grabado o un emblema, un rótulo, un filete con
## rombo y una línea de ayuda que puede llevar una tecla real del InputMap («en el tablero [B]»).
## Está centrado y compuesto como una página más, no como un hueco sin terminar.

const ART_MAX := Vector2(520.0, 330.0)
const EMBLEM_SIZE := 104.0

var _art: TextureRect
var _emblem: Control
var _emblem_picture: TextureRect
var _title: Label
var _text_row: HBoxContainer
var _text_before: Label
var _key: KeyCap
var _text_after: Label
var _gap_before: Control
var _gap_after: Control
var _note: Label
var _emblem_icon := ""


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.hide()
	add_child(_art)
	_emblem = Control.new()
	_emblem.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
	_emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.draw.connect(_draw_emblem)
	_emblem.hide()
	add_child(_emblem)
	_emblem_picture = TextureRect.new()
	_emblem_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem_picture.modulate = Color(JournalStyle.INK, 0.8)
	_emblem_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := EMBLEM_SIZE * 0.24
	_emblem_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_emblem_picture.offset_left = inset
	_emblem_picture.offset_top = inset
	_emblem_picture.offset_right = -inset
	_emblem_picture.offset_bottom = -inset
	_emblem.add_child(_emblem_picture)
	_title = JournalStyle.make_label("", JournalStyle.heading_font(), JournalStyle.EMPTY_TITLE_SIZE, JournalStyle.BURGUNDY_INK, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	var rule := JournalStyle.make_rule(Color(JournalStyle.INK, 0.6))
	rule.custom_minimum_size = Vector2(380.0, 20.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(rule)
	_text_row = HBoxContainer.new()
	_text_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Sin separación propia: los huecos van aparte para que un punto final quede pegado a la tecla.
	_text_row.add_theme_constant_override("separation", 0)
	_text_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_before = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.EMPTY_TEXT_SIZE, JournalStyle.INK_SOFT, true)
	_text_before.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_row.add_child(_text_before)
	_key = KeyCap.new()
	_key.hide()
	_gap_before = _gap(10.0)
	_text_row.add_child(_gap_before)
	_text_row.add_child(_key)
	_gap_after = _gap(10.0)
	_text_row.add_child(_gap_after)
	_text_after = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.EMPTY_TEXT_SIZE, JournalStyle.INK_SOFT)
	_text_row.add_child(_text_after)
	add_child(_text_row)
	_note = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.NOTE_SIZE, Color(JournalStyle.INK_SOFT, 0.85), true)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.hide()
	add_child(_note)
	resized.connect(_fit_text)


## Rellena el estado vacío. `key` es una tecla real; si no hay, la frase va sola.
func setup(title: String, text: String, key: String = "", text_after: String = "", note: String = "") -> void:
	_title.text = title
	_text_before.text = text
	_key.text = key
	_key.visible = not key.is_empty()
	_text_after.text = text_after
	_text_after.visible = not text_after.is_empty()
	_gap_after.custom_minimum_size.x = 3.0 if text_after.left(1) in [".", ",", ";", ":"] else 10.0
	_gap_before.visible = _key.visible
	_gap_after.visible = _key.visible and _text_after.visible
	_note.text = note
	_note.visible = not note.is_empty()
	_fit_text()


static func _gap(width: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.x = width
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## Grabado sobre el rótulo (el tablero de las deducciones).
func set_art(texture: Texture2D, max_size: Vector2 = ART_MAX) -> void:
	_art.texture = texture
	_art.custom_minimum_size = max_size
	_art.visible = texture != null
	_emblem.visible = false


## Emblema circular con un icono, cuando no hay grabado.
func set_emblem(icon_name: String) -> void:
	_emblem_icon = icon_name
	_emblem_picture.texture = JournalStyle.icon(icon_name) if not icon_name.is_empty() else null
	_emblem.visible = not icon_name.is_empty()
	_art.visible = false
	_emblem.queue_redraw()


func get_title() -> String:
	return _title.text


## Frase de ayuda completa, con la tecla entre corchetes.
func get_text() -> String:
	var text := _text_before.text
	if _key.visible:
		text += " [%s]" % _key.text
	if _text_after.visible:
		text += ("" if _gap_after.custom_minimum_size.x < 5.0 else " ") + _text_after.text
	return text


func get_emblem_icon() -> String:
	return _emblem_icon if _emblem.visible else ""


func get_key() -> String:
	return _key.text if _key.visible else ""


func get_note() -> String:
	return _note.text if _note.visible else ""


func is_art_shown() -> bool:
	return _art.visible


## Con tecla, la frase no se parte para que la tecla quede a su lado; sin tecla, se ajusta al ancho.
func _fit_text() -> void:
	var available := maxf(size.x - 40.0, 200.0)
	if _key.visible:
		_text_before.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text_before.custom_minimum_size.x = 0.0
	else:
		_text_before.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text_before.custom_minimum_size.x = minf(available, 760.0)
	_title.custom_minimum_size.x = minf(available, 760.0)
	_note.custom_minimum_size.x = minf(available, 700.0)
	_art.custom_minimum_size.x = minf(_art.custom_minimum_size.x, available)


func _draw_emblem() -> void:
	var center := _emblem.size * 0.5
	var radius := minf(center.x, center.y) - 3.0
	_emblem.draw_circle(center, radius, Color(JournalStyle.INK, 0.06))
	_emblem.draw_arc(center, radius, 0.0, TAU, 64, Color(JournalStyle.BURGUNDY_INK, 0.75), 2.0, true)
	_emblem.draw_arc(center, radius - 6.0, 0.0, TAU, 64, Color(JournalStyle.GOLD_DARK, 0.7), 1.0, true)
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		HudOrnaments.draw_diamond(_emblem, center + Vector2(cos(angle), sin(angle)) * radius, 4.0, JournalStyle.BURGUNDY, JournalStyle.PARCHMENT)
