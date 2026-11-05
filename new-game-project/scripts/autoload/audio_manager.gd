extends Node
## Sonido procedural. Todo se sintetiza al arrancar, de modo que el juego no depende de
## archivos de audio. Para usar música propia basta con sustituir el stream de `_music`.

const RATE := 22050
const MUSIC_RATE := 11025
const MUSIC_SECONDS := 16.0

var _sounds: Dictionary = {}
var _rain: AudioStreamPlayer
var _music: AudioStreamPlayer
var _effects: Array[AudioStreamPlayer] = []
var _next_effect := 0
var _ready_to_play := false


func _ready() -> void:
	# Sin dispositivo de audio real (pruebas) no hay nada que sintetizar.
	if DisplayServer.get_name() == "headless":
		return
	for index in 6:
		var player := AudioStreamPlayer.new()
		player.bus = "Efectos"
		add_child(player)
		_effects.append(player)
	_rain = AudioStreamPlayer.new()
	_rain.bus = "Ambiente"
	add_child(_rain)
	_music = AudioStreamPlayer.new()
	_music.bus = "Musica"
	add_child(_music)
	_sounds["click"] = _make_click()
	_sounds["tecla"] = _make_key()
	_sounds["pista"] = _make_chime()
	_rain.stream = _make_rain()
	_music.stream = _make_drone()
	_ready_to_play = true
	EventBus.clue_discovered.connect(_on_discovery)
	EventBus.deduction_made.connect(_on_discovery)
	_music.play()


## Los bucles siguen sonando hasta el último fotograma: hay que soltarlos al salir.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in [_rain, _music]:
		if player != null:
			player.stop()
			player.stream = null


func play(sound_id: String) -> void:
	if not _ready_to_play or not _sounds.has(sound_id):
		return
	var player := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	player.stream = _sounds[sound_id]
	player.play()


## La lluvia suena fuerte en la calle y amortiguada dentro de los edificios.
func set_rain(outdoor: bool) -> void:
	if not _ready_to_play:
		return
	if not _rain.playing:
		_rain.play()
	_rain.volume_db = -4.0 if outdoor else -20.0


func _on_discovery(_id: String) -> void:
	play("pista")


func _to_stream(samples: PackedFloat32Array, rate: int, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		bytes.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	return stream


func _make_click() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 0.05))
	for index in samples.size():
		var time := float(index) / RATE
		samples[index] = sin(TAU * 520.0 * time) * exp(-time * 90.0) * 0.5
	return _to_stream(samples, RATE, false)


func _make_key() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 0.03))
	for index in samples.size():
		var time := float(index) / RATE
		samples[index] = randf_range(-1.0, 1.0) * exp(-time * 220.0) * 0.22
	return _to_stream(samples, RATE, false)


func _make_chime() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 0.9))
	for index in samples.size():
		var time := float(index) / RATE
		var first := sin(TAU * 440.0 * time) * exp(-time * 5.0)
		var second := 0.0
		if time > 0.14:
			second = sin(TAU * 659.25 * (time - 0.14)) * exp(-(time - 0.14) * 5.0)
		samples[index] = (first + second) * 0.26
	return _to_stream(samples, RATE, false)


## Ruido filtrado de duración fija, con los extremos fundidos para que el bucle no se note.
func _make_rain() -> AudioStreamWAV:
	var count := int(RATE * 3.0)
	var fade := int(RATE * 0.25)
	var noise := PackedFloat32Array()
	noise.resize(count + fade)
	var state := 0.0
	for index in noise.size():
		state += (randf_range(-1.0, 1.0) - state) * 0.35
		noise[index] = state
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index in count:
		var value := noise[index]
		if index < fade:
			var mix := float(index) / float(fade)
			value = noise[index + count] * (1.0 - mix) + value * mix
		samples[index] = value * 0.7
	return _to_stream(samples, RATE, true)


## Dron grave en la menor con un latido lento. Se repite sin saltos porque cada parcial
## completa un número entero de ciclos dentro del bucle.
func _make_drone() -> AudioStreamWAV:
	var count := int(MUSIC_RATE * MUSIC_SECONDS)
	var partials: Array[Vector2] = [Vector2(55.0, 0.34), Vector2(110.0, 0.2), Vector2(130.8125, 0.11), Vector2(164.8125, 0.09)]
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index in count:
		var time := float(index) / MUSIC_RATE
		var swell := 0.6 + 0.4 * sin(TAU * time / MUSIC_SECONDS * 2.0)
		var value := 0.0
		for partial in partials:
			value += sin(TAU * partial.x * time) * partial.y
		samples[index] = value * swell * 0.55
	return _to_stream(samples, MUSIC_RATE, true)
