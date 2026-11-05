class_name ClueObject
extends Interactable
## Objeto del escenario que contiene una pista. Mientras no se haya examinado muestra
## su marcador a distancia; después se puede releer, pero no se registra de nuevo.

@export var clue_id := ""


func _init(id: String = "") -> void:
	clue_id = id
	marker_height = 1.0


func get_prompt() -> String:
	return GameData.clues.get(clue_id, {}).get("prompt", "Examinar")


func wants_attention() -> bool:
	return not GameState.clues.has(clue_id)


func interact(actor: Node) -> void:
	super.interact(actor)
	EventBus.clue_inspection_requested.emit(clue_id)
	refresh_marker()
