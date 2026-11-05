extends LocationBase
## Campo de pruebas para comprobar movimiento, colisiones e interacción.


func build() -> void:
	Atmosphere.add_exterior(self)
	camera_limits = Rect2(-12.0, -12.0, 24.0, 24.0)
	add_spawn("inicio", Vector3(0.0, 0.1, 0.0), 45.0)

	solid(Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 40.0), Palette.STONE_DARK)
	solid(Vector3(-5.0, 1.0, -3.0), Vector3(3.0, 2.0, 2.0), Palette.BRICK)
	solid(Vector3(4.0, 0.75, -6.0), Vector3(2.0, 1.5, 4.0), Palette.PLASTER)
	solid(Vector3(6.0, 0.5, 4.0), Vector3(1.5, 1.0, 1.5), Palette.WOOD, deg_to_rad(30.0))

	add_point_light(Vector3(-2.0, 3.0, 2.0), Palette.WINDOW_WARM, 3.0, 12.0, true)

	var sign_post := add_interactable(Interactable.new(), Vector3(2.0, 0.0, 2.0))
	sign_post.prompt = "Examinar poste"
	sign_post.interacted.connect(_on_post_examined)
	batch.box(Vector3(2.0, 0.6, 2.0), Vector3(0.25, 1.2, 0.25), Palette.WOOD_LIGHT)
	collider(Vector3(2.0, 0.6, 2.0), Vector3(0.25, 1.2, 0.25))


func _on_post_examined(_actor: Node) -> void:
	EventBus.notification_requested.emit("Poste de pruebas", "La interacción funciona.", "info")
