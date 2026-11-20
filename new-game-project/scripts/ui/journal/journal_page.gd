class_name JournalPage
extends PanelContainer
## Página de pergamino del expediente: el papel manchado y quemado de los demás pergaminos del juego
## (su shader), un borde oscuro, un filete dorado, escuadras en las esquinas y una sombra sobre el
## cuero. Con `art`, un grabado sepia decorativo se asienta en una esquina inferior, detrás del
## contenido: adorna el espacio vacío sin ocupar sitio en el reparto.
##
## Las cinco pestañas usan estas páginas, así comparten un mismo aspecto sin repetir código.

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const BORDER_WIDTH := 2.0
const FILET_INSET := 6.0
const BRACKET_INSET := 10.0
const BRACKET_LENGTH := 18.0

enum ArtCorner { BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT }

## Márgenes del contenido: izquierda, arriba, derecha y abajo.
@export var padding := Vector4(26.0, 22.0, 26.0, 22.0):
	set(value):
		padding = value
		_apply_padding()
@export var paper_seed := 4.0
## Grabado decorativo de fondo (opcional).
@export var art: Texture2D:
	set(value):
		art = value
		queue_redraw()
@export var art_corner := ArtCorner.BOTTOM_LEFT
## Tamaño máximo del grabado y opacidad.
@export var art_size := Vector2(380.0, 230.0)
@export var art_alpha := 0.55

var _paper: ColorRect
var _paper_material: ShaderMaterial
var _padding_box := StyleBoxEmpty.new()
var _shadow: StyleBoxFlat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _padding_box)
	_apply_padding()


func _ready() -> void:
	_shadow = StyleBoxFlat.new()
	_shadow.draw_center = false
	_shadow.set_corner_radius_all(3)
	_shadow.shadow_color = JournalStyle.SHADOW
	_shadow.shadow_size = 12
	_shadow.shadow_offset = Vector2(0.0, 4.0)
	_paper_material = ShaderMaterial.new()
	_paper_material.shader = PARCHMENT_SHADER
	_paper_material.set_shader_parameter("base_color", JournalStyle.PARCHMENT)
	_paper_material.set_shader_parameter("stain_color", JournalStyle.PARCHMENT_STAIN)
	_paper_material.set_shader_parameter("edge_color", JournalStyle.PARCHMENT_EDGE)
	_paper_material.set_shader_parameter("corner_radius", 3.0)
	_paper_material.set_shader_parameter("edge_width", 46.0)
	_paper_material.set_shader_parameter("seed", paper_seed)
	_paper = ColorRect.new()
	_paper.name = "Paper"
	_paper.material = _paper_material
	_paper.show_behind_parent = true
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper, false, Node.INTERNAL_MODE_FRONT)
	# El contenedor encaja a todos sus hijos, el papel incluido, dentro de los márgenes: después de
	# cada reparto el papel vuelve a cubrir la página entera.
	sort_children.connect(_fit_paper)
	resized.connect(_on_resized)
	_fit_paper()


## Rectángulo donde se dibuja el grabado, o vacío si no hay grabado.
func get_art_rect() -> Rect2:
	if art == null:
		return Rect2()
	var inner := Rect2(Vector2.ZERO, size).grow(-FILET_INSET - 8.0)
	var scale := minf(art_size.x / art.get_width(), art_size.y / art.get_height())
	scale = minf(scale, inner.size.x / art.get_width())
	var art_extent := art.get_size() * scale
	var x := inner.position.x
	match art_corner:
		ArtCorner.BOTTOM_CENTER:
			x = inner.position.x + (inner.size.x - art_extent.x) * 0.5
		ArtCorner.BOTTOM_RIGHT:
			x = inner.end.x - art_extent.x
	return Rect2(Vector2(x, inner.end.y - art_extent.y), art_extent)


func _apply_padding() -> void:
	_padding_box.content_margin_left = padding.x
	_padding_box.content_margin_top = padding.y
	_padding_box.content_margin_right = padding.z
	_padding_box.content_margin_bottom = padding.w
	update_minimum_size()


func _fit_paper() -> void:
	if _paper == null:
		return
	_paper.position = Vector2.ZERO
	_paper.size = size
	_paper_material.set_shader_parameter("rect_size", size)


func _on_resized() -> void:
	_fit_paper()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_shadow, rect)
	if art != null:
		draw_texture_rect(art, get_art_rect(), false, Color(1.0, 1.0, 1.0, art_alpha))
	draw_rect(rect.grow(-BORDER_WIDTH * 0.5), JournalStyle.FRAME, false, BORDER_WIDTH, true)
	draw_rect(rect.grow(-FILET_INSET), Color(JournalStyle.GOLD_DARK, 0.75), false, 1.2, true)
	HudOrnaments.draw_corner_brackets(self, rect.grow(-BRACKET_INSET), BRACKET_LENGTH, Color(JournalStyle.GOLD_DARK, 0.9))
