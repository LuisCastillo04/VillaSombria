class_name BoardComparisonPanel
extends JournalPage
## Columna derecha del tablero, en el pergamino de las páginas del expediente: «Comparar elementos»
## con su lupa, los dos huecos de la comparación, el botón «Relacionar» y la respuesta.
##
## «Relacionar» sólo se activa con dos elementos válidos elegidos; al pulsarlo, quien usa el panel
## pide la relación a `Investigation.try_link` y le pasa el resultado con `show_outcome()`. El panel
## no decide nada: sólo cuenta lo que dice la investigación, con un aspecto distinto según sea una
## deducción nueva, una ya conocida, ninguna relación o un elemento que falta, y nunca adelanta qué
## combinación es la buena.

signal link_pressed
## El jugador quita de la comparación el elemento 1 o el 2 con su cruz.
signal remove_requested(index: int)

enum Feedback { HINT, NEED_SECOND, NEW, KNOWN, NONE, MISSING }

const HINT := "Selecciona dos elementos y comprueba si guardan relación."
const NEED_SECOND := "Elige un segundo elemento para compararlo con «%s»."
const READY := "Pulsa «Relacionar» para comprobar si guardan relación."
const NONE_TEXT := "No encuentro ninguna relación concluyente entre estos dos elementos."
const KNOWN_TEXT := "Ya estableciste esta relación: %s."
const MISSING_TEXT := "Uno de los elementos ya no está en el expediente. Elige otro."
const RESULT_HEIGHT := 128.0
## Una deducción nueva trae su conclusión entera: la respuesta gana sitio mientras se lee.
const RESULT_HEIGHT_NEW := 230.0

var _slots: Array[BoardComparisonSlot] = []
var _link: Button
var _result: HBoxContainer
var _result_icon: TextureRect
var _result_scroll: ScrollContainer
var _result_title: Label
var _result_text: Label
var _feedback := Feedback.HINT
var _feedback_tween: Tween


func _init() -> void:
	super._init()
	name = "Comparison"
	padding = Vector4(26.0, 22.0, 26.0, 22.0)
	paper_seed = 9.1
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := HBoxContainer.new()
	heading.name = "Heading"
	heading.add_theme_constant_override("separation", 14)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(BoardStyle.make_icon("lupa", 38.0, BoardStyle.INK))
	var title := BoardStyle.make_label("Comparar elementos", BoardStyle.heading_font(), BoardStyle.PANEL_TITLE_SIZE, BoardStyle.BURGUNDY_INK)
	title.name = "Title"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	box.add_child(heading)
	box.add_child(BoardStyle.make_rule())
	for index in 2:
		var slot := BoardComparisonSlot.new(index + 1)
		slot.remove_requested.connect(func() -> void: remove_requested.emit(slot.index))
		_slots.append(slot)
		box.add_child(slot)
		box.add_child(BoardStyle.make_rule())
	_link = Button.new()
	_link.name = "Link"
	_link.text = "Relacionar"
	_link.custom_minimum_size.y = 58.0
	_link.icon = BoardStyle.icon("conexion")
	_link.expand_icon = false
	_link.add_theme_constant_override("icon_max_width", 30)
	_link.add_theme_constant_override("h_separation", 12)
	BoardStyle.apply_primary_button(_link)
	_link.add_theme_color_override("icon_normal_color", BoardStyle.CREAM)
	_link.add_theme_color_override("icon_hover_color", BoardStyle.CREAM)
	_link.add_theme_color_override("icon_pressed_color", BoardStyle.CREAM)
	_link.add_theme_color_override("icon_focus_color", BoardStyle.CREAM)
	_link.add_theme_color_override("icon_disabled_color", Color("6d604d"))
	_link.pressed.connect(func() -> void: link_pressed.emit())
	box.add_child(_link)
	_result = HBoxContainer.new()
	_result.name = "Result"
	_result.custom_minimum_size.y = RESULT_HEIGHT
	_result.add_theme_constant_override("separation", 12)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_icon = BoardStyle.make_icon("lupa", 30.0, BoardStyle.BURGUNDY_INK)
	_result_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_result.add_child(_result_icon)
	_result_scroll = ScrollContainer.new()
	_result_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BoardStyle.style_scroll(_result_scroll)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_title = BoardStyle.make_label("", BoardStyle.heading_font(), BoardStyle.RESULT_TITLE_SIZE, BoardStyle.BURGUNDY_INK, true)
	_result_title.name = "ResultTitle"
	texts.add_child(_result_title)
	_result_text = BoardStyle.make_label("", BoardStyle.italic_font(), BoardStyle.RESULT_SIZE, BoardStyle.INK, true)
	_result_text.name = "ResultText"
	texts.add_child(_result_text)
	_result_scroll.add_child(texts)
	_result.add_child(_result_scroll)
	box.add_child(_result)
	add_child(box)
	show_selection([], false)


## Pinta los elementos elegidos (descritos por `BoardInfo.describe()`) y activa «Relacionar» si se
## puede intentar. La línea de ayuda dice qué falta; el resultado de una relación se muestra después
## con `show_outcome()`.
func show_selection(entries: Array[Dictionary], can_link: bool) -> void:
	for index in _slots.size():
		_slots[index].show_item(entries[index] if index < entries.size() else {})
	_link.disabled = not can_link
	_link.mouse_default_cursor_shape = Control.CURSOR_ARROW if _link.disabled else Control.CURSOR_POINTING_HAND
	_link.focus_mode = Control.FOCUS_NONE if _link.disabled else Control.FOCUS_ALL
	if entries.size() == 1:
		show_feedback(Feedback.NEED_SECOND, "", NEED_SECOND % entries[0].get("title", ""))
	elif entries.size() >= 2 and can_link:
		show_feedback(Feedback.HINT, "", READY)
	else:
		show_feedback(Feedback.HINT, "", HINT)


## Cuenta el resultado de `Investigation.try_link`.
func show_outcome(outcome: Dictionary) -> void:
	var deduction: Dictionary = GameData.deductions.get(outcome.get("deduction", ""), {})
	match outcome.get("result", Investigation.LinkResult.NONE):
		Investigation.LinkResult.NEW:
			show_feedback(Feedback.NEW, "Deducción registrada: %s" % deduction.get("title", ""), deduction.get("text", ""))
		Investigation.LinkResult.ALREADY_KNOWN:
			show_feedback(Feedback.KNOWN, "", KNOWN_TEXT % deduction.get("title", ""))
		Investigation.LinkResult.MISSING_ITEM:
			show_feedback(Feedback.MISSING, "", MISSING_TEXT)
		_:
			show_feedback(Feedback.NONE, "", NONE_TEXT)


func show_feedback(kind: Feedback, title: String, text: String) -> void:
	_feedback = kind
	_result.custom_minimum_size.y = RESULT_HEIGHT_NEW if kind == Feedback.NEW else RESULT_HEIGHT
	_result_title.text = title
	_result_title.visible = not title.is_empty()
	_result_text.text = text
	_result_scroll.scroll_vertical = 0
	var icon_name := "lupa"
	var color := BoardStyle.INK_SOFT
	match kind:
		Feedback.NEW:
			icon_name = "conexion"
			color = BoardStyle.BURGUNDY
		Feedback.KNOWN:
			icon_name = "archivo"
			color = BoardStyle.INK
		Feedback.NONE:
			icon_name = "lupa"
			color = BoardStyle.INK
		Feedback.MISSING:
			icon_name = "salir"
			color = BoardStyle.BURGUNDY
		Feedback.NEED_SECOND:
			icon_name = "mano"
	_result_icon.texture = BoardStyle.icon(icon_name)
	_result_icon.modulate = color
	_result_text.add_theme_font_override("font", BoardStyle.body_font() if kind == Feedback.NEW else BoardStyle.italic_font())
	_animate_feedback(kind)


func get_feedback() -> Feedback:
	return _feedback


## Texto de la respuesta, con su título si lo tiene.
func get_result_text() -> String:
	if _result_title.visible:
		return "%s\n%s" % [_result_title.text, _result_text.text]
	return _result_text.text


func get_link_button() -> Button:
	return _link


func get_slot(index: int) -> BoardComparisonSlot:
	return _slots[index - 1]


func get_result() -> Control:
	return _result


## La respuesta aparece con un gesto según lo que dice: una deducción nueva se estampa, una
## combinación sin relación tiembla un instante y lo demás simplemente aparece.
func _animate_feedback(kind: Feedback) -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
	_result.modulate.a = 1.0
	_result.scale = Vector2.ONE
	_result.position.x = 0.0
	if not is_inside_tree():
		return
	_result.pivot_offset = Vector2(24.0, 20.0)
	_feedback_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	match kind:
		Feedback.NEW:
			_result.modulate.a = 0.0
			_result.scale = Vector2.ONE * 1.08
			_feedback_tween.set_parallel()
			_feedback_tween.tween_property(_result, "modulate:a", 1.0, BoardStyle.FEEDBACK_SECONDS)
			_feedback_tween.tween_property(_result, "scale", Vector2.ONE, BoardStyle.FEEDBACK_SECONDS).set_trans(Tween.TRANS_BACK)
		Feedback.NONE, Feedback.MISSING:
			_result.modulate.a = 0.4
			_feedback_tween.tween_property(_result, "modulate:a", 1.0, BoardStyle.FEEDBACK_SECONDS * 0.5)
			var origin := _result.position
			for offset: float in [7.0, -6.0, 4.0, -2.0, 0.0]:
				_feedback_tween.tween_property(_result, "position:x", origin.x + offset, 0.045)
		_:
			_result.modulate.a = 0.35
			_feedback_tween.tween_property(_result, "modulate:a", 1.0, BoardStyle.FEEDBACK_SECONDS)
