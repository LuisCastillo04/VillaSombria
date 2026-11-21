class_name DialogueFrame
extends Control
## Ventana inferior de las conversaciones: cuero oscuro con filetes dorados por fuera, esquinas de
## latón y, dentro, un pergamino envejecido con un filete de tinta de esquinas en escuadra. Es la
## misma ventana para el diálogo y para las respuestas: sólo cambian lo que lleva dentro y su altura.
##
## Se dibuja en código con los shaders de cuero y de pergamino del expediente y del tablero, sin
## texturas estiradas, así que sirve para cualquier tamaño. Las piezas de dentro (la placa con el
## nombre, el texto, las respuestas y los avisos de teclas) son hijas ancladas a sus bordes: al
## cambiar la altura de la ventana, cada una sigue al borde que le corresponde.

const LEATHER_SHADER := preload("res://assets/shaders/leather.gdshader")
const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const RADIUS := 6.0
## Distancia del filete de tinta al borde del pergamino y tamaño de sus escuadras.
const RULE_INSET := 9.0
const RULE_NOTCH := 9.0
const CORNER_LENGTH := 30.0

## Cada ventana con sus propias manchas y vetas.
@export var paper_seed := 6.1

var _leather: ColorRect
var _paper: ColorRect
var _shadow: StyleBoxFlat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow = StyleBoxFlat.new()
	_shadow.draw_center = false
	_shadow.set_corner_radius_all(int(RADIUS))
	_shadow.shadow_color = DialogueStyle.SHADOW
	_shadow.shadow_size = 22
	_shadow.shadow_offset = Vector2(0.0, 6.0)
	_leather = _shader_rect("Leather", LEATHER_SHADER)
	var leather := _leather.material as ShaderMaterial
	leather.set_shader_parameter("base_color", DialogueStyle.LEATHER)
	leather.set_shader_parameter("dark_color", DialogueStyle.LEATHER_DARK)
	leather.set_shader_parameter("sheen_color", DialogueStyle.LEATHER_SHEEN)
	leather.set_shader_parameter("corner_radius", RADIUS)
	leather.set_shader_parameter("edge_width", 10.0)
	leather.set_shader_parameter("seed", 3.9)
	_paper = _shader_rect("Paper", PARCHMENT_SHADER)
	var paper := _paper.material as ShaderMaterial
	paper.set_shader_parameter("base_color", DialogueStyle.PARCHMENT)
	paper.set_shader_parameter("stain_color", DialogueStyle.PARCHMENT_STAIN)
	paper.set_shader_parameter("edge_color", DialogueStyle.PARCHMENT_EDGE)
	paper.set_shader_parameter("corner_radius", 2.0)
	paper.set_shader_parameter("edge_width", 46.0)
	resized.connect(_on_resized)


func _ready() -> void:
	(_paper.material as ShaderMaterial).set_shader_parameter("seed", paper_seed)
	_on_resized()


## Rectángulo del pergamino, dentro de la banda de cuero.
func get_paper_rect() -> Rect2:
	var border := DialogueStyle.BORDER
	return Rect2(Vector2(border, border), (size - Vector2(border, border) * 2.0).max(Vector2.ZERO))


func _shader_rect(node_name: String, shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	rect.show_behind_parent = true
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect, false, Node.INTERNAL_MODE_FRONT)
	return rect


func _on_resized() -> void:
	_fit(_leather, Rect2(Vector2.ZERO, size))
	_fit(_paper, get_paper_rect())
	queue_redraw()


static func _fit(rect: ColorRect, area: Rect2) -> void:
	rect.position = area.position
	rect.size = area.size
	(rect.material as ShaderMaterial).set_shader_parameter("rect_size", area.size)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < CORNER_LENGTH * 3.0 or rect.size.y < CORNER_LENGTH * 2.0:
		return
	var paper := get_paper_rect()
	draw_style_box(_shadow, rect)
	# Por fuera, un filete dorado viejo y otro más vivo; por dentro, el dorado que enmarca el papel.
	draw_rect(rect.grow(-1.0), Color(DialogueStyle.GOLD_DARK, 0.95), false, 2.0, true)
	draw_rect(rect.grow(-4.5), Color(DialogueStyle.GOLD, 0.55), false, 1.0, true)
	draw_rect(paper.grow(1.5), Color(DialogueStyle.GOLD, 0.95), false, 1.8, true)
	draw_rect(Rect2(paper.position, Vector2(paper.size.x, 7.0)), Color(0.0, 0.0, 0.0, 0.12))
	# Filete de tinta sobre el pergamino, con las esquinas en escuadra.
	var rule := DialogueOrnaments.notched_rect(paper.grow(-RULE_INSET), RULE_NOTCH)
	draw_polyline(HudOrnaments.closed(rule), DialogueStyle.RULE, 1.2, true)
	var inset := DialogueStyle.BORDER * 0.5
	var fill := DialogueStyle.LEATHER_DARK
	DialogueOrnaments.draw_corner_piece(self, Vector2(inset, inset), Vector2(1.0, 1.0), CORNER_LENGTH, DialogueStyle.GOLD_LIGHT, fill)
	DialogueOrnaments.draw_corner_piece(self, Vector2(size.x - inset, inset), Vector2(-1.0, 1.0), CORNER_LENGTH, DialogueStyle.GOLD_LIGHT, fill)
	DialogueOrnaments.draw_corner_piece(self, Vector2(inset, size.y - inset), Vector2(1.0, -1.0), CORNER_LENGTH, DialogueStyle.GOLD_LIGHT, fill)
	DialogueOrnaments.draw_corner_piece(self, size - Vector2(inset, inset), Vector2(-1.0, -1.0), CORNER_LENGTH, DialogueStyle.GOLD_LIGHT, fill)
