class_name LocationExit
extends Interactable
## Puerta o camino que lleva a otro escenario. Puede estar cerrada hasta que se cumpla
## una condición, y recorrerla consume tiempo del calendario.

@export var target_location := ""
@export var target_spawn := ""
@export var travel_minutes := 10

## Condición para poder pasar, con el formato de `Conditions`.
var requires: Dictionary = {}
var locked_message := ""


func _init(location_id: String = "", spawn_id: String = "", label: String = "Entrar") -> void:
	target_location = location_id
	target_spawn = spawn_id
	prompt = label
	marker_height = 2.3


func with_lock(condition: Dictionary, message: String) -> LocationExit:
	requires = condition
	locked_message = message
	return self


func interact(actor: Node) -> void:
	super.interact(actor)
	if not Conditions.check(requires):
		EventBus.notification_requested.emit("Cerrado", locked_message, "info")
		return
	GameClock.advance(travel_minutes)
	EventBus.location_change_requested.emit(target_location, target_spawn)
