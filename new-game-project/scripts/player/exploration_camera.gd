class_name ExplorationCamera
extends Node3D
## Cámara ortográfica semicenital que sigue a un objetivo con suavizado.

@export var yaw_degrees := 45.0
@export var pitch_degrees := -36.0
@export var view_size := 15.0
@export var distance := 40.0
@export var smoothing := 6.0

var target: Node3D
## Rectángulo XZ que limita el punto enfocado. Un tamaño cero desactiva el límite.
var limits := Rect2()

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = view_size
	camera.position = Vector3(0.0, 0.0, distance)
	camera.near = 0.5
	camera.far = distance * 2.5
	camera.current = true


func get_yaw() -> float:
	return deg_to_rad(yaw_degrees)


## Coloca la cámara directamente sobre el objetivo, sin transición.
func snap() -> void:
	if target != null:
		global_position = _focus_point()


func _process(delta: float) -> void:
	if target == null:
		return
	global_position = global_position.lerp(_focus_point(), 1.0 - exp(-smoothing * delta))


func _focus_point() -> Vector3:
	var focus := target.global_position + Vector3.UP * 0.9
	if limits.has_area():
		focus.x = clampf(focus.x, limits.position.x, limits.end.x)
		focus.z = clampf(focus.z, limits.position.y, limits.end.y)
	return focus
