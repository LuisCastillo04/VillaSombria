extends Node
## Guardado y carga de partidas. Cada sistema aporta su parte del estado como una sección
## con nombre; aquí se reúnen en un documento de `SaveFormat` y se escriben con `SaveFile`.

## Ruta del archivo. Las pruebas la redirigen para no tocar la partida real.
var save_path := "user://partida.json"
## Pide a la escena de juego que cargue la partida al arrancar.
var load_requested := false
## El guardado automático se puede desactivar durante las pruebas.
var autosave_enabled := true

## Secciones registradas: clave -> {"save": Callable, "load": Callable}.
var _sections: Dictionary = {}


func _ready() -> void:
	register_section("state", GameState.to_dict, GameState.from_dict)
	register_section("clock", GameClock.to_dict, GameClock.from_dict)


## Incorpora una parte del estado a las partidas. `save_callable` devuelve un diccionario
## que se pueda escribir en JSON y `load_callable` lo recibe al cargar, vacío si la partida
## no lo incluía. Las secciones se restauran en el orden en que se registraron.
func register_section(key: String, save_callable: Callable, load_callable: Callable) -> void:
	_sections[key] = {"save": save_callable, "load": load_callable}


## Retira una sección. Con `section_owner`, sólo si la registró ese objeto.
func unregister_section(key: String, section_owner: Object = null) -> void:
	if not _sections.has(key):
		return
	if section_owner != null and (_sections[key]["save"] as Callable).get_object() != section_owner:
		return
	_sections.erase(key)


func capture_sections() -> Dictionary:
	var sections := {}
	for key: String in _sections:
		var saver: Callable = _sections[key]["save"]
		if saver.is_valid():
			sections[key] = saver.call()
	return sections


## Aplica las secciones de una partida ya validada.
func apply_sections(sections: Dictionary) -> void:
	for key: String in _sections:
		var loader: Callable = _sections[key]["load"]
		if loader.is_valid():
			loader.call(sections.get(key, {}))


func has_save() -> bool:
	return SaveFile.exists(save_path)


func save_game() -> bool:
	var meta := {"kind": "manual", "saved_at": int(Time.get_unix_time_from_system()), "reason": "manual"}
	var document := SaveFormat.build(meta, capture_sections())
	# Nunca se escribe una partida que después no se podría cargar.
	var problem := SaveFormat.validate(document.duplicate(true))
	if not problem.is_empty():
		push_warning("Estado no guardable: %s" % problem["error"])
		return false
	var error := SaveFile.write_atomic(save_path, SaveFormat.to_text(document))
	if error != OK:
		push_error("No se pudo escribir la partida: %s" % error_string(error))
		return false
	return true


func autosave() -> void:
	if autosave_enabled:
		save_game()


## Restaura la partida. Devuelve false, sin alterar nada, si el archivo no es válido.
func load_game() -> bool:
	var document := read_save()
	if document.is_empty():
		return false
	apply_sections(document["sections"])
	return true


## Lee y valida el archivo sin aplicarlo. Devuelve el documento o un diccionario vacío.
func read_save() -> Dictionary:
	if not has_save():
		return {}
	var file := SaveFile.read_text(save_path)
	if file["error"] != OK:
		push_warning("No se pudo leer la partida: %s" % error_string(file["error"]))
		return {}
	var result := SaveFormat.parse(file["text"], {"saved_at": FileAccess.get_modified_time(save_path)})
	if result["status"] != SaveFormat.Status.OK:
		push_warning("Partida guardada no válida: %s" % result["error"])
		return {}
	return result["document"]


## Descripción breve para el menú, como «Día 2 · 14:30».
func describe_save() -> String:
	var document := read_save()
	if document.is_empty():
		return ""
	var clock: Dictionary = document["sections"]["clock"]
	var minutes := int(clock["minutes"])
	return "Día %d · %02d:%02d" % [int(clock["day"]), minutes / 60, minutes % 60]


func delete_save() -> void:
	SaveFile.remove(save_path)
