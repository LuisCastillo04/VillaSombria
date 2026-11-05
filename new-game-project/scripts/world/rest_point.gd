class_name RestPoint
extends Interactable
## Cama de la pensión. Avanza al día siguiente sólo si lo imprescindible está hecho,
## de modo que nadie pueda saltarse una parte de la historia por accidente.


func _init() -> void:
	prompt = "Acostarse hasta mañana"
	marker_height = 1.1


func interact(actor: Node) -> void:
	super.interact(actor)
	if StoryDirector.can_rest():
		EventBus.rest_requested.emit()
	else:
		EventBus.notification_requested.emit("Todavía no", StoryDirector.get_rest_blocked_message(), "info")
