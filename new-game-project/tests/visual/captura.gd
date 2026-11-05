extends Node
## Herramienta de captura para revisar el juego renderizado sin intervención manual.
## Uso:  godot --path . --resolution 1280x720 res://tests/visual/captura.tscn -- --out=C:/ruta/img.png
## Argumentos:
##   --out=ruta            archivo de salida
##   --frames=N            fotogramas de espera antes de capturar
##   --location=id         escenario inicial        --spawn=id  punto de aparición
##   --pos=x,y,z           coloca al detective
##   --shots=x,y,z;x,y,z   guarda una imagen numerada por cada posición
##   --day=N --time=HH:MM  fija el calendario
##   --seed=todo           concede todas las pistas y testimonios
##   --dialogue-shots=A,B  abre una conversación con cada NPC y la captura
##   --open=clue:id | journal:n | board | accusation | pause | closed

const GAME_SCENE := "res://scenes/main/game.tscn"


func _ready() -> void:
	var args := _parse_args()
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await _wait_seconds(0.2)
	if args.has("day"):
		GameClock.day = int(args["day"])
	if args.has("time"):
		GameClock.minutes = GameClock.parse_time(args["time"])
		GameClock.advance(1)
	if args.get("seed", "") == "todo":
		_grant_everything()
	if args.has("location"):
		await game.go_to(args["location"], args.get("spawn", ""))
	var out: String = args.get("out", "user://captura.png")
	var frames := int(args.get("frames", "60"))
	if args.has("dialogue-shots"):
		for npc_id: String in (args["dialogue-shots"] as String).split(","):
			DialogueManager.start(npc_id)
			await _save_frame(out.get_basename() + "_%s.png" % npc_id, frames)
			DialogueManager.close()
			await _wait_seconds(0.4)
	elif args.has("shots"):
		var index := 1
		for shot: String in (args["shots"] as String).split(";"):
			_place_player(game, shot)
			await _save_frame(out.get_basename() + "_%d.png" % index, frames)
			index += 1
	else:
		if args.has("pos"):
			_place_player(game, args["pos"])
		if args.has("open"):
			_open_panel(game, args["open"])
		await _save_frame(out, frames)
	get_tree().quit()


func _open_panel(game: Game, what: String) -> void:
	var parts := what.split(":")
	match parts[0]:
		"clue":
			EventBus.clue_inspection_requested.emit(parts[1])
		"journal":
			game.get_node("JournalUi").open(int(parts[1]))
		"board":
			game.get_node("BoardUi").open()
		"accusation":
			game.get_node("AccusationUi").open()
		"pause":
			game.get_node("PauseMenu").open()
		"closed":
			game.get_node("CaseClosedUi").open()


func _grant_everything() -> void:
	for clue_id: String in GameData.clues:
		Investigation.discover_clue(clue_id)
	for testimony_id: String in GameData.testimonies:
		Investigation.record_testimony(testimony_id)


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
