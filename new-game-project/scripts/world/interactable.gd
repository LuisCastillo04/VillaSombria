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
var _focused := false


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
	_focused = value
	if _marker != null:
		_marker.set_focused(value)


## Estado opcional que acompaña al aviso de interacción («Preguntas pendientes»), o vacío.
func get_status_text() -> String:
	return ""


## Clase del estado, para su icono en el HUD (por ejemplo, las de `ConversationLog.npc_status`).
func get_status_kind() -> String:
	return ""


func set_marker_height(height: float) -> void:
	marker_height = height
	if _marker != null:
		_marker.position = Vector3.UP * height


## Indica si el marcador debe seguir visible cuando el jugador no está cerca.
func wants_attention() -> bool:
	return false


## Pone al día el marcador y, si el detective lo está mirando, el estado que enseña el HUD.
func refresh_marker() -> void:
	if _marker != null:
		_marker.set_attention(wants_attention())
		_marker.set_emphasis(wants_emphasis())
	if _focused:
		EventBus.interaction_status_changed.emit(get_status_text(), get_status_kind())


## Si el marcador debe destacar más de lo normal (algo nuevo que atender).
func wants_emphasis() -> bool:
	return false


func get_marker() -> InteractionMarker:
	return _marker


func _has_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false
