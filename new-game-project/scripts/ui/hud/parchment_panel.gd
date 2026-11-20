class_name ParchmentPanel
extends PanelContainer
## Panel de pergamino envejecido del HUD: el papel manchado y quemado del expediente (su shader),
## un borde exterior oscuro que lo separa del escenario, un filete dorado por dentro, escuadras en
## las esquinas y una sombra. Con `banner_text`, una cinta burdeos con el rótulo monta sobre el
## borde superior, como el «OBJETIVO» del panel de objetivos.
##
## Todo se dibuja en código, sin texturas estiradas: el panel crece con su contenido y se adapta a
## cualquier tamaño. No recibe el ratón, así que nunca tapa la exploración.

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const BORDER_WIDTH := 2.5
const FILET_INSET := 5.5
const BRACKET_INSET := 9.5
const BRACKET_LENGTH := 15.0
const BANNER_PADDING := 40.0
const BANNER_NOTCH := 10.0
## Distancia de los rombos de la cinta al texto.
const BANNER_DIAMOND_GAP := 14.0

## Rótulo de la cinta sobre el borde superior; vacío, sin cinta.
@export var banner_text := "":
	set(value):
		banner_text = value
		_update_padding()
		queue_redraw()
## Márgenes del contenido: izquierda, arriba, derecha y abajo, dentro del borde.
@export var padding := Vector4(24.0, 16.0, 26.0, 16.0):
	set(value):
		padding = value
		_update_padding()
## Cada panel con sus propias manchas, como hojas distintas.
@export var paper_seed := 2.0

## Destello de la cinta, de 0 a 1. Lo anima quien quiera llamar la atención sobre el panel.
var banner_glow := 0.0:
	set(value):
		banner_glow = value
		queue_redraw()

var _paper: ColorRect
var _paper_material: ShaderMaterial
var _padding_box := StyleBoxEmpty.new()
var _shadow: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _padding_box)
	_shadow = StyleBoxFlat.new()
	_shadow.draw_center = false
	_shadow.set_corner_radius_all(3)
	_shadow.shadow_color = HudStyle.SHADOW
	_shadow.shadow_size = 16
	_shadow.shadow_offset = Vector2(0.0, 4.0)
	_build_paper()
	_update_padding()
	resized.connect(_on_resized)
	# El contenedor encaja a todos sus hijos, también al papel, dentro de los márgenes: después de
	# cada reparto se devuelve el papel a todo el pergamino.
	sort_children.connect(_fit_paper)


## Altura de la cinta que sobresale por encima del borde superior.
func get_banner_overhang() -> float:
	return HudStyle.BANNER_HEIGHT * 0.5 if not banner_text.is_empty() else 0.0


## Rectángulo del pergamino dentro del control, sin la parte de la cinta que sobresale.
func get_frame_rect() -> Rect2:
	var top := get_banner_overhang()
	return Rect2(0.0, top, size.x, maxf(size.y - top, 0.0))


func _build_paper() -> void:
	_paper_material = ShaderMaterial.new()
	_paper_material.shader = PARCHMENT_SHADER
	_paper_material.set_shader_parameter("base_color", HudStyle.PARCHMENT)
	_paper_material.set_shader_parameter("stain_color", HudStyle.PARCHMENT_STAIN)
	_paper_material.set_shader_parameter("edge_color", HudStyle.PARCHMENT_EDGE)
	_paper_material.set_shader_parameter("corner_radius", 2.0)
	_paper_material.set_shader_parameter("edge_width", 30.0)
	_paper_material.set_shader_parameter("seed", paper_seed)
	_paper = ColorRect.new()
	_paper.name = "Paper"
	_paper.material = _paper_material
	_paper.show_behind_parent = true
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper, false, Node.INTERNAL_MODE_FRONT)


func _update_padding() -> void:
	# Bajo la cinta, el texto empieza después de su mitad inferior.
	_padding_box.content_margin_left = padding.x
	_padding_box.content_margin_top = padding.y + get_banner_overhang() * 2.0
	_padding_box.content_margin_right = padding.z
	_padding_box.content_margin_bottom = padding.w
	update_minimum_size()
	_fit_paper()


func _fit_paper() -> void:
	if _paper == null:
		return
	var frame := get_frame_rect()
	_paper.position = frame.position
	_paper.size = frame.size
	_paper_material.set_shader_parameter("rect_size", frame.size)


func _on_resized() -> void:
	_fit_paper()
	queue_redraw()


func _draw() -> void:
	var frame := get_frame_rect()
	draw_style_box(_shadow, frame)
	draw_rect(frame.grow(-BORDER_WIDTH * 0.5), HudStyle.FRAME, false, BORDER_WIDTH, true)
	draw_rect(frame.grow(-FILET_INSET), Color(HudStyle.GOLD, 0.8), false, 1.2, true)
	HudOrnaments.draw_corner_brackets(self, frame.grow(-BRACKET_INSET), BRACKET_LENGTH, Color(HudStyle.GOLD, 0.95))
	if not banner_text.is_empty():
		_draw_banner()


## Cinta burdeos centrada sobre el borde superior, con el rótulo en versalitas entre dos rombos.
func _draw_banner() -> void:
	var font := HudStyle.banner_font()
	var font_size := HudStyle.BANNER_SIZE
	var text_width := font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := text_width + BANNER_PADDING * 2.0
	var rect := Rect2((size.x - width) * 0.5, 0.0, width, HudStyle.BANNER_HEIGHT)
	if banner_glow > 0.0:
		for ring in 3:
			var halo := HudOrnaments.ribbon(rect.grow(3.0 + ring * 4.0), BANNER_NOTCH)
			draw_colored_polygon(halo, Color(HudStyle.GOLD_LIGHT, 0.16 * banner_glow / (ring + 1)))
	var shape := HudOrnaments.ribbon(rect, BANNER_NOTCH)
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(0.0, 3.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.35))
	draw_colored_polygon(shape, HudStyle.BURGUNDY.lerp(Color("b23a45"), banner_glow * 0.5))
	draw_polyline(HudOrnaments.closed(shape), HudStyle.GOLD.lerp(HudStyle.GOLD_LIGHT, banner_glow), 1.6, true)
	var inner := HudOrnaments.ribbon(rect.grow(-3.5), BANNER_NOTCH - 1.0)
	draw_polyline(HudOrnaments.closed(inner), Color(HudStyle.GOLD, 0.45), 1.0, true)
	var center := rect.get_center()
	var baseline := rect.position.y + (rect.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	draw_string(font, Vector2(center.x - text_width * 0.5, baseline), banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HudStyle.CREAM)
	for side: float in [-1.0, 1.0]:
		var spot := Vector2(center.x + side * (text_width * 0.5 + BANNER_DIAMOND_GAP), center.y)
		HudOrnaments.draw_diamond(self, spot, 3.4, HudStyle.GOLD_LIGHT)
