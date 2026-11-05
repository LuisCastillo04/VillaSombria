extends Node
## Herramienta de captura para revisar el juego renderizado sin intervención manual.
## Uso:  godot --path . --resolution 1280x720 res://tests/visual/captura.tscn -- --out=C:/ruta/img.png
## Argumentos: --out=ruta  --pos=x,y,z  --frames=N  --location=id  --spawn=id

const GAME_SCENE := "res://scenes/main/game.tscn"


func _ready() -> void:
	var args := _parse_args()
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	if args.has("location"):
		await game.go_to(args["location"], args.get("spawn", ""))
	if args.has("pos"):
		var parts: PackedStringArray = (args["pos"] as String).split(",")
		game.player.teleport(Vector3(float(parts[0]), float(parts[1]), float(parts[2])), 0.0)
		game.camera.snap()
	for frame in int(args.get("frames", "60")):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(args.get("out", "user://captura.png"))
	print("Captura guardada, código ", error, ": ", image.get_size())
	get_tree().quit()


func _parse_args() -> Dictionary:
	var result := {}
	for raw in OS.get_cmdline_user_args():
		var pair := raw.trim_prefix("--").split("=", true, 1)
		result[pair[0]] = pair[1] if pair.size() > 1 else "1"
	return result
