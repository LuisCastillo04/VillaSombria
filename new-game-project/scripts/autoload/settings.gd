extends Node
## Preferencias del jugador, comunes a todas las partidas: audio, gráficos, jugabilidad,
## accesibilidad y controles. Se guardan en `user://ajustes.cfg`, aparte de las partidas, así que
## no dependen de ninguna ranura.
##
## Qué preferencias existen, sus valores por defecto y los que admiten lo dice `SettingsSchema`;
## aquí se leen, se validan, se aplican y se guardan. Cada cambio se escribe en el acto y sólo toca
## su propia clave: el resto del archivo, incluidas las secciones que este autoload no conoce (por
## ejemplo, las teclas que guarda `Controls` en `controles`), se conserva.
##
## Quien dependa de una preferencia la lee con `get_value` y escucha `changed` para aplicarla en
## caliente. Lo que pertenece al motor (volumen de los canales y ventana) lo aplica este autoload.
##
## Los cambios de pantalla (modo de ventana y resolución) pasan por `request_display_change`: se
## prueban sin guardarlos, se pregunta si se mantienen y, si no se confirma a tiempo, se vuelve a lo
## anterior. Así ninguna combinación deja al jugador sin ver los menús.

## Una preferencia cambió de valor (ya validado, aplicado y guardado).
signal changed(key: String, value: Variant)
## Se volvió a leer el archivo (al arrancar o con `use_file`). Quien guarde en él su propia sección
## (las teclas de `Controls`) la vuelve a leer al recibirlo.
signal reloaded

const SETTINGS_PATH := "user://ajustes.cfg"
const BUSES: Array[String] = ["Master", "Musica", "Efectos", "Ambiente"]
const DEFAULT_VOLUME := SettingsSchema.DEFAULT_VOLUME
## Copia que se guarda de un archivo ilegible antes de sustituirlo.
const DAMAGED_SUFFIX := ".danado"
## Segundos para confirmar un cambio de pantalla antes de que se restaure el anterior.
const DISPLAY_CONFIRM_SECONDS := 15.0
const DISPLAY_KEYS: Array[String] = ["graficos/modo_ventana", "graficos/resolucion"]

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
## Hay un cambio de pantalla en prueba, esperando a que el jugador lo confirme.
var _display_pending := false
## Contraste aumentado de toda la interfaz (`accesibilidad/contraste_alto`).
var _contrast := ContrastFilter.new()


func _ready() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index := AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	load_settings()
	for bus_name in BUSES:
		_apply_volume(bus_name)
	DisplaySettings.apply_vsync(vsync)
	GraphicsQuality.apply_lighting(get_tree(), get_value("graficos/calidad_iluminacion"))
	GraphicsQuality.apply_effects(get_tree(), get_value("graficos/calidad_efectos"))
	_apply_accessibility()
	# La ventana se coloca cuando ya se sabe qué escena arranca: las de prueba fijan la suya.
	_apply_display.call_deferred()


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


## Cambia varias preferencias a la vez: o se aceptan todas o ninguna. Se aplican una sola vez, para
## que, por ejemplo, el modo de ventana y la resolución no muevan la ventana dos veces.
func set_values(changes: Dictionary) -> bool:
	var accepted := {}
	for key: String in changes:
		var valid: Variant = SettingsSchema.validate(key, changes[key])
		if valid == null:
			push_warning("Ajuste rechazado: %s = %s" % [key, str(changes[key])])
			return false
		if _values.get(key) != valid:
			accepted[key] = valid
	if accepted.is_empty():
		return true
	var keys: Array[String] = []
	for key: String in accepted:
		_values[key] = accepted[key]
		keys.append(key)
	_sync_volumes()
	if keys.any(func(key: String) -> bool: return key in DISPLAY_KEYS):
		_apply_display()
	for key in keys:
		if not key in DISPLAY_KEYS:
			_apply_key(key)
	_write(keys)
	for key in keys:
		changed.emit(key, accepted[key])
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
## migra. Si hubo que corregir algo, el archivo se reescribe ya corregido. Al terminar avisa con
## `reloaded`.
func load_settings() -> void:
	_read_file()
	reloaded.emit()


func _read_file() -> void:
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


# --- Secciones de otros sistemas ---

## Contenido de una sección que gestiona otro sistema (`SettingsSchema.EXTERNAL_SECTIONS`), tal como
## está en el archivo. Vacío si no existe o el archivo no se puede leer. Validarlo es cosa de quien
## lo usa.
func read_section(section: String) -> Dictionary:
	var values := {}
	var config := ConfigFile.new()
	if not FileAccess.file_exists(settings_path) or config.load(settings_path) != OK:
		return values
	if config.has_section(section):
		for key in config.get_section_keys(section):
			values[key] = config.get_value(section, key)
	return values


## Sustituye entera una sección de otro sistema por `values` (vacío la retira) y conserva todo lo
## demás. Las secciones de las preferencias de `SettingsSchema` no se pueden escribir así. Devuelve si
## se guardó.
func write_section(section: String, values: Dictionary) -> bool:
	if not section in SettingsSchema.EXTERNAL_SECTIONS:
		push_warning("La sección %s no es de otro sistema: usa set_value." % section)
		return false
	var config := _open_config()
	if config.has_section(section):
		config.erase_section(section)
	for key: String in values:
		config.set_value(section, key, values[key])
	return _save_config(config)


# --- Pantalla ---

## Prueba un modo de ventana y una resolución, pregunta si se mantienen y sólo entonces los guarda.
## Si el jugador elige restaurar, cierra la pregunta o no contesta en `timeout` segundos, la ventana
## vuelve a lo que había. Devuelve si el cambio quedó confirmado. Mientras hay uno pendiente, otro
## se rechaza.
func request_display_change(mode: String, resolution: Vector2i, timeout: float = DISPLAY_CONFIRM_SECONDS) -> bool:
	var valid_mode: Variant = SettingsSchema.validate("graficos/modo_ventana", mode)
	var valid_size: Variant = SettingsSchema.validate("graficos/resolucion", resolution)
	if _display_pending or valid_mode == null or valid_size == null:
		return false
	if valid_mode == get_value("graficos/modo_ventana") and valid_size == get_value("graficos/resolucion"):
		return true
	_display_pending = true
	if not DisplaySettings.is_window_fixed(get_tree()):
		DisplaySettings.apply(get_tree().root, valid_mode, valid_size)
	var keep: bool = await ConfirmDialog.ask("¿MANTENER ESTA PANTALLA?",
		"La pantalla ha cambiado a «%s»%s." % [SettingsSchema.label_of(valid_mode), _size_text(valid_mode, valid_size)],
		{"confirm_text": "Mantener", "cancel_text": "Restaurar", "focus": "cancel",
			"timeout": timeout, "timeout_text": "Si no confirmas, se restaurará la anterior en %d s."})
	_display_pending = false
	if keep:
		set_values({"graficos/modo_ventana": valid_mode, "graficos/resolucion": valid_size})
	else:
		_apply_display()
	return keep


## Si hay un cambio de pantalla esperando confirmación.
func is_display_change_pending() -> bool:
	return _display_pending


## Resolución con la que se dibuja de verdad: la elegida en los modos con ventana (ajustada al
## monitor) y la del monitor en pantalla completa.
func get_effective_resolution() -> Vector2i:
	var mode := String(get_value("graficos/modo_ventana"))
	return DisplaySettings.fit(get_value("graficos/resolucion"), mode)


static func _size_text(mode: String, size: Vector2i) -> String:
	if DisplaySettings.is_fullscreen_mode(mode):
		return ""
	var real := DisplaySettings.fit(size, mode)
	return " a %d × %d" % [real.x, real.y]


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
	DisplaySettings.apply_vsync(vsync)
	GraphicsQuality.apply_lighting(get_tree(), get_value("graficos/calidad_iluminacion"))
	GraphicsQuality.apply_effects(get_tree(), get_value("graficos/calidad_efectos"))
	_apply_accessibility()
	_apply_display()


## Tamaño de letra (escala de la interfaz) y contraste aumentado. Los subtítulos y el movimiento
## reducido los leen quienes los usan.
func _apply_accessibility() -> void:
	if not is_inside_tree():
		return
	UiAccessibility.apply_text_scale(get_tree(), get_value("accesibilidad/tamano_letra"))
	_contrast.set_enabled(get_tree(), bool(get_value("accesibilidad/contraste_alto")))


## Si el contraste aumentado está aplicado ahora mismo a la interfaz.
func is_high_contrast_applied() -> bool:
	return _contrast.is_enabled()


func _apply_key(key: String) -> void:
	match key:
		"graficos/modo_ventana", "graficos/resolucion":
			_apply_display()
		"graficos/vsync":
			DisplaySettings.apply_vsync(vsync)
		"graficos/calidad_iluminacion":
			GraphicsQuality.apply_lighting(get_tree(), get_value(key))
		"graficos/calidad_efectos":
			GraphicsQuality.apply_effects(get_tree(), get_value(key))
		VisualFilters.SETTING_KEY:
			VisualFilters.apply(get_tree(), get_value(key))
		"accesibilidad/tamano_letra", "accesibilidad/contraste_alto":
			_apply_accessibility()
		_:
			if SettingsSchema.section_of(key) == "audio":
				_apply_volume(SettingsSchema.name_of(key))


func _apply_volume(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var value := float(get_value("audio/" + bus_name))
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


## Coloca la ventana según el modo y la resolución guardados, salvo que la escena la fije ella misma.
func _apply_display() -> void:
	if not is_inside_tree() or DisplaySettings.is_window_fixed(get_tree()):
		return
	DisplaySettings.apply(get_tree().root, get_value("graficos/modo_ventana"), get_value("graficos/resolucion"))


func _sync_volumes() -> void:
	for bus_name in BUSES:
		volumes[bus_name] = float(get_value("audio/" + bus_name))


## Escribe las claves dadas sobre el archivo existente, conservando todo lo demás.
func _write(keys: Array[String]) -> bool:
	var config := _open_config()
	for key in keys:
		config.set_value(SettingsSchema.section_of(key), SettingsSchema.name_of(key), get_value(key))
	return _save_config(config)


## El archivo tal como está, listo para cambiarlo: sin las secciones del formato anterior, que ya se
## migraron al leer, y con la versión actual. Si no existe o es ilegible, uno vacío.
func _open_config() -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(settings_path) and config.load(settings_path) != OK:
		config = ConfigFile.new()
	for section in SettingsSchema.LEGACY_SECTIONS:
		if config.has_section(section):
			config.erase_section(section)
	config.set_value("meta", "version", SettingsSchema.VERSION)
	return config


func _save_config(config: ConfigFile) -> bool:
	var error := config.save(settings_path)
	if error != OK:
		push_warning("No se pudieron guardar los ajustes en %s (%s)" % [settings_path, error_string(error)])
	return error == OK
