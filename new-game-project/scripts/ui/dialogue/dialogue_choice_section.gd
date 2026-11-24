class_name DialogueChoiceSection
extends Button
## Cabecera plegable de «Preguntas realizadas»: una línea discreta entre dos filetes, con un cheurón
## que gira al desplegarla y el número de preguntas que guarda. Plegada por defecto, para que las
## preguntas nuevas sean lo primero que se ve y lo primero que se recorre.
##
## Se maneja como una respuesta más: recibe el foco con las flechas o el ratón, y la tecla de
## confirmar o un clic la despliegan o la pliegan (también → y ←, desde `DialogueChoices`). No lleva
## número: las teclas numéricas sólo eligen preguntas. Señalada, toma el burdeos y el dorado de las
## tarjetas, como cualquier otra opción.

const HEIGHT := 46.0
const HEIGHT_COMPACT := 40.0
const NOTCH := 6.0
const CHEVRON := 7.0
## Hueco a cada lado del rótulo antes de que empiecen los filetes.
const RULE_GAP := 22.0
const LABEL := "Preguntas realizadas"

var expanded := false

var _count := 0
var _compact := false
var _highlight := 0.0
var _turn := 0.0
var _tween: Tween
var _turn_tween: Tween
var _card: Control


func _init() -> void:
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	toggle_mode = false
	_card = Control.new()
	_card.name = "Card"
	_card.show_behind_parent = true
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card, false, Node.INTERNAL_MODE_FRONT)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.draw.connect(_draw_card)
	add_theme_font_override("font", DialogueStyle.section_font())
	add_theme_font_size_override("font_size", DialogueStyle.SECTION_SIZE)
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 40.0
	box.content_margin_right = 20.0
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, box)
	_apply_highlight(0.0)
	_refresh_text()


func _ready() -> void:
	focus_entered.connect(_refresh_highlight)
	focus_exited.connect(_refresh_highlight)
	mouse_entered.connect(_card.queue_redraw)
	mouse_exited.connect(_card.queue_redraw)


## Al mover el ratón por encima toma el foco, como las tarjetas.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not has_focus():
		grab_focus()


## Cuántas preguntas guarda la sección.
func setup(count: int) -> void:
	_count = count
	_refresh_text()


func get_count() -> int:
	return _count


func set_compact(compact: bool) -> void:
	_compact = compact
	custom_minimum_size.y = HEIGHT_COMPACT if compact else HEIGHT


func get_height() -> float:
	return HEIGHT_COMPACT if _compact else HEIGHT


## Despliega o pliega la sección. El cheurón gira con una transición corta.
func set_expanded(value: bool, animate: bool = true) -> void:
	expanded = value
	_refresh_text()
	var target := 1.0 if value else 0.0
	if _turn_tween != null:
		_turn_tween.kill()
		_turn_tween = null
	if not animate or not is_inside_tree():
		_set_turn(target)
		return
	_turn_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_method(_set_turn, _turn, target, DialogueStyle.SECTION_SECONDS * UiAccessibility.motion() + 0.001)


func is_highlighted() -> bool:
	return _highlight > 0.5


func _refresh_text() -> void:
	text = "%s · %d" % [LABEL.to_upper(), _count]
	tooltip_text = "Ocultar las preguntas ya hechas" if expanded else "Mostrar las preguntas ya hechas"


func _set_turn(value: float) -> void:
	_turn = value
	_card.queue_redraw()


func _refresh_highlight() -> void:
	var target := 1.0 if has_focus() else 0.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if not is_visible_in_tree():
		_apply_highlight(target)
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply_highlight, _highlight, target, DialogueStyle.SELECT_SECONDS)


func _apply_highlight(value: float) -> void:
	_highlight = value
	var ink := DialogueStyle.INK_MUTED.lerp(DialogueStyle.CREAM, value)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, ink)
	_card.queue_redraw()


## Ancho que ocupa el rótulo con su cheurón, centrado en la fila.
func _label_rect() -> Rect2:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 60.0
	width = minf(width, size.x)
	return Rect2(Vector2((size.x - width) * 0.5, 3.0), Vector2(width, size.y - 6.0))


func _draw_card() -> void:
	if size.x < 80.0:
		return
	var middle := size.y * 0.5
	var label := _label_rect()
	var hovered := is_hovered() and _highlight < 0.5
	var rule := Color(DialogueStyle.RULE, 0.55 + (0.25 if hovered else 0.0))
	# Filetes a los lados, con un rombo hueco en su extremo exterior.
	if label.position.x - RULE_GAP > 40.0:
		_card.draw_line(Vector2(24.0, middle), Vector2(label.position.x - RULE_GAP * 0.4, middle), rule, 1.2, true)
		_card.draw_line(Vector2(label.end.x + RULE_GAP * 0.4, middle), Vector2(size.x - 24.0, middle), rule, 1.2, true)
		HudOrnaments.draw_diamond(_card, Vector2(18.0, middle), 4.0, rule)
		HudOrnaments.draw_diamond(_card, Vector2(size.x - 18.0, middle), 4.0, rule)
	if _highlight > 0.0:
		var shape := DialogueOrnaments.notched_rect(label, NOTCH)
		DialogueOrnaments.draw_gradient_polygon(_card, shape, Color(DialogueStyle.BURGUNDY_LIGHT, _highlight), Color(DialogueStyle.BURGUNDY_DARK, _highlight))
		_card.draw_polyline(HudOrnaments.closed(shape), Color(DialogueStyle.GOLD_LIGHT, _highlight), 1.8, true)
	elif hovered:
		_card.draw_colored_polygon(DialogueOrnaments.notched_rect(label, NOTCH), Color(DialogueChoiceItem.PAPER_HOVER, 0.5))
	var color := DialogueStyle.INK_MUTED.lerp(DialogueStyle.GOLD_LIGHT, _highlight)
	DialogueOrnaments.draw_chevron(_card, Vector2(label.position.x + 24.0, middle), CHEVRON, _turn, color)
