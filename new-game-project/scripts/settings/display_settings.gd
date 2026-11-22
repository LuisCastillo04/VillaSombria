class_name DisplaySettings
extends RefCounted
## Modo de ventana, resolución y sincronización vertical aplicados a la ventana real.
##
## La resolución lógica del juego no cambia nunca: el lienzo sigue siendo de 1920 × 1080 con
## `canvas_items` y `expand`, así que la interfaz y la escena se escalan con la ventana sin
## deformarse ni recortarse. Lo que cambia es el tamaño de la ventana en los modos con ventana y
## cómo ocupa el monitor en los de pantalla completa, donde manda la resolución del monitor (Godot
## 4 no cambia el modo de vídeo del sistema, ni siquiera en pantalla completa exclusiva).
##
## Sólo se ofrecen tamaños que caben en el monitor donde está la ventana, y la ventana nunca baja
## de `MIN_WINDOW`: ninguna combinación deja los menús fuera de la pantalla.

const MODES: Array[String] = ["ventana", "sin_bordes", "pantalla_completa", "exclusiva"]
const FULLSCREEN_MODES: Array[String] = ["pantalla_completa", "exclusiva"]
## Ventana más pequeña que se permite, también al arrastrar sus bordes.
const MIN_WINDOW := Vector2i(1024, 576)
## Sitio que se reserva a la barra de título y a los bordes al comprobar si una ventana cabe.
const DECORATION_ALLOWANCE := Vector2i(16, 40)
## Tamaños habituales de ventana, de menor a mayor.
const STANDARD_SIZES: Array[Vector2i] = [
	Vector2i(1024, 576), Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1280, 800),
	Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1680, 1050),
	Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(2560, 1440),
	Vector2i(2560, 1600), Vector2i(3440, 1440), Vector2i(3840, 2160),
]
## Argumento (tras `--`) para que el juego respete la ventana pedida en la línea de órdenes.
const KEEP_WINDOW_ARG := "--respetar-ventana"

## Hace que `Settings` maneje la ventana también en una escena de prueba (la comprobación con
## ventana real de `tests/visual/pantalla.tscn`).
static var manage_test_window := false


static func is_fullscreen_mode(mode: String) -> bool:
	return mode in FULLSCREEN_MODES


## Si hay una ventana real que manejar (no la hay al ejecutar sin pantalla).
static func has_window() -> bool:
	return DisplayServer.get_name() != "headless"


## Modos que ofrece esta plataforma. En un ordenador, los cuatro; en otras, sólo pantalla completa.
static func available_modes() -> Array[String]:
	if OS.has_feature("pc"):
		return MODES.duplicate()
	var only: Array[String] = ["pantalla_completa"]
	return only


## Monitor en el que está la ventana.
static func current_screen() -> int:
	return DisplayServer.window_get_current_screen() if has_window() else 0


## Resolución del monitor de la ventana. Sin pantalla, la del lienzo lógico.
static func screen_size() -> Vector2i:
	if not has_window():
		return Vector2i(1920, 1080)
	return DisplayServer.screen_get_size(current_screen())


## Espacio del monitor que deja libre la barra de tareas.
static func usable_size() -> Vector2i:
	if not has_window():
		return Vector2i(1920, 1040)
	return DisplayServer.screen_get_usable_rect(current_screen()).size


## Mayor tamaño de ventana que admite un modo en este monitor.
static func size_limit(mode: String) -> Vector2i:
	match mode:
		"ventana":
			return usable_size() - DECORATION_ALLOWANCE
		"sin_bordes":
			return screen_size()
	return screen_size()


## Tamaños habituales que caben en `limit`, de menor a mayor. Si el monitor es tan pequeño que no
## cabe ninguno, queda el mínimo.
static func sizes_fitting(limit: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for size in STANDARD_SIZES:
		if size.x <= limit.x and size.y <= limit.y:
			found.append(size)
	if found.is_empty():
		found.append(MIN_WINDOW)
	return found


## Resoluciones que se pueden elegir en un modo: en los de ventana, las que caben en el monitor; en
## los de pantalla completa, sólo la del monitor.
static func resolutions_for(mode: String) -> Array[Vector2i]:
	if is_fullscreen_mode(mode):
		var only: Array[Vector2i] = [screen_size()]
		return only
	var found := sizes_fitting(size_limit(mode))
	# En una ventana sin bordes también se ofrece exactamente el tamaño del monitor.
	if mode == "sin_bordes" and not found.has(screen_size()):
		found.append(screen_size())
	return found


## Resolución que se usará de verdad: la pedida si cabe; si no, la mayor de la lista que no la
## supera, y como último recurso la más pequeña.
static func fit(size: Vector2i, mode: String) -> Vector2i:
	var options := resolutions_for(mode)
	if options.has(size):
		return size
	var best := options[0]
	for option in options:
		if option.x <= size.x and option.y <= size.y and option.x * option.y >= best.x * best.y:
			best = option
	return best


## Aplica el modo y el tamaño a la ventana. En los modos con ventana, la centra en su monitor.
static func apply(window: Window, mode: String, size: Vector2i) -> void:
	if not has_window() or window == null:
		return
	window.min_size = MIN_WINDOW
	match mode:
		"pantalla_completa":
			window.borderless = false
			window.mode = Window.MODE_FULLSCREEN
		"exclusiva":
			window.borderless = false
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			var target := fit(size, mode)
			if window.mode != Window.MODE_WINDOWED:
				window.mode = Window.MODE_WINDOWED
			window.borderless = mode == "sin_bordes"
			_place(window, target)
			# Al salir de pantalla completa el sistema restaura el tamaño anterior un instante
			# después: se vuelve a colocar cuando ya lo ha hecho.
			(func() -> void: _place(window, target)).call_deferred()


static func apply_vsync(enabled: bool) -> void:
	if has_window():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)


## Estado real de la ventana, para comprobar que lo aplicado es lo pedido.
static func window_state(window: Window) -> Dictionary:
	var mode := "ventana"
	match window.mode:
		Window.MODE_FULLSCREEN:
			mode = "pantalla_completa"
		Window.MODE_EXCLUSIVE_FULLSCREEN:
			mode = "exclusiva"
		_:
			mode = "sin_bordes" if window.borderless else "ventana"
	var vsync := has_window() and DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	return {"mode": mode, "size": window.size, "vsync": vsync}


## Si la ventana la decide quien lanzó el juego: las escenas de prueba y de captura (las de
## `res://tests/`) fijan su tamaño con `--resolution`, y cualquier escena lo hace con `--respetar-ventana`.
static func is_window_fixed(tree: SceneTree) -> bool:
	if OS.get_cmdline_user_args().has(KEEP_WINDOW_ARG):
		return true
	if manage_test_window:
		return false
	var scene := tree.current_scene
	return scene != null and scene.scene_file_path.begins_with("res://tests/")


static func _place(window: Window, size: Vector2i) -> void:
	if not is_instance_valid(window) or window.mode != Window.MODE_WINDOWED:
		return
	window.size = size
	window.move_to_center()
