class_name Game
extends Node
## Escena de juego: mantiene al detective, la cámara y la interfaz, y sustituye el
## escenario activo cuando el jugador cruza una salida.

const LOCATION_SCENES := {
	"test_ground": "res://scenes/world/locations/test_ground.tscn",
	"plaza": "res://scenes/world/locations/plaza.tscn",
}
const OUTDOOR_LOCATIONS: Array[String] = ["test_ground", "plaza", "estacion"]
const START_LOCATION := "plaza"
const START_SPAWN := "inicio"

var current_location: LocationBase
var _changing := false
var _rain: RainEffect

@onready var _world_root: Node3D = $WorldRoot
@onready var _fade: ScreenFade = $ScreenFade
@onready var _post_fx: PostFx = $PostFx
@onready var player: PlayerController = $Player
@onready var camera: ExplorationCamera = $CameraRig


func _ready() -> void:
	camera.target = player
	player.camera_yaw = camera.get_yaw()
	EventBus.location_change_requested.connect(go_to)
	_load_location(START_LOCATION, START_SPAWN)
	_fade.fade_in()


## Cambia de escenario con un fundido. Ignora peticiones durante otra transición.
func go_to(location_id: String, spawn_id: String) -> void:
	if _changing:
		return
	if not LOCATION_SCENES.has(location_id):
		EventBus.notification_requested.emit("Cerrado", "Este lugar aún no está disponible.", "info")
		return
	_changing = true
	GameState.lock_player("transicion")
	await _fade.fade_out()
	_load_location(location_id, spawn_id)
	await _fade.fade_in()
	GameState.unlock_player("transicion")
	_changing = false


func _load_location(location_id: String, spawn_id: String) -> void:
	if current_location != null:
		_world_root.remove_child(current_location)
		current_location.queue_free()
	var scene: PackedScene = load(LOCATION_SCENES[location_id])
	current_location = scene.instantiate()
	_world_root.add_child(current_location)
	var spawn := current_location.get_spawn(spawn_id)
	player.teleport(spawn["position"], spawn["yaw"])
	camera.limits = current_location.camera_limits
	camera.snap()
	_apply_weather(OUTDOOR_LOCATIONS.has(location_id))
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
