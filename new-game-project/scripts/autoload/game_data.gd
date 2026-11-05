extends Node
## Carga los archivos de `data/`. Toda la historia vive allí, separada del código.

const DATA_ROOT := "res://data/"

var characters: Dictionary = {}
var clues: Dictionary = {}
var testimonies: Dictionary = {}
var deductions: Dictionary = {}
var schedules: Dictionary = {}
var locations: Dictionary = {}
var story: Dictionary = {}
var scenes: Dictionary = {}

var _dialogues: Dictionary = {}


func _ready() -> void:
	characters = _read("characters.json")
	clues = _read("clues.json")
	testimonies = _read("testimonies.json")
	deductions = _read("deductions.json")
	schedules = _read("schedules.json")
	locations = _read("locations.json")
	story = _read("story.json")
	scenes = _read("dialogues/escenas.json")


func _exit_tree() -> void:
	MaterialLibrary.clear()
	UiTheme.clear()


func get_dialogue(npc_id: String) -> Dictionary:
	if not _dialogues.has(npc_id):
		_dialogues[npc_id] = _read("dialogues/%s.json" % npc_id)
	return _dialogues[npc_id]


func get_character_name(character_id: String) -> String:
	var character: Dictionary = characters.get(character_id, {})
	return character.get("name", "")


func get_suspects() -> Array[String]:
	var suspects: Array[String] = []
	for character_id: String in characters:
		if bool(characters[character_id].get("suspect", false)):
			suspects.append(character_id)
	return suspects


func _read(relative_path: String) -> Dictionary:
	var path := DATA_ROOT + relative_path
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("No se pudo leer %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("JSON inválido en %s" % path)
		return {}
	return parsed
