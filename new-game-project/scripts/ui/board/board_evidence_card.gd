class_name BoardEvidenceCard
extends Button
## Ficha de un elemento del expediente prendida en el corcho: papel envejecido del color de su tipo
## (pruebas, declaraciones y deducciones), una cinta con el tipo («PRUEBA»), el título y una línea
## breve, y una chincheta en el borde superior de la que salen los hilos.
##
## Pulsarla la elige para compararla: se levanta un poco, se ilumina en dorado y muestra si es el
## elemento 1 o el 2. Cada ficha se inclina siempre igual, según su identificador, como papeles
## prendidos a mano, sin dejar de leerse.

## Se mueve su chincheta (al levantarse o al cambiar de sitio): los hilos deben seguirla.
signal moved

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
## La chincheta sujeta el borde superior: el hilo sale de ella por encima del papel, sin cruzar textos.
const PIN_OFFSET := Vector2(0.0, 1.0)
const MAX_TILT := 1.4
const TITLE_LINES := 2

var item_id := ""
var kind := ""
## Orden en la comparación: 0 si no está elegida, 1 o 2 si lo está.
var slot := 0
## Si comparte una relación ya registrada con una ficha elegida.
var related := false:
	set(value):
		related = value
		queue_redraw()
## Cuánto se ha levantado del corcho, de 0 a 1. Lo anima la selección.
var lift := 0.0:
	set(value):
		lift = value
		scale = Vector2.ONE * (1.0 + 0.035 * lift)
		_back.queue_redraw()
		queue_redraw()
		moved.emit()
## Destello dorado al aparecer una deducción nueva, de 0 a 1.
var flash := 0.0:
	set(value):
		flash = value
		_back.queue_redraw()
		queue_redraw()

var _back: Control
var _paper: ColorRect
var _paper_material: ShaderMaterial
var _content: VBoxContainer
var _tag: Label
var _title: Label
var _subtitle: Label
var _tween: Tween


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = BoardStyle.CARD_SIZE
	size = BoardStyle.CARD_SIZE
	pivot_offset = BoardStyle.CARD_SIZE * 0.5
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_stylebox_override("focus", BoardStyle.focus_ring(3))
	_back = Control.new()
	_back.name = "Back"
	_back.show_behind_parent = true
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_draw_back)
	add_child(_back, false, Node.INTERNAL_MODE_FRONT)
	_paper_material = ShaderMaterial.new()
	_paper_material.shader = PARCHMENT_SHADER
	_paper_material.set_shader_parameter("stain_color", BoardStyle.PARCHMENT_STAIN)
	_paper_material.set_shader_parameter("edge_color", BoardStyle.PARCHMENT_EDGE)
	_paper_material.set_shader_parameter("corner_radius", 2.0)
	_paper_material.set_shader_parameter("edge_width", 22.0)
	_paper = ColorRect.new()
	_paper.name = "Paper"
	_paper.material = _paper_material
	_paper.show_behind_parent = true
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper, false, Node.INTERNAL_MODE_FRONT)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 3)
	_tag = BoardStyle.make_label("", BoardStyle.banner_font(), BoardStyle.CARD_TAG_SIZE, BoardStyle.CREAM)
	_tag.name = "Tag"
	_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(_tag)
	_title = BoardStyle.make_label("", BoardStyle.heading_font(), BoardStyle.CARD_TITLE_SIZE, BoardStyle.INK, true)
	_title.name = "Title"
	_title.max_lines_visible = TITLE_LINES
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title.add_theme_constant_override("line_spacing", -2)
	_content.add_child(_title)
	_subtitle = BoardStyle.make_label("", BoardStyle.italic_font(), BoardStyle.CARD_SUBTITLE_SIZE, BoardStyle.INK_SOFT)
	_subtitle.name = "Subtitle"
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.clip_text = true
	_content.add_child(_subtitle)
	add_child(_content)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	_layout()


## Rellena la ficha con una entrada de `BoardInfo.items()`.
func setup(entry: Dictionary) -> void:
	item_id = entry.get("id", "")
	kind = entry.get("kind", "")
	name = "Card_%s" % item_id
	_tag.text = entry.get("kind_label", "")
	_tag.add_theme_stylebox_override("normal", BoardStyle.tag_box(kind))
	_title.text = entry.get("card_title", entry.get("title", ""))
	_subtitle.text = entry.get("subtitle", "")
	_subtitle.visible = not _subtitle.text.is_empty()
	# El título completo, por si la ficha lo recorta.
	tooltip_text = entry.get("title", "")
	var seed_value := absi(hash(item_id))
	_paper_material.set_shader_parameter("base_color", BoardStyle.paper_color(kind))
	_paper_material.set_shader_parameter("seed", float(seed_value % 97) * 0.37)
	rotation_degrees = (float(seed_value % 29) / 14.0 - 1.0) * MAX_TILT


## Elige la ficha como elemento 1 o 2 de la comparación, o la suelta con 0.
func set_slot(value: int, animate: bool = true) -> void:
	if value == slot and button_pressed == (value > 0):
		return
	slot = value
	set_pressed_no_signal(value > 0)
	if _tween != null:
		_tween.kill()
	var target := 1.0 if value > 0 else 0.0
	if animate and is_inside_tree():
		_tween = create_tween().set_trans(Tween.TRANS_BACK if value > 0 else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "lift", target, BoardStyle.SELECT_SECONDS)
	else:
		lift = target
	queue_redraw()


## Destello dorado breve: la ficha acaba de llegar al tablero.
func pulse() -> void:
	if not is_inside_tree():
		return
	flash = 1.0
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).tween_property(self, "flash", 0.0, BoardStyle.PULSE_SECONDS * 1.6)


## Chincheta de la ficha en las coordenadas de su padre, con la inclinación y el levantamiento.
func get_pin_position() -> Vector2:
	return get_transform() * (Vector2(size.x * 0.5, 0.0) + PIN_OFFSET)


func get_title() -> String:
	return _title.text


func get_tag() -> String:
	return _tag.text


func get_subtitle() -> String:
	return _subtitle.text if _subtitle.visible else ""


## Si el título se ve entero, sin puntos suspensivos.
func is_title_complete() -> bool:
	return _title.get_line_count() <= TITLE_LINES


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	pivot_offset = size * 0.5
	_back.position = Vector2.ZERO
	_back.size = size
	_paper.position = Vector2.ZERO
	_paper.size = size
	_paper_material.set_shader_parameter("rect_size", size)
	_content.position = Vector2(14.0, 24.0)
	_content.size = size - Vector2(28.0, 32.0)


func _draw_back() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var depth := 1.0 + lift * 1.6
	_back.draw_rect(Rect2(rect.position + Vector2(3.0, 5.0) * depth, rect.size), Color(0.0, 0.0, 0.0, 0.28 + lift * 0.08))
	_back.draw_rect(Rect2(rect.position + Vector2(1.0, 2.0) * depth, rect.size), Color(0.0, 0.0, 0.0, 0.22))
	var light := maxf(lift, flash)
	if light > 0.0:
		for ring in 3:
			_back.draw_rect(rect.grow(2.0 + ring * 2.5), Color(BoardStyle.GOLD_LIGHT, 0.26 * light * (1.0 - ring / 3.0)))


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var hovered := is_hovered()
	var border := Color(BoardStyle.INK, 0.45)
	if hovered:
		border = BoardStyle.GOLD_DARK
	draw_rect(rect.grow(-0.5), border, false, 1.2, true)
	draw_rect(rect.grow(-4.0), Color(BoardStyle.PARCHMENT_EDGE, 0.35), false, 1.0, true)
	if maxf(lift, flash) > 0.0:
		draw_rect(rect.grow(0.5), Color(BoardStyle.GOLD_LIGHT, maxf(lift, flash)), false, 3.0, true)
	# Esquina doblada, abajo a la derecha.
	var fold := 14.0
	var corner := rect.end
	draw_colored_polygon(PackedVector2Array([corner - Vector2(fold, 0.0), corner - Vector2(0.0, fold), corner]), Color(BoardStyle.CORK_DARK, 0.9))
	draw_colored_polygon(PackedVector2Array([corner - Vector2(fold, 0.0), corner - Vector2(0.0, fold), corner - Vector2(fold, fold)]), Color(BoardStyle.paper_color(kind).darkened(0.12)))
	if slot > 0:
		_draw_slot_badge(Vector2(size.x - 20.0, 20.0))
	var pin_color := BoardStyle.pin_color(kind)
	if related and slot == 0:
		draw_circle(Vector2(size.x * 0.5, 0.0) + PIN_OFFSET, BoardStyle.PIN_RADIUS + 5.0, Color(BoardStyle.THREAD, 0.25), true, -1.0, true)
	BoardOrnaments.draw_pin(self, Vector2(size.x * 0.5, 0.0) + PIN_OFFSET, pin_color, BoardStyle.PIN_RADIUS, lift)


## Número del elemento en la comparación, en un sello burdeos.
func _draw_slot_badge(center: Vector2) -> void:
	draw_circle(center + Vector2(1.0, 2.0), 12.0, Color(0.0, 0.0, 0.0, 0.3), true, -1.0, true)
	draw_circle(center, 12.0, BoardStyle.BURGUNDY, true, -1.0, true)
	draw_arc(center, 12.0, 0.0, TAU, 32, BoardStyle.GOLD_LIGHT, 1.6, true)
	var font := BoardStyle.heading_font()
	var text := str(slot)
	var font_size := 17
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BoardStyle.CREAM)
