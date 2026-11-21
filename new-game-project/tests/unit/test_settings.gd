extends TestCase
## Preferencias persistentes: valores por defecto, validación, escritura independiente de cada
## clave, secciones ajenas conservadas, migración del formato anterior y valores dañados.
##
## Un archivo ilegible se aparta con el sufijo `.danado` y se usan los valores por defecto; no se
## prueba aquí porque el motor imprime un `ERROR:` al analizarlo y `verificar.ps1` lo tomaría por un
## fallo.

const FILE := "user://pruebas_guardado/ajustes_prueba.cfg"

var _changes: Array = []


func before_each() -> void:
	_remove(FILE)
	_remove(FILE + Settings.DAMAGED_SUFFIX)
	_changes.clear()


func after_each() -> void:
	if Settings.changed.is_connected(_on_changed):
		Settings.changed.disconnect(_on_changed)
	_remove(FILE)
	_remove(FILE + Settings.DAMAGED_SUFFIX)
	TestCase.reset_test_settings()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write_raw(text: String) -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _stored() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(FILE)
	return config


func _on_changed(key: String, value: Variant) -> void:
	_changes.append([key, value])


func test_without_file_every_setting_has_its_default() -> void:
	Settings.use_file(FILE)
	check_equal(Settings.get_load_report()["file"], "missing", "sin archivo se informa")
	for key in SettingsSchema.keys():
		check_equal(Settings.get_value(key), SettingsSchema.default_value(key), "%s toma su valor por defecto" % key)
	check(not FileAccess.file_exists(FILE), "leer no crea el archivo")
	check(not Settings.fullscreen and not Settings.vsync, "ventana y sin sincronización vertical")
	check_equal(Settings.get_value("jugabilidad/velocidad_texto"), "normal", "texto a velocidad normal")
	check_equal(Settings.get_value("jugabilidad/confirmaciones"), true, "con confirmaciones")
	check_equal(Settings.get_value("graficos/calidad_iluminacion"), "alto", "calidad alta: el aspecto original")


func test_categories_are_the_sections_of_the_file() -> void:
	check_equal(SettingsSchema.SECTIONS, ["audio", "graficos", "jugabilidad", "accesibilidad", "controles"] as Array[String], "cinco categorías")
	for key in SettingsSchema.keys():
		check(SettingsSchema.section_of(key) in SettingsSchema.SECTIONS, "%s pertenece a una categoría" % key)
	check(SettingsSchema.keys_in("graficos").size() == 5, "gráficos: modo, resolución, sincronización, iluminación y efectos")
	check(SettingsSchema.keys_in("accesibilidad").size() == 4, "accesibilidad: letra, contraste, subtítulos y movimiento")


func test_each_change_is_validated_applied_saved_and_announced() -> void:
	Settings.use_file(FILE)
	Settings.changed.connect(_on_changed)
	check(Settings.set_value("jugabilidad/velocidad_texto", "rapido"), "un valor admitido se acepta")
	check_equal(Settings.get_value("jugabilidad/velocidad_texto"), "rapido", "y queda vigente")
	check_equal(_stored().get_value("jugabilidad", "velocidad_texto", ""), "rapido", "y se guarda en su sección")
	check_equal(_stored().get_value("meta", "version", 0), SettingsSchema.VERSION, "con la versión del formato")
	check_equal(_changes, [["jugabilidad/velocidad_texto", "rapido"]], "y se anuncia una vez")
	check(Settings.set_value("jugabilidad/velocidad_texto", "rapido"), "repetir el valor no es un error")
	check_equal(_changes.size(), 1, "pero no se anuncia de nuevo")


func test_invalid_values_are_rejected_and_keep_the_previous_one() -> void:
	Settings.use_file(FILE)
	Settings.set_value("graficos/calidad_efectos", "medio")
	check(not Settings.set_value("graficos/calidad_efectos", "ultra"), "una opción inexistente se rechaza")
	check(not Settings.set_value("graficos/calidad_efectos", 2), "un tipo equivocado también")
	check(not Settings.set_value("accesibilidad/contraste_alto", "sí"), "un interruptor sólo admite sí o no")
	check(not Settings.set_value("graficos/resolucion", Vector2i(320, 200)), "una resolución demasiado pequeña se rechaza")
	check(not Settings.set_value("no/existe", true), "una clave desconocida se rechaza")
	check_equal(Settings.get_value("graficos/calidad_efectos"), "medio", "el valor anterior se conserva")
	Settings.set_volume("Musica", 1.7)
	check(is_equal_approx(Settings.volumes["Musica"], 1.0), "un volumen fuera de rango se ajusta al máximo")
	check(Settings.set_value("graficos/resolucion", "1600x900"), "la resolución se admite como texto")
	check_equal(Settings.get_value("graficos/resolucion"), Vector2i(1600, 900), "y se guarda como tamaño")


func test_writing_one_setting_keeps_the_rest_of_the_file() -> void:
	_write_raw("[meta]\nversion=2\n\n[controles]\ninteract=\"F\"\n\n[jugabilidad]\navance_automatico=true\n")
	Settings.use_file(FILE)
	check_equal(Settings.get_value("jugabilidad/avance_automatico"), true, "se lee lo guardado")
	Settings.set_value("accesibilidad/subtitulos", false)
	var stored := _stored()
	check_equal(stored.get_value("controles", "interact", ""), "F", "la sección de controles no se toca")
	check_equal(stored.get_value("jugabilidad", "avance_automatico", false), true, "ni las demás preferencias")
	check_equal(stored.get_value("accesibilidad", "subtitulos", true), false, "sólo cambia la clave escrita")


func test_damaged_values_fall_back_to_defaults_and_are_repaired() -> void:
	_write_raw("[meta]\nversion=2\n\n[graficos]\ncalidad_iluminacion=\"cinematica\"\nvsync=7\nresolucion=Vector2i(99999, 5)\n\n[audio]\nMusica=0.3\n")
	Settings.use_file(FILE)
	var report := Settings.get_load_report()
	check_equal(Settings.get_value("graficos/calidad_iluminacion"), "alto", "una calidad desconocida vuelve a Alto")
	check_equal(Settings.get_value("graficos/vsync"), false, "un interruptor imposible vuelve a su valor")
	check_equal(Settings.get_value("graficos/resolucion"), Vector2i(1280, 720), "y una resolución imposible también")
	check(is_equal_approx(Settings.volumes["Musica"], 0.3), "lo válido se respeta")
	check_equal((report["rejected"] as Array).size(), 3, "se informa de los tres valores descartados")
	check_equal(_stored().get_value("graficos", "calidad_iluminacion", ""), "alto", "y el archivo queda corregido")


func test_previous_format_is_migrated() -> void:
	_write_raw("[volumen]\nMaster=0.5\nMusica=0.25\nEfectos=0.9\nAmbiente=0.0\n\n[pantalla]\ncompleta=true\nvsync=true\n")
	Settings.use_file(FILE)
	check(Settings.get_load_report()["migrated"], "se reconoce el formato anterior")
	check(is_equal_approx(Settings.volumes["Master"], 0.5) and is_equal_approx(Settings.volumes["Ambiente"], 0.0), "los volúmenes se conservan")
	check_equal(Settings.get_value("graficos/modo_ventana"), "pantalla_completa", "pantalla completa pasa a ser un modo de ventana")
	check(Settings.fullscreen and Settings.vsync, "y la sincronización vertical se mantiene")
	var stored := _stored()
	check(not stored.has_section("volumen") and not stored.has_section("pantalla"), "las secciones antiguas se retiran")
	check(is_equal_approx(float(stored.get_value("audio", "Musica", -1.0)), 0.25), "y su contenido pasa a las nuevas")
	check_equal(stored.get_value("meta", "version", 0), SettingsSchema.VERSION, "con la versión actual")


func test_settings_survive_a_reload() -> void:
	Settings.use_file(FILE)
	Settings.set_value("graficos/modo_ventana", "sin_bordes")
	Settings.set_value("jugabilidad/avance_automatico", true)
	Settings.set_value("accesibilidad/tamano_letra", "muy_grande")
	Settings.set_volume("Efectos", 0.4)
	# Otro arranque: se vuelve a leer el mismo archivo desde cero.
	Settings.use_file(FILE)
	check_equal(Settings.get_load_report()["file"], "loaded", "se lee el archivo")
	check_equal(Settings.get_value("graficos/modo_ventana"), "sin_bordes", "el modo de ventana persiste")
	check_equal(Settings.get_value("jugabilidad/avance_automatico"), true, "el avance automático persiste")
	check_equal(Settings.get_value("accesibilidad/tamano_letra"), "muy_grande", "el tamaño de letra persiste")
	check(is_equal_approx(Settings.volumes["Efectos"], 0.4), "y el volumen")


func test_restore_defaults() -> void:
	Settings.use_file(FILE)
	Settings.set_value("graficos/calidad_efectos", "bajo")
	Settings.set_value("accesibilidad/contraste_alto", true)
	Settings.restore_defaults(["graficos/calidad_efectos"] as Array[String])
	check_equal(Settings.get_value("graficos/calidad_efectos"), "alto", "la clave indicada vuelve a su valor")
	check_equal(Settings.get_value("accesibilidad/contraste_alto"), true, "las demás no se tocan")
	Settings.restore_defaults()
	check_equal(Settings.get_value("accesibilidad/contraste_alto"), false, "sin claves, vuelven todas")


func test_settings_do_not_belong_to_a_save_slot() -> void:
	Settings.use_file(FILE)
	Settings.set_value("jugabilidad/velocidad_texto", "lento")
	GameState.reset()
	GameClock.reset()
	var game := await make_game()
	check(await save_and_wait("manual_1"), "se guarda una partida")
	var text := FileAccess.get_file_as_string(SaveSystem.get_slot_path("manual_1"))
	check(not text.contains("velocidad_texto"), "la partida no lleva las preferencias")
	game.queue_free()
	await get_tree().process_frame
	check_equal(Settings.get_value("jugabilidad/velocidad_texto"), "lento", "y siguen igual al salir de la partida")
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
