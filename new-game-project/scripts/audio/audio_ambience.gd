class_name AudioAmbience
extends Node
## Paisaje sonoro de un lugar: capas en bucle, emisores colocados en el escenario, detalles
## ocasionales y campanadas.
##
## - **Capas** (`layers`): bucles sin posición, como la lluvia o el murmullo del café. Al cambiar de
##   lugar, las que siguen se reajustan sin reiniciarse (la lluvia de la calle continúa de la plaza a
##   la estación), las nuevas entran con un fundido y las que sobran se apagan y se liberan.
## - **Noche** (`night_layers`): capas que sólo suenan desde la hora de la noche del catálogo.
## - **Emisores** (`emitters`): bucles 3D en la posición real del objeto (la fuente, la chimenea, el
##   reloj de pie, la locomotora). Se oyen según dónde esté el detective.
## - **Detalles** (`details`): sonidos sueltos a intervalos aleatorios, sin repetir el último, en un
##   punto al azar del área indicada. Algunos sólo de noche o de día (`hours`).
## - **Campanadas** (`chime`): al pasar una hora en punto en el lugar, tantas como marque el reloj.

signal details_played(sound_id: String)

const DEFAULT_FADE := 2.5

var catalog: AudioCatalog
var effects: AudioEffects
var bus := "Ambiente"
## Contenedor de los emisores, en el mundo 3D del juego. Se pausa con el juego.
var world_root: Node3D
var location_id := ""
## Atenuación global de los ambientes en dB.
var duck_db := 0.0
var night := false
## Si se pueden disparar detalles (se suspenden durante los diálogos).
var details_enabled := true

var _config: Dictionary = {}
var _location: Node3D
var _layers: Dictionary = {}
var _emitters: Array[AudioLoop] = []
var _retiring: Array[AudioLoop] = []
var _details_timer: Timer
var _last_detail := ""
var _chime_tween: Tween
var _duck_tween: Tween


func _ready() -> void:
	_details_timer = Timer.new()
	_details_timer.one_shot = true
	# El temporizador se detiene con la pausa: el mundo congelado no hace ruidos nuevos.
	_details_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_details_timer.timeout.connect(_on_details_timer)
	add_child(_details_timer)


## Pasa al paisaje sonoro de un lugar (o de «menu»). `location` es el nodo del escenario, para
## colocar los emisores y los detalles en sus coordenadas.
func enter(id: String, location: Node3D, fade: float = DEFAULT_FADE) -> void:
	location_id = id
	_location = location
	_config = catalog.location(id)
	stop_chimes()
	_apply_layers(fade)
	_replace_emitters(fade)
	_restart_details(true)


## Cambia entre día y noche: entran o salen las capas nocturnas.
func set_night(value: bool, fade: float = 6.0) -> void:
	if value == night:
		return
	night = value
	_apply_layers(fade)


func set_duck(value_db: float, seconds: float) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if is_equal_approx(value_db, duck_db):
		return
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck_now, duck_db, value_db, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE)


## Capas que suenan ahora mismo (sin contar las que se están apagando), por identificador.
func active_layers() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _layers:
		if (_layers[id] as AudioLoop).is_alive():
			ids.append(id)
	return ids


func active_emitters() -> int:
	var count := 0
	for loop in _emitters:
		if loop.is_alive():
			count += 1
	return count


## Reproductores de bucle vivos, incluidos los que se apagan (para comprobar que se liberan).
func live_players() -> int:
	var count := 0
	for loop in _all_loops():
		if is_instance_valid(loop.player):
			count += 1
	return count


func get_layer_player(id: String) -> AudioStreamPlayer:
	var loop: AudioLoop = _layers.get(id)
	return loop.player as AudioStreamPlayer if loop != null and loop.is_alive() else null


## Da las campanadas de una hora (`hour` de 0 a 23) si el lugar tiene reloj. Devuelve cuántas.
func chime(hour: int) -> int:
	if not _config.has("chime"):
		return 0
	var config: Dictionary = _config["chime"]
	var count := hour % 12
	if count == 0:
		count = 12
	count = mini(count, int(config.get("max", 12)))
	stop_chimes()
	_chime_tween = create_tween()
	var spacing := float(config.get("spacing", 2.0))
	for index in count:
		if index > 0:
			_chime_tween.tween_interval(spacing)
		_chime_tween.tween_callback(_strike.bind(String(config["sound"]), config.get("position", [])))
	return count


func stop_chimes() -> void:
	if _chime_tween != null and _chime_tween.is_valid():
		_chime_tween.kill()
	_chime_tween = null


func stop_now() -> void:
	stop_chimes()
	_details_timer.stop()
	for loop in _all_loops():
		loop.free_player()
	_layers.clear()
	_emitters.clear()
	_retiring.clear()


## Dispara ya un detalle del lugar (para las pruebas y el diagnóstico). Devuelve cuál sonó.
func play_detail_now() -> String:
	return _play_detail()


func _all_loops() -> Array[AudioLoop]:
	var loops: Array[AudioLoop] = []
	for loop: AudioLoop in _layers.values():
		loops.append(loop)
	loops.append_array(_emitters)
	loops.append_array(_retiring)
	return loops


func _apply_layers(fade: float) -> void:
	var wanted: Dictionary = (_config.get("layers", {}) as Dictionary).duplicate()
	if night:
		wanted.merge(_config.get("night_layers", {}), true)
	for id: String in _layers.keys():
		var loop: AudioLoop = _layers[id]
		if not wanted.has(id) or not loop.is_alive():
			if loop.is_alive():
				loop.fade_to(self, 0.0, fade, true)
				_retiring.append(loop)
			_layers.erase(id)
	for id: String in wanted:
		var level := float(catalog.ambience(id).get("volume_db", 0.0)) + float(wanted[id])
		if _layers.has(id):
			# La capa ya suena: se reajusta su nivel sin reiniciarla.
			var loop: AudioLoop = _layers[id]
			_retarget(loop, level, fade)
			continue
		var player := AudioStreamPlayer.new()
		player.name = "Capa_%s" % id
		player.bus = bus
		player.stream = catalog.loop_stream(String(catalog.ambience(id).get("file", "")))
		if player.stream == null:
			player.free()
			continue
		add_child(player)
		var created := AudioLoop.new(id, player, level)
		created.extra_db = duck_db
		created.apply()
		# Empieza en un punto al azar para que dos visitas seguidas no suenen idénticas.
		player.play(randf() * maxf(player.stream.get_length() - 1.0, 0.0))
		created.fade_to(self, 1.0, fade)
		_layers[id] = created
	_prune_retiring()


## Cambia el nivel propio de una capa con un fundido, sin tocar su reproducción.
func _retarget(loop: AudioLoop, level: float, fade: float) -> void:
	if is_equal_approx(loop.base_db, level):
		loop.fade_to(self, 1.0, fade)
		return
	# El cambio se expresa como ganancia para reutilizar la curva del fundido: el volumen no salta y
	# llega al nivel nuevo cuando la ganancia vuelve a 1.
	loop.gain = loop.gain / maxf(db_to_linear(level - loop.base_db), AudioLoop.SILENCE)
	loop.base_db = level
	loop.apply()
	loop.fade_to(self, 1.0, fade)


func _replace_emitters(fade: float) -> void:
	for loop in _emitters:
		loop.fade_to(self, 0.0, fade, true)
		_retiring.append(loop)
	_emitters.clear()
	if world_root == null or not world_root.is_inside_tree():
		return
	for emitter: Dictionary in _config.get("emitters", []):
		var entry := catalog.ambience(String(emitter["ambience"]))
		var stream := catalog.loop_stream(String(entry.get("file", "")))
		if stream == null:
			continue
		var player := AudioStreamPlayer3D.new()
		player.name = "Emisor_%s" % emitter["ambience"]
		player.bus = bus
		player.stream = stream
		player.unit_size = float(emitter.get("unit_size", entry.get("unit_size", 6.0)))
		player.max_distance = float(emitter.get("max_distance", entry.get("max_distance", 30.0)))
		player.attenuation_filter_cutoff_hz = float(entry.get("filter_hz", 5000.0))
		world_root.add_child(player)
		player.global_position = _to_world(emitter["position"])
		var level := float(entry.get("volume_db", 0.0)) + float(emitter.get("volume_db", 0.0))
		var loop := AudioLoop.new(String(emitter["ambience"]), player, level)
		loop.extra_db = duck_db
		loop.apply()
		player.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
		loop.fade_to(self, 1.0, fade)
		_emitters.append(loop)
	_prune_retiring()


func _prune_retiring() -> void:
	var alive: Array[AudioLoop] = []
	for loop in _retiring:
		if is_instance_valid(loop.player):
			alive.append(loop)
	_retiring = alive


func _set_duck_now(value: float) -> void:
	duck_db = value
	for loop in _all_loops():
		loop.extra_db = value
		loop.apply()


func _to_world(position: Array) -> Vector3:
	var local := Vector3(float(position[0]), float(position[1]), float(position[2]))
	if _location != null and is_instance_valid(_location) and _location.is_inside_tree():
		return _location.to_global(local)
	return local


# --- Detalles ocasionales ---

func _restart_details(first: bool) -> void:
	_details_timer.stop()
	var details: Dictionary = _config.get("details", {})
	if details.is_empty():
		return
	var every: Array = details.get("every", [12, 30])
	var wait := randf_range(float(every[0]), float(every[1]))
	# Al llegar, el primer detalle tarda menos: el lugar se presenta enseguida.
	_details_timer.start(wait * (0.45 if first else 1.0))


func _on_details_timer() -> void:
	if details_enabled:
		_play_detail()
	_restart_details(false)


func _play_detail() -> String:
	var details: Dictionary = _config.get("details", {})
	var options: Array[String] = []
	var weights: Array[float] = []
	var minutes := GameClock.minutes
	for sound_id: String in details.get("sounds", {}):
		var rule: Variant = details["sounds"][sound_id]
		var weight := float(rule) if not rule is Dictionary else float((rule as Dictionary).get("weight", 1.0))
		if rule is Dictionary and (rule as Dictionary).has("hours") and not _in_hours((rule as Dictionary)["hours"], minutes):
			continue
		if sound_id == _last_detail and details["sounds"].size() > 1:
			weight *= 0.15
		options.append(sound_id)
		weights.append(weight)
	if options.is_empty():
		return ""
	var chosen := options[_weighted_index(weights)]
	var area: Array = details.get("area", [])
	var played := false
	if area.size() == 4:
		var local := [randf_range(float(area[0]), float(area[0]) + float(area[2])), float(details.get("height", 1.6)),
			randf_range(float(area[1]), float(area[1]) + float(area[3]))]
		played = effects.play(chosen, {"position": _to_world(local)})
	else:
		played = effects.play(chosen)
	if played:
		_last_detail = chosen
		details_played.emit(chosen)
	return chosen if played else ""


static func _in_hours(hours: Array, minutes: int) -> bool:
	var start := GameClock.parse_time(String(hours[0]))
	var finish := GameClock.parse_time(String(hours[1]))
	if start <= finish:
		return minutes >= start and minutes <= finish
	return minutes >= start or minutes <= finish


static func _weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	var pick := randf() * total
	for index in weights.size():
		pick -= weights[index]
		if pick <= 0.0:
			return index
	return weights.size() - 1


func _strike(sound_id: String, position: Array) -> void:
	if position.size() == 3:
		effects.play(sound_id, {"position": _to_world(position), "force": true})
	else:
		effects.play(sound_id, {"force": true})
