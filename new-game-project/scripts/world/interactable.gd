class_name Interactable
extends Area3D
## Elemento con el que el jugador puede interactuar pulsando E. Las pistas, puertas y
## NPC heredan de esta clase y sobrescriben `interact`.

signal interacted(actor: Node)

@export var prompt := "Examinar"
@export var enabled := true
@export var marker_height := 1.5
@export var trigger_radius := 1.1

var _marker: InteractionMarker


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if not _has_shape():
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = trigger_radius
		shape.shape = sphere
		add_child(shape)
	_marker = InteractionMarker.new()
	_marker.position = Vector3.UP * marker_height
	add_child(_marker)
	refresh_marker()


func get_prompt() -> String:
	return prompt


func can_interact() -> bool:
	return enabled


func interact(actor: Node) -> void:
	interacted.emit(actor)


func set_focused(value: bool) -> void:
	if _marker != null:
		_marker.set_focused(value)


## Indica si el marcador debe seguir visible cuando el jugador no está cerca.
func wants_attention() -> bool:
	return false


func refresh_marker() -> void:
	if _marker != null:
		_marker.set_attention(wants_attention())


func _has_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false
