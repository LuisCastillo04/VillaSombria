class_name AccusationSheet
extends Control
## Hoja de la acusación formal: papel envejecido dentro de un marco burdeos con dos filetes dorados,
## volutas en las esquinas y una sombra suave sobre el escenario. Sólo pinta el soporte: lo que se
## lee y se elige (encabezado, campos, veredicto y botones) son sus hijos, ordenados por
## contenedores en la escena.
##
## El papel es el pergamino de las páginas del expediente (su shader); encima lleva un filete de
## tinta, escuadras en las esquinas y un cerco de café muy tenue, como una hoja usada.

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const RADIUS := 8.0
const BRACKET_INSET := 12.0
const BRACKET_LENGTH := 22.0

@export var paper_seed := 7.3
## Cerco de café en la esquina inferior derecha del papel.
@export var coffee_ring := true

var _paper: ColorRect
var _paper_material: ShaderMaterial
var _decor: Control
var _shadow: StyleBoxFlat
var _frame: StyleBoxFlat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shadow = AccusationStyle.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, int(RADIUS))
	_shadow.draw_center = false
	_shadow.shadow_color = AccusationStyle.SHADOW
	_shadow.shadow_size = 26
	_shadow.shadow_offset = Vector2(0.0, 10.0)
	_frame = AccusationStyle.box(AccusationStyle.FRAME, AccusationStyle.FRAME_DARK, 2, int(RADIUS))
	_paper_material = ShaderMaterial.new()
	_paper_material.shader = PARCHMENT_SHADER
	_paper_material.set_shader_parameter("base_color", AccusationStyle.PAPER)
	_paper_material.set_shader_parameter("stain_color", AccusationStyle.PAPER_STAIN)
	_paper_material.set_shader_parameter("edge_color", AccusationStyle.PAPER_EDGE)
	_paper_material.set_shader_parameter("corner_radius", 3.0)
	_paper_material.set_shader_parameter("edge_width", 60.0)
	_paper = ColorRect.new()
	_paper.name = "Paper"
	_paper.material = _paper_material
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper, false, Node.INTERNAL_MODE_FRONT)
	# Lo que se pinta sobre el papel y bajo el contenido: filete, escuadras y cerco de café.
	_decor = Control.new()
	_decor.name = "Decor"
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.draw.connect(_draw_decor)
	add_child(_decor, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	_paper_material.set_shader_parameter("seed", paper_seed)
	resized.connect(_fit)
	_fit()


## Rectángulo del papel, dentro del marco, en coordenadas de la hoja.
func get_paper_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-AccusationStyle.FRAME_WIDTH)


func _fit() -> void:
	var paper := get_paper_rect()
	_paper.position = paper.position
	_paper.size = paper.size
	_paper_material.set_shader_parameter("rect_size", paper.size)
	_decor.position = Vector2.ZERO
	_decor.size = size
	queue_redraw()
	_decor.queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_shadow, rect)
	draw_style_box(_frame, rect)
	# Luz rasante en la mitad superior del marco, como un barniz.
	draw_rect(Rect2(rect.position + Vector2(RADIUS, 2.0), Vector2(rect.size.x - RADIUS * 2.0, AccusationStyle.FRAME_WIDTH * 0.45)), Color(1.0, 0.8, 0.7, 0.06))
	draw_rect(rect.grow(-4.0), Color(AccusationStyle.GOLD, 0.85), false, 1.8, true)
	draw_rect(rect.grow(-AccusationStyle.FRAME_WIDTH + 3.0), Color(AccusationStyle.GOLD_DARK, 0.9), false, 1.2, true)
	var corners := [
		[rect.position + Vector2(4.0, 4.0), Vector2(-1.0, -1.0)],
		[Vector2(rect.end.x - 4.0, rect.position.y + 4.0), Vector2(1.0, -1.0)],
		[rect.end - Vector2(4.0, 4.0), Vector2(1.0, 1.0)],
		[Vector2(rect.position.x + 4.0, rect.end.y - 4.0), Vector2(-1.0, 1.0)],
	]
	for corner: Array in corners:
		EvidenceOrnaments.draw_corner_scroll(self, corner[0], corner[1], Color(AccusationStyle.GOLD, 0.9), 1.5)


func _draw_decor() -> void:
	var paper := get_paper_rect()
	_decor.draw_rect(paper.grow(-6.0), Color(AccusationStyle.GOLD_DARK, 0.55), false, 1.1, true)
	HudOrnaments.draw_corner_brackets(_decor, paper.grow(-BRACKET_INSET), BRACKET_LENGTH, Color(AccusationStyle.GOLD_DARK, 0.85))
	if not coffee_ring:
		return
	# Cerco de una taza apoyada en la esquina, muy tenue para no estorbar la lectura.
	var ring := Vector2(paper.end.x - 96.0, paper.end.y - 214.0)
	BoardOrnaments.draw_coffee_ring(_decor, ring, 46.0, Color(AccusationStyle.PAPER_STAIN, 0.38))
	_decor.draw_circle(ring + Vector2(-58.0, 36.0), 3.0, Color(AccusationStyle.PAPER_STAIN, 0.3), true, -1.0, true)
	_decor.draw_circle(ring + Vector2(-70.0, 52.0), 1.8, Color(AccusationStyle.PAPER_STAIN, 0.25), true, -1.0, true)
