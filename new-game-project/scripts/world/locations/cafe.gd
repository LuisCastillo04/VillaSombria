extends LocationBase
## Café La Luna y su pensión. Salón principal con barra, trastienda de juego a la derecha
## y la habitación del detective a la izquierda.

const WALL_COLOR := Color("5a4538")
const WALL_DARK := Color("47362c")


func build() -> void:
	Atmosphere.add_interior(self)
	camera_limits = Rect2(-9.0, -3.5, 16.0, 7.5)
	collider(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 24.0))
	InteriorKit.tile_floor(self, Vector2(-8.0, -6.0), Vector2(8.0, 6.0), Color("7d6a52"), Color("372a22"), 1.0)
	InteriorKit.plank_floor(self, Vector2(-15.0, -6.0), Vector2(-8.0, 6.0), Palette.WOOD_DARK.lightened(0.1))
	InteriorKit.plank_floor(self, Vector2(8.0, -6.0), Vector2(13.0, 6.0), Palette.WOOD, false)
	_build_walls()
	_build_bar()
	_build_tables()
	_build_pension_room()
	_build_back_room()
	_register_points()


func _build_walls() -> void:
	var back := InteriorKit.BACK_WALL
	var low := InteriorKit.PARTITION
	InteriorKit.wall(self, Vector2(-15.0, -6.0), Vector2(13.0, -6.0), back, WALL_COLOR)
	InteriorKit.wall(self, Vector2(-15.0, -6.0), Vector2(-15.0, 6.0), back, WALL_DARK)
	InteriorKit.wall(self, Vector2(13.0, -6.0), Vector2(13.0, 6.0), 0.5, WALL_DARK)
	var front_gaps: Array[Vector2] = [Vector2(0.0, 2.2)]
	InteriorKit.wall(self, Vector2(-15.0, 6.0), Vector2(13.0, 6.0), 0.5, WALL_DARK, front_gaps)
	var left_gaps: Array[Vector2] = [Vector2(-1.5, 1.6)]
	InteriorKit.wall(self, Vector2(-8.0, -6.0), Vector2(-8.0, 6.0), low, WALL_COLOR, left_gaps)
	var right_gaps: Array[Vector2] = [Vector2(-1.5, 1.6)]
	InteriorKit.wall(self, Vector2(8.0, -6.0), Vector2(8.0, 6.0), low, WALL_COLOR, right_gaps)


func _build_bar() -> void:
	solid(Vector3(0.0, 0.55, -3.9), Vector3(9.0, 1.1, 0.7), Palette.WOOD_DARK)
	batch.box(Vector3(0.0, 1.13, -3.9), Vector3(9.2, 0.06, 0.86), Palette.WOOD_LIGHT)
	batch.box(Vector3(0.0, 0.2, -3.5), Vector3(9.0, 0.08, 0.1), Palette.AMBER_SOFT.darkened(0.45))
	for x: float in [-3.4, -1.9, -0.4, 1.1, 2.6]:
		batch.cylinder(Vector3(x, 0.0, -2.9), 0.03, 0.03, 0.72, Palette.IRON, 5)
		batch.cylinder(Vector3(x, 0.72, -2.9), 0.2, 0.2, 0.06, Palette.WINE.darkened(0.2), 7)
		collider(Vector3(x, 0.4, -2.9), Vector3(0.36, 0.8, 0.36))
	# Estantes de botellas y espejo.
	batch.box(Vector3(0.0, 2.3, -5.85), Vector3(6.6, 1.8, 0.05), Color("586878"))
	for y: float in [1.45, 2.05, 2.65]:
		batch.box(Vector3(0.0, y, -5.72), Vector3(7.0, 0.05, 0.3), Palette.WOOD)
		for index in 13:
			var x := -3.2 + 0.53 * float(index)
			var tint: Color = [Palette.WINE, Color("3d5a3e"), Palette.AMBER.darkened(0.3), Color("7a8ea0")][(index + int(y * 10.0)) % 4]
			batch.cylinder(Vector3(x, y + 0.03, -5.72), 0.06, 0.05, 0.28, tint, 6)
			batch.cylinder(Vector3(x, y + 0.31, -5.72), 0.025, 0.025, 0.1, tint, 5)
	add_sign("CAFÉ LA LUNA", Vector3(0.0, 3.3, -5.86), 0.3, Palette.AMBER_SOFT)
	# El teléfono de la llamada del primer día.
	batch.box(Vector3(3.9, 1.22, -3.9), Vector3(0.24, 0.14, 0.3), Palette.INK)
	batch.box(Vector3(3.9, 1.34, -3.9), Vector3(0.36, 0.06, 0.1), Palette.INK)
	InteriorKit.ceiling_lamp(self, Vector3(-2.5, 3.0, -3.6), 3.0, 8.0)
	InteriorKit.ceiling_lamp(self, Vector3(2.5, 3.0, -3.6), 3.0, 8.0, true)


func _build_tables() -> void:
	PropsKit.cafe_table(self, Vector3(-5.2, 0.0, 2.0))
	PropsKit.cafe_table(self, Vector3(-2.0, 0.0, 3.8))
	PropsKit.cafe_table(self, Vector3(3.0, 0.0, 3.8))
	PropsKit.cafe_table(self, Vector3(5.8, 0.0, 1.0))
	InteriorKit.plant(self, Vector3(7.3, 0.0, 5.2))
	InteriorKit.ceiling_lamp(self, Vector3(-3.5, 2.9, 2.5), 2.6, 7.5)
	InteriorKit.ceiling_lamp(self, Vector3(4.4, 2.9, 2.5), 2.6, 7.5)
	add_interactable(LocationExit.new("plaza", "desde_cafe", "Salir a la plaza"), Vector3(0.0, 0.0, 5.4))


func _build_pension_room() -> void:
	InteriorKit.back_window(self, Vector3(-11.6, 2.1, -5.86), Vector2(1.4, 1.9))
	InteriorKit.bed(self, Vector3(-12.8, 0.0, -3.6), 0.0, Color("3c4a55"), Vector2(1.6, 2.2))
	InteriorKit.dresser(self, Vector3(-10.0, 0.0, -5.6), 1.4, false)
	batch.box(Vector3(-9.6, 0.26, -3.2), Vector3(0.7, 0.5, 0.3), Palette.WOOD_LIGHT.darkened(0.2))
	collider(Vector3(-9.6, 0.26, -3.2), Vector3(0.7, 0.5, 0.3))
	InteriorKit.rug(self, Vector3(-11.4, 0.0, 1.6), Vector2(4.0, 3.0), Color("3f4a3a"))
	InteriorKit.table(self, Vector3(-13.5, 0.0, 3.8), Vector3(1.2, 0.76, 0.8), Palette.WOOD)
	InteriorKit.floor_lamp(self, Vector3(-9.0, 0.0, 4.8), 2.0)
	InteriorKit.ceiling_lamp(self, Vector3(-11.5, 2.8, 0.0), 2.0, 7.0)
	add_sign("PENSIÓN", Vector3(-8.13, 0.86, 1.2), 0.2, Palette.AMBER_SOFT, -PI * 0.5)
	add_interactable(RestPoint.new(), Vector3(-12.8, 0.0, -2.2))


func _build_back_room() -> void:
	PropsKit.cafe_table(self, Vector3(10.4, 0.0, 2.2))
	batch.box(Vector3(10.4, 0.8, 2.2), Vector3(0.5, 0.012, 0.32), Palette.PAPER)
	for offset: Vector3 in [Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.2), Vector3(0.0, 0.0, -1.0)]:
		InteriorKit.chair(self, Vector3(10.4, 0.0, 2.2) + offset, 0.0, Palette.WOOD)
	PropsKit.crate(self, Vector3(12.0, 0.0, -5.0), 0.9, 12.0)
	PropsKit.barrel(self, Vector3(10.4, 0.0, -5.2))
	InteriorKit.ceiling_lamp(self, Vector3(10.4, 2.5, 2.2), 2.6, 6.0)


func _register_points() -> void:
	add_spawn("desde_plaza", Vector3(0.0, 0.1, 4.4), 0.0)
	add_spawn("cama", Vector3(-11.4, 0.1, -2.4), 90.0)
	add_marker("barra", Vector3(0.0, 0.0, -5.0))
	add_marker("mesa_ventana", Vector3(4.2, 0.0, 1.6))
	add_marker("mesa_fondo", Vector3(-4.0, 0.0, 0.8))
	add_marker("trastienda", Vector3(10.4, 0.0, 0.0))
