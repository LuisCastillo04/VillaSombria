extends TestCase
## Escritura segura de archivos y validación del formato de las partidas.

const DIR := "user://pruebas_guardado/formato"
const PATH := DIR + "/partida.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveFile.remove(PATH)


func after_each() -> void:
	SaveFile.remove(PATH)


func _valid_document() -> Dictionary:
	return SaveFormat.build(
		{"kind": "manual", "saved_at": 1763500000, "reason": "manual"},
		{
			"state": {
				"flags": ["llamada_atendida"],
				"clues": ["reloj_despacho"],
				"testimonies": [],
				"deductions": [],
				"asked_topics": [],
				"hypotheses": {},
				"location_id": "mansion",
				"spawn_id": "desde_plaza",
				"accusation_attempts": 0,
				"play_seconds": 120.5,
			},
			"clock": {"day": 2, "minutes": 600},
			"player": {"location_id": "mansion", "position": [1.0, 0.1, -2.0], "yaw": 0.5},
		}
	)


func _parse(document: Dictionary) -> Dictionary:
	return SaveFormat.parse(JSON.stringify(document))


func test_atomic_write_leaves_only_the_final_file() -> void:
	check_equal(SaveFile.write_atomic(PATH, "primera"), OK, "la escritura funciona")
	check_equal(SaveFile.write_atomic(PATH, "segunda"), OK, "la sobrescritura funciona")
	check_equal(FileAccess.get_file_as_string(PATH), "segunda", "queda el contenido nuevo")
	check(not FileAccess.file_exists(PATH + SaveFile.TEMP_SUFFIX), "no queda el temporal")
	check(not FileAccess.file_exists(PATH + SaveFile.BACKUP_SUFFIX), "no queda la copia")


func test_interrupted_write_is_recovered_from_the_backup() -> void:
	SaveFile.write_atomic(PATH, "partida anterior")
	# Simula un corte entre los dos renombrados: sólo queda la copia y un temporal.
	DirAccess.rename_absolute(PATH, PATH + SaveFile.BACKUP_SUFFIX)
	var temp := FileAccess.open(PATH + SaveFile.TEMP_SUFFIX, FileAccess.WRITE)
	temp.store_string("{incompleto")
	temp.close()
	check(SaveFile.exists(PATH), "la partida sigue existiendo")
	var result := SaveFile.read_text(PATH)
	check_equal(result["error"], OK, "se puede leer")
	check_equal(result["text"], "partida anterior", "se recupera la versión anterior")


func test_remove_deletes_every_trace() -> void:
	SaveFile.write_atomic(PATH, "algo")
	var backup := FileAccess.open(PATH + SaveFile.BACKUP_SUFFIX, FileAccess.WRITE)
	backup.store_string("copia")
	backup.close()
	check_equal(SaveFile.remove(PATH), OK, "se borra sin errores")
	check(not SaveFile.exists(PATH), "no queda nada")


func test_binary_files_are_written_atomically() -> void:
	var data := PackedByteArray([0, 255, 13, 10, 42])
	check_equal(SaveFile.write_atomic_bytes(PATH, data), OK, "se escriben bytes")
	check_equal(FileAccess.get_file_as_bytes(PATH), data, "sin alterar ninguno")
	check_equal(SaveFile.sha256_hex(data).length(), 64, "con una huella SHA-256")
	check(SaveFile.sha256_hex(data) != SaveFile.sha256_hex(PackedByteArray([0, 255])), "distinta para datos distintos")


func test_preview_references_are_validated() -> void:
	var document := _valid_document()
	document["meta"]["preview"] = {"file": "manual_1.jpg", "sha256": "a".repeat(64)}
	check(_parse(document)["document"]["meta"].has("preview"), "una referencia correcta se conserva")
	for bad: Variant in [
		{"file": "../ajustes.cfg", "sha256": "a".repeat(64)},
		{"file": "manual_1.jpg", "sha256": "corta"},
		"manual_1.jpg",
	]:
		document["meta"]["preview"] = bad
		var result := _parse(document)
		check_equal(result["status"], SaveFormat.Status.OK, "la partida sigue siendo válida")
		check(not result["document"]["meta"].has("preview"), "y la referencia dudosa se descarta: %s" % str(bad))


func test_missing_file_reports_not_found() -> void:
	check_equal(SaveFile.read_text(PATH)["error"], ERR_FILE_NOT_FOUND, "sin archivo")


func test_valid_document_round_trips() -> void:
	var result := _parse(_valid_document())
	check_equal(result["status"], SaveFormat.Status.OK, "un documento válido se acepta")
	var sections: Dictionary = result["document"]["sections"]
	check_equal(sections["clock"]["day"], 2, "los números vuelven como enteros")
	check(sections["clock"]["day"] is int, "tipo entero")
	check(sections.has("player"), "conserva la posición")


func test_broken_json_is_corrupt() -> void:
	var result := SaveFormat.parse("{\"version\": 2, ")
	check_equal(result["status"], SaveFormat.Status.CORRUPT, "texto truncado")
	check(not (result["error"] as String).is_empty(), "explica el problema")


func test_future_version_is_incompatible() -> void:
	var document := _valid_document()
	document["version"] = SaveFormat.VERSION + 1
	check_equal(_parse(document)["status"], SaveFormat.Status.INCOMPATIBLE, "versión más reciente")


func test_foreign_json_is_rejected() -> void:
	var result := SaveFormat.parse(JSON.stringify({"format": "otro_juego", "version": 2}))
	check_equal(result["status"], SaveFormat.Status.CORRUPT, "otro formato")


func test_wrong_types_are_rejected() -> void:
	var document := _valid_document()
	document["sections"]["state"]["clues"] = "reloj_despacho"
	check_equal(_parse(document)["status"], SaveFormat.Status.CORRUPT, "una lista que no es lista")
	document = _valid_document()
	document["sections"]["clock"]["day"] = 99
	check_equal(_parse(document)["status"], SaveFormat.Status.CORRUPT, "un día imposible")
	document = _valid_document()
	document["meta"]["kind"] = "trampa"
	check_equal(_parse(document)["status"], SaveFormat.Status.CORRUPT, "un tipo de ranura desconocido")
	document = _valid_document()
	(document["sections"] as Dictionary).erase("clock")
	check_equal(_parse(document)["status"], SaveFormat.Status.CORRUPT, "falta una sección obligatoria")


func test_unknown_references_are_dropped_not_fatal() -> void:
	var document := _valid_document()
	document["sections"]["state"]["clues"] = ["reloj_despacho", "pista_inexistente", "reloj_despacho"]
	var result := _parse(document)
	check_equal(result["status"], SaveFormat.Status.OK, "la partida sigue siendo válida")
	check_equal(result["document"]["sections"]["state"]["clues"], ["reloj_despacho"], "sin desconocidas ni duplicadas")


func test_unknown_location_is_incompatible() -> void:
	var document := _valid_document()
	document["sections"]["state"]["location_id"] = "faro"
	check_equal(_parse(document)["status"], SaveFormat.Status.INCOMPATIBLE, "un lugar que no existe")


func test_invalid_pose_falls_back_to_the_entrance() -> void:
	var document := _valid_document()
	document["sections"]["player"]["position"] = [1.0, "dos"]
	var result := _parse(document)
	check_equal(result["status"], SaveFormat.Status.OK, "se puede cargar igualmente")
	check(not (result["document"]["sections"] as Dictionary).has("player"), "sin posición inválida")


func test_version_one_is_migrated() -> void:
	var legacy := {
		"version": 1,
		"state": {"flags": ["llamada_atendida"], "clues": [], "testimonies": [], "deductions": [],
			"asked_topics": [], "hypotheses": {}, "location_id": "cafe", "spawn_id": "desde_plaza",
			"accusation_attempts": 0},
		"clock": {"day": 1, "minutes": 1410},
	}
	var result := SaveFormat.parse(JSON.stringify(legacy), {"saved_at": 1763400000})
	check_equal(result["status"], SaveFormat.Status.OK, "la versión 1 se acepta")
	var document: Dictionary = result["document"]
	check_equal(document["version"], SaveFormat.VERSION, "se convierte a la versión actual")
	check_equal(document["meta"]["saved_at"], 1763400000, "la fecha sale del archivo original")
	check_equal(document["meta"]["reason"], "importada", "se marca como importada")
	check(not (document["sections"]["state"] as Dictionary).has("play_seconds"), "no inventa el tiempo jugado")
