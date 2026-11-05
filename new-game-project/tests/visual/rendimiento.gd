extends Node
## Banco de rendimiento: mide el tiempo medio por fotograma tras calentar los shaders.
## Uso:  godot --path . --resolution 1920x1080 res://tests/visual/rendimiento.tscn -- --location=plaza
## Argumentos: --location=id  --sin=sombras,post,lluvia,glow,msaa,niebla,luces

const GAME_SCENE := "res://scenes/main/game.tscn"
const WARMUP_FRAMES := 120
const MEASURED_FRAMES := 120


func _ready() -> void:
	var args := _parse_args()
	SaveSystem.autosave_enabled = false
	Game.play_intro = false
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await game.go_to(args.get("location", "plaza"), "")
	var disabled: PackedStringArray = (args.get("sin", "") as String).split(",", false)
	_disable(game, disabled)
	for frame in WARMUP_FRAMES:
		await get_tree().process_frame
	var started := Time.get_ticks_usec()
	for frame in MEASURED_FRAMES:
		await get_tree().process_frame
	var average_ms := float(Time.get_ticks_usec() - started) / 1000.0 / float(MEASURED_FRAMES)
	var label := ",".join(disabled) if not disabled.is_empty() else "todo activo"
	print("MEDIDA %s [%s]: %.1f ms por fotograma, %.0f FPS" % [args.get("location", "plaza"), label, average_ms, 1000.0 / average_ms])
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
