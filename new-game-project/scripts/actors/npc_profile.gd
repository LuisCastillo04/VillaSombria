class_name NpcProfile
extends RefCounted
## Parámetros del comportamiento ambiental de un NPC. El carácter de cada personaje está en
## `characters.json` (bloque «ambient») y cada tramo de `schedules.json` puede ajustarlo según lo
## que esté haciendo («behavior», «radius», «patrol», «visits»...). Ver docs/NPC.md.

enum Mode {
	## Se queda en su puesto: sólo pausas, miradas y giros.
	STAY,
	## Da paseos cortos alrededor de su puesto y, a veces, visita puntos concretos.
	WANDER,
	## Recorre en bucle los puntos de su ronda, parándose en cada uno.
	PATROL,
}

const MODE_NAMES := {"stay": Mode.STAY, "wander": Mode.WANDER, "patrol": Mode.PATROL}

## Valores de partida según el papel del personaje en la historia.
const ROLES := {
	## Imprescindible para la investigación: no se aleja de su puesto.
	"importante": {"mode": "stay", "radius": 1.0, "wander_chance": 0.3},
	## Puede moverse un poco por su zona.
	"secundario": {"mode": "wander", "radius": 1.6, "wander_chance": 0.55},
	## Hace una ronda corta y vigila a su alrededor.
	"vigilancia": {"mode": "patrol", "radius": 1.2, "wander_chance": 0.3, "glance": [1.5, 3.5]},
}

const DEFAULTS := {
	"role": "secundario",
	## Metros por segundo al caminar (el detective anda a 4).
	"speed": 1.2,
	## Segundos de pausa entre un movimiento y el siguiente.
	"pause": [4.0, 9.0],
	## Segundos entre miradas y cambios de orientación mientras está quieto.
	"glance": [2.0, 5.0],
	## Probabilidad de dar un paseo corto al terminar cada pausa (modo «wander»).
	"wander_chance": 0.5,
	## Probabilidad de ir a uno de sus puntos de visita al terminar cada pausa.
	"visit_chance": 0.0,
	## Segundos que se queda mirando al detective que lo enfoca sin hablarle.
	"attend_seconds": 5.0,
	## Pausa tras una conversación antes de retomar lo que hacía.
	"talk_pause": [2.5, 4.5],
	## Inclinación de la cabeza en reposo: negativa mira al suelo.
	"head_tilt": 0.0,
	## Distancia a la que se fija en el detective.
	"notice_distance": 3.5,
}

var role := "secundario"
var mode := Mode.STAY
var wander_radius := 1.0
var walk_speed := 1.2
var pause_range := Vector2(4.0, 9.0)
var glance_range := Vector2(2.0, 5.0)
var wander_chance := 0.5
var visit_chance := 0.0
var attend_seconds := 5.0
var talk_pause_range := Vector2(2.5, 4.5)
var head_tilt := 0.0
var notice_distance := 3.5


## Perfil de un personaje para un tramo de su rutina. Prioridad: tramo > personaje > papel.
static func build(ambient: Dictionary, slot: Dictionary = {}) -> NpcProfile:
	var values := DEFAULTS.duplicate()
	values.merge(ROLES.get(String(ambient.get("role", values["role"])), {}), true)
	values.merge(ambient, true)
	if slot.has("patrol"):
		values["mode"] = "patrol"
	for key: String in ["behavior", "radius", "speed", "pause", "wander_chance", "visit_chance"]:
		if slot.has(key):
			values["mode" if key == "behavior" else key] = slot[key]
	var profile := NpcProfile.new()
	profile.role = String(values["role"])
	profile.mode = MODE_NAMES.get(String(values["mode"]), Mode.STAY)
	profile.wander_radius = float(values["radius"])
	profile.walk_speed = float(values["speed"])
	profile.pause_range = _range(values["pause"])
	profile.glance_range = _range(values["glance"])
	profile.wander_chance = float(values["wander_chance"])
	profile.visit_chance = float(values["visit_chance"])
	profile.attend_seconds = float(values["attend_seconds"])
	profile.talk_pause_range = _range(values["talk_pause"])
	profile.head_tilt = float(values["head_tilt"])
	profile.notice_distance = float(values["notice_distance"])
	return profile


## Indica si un nombre de modo de los datos es válido.
static func is_mode(mode_name: String) -> bool:
	return MODE_NAMES.has(mode_name)


func random_pause(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(pause_range.x, pause_range.y)


func random_glance(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(glance_range.x, glance_range.y)


func random_talk_pause(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(talk_pause_range.x, talk_pause_range.y)


static func _range(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(float(value), float(value))
