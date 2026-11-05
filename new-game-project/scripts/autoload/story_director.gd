extends Node
## Hilo narrativo: objetivos, eventos por hora y paso de un día al siguiente.
## Los eventos se disparan al alcanzar o superar su hora, de modo que ningún salto de
## tiempo puede saltárselos.


func _ready() -> void:
	EventBus.time_changed.connect(_on_time_changed)


## Objetivos del día actual, pendientes primero.
func get_objectives() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	var finished: Array[Dictionary] = []
	for objective: Dictionary in GameData.story["objectives"]:
		if int(objective["day"]) != GameClock.day:
			continue
		if not Conditions.check(objective.get("visible", {})):
			continue
		var entry := {"text": objective["text"], "done": Conditions.check(objective["done"])}
		if entry["done"]:
			finished.append(entry)
		else:
			pending.append(entry)
	pending.append_array(finished)
	return pending


func get_day_title() -> String:
	return GameData.story["days"][str(GameClock.day)]["title"]


func can_rest() -> bool:
	return Conditions.check(GameData.story["days"][str(GameClock.day)]["rest_requires"])


func get_rest_blocked_message() -> String:
	return GameData.story["days"][str(GameClock.day)]["rest_blocked"]


## Pasa al día siguiente si se ha completado lo imprescindible.
func rest() -> bool:
	if not can_rest() or GameClock.day >= GameClock.LAST_DAY:
		return false
	GameClock.start_next_day()
	return true


## Ubicación actual de un personaje según su rutina, para el expediente.
func describe_whereabouts(npc_id: String) -> String:
	var slot := NpcSchedule.get_slot(npc_id, GameClock.day, GameClock.minutes)
	return slot.get("activity", "Paradero desconocido")


## Reproduce la escena narrativa asociada a entrar en un lugar, si la hay.
func on_location_entered(location_id: String) -> void:
	for trigger: Dictionary in GameData.story["on_enter"]:
		if trigger["location"] == location_id and Conditions.check(trigger.get("if", {})):
			DialogueManager.play_scene(trigger["scene"])
			return


func fire_due_events() -> void:
	for event: Dictionary in GameData.story["events"]:
		var flag := "evento_%s" % event["id"]
		if GameState.has_flag(flag):
			continue
		var day := int(event["day"])
		var due := GameClock.day > day
		due = due or (GameClock.day == day and GameClock.minutes >= GameClock.parse_time(event["time"]))
		if due and Conditions.check(event.get("if", {})):
			GameState.set_flag(flag)
			Effects.apply(event.get("effects", {}))


func _on_time_changed(_day: int, _minutes: int) -> void:
	fire_due_events()
