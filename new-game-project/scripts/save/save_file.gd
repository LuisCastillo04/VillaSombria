class_name SaveFile
extends RefCounted
## Acceso seguro a los archivos de guardado. Cada escritura va primero a un archivo
## temporal, se relee para comprobarla y sólo entonces sustituye al definitivo; mientras
## tanto, la versión anterior se conserva como copia. No toca el árbol de escenas, así que
## puede ejecutarse en un hilo secundario.

const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"


## Escribe `text` en `path` sin dejar nunca el archivo definitivo a medias.
static func write_atomic(path: String, text: String) -> Error:
	var temp_path := path + TEMP_SUFFIX
	var backup_path := path + BACKUP_SUFFIX
	var error := _write_verified(temp_path, text)
	if error != OK:
		_remove_if_exists(temp_path)
		return error
	var had_previous := FileAccess.file_exists(path)
	if had_previous:
		_remove_if_exists(backup_path)
		error = DirAccess.rename_absolute(path, backup_path)
		if error != OK:
			_remove_if_exists(temp_path)
			return error
	error = DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		if had_previous:
			DirAccess.rename_absolute(backup_path, path)
		_remove_if_exists(temp_path)
		return error
	if had_previous:
		_remove_if_exists(backup_path)
	return OK


## Lee el archivo completo. Devuelve {"error": Error, "text": String}.
static func read_text(path: String) -> Dictionary:
	recover(path)
	if not FileAccess.file_exists(path):
		return {"error": ERR_FILE_NOT_FOUND, "text": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error(), "text": ""}
	return {"error": OK, "text": file.get_as_text()}


## Una escritura interrumpida entre los dos renombrados deja sólo la copia: se restaura.
static func recover(path: String) -> void:
	var backup_path := path + BACKUP_SUFFIX
	if not FileAccess.file_exists(path) and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(backup_path, path)


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BACKUP_SUFFIX)


static func has_backup(path: String) -> bool:
	return FileAccess.file_exists(path + BACKUP_SUFFIX)


## Borra el archivo junto con su temporal y su copia.
static func remove(path: String) -> Error:
	var result := OK
	for candidate: String in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		var error := _remove_if_exists(candidate)
		if error != OK:
			result = error
	return result


static func _write_verified(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	# Releer evita dar por buena una escritura incompleta, por ejemplo con el disco lleno.
	if FileAccess.get_file_as_string(path) != text:
		return ERR_FILE_CORRUPT
	return OK


static func _remove_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)
