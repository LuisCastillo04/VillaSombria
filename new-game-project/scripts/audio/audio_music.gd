class_name AudioMusic
extends Node
## Música adaptativa: una pista por momento del juego, con su capa de tensión sincronizada.
##
## - **Cambio de pista:** fundido cruzado. Pedir la pista que ya suena no la reinicia.
## - **Intensidad (0 a 1):** cada pista puede tener una capa de tensión de la misma duración exacta;
##   las dos suenan juntas en un `AudioStreamSynchronized` y la intensidad sólo sube o baja el volumen
##   de esa capa, así que la tensión crece o se disuelve sin cortar la música.
## - **Atenuación:** los diálogos, la pausa o un fragmento musical bajan la música sin pararla.
## - **Silencios intencionados:** en las pistas tranquilas, tras unos minutos la música se retira un
##   rato y deja solo el ambiente; vuelve después. Se suspenden si sube la tensión.

signal track_changed(track_id: String)

## Por debajo de esta intensidad la capa de tensión está callada.
const TENSION_FLOOR := 0.02
const REST_FADE_OUT := 9.0
const REST_FADE_IN := 7.0
## Intensidad a partir de la cual no hay silencios intencionados.
const REST_MAX_INTENSITY := 0.45

var catalog: AudioCatalog
var bus := "Musica"
## Pista que suena (vacío: silencio).
var track_id := ""
## Intensidad aplicada ahora mismo (avanza hacia la pedida con un fundido).
var intensity := 0.0
## Atenuación global de la música en dB (diálogo, pausa...).
var duck_db := 0.0
## La música está retirada por un silencio intencionado.
var resting := false

var _current: AudioLoop
var _loops: Array[AudioLoop] = []
var _stinger_db := 0.0
var _rest_scale := 1.0
var _rest_timer: Timer
var _rest_config: Dictionary = {}
var _intensity_tween: Tween
var _duck_tween: Tween
var _stinger_tween: Tween
var _rest_tween: Tween


func _ready() -> void:
	_rest_timer = Timer.new()
	_rest_timer.one_shot = true
	_rest_timer.timeout.connect(_on_rest_timer)
	add_child(_rest_timer)


## Cambia de pista con un fundido cruzado. Devuelve si hubo cambio.
func play(id: String, fade: float) -> bool:
	if id == track_id:
		return false
	track_id = id
	if _current != null:
		_current.fade_to(self, 0.0, fade, true)
	_current = null
	_set_resting(false, 0.0)
	var entry := catalog.music(id) if not id.is_empty() else {}
	if not entry.is_empty():
		var stream := _build_stream(entry)
		if stream != null:
			var player := AudioStreamPlayer.new()
			player.name = "Pista_%s" % id
			player.bus = bus
			player.stream = stream
			add_child(player)
			_current = AudioLoop.new(id, player, float(entry.get("volume_db", 0.0)))
			_loops.append(_current)
			_apply_intensity(_current)
			_refresh(_current)
			player.play()
			_current.fade_to(self, 1.0, fade)
	_prune()
	_restart_rest_timer()
	track_changed.emit(id)
	return true


## Lleva la intensidad a `value` (0 a 1) en `seconds`.
func set_intensity(value: float, seconds: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if _intensity_tween != null and _intensity_tween.is_valid():
		_intensity_tween.kill()
	if is_equal_approx(value, intensity):
		return
	if seconds <= 0.0:
		_set_intensity_now(value)
	else:
		_intensity_tween = create_tween()
		_intensity_tween.tween_method(_set_intensity_now, intensity, value, seconds).set_trans(Tween.TRANS_SINE)
	if value >= REST_MAX_INTENSITY and resting:
		_set_resting(false, REST_FADE_IN * 0.5)


## Atenuación global (dB, 0 = ninguna) con un fundido.
func set_duck(value_db: float, seconds: float) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if is_equal_approx(value_db, duck_db):
		return
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck_now, duck_db, value_db, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE)


## Baja la música mientras suena un fragmento musical y la devuelve después.
func duck_for_stinger(value_db: float, hold: float) -> void:
	if _stinger_tween != null and _stinger_tween.is_valid():
		_stinger_tween.kill()
	_stinger_tween = create_tween()
	_stinger_tween.tween_method(_set_stinger_now, _stinger_db, value_db, 0.35)
	_stinger_tween.tween_interval(hold)
	_stinger_tween.tween_method(_set_stinger_now, value_db, 0.0, 2.5).set_trans(Tween.TRANS_SINE)


## Configura los silencios intencionados: `{"after": [mín, máx], "silence": [mín, máx]}` en segundos.
func configure_rests(config: Dictionary) -> void:
	_rest_config = config
	_restart_rest_timer()


## Volumen efectivo de la pista actual (para el diagnóstico): dB de su reproductor.
func get_current_volume_db() -> float:
	if _current == null or not is_instance_valid(_current.player):
		return -80.0
	return float(_current.player.get("volume_db"))


func get_current_player() -> AudioStreamPlayer:
	return _current.player as AudioStreamPlayer if _current != null else null


## Volumen en dB de la capa de tensión de la pista actual, o -80 si no tiene.
func get_tension_db() -> float:
	if _current == null or not is_instance_valid(_current.player):
		return -80.0
	var stream: Variant = _current.player.get("stream")
	if stream is AudioStreamSynchronized and (stream as AudioStreamSynchronized).stream_count > 1:
		return (stream as AudioStreamSynchronized).get_sync_stream_volume(1)
	return -80.0


func active_players() -> int:
	_prune()
	return _loops.size()


func stop_now() -> void:
	for loop in _loops:
		loop.free_player()
	_loops.clear()
	_current = null
	track_id = ""


func _build_stream(entry: Dictionary) -> AudioStream:
	var base := catalog.loop_stream(String(entry.get("base", "")))
	if base == null:
		return null
	if not entry.has("tension"):
		return base
	var tension := catalog.loop_stream(String(entry["tension"]))
	if tension == null:
		return base
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = 2
	sync.set_sync_stream(0, base)
	sync.set_sync_stream(1, tension)
	sync.set_sync_stream_volume(1, -80.0)
	return sync


func _set_intensity_now(value: float) -> void:
	intensity = value
	if _current != null:
		_apply_intensity(_current)


## La capa de tensión sigue una curva (intensidad^1,5): poco presente al principio y plena al
## final. La base cede un poco cuando la tensión domina.
func _apply_intensity(loop: AudioLoop) -> void:
	if not is_instance_valid(loop.player):
		return
	var stream: Variant = loop.player.get("stream")
	if not stream is AudioStreamSynchronized:
		return
	var sync := stream as AudioStreamSynchronized
	var tension_db := -80.0 if intensity < TENSION_FLOOR else linear_to_db(pow(intensity, 1.5))
	sync.set_sync_stream_volume(1, tension_db)
	sync.set_sync_stream_volume(0, -2.5 * intensity)


func _set_duck_now(value: float) -> void:
	duck_db = value
	_refresh_all()


func _set_stinger_now(value: float) -> void:
	_stinger_db = value
	_refresh_all()


func _set_rest_scale(value: float) -> void:
	_rest_scale = value
	_refresh_all()


func _refresh_all() -> void:
	for loop in _loops:
		_refresh(loop)


## La pista que sale conserva su escala: si se cambia de pista durante un silencio, sigue callada.
func _refresh(loop: AudioLoop) -> void:
	loop.extra_db = duck_db + _stinger_db
	if loop == _current:
		loop.scale = _rest_scale
	loop.apply()


func _prune() -> void:
	var alive: Array[AudioLoop] = []
	for loop in _loops:
		if is_instance_valid(loop.player):
			alive.append(loop)
	_loops = alive


# --- Silencios intencionados ---

func _restart_rest_timer() -> void:
	if _rest_timer == null:
		return
	_rest_timer.stop()
	if _current == null or _rest_config.is_empty() or not catalog.music(track_id).get("rests", false):
		return
	var after: Array = _rest_config.get("after", [180, 240])
	_rest_timer.start(randf_range(float(after[0]), float(after[1])))


func _on_rest_timer() -> void:
	if _current == null:
		return
	if resting:
		_set_resting(false, REST_FADE_IN)
		_restart_rest_timer()
	elif intensity < REST_MAX_INTENSITY:
		_set_resting(true, REST_FADE_OUT)
		var silence: Array = _rest_config.get("silence", [40, 70])
		_rest_timer.start(randf_range(float(silence[0]), float(silence[1])))
	else:
		_restart_rest_timer()


func _set_resting(value: bool, seconds: float) -> void:
	resting = value
	if _rest_tween != null and _rest_tween.is_valid():
		_rest_tween.kill()
	var target := 0.0 if value else 1.0
	if seconds <= 0.0:
		_set_rest_scale(target)
		return
	_rest_tween = create_tween()
	_rest_tween.tween_method(_set_rest_scale, _rest_scale, target, seconds).set_trans(Tween.TRANS_SINE)
