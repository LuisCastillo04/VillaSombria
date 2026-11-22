class_name EvidenceDocument
extends Control
## Base de las plantillas de evidencia: la hoja de papel y lo que va escrito o dibujado en ella.
##
## Cada plantilla (`EvidenceLetter`, `EvidenceNewspaper`, `EvidenceRecordCard`) coloca sus piezas en
## su propio tamaño de diseño (`get_design_size`), como si la pantalla midiera eso. La interfaz
## escala el documento entero para que quepa: así ningún texto se sale ni se pisa en ninguna
## resolución ni con ningún tamaño de letra de Accesibilidad, y el papel conserva su proporción.
##
## Los datos llegan ya leídos por `EvidenceInfo` (`setup`); la plantilla sólo los pinta. Fondo,
## adornos y textos son nodos separados: el papel es un shader, las ilustraciones son SVG y todo lo
## que se lee son etiquetas con los textos de `data/clues.json`.

const DEFAULT_DESIGN_SIZE := Vector2(1500.0, 900.0)

## Datos de la prueba, como los devuelve `EvidenceInfo.describe`.
var entry: Dictionary = {}
var paper: EvidencePaper
## Capa de tinta entre el papel y los textos: filetes, subrayados y trazos de pluma. La dibuja
## `_draw_ink` de cada plantilla.
var ink: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_design_size()
	paper = EvidencePaper.new()
	add_child(paper)
	paper.fit(Rect2(Vector2.ZERO, get_design_size()))
	ink = Control.new()
	ink.name = "Ink"
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.size = get_design_size()
	add_child(ink)
	ink.draw.connect(func() -> void: _draw_ink(ink))


## Tamaño en el que la plantilla coloca sus piezas; la interfaz lo escala para que quepa.
func get_design_size() -> Vector2:
	return DEFAULT_DESIGN_SIZE


func setup(data: Dictionary) -> void:
	entry = data
	_build()
	ink.queue_redraw()


## Lo implementa cada plantilla: crea sus piezas a partir de `entry`.
func _build() -> void:
	pass


## Lo implementa cada plantilla que traza líneas sobre el papel, por debajo de los textos.
func _draw_ink(_canvas: Control) -> void:
	pass


## Identificador de la plantilla, como en `EvidenceInfo.TEMPLATES`.
func get_template_id() -> String:
	return ""


## Todos los textos que se leen en el documento, en orden, para comprobarlos.
func get_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	_collect_texts(self, texts)
	return texts


## Un campo de la presentación de la prueba (`presentation` en `clues.json`), o `fallback`.
func field(key: String, fallback: String = "") -> String:
	var presentation: Dictionary = entry.get("presentation", {})
	return str(presentation.get(key, fallback))


## Etiqueta colocada en `rect` (coordenadas de diseño), con ajuste de línea si `wrapped`.
func add_label(text: String, font: Font, font_size: int, color: Color, rect: Rect2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrapped: bool = true, line_spacing: float = 0.0) -> Label:
	var label := EvidenceStyle.make_label(text, font, font_size, color)
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrapped else TextServer.AUTOWRAP_OFF
	if line_spacing != 0.0:
		label.add_theme_constant_override("line_spacing", int(line_spacing))
	label.position = rect.position
	label.size = rect.size
	add_child(label)
	return label


## Imagen colocada en `rect`, sin deformarla, con filtrado suave para cualquier escala.
func add_texture(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.modulate = tint
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.position = rect.position
	image.size = rect.size
	add_child(image)
	return image


## Carga una textura de los datos sólo si existe, para que una ruta mal escrita no rompa la hoja.
static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _collect_texts(node: Node, texts: PackedStringArray) -> void:
	for child in node.get_children():
		if child is Label and (child as Label).visible and not (child as Label).text.is_empty():
			texts.append((child as Label).text)
		_collect_texts(child, texts)
