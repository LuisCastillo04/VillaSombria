class_name BoardSuspectCard
extends Button
## Ficha de un sospechoso en la fila superior del tablero: pergamino con marco oscuro y filete dorado,
## su silueta, el nombre corto y la valoración que le dio el jugador.
##
## Dos estados independientes:
## - la valoración (`status`), que es de la partida: «Principal sospechoso» va en burdeos con una
##   chincheta roja, «Sospechoso» lleva una de latón y «Descartado» apaga el papel y cruza la silueta
##   sin tocar el texto, que se sigue leyendo;
## - la selección (`selected`), que es sólo de la interfaz: la ficha cuya hipótesis se está anotando
##   se ilumina en dorado. Elegir una ficha nunca cambia su valoración.
##
## Si el jugador dejó una hipótesis a medias, un lápiz en la esquina lo recuerda.

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const GLOW_SIZE := 7.0
const RADIUS := 4.0

var suspect_id := ""
var status := ""
var selected := false
var has_draft := false

## Brillo dorado de la selección y destello al guardar, de 0 a 1. Los animan las transiciones.
var glow := 0.0:
	set(value):
		glow = value
		_back.queue_redraw()
		queue_redraw()
var flash := 0.0:
	set(value):
		flash = value
		_back.queue_redraw()
		queue_redraw()

var _back: Control
var _paper: ColorRect
var _paper_material: ShaderMaterial
var _content: HBoxContainer
var _portrait: TextureRect
var _name: Label
var _status: Label
var _tween: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(BoardStyle.SUSPECT_CARD_MIN_WIDTH, BoardStyle.SUSPECT_CARD_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_stylebox_override("focus", BoardStyle.focus_ring(int(RADIUS)))
	# Por detrás, primero el brillo y la sombra y después el papel; el marco lo pinta la ficha.
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
	_paper_material.set_shader_parameter("corner_radius", RADIUS)
	_paper_material.set_shader_parameter("edge_width", 26.0)
	_paper = ColorRect.new()
	_paper.name = "Paper"
	_paper.material = _paper_material
	_paper.show_behind_parent = true
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper, false, Node.INTERNAL_MODE_FRONT)
	_content = HBoxContainer.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 14)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = BoardStyle.SUSPECT_PORTRAIT
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_END
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_portrait)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = BoardStyle.make_label("", BoardStyle.heading_font(), BoardStyle.SUSPECT_NAME_SIZE, BoardStyle.INK)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	texts.add_child(_name)
	_status = BoardStyle.make_label("", BoardStyle.body_font(), BoardStyle.SUSPECT_STATUS_SIZE, BoardStyle.INK)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	texts.add_child(_status)
	_content.add_child(texts)
	add_child(_content)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Rellena la ficha con una entrada de `BoardInfo.suspects()`.
func setup(entry: Dictionary) -> void:
	suspect_id = entry.get("id", "")
	name = "Suspect_%s" % suspect_id
	_name.text = entry.get("short", entry.get("name", ""))
	tooltip_text = ""
	_portrait.texture = JournalInfo.portrait(entry.get("portrait", ""), JournalInfo.PORTRAIT_BUST)
	_paper_material.set_shader_parameter("seed", float(hash(suspect_id) % 89) * 0.41)
	set_status(entry.get("status", ""))


## Pinta la valoración. Sólo cambia el aspecto: la valoración la guarda la partida.
func set_status(new_status: String) -> void:
	status = new_status
	_status.text = BoardInfo.status_label(status)
	var discarded := status == "descartado"
	var principal := status == "principal"
	var ink := BoardStyle.DISCARDED_INK if discarded else BoardStyle.INK
	_name.add_theme_color_override("font_color", ink)
	_status.add_theme_color_override("font_color", BoardStyle.BURGUNDY if principal else ink)
	_status.add_theme_font_override("font", BoardStyle.italic_font() if principal or discarded else BoardStyle.body_font())
	_portrait.modulate = Color(0.32, 0.27, 0.23, 0.75) if discarded else Color(0.09, 0.06, 0.05)
	_paper_material.set_shader_parameter("base_color", BoardStyle.DISCARDED_PAPER if discarded else BoardStyle.PARCHMENT)
	queue_redraw()


func set_selected(value: bool, animate: bool = true) -> void:
	selected = value
	if _tween != null:
		_tween.kill()
	var target := 1.0 if value else 0.0
	if animate and is_inside_tree():
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "glow", target, BoardStyle.SELECT_SECONDS)
	else:
		glow = target


func set_draft(value: bool) -> void:
	has_draft = value
	queue_redraw()


## Destello dorado breve: la valoración o la hipótesis se acaban de guardar.
func pulse() -> void:
	if not is_inside_tree():
		return
	flash = 1.0
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(self, "flash", 0.0, BoardStyle.PULSE_SECONDS)


func get_name_text() -> String:
	return _name.text


func get_status_text() -> String:
	return _status.text


func get_status_color() -> Color:
	return _status.get_theme_color("font_color")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_back.position = Vector2.ZERO
	_back.size = size
	_paper.position = Vector2.ZERO
	_paper.size = size
	_paper_material.set_shader_parameter("rect_size", size)
	_content.position = Vector2(16.0, 6.0)
	_content.size = rect.size - Vector2(16.0 + 26.0, 6.0)


func _draw_back() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var light := maxf(glow, flash)
	if light > 0.0:
		for ring in 4:
			var spread := 1.5 + ring * (GLOW_SIZE / 4.0)
			_back.draw_rect(rect.grow(spread), Color(BoardStyle.GOLD_LIGHT, 0.3 * light * (1.0 - ring / 4.0)))
	_back.draw_rect(Rect2(rect.position + Vector2(0.0, 4.0), rect.size), Color(0.0, 0.0, 0.0, 0.4))
	_back.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size), Color(0.0, 0.0, 0.0, 0.25))


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var light := maxf(glow, flash)
	if light > 0.0:
		draw_rect(rect, Color(1.0, 0.96, 0.82, 0.12 * light))
	var hovered := is_hovered() and not selected
	draw_rect(rect.grow(-1.0), BoardStyle.FRAME, false, 2.0, true)
	if light > 0.0:
		draw_rect(rect.grow(0.5), Color(BoardStyle.GOLD_LIGHT, light), false, 3.0, true)
		draw_rect(rect.grow(-2.5), Color(BoardStyle.GOLD, light * 0.8), false, 1.4, true)
	var filet := BoardStyle.GOLD_LIGHT if light > 0.5 else (BoardStyle.GOLD if hovered else Color(BoardStyle.GOLD_DARK, 0.8))
	draw_rect(rect.grow(-5.0), filet, false, 1.2, true)
	HudOrnaments.draw_corner_brackets(self, rect.grow(-8.5), 10.0, Color(BoardStyle.GOLD_DARK, 0.85), 1.2)
	var corner := Vector2(size.x - 18.0, 16.0)
	match status:
		"principal":
			BoardOrnaments.draw_pin(self, corner, BoardStyle.PINS["pista"], 7.0)
		"sospechoso":
			BoardOrnaments.draw_pin(self, corner, BoardStyle.BRASS, 6.0)
		"descartado":
			_draw_cross(Rect2(_content.position + _portrait.position, _portrait.size).grow(-10.0))
	if has_draft:
		var pencil := BoardStyle.icon("nota")
		draw_texture_rect(pencil, Rect2(Vector2(size.x - 34.0, size.y - 32.0), Vector2(22.0, 22.0)), false, Color(BoardStyle.BURGUNDY_INK, 0.85))


## Aspa de tinta sobre la silueta de un descartado, sin tocar el nombre ni la valoración.
func _draw_cross(area: Rect2) -> void:
	var ink := Color(BoardStyle.BURGUNDY, 0.55)
	draw_line(area.position, area.end, ink, 3.0, true)
	draw_line(Vector2(area.end.x, area.position.y), Vector2(area.position.x, area.end.y), ink, 3.0, true)
