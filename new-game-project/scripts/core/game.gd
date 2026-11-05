class_name Game
extends Node
## Escena de juego: mantiene al detective, la cámara y la interfaz, sustituye el
## escenario activo y atiende las acciones globales de la partida.

const START_LOCATION := "plaza"
const START_SPAWN := "inicio"
const WAIT_MINUTES := 60

var current_location: LocationBase
var _changing := false
var _rain: RainEffect

@onready var _world_root: Node3D = $WorldRoot
@onready var _fade: ScreenFade = $ScreenFade
@onready var _post_fx: PostFx = $PostFx
@onready var _journal: JournalUi = $JournalUi
@onready var player: PlayerController = $Player
@onready var camera: ExplorationCamera = $CameraRig


func _ready() -> void:
	camera.target = player
	player.camera_yaw = camera.get_yaw()
	EventBus.location_change_requested.connect(go_to)
	EventBus.rest_requested.connect(_on_rest_requested)
	GameState.reset()
	GameClock.reset()
	Investigation.discover_clue("carta_valdes")
	_load_location(START_LOCATION, START_SPAWN)
	_fade.fade_in()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_player_locked():
		return
	if event.is_action_pressed("open_journal"):
		get_viewport().set_input_as_handled()
		_journal.open()
	elif event.is_action_pressed("wait_time"):
		get_viewport().set_input_as_handled()
		_wait_an_hour()


## Cambia de escenario con un fundido. Ignora peticiones durante otra transición.
func go_to(location_id: String, spawn_id: String) -> void:
	if _changing:
		return
	if not ResourceLoader.exists(_scene_path(location_id)):
		EventBus.notification_requested.emit("Cerrado", "Este lugar aún no está disponible.", "info")
		return
	_changing = true
	GameState.lock_player("transicion")
	await _fade.fade_out()
	_load_location(location_id, spawn_id)
	await _fade.fade_in()
	GameState.unlock_player("transicion")
	_changing = false


func _scene_path(location_id: String) -> String:
	return GameData.locations.get(location_id, {}).get("scene", "")


func _load_location(location_id: String, spawn_id: String) -> void:
	if current_location != null:
		_world_root.remove_child(current_location)
		current_location.queue_free()
	var scene: PackedScene = load(_scene_path(location_id))
	current_location = scene.instantiate()
	_world_root.add_child(current_location)
	var spawn := current_location.get_spawn(spawn_id)
	player.teleport(spawn["position"], spawn["yaw"])
	camera.limits = current_location.camera_limits
	camera.snap()
	GameState.location_id = location_id
	GameState.spawn_id = spawn_id
	_apply_weather(bool(GameData.locations[location_id].get("outdoor", false)))
	EventBus.location_changed.emit(location_id)


func _apply_weather(outdoor: bool) -> void:
	_post_fx.set_outdoor(outdoor)
	if outdoor and _rain == null:
		_rain = RainEffect.new()
		_rain.target = player
		add_child(_rain)
	elif not outdoor and _rain != null:
		_rain.queue_free()
		_rain = null


func _wait_an_hour() -> void:
	if GameClock.is_at_limit():
		EventBus.notification_requested.emit("Es muy tarde", "Deberías descansar en la pensión del café.", "info")
		return
	GameClock.advance(WAIT_MINUTES)
	EventBus.notification_requested.emit("Pasa el tiempo", "Son las %s." % GameClock.format_time(), "info")


func _on_rest_requested() -> void:
	if _changing:
		return
	_changing = true
	GameState.lock_player("transicion")
	await _fade.fade_out(0.8)
	var rested := StoryDirector.rest()
	_load_location(GameState.location_id, GameState.spawn_id)
	await _fade.fade_in(0.8)
	GameState.unlock_player("transicion")
	_changing = false
	if rested:
		DialogueManager.play_scene("dia_%d" % GameClock.day)
