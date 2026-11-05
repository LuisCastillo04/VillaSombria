extends Node
## Ajustes del jugador: volumen por canal, pantalla completa y sincronización vertical.

const SETTINGS_PATH := "user://ajustes.cfg"
const BUSES: Array[String] = ["Master", "Musica", "Efectos", "Ambiente"]
const DEFAULT_VOLUME := 0.8

var volumes: Dictionary = {}
var fullscreen := false
## Desactivada por defecto: en portátiles con doble GPU la sincronización vertical puede
## hundir la tasa de fotogramas. El motor limita igualmente el juego a 60 FPS.
var vsync := false


func _ready() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index := AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
		volumes[bus_name] = DEFAULT_VOLUME
	_load()
	_apply()


func set_volume(bus_name: String, value: float) -> void:
	volumes[bus_name] = clampf(value, 0.0, 1.0)
	_apply_volume(bus_name)
	save()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window()
	save()


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_window()
	save()


func save() -> void:
	var config := ConfigFile.new()
	for bus_name in BUSES:
		config.set_value("volumen", bus_name, volumes[bus_name])
	config.set_value("pantalla", "completa", fullscreen)
	config.set_value("pantalla", "vsync", vsync)
	config.save(SETTINGS_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus_name in BUSES:
		volumes[bus_name] = float(config.get_value("volumen", bus_name, DEFAULT_VOLUME))
	fullscreen = bool(config.get_value("pantalla", "completa", false))
	vsync = bool(config.get_value("pantalla", "vsync", false))


func _apply() -> void:
	for bus_name in BUSES:
		_apply_volume(bus_name)
	_apply_window()


func _apply_volume(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	var value: float = volumes[bus_name]
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
