extends Node
## Preferencias al cerrar y volver a abrir el juego, en dos procesos de Godot distintos:
##   godot --headless --path . res://tests/persistencia/ajustes.tscn -- --fase=guardar
##   godot --headless --path . res://tests/persistencia/ajustes.tscn -- --fase=comprobar
## La primera fase cambia preferencias de todas las categorías y termina; la segunda, en un proceso
## nuevo, las lee como al arrancar (`Settings.load_settings` y `apply_all`) y comprueba que siguen y
## que se aplican. Usa un archivo propio: nunca toca los ajustes del jugador.

const FILE := "user://pruebas_guardado/ajustes_reinicio.cfg"
const CHANGES := {
	"audio/Musica": 0.35,
	"graficos/vsync": true,
	"graficos/calidad_iluminacion": "bajo",
	"graficos/calidad_efectos": "medio",
	"graficos/resolucion": Vector2i(1366, 768),
	"jugabilidad/velocidad_texto": "rapido",
	"jugabilidad/avance_automatico": true,
	"jugabilidad/confirmaciones": false,
	"jugabilidad/sistema_dialogos": "unico",
	"filtros/activo": "sepia",
	"accesibilidad/tamano_letra": "grande",
	"accesibilidad/contraste_alto": true,
	"accesibilidad/subtitulos": false,
	"accesibilidad/movimiento_reducido": true,
}

var _failures := 0


func _ready() -> void:
	var phase := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fase="):
			phase = argument.trim_prefix("--fase=")
	match phase:
		"guardar":
			_save()
		"comprobar":
			_check_loaded()
		_:
			print("FALLO falta --fase=guardar o --fase=comprobar")
			_failures += 1
	print("RESUMEN: %s" % ("todo correcto" if _failures == 0 else "%d fallos" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(FILE.get_base_dir())
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	Settings.use_file(FILE)
	for key: String in CHANGES:
		_check(Settings.set_value(key, CHANGES[key]), "se acepta %s" % key)
	_check(FileAccess.file_exists(FILE), "las preferencias quedan escritas")


func _check_loaded() -> void:
	_check(FileAccess.file_exists(FILE), "el archivo de la fase anterior existe")
	# Un mundo que ya estaba en pantalla toma el filtro al leer el archivo, y uno nuevo al aparecer.
	var shown_before := _make_post()
	Settings.use_file(FILE)
	for key: String in CHANGES:
		var value: Variant = Settings.get_value(key)
		var same: bool = is_equal_approx(float(value), float(CHANGES[key])) if typeof(value) == TYPE_FLOAT else value == CHANGES[key]
		_check(same, "%s sigue valiendo %s (%s)" % [key, CHANGES[key], value])
	_check(is_equal_approx(get_tree().root.content_scale_factor, UiAccessibility.TEXT_SCALES["grande"]), "el tamaño de letra se aplica al arrancar")
	_check(Settings.is_high_contrast_applied(), "el contraste aumentado también")
	_check(get_tree().root.positional_shadow_atlas_size < int(ProjectSettings.get_setting(GraphicsQuality.POSITIONAL_SIZE)), "y la calidad de iluminación")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica")), linear_to_db(0.35)), "y el volumen")
	_check(not ConfirmDialog.confirmations_enabled(), "las confirmaciones siguen desactivadas")
	_check(shown_before.get_visual_filter() == "sepia", "el filtro visual se aplica al mundo que ya estaba")
	var shown_after := _make_post()
	_check(shown_after.get_visual_filter() == "sepia", "y al que aparece después")
	shown_before.queue_free()
	shown_after.queue_free()
	DirAccess.remove_absolute(FILE)
	TestCase.reset_test_settings()


func _make_post() -> PostFx:
	var post: PostFx = (load("res://scenes/world/post_fx.tscn") as PackedScene).instantiate()
	add_child(post)
	return post


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK ", message)
	else:
		_failures += 1
		print("FALLO ", message)
