class_name EvidenceRecordCard
extends EvidenceDocument
## Ficha de investigación («Evidencia / Objeto»): una cartulina antigua doblada por la mitad con el
## tipo de prueba en rojo, el título, la etiqueta de dónde se halló y la descripción a máquina a la
## izquierda, y la ilustración de la prueba a la derecha.
##
## Sirve para cualquier prueba: sólo usa los campos de siempre de `clues.json`. La ilustración sale
## del bloque `presentation.art` (imagen propia de la ficha, con su centro, ancho y giro) o, si no lo
## trae, del campo `image` (la misma que enseña el expediente); sin ninguna de las dos, la derecha
## muestra el emblema de la categoría estampado en tinta tenue. Los textos largos reducen la letra
## para caber, y la ilustración se encoge si sus partes opacas fueran a tapar algún texto.
##
## Con `presentation.guest_list`, la ilustración es una lista escrita con esos datos
## (`EvidenceGuestList`) sobre el papel de `art.image`.

const DESIGN_SIZE := Vector2(1500.0, 900.0)
const LEFT := 86.0
const TOP := 70.0
## Ancho de la columna de texto y del título, que pueden invadir un poco el pliegue.
const TEXT_WIDTH := 745.0
const TITLE_WIDTH := 900.0
## El título prefiere una sola línea: sólo si a este tamaño no cabe, se parte en dos.
const TITLE_SIZE := 62
const TITLE_MIN_SINGLE := 46
const TITLE_MIN := 38
## Límite inferior de la descripción.
const BOTTOM := 812.0
const ART_RECT := Rect2(845.0, 120.0, 600.0, 660.0)
## Hasta dónde puede llegar una ilustración colocada con `presentation.art`: dentro de los filetes.
const ART_BOUNDS := Rect2(RULE_INSET + 8.0, RULE_INSET + 8.0, DESIGN_SIZE.x - (RULE_INSET + 8.0) * 2.0, DESIGN_SIZE.y - (RULE_INSET + 8.0) * 2.0)
## Aire mínimo entre lo opaco de la ilustración y cualquier texto.
const ART_TEXT_GAP := 12.0
## Lo más que se encoge una ilustración para no tapar textos o salirse de la cartulina.
const ART_MIN_SCALE := 0.55
## Opacidad a partir de la cual un píxel de la ilustración cuenta como «tapa el texto».
const ART_SOLID_ALPHA := 0.15
## Entrada de la ilustración al abrir la ficha: aparece y se asienta sobre el papel.
const ART_DELAY := 0.08
const ART_IN := 0.42
const ART_SETTLE_SCALE := 0.95
const ART_SETTLE_DEGREES := -1.5
const EMBLEM_SIZE := 280.0
## Filetes interiores de la cartulina.
const RULE_INSET := 30.0
const LINE_SPACING := 12.0

var _tag_rule := Rect2()
var _title_rule := Rect2()
## La ilustración de la prueba (imagen o lista), si la tiene; el emblema de categoría no cuenta.
var illustration: Control
## Lo que ocupan los textos, para que la ilustración no los tape.
var _text_rects: Array[Rect2] = []


func get_design_size() -> Vector2:
	return DESIGN_SIZE


func get_template_id() -> String:
	return "ficha"


func _build() -> void:
	paper.configure({
		"seed": 4.3, "tear": 8.0, "chunks": 0.5, "folds_x": [0.508],
		"ring": Vector4(0.045, 0.93, 100.0, 1.0),
	})
	var y := TOP
	var tag := str(entry.get("tag", ""))
	var tag_font := EvidenceStyle.typewriter_spaced()
	add_label(tag, tag_font, 32, EvidenceStyle.TYPE_RED, Rect2(LEFT, y, TITLE_WIDTH, 44.0), HORIZONTAL_ALIGNMENT_LEFT, false)
	var tag_width := tag_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	_text_rects.append(Rect2(LEFT, y, tag_width, 52.0))
	_tag_rule = Rect2(LEFT, y + 48.0, tag_width, 0.0)
	y += 78.0

	var title := str(entry.get("title", ""))
	var title_font := EvidenceStyle.record_title()
	var title_size := TITLE_SIZE
	while title_size > TITLE_MIN_SINGLE and title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > TITLE_WIDTH:
		title_size -= 1
	if title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > TITLE_WIDTH:
		title_size = EvidenceStyle.fit_font_size(title, title_font, TITLE_SIZE, TITLE_MIN, Vector2(TITLE_WIDTH, 160.0))
	var title_height := EvidenceStyle.text_height(title, title_font, title_size, TITLE_WIDTH)
	add_label(title, title_font, title_size, EvidenceStyle.TYPE_INK, Rect2(LEFT, y, TITLE_WIDTH, title_height + 8.0))
	var title_width := minf(title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x, TITLE_WIDTH)
	_text_rects.append(Rect2(LEFT, y, title_width, title_height + 8.0))
	y += title_height + 18.0
	_title_rule = Rect2(LEFT, y, TITLE_WIDTH - 20.0, 0.0)
	y += 30.0

	var where := str(entry.get("where", ""))
	if not where.is_empty():
		var chip := EvidenceTag.new("Hallada en: %s" % where, "ubicacion", 25)
		chip.name = "Where"
		add_child(chip)
		chip.position = Vector2(LEFT, y)
		var chip_size := chip.fit(TEXT_WIDTH + 40.0)
		_text_rects.append(Rect2(chip.position, chip_size))
		y += chip_size.y + 36.0

	var description := str(entry.get("description", ""))
	var font := EvidenceStyle.typewriter()
	var box := Vector2(TEXT_WIDTH, BOTTOM - y)
	var font_size := EvidenceStyle.fit_font_size(description, font, 30, 20, box, LINE_SPACING)
	var body := add_label(description, font, font_size, EvidenceStyle.TYPE_INK, Rect2(Vector2(LEFT, y), box), HORIZONTAL_ALIGNMENT_LEFT, true, LINE_SPACING)
	body.name = "Description"
	_text_rects.append(Rect2(Vector2(LEFT, y), Vector2(_widest_line(description, font, font_size), EvidenceStyle.text_height(description, font, font_size, TEXT_WIDTH, LINE_SPACING))))

	var presentation: Dictionary = entry.get("presentation", {})
	var art_spec: Dictionary = presentation.get("art", {})
	var art := EvidenceDocument.load_texture(str(entry.get("image", "")))
	if not art_spec.is_empty() and _build_art(art_spec, presentation.get("guest_list", {})):
		pass
	elif art != null:
		illustration = add_texture(art, ART_RECT)
		illustration.name = "Illustration"
		illustration.pivot_offset = ART_RECT.size * 0.5
	else:
		var emblem_name: String = EvidenceInfo.CATEGORY_ICONS.get(str(entry.get("category", "")), "lupa")
		var emblem_rect := Rect2(ART_RECT.get_center() - Vector2(EMBLEM_SIZE, EMBLEM_SIZE) * 0.5, Vector2(EMBLEM_SIZE, EMBLEM_SIZE))
		var emblem := add_texture(EvidenceStyle.icon(emblem_name), emblem_rect, Color(EvidenceStyle.TYPE_INK, 0.14))
		emblem.name = "Emblem"
		# Los iconos se importan sin mipmaps.
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_animate_art()


## Ilustración colocada con `presentation.art`: `image` (ruta), `center` ([x, y] en el tamaño de
## diseño de la ficha), `width` (ancho en ese mismo tamaño; por defecto, el de la imagen) y
## `rotation` (grados). Con `guest_list`, la imagen es el papel de una lista escrita con esos datos.
## Devuelve falso si la imagen no existe, para que la ficha use lo de siempre.
func _build_art(spec: Dictionary, guest_list: Dictionary) -> bool:
	var texture := EvidenceDocument.load_texture(str(spec.get("image", "")))
	if texture == null:
		push_warning("Ilustración de evidencia inexistente: %s" % spec.get("image", ""))
		return false
	var natural := texture.get_size()
	var width := float(spec.get("width", natural.x))
	var art_size := Vector2(width, width * natural.y / natural.x)
	var center := ART_RECT.get_center()
	var raw_center: Variant = spec.get("center", [])
	if raw_center is Array and (raw_center as Array).size() == 2:
		center = Vector2(float(raw_center[0]), float(raw_center[1]))
	var degrees := float(spec.get("rotation", 0.0))
	var rect := fit_art_rect(Rect2(center - art_size * 0.5, art_size), degrees, texture.get_image())
	if guest_list.is_empty():
		illustration = add_texture(texture, rect)
	else:
		illustration = EvidenceGuestList.new(texture, guest_list)
		illustration.position = rect.position
		illustration.size = rect.size
		add_child(illustration)
	illustration.name = "Illustration"
	illustration.pivot_offset = rect.size * 0.5
	illustration.rotation_degrees = degrees
	return true


## Encoge la ilustración hacia su centro mientras se salga de la cartulina o algo opaco suyo fuera
## a tapar un texto. Así un título o una descripción más largos nunca quedan debajo del dibujo.
func fit_art_rect(rect: Rect2, degrees: float, image: Image) -> Rect2:
	var center := rect.get_center()
	var factor := 1.0
	while factor > ART_MIN_SCALE:
		var candidate := Rect2(center - rect.size * factor * 0.5, rect.size * factor)
		if ART_BOUNDS.encloses(_rotated_bounds(candidate, degrees)) and not art_covers_text(candidate, degrees, image):
			return candidate
		factor -= 0.025
	return Rect2(center - rect.size * ART_MIN_SCALE * 0.5, rect.size * ART_MIN_SCALE)


## Si alguna parte opaca de la ilustración (en `rect`, girada `degrees`) cae sobre un texto. Sin
## imagen que leer, cuenta el rectángulo entero.
func art_covers_text(rect: Rect2, degrees: float, image: Image) -> bool:
	var bounds := _rotated_bounds(rect, degrees)
	for text_rect in _text_rects:
		var area := text_rect.grow(ART_TEXT_GAP).intersection(bounds)
		if area.has_area() and (image == null or _has_solid_pixels(area, rect, degrees, image)):
			return true
	return false


## Lo que ocupan los textos de la ficha (tipo, título, «Hallada en» y descripción).
func get_text_rects() -> Array[Rect2]:
	return _text_rects.duplicate()


## Ancho de la línea más larga de la descripción, partida en líneas como la etiqueta: la ilustración
## puede acercarse a lo escrito, no al borde de la caja.
static func _widest_line(text: String, font: Font, font_size: int) -> float:
	var paragraph := TextParagraph.new()
	paragraph.add_string(text, font, font_size)
	paragraph.width = TEXT_WIDTH
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var widest := 0.0
	for line in paragraph.get_line_count():
		widest = maxf(widest, paragraph.get_line_width(line))
	return minf(ceilf(widest), TEXT_WIDTH)


func _has_solid_pixels(area: Rect2, rect: Rect2, degrees: float, image: Image) -> bool:
	var pixels := Vector2(image.get_size())
	var turn := -deg_to_rad(degrees)
	var step := 3.0
	var y := area.position.y
	while y <= area.end.y:
		var x := area.position.x
		while x <= area.end.x:
			var local := (Vector2(x, y) - rect.get_center()).rotated(turn) + rect.size * 0.5
			var pixel := (local / rect.size * pixels).floor()
			if pixel.x >= 0.0 and pixel.y >= 0.0 and pixel.x < pixels.x and pixel.y < pixels.y:
				if image.get_pixel(int(pixel.x), int(pixel.y)).a > ART_SOLID_ALPHA:
					return true
			x += step
		y += step
	return false


static func _rotated_bounds(rect: Rect2, degrees: float) -> Rect2:
	if is_zero_approx(degrees):
		return rect
	var center := rect.get_center()
	var half := rect.size * 0.5
	var turn := deg_to_rad(degrees)
	var bounds := Rect2(center + Vector2(-half.x, -half.y).rotated(turn), Vector2.ZERO)
	for corner: Vector2 in [Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		bounds = bounds.expand(center + corner.rotated(turn))
	return bounds


## La ilustración aparece y se asienta sobre el papel justo después de abrirse la hoja. Con
## «Reducir movimiento» sólo aparece, sin moverse.
func _animate_art() -> void:
	if illustration == null or not is_inside_tree():
		return
	var motion := UiAccessibility.motion()
	var final_rotation := illustration.rotation
	illustration.modulate.a = 0.0
	illustration.scale = Vector2.ONE * lerpf(1.0, ART_SETTLE_SCALE, motion)
	illustration.rotation = final_rotation + deg_to_rad(ART_SETTLE_DEGREES) * motion
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(illustration, "modulate:a", 1.0, ART_IN).set_delay(ART_DELAY)
	tween.tween_property(illustration, "scale", Vector2.ONE, ART_IN).set_delay(ART_DELAY)
	tween.tween_property(illustration, "rotation", final_rotation, ART_IN).set_delay(ART_DELAY)


func _draw_ink(canvas: Control) -> void:
	var rule := Color(EvidenceStyle.PAPER_EDGE, 0.42)
	var inner := Rect2(Vector2.ZERO, DESIGN_SIZE).grow(-RULE_INSET)
	canvas.draw_rect(inner, rule, false, 1.4, true)
	canvas.draw_rect(inner.grow(-6.0), Color(rule, 0.22), false, 1.0, true)
	var red := Color(EvidenceStyle.TYPE_RED, 0.9)
	canvas.draw_line(_tag_rule.position, _tag_rule.position + Vector2(_tag_rule.size.x, 0.0), red, 2.4, true)
	# El subrayado del título se desvanece hacia la derecha, como un trazo de lápiz rojo.
	var start := _title_rule.position
	var finish := start + Vector2(_title_rule.size.x, 0.0)
	canvas.draw_polyline_colors(PackedVector2Array([start, start.lerp(finish, 0.75), finish]), PackedColorArray([red, red, Color(red, 0.0)]), 2.2, true)
