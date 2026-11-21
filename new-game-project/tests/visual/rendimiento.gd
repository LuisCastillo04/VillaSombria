extends Node
## Banco de rendimiento: mide el tiempo medio por fotograma tras calentar los shaders, y el tiempo
## de dibujado que informa el propio servidor (CPU y GPU), que no depende del tope de fotogramas ni de
## la sincronización vertical.
## Uso:  godot --path . --resolution 1920x1080 res://tests/visual/rendimiento.tscn -- --location=plaza
## Argumentos: --location=id  --sin=sombras,post,lluvia,glow,msaa,niebla,luces
##             --iluminacion=bajo|medio|alto  --efectos=bajo|medio|alto  (calidad de Configuración)

const GAME_SCENE := "res://scenes/main/game.tscn"
const WARMUP_FRAMES := 120
const MEASURED_FRAMES := 120


func _ready() -> void:
	var args := _parse_args()
	SaveSystem.autosave_enabled = false
	SaveSystem.use_storage("user://pruebas_guardado/capturas")
	TestCase.reset_test_settings()
	if args.has("iluminacion"):
		Settings.set_value("graficos/calidad_iluminacion", args["iluminacion"])
	if args.has("efectos"):
		Settings.set_value("graficos/calidad_efectos", args["efectos"])
	Game.play_intro = false
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await game.go_to(args.get("location", "plaza"), "")
	var disabled: PackedStringArray = (args.get("sin", "") as String).split(",", false)
	_disable(game, disabled)
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	for frame in WARMUP_FRAMES:
		await get_tree().process_frame
	var started := Time.get_ticks_usec()
	var gpu := 0.0
	var cpu := 0.0
	var draws := 0
	var primitives := 0
	for frame in MEASURED_FRAMES:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var average_ms := float(Time.get_ticks_usec() - started) / 1000.0 / float(MEASURED_FRAMES)
	var label := ",".join(disabled) if not disabled.is_empty() else "todo activo"
	var quality := "iluminación %s, efectos %s" % [Settings.get_value("graficos/calidad_iluminacion"), Settings.get_value("graficos/calidad_efectos")]
	print("MEDIDA %s [%s; %s]: %.1f ms por fotograma, %.0f FPS" % [args.get("location", "plaza"), label, quality, average_ms, 1000.0 / average_ms])
	print("DIBUJADO GPU %.2f ms, CPU %.2f ms, %d llamadas, %d primitivas, %.0f MB de vídeo" % [
		gpu / MEASURED_FRAMES, cpu / MEASURED_FRAMES, draws / MEASURED_FRAMES, primitives / MEASURED_FRAMES,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
	TestCase.reset_test_settings()
	get_tree().quit()


func _disable(game: Game, what: PackedStringArray) -> void:
	var environment: Environment = _find_environment(game.current_location)
	if what.has("sombras"):
		_for_each_light(game.current_location, func(light: Light3D) -> void: light.shadow_enabled = false)
	if what.has("luces"):
		_for_each_light(game.current_location, func(light: Light3D) -> void:
			if light is OmniLight3D:
				light.visible = false
		)
	if what.has("post"):
		game.get_node("PostFx").visible = false
		(game.get_node("PostFx/Rect") as CanvasItem).visible = false
	if what.has("lluvia") and game._rain != null:
		game._rain.emitting = false
		game._rain.visible = false
	if environment != null:
		if what.has("glow"):
			environment.glow_enabled = false
		if what.has("niebla"):
			environment.fog_enabled = false
		if what.has("ajuste"):
			environment.adjustment_enabled = false
	if what.has("msaa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED


func _find_environment(root: Node) -> Environment:
	for child in root.get_children():
		if child is WorldEnvironment:
			return (child as WorldEnvironment).environment
	return null


func _for_each_light(root: Node, action: Callable) -> void:
	for child in root.get_children():
		if child is Light3D:
			action.call(child)


func _parse_args() -> Dictionary:
	var result := {}
	for raw in OS.get_cmdline_user_args():
		var pair := raw.trim_prefix("--").split("=", true, 1)
		result[pair[0]] = pair[1] if pair.size() > 1 else "1"
	return result
