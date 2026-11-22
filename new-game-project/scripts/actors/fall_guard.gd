class_name FallGuard
extends Node
## Red de seguridad contra caídas para el CharacterBody3D padre (el detective o un NPC). Recuerda
## la última posición en la que pisaba suelo válido y, si el cuerpo cae por debajo del escenario o
## sale de su área transitable, lo devuelve allí parado. No sustituye a las colisiones: es la
## última defensa si alguna falla.

## Se emite tras devolver el cuerpo a un punto seguro.
signal recovered(from: Vector3, to: Vector3)

## Metros por debajo del suelo a partir de los cuales el cuerpo se da por caído.
const FALL_DEPTH := 2.0
## Margen fuera del área transitable antes de intervenir: el umbral de una puerta no cuenta.
const AREA_MARGIN := 0.75
## Diferencia de altura con el suelo que aún se considera «pisar suelo».
const GROUND_TOLERANCE := 0.5
## Segundos seguidos sobre suelo válido antes de recordar la posición: así no se guarda un punto
## en el que sólo se estaba resbalando.
const SETTLE_SECONDS := 0.2
## Pausa tras un rescate antes de volver a vigilar, para que la física se asiente.
const COOLDOWN_SECONDS := 0.25
## Más rescates que estos en LOOP_WINDOW segundos significan que el punto seguro no lo es: se
## descarta y se usa el de reserva. Así no hay bucles de rescate.
const LOOP_LIMIT := 3
const LOOP_WINDOW := 5.0

## Escenario actual: aporta el área transitable. Sin escenario sólo se vigila la altura.
var location: LocationBase
## Punto de reserva: la entrada del escenario para el detective, su puesto para un NPC.
var fallback := Vector3.ZERO
## Rescates hechos desde que se creó; útil para pruebas y diagnóstico.
var recoveries := 0

var _body: CharacterBody3D
var _safe := Vector3.ZERO
var _has_safe := false
var _settled := 0.0
var _cooldown := 0.0
var _clock := 0.0
var _recent: Array[float] = []


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_error("FallGuard debe ser hijo de un CharacterBody3D.")
		set_physics_process(false)


## El cuerpo se ha colocado a propósito (aparición, carga, cambio de escenario): ese punto pasa a
## ser el seguro y se olvida el historial de rescates.
func reset(where: Vector3) -> void:
	_safe = where
	_has_safe = true
	_settled = 0.0
	_cooldown = 0.0
	_recent.clear()


## Última posición segura conocida, o la de reserva si no hay ninguna.
func get_safe_position() -> Vector3:
	return _safe if _has_safe else fallback


## Posición que se puede guardar en una partida: la actual si pisa suelo válido y, si no (en
## plena caída, por ejemplo), la última segura.
func get_savable_position() -> Vector3:
	if _body != null and _body.is_on_floor() and _is_valid_ground(_body.global_position):
		return _body.global_position
	return get_safe_position()


## Indica si el cuerpo está ahora mismo fuera de lo permitido.
func is_lost() -> bool:
	return _body != null and _is_lost(_body.global_position)


func _physics_process(delta: float) -> void:
	_clock += delta
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	var where := _body.global_position
	if _is_lost(where):
		_recover()
		return
	if _body.is_on_floor() and _is_valid_ground(where):
		_settled += delta
		if _settled >= SETTLE_SECONDS:
			_safe = where
			_has_safe = true
	else:
		_settled = 0.0


func _is_lost(where: Vector3) -> bool:
	if where.y < LocationBase.FLOOR_HEIGHT - FALL_DEPTH:
		return true
	return location != null and not location.is_inside_play_area(where, AREA_MARGIN)


func _is_valid_ground(where: Vector3) -> bool:
	if absf(where.y - LocationBase.FLOOR_HEIGHT) > GROUND_TOLERANCE:
		return false
	return location == null or location.is_inside_play_area(where)


func _recover() -> void:
	var from := _body.global_position
	var still_recent: Array[float] = []
	for moment in _recent:
		if _clock - moment < LOOP_WINDOW:
			still_recent.append(moment)
	_recent = still_recent
	_recent.append(_clock)
	if _recent.size() > LOOP_LIMIT and _has_safe:
		push_warning("FallGuard: el punto seguro %s no lo es; se usa el de reserva." % str(_safe))
		_has_safe = false
	var target := get_safe_position()
	_body.global_position = target + Vector3.UP * 0.05
	_body.velocity = Vector3.ZERO
	_settled = 0.0
	_cooldown = COOLDOWN_SECONDS
	recoveries += 1
	recovered.emit(from, target)
