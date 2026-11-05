class_name PlayerController
extends CharacterBody3D
## Detective controlado por el jugador. El movimiento es relativo a la cámara.

const LOOK := {
	"skin": "c9a27e",
	"coat": "8a7a5c",
	"pants": "23262e",
	"accent": "c0862c",
	"hair": "1c1a18",
	"hair_style": "short",
	"hat": "fedora",
	"hat_color": "23252c",
	"coat_length": "long",
	"extras": ["scarf"],
}

@export var walk_speed := 4.0
@export var sprint_speed := 6.4
@export var acceleration := 34.0
@export var turn_speed := 13.0
@export var gravity := 22.0

## Orientación de la cámara, usada para que W siempre sea "arriba" en pantalla.
var camera_yaw := deg_to_rad(45.0)

@onready var model: CharacterModel = $Model
@onready var detector: InteractionDetector = $InteractionDetector


func _ready() -> void:
	model.build(LOOK)


func teleport(where: Vector3, facing_yaw: float = 0.0) -> void:
	global_position = where
	velocity = Vector3.ZERO
	model.rotation.y = facing_yaw


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not GameState.is_player_locked():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_move(input, Input.is_action_pressed("sprint"), delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not GameState.is_player_locked():
		if detector.trigger(self):
			get_viewport().set_input_as_handled()


func _move(input: Vector2, sprinting: bool, delta: float) -> void:
	var speed := sprint_speed if sprinting else walk_speed
	var wish := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw) * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	if wish.length_squared() > 0.01:
		var target_yaw := atan2(-wish.x, -wish.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	model.set_motion(horizontal.length() / sprint_speed)
