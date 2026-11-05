extends Node
## Herramienta de captura para revisar el juego renderizado sin intervención manual.
## Uso:  godot --path . --resolution 1280x720 res://tests/visual/captura.tscn -- --out=C:/ruta/img.png
## Argumentos: --out=ruta  --pos=x,y,z  --frames=N  --location=id  --spawn=id
##             --shots=x,y,z;x,y,z  guarda una imagen numerada por cada posición.

const GAME_SCENE := "res://scenes/main/game.tscn"


func _ready() -> void:
	var args := _parse_args()
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	if args.has("location"):
		await game.go_to(args["location"], args.get("spawn", ""))
	var out: String = args.get("out", "user://captura.png")
	var frames := int(args.get("frames", "60"))
	if args.has("shots"):
		var index := 1
		for shot: String in (args["shots"] as String).split(";"):
			_place_player(game, shot)
			await _save_frame(out.get_basename() + "_%d.png" % index, frames)
			index += 1
	else:
		if args.has("pos"):
			_place_player(game, args["pos"])
		await _save_frame(out, frames)
	get_tree().quit()


func _place_player(game: Game, text: String) -> void:
	var parts := text.split(",")
	game.player.teleport(Vector3(float(parts[0]), float(parts[1]), float(parts[2])), 0.0)
	game.camera.snap()


func _save_frame(path: String, frames: int) -> void:
	for frame in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("Captura ", path, " código ", image.save_png(path))


func _parse_args() -> Dictionary:
	var result := {}
	for raw in OS.get_cmdline_user_args():
		var pair := raw.trim_prefix("--").split("=", true, 1)
		result[pair[0]] = pair[1] if pair.size() > 1 else "1"
	return result
