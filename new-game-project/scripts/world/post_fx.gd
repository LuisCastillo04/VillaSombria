class_name PostFx
extends CanvasLayer
## Capa de postproceso del mundo: niebla, filtro de color, viñeta y grano (`noir_post.gdshader`).
## La niebla sólo tiene sentido en exteriores. Su detalle y el grano de película dependen de la calidad
## de «Efectos y partículas» (`GraphicsQuality`); el filtro de color, de Configuración → Filtros
## (`VisualFilters`).

## Capa del postproceso: por debajo de toda la interfaz (HUD 2, menú principal 5, conversaciones 6,
## pausa 20, fundido 30, confirmaciones 45...). Lo que lee de la pantalla es sólo el mundo 3D, así que
## la niebla y el filtro de color nunca tiñen un menú, un diálogo ni el HUD.
const LAYER := 1
const OUTDOOR_FOG := 0.2
## Grano de película original (el valor por defecto de `noir_post.gdshader`).
const GRAIN := 0.035

@onready var _rect: ColorRect = $Rect


func _ready() -> void:
	layer = LAYER
	GraphicsQuality.register_post(self)
	VisualFilters.register_post(self)


## Filtro de color de Configuración → Filtros. Repetir el vigente no toca el material.
func set_visual_filter(id: String) -> void:
	VisualFilters.apply_to_material(_rect.material as ShaderMaterial, id)


## Filtro que se ve ahora.
func get_visual_filter() -> String:
	return VisualFilters.applied_to(_rect.material as ShaderMaterial)


## Capas de ruido de la niebla (de 1 a 4; 4 es la original) y si se dibuja el grano.
func set_quality(fog_octaves: int, grain: bool) -> void:
	var material := _rect.material as ShaderMaterial
	material.set_shader_parameter("fog_octaves", clampi(fog_octaves, 1, 4))
	material.set_shader_parameter("grain", GRAIN if grain else 0.0)


func get_fog_octaves() -> int:
	var value: Variant = (_rect.material as ShaderMaterial).get_shader_parameter("fog_octaves")
	return 4 if value == null else int(value)


func get_grain() -> float:
	var value: Variant = (_rect.material as ShaderMaterial).get_shader_parameter("grain")
	return GRAIN if value == null else float(value)


func set_outdoor(outdoor: bool) -> void:
	var material := _rect.material as ShaderMaterial
	material.set_shader_parameter("fog_amount", OUTDOOR_FOG if outdoor else 0.0)


## Niebla aplicada ahora, para que la imagen de una partida se vea igual que el juego.
func get_fog_amount() -> float:
	var material := _rect.material as ShaderMaterial
	return float(material.get_shader_parameter("fog_amount"))
