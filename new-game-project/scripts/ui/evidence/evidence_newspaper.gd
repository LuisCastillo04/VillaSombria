class_name EvidenceNewspaper
extends EvidenceDocument
## Periódico o crónica: una plana de diario de la época, doblada en cuatro y con los bordes
## mordidos. Cabecera con su viñeta grabada y el recuadro del lema, la línea de número, fecha y
## precio entre filetes, el titular a cuatro columnas, el subtítulo en cursiva, dos columnas de texto
## justificado y una fotografía nocturna de la mansión impresa en trama. Bajo la foto, la etiqueta
## de dónde se halló.
##
## Campos de `presentation` en `clues.json`: `masthead`, `tagline`, `issue`, `date`, `price`,
## `headline`, `subheadline`, `columns` (lista de textos), `image` (la foto) y `vignette` (la viñeta
## de la cabecera). Las imágenes son grabados con fondo transparente, como `mansion_grabado.svg`: la
## trama de imprenta la pone `evidence_newsprint.gdshader`.

const DESIGN_SIZE := Vector2(1500.0, 900.0)
const NEWSPRINT_SHADER := preload("res://assets/shaders/evidence_newsprint.gdshader")
const LEFT := 64.0
const RIGHT := 1436.0
const MASTHEAD_RECT := Rect2(318.0, 24.0, 906.0, 108.0)
const VIGNETTE_RECT := Rect2(72.0, 36.0, 232.0, 112.0)
const TAGLINE_RECT := Rect2(1262.0, 38.0, 172.0, 104.0)
const INFO_TOP := 176.0
const INFO_HEIGHT := 40.0
const STORY_LEFT := 66.0
const STORY_WIDTH := 840.0
const STORY_TOP := 248.0
const COLUMN_GAP := 44.0
const COLUMNS_BOTTOM := 836.0
const PHOTO_RECT := Rect2(940.0, 250.0, 494.0, 432.0)
const PHOTO_INSET := 9.0
## El grabado incluye árboles y suelo a los lados: se acerca para que la casa llene la foto.
const PHOTO_ZOOM := 1.55
const COLUMN_SPACING := 3.0
const COLUMN_FONT_SIZE := 25

var _rules: Array[Rect2] = []
var _column_rule := Rect2()


func get_design_size() -> Vector2:
	return DESIGN_SIZE


func get_template_id() -> String:
	return "periodico"


func _build() -> void:
	paper.configure({
		"seed": 7.7, "tear": 11.0, "chunks": 1.6, "edge_width": 90.0,
		"folds_x": [0.505], "folds_y": [0.5],
		"blot": Vector4(0.95, 0.94, 150.0, 0.55),
		"base_color": Color("d8c39b"), "light_color": Color("ecdcbb"),
	})
	_build_masthead()
	_build_info_line()
	var y := _build_story_head()
	_build_columns(y)
	_build_photo()
	var where := str(entry.get("where", ""))
	if not where.is_empty():
		var chip := EvidenceTag.new("Hallada en: %s" % where, "ubicacion", 23)
		chip.name = "Where"
		add_child(chip)
		chip.position = Vector2(PHOTO_RECT.position.x + 4.0, PHOTO_RECT.end.y + 30.0)
		chip.fit(PHOTO_RECT.size.x)


func _build_masthead() -> void:
	var vignette := EvidenceDocument.load_texture(field("vignette"))
	if vignette != null:
		_add_print(vignette, VIGNETTE_RECT, false).name = "Vignette"
	var masthead := field("masthead")
	var font := EvidenceStyle.masthead()
	var font_size := 108
	while font_size > 60 and font.get_string_size(masthead, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > MASTHEAD_RECT.size.x:
		font_size -= 2
	add_label(masthead, font, font_size, EvidenceStyle.PRINT_INK, MASTHEAD_RECT, HORIZONTAL_ALIGNMENT_CENTER, false).name = "Masthead"
	_rules.append(Rect2(MASTHEAD_RECT.position.x, MASTHEAD_RECT.end.y + 6.0, MASTHEAD_RECT.size.x, 2.4))
	_rules.append(Rect2(MASTHEAD_RECT.position.x, MASTHEAD_RECT.end.y + 12.0, MASTHEAD_RECT.size.x, 1.0))
	var tagline := field("tagline")
	if not tagline.is_empty():
		# Una palabra por línea, con la letra que deje caber la más larga dentro del recuadro.
		var words := tagline.to_upper().split(" ", false)
		var tag_font := EvidenceStyle.newspaper_bold()
		var box := TAGLINE_RECT.grow(-9.0)
		var tag_size := 22
		for word in words:
			while tag_size > 12 and tag_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x > box.size.x:
				tag_size -= 1
		var label := add_label("\n".join(words), tag_font, tag_size, EvidenceStyle.PRINT_INK, box, HORIZONTAL_ALIGNMENT_CENTER, false, -2.0)
		label.name = "Tagline"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_info_line() -> void:
	_rules.append(Rect2(LEFT, INFO_TOP - 12.0, RIGHT - LEFT, 3.0))
	_rules.append(Rect2(LEFT, INFO_TOP - 6.0, RIGHT - LEFT, 1.0))
	var font := EvidenceStyle.newspaper_bold()
	var row := Rect2(LEFT + 4.0, INFO_TOP, RIGHT - LEFT - 8.0, INFO_HEIGHT)
	for item: Array in [["issue", HORIZONTAL_ALIGNMENT_LEFT], ["date", HORIZONTAL_ALIGNMENT_CENTER], ["price", HORIZONTAL_ALIGNMENT_RIGHT]]:
		var text := field(item[0])
		if not text.is_empty():
			var label := add_label(text, font, 25, EvidenceStyle.PRINT_INK, row, item[1], false)
			label.name = String(item[0]).capitalize()
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rules.append(Rect2(LEFT, INFO_TOP + INFO_HEIGHT + 4.0, RIGHT - LEFT, 1.0))
	_rules.append(Rect2(LEFT, INFO_TOP + INFO_HEIGHT + 8.0, RIGHT - LEFT, 3.0))


## Titular en mayúsculas y subtítulo en cursiva. Devuelve dónde empiezan las columnas.
func _build_story_head() -> float:
	var y := STORY_TOP
	var headline := field("headline").to_upper()
	var font := EvidenceStyle.headline()
	var box := Vector2(STORY_WIDTH, 220.0)
	var font_size := EvidenceStyle.fit_font_size(headline, font, 104, 54, box, -6.0)
	var height := EvidenceStyle.text_height(headline, font, font_size, STORY_WIDTH, -6.0)
	add_label(headline, font, font_size, EvidenceStyle.PRINT_INK, Rect2(STORY_LEFT, y, STORY_WIDTH, height + 6.0), HORIZONTAL_ALIGNMENT_LEFT, true, -6.0).name = "Headline"
	y += height + 14.0
	var subheadline := field("subheadline")
	if not subheadline.is_empty():
		var italic := EvidenceStyle.newspaper_italic()
		var sub_size := EvidenceStyle.fit_font_size(subheadline, italic, 46, 30, Vector2(STORY_WIDTH - 40.0, 120.0))
		var sub_height := EvidenceStyle.text_height(subheadline, italic, sub_size, STORY_WIDTH - 40.0)
		add_label(subheadline, italic, sub_size, EvidenceStyle.PRINT_INK, Rect2(STORY_LEFT, y, STORY_WIDTH - 40.0, sub_height + 6.0)).name = "Subheadline"
		y += sub_height + 26.0
	return y


## Columnas de texto justificado con un filete entre ellas; la letra es la misma en todas y se
## reduce si alguna no cabe.
func _build_columns(top: float) -> void:
	var presentation: Dictionary = entry.get("presentation", {})
	var columns: Array = presentation.get("columns", [])
	if columns.is_empty():
		return
	var count := columns.size()
	var width := (STORY_WIDTH - COLUMN_GAP * (count - 1)) / count
	var box := Vector2(width, COLUMNS_BOTTOM - top)
	var font := EvidenceStyle.newspaper_body()
	var font_size := COLUMN_FONT_SIZE
	for text: Variant in columns:
		font_size = mini(font_size, EvidenceStyle.fit_font_size(str(text), font, COLUMN_FONT_SIZE, 18, box, COLUMN_SPACING))
	for index in count:
		var x := STORY_LEFT + index * (width + COLUMN_GAP)
		var label := add_label(str(columns[index]), font, font_size, EvidenceStyle.PRINT_INK, Rect2(Vector2(x, top), box), HORIZONTAL_ALIGNMENT_FILL, true, COLUMN_SPACING)
		label.name = "Column%d" % (index + 1)
		label.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_SKIP_LAST_LINE
	if count > 1:
		var lines := EvidenceStyle.text_height(str(columns[0]), font, font_size, width, COLUMN_SPACING)
		for text: Variant in columns:
			lines = maxf(lines, EvidenceStyle.text_height(str(text), font, font_size, width, COLUMN_SPACING))
		_column_rule = Rect2(STORY_LEFT + width + COLUMN_GAP * 0.5, top + 4.0, 0.0, lines)


## Fotografía con marco de imprenta; la imagen llena el recuadro apoyada abajo, con cielo encima.
func _build_photo() -> void:
	var texture := EvidenceDocument.load_texture(field("image"))
	if texture == null:
		return
	var inner := PHOTO_RECT.grow(-PHOTO_INSET)
	var photo := ColorRect.new()
	photo.name = "Photo"
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.position = inner.position
	photo.size = inner.size
	var art_width := inner.size.x * PHOTO_ZOOM
	var art_height := art_width * texture.get_height() / maxf(texture.get_width(), 1.0)
	var art_rect := Rect2((inner.size.x - art_width) * 0.5, inner.size.y - art_height * 0.93, art_width, art_height)
	photo.material = _newsprint(texture, inner.size, art_rect, true)
	add_child(photo)


## Viñeta impresa: el grabado entintado en trama, sin fondo.
func _add_print(texture: Texture2D, rect: Rect2, night: bool) -> ColorRect:
	var print_rect := ColorRect.new()
	print_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print_rect.position = rect.position
	print_rect.size = rect.size
	var scale_factor := minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	var art_size := Vector2(texture.get_width(), texture.get_height()) * scale_factor
	print_rect.material = _newsprint(texture, rect.size, Rect2((rect.size - art_size) * 0.5, art_size), night)
	add_child(print_rect)
	return print_rect


static func _newsprint(texture: Texture2D, rect_size: Vector2, art_rect: Rect2, night: bool) -> ShaderMaterial:
	var newsprint := ShaderMaterial.new()
	newsprint.shader = NEWSPRINT_SHADER
	newsprint.set_shader_parameter("art_texture", texture)
	newsprint.set_shader_parameter("art_rect", Vector4(art_rect.position.x, art_rect.position.y, art_rect.size.x, art_rect.size.y))
	newsprint.set_shader_parameter("rect_size", rect_size)
	newsprint.set_shader_parameter("ink_color", EvidenceStyle.PRINT_INK)
	newsprint.set_shader_parameter("paper_color", Color("d9c7a0"))
	newsprint.set_shader_parameter("night", 1.0 if night else 0.0)
	newsprint.set_shader_parameter("dot_spacing", 4.4 if night else 3.2)
	return newsprint


func _draw_ink(canvas: Control) -> void:
	var ink := EvidenceStyle.PRINT_INK
	for rule in _rules:
		canvas.draw_rect(rule, ink)
	canvas.draw_rect(TAGLINE_RECT, ink, false, 2.0, true)
	canvas.draw_rect(TAGLINE_RECT.grow(-4.0), Color(ink, 0.6), false, 1.0, true)
	if _column_rule.size.y > 0.0:
		canvas.draw_line(_column_rule.position, _column_rule.position + Vector2(0.0, _column_rule.size.y), Color(ink, 0.8), 1.4, true)
	if get_node_or_null("Photo") != null:
		canvas.draw_rect(PHOTO_RECT, ink, false, 2.4, true)
		canvas.draw_rect(PHOTO_RECT.grow(-4.5), Color(ink, 0.55), false, 1.0, true)
