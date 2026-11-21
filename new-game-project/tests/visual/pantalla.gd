extends Node
## Comprobación con ventana real de los modos de pantalla, la resolución y la sincronización
## vertical: aplica cada combinación, espera a que el sistema la asiente y compara el estado real de
## la ventana con lo pedido. Al terminar deja la ventana como estaba.
## Uso:  godot --path . --resolution 1280x720 res://tests/visual/pantalla.tscn
## Imprime una línea OK o FALLO por comprobación y termina con código 1 si alguna falla.

const SETTLE_SECONDS := 0.8

var _failures := 0


func _ready() -> void:
	TestCase.reset_test_settings()
	var window := get_tree().root
	var screen := DisplaySettings.screen_size()
	print("Monitor %d × %d, zona útil %s, modos %s" % [screen.x, screen.y, DisplaySettings.usable_size(), DisplaySettings.available_modes()])
	print("Resoluciones con ventana: %s" % [DisplaySettings.resolutions_for("ventana")])
	var cases := [
		["ventana", Vector2i(1280, 720)],
		["ventana", Vector2i(1024, 576)],
		["sin_bordes", Vector2i(1366, 768)],
		["pantalla_completa", Vector2i(1280, 720)],
		["exclusiva", Vector2i(1280, 720)],
		["ventana", Vector2i(7680, 4320)],
		["ventana", Vector2i(1280, 720)],
	]
	for entry: Array in cases:
		var mode: String = entry[0]
		var asked: Vector2i = entry[1]
		DisplaySettings.apply(window, mode, asked)
		await _settle()
		var state := DisplaySettings.window_state(window)
		var expected := DisplaySettings.fit(asked, mode)
		_check(state["mode"] == mode, "%s: la ventana queda en ese modo (%s)" % [mode, state["mode"]])
		_check(state["size"] == expected, "%s %s: tamaño %s (esperado %s)" % [mode, asked, state["size"], expected])
		_check(window.size.x <= screen.x and window.size.y <= screen.y, "%s: la ventana cabe en el monitor" % mode)
		if not DisplaySettings.is_fullscreen_mode(mode):
			var position := DisplayServer.window_get_position()
			var usable := DisplayServer.screen_get_usable_rect(DisplaySettings.current_screen())
			_check(usable.has_point(position), "%s: la esquina de la ventana está en la zona visible (%s)" % [mode, position])
	for enabled: bool in [true, false]:
		DisplaySettings.apply_vsync(enabled)
		await _settle()
		_check(DisplaySettings.window_state(window)["vsync"] == enabled, "sincronización vertical %s" % ("activada" if enabled else "desactivada"))
	# El flujo completo de Configuración con la ventana real: se prueba el cambio, nadie contesta y
	# se restaura; después se prueba otro y se confirma.
	DisplaySettings.manage_test_window = true
	Settings.set_values({"graficos/modo_ventana": "ventana", "graficos/resolucion": Vector2i(1280, 720)})
	await _settle()
	Settings.request_display_change("sin_bordes", Vector2i(1366, 768), 2.0)
	await _settle()
	_check(DisplaySettings.window_state(window)["mode"] == "sin_bordes", "el cambio se ve antes de confirmarlo")
	_check(ConfirmDialog.is_open(), "con la pregunta en pantalla")
	await get_tree().create_timer(1.6).timeout
	await _settle()
	_check(not ConfirmDialog.is_open(), "sin respuesta, la pregunta se cierra")
	var state := DisplaySettings.window_state(window)
	_check(state["mode"] == "ventana" and state["size"] == Vector2i(1280, 720), "y la ventana vuelve a la anterior (%s %s)" % [state["mode"], state["size"]])
	_check(Settings.get_value("graficos/modo_ventana") == "ventana", "sin guardar el cambio")
	Settings.request_display_change("ventana", Vector2i(1600, 900), 5.0)
	await _settle()
	ConfirmDialog.confirm()
	await _settle()
	_check(DisplaySettings.window_state(window)["size"] == DisplaySettings.fit(Vector2i(1600, 900), "ventana"), "confirmado, se queda")
	_check(Settings.get_value("graficos/resolucion") == Vector2i(1600, 900), "y se guarda")
	Settings.set_values({"graficos/modo_ventana": "ventana", "graficos/resolucion": Vector2i(1280, 720)})
	await _settle()
	DisplaySettings.manage_test_window = false
	print("RESUMEN: %s" % ("todo correcto" if _failures == 0 else "%d fallos" % _failures))
	TestCase.reset_test_settings()
	get_tree().quit(1 if _failures > 0 else 0)


func _settle() -> void:
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK ", message)
	else:
		_failures += 1
		print("FALLO ", message)
