class_name EvidenceLetter
extends EvidenceDocument
## Carta personal: un pliego desplegado con pliegues en cruz, escrito a pluma. Arriba a la derecha,
## el lugar donde se halló; el encabezado («Lucía:») con un trazo rojo debajo, el cuerpo en letra
## manuscrita con sangría, la firma subrayada y, si la carta lo trae, un adorno prensado en la
## esquina (las violetas de Marcos). Una tira escrita a máquina recoge la nota del investigador
## (dónde estaba doblada), separada del mensaje para no confundirla con lo que dice la carta.
##
## Campos de `presentation` en `clues.json`: `salutation`, `body`, `signature`, `note` y
## `ornament` (ruta de un SVG); todos opcionales salvo `body`. No hay fecha: la carta del juego no
## la tiene y no se inventa.

const DESIGN_SIZE := Vector2(1420.0, 900.0)
const PLACE_RECT := Rect2(880.0, 46.0, 430.0, 60.0)
const SALUTATION_POSITION := Vector2(178.0, 128.0)
const SALUTATION_SIZE := 118
const BODY_RECT := Rect2(190.0, 280.0, 1130.0, 340.0)
const BODY_SIZE := 66
const BODY_MIN_SIZE := 36
const BODY_LINE_SPACING := 10.0
## Sangría de la primera línea, como en una carta escrita a mano.
const INDENT := "  "
const SIGNATURE_RECT := Rect2(930.0, 600.0, 300.0, 140.0)
const SIGNATURE_SIZE := 128
const ORNAMENT_RECT := Rect2(30.0, 560.0, 270.0, 320.0)
const NOTE_POSITION := Vector2(745.0, 806.0)
const NOTE_MAX_WIDTH := 520.0

var _salutation_width := 0.0
var _signature_label: Label
var _place_label: Label


func get_design_size() -> Vector2:
	return DESIGN_SIZE


func get_template_id() -> String:
	return "carta"


func _build() -> void:
	paper.configure({
		"seed": 3.1, "tear": 9.0, "chunks": 0.7, "folds_x": [0.5], "folds_y": [0.47],
		"blot": Vector4(0.035, 0.06, 165.0, 0.85), "ring": Vector4(0.905, 0.88, 112.0, 0.9),
	})
	var ornament := EvidenceDocument.load_texture(field("ornament"))
	if ornament != null:
		add_texture(ornament, ORNAMENT_RECT, Color(1.0, 1.0, 1.0, 0.94)).name = "Ornament"

	var place := str(entry.get("where", ""))
	if not place.is_empty():
		_place_label = add_label(place, EvidenceStyle.handwriting(), 40, EvidenceStyle.PEN_SOFT, PLACE_RECT, HORIZONTAL_ALIGNMENT_RIGHT, false)
		_place_label.name = "Place"

	var salutation := field("salutation")
	if not salutation.is_empty():
		var font := EvidenceStyle.flourish()
		_salutation_width = font.get_string_size(salutation, HORIZONTAL_ALIGNMENT_LEFT, -1, SALUTATION_SIZE).x
		var label := add_label(salutation, font, SALUTATION_SIZE, EvidenceStyle.PEN_INK, Rect2(SALUTATION_POSITION, Vector2(_salutation_width + 40.0, 170.0)), HORIZONTAL_ALIGNMENT_LEFT, false)
		label.name = "Salutation"

	var body := INDENT + field("body")
	var body_font := EvidenceStyle.handwriting()
	var body_size := EvidenceStyle.fit_font_size(body, body_font, BODY_SIZE, BODY_MIN_SIZE, BODY_RECT.size, BODY_LINE_SPACING)
	var body_label := add_label(body, body_font, body_size, EvidenceStyle.PEN_INK, BODY_RECT, HORIZONTAL_ALIGNMENT_LEFT, true, BODY_LINE_SPACING)
	body_label.name = "Body"

	var signature := field("signature")
	if not signature.is_empty():
		_signature_label = add_label(signature, EvidenceStyle.flourish(), SIGNATURE_SIZE, EvidenceStyle.PEN_INK, SIGNATURE_RECT, HORIZONTAL_ALIGNMENT_CENTER, false)
		_signature_label.name = "Signature"

	var note := field("note")
	if not note.is_empty():
		var tag := EvidenceTag.new(note, "etiqueta", 23)
		tag.name = "Note"
		add_child(tag)
		tag.position = NOTE_POSITION
		tag.fit(NOTE_MAX_WIDTH)


## Texto de la carta tal como se lee, sin la sangría.
func get_body_text() -> String:
	var body := get_node_or_null("Body") as Label
	return body.text.trim_prefix(INDENT) if body != null else ""


func _draw_ink(canvas: Control) -> void:
	var pen := Color(EvidenceStyle.PEN_INK, 0.9)
	# Filete con un rombo bajo el lugar, como el remate de un membrete escrito a mano.
	if _place_label != null:
		var y := PLACE_RECT.end.y + 16.0
		var right := PLACE_RECT.end.x - 10.0
		var left := right - 250.0
		var middle := (left + right) * 0.5
		canvas.draw_line(Vector2(left, y), Vector2(middle - 10.0, y), Color(pen, 0.7), 1.4, true)
		canvas.draw_line(Vector2(middle + 10.0, y), Vector2(right, y), Color(pen, 0.7), 1.4, true)
		HudOrnaments.draw_diamond(canvas, Vector2(middle, y), 4.0, Color(pen, 0.8))
	# Trazo rojo bajo el encabezado, de izquierda a derecha y algo ascendente, más grueso al centro.
	if _salutation_width > 0.0:
		var start := SALUTATION_POSITION + Vector2(-14.0, 150.0)
		var finish := SALUTATION_POSITION + Vector2(_salutation_width + 30.0, 118.0)
		_draw_pen_stroke(canvas, start, finish, -16.0, 4.2, Color(EvidenceStyle.PEN_RED, 0.92))
	# Rúbrica bajo la firma.
	if _signature_label != null:
		var base := SIGNATURE_RECT.position + Vector2(-34.0, SIGNATURE_RECT.size.y + 34.0)
		_draw_pen_stroke(canvas, base, base + Vector2(330.0, -62.0), 6.0, 4.6, pen)


## Trazo de pluma entre dos puntos, curvado `bend` píxeles, que engorda en el centro y afina en
## los extremos, como la tinta de un plumín.
static func _draw_pen_stroke(canvas: Control, start: Vector2, finish: Vector2, bend: float, thickness: float, color: Color) -> void:
	var normal := (finish - start).orthogonal().normalized()
	var steps := 24
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for step in steps + 1:
		var t := float(step) / steps
		var point := start.lerp(finish, t) + normal * bend * sin(t * PI)
		var half := thickness * 0.5 * pow(sin(t * PI), 0.6) + 0.3
		upper.append(point + normal * half)
		lower.append(point - normal * half)
	lower.reverse()
	upper.append_array(lower)
	canvas.draw_colored_polygon(upper, color)
