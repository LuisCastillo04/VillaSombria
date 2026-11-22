extends Node
## Sonido adaptativo de Villa Sombría: coordina la música, los ambientes y los efectos y los hace
## reaccionar al lugar, a la historia y a lo que hace el jugador. Lo que suena en cada caso lo
## describe `data/audio.json` (ver `AudioCatalog` y docs/AUDIO.md); aquí sólo se decide cuándo.
##
## Piezas:
## - `AudioMusic`: pista del momento con su capa de tensión sincronizada, fundidos y silencios.
## - `AudioAmbience`: capas, emisores 3D, detalles ocasionales y campanadas de cada lugar.
## - `AudioEffects`: efectos puntuales (interfaz, interacciones, fragmentos y detalles).
## - `AudioMood`: la tensión que pide la historia, deducida del estado de la partida.
##
## Escucha `EventBus`, `DialogueManager`, `SaveSystem` y los bloqueos del jugador, de modo que el resto
## del juego no tiene que avisar de casi nada. Las llamadas explícitas son pocas: `enter_location`
## (lo hace la escena de juego al cambiar de escenario), `attach_listener` y `play`.
##
## Canales: `Musica`, `Ambiente` y `Efectos` envían a `Master`, y sus volúmenes son los de
## Configuración (`Settings`). Este autoload nunca toca esos volúmenes: atenúa con los reproductores
## y, en la pausa, apaga los agudos de la música y del ambiente con un filtro en su canal.

signal state_changed

const MUSIC_BUS := "Musica"
const AMBIENCE_BUS := "Ambiente"
const EFFECTS_BUS := "Efectos"
## Canales que se amortiguan (filtro de paso bajo) mientras el juego está en pausa.
const MUFFLED_BUSES: Array[String] = [MUSIC_BUS, AMBIENCE_BUS]
const MUFFLE_CUTOFF_HZ := 850.0
const OPEN_CUTOFF_HZ := 20500.0
## Espera antes de decidir la música de un lugar nuevo: da tiempo a que empiece la escena que
## dispara la llegada (la llamada del café, la introducción) sin que asome la pista del lugar.
const LOCATION_MUSIC_DELAY := 1.0
## Ventana en la que un cambio de foco cuenta como navegación del jugador (y suena).
const NAVIGATION_WINDOW_MS := 250
const NAVIGATION_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

var catalog: AudioCatalog
var music: AudioMusic
var ambience: AudioAmbience
var effects: AudioEffects
## Lugar cuyo paisaje sonoro suena («menu» en el menú principal).
var location_id := ""
## La música y el ambiente están amortiguados (pausa).
var muffled := false

var _world: Node3D
var _listener: AudioListener3D
var _locks: Dictionary = {}
var _boost := 0.0
var _boost_timer: Timer
var _music_timer: Timer
var _override := ""
var _last_time := Vector2i(-1, -1)
var _manual_saves: Dictionary = {}
var _last_navigation := -100000
var _lowpass: Array[AudioEffectLowPassFilter] = []
var _muffle_tween: Tween
var _pending_chime: Tween


func _ready() -> void:
	# La interfaz suena también en pausa, y los fundidos no se congelan con el juego.
	process_mode = Node.PROCESS_MODE_ALWAYS
	catalog = AudioCatalog.load_file()
	_setup_buses()
	_world = Node3D.new()
	_world.name = "Mundo"
	# Los sonidos colocados en el escenario se congelan con él.
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	effects = AudioEffects.new()
	effects.name = "Efectos"
	effects.catalog = catalog
	effects.spatial_root = _world
	add_child(effects)
	music = AudioMusic.new()
	music.name = "Musica"
	music.catalog = catalog
	music.bus = MUSIC_BUS
	add_child(music)
	music.configure_rests(catalog.section("rests"))
	ambience = AudioAmbience.new()
	ambience.name = "Ambiente"
	ambience.catalog = catalog
	ambience.effects = effects
	ambience.world_root = _world
	ambience.bus = AMBIENCE_BUS
	add_child(ambience)
	_music_timer = _make_timer(_apply_music.bind(true))
	_boost_timer = _make_timer(_on_boost_finished)
	effects.played.connect(_on_effect_played)
	_connect_game()


## Los bucles siguen sonando hasta el último fotograma: hay que soltarlos al salir.
func _exit_tree() -> void:
	if music != null:
		music.stop_now()
	if ambience != null:
		ambience.stop_now()
	if effects != null:
		effects.stop_all()
	if catalog != null:
		catalog.clear_cache()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > 1.5:
			_last_navigation = Time.get_ticks_msec()
		return
	if not event.is_pressed():
		return
	for action in NAVIGATION_ACTIONS:
		if event.is_action_pressed(action):
			_last_navigation = Time.get_ticks_msec()
			return


# --- API pública ---

## Reproduce un efecto del catálogo («click», «tecla», «puerta_cerrada»...). Devuelve si sonó.
func play(sound_id: String) -> bool:
	if effects == null or sound_id.is_empty():
		return false
	return effects.play(sound_id)


## Reproduce un efecto colocado en el mundo (si el efecto es espacial).
func play_at(sound_id: String, where: Vector3) -> bool:
	return effects != null and effects.play(sound_id, {"position": where})


## Pasa al paisaje sonoro de un lugar. Lo llama la escena de juego al construir el escenario
## (`location` es su nodo, para colocar los sonidos) y el menú principal con «menu».
func enter_location(id: String, location: Node3D = null) -> void:
	location_id = id
	_cancel_pending_chime()
	ambience.night = _is_night(GameClock.minutes) and _is_outdoor(id)
	ambience.enter(id, location, _fade("location", 2.5))
	ambience.details_enabled = _details_allowed()
	_last_time = Vector2i(GameClock.day, GameClock.minutes)
	_schedule_music(LOCATION_MUSIC_DELAY if id != "menu" else 0.0)
	state_changed.emit()


## El detective oye desde su posición, orientado como la cámara (para que izquierda y derecha
## coincidan con la pantalla). Sin oyente, oye la cámara.
func attach_listener(target: Node3D, yaw: float) -> void:
	if is_instance_valid(_listener):
		_listener.queue_free()
	_listener = AudioListener3D.new()
	_listener.name = "OidoDelDetective"
	_listener.position = Vector3(0.0, 1.6, 0.0)
	_listener.rotation = Vector3(0.0, yaw, 0.0)
	target.add_child(_listener)
	_listener.make_current()


## Sube la tensión durante un rato (para sucesos futuros que la historia todavía no tiene).
func raise_tension(amount: float, seconds: float) -> void:
	_boost = clampf(maxf(_boost, amount), 0.0, 1.0)
	_boost_timer.start(maxf(seconds, 0.1))
	_apply_music(false)


## Fija una pista (o «silencio») por encima de todo lo demás, para una cinemática futura, hasta que
## se retire con una cadena vacía; entonces vuelve lo que pida el momento.
func set_music_override(track_id: String) -> void:
	_override = track_id
	_apply_music(true)


## Un paso del detective: el sonido depende del suelo que pisa en `location` (tarima, baldosa o
## alfombra, según lo declarado por el escenario); sin suelo declarado, el de fuera o el de dentro.
func play_footstep(location: LocationBase, where: Vector3) -> bool:
	var steps: Dictionary = catalog.section("footsteps")
	var surface := location.get_surface_at(where) if location != null else ""
	if surface.is_empty():
		surface = String(steps.get("outdoor" if _is_outdoor(location_id) else "indoor", ""))
	return play(String((steps.get("surfaces", {}) as Dictionary).get(surface, "")))


## Suena una muestra al mover el volumen de un canal, para oír el nivel elegido.
func preview_volume(bus_name: String) -> void:
	if bus_name in ["Master", EFFECTS_BUS]:
		play("ui_mover")


## Estado del sonido para el diagnóstico y las pruebas.
func get_debug_state() -> Dictionary:
	return {
		"location": location_id,
		"track": music.track_id,
		"intensity": music.intensity,
		"tension_db": music.get_tension_db(),
		"music_duck_db": music.duck_db,
		"ambience_duck_db": ambience.duck_db,
		"layers": ambience.active_layers(),
		"emitters": ambience.active_emitters(),
		"muffled": muffled,
		"night": ambience.night,
		"resting": music.resting,
		"details": ambience.details_enabled,
		"locks": _locks.keys(),
		"desired": _desired(),
	}


## Decide ya la música, sin esperar (para las pruebas y para las órdenes inmediatas).
func refresh_music_now() -> void:
	_music_timer.stop()
	_apply_music(true)


## Detiene todo al momento y olvida el lugar, la tensión extra y las órdenes (pruebas y diagnóstico).
func reset() -> void:
	_music_timer.stop()
	_boost_timer.stop()
	_cancel_pending_chime()
	_boost = 0.0
	_override = ""
	location_id = ""
	music.stop_now()
	music.set_intensity(0.0, 0.0)
	music.set_duck(0.0, 0.0)
	ambience.stop_now()
	ambience.set_duck(0.0, 0.0)
	effects.stop_all()
	effects.history.clear()
	_set_muffled(false)
	if _muffle_tween != null and _muffle_tween.is_valid():
		_muffle_tween.kill()
	_set_cutoff(OPEN_CUTOFF_HZ)
	_enable_lowpass(false)


# --- Canales ---

func _setup_buses() -> void:
	for bus_name in [MUSIC_BUS, AMBIENCE_BUS, EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index := AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	for bus_name in MUFFLED_BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = OPEN_CUTOFF_HZ
		AudioServer.add_bus_effect(index, filter)
		AudioServer.set_bus_effect_enabled(index, AudioServer.get_bus_effect_count(index) - 1, false)
		_lowpass.append(filter)
	# Un limitador en la salida evita que la suma de capas sature.
	var master := AudioServer.get_bus_index("Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(master, limiter)


func _set_muffled(value: bool) -> void:
	if value == muffled:
		return
	muffled = value
	if _muffle_tween != null and _muffle_tween.is_valid():
		_muffle_tween.kill()
	if value:
		_enable_lowpass(true)
	_muffle_tween = create_tween()
	var target := MUFFLE_CUTOFF_HZ if value else OPEN_CUTOFF_HZ
	_muffle_tween.tween_method(_set_cutoff, _lowpass[0].cutoff_hz, target, 0.35 if value else 0.6).set_trans(Tween.TRANS_SINE)
	if not value:
		_muffle_tween.tween_callback(_enable_lowpass.bind(false))


func _set_cutoff(value: float) -> void:
	for filter in _lowpass:
		filter.cutoff_hz = value


func _enable_lowpass(enabled: bool) -> void:
	for bus_name in MUFFLED_BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		for effect_index in AudioServer.get_bus_effect_count(index):
			if AudioServer.get_bus_effect(index, effect_index) in _lowpass:
				AudioServer.set_bus_effect_enabled(index, effect_index, enabled)


## Si el filtro de la pausa está activo en el canal de la música.
func is_lowpass_enabled() -> bool:
	var index := AudioServer.get_bus_index(MUSIC_BUS)
	for effect_index in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect_index) in _lowpass:
			return AudioServer.is_bus_effect_enabled(index, effect_index)
	return false


# --- Juego ---

func _connect_game() -> void:
	EventBus.location_change_requested.connect(_on_location_change_requested)
	EventBus.clue_discovered.connect(_on_event_sound.bind("clue").unbind(1))
	EventBus.deduction_made.connect(_on_event_sound.bind("deduction").unbind(1))
	EventBus.testimony_recorded.connect(_on_event_sound.bind("testimony").unbind(1))
	EventBus.notification_requested.connect(_on_notification)
	EventBus.player_locks_changed.connect(_on_locks_changed)
	EventBus.time_changed.connect(_on_time_changed)
	EventBus.flag_set.connect(_schedule_music.bind(0.0).unbind(1))
	EventBus.day_changed.connect(_schedule_music.bind(0.0).unbind(1))
	EventBus.rest_requested.connect(_on_event_sound.bind("rest"))
	DialogueManager.scene_started.connect(_on_scene_started)
	DialogueManager.closed.connect(_on_dialogue_closed)
	SaveSystem.save_started.connect(_on_save_started)
	SaveSystem.save_finished.connect(_on_save_finished)
	get_tree().root.gui_focus_changed.connect(_on_focus_changed)


func _make_timer(callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(callback)
	add_child(timer)
	return timer


func _fade(key: String, fallback: float) -> float:
	return float((catalog.section("fades") as Dictionary).get(key, fallback))


func _is_outdoor(id: String) -> bool:
	if id == "menu":
		return true
	return bool((GameData.locations.get(id, {}) as Dictionary).get("outdoor", false))


func _is_night(minutes: int) -> bool:
	return AudioMood.is_night(catalog.section("intensity"), minutes)


func _schedule_music(delay: float) -> void:
	if delay <= 0.0:
		_music_timer.stop()
		_apply_music.call_deferred(true)
	else:
		_music_timer.start(delay)


func _desired() -> Dictionary:
	var base := AudioMood.story_intensity(catalog.section("intensity"), location_id, GameClock.day,
		GameClock.minutes, GameState.flags, _is_outdoor(location_id))
	if location_id == "menu":
		base = 0.0
	var scene := DialogueManager.scene_id if DialogueManager.active else ""
	return AudioMood.desired_music(catalog, location_id, clampf(base + _boost, 0.0, 1.0), _locks.keys(), scene,
		GameState.flags, _override)


## Aplica la pista y la tensión que tocan. `change_track` en falso sólo reajusta la tensión.
func _apply_music(change_track: bool = true) -> void:
	if location_id.is_empty():
		return
	var wanted := _desired()
	if change_track:
		var fade := _fade("music", 3.0)
		if String(wanted["track"]).is_empty():
			fade = _fade("silence", 1.8)
		music.play(String(wanted["track"]), fade)
	music.set_intensity(float(wanted["intensity"]), _fade("intensity", 4.0))
	state_changed.emit()


func _on_boost_finished() -> void:
	_boost = 0.0
	_apply_music(false)


func _on_event_sound(event_name: String) -> void:
	play(catalog.event(event_name))


## Los fragmentos musicales bajan un momento la música de fondo para destacar.
func _on_effect_played(_id: String, entry: Dictionary) -> void:
	if entry.has("duck_music_db"):
		music.duck_for_stinger(float(entry["duck_music_db"]), float(entry.get("hold", 2.0)))


func _on_notification(_title: String, _body: String, kind: String) -> void:
	match kind:
		"historia":
			# Un suceso inquietante: fragmento y, durante un rato, más tensión de fondo.
			play(catalog.event("story_notice"))
			var boost: Dictionary = catalog.section("intensity").get("story_boost", {})
			if not boost.is_empty():
				raise_tension(float(boost.get("amount", 0.25)), float(boost.get("seconds", 90.0)))
		"info":
			play(catalog.event("info_notice"))


## Puerta o camino al cambiar de lugar: el sonido depende de adónde se entra y de dónde se sale.
func _on_location_change_requested(target: String, _spawn: String) -> void:
	var transitions: Dictionary = catalog.section("transitions")
	var sound := ""
	if not _is_outdoor(target):
		sound = String(transitions.get(target, transitions.get("interior", "")))
	elif not _is_outdoor(location_id):
		sound = String(transitions.get("exit", ""))
	else:
		sound = String(transitions.get("street", ""))
	play(sound)
	_cancel_pending_chime()


func _on_scene_started(scene_id: String) -> void:
	var scene := catalog.scene(scene_id)
	if scene.has("cue"):
		play(String(scene["cue"]))
	_apply_screen_mix()
	_schedule_music(0.0)


func _on_dialogue_closed(_npc_id: String) -> void:
	_schedule_music(0.0)


## Cada pantalla o situación que bloquea al jugador puede sonar al abrirse y al cerrarse, atenuar
## la música y el ambiente, amortiguarlos (pausa), suspender los detalles o cambiar la música.
func _on_locks_changed() -> void:
	var current := {}
	for reason in GameState.get_player_lock_reasons():
		current[reason] = true
	var added: Array[String] = []
	var removed: Array[String] = []
	for reason: String in current:
		if not _locks.has(reason):
			added.append(reason)
	for reason: String in _locks:
		if not current.has(reason):
			removed.append(reason)
	_locks = current
	# Sólo suena un cambio suelto; un vaciado de golpe (cargar partida, volver al menú) es silencioso.
	if added.size() + removed.size() == 1:
		for reason in added:
			play(String(catalog.screen(reason).get("open", "")))
		for reason in removed:
			play(String(catalog.screen(reason).get("close", "")))
	_apply_screen_mix()
	var changes_music := false
	for reason in added + removed:
		changes_music = changes_music or catalog.screen(reason).has("music")
	if changes_music:
		_schedule_music(0.0)
	state_changed.emit()


## Una escena narrativa puede fijar su propia atenuación de la música (`music_db`), que sustituye a la
## de un diálogo corriente: en la confrontación final, la música no se aparta tanto.
func _apply_screen_mix() -> void:
	var music_db := 0.0
	var ambience_db := 0.0
	var muffle := false
	var scene := catalog.scene(DialogueManager.scene_id) if DialogueManager.active else {}
	for reason: String in _locks:
		var screen := catalog.screen(reason)
		if reason == "dialogo" and scene.has("music_db"):
			music_db = minf(music_db, float(scene["music_db"]))
		else:
			music_db = minf(music_db, float(screen.get("music_db", 0.0)))
		ambience_db = minf(ambience_db, float(screen.get("ambience_db", 0.0)))
		muffle = muffle or bool(screen.get("muffle", false))
	var down := music_db < music.duck_db or ambience_db < ambience.duck_db
	var seconds := _fade("duck", 0.6) if down else _fade("unduck", 1.4)
	music.set_duck(music_db, seconds)
	ambience.set_duck(ambience_db, seconds)
	ambience.details_enabled = _details_allowed()
	_set_muffled(muffle)


func _details_allowed() -> bool:
	for reason: String in _locks:
		if not bool(catalog.screen(reason).get("details", true)):
			return false
	return true


## La hora avanza: de noche cambian las capas y, si el lugar tiene reloj, da las campanadas.
func _on_time_changed(day: int, minutes: int) -> void:
	var previous := _last_time
	_last_time = Vector2i(day, minutes)
	ambience.set_night(_is_night(minutes) and _is_outdoor(location_id))
	var advanced := minutes - previous.y
	if previous.x == day and advanced > 0 and advanced <= 120 and minutes / 60 > previous.y / 60:
		_cancel_pending_chime()
		# Se espera un instante: si el tiempo pasó al cruzar una puerta, la campanada no suena en
		# el lugar que se abandona.
		_pending_chime = create_tween()
		_pending_chime.tween_interval(1.2)
		_pending_chime.tween_callback(ambience.chime.bind(minutes / 60))
	_apply_music(false)


func _cancel_pending_chime() -> void:
	if _pending_chime != null and _pending_chime.is_valid():
		_pending_chime.kill()
	_pending_chime = null


func _on_save_started(slot_id: String) -> void:
	if SaveSystem.get_writing_kind() == "manual":
		_manual_saves[slot_id] = true


func _on_save_finished(slot_id: String, ok: bool, _message: String) -> void:
	if _manual_saves.erase(slot_id) and ok:
		play(catalog.event("save"))


## Mover el foco con el teclado, el mando o el ratón suena; los cambios de foco que hace el propio
## juego al abrir una pantalla, no.
func _on_focus_changed(control: Control) -> void:
	if Time.get_ticks_msec() - _last_navigation > NAVIGATION_WINDOW_MS:
		return
	if control is BaseButton or control is Range:
		play(catalog.event("focus"))
