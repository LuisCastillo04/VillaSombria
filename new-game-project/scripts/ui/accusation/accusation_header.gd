class_name AccusationHeader
extends Control
## Encabezado de la hoja de acusación: el rótulo «ACUSACIÓN FORMAL» en versalitas, un filete con un
## rombo debajo, el emblema de la balanza montado sobre el borde superior del marco, la fotografía
## de la mansión prendida con un clip en la esquina y una pluma estilográfica en la otra.
##
## La foto y el emblema sobresalen del encabezado a propósito, sobre el marco, como objetos dejados
## encima de la hoja; el rótulo se reduce si no cabe.

const SCENE_PHOTO := preload("res://assets/ui/mansion_grabado.svg")
## Posición de la foto y su tamaño, relativos al encabezado (sale por la esquina de la hoja).
const PHOTO_POSITION := Vector2(-96.0, -70.0)
const PHOTO_SIZE := Vector2(172.0, 150.0)
const EMBLEM_RADIUS := 40.0
## Las letras que no empiezan palabra van a este tamaño relativo, como unas versalitas.
const SMALL_CAPS := 0.8
const TITLE_TOP := 34.0
const RULE_GAP := 14.0
const RULE_HALF := 190.0

@export var title_text := "ACUSACIÓN FORMAL":
	set(value):
		title_text = value
		queue_redraw()
## Distancia del borde superior del marco al encabezado: el emblema se centra en ese borde.
@export var frame_offset := 42.0
@export var show_photo := true
@export var show_pen := true

var _photo: JournalPhoto
var _title_size := AccusationStyle.TITLE_SIZE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = AccusationStyle.HEADER_HEIGHT


func _ready() -> void:
	if show_photo:
		_photo = JournalPhoto.new()
		_photo.name = "Photo"
		_photo.tilt = -7.0
		_photo.clip_side = -1
		_photo.set_picture(SCENE_PHOTO, JournalPhoto.Mode.PORTRAIT)
		_photo.position = PHOTO_POSITION
		_photo.size = PHOTO_SIZE
		add_child(_photo)
	resized.connect(_on_resized)
	_on_resized()


func get_title() -> String:
	return title_text


func get_title_font_size() -> int:
	return _title_size


func get_photo() -> JournalPhoto:
	return _photo


func _on_resized() -> void:
	_title_size = _fit_title_size(size.x - 40.0)
	queue_redraw()


## Mayor tamaño (hasta `TITLE_MIN_SIZE`) con el que el rótulo cabe en `available` píxeles.
func _fit_title_size(available: float) -> int:
	var font_size := AccusationStyle.TITLE_SIZE
	while font_size > AccusationStyle.TITLE_MIN_SIZE and _title_width(font_size) > available:
		font_size -= 2
	return font_size


func _title_width(font_size: int) -> float:
	var width := 0.0
	for part in _title_parts(font_size):
		width += AccusationStyle.title_font().get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, part[1]).x
	return width


## Trozos del rótulo con su tamaño: la inicial de cada palabra entera y el resto más pequeño.
func _title_parts(font_size: int) -> Array:
	var parts: Array = []
	var small := int(round(font_size * SMALL_CAPS))
	var words := title_text.split(" ")
	for index in words.size():
		var word := words[index]
		if word.is_empty():
			continue
		parts.append([word.left(1), font_size])
		var rest := word.substr(1) + (" " if index < words.size() - 1 else "")
		if not rest.is_empty():
			parts.append([rest, small])
	return parts


func _draw() -> void:
	_draw_emblem(Vector2(size.x * 0.5, -frame_offset + 18.0))
	var font := AccusationStyle.title_font()
	var baseline := TITLE_TOP + font.get_ascent(_title_size)
	var cursor := (size.x - _title_width(_title_size)) * 0.5
	for part: Array in _title_parts(_title_size):
		var text: String = part[0]
		var font_size: int = part[1]
		draw_string(font, Vector2(cursor, baseline + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.96, 0.86, 0.5))
		draw_string(font, Vector2(cursor, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, AccusationStyle.INK)
		cursor += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var rule_y := baseline + font.get_descent(_title_size) + RULE_GAP
	_draw_rule(Vector2(size.x * 0.5, rule_y), minf(RULE_HALF, size.x * 0.4))
	if show_pen:
		_draw_pen(Vector2(size.x + 6.0, 70.0), deg_to_rad(-58.0), 156.0)


## Filete de tinta que se apaga hacia los extremos, con un rombo hueco y dos volutas en el centro.
func _draw_rule(center: Vector2, half: float) -> void:
	var color := Color(AccusationStyle.BURGUNDY_INK, 0.8)
	var faded := Color(color, 0.0)
	var gap := 22.0
	draw_polyline_colors(PackedVector2Array([center - Vector2(half, 0.0), center - Vector2(half * 0.45, 0.0), center - Vector2(gap, 0.0)]), PackedColorArray([faded, color, color]), 1.4, true)
	draw_polyline_colors(PackedVector2Array([center + Vector2(gap, 0.0), center + Vector2(half * 0.45, 0.0), center + Vector2(half, 0.0)]), PackedColorArray([color, color, faded]), 1.4, true)
	draw_polyline(HudOrnaments.closed(HudOrnaments.diamond(center, 6.0)), color, 1.5, true)
	draw_colored_polygon(HudOrnaments.diamond(center, 2.4), color)
	for side: float in [-1.0, 1.0]:
		var curl := center + Vector2(side * 14.0, 0.0)
		draw_polyline(EvidenceOrnaments.spiral(curl + Vector2(0.0, -3.5), 4.0, 1.2, PI * 0.5, 0.9 * side, 18), color, 1.2, true)


## Emblema de la justicia: un medallón burdeos con la balanza, engastado en el borde superior del
## marco y con dos filetes que lo abrazan por los lados.
func _draw_emblem(center: Vector2) -> void:
	var radius := EMBLEM_RADIUS
	var gold := AccusationStyle.GOLD
	for side: float in [-1.0, 1.0]:
		var from := center + Vector2(side * (radius + 6.0), 0.0)
		var to := center + Vector2(side * (radius + 64.0), 0.0)
		EvidenceOrnaments.draw_scroll_line(self, from, to, Color(gold, 0.9), side > 0.0, 1.6)
	draw_circle(center + Vector2(0.0, 5.0), radius + 4.0, Color(0.0, 0.0, 0.0, 0.4), true, -1.0, true)
	draw_circle(center, radius + 3.0, AccusationStyle.FRAME_DARK, true, -1.0, true)
	draw_circle(center, radius, AccusationStyle.BURGUNDY_DARK, true, -1.0, true)
	draw_circle(center + Vector2(0.0, -radius * 0.25), radius * 0.72, Color(AccusationStyle.BURGUNDY_LIGHT, 0.45), true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 64, gold, 2.4, true)
	draw_arc(center, radius - 5.0, 0.0, TAU, 64, Color(gold, 0.5), 1.0, true)
	var icon := AccusationStyle.icon("balanza")
	var icon_size := radius * 1.18
	draw_texture_rect(icon, Rect2(center - Vector2(icon_size, icon_size) * 0.5 + Vector2(0.0, -1.0), Vector2(icon_size, icon_size)), false, AccusationStyle.GOLD_LIGHT)


## Pluma estilográfica apoyada en la hoja: plumín dorado, sección negra, anilla y cuerpo lacado con
## un brillo y su clip. `nib` es la punta y `angle`, la dirección del plumín hacia el capuchón.
func _draw_pen(nib: Vector2, angle: float, length: float) -> void:
	for pass_index in 2:
		var shadow := pass_index == 0
		var origin := nib + (Vector2(5.0, 8.0) if shadow else Vector2.ZERO)
		draw_set_transform(origin, angle, Vector2.ONE)
		var body := Color(0.0, 0.0, 0.0, 0.32) if shadow else Color("15100e")
		var nib_color := Color(0.0, 0.0, 0.0, 0.32) if shadow else AccusationStyle.GOLD
		# Plumín: un triángulo alargado con su raja.
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(26.0, -5.5), Vector2(30.0, 0.0), Vector2(26.0, 5.5)]), nib_color)
		if not shadow:
			draw_line(Vector2(2.0, 0.0), Vector2(20.0, 0.0), AccusationStyle.FRAME_DARK, 1.0, true)
			draw_circle(Vector2(20.0, 0.0), 1.6, AccusationStyle.FRAME_DARK, true, -1.0, true)
		# Sección y cuerpo, algo más ancho hacia el capuchón.
		draw_colored_polygon(PackedVector2Array([Vector2(28.0, -6.0), Vector2(46.0, -7.0), Vector2(46.0, 7.0), Vector2(28.0, 6.0)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(50.0, -8.0), Vector2(length - 6.0, -9.0), Vector2(length - 6.0, 9.0), Vector2(50.0, 8.0)]), body)
		draw_circle(Vector2(length - 6.0, 0.0), 9.0, body, true, -1.0, true)
		if not shadow:
			draw_rect(Rect2(Vector2(45.0, -8.0), Vector2(5.0, 16.0)), AccusationStyle.GOLD)
			draw_rect(Rect2(Vector2(length * 0.6, -9.0), Vector2(3.0, 18.0)), AccusationStyle.GOLD_DARK)
			draw_line(Vector2(54.0, -5.0), Vector2(length - 10.0, -6.0), Color(1.0, 1.0, 1.0, 0.16), 2.0, true)
			# Clip del capuchón.
			draw_line(Vector2(length * 0.64, 10.5), Vector2(length - 8.0, 10.5), AccusationStyle.GOLD_LIGHT, 2.2, true)
			draw_circle(Vector2(length * 0.64, 10.5), 2.0, AccusationStyle.GOLD_LIGHT, true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
