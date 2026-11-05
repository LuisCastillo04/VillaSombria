class_name Effects
extends RefCounted
## Aplica los efectos declarados en los datos al terminar un diálogo o un evento.


static func apply(effects: Dictionary) -> void:
	for flag: String in effects.get("flags", []):
		GameState.set_flag(flag)
	for clue_id: String in effects.get("clues", []):
		Investigation.discover_clue(clue_id)
	for testimony_id: String in effects.get("testimonies", []):
		Investigation.record_testimony(testimony_id)
	if effects.has("notify"):
		var note: Dictionary = effects["notify"]
		EventBus.notification_requested.emit(note.get("title", ""), note.get("body", ""), "historia")
	if effects.has("minutes"):
		GameClock.advance(int(effects["minutes"]))
	if effects.has("action"):
		EventBus.story_action.emit(effects["action"])
