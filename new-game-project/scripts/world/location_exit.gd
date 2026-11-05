class_name LocationExit
extends Interactable
## Puerta o camino que lleva a otro escenario.

@export var target_location := ""
@export var target_spawn := ""


func _init(location_id: String = "", spawn_id: String = "", label: String = "Entrar") -> void:
	target_location = location_id
	target_spawn = spawn_id
	prompt = label
	marker_height = 2.3


func interact(actor: Node) -> void:
	super.interact(actor)
	EventBus.location_change_requested.emit(target_location, target_spawn)
