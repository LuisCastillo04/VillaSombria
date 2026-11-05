extends LocationBase
## Mansión Valdés, escena del crimen. Planta con seis estancias:
##   alcoba de Elena | salón    | despacho
##   cuarto de Lucía | vestíbulo | office del mayordomo

const WALL_COLOR := Color("4a3a33")
const WALL_DARK := Color("3a2e2c")
const FABRIC := Color("5a2a30")


func build() -> void:
	Atmosphere.add_interior(self)
	camera_limits = Rect2(-9.0, -6.0, 18.0, 13.0)
	collider(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 30.0))
	_build_floors()
	_build_walls()
	_build_salon()
	_build_study()
	_build_bedroom()
	_build_maid_room()
	_build_hall()
	_build_office()
	_register_points()


func _build_floors() -> void:
	InteriorKit.plank_floor(self, Vector2(-5.0, -9.0), Vector2(6.0, -1.0), Palette.WOOD)
	InteriorKit.plank_floor(self, Vector2(6.0, -9.0), Vector2(14.0, -1.0), Palette.WOOD.darkened(0.15), false)
	InteriorKit.plank_floor(self, Vector2(-14.0, -9.0), Vector2(-5.0, -1.0), Palette.WOOD_LIGHT.darkened(0.2))
	InteriorKit.plank_floor(self, Vector2(-14.0, -1.0), Vector2(-5.0, 9.0), Palette.WOOD_DARK.lightened(0.12), false)
	InteriorKit.tile_floor(self, Vector2(-5.0, -1.0), Vector2(6.0, 9.0), Color("7a7670"), Color("2e2a2a"), 1.1)
	InteriorKit.tile_floor(self, Vector2(6.0, -1.0), Vector2(14.0, 9.0), Color("5c5a55"), Color("454340"), 0.8)


func _build_walls() -> void:
	var back := InteriorKit.BACK_WALL
	var low := InteriorKit.PARTITION
	InteriorKit.wall(self, Vector2(-14.0, -9.0), Vector2(14.0, -9.0), back, WALL_COLOR)
	InteriorKit.wall(self, Vector2(-14.0, -9.0), Vector2(-14.0, 9.0), back, WALL_DARK)
	InteriorKit.wall(self, Vector2(14.0, -9.0), Vector2(14.0, 9.0), 0.5, WALL_DARK)
	var front_gaps: Array[Vector2] = [Vector2(0.5, 2.4)]
	InteriorKit.wall(self, Vector2(-14.0, 9.0), Vector2(14.0, 9.0), 0.5, WALL_DARK, front_gaps)
	var salon_gaps: Array[Vector2] = [Vector2(-5.0, 1.8)]
	InteriorKit.wall(self, Vector2(-5.0, -9.0), Vector2(-5.0, -1.0), low, WALL_COLOR, salon_gaps)
	var study_gaps: Array[Vector2] = [Vector2(-5.0, 1.8)]
	InteriorKit.wall(self, Vector2(6.0, -9.0), Vector2(6.0, -1.0), low, WALL_COLOR, study_gaps)
	var middle_gaps: Array[Vector2] = [Vector2(-9.5, 1.4), Vector2(0.5, 3.0), Vector2(11.0, 1.4)]
	InteriorKit.wall(self, Vector2(-14.0, -1.0), Vector2(14.0, -1.0), low, WALL_COLOR, middle_gaps)
	var left_gaps: Array[Vector2] = [Vector2(4.0, 1.6)]
	InteriorKit.wall(self, Vector2(-5.0, -1.0), Vector2(-5.0, 9.0), low, WALL_DARK, left_gaps)
	var right_gaps: Array[Vector2] = [Vector2(4.0, 1.6)]
	InteriorKit.wall(self, Vector2(6.0, -1.0), Vector2(6.0, 9.0), low, WALL_DARK, right_gaps)


func _build_salon() -> void:
	InteriorKit.rug(self, Vector3(0.5, 0.0, -5.0), Vector2(7.0, 4.6), Palette.CARPET)
	InteriorKit.fireplace(self, Vector3(3.2, 0.0, -8.6))
	InteriorKit.painting(self, Vector3(3.2, 2.9, -8.85), Vector2(1.7, 1.0), Color("3c4a44"))
	InteriorKit.back_window(self, Vector3(-2.6, 2.1, -8.86), Vector2(1.5, 2.1))
	InteriorKit.sofa(self, Vector3(-1.2, 0.0, -5.2), 90.0, FABRIC)
	InteriorKit.armchair(self, Vector3(2.8, 0.0, -3.0), 0.0, FABRIC.darkened(0.15))
	InteriorKit.table(self, Vector3(0.9, 0.0, -5.2), Vector3(1.3, 0.42, 0.8), Palette.WOOD_DARK)
	InteriorKit.floor_lamp(self, Vector3(-4.2, 0.0, -2.2))
	InteriorKit.ceiling_lamp(self, Vector3(0.6, 3.0, -4.6), 4.2, 10.0, true)
	InteriorKit.plant(self, Vector3(5.2, 0.0, -8.2))


func _build_study() -> void:
	InteriorKit.rug(self, Vector3(10.2, 0.0, -5.0), Vector2(5.4, 4.2), Color("2f3a4a"))
	InteriorKit.bookshelf(self, Vector3(8.2, 0.0, -8.8), 3.2)
	InteriorKit.bookshelf(self, Vector3(12.0, 0.0, -8.8), 3.2)
	InteriorKit.desk(self, Vector3(11.0, 0.0, -6.4), Vector3(2.5, 0.78, 1.1))
	batch.box(Vector3(10.2, 0.92, -6.5), Vector3(0.14, 0.2, 0.14), Color("6a3b1e"))
	batch.cylinder(Vector3(12.0, 0.84, -6.3), 0.06, 0.09, 0.18, Color("c4d0dc"), 7)
	InteriorKit.chair(self, Vector3(11.0, 0.0, -7.5), 0.0, Palette.WINE.darkened(0.2))
	InteriorKit.armchair(self, Vector3(8.0, 0.0, -3.0), 45.0, Palette.WINE.darkened(0.15))
	# Reloj caído y cristales rotos junto al sillón.
	batch.box(Vector3(9.3, 0.1, -3.9), Vector3(0.5, 0.18, 0.34), Color("8a6a3a"), 0.4)
	for offset: Vector3 in [Vector3(0.3, 0.02, 0.2), Vector3(-0.2, 0.02, 0.3), Vector3(0.1, 0.02, -0.3)]:
		batch.box(Vector3(9.3, 0.0, -3.9) + offset, Vector3(0.08, 0.02, 0.05), Color("b9c6d4"), 0.7)
	# Huellas de betún hacia la puerta de servicio.
	for index in 5:
		var step := Vector3(11.0 - 0.15 * float(index % 2), 0.045, -2.0 - 0.62 * float(index))
		batch.box(step, Vector3(0.14, 0.012, 0.28), Color("0b0b0d"))
	InteriorKit.ceiling_lamp(self, Vector3(10.0, 3.0, -5.0), 3.0, 8.0, true)
	add_interactable(ClueObject.new("reloj_despacho"), Vector3(9.3, 0.0, -3.9))
	add_interactable(ClueObject.new("copa_lavada"), Vector3(12.0, 0.6, -6.0))
	add_interactable(ClueObject.new("huellas_betun"), Vector3(11.2, 0.0, -2.2))


func _build_bedroom() -> void:
	InteriorKit.rug(self, Vector3(-9.5, 0.0, -4.6), Vector2(4.8, 3.4), Color("3d2f45"))
	InteriorKit.bed(self, Vector3(-7.0, 0.0, -7.4), 0.0, Color("4a2b3f"), Vector2(2.0, 2.3))
	InteriorKit.dresser(self, Vector3(-12.0, 0.0, -8.6), 2.0, true)
	InteriorKit.back_window(self, Vector3(-9.6, 2.1, -8.86), Vector2(1.2, 1.8))
	InteriorKit.floor_lamp(self, Vector3(-13.2, 0.0, -2.0), 2.2)
	InteriorKit.chair(self, Vector3(-12.0, 0.0, -7.4), 180.0, FABRIC)
	add_interactable(ClueObject.new("billete_tren"), Vector3(-10.6, 0.0, -7.8))


func _build_maid_room() -> void:
	InteriorKit.bed(self, Vector3(-12.6, 0.0, 6.6), 90.0, Color("3f4a55"), Vector2(1.2, 2.0))
	InteriorKit.table(self, Vector3(-11.4, 0.0, 4.6), Vector3(0.7, 0.6, 0.7), Palette.WOOD)
	batch.box(Vector3(-11.4, 0.66, 4.6), Vector3(0.22, 0.08, 0.3), Palette.INK)
	InteriorKit.dresser(self, Vector3(-9.0, 0.0, 0.0), 1.6, false, 0.0)
	InteriorKit.ceiling_lamp(self, Vector3(-9.5, 2.8, 4.0), 2.2, 7.0)
	add_interactable(ClueObject.new("carta_amor"), Vector3(-10.6, 0.0, 4.6))


func _build_hall() -> void:
	InteriorKit.rug(self, Vector3(0.5, 0.0, 4.0), Vector2(3.0, 9.0), Palette.CARPET.darkened(0.1))
	InteriorKit.table(self, Vector3(3.8, 0.0, 7.6), Vector3(1.6, 0.86, 0.6), Palette.WOOD_DARK)
	batch.box(Vector3(3.6, 0.9, 7.6), Vector3(0.4, 0.015, 0.5), Palette.PAPER)
	InteriorKit.grandfather_clock(self, Vector3(-4.4, 0.0, 7.6), 90.0)
	InteriorKit.plant(self, Vector3(-4.3, 0.0, 0.0))
	InteriorKit.plant(self, Vector3(5.3, 0.0, 0.0))
	InteriorKit.ceiling_lamp(self, Vector3(0.5, 3.0, 4.0), 3.8, 9.5, true)
	add_interactable(ClueObject.new("lista_invitados"), Vector3(3.2, 0.0, 6.6))
	add_interactable(LocationExit.new("plaza", "desde_mansion", "Salir a la plaza"), Vector3(0.5, 0.0, 8.4))


func _build_office() -> void:
	InteriorKit.table(self, Vector3(8.2, 0.0, 7.4), Vector3(2.2, 0.86, 1.0), Palette.WOOD)
	batch.box(Vector3(7.8, 0.91, 7.4), Vector3(0.5, 0.05, 0.7), Palette.WINE.darkened(0.3))
	InteriorKit.bookshelf(self, Vector3(13.7, 0.0, 3.0), 3.0, 2.0, -90.0)
	InteriorKit.dresser(self, Vector3(8.6, 0.0, -0.6), 1.8, false)
	batch.box(Vector3(8.6, 1.08, -0.7), Vector3(0.3, 0.42, 0.04), Palette.PAPER)
	# Tablero de llaves junto a la puerta de servicio.
	batch.box(Vector3(12.9, 1.0, -0.86), Vector3(1.3, 0.8, 0.05), Palette.WOOD_DARK)
	for x: float in [12.5, 12.8, 13.1, 13.4]:
		batch.box(Vector3(x, 1.0, -0.82), Vector3(0.06, 0.2, 0.02), Palette.AMBER_SOFT)
	InteriorKit.ceiling_lamp(self, Vector3(10.0, 2.8, 4.0), 2.8, 8.0)
	add_interactable(ClueObject.new("foto_clara"), Vector3(8.6, 0.0, 0.5))
	add_interactable(ClueObject.new("libro_bodega"), Vector3(7.7, 0.0, 6.2))
	add_interactable(ClueObject.new("llave_reloj"), Vector3(12.9, 0.0, 0.3))


func _register_points() -> void:
	add_spawn("desde_plaza", Vector3(0.5, 0.1, 7.2), 0.0)
	add_marker("vestibulo", Vector3(-2.2, 0.0, 5.8))
	add_marker("pasillo", Vector3(2.4, 0.0, 4.0))
	add_marker("salon_sofa", Vector3(-0.7, 0.0, -3.4))
	add_marker("salon_chimenea", Vector3(1.4, 0.0, -7.2))
	add_marker("salon_ventana", Vector3(-3.5, 0.0, -7.4))
	add_marker("alcoba_elena", Vector3(-9.5, 0.0, -4.6))
	add_marker("cuarto_lucia", Vector3(-8.0, 0.0, 5.6))
	add_marker("office", Vector3(9.6, 0.0, 4.0))
