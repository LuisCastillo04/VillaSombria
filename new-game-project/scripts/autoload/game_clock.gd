extends Node
## Calendario de los tres días del caso. El tiempo sólo avanza con las acciones del
## jugador, nunca en tiempo real, para que no se pueda perder nada por llegar tarde.

const DAY_START := 8 * 60
## Hora tope: pasada esta hora el reloj se detiene hasta que el detective duerma.
const DAY_LIMIT := 23 * 60 + 30
const LAST_DAY := 3

var day := 1
var minutes := DAY_START


func reset() -> void:
	day = 1
	minutes = DAY_START


func advance(amount: int) -> void:
	if amount <= 0 or minutes >= DAY_LIMIT:
		return
	minutes = mini(minutes + amount, DAY_LIMIT)
	EventBus.time_changed.emit(day, minutes)


func start_next_day() -> void:
	if day >= LAST_DAY:
		return
	day += 1
	minutes = DAY_START
	EventBus.day_changed.emit(day)
	EventBus.time_changed.emit(day, minutes)


func format_time() -> String:
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func is_at_limit() -> bool:
	return minutes >= DAY_LIMIT


## Convierte una hora "HH:MM" en minutos desde medianoche.
static func parse_time(text: String) -> int:
	var parts := text.split(":")
	return int(parts[0]) * 60 + int(parts[1])


func to_dict() -> Dictionary:
	return {"day": day, "minutes": minutes}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	minutes = int(data.get("minutes", DAY_START))
	EventBus.time_changed.emit(day, minutes)
