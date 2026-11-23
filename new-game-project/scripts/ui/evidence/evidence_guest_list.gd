class_name EvidenceGuestList
extends Control
## Lista de invitados de la cena, a la derecha de la ficha: el papel con el escudo, el encabezado y
## la fecha es una imagen (`lista_invitados.png`), y los invitados se escriben encima con los datos
## de `presentation.guest_list` en `clues.json`. Así los nombres siempre casan con la historia.
##
## Cada invitado lleva su casilla marcada, su nombre a pluma y, si la tiene, su función entre
## paréntesis. El último, `added`, es el que Julián añadió a mano: otra tinta, otra letra y un
## subrayado rojo, porque esa anotación es la pista.
##
## Todo se coloca en píxeles del papel y la pieza entera se escala al tamaño que le da la ficha.
## La hoja de la imagen está algo girada; las filas siguen ese giro.

## Dónde empieza la primera fila en el papel, el giro de los renglones y su separación.
const ROWS_ORIGIN := Vector2(116.0, 262.0)
const ROWS_DEGREES := 3.8
const ROW_HEIGHT := 41.0
## Ancho útil de cada renglón, desde la casilla hasta el margen derecho del papel.
const ROW_WIDTH := 418.0
const BOX_SIZE := 26.0
const NAME_LEFT := 50.0
const NAME_SIZE := 34
const NAME_MIN := 24
const NOTE_SIZE := 25
const ADDED_SIZE := 33
## Más filas que estas no caben entre la fecha y los adornos del pie del papel.
const MAX_ROWS := 8
## Pinza de latón: dónde va en el papel, para tapar la pinza recortada de la referencia.
const CLIP_POSITION := Vector2(299.0, -22.0)
const CLIP_SIZE := Vector2(176.0, 108.0)
## Tinta azul negra de la pluma de Julián, distinta de la del resto de la lista.
const ADDED_INK := Color("1d2638")

var _paper_size := Vector2.ONE
var _content: Control
var _rows: Control
var _rules: Array[Vector2] = []
var _checks: Array[Vector2] = []
var _underline := PackedVector2Array()


func _init(paper: Texture2D, data: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper_size = paper.get_size()
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = _paper_size
	add_child(_content)
	var sheet := TextureRect.new()
	sheet.name = "Paper"
	sheet.texture = paper
	sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.size = _paper_size
	_content.add_child(sheet)
	_rows = Control.new()
	_rows.name = "Rows"
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.position = ROWS_ORIGIN
	_rows.rotation_degrees = ROWS_DEGREES
	_rows.size = Vector2(ROW_WIDTH, ROW_HEIGHT * MAX_ROWS)
	_content.add_child(_rows)
	_rows.draw.connect(_draw_rows)
	_write(data)
	var clip := EvidenceDocument.load_texture(str(data.get("clip", "")))
	if clip != null:
		var pin := TextureRect.new()
		pin.name = "Clip"
		pin.texture = clip
		pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pin.position = CLIP_POSITION
		pin.size = CLIP_SIZE
		_content.add_child(pin)
	resized.connect(_fit_content)


## Nombres escritos en la lista, en orden; el añadido a mano es el último.
func get_guest_names() -> PackedStringArray:
	var names := PackedStringArray()
	for child in _rows.get_children():
		if child is Label and String(child.name).begins_with("Guest"):
			names.append((child as Label).text)
	return names


## Nombre añadido a mano, o vacío si la lista no lo trae.
func get_added_name() -> String:
	var label := _rows.get_node_or_null("AddedGuest") as Label
	return label.text if label != null else ""


## Casillas marcadas; todas lo están.
func get_checked_count() -> int:
	return _checks.size()


func _fit_content() -> void:
	_content.scale = size / _paper_size


func _write(data: Dictionary) -> void:
	var guests: Array = data.get("guests", [])
	var added: Dictionary = data.get("added", {})
	var count := mini(guests.size(), MAX_ROWS - (0 if added.is_empty() else 1))
	if count < guests.size():
		push_warning("La lista de invitados tiene más filas de las que caben en el papel: %d." % guests.size())
	for index in count:
		var guest: Dictionary = guests[index]
		_write_row(index, str(guest.get("name", "")), str(guest.get("note", "")), false)
	if not added.is_empty():
		_write_row(count, str(added.get("name", "")), str(added.get("note", "")), true)


func _write_row(index: int, guest_name: String, note: String, is_added: bool) -> void:
	var top := index * ROW_HEIGHT
	var font := EvidenceStyle.handwriting() if is_added else EvidenceStyle.flourish()
	var ink := ADDED_INK if is_added else EvidenceStyle.PEN_INK
	var room := ROW_WIDTH - NAME_LEFT
	var note_text := "(%s)" % note if not note.is_empty() else ""
	var note_font := EvidenceStyle.handwriting() if is_added else EvidenceStyle.flourish()
	var note_width := note_font.get_string_size(note_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE_SIZE).x + 10.0 if not note_text.is_empty() else 0.0
	var font_size := ADDED_SIZE if is_added else NAME_SIZE
	while font_size > NAME_MIN and font.get_string_size(guest_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room - note_width:
		font_size -= 1
	var name_width := font.get_string_size(guest_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var line_height := font.get_height(font_size)
	var name_label := _label(guest_name, font, font_size, ink, Vector2(NAME_LEFT, top + ROW_HEIGHT - line_height - 2.0))
	name_label.name = "AddedGuest" if is_added else "Guest%d" % index
	var baseline := name_label.position.y + font.get_ascent(font_size)
	if not note_text.is_empty():
		var note_label := _label(note_text, note_font, NOTE_SIZE, Color(ink, 0.85), Vector2(NAME_LEFT + name_width + 10.0, baseline - note_font.get_ascent(NOTE_SIZE)))
		note_label.name = "AddedNote" if is_added else "Note%d" % index
	_checks.append(Vector2(0.0, top + ROW_HEIGHT - BOX_SIZE - 6.0))
	if is_added:
		# Subrayado rojo a pulso, un poco más largo que el nombre.
		var y := baseline + 9.0
		var finish := NAME_LEFT + name_width + 14.0
		_underline = PackedVector2Array([
			Vector2(NAME_LEFT - 8.0, y + 3.0), Vector2(NAME_LEFT + name_width * 0.3, y),
			Vector2(NAME_LEFT + name_width * 0.7, y - 1.0), Vector2(finish, y - 4.0),
		])
	else:
		_rules.append(Vector2(top + ROW_HEIGHT - 1.0, NAME_LEFT - 6.0))


func _label(text: String, font: Font, font_size: int, color: Color, at: Vector2) -> Label:
	var label := EvidenceStyle.make_label(text, font, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.position = at
	label.size = Vector2(ROW_WIDTH - at.x, font.get_height(font_size))
	_rows.add_child(label)
	return label


func _draw_rows() -> void:
	var rule := Color(EvidenceStyle.PAPER_EDGE, 0.2)
	for line in _rules:
		_rows.draw_line(Vector2(line.y, line.x), Vector2(ROW_WIDTH - 20.0, line.x), rule, 1.0, true)
	var box_ink := Color(EvidenceStyle.PEN_INK, 0.85)
	var red := EvidenceStyle.PEN_RED
	for corner in _checks:
		var box := Rect2(corner, Vector2(BOX_SIZE, BOX_SIZE))
		_rows.draw_rect(box, box_ink, false, 2.2, true)
		# La marca roja sale de la casilla por arriba, como un trazo rápido de pluma.
		var tick := PackedVector2Array([
			corner + Vector2(5.0, BOX_SIZE * 0.52), corner + Vector2(11.0, BOX_SIZE * 0.82),
			corner + Vector2(BOX_SIZE + 3.0, -2.0), corner + Vector2(BOX_SIZE + 10.0, -9.0),
		])
		_rows.draw_polyline(tick, red, 4.0, true)
	if not _underline.is_empty():
		_rows.draw_polyline(_underline, Color(red, 0.9), 3.0, true)
