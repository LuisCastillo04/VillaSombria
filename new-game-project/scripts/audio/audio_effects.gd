class_name AudioEffects
extends Node
## Efectos puntuales: interfaz, interacciones, fragmentos musicales y detalles de ambiente.
##
## Un grupo fijo de reproductores evita crear nodos en cada sonido. Cada efecto del catálogo decide
## su canal, su volumen, la variación de tono, el tiempo mínimo entre dos disparos (`cooldown`), cuántas
## copias pueden sonar a la vez (`max`) y su prioridad: si no queda ningún reproductor libre, se
## interrumpe el más antiguo de menor prioridad, nunca uno más importante. Entre las variantes de un
## efecto nunca se repite la misma dos veces seguidas.
##
## Los efectos con `spatial` se colocan en el mundo con un `AudioStreamPlayer3D` temporal que se
## libera al terminar; si no hay posición, suenan sin colocar.

signal played(id: String, entry: Dictionary)

const VOICES := 12
const MAX_SPATIAL := 8
const HISTORY_SIZE := 32

var catalog: AudioCatalog
## Dónde se crean los efectos 3D (en el mismo mundo que el escenario y el oyente).
var spatial_root: Node3D
## Últimos efectos que sonaron, para el diagnóstico y las pruebas.
var history: Array[String] = []

var _voices: Array[AudioStreamPlayer] = []
var _voice_id: Array[String] = []
var _voice_priority: Array[int] = []
var _voice_started: Array[int] = []
var _last_played: Dictionary = {}
var _last_variant: Dictionary = {}


func _ready() -> void:
	for index in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voz%d" % index
		add_child(player)
		_voices.append(player)
		_voice_id.append("")
		_voice_priority.append(0)
		_voice_started.append(0)


## Reproduce un efecto. Opciones: `position` (Vector3 global, para los espaciales), `volume_db`
## (ajuste extra) y `force` (ignora el tiempo de espera). Devuelve si llegó a sonar.
func play(id: String, options: Dictionary = {}) -> bool:
	if catalog == null:
		return false
	var entry := catalog.sound(id)
	if entry.is_empty():
		push_warning("Efecto de sonido desconocido: %s" % id)
		return false
	var key := _resolved_id(id)
	var now := Time.get_ticks_msec()
	var cooldown := int(float(entry.get("cooldown", 0.0)) * 1000.0)
	if not options.get("force", false) and _last_played.has(key) and now - int(_last_played[key]) < cooldown:
		return false
	if count_playing(key) >= int(entry.get("max", 3)):
		return false
	var stream := _pick_variant(key, entry)
	if stream == null:
		return false
	var volume := float(entry.get("volume_db", 0.0)) + float(options.get("volume_db", 0.0))
	var pitch_range: Array = entry.get("pitch", [1.0, 1.0])
	var pitch := randf_range(float(pitch_range[0]), float(pitch_range[1]))
	var bus := String(entry.get("bus", "Efectos"))
	var sounded := false
	if entry.get("spatial", false) and options.has("position") and spatial_root != null and spatial_root.is_inside_tree():
		sounded = _play_spatial(key, stream, entry, options["position"], volume, pitch, bus)
	else:
		sounded = _play_flat(key, stream, int(entry.get("priority", 1)), volume, pitch, bus)
	if sounded:
		_last_played[key] = now
		history.append(key)
		if history.size() > HISTORY_SIZE:
			history.pop_front()
		played.emit(key, entry)
	return sounded


## Copias de un efecto sonando ahora mismo.
func count_playing(id: String) -> int:
	var count := 0
	for index in _voices.size():
		if _voice_id[index] == id and _voices[index].playing:
			count += 1
	if spatial_root != null:
		for child in spatial_root.get_children():
			if child is AudioStreamPlayer3D and child.has_meta("efecto") and child.get_meta("efecto") == id:
				count += 1
	return count


func playing_voices() -> int:
	var count := 0
	for player in _voices:
		if player.playing:
			count += 1
	return count


## Detiene los efectos de un canal (por ejemplo, los detalles del lugar que se abandona).
func stop_bus(bus: String) -> void:
	for index in _voices.size():
		if _voices[index].bus == bus:
			_voices[index].stop()
	if spatial_root != null:
		for child in spatial_root.get_children():
			if child is AudioStreamPlayer3D and child.bus == bus:
				child.queue_free()


func stop_all() -> void:
	_last_played.clear()
	for player in _voices:
		player.stop()
		player.stream = null
	if spatial_root != null:
		for child in spatial_root.get_children():
			child.queue_free()


func _resolved_id(id: String) -> String:
	var current := id
	for _step in 4:
		var entry: Dictionary = catalog.section("sounds").get(current, {})
		if not entry.has("alias"):
			return current
		current = entry["alias"]
	return current


func _pick_variant(id: String, entry: Dictionary) -> AudioStream:
	var files: Array = entry.get("files", [])
	if files.is_empty():
		return null
	var index := randi() % files.size()
	if files.size() > 1 and index == int(_last_variant.get(id, -1)):
		index = (index + 1 + randi() % (files.size() - 1)) % files.size()
	_last_variant[id] = index
	return catalog.effect_stream(String(files[index]))


func _play_flat(id: String, stream: AudioStream, priority: int, volume: float, pitch: float, bus: String) -> bool:
	var chosen := -1
	for index in _voices.size():
		if not _voices[index].playing:
			chosen = index
			break
	if chosen == -1:
		# Sin voces libres: se sacrifica la más antigua de las de menor prioridad.
		var lowest := priority
		var oldest := Time.get_ticks_msec() + 1
		for index in _voices.size():
			var candidate := _voice_priority[index]
			if candidate < lowest or (candidate == lowest and _voice_started[index] < oldest):
				lowest = candidate
				oldest = _voice_started[index]
				chosen = index
		if chosen == -1:
			return false
	var player := _voices[chosen]
	player.stop()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()
	_voice_id[chosen] = id
	_voice_priority[chosen] = priority
	_voice_started[chosen] = Time.get_ticks_msec()
	return true


func _play_spatial(id: String, stream: AudioStream, entry: Dictionary, where: Vector3, volume: float, pitch: float, bus: String) -> bool:
	var active := 0
	for child in spatial_root.get_children():
		if child is AudioStreamPlayer3D and child.has_meta("efecto"):
			active += 1
	if active >= MAX_SPATIAL:
		return false
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume
	player.pitch_scale = pitch
	player.unit_size = float(entry.get("unit_size", 8.0))
	player.max_distance = float(entry.get("max_distance", 40.0))
	player.attenuation_filter_cutoff_hz = float(entry.get("filter_hz", 6000.0))
	player.set_meta("efecto", id)
	spatial_root.add_child(player)
	player.global_position = where
	player.finished.connect(player.queue_free)
	player.play()
	return true
