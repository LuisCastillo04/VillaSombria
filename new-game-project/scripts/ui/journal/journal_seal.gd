class_name JournalSeal
extends CaseStamp
## Matasellos de la carpeta: ondas de franqueo y un sello redondo con «VILLA SOMBRÍA» en arco, el año
## en el centro y la silueta del pueblo al pie. Reutiliza el texto en arco del sello de las pantallas
## de guardar (`CaseStamp`); sólo cambia el dibujo del centro.

@export var year := "1948"
## Ancho de las ondas de franqueo a la izquierda del sello.
@export var waves_width := 150.0


func _init() -> void:
	top_text = "VILLA SOMBRÍA"
	bottom_text = ""
	ink = Color(0.27, 0.17, 0.1, 0.82)
	custom_minimum_size = Vector2(300.0, 150.0)


func _ready() -> void:
	super._ready()
	resized.connect(_tilt)
	_tilt()


## El sello se estampa algo torcido: gira el control entero alrededor del centro del sello.
func _tilt() -> void:
	pivot_offset = get_seal_center()
	rotation_degrees = -7.0


func get_seal_center() -> Vector2:
	var radius := _radius()
	return Vector2(size.x - radius - 6.0, size.y * 0.5)


func _radius() -> float:
	return minf(size.y * 0.5 - 4.0, 72.0)


func _draw() -> void:
	var radius := _radius()
	var center := get_seal_center()
	var waves := Rect2(Vector2(maxf(center.x - radius - waves_width + 22.0, 0.0), center.y - 34.0), Vector2(waves_width, 52.0))
	JournalOrnaments.draw_postal_waves(self, waves, 5, Color(ink, 0.55))
	var origin := center
	draw_circle(origin, radius, Color(JournalStyle.PARCHMENT, 0.55))
	draw_arc(origin, radius, 0.0, TAU, 72, ink, 3.0, true)
	draw_arc(origin, radius - 6.0, 0.0, TAU, 72, ink, 1.2, true)
	draw_arc(origin, radius * 0.58, 0.0, TAU, 64, ink, 1.5, true)
	var font := CaseFileStyle.serif_bold()
	var font_size := int(radius * 0.2)
	_arched_text(top_text, origin, radius - 12.0 - font_size * 0.72, font, font_size, true)
	for side: float in [-1.0, 1.0]:
		var star := origin + Vector2(side * (radius - 13.0), font_size * 0.15)
		HudOrnaments.draw_diamond(self, star, 3.4, ink)
	var year_font := JournalStyle.heading_font()
	var year_size := int(radius * 0.36)
	var year_width := year_font.get_string_size(year, HORIZONTAL_ALIGNMENT_LEFT, -1, year_size).x
	draw_string(year_font, origin + Vector2(-year_width * 0.5, radius * 0.06), year, HORIZONTAL_ALIGNMENT_LEFT, -1, year_size, ink)
	_draw_skyline(origin + Vector2(0.0, radius * 0.4), radius * 0.5)


## Tejados, chimeneas y el campanario del pueblo, en tinta, dentro del círculo interior.
func _draw_skyline(base: Vector2, half_width: float) -> void:
	var w := half_width
	var points := PackedVector2Array([
		base + Vector2(-w, 0.0), base + Vector2(-w, -w * 0.18), base + Vector2(-w * 0.78, -w * 0.32),
		base + Vector2(-w * 0.56, -w * 0.18), base + Vector2(-w * 0.56, -w * 0.38), base + Vector2(-w * 0.48, -w * 0.38),
		base + Vector2(-w * 0.48, -w * 0.24), base + Vector2(-w * 0.3, -w * 0.24), base + Vector2(-w * 0.18, -w * 0.4),
		base + Vector2(-w * 0.08, -w * 0.4), base + Vector2(-w * 0.08, -w * 0.72), base + Vector2(0.0, -w * 0.9),
		base + Vector2(w * 0.08, -w * 0.72), base + Vector2(w * 0.08, -w * 0.36), base + Vector2(w * 0.26, -w * 0.36),
		base + Vector2(w * 0.4, -w * 0.5), base + Vector2(w * 0.54, -w * 0.36), base + Vector2(w * 0.54, -w * 0.22),
		base + Vector2(w * 0.72, -w * 0.22), base + Vector2(w * 0.72, -w * 0.34), base + Vector2(w * 0.8, -w * 0.34),
		base + Vector2(w * 0.8, -w * 0.18), base + Vector2(w, -w * 0.12), base + Vector2(w, 0.0),
	])
	draw_colored_polygon(points, ink)
	draw_line(base + Vector2(0.0, -w * 0.9), base + Vector2(0.0, -w * 1.05), ink, 1.4, true)
	draw_line(base + Vector2(-w * 0.06, -w * 0.99), base + Vector2(w * 0.06, -w * 0.99), ink, 1.4, true)
	draw_line(base + Vector2(-w * 1.05, 1.0), base + Vector2(w * 1.05, 1.0), ink, 1.6, true)
