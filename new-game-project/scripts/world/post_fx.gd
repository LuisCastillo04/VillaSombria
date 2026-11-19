class_name PostFx
extends CanvasLayer
## Capa de postproceso. La niebla sólo tiene sentido en exteriores.

const OUTDOOR_FOG := 0.2

@onready var _rect: ColorRect = $Rect


func set_outdoor(outdoor: bool) -> void:
	var material := _rect.material as ShaderMaterial
	material.set_shader_parameter("fog_amount", OUTDOOR_FOG if outdoor else 0.0)


## Niebla aplicada ahora, para que la imagen de una partida se vea igual que el juego.
func get_fog_amount() -> float:
	var material := _rect.material as ShaderMaterial
	return float(material.get_shader_parameter("fog_amount"))
