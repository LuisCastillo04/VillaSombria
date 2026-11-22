class_name AudioCatalog
extends RefCounted
## Catálogo sonoro del juego, leído de `data/audio.json`: qué música, ambientes y efectos existen,
## qué suena en cada lugar, cómo reacciona el sonido a las pantallas, a las escenas y a la historia.
## Igual que el resto del contenido, se amplía sin tocar código. Ver docs/AUDIO.md.
##
## Los efectos se cargan la primera vez que suenan y se conservan (son pequeños). La música y los
## ambientes no se guardan aquí: los retiene el reproductor que los usa y se liberan con él.

const PATH := "res://data/audio.json"
const SECTIONS: Array[String] = ["fades", "music", "ambience", "sounds", "locations", "screens", "scenes", "events",
	"transitions", "footsteps", "intensity", "rests"]

var data: Dictionary = {}
var _effects_cache: Dictionary = {}


static func load_file(path: String = PATH) -> AudioCatalog:
	var catalog := AudioCatalog.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se puede abrir el catálogo de audio %s" % path)
		return catalog
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		catalog.data = parsed
	else:
		push_error("El catálogo de audio %s no es un objeto JSON válido" % path)
	return catalog


func section(name: String) -> Dictionary:
	return data.get(name, {})


## Efecto por su identificador, siguiendo los alias («click» → «ui_aceptar»). Vacío si no existe.
func sound(id: String) -> Dictionary:
	var sounds := section("sounds")
	var current := id
	for _step in 4:
		var entry: Dictionary = sounds.get(current, {})
		if not entry.has("alias"):
			return entry
		current = entry["alias"]
	return {}


func has_sound(id: String) -> bool:
	return not sound(id).is_empty()


func music(id: String) -> Dictionary:
	return section("music").get(id, {})


func ambience(id: String) -> Dictionary:
	return section("ambience").get(id, {})


## Paisaje sonoro de un lugar (o de «menu»). Vacío si el lugar no tiene sonido propio.
func location(id: String) -> Dictionary:
	return section("locations").get(id, {})


## Cómo cambia el sonido mientras hay un motivo de bloqueo del jugador («pausa», «dialogo»...).
func screen(reason: String) -> Dictionary:
	return section("screens").get(reason, {})


func scene(id: String) -> Dictionary:
	return section("scenes").get(id, {})


## Efecto asociado a un suceso del juego («clue», «deduction»...), o vacío.
func event(name: String) -> String:
	return String(section("events").get(name, ""))


## Carga un efecto (y lo conserva). Un archivo que falta devuelve null.
func effect_stream(path: String) -> AudioStream:
	if _effects_cache.has(path):
		return _effects_cache[path]
	var stream := _load(path)
	if stream != null:
		_effects_cache[path] = stream
	return stream


## Carga una pista o un ambiente para reproducirlo en bucle. No se conserva en el catálogo.
func loop_stream(path: String) -> AudioStream:
	var stream := _load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


func cached_effects() -> int:
	return _effects_cache.size()


func clear_cache() -> void:
	_effects_cache.clear()


func _load(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Falta el archivo de audio %s" % path)
		return null
	return load(path) as AudioStream


## Todos los archivos que el catálogo nombra, sin repetir.
func referenced_files() -> Array[String]:
	var files: Array[String] = []
	for entry: Dictionary in section("music").values():
		for key in ["base", "tension"]:
			if entry.has(key):
				files.append(String(entry[key]))
	for entry: Dictionary in section("ambience").values():
		files.append(String(entry.get("file", "")))
	for entry: Dictionary in section("sounds").values():
		for path: String in entry.get("files", []):
			files.append(path)
	var unique: Array[String] = []
	for path in files:
		if not path in unique:
			unique.append(path)
	return unique


## Comprueba que el catálogo es coherente: archivos que existen e identificadores que apuntan a
## entradas reales. Devuelve la lista de problemas (vacía si está bien).
func validate(location_ids: Array = []) -> Array[String]:
	var problems: Array[String] = []
	for name in SECTIONS:
		if not data.has(name):
			problems.append("falta la sección «%s»" % name)
	for path in referenced_files():
		if not ResourceLoader.exists(path):
			problems.append("no existe %s" % path)
	for id: String in section("sounds"):
		var entry: Dictionary = section("sounds")[id]
		if entry.has("alias"):
			if sound(id).is_empty():
				problems.append("el alias %s no lleva a ningún efecto" % id)
		elif (entry.get("files", []) as Array).is_empty():
			problems.append("el efecto %s no tiene archivos" % id)
	for id: String in section("music"):
		if not (section("music")[id] as Dictionary).has("base"):
			problems.append("la pista %s no tiene base" % id)
	for id: String in section("locations"):
		problems.append_array(_validate_location(id, section("locations")[id]))
	for reason: String in section("screens"):
		problems.append_array(_validate_refs("pantalla " + reason, section("screens")[reason]))
	for id: String in section("scenes"):
		problems.append_array(_validate_refs("escena " + id, section("scenes")[id]))
	for name: String in section("events"):
		if not has_sound(event(name)):
			problems.append("el suceso %s usa un efecto desconocido (%s)" % [name, event(name)])
	for key: String in section("transitions"):
		if not has_sound(String(section("transitions")[key])):
			problems.append("la transición %s usa un efecto desconocido" % key)
	for surface: String in section("footsteps").get("surfaces", {}):
		if not has_sound(String(section("footsteps")["surfaces"][surface])):
			problems.append("el suelo %s usa un efecto desconocido" % surface)
	for id: String in location_ids:
		if not section("locations").has(id):
			problems.append("el lugar %s no tiene paisaje sonoro" % id)
	return problems


func _validate_location(id: String, entry: Dictionary) -> Array[String]:
	var problems := _validate_refs("lugar " + id, entry)
	for key in ["layers", "night_layers"]:
		for layer: String in entry.get(key, {}):
			if ambience(layer).is_empty():
				problems.append("lugar %s: ambiente desconocido %s" % [id, layer])
	for emitter: Dictionary in entry.get("emitters", []):
		if ambience(String(emitter.get("ambience", ""))).is_empty():
			problems.append("lugar %s: emisor con ambiente desconocido" % id)
		if (emitter.get("position", []) as Array).size() != 3:
			problems.append("lugar %s: emisor sin posición x, y, z" % id)
	var details: Dictionary = entry.get("details", {})
	for sound_id: String in details.get("sounds", {}):
		if not has_sound(sound_id):
			problems.append("lugar %s: detalle desconocido %s" % [id, sound_id])
	if entry.has("chime") and not has_sound(String(entry["chime"]["sound"])):
		problems.append("lugar %s: campanada desconocida" % id)
	return problems


func _validate_refs(owner: String, entry: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if entry.has("music") and not String(entry["music"]).is_empty() and music(String(entry["music"])).is_empty():
		problems.append("%s: pista desconocida %s" % [owner, entry["music"]])
	for key in ["open", "close", "cue"]:
		if entry.has(key) and not has_sound(String(entry[key])):
			problems.append("%s: efecto desconocido %s" % [owner, entry[key]])
	return problems
