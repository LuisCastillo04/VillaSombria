extends LocationBase
## Archivo municipal: mostrador de Don Hilario, sala de lectura y depósito de legajos.

const WALL_COLOR := Color("4c4a4a")
const WALL_DARK := Color("3a3a3e")


func build() -> void:
	Atmosphere.add_interior(self)
	camera_limits = Rect2(-5.0, -3.0, 10.0, 6.0)
	collider(Vector3(0.0, -0.5, 0.0), Vector3(30.0, 1.0, 24.0))
	InteriorKit.plank_floor(self, Vector2(-10.0, -7.0), Vector2(10.0, 7.0), Color("4d4238"), false)
	_build_walls()
	_build_counter()
	_build_stacks()
	_build_reading_room()
	add_spawn("desde_plaza", Vector3(0.0, 0.1, 5.4), 0.0)
	add_marker("mostrador", Vector3(0.0, 0.0, -3.6))
	add_marker("sala_lectura", Vector3(-5.8, 0.0, 3.0))
	add_marker("estanterias", Vector3(6.4, 0.0, 0.0))


func _build_walls() -> void:
	var back := InteriorKit.BACK_WALL
	InteriorKit.wall(self, Vector2(-10.0, -7.0), Vector2(10.0, -7.0), back, WALL_COLOR)
	InteriorKit.wall(self, Vector2(-10.0, -7.0), Vector2(-10.0, 7.0), back, WALL_DARK)
	InteriorKit.wall(self, Vector2(10.0, -7.0), Vector2(10.0, 7.0), 0.5, WALL_DARK)
	var front_gaps: Array[Vector2] = [Vector2(0.0, 2.2)]
	InteriorKit.wall(self, Vector2(-10.0, 7.0), Vector2(10.0, 7.0), 0.5, WALL_DARK, front_gaps)
	add_interactable(LocationExit.new("plaza", "desde_archivo", "Salir a la plaza"), Vector3(0.0, 0.0, 6.4))


func _build_counter() -> void:
	solid(Vector3(0.0, 0.55, -2.6), Vector3(6.0, 1.1, 0.7), Palette.WOOD_DARK)
	batch.box(Vector3(0.0, 1.13, -2.6), Vector3(6.2, 0.06, 0.86), Palette.WOOD)
	batch.box(Vector3(-1.8, 1.24, -2.6), Vector3(0.7, 0.16, 0.5), Palette.PAPER.darkened(0.1))
	batch.box(Vector3(1.6, 1.2, -2.6), Vector3(0.5, 0.08, 0.36), Palette.WINE.darkened(0.2))
	InteriorKit.bookshelf(self, Vector3(-3.0, 0.0, -6.8), 4.0, 3.0)
	InteriorKit.bookshelf(self, Vector3(3.0, 0.0, -6.8), 4.0, 3.0)
	for x: float in [-7.5, -6.4, 6.4, 7.5]:
		InteriorKit.filing_cabinet(self, Vector3(x, 0.0, -6.5))
	InteriorKit.ceiling_lamp(self, Vector3(0.0, 3.0, -3.4), 3.6, 9.0, true)


func _build_stacks() -> void:
	for z: float in [-2.0, 1.6, 5.0]:
		InteriorKit.bookshelf(self, Vector3(8.0, 0.0, z), 3.0, 2.5, 180.0)
		InteriorKit.bookshelf(self, Vector3(8.0, 0.0, z + 0.3), 3.0, 2.5, 0.0)
	InteriorKit.ceiling_lamp(self, Vector3(5.6, 2.9, 2.0), 2.4, 7.5)


func _build_reading_room() -> void:
	InteriorKit.rug(self, Vector3(-5.8, 0.0, 1.8), Vector2(6.2, 6.0), Color("2f3a44"))
	InteriorKit.table(self, Vector3(-5.8, 0.0, 1.4), Vector3(3.6, 0.8, 1.3), Palette.WOOD)
	for x: float in [-7.0, -5.8, -4.6]:
		InteriorKit.chair(self, Vector3(x, 0.0, 0.3), 180.0)
	batch.box(Vector3(-6.6, 0.84, 1.4), Vector3(0.5, 0.05, 0.7), Palette.PAPER.darkened(0.15))
	batch.box(Vector3(-4.8, 0.86, 1.3), Vector3(0.44, 0.1, 0.6), Palette.WINE.darkened(0.25))
	InteriorKit.floor_lamp(self, Vector3(-3.6, 0.0, 0.6), 2.2)
	InteriorKit.back_window(self, Vector3(-9.86, 2.1, 1.5), Vector2(1.6, 2.0), 90.0)
	InteriorKit.painting(self, Vector3(-9.86, 2.3, -3.6), Vector2(1.6, 1.0), Color("4a5a55"), 90.0)
	InteriorKit.ceiling_lamp(self, Vector3(-5.8, 2.9, 2.4), 2.6, 7.5)
