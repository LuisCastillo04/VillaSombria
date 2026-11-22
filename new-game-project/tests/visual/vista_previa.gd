extends TestCase
## Comprueba con ventana que la imagen de cada ranura es la escena real del guardado, y que conserva
## sus colores aunque haya un filtro visual activo (el filtro es de la pantalla, no de la partida).
## Uso:  godot --path . --resolution 1280x720 res://tests/visual/vista_previa.tscn -- --out=C:/ruta
## (--out es opcional: copia allí las imágenes para revisarlas). Sin ventana no hay imagen
## que comprobar, así que no forma parte de las pruebas automáticas.

const STORAGE := "user://pruebas_guardado/vista_previa"


func _ready() -> void:
	SaveSystem.autosave_enabled = false
	SaveSystem.use_storage(STORAGE)
	TestCase.clear_save_storage()
	TestCase.reset_test_settings()
	await _run()
	for failure in failures:
		print("FALLO vista previa: ", failure)
	if failures.is_empty():
		print("VISTA PREVIA correcta")
	TestCase.clear_save_storage()
	TestCase.reset_test_settings()
	get_tree().quit(1 if not failures.is_empty() else 0)


func _run() -> void:
	var game := await make_game()
	await game.go_to("plaza", "desde_cafe")
	await _settle()
	await save_and_wait("manual_1")
	GameState.set_flag("llamada_atendida")
	await game.go_to("mansion", "desde_plaza")
	await _settle()
	await save_and_wait("manual_2")
	# Con la pausa y la lista de ranuras en pantalla, la imagen debe ser la misma escena; y con el
	# modo noir activo, también sus colores.
	Settings.set_value(VisualFilters.SETTING_KEY, "noir")
	var pause: PauseMenu = game.get_node("PauseMenu")
	pause.open()
	(pause.get_node("Root/Center/Panel/Box/Save") as Button).pressed.emit()
	await get_tree().process_frame
	await save_and_wait("manual_3")
	pause.close()

	var images := {}
	for slot_id: String in ["manual_1", "manual_2", "manual_3"]:
		var texture := SaveSystem.get_slot_preview(slot_id)
		check(texture != null, "%s tiene imagen" % slot_id)
		if texture == null:
			return
		var image := texture.get_image()
		check_equal(image.get_size(), SavePreview.SIZE, "tamaño de la imagen de %s" % slot_id)
		check(_spread(image) > 0.02, "la imagen de %s no es un color plano" % slot_id)
		images[slot_id] = image
	_export(images)
	var between_places := _difference(images["manual_1"], images["manual_2"])
	var with_pause := _difference(images["manual_2"], images["manual_3"])
	print("diferencia plaza/mansión=%.3f  mansión/mansión con pausa=%.3f" % [between_places, with_pause])
	check(with_pause < 0.04, "la pausa y la lista de ranuras no aparecen en la imagen")
	check(between_places > with_pause * 3.0, "cada imagen muestra el lugar de su guardado")
	var color_before := _chroma(images["manual_2"])
	var color_noir := _chroma(images["manual_3"])
	print("color de la imagen sin filtro=%.3f  con el modo noir activo=%.3f" % [color_before, color_noir])
	check(color_noir > 0.02 and color_noir > color_before * 0.7, "con el modo noir activo, la imagen de la ranura conserva sus colores")

	var path := SaveSystem.get_preview_path("manual_1")
	var bytes := FileAccess.get_file_as_bytes(path)
	bytes[bytes.size() / 2] = bytes[bytes.size() / 2] ^ 0xFF
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	SaveSystem.use_storage(STORAGE)
	check(SaveSystem.get_slot_preview("manual_1") == null, "una imagen dañada se sustituye por el marcador")
	SaveSystem.delete_slot("manual_2")
	check(not FileAccess.file_exists(SaveSystem.get_preview_path("manual_2")), "eliminar la partida elimina su imagen")
	game.queue_free()
	await get_tree().process_frame


func _settle() -> void:
	for frame in 30:
		await get_tree().process_frame


## Diferencia media entre dos imágenes reducidas, de 0 (iguales) a 1.
func _difference(first: Image, second: Image) -> float:
	var a := _reduced(first)
	var b := _reduced(second)
	var total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			total += absf(a.get_pixel(x, y).get_luminance() - b.get_pixel(x, y).get_luminance())
	return total / float(a.get_width() * a.get_height())


## Color medio de una imagen: diferencia entre su canal más alto y el más bajo (0 en blanco y negro).
func _chroma(image: Image) -> float:
	var reduced := _reduced(image)
	var total := 0.0
	for y in reduced.get_height():
		for x in reduced.get_width():
			var pixel := reduced.get_pixel(x, y)
			total += maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b))
	return total / float(reduced.get_width() * reduced.get_height())


func _spread(image: Image) -> float:
	var reduced := _reduced(image)
	var low := 1.0
	var high := 0.0
	for y in reduced.get_height():
		for x in reduced.get_width():
			var value := reduced.get_pixel(x, y).get_luminance()
			low = minf(low, value)
			high = maxf(high, value)
	return high - low


func _reduced(image: Image) -> Image:
	var copy := image.duplicate() as Image
	copy.convert(Image.FORMAT_RGB8)
	copy.resize(48, 27, Image.INTERPOLATE_BILINEAR)
	return copy


func _export(images: Dictionary) -> void:
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	if out.is_empty():
		return
	for slot_id: String in images:
		(images[slot_id] as Image).save_png(out.path_join("vista_previa_%s.png" % slot_id))
