class_name EvidenceRecordCard
extends EvidenceDocument
## Ficha de investigación («Evidencia / Objeto»): una cartulina antigua doblada por la mitad con el
## tipo de prueba en rojo, el título, la etiqueta de dónde se halló y la descripción a máquina a la
## izquierda, y la ilustración de la prueba a la derecha.
##
## Sirve para cualquier prueba: sólo usa los campos de siempre de `clues.json`. La ilustración es
## el campo `image` (la misma que enseña el expediente); sin ella, la derecha muestra el emblema de
## la categoría estampado en tinta tenue. Los textos largos reducen la letra para caber.

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
const EMBLEM_SIZE := 280.0
## Filetes interiores de la cartulina.
const RULE_INSET := 30.0
const LINE_SPACING := 12.0

var _tag_rule := Rect2()
var _title_rule := Rect2()


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
	y += title_height + 18.0
	_title_rule = Rect2(LEFT, y, TITLE_WIDTH - 20.0, 0.0)
	y += 30.0

	var where := str(entry.get("where", ""))
	if not where.is_empty():
		var chip := EvidenceTag.new("Hallada en: %s" % where, "ubicacion", 25)
		chip.name = "Where"
		add_child(chip)
		chip.position = Vector2(LEFT, y)
		y += chip.fit(TEXT_WIDTH + 40.0).y + 36.0

	var description := str(entry.get("description", ""))
	var font := EvidenceStyle.typewriter()
	var box := Vector2(TEXT_WIDTH, BOTTOM - y)
	var font_size := EvidenceStyle.fit_font_size(description, font, 30, 20, box, LINE_SPACING)
	var body := add_label(description, font, font_size, EvidenceStyle.TYPE_INK, Rect2(Vector2(LEFT, y), box), HORIZONTAL_ALIGNMENT_LEFT, true, LINE_SPACING)
	body.name = "Description"

	var art := EvidenceDocument.load_texture(str(entry.get("image", "")))
	if art != null:
		add_texture(art, ART_RECT).name = "Illustration"
	else:
		var emblem_name: String = EvidenceInfo.CATEGORY_ICONS.get(str(entry.get("category", "")), "lupa")
		var emblem_rect := Rect2(ART_RECT.get_center() - Vector2(EMBLEM_SIZE, EMBLEM_SIZE) * 0.5, Vector2(EMBLEM_SIZE, EMBLEM_SIZE))
		var emblem := add_texture(EvidenceStyle.icon(emblem_name), emblem_rect, Color(EvidenceStyle.TYPE_INK, 0.14))
		emblem.name = "Emblem"
		# Los iconos se importan sin mipmaps.
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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
