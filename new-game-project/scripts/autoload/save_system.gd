extends Node
## Guardado y carga de partidas en un archivo JSON legible del directorio de usuario.

const SAVE_VERSION := 1

## Ruta del archivo. Las pruebas la redirigen para no tocar la partida real.
var save_path := "user://partida.json"
## Pide a la escena de juego que cargue la partida al arrancar.
var load_requested := false
## El guardado automático se puede desactivar durante las pruebas.
var autosave_enabled := true


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo escribir la partida: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"state": GameState.to_dict(),
		"clock": GameClock.to_dict(),
	}, "\t"))
	return true


func autosave() -> void:
	if autosave_enabled:
		save_game()


## Restaura la partida. Devuelve false, sin alterar nada, si el archivo no es válido.
func load_game() -> bool:
	var data := read_save()
	if data.is_empty():
		return false
	GameState.from_dict(data["state"])
	GameClock.from_dict(data["clock"])
	return true


## Lee y valida el archivo sin aplicarlo.
func read_save() -> Dictionary:
	if not has_save():
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK or not json.data is Dictionary:
		push_warning("Partida guardada ilegible.")
		return {}
	var data: Dictionary = json.data
	if int(data.get("version", 0)) != SAVE_VERSION or not data.has("state") or not data.has("clock"):
		push_warning("Partida guardada incompatible.")
		return {}
	return data


## Descripción breve para el menú, como «Día 2 · 14:30».
func describe_save() -> String:
	var data := read_save()
	if data.is_empty():
		return ""
	var clock: Dictionary = data["clock"]
	var minutes := int(clock["minutes"])
	return "Día %d · %02d:%02d" % [int(clock["day"]), minutes / 60, minutes % 60]


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
