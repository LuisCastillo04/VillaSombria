class_name ScreenFade
extends CanvasLayer
## Fundido a negro para las transiciones entre escenarios.

@onready var _rect: ColorRect = $Rect


func _ready() -> void:
	_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_out(seconds: float = 0.35) -> void:
	await _fade_to(1.0, seconds)


func fade_in(seconds: float = 0.45) -> void:
	await _fade_to(0.0, seconds)


func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, seconds)
	await tween.finished
