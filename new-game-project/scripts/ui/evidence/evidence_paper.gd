class_name EvidencePaper
extends ColorRect
## Hoja de papel antiguo de una evidencia, pintada por `evidence_paper.gdshader`: manchas, fibras,
## pliegues, bordes rasgados y quemados, un cerco de café opcional y la sombra que la separa del
## fondo. Cada plantilla elige sus pliegues y manchas con `configure`.
##
## El nodo sobresale `SHADOW_MARGIN` píxeles por cada lado para dibujar la sombra: `fit` recibe el
## rectángulo del papel y se encarga del resto.

const SHADER := preload("res://assets/shaders/evidence_paper.gdshader")
const SHADOW_MARGIN := 44.0

var _material: ShaderMaterial


func _init() -> void:
	name = "Paper"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	color = Color.WHITE
	_param("base_color", EvidenceStyle.PAPER)
	_param("light_color", EvidenceStyle.PAPER_LIGHT)
	_param("stain_color", EvidenceStyle.PAPER_STAIN)
	_param("edge_color", EvidenceStyle.PAPER_EDGE)
	_param("shadow_margin", SHADOW_MARGIN)


## Ajusta el aspecto de la hoja. Claves admitidas (todas opcionales):
## `seed`, `tear`, `chunks`, `edge_width`, `fold_strength`, `foxing`, `folds_x` y `folds_y` (listas
## de hasta cuatro posiciones entre 0 y 1), `ring` y `blot` (Vector4: centro relativo, radio en
## píxeles e intensidad) y los colores `base_color`, `light_color`, `stain_color` y `edge_color`.
func configure(options: Dictionary) -> void:
	for key: String in options:
		var value: Variant = options[key]
		if key == "folds_x" or key == "folds_y":
			value = _folds(value)
		_param(key, value)


## Coloca el papel en `rect` (coordenadas del padre), con su sombra alrededor.
func fit(rect: Rect2) -> void:
	position = rect.position - Vector2(SHADOW_MARGIN, SHADOW_MARGIN)
	size = rect.size + Vector2(SHADOW_MARGIN, SHADOW_MARGIN) * 2.0
	_param("rect_size", size)


## Rectángulo del papel, sin la sombra, en las coordenadas del padre.
func get_paper_rect() -> Rect2:
	return Rect2(position + Vector2(SHADOW_MARGIN, SHADOW_MARGIN), size - Vector2(SHADOW_MARGIN, SHADOW_MARGIN) * 2.0)


func get_parameter(key: String) -> Variant:
	return _material.get_shader_parameter(key)


func _param(key: StringName, value: Variant) -> void:
	_material.set_shader_parameter(key, value)


## Hasta cuatro posiciones de pliegue; el resto, -1 (sin pliegue).
static func _folds(positions: Variant) -> Vector4:
	var values := [-1.0, -1.0, -1.0, -1.0]
	if positions is Array:
		for index in mini((positions as Array).size(), 4):
			values[index] = float(positions[index])
	return Vector4(values[0], values[1], values[2], values[3])
