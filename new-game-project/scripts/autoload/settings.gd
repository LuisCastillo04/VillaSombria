extends Node
## Preferencias del jugador, comunes a todas las partidas: audio, gráficos, jugabilidad,
## accesibilidad y controles. Se guardan en `user://ajustes.cfg`, aparte de las partidas, así que
## no dependen de ninguna ranura.
##
## Qué preferencias existen, sus valores por defecto y los que admiten lo dice `SettingsSchema`;
## aquí se leen, se validan, se aplican y se guardan. Cada cambio se escribe en el acto y sólo toca
## su propia clave: el resto del archivo, incluidas las secciones que este autoload no conoce (por
## ejemplo, las teclas que guarde un sistema de reasignación en `controles`), se conserva.
##
## Quien dependa de una preferencia la lee con `get_value` y escucha `changed` para aplicarla en
## caliente. Lo que pertenece al motor (volumen de los canales y ventana) lo aplica este autoload.

## Una preferencia cambió de valor (ya validado, aplicado y guardado).
signal changed(key: String, value: Variant)

const SETTINGS_PATH := "user://ajustes.cfg"
const BUSES: Array[String] = ["Master", "Musica", "Efectos", "Ambiente"]
const DEFAULT_VOLUME := SettingsSchema.DEFAULT_VOLUME
## Copia que se guarda de un archivo ilegible antes de sustituirlo.
const DAMAGED_SUFFIX := ".danado"

## Archivo en uso. Las pruebas lo cambian con `use_file` para no tocar los ajustes del jugador.
var settings_path := SETTINGS_PATH
## Volumen de cada canal, de 0 a 1: reflejo de `audio/*` para quien ya lo leía así.
var volumes: Dictionary = {}
## Si el modo de ventana es uno de pantalla completa.
var fullscreen: bool:
	get:
		return String(get_value("graficos/modo_ventana")) in ["pantalla_completa", "exclusiva"]
var vsync: bool:
	get:
		return bool(get_value("graficos/vsync"))

var _values: Dictionary = {}
## Qué pasó en la última lectura: archivo ausente o ilegible, migración y valores descartados.
var _load_report: Dictionary = {}


func _ready() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index := AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	load_settings()
	apply_all()


# --- Lectura y escritura de preferencias ---

## Valor vigente de una preferencia («graficos/vsync»).
func get_value(key: String) -> Variant:
	if _values.has(key):
		return _values[key]
	return SettingsSchema.default_value(key)


## Cambia una preferencia: la valida, la aplica, guarda sólo su clave y avisa con `changed`. Un valor
## no admitido se rechaza y deja el anterior. Devuelve si el valor queda aceptado.
func set_value(key: String, value: Variant) -> bool:
	var valid: Variant = SettingsSchema.validate(key, value)
	if valid == null:
		push_warning("Ajuste rechazado: %s = %s" % [key, str(value)])
		return false
	if _values.get(key) == valid:
		return true
	_values[key] = valid
	_sync_volumes()
	_apply_key(key)
	_write([key])
	changed.emit(key, valid)
	return true


## Vuelve a los valores por defecto las claves dadas, o todas si no se indica ninguna.
func restore_defaults(keys: Array[String] = []) -> void:
	var targets := keys if not keys.is_empty() else SettingsSchema.keys()
	for key in targets:
		set_value(key, SettingsSchema.default_value(key))


## Qué pasó en la última lectura del archivo, para las pruebas y el diagnóstico.
func get_load_report() -> Dictionary:
	return _load_report.duplicate(true)


## Usa otro archivo de ajustes: lo lee y lo aplica. Las pruebas trabajan así con uno propio.
func use_file(path: String) -> void:
	settings_path = path
	load_settings()
	apply_all()


## Lee el archivo. Lo que falte o no sea válido toma su valor por defecto; el formato anterior se
## migra. Si hubo que corregir algo, el archivo se reescribe ya corregido.
func load_settings() -> void:
	_values = SettingsSchema.defaults()
	_load_report = {"file": "missing", "migrated": false, "rejected": []}
	if not FileAccess.file_exists(settings_path):
		_sync_volumes()
		return
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		# Ilegible: se aparta una copia para no perder nada y se sigue con los valores por defecto.
		_load_report["file"] = "damaged"
		DirAccess.copy_absolute(settings_path, settings_path + DAMAGED_SUFFIX)
		DirAccess.remove_absolute(settings_path)
		_write(SettingsSchema.keys())
		_sync_volumes()
		return
	_load_report["file"] = "loaded"
	var stored := SettingsSchema.migrate_legacy(config)
	var rewrite := not stored.is_empty()
	_load_report["migrated"] = rewrite
	for key in SettingsSchema.keys():
		var section := SettingsSchema.section_of(key)
		var setting := SettingsSchema.name_of(key)
		if config.has_section_key(section, setting):
			stored[key] = config.get_value(section, setting)
	for key: String in stored:
		var valid: Variant = SettingsSchema.validate(key, stored[key])
		if valid == null:
			(_load_report["rejected"] as Array).append(key)
			rewrite = true
		else:
			_values[key] = valid
			rewrite = rewrite or valid != stored[key]
	if rewrite or int(config.get_value("meta", "version", 0)) != SettingsSchema.VERSION:
		_write(SettingsSchema.keys())
	_sync_volumes()


## Escribe todas las preferencias.
func save() -> void:
	_write(SettingsSchema.keys())


# --- Atajos de las preferencias que ya existían ---

func set_volume(bus_name: String, value: float) -> void:
	set_value("audio/" + bus_name, value)


func set_fullscreen(value: bool) -> void:
	set_value("graficos/modo_ventana", "pantalla_completa" if value else "ventana")


func set_vsync(value: bool) -> void:
	set_value("graficos/vsync", value)


# --- Aplicación ---

## Aplica todas las preferencias que dependen del motor.
func apply_all() -> void:
	for bus_name in BUSES:
		_apply_volume(bus_name)
	_apply_window()


func _apply_key(key: String) -> void:
	match SettingsSchema.section_of(key):
		"audio":
			_apply_volume(SettingsSchema.name_of(key))
		"graficos":
			if key in ["graficos/modo_ventana", "graficos/resolucion", "graficos/vsync"]:
				_apply_window()


func _apply_volume(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var value := float(get_value("audio/" + bus_name))
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _sync_volumes() -> void:
	for bus_name in BUSES:
		volumes[bus_name] = float(get_value("audio/" + bus_name))


## Escribe las claves dadas sobre el archivo existente, conservando todo lo demás. Retira las
## secciones del formato anterior, que ya se migraron al leer.
func _write(keys: Array[String]) -> bool:
	var config := ConfigFile.new()
	if FileAccess.file_exists(settings_path) and config.load(settings_path) != OK:
		config = ConfigFile.new()
	for section in SettingsSchema.LEGACY_SECTIONS:
		if config.has_section(section):
			config.erase_section(section)
	config.set_value("meta", "version", SettingsSchema.VERSION)
	for key in keys:
		config.set_value(SettingsSchema.section_of(key), SettingsSchema.name_of(key), get_value(key))
	var error := config.save(settings_path)
	if error != OK:
		push_warning("No se pudieron guardar los ajustes en %s (%s)" % [settings_path, error_string(error)])
	return error == OK
