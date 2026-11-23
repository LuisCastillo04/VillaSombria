extends LocationBase
## Café La Luna y su pensión. Salón principal con barra, trastienda de juego a la derecha
## y la habitación del detective a la izquierda.

const WALL_COLOR := Color("5a4538")
const WALL_DARK := Color("47362c")
## Cama de la pensión (centro de su base): el punto de descanso y el de aparición «cama» van con ella.
const BED := Vector3(-12.8, 0.0, -4.65)
## Mesilla de noche de la pensión: centro de su base y medidas.
const NIGHTSTAND := Vector3(-11.57, 0.0, -5.69)
const NIGHTSTAND_SIZE := Vector3(0.7, 0.5, 0.3)
## Silla delante de la cómoda de la pensión (centro de su base y giro en grados).
const DESK_CHAIR := Vector3(-10.05, 0.0, -4.9)
const DESK_CHAIR_YAW := 168.0


func build() -> void:
	Atmosphere.add_interior(self)
	camera_limits = Rect2(-9.0, -3.5, 16.0, 7.5)
	play_area = Rect2(-15.0, -6.0, 28.0, 12.0)
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
	InteriorKit.seal_street_door(self, Vector2(-15.0, 6.0), Vector2(13.0, 6.0), front_gaps[0])
	var left_gaps: Array[Vector2] = [Vector2(-1.5, 1.6)]
	InteriorKit.wall(self, Vector2(-8.0, -6.0), Vector2(-8.0, 6.0), low, WALL_COLOR, left_gaps)
	var right_gaps: Array[Vector2] = [Vector2(-1.5, 1.6)]
	InteriorKit.wall(self, Vector2(8.0, -6.0), Vector2(8.0, 6.0), low, WALL_COLOR, right_gaps)


func _build_bar() -> void:
	ModelCatalog.draw(self, "barra_cafe", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -3.9)), func(_tint: Color) -> void: _bar_mesh())
	collider(Vector3(0.0, 0.55, -3.9), Vector3(9.0, 1.1, 0.7))
	for x: float in [-3.4, -1.9, -0.4, 1.1, 2.6]:
		var stool := Vector3(x, 0.0, -2.9)
		ModelCatalog.draw(self, "taburete", Transform3D(Basis.IDENTITY, stool), func(_tint: Color) -> void: _stool_mesh(stool))
		collider(Vector3(x, 0.4, -2.9), Vector3(0.36, 0.8, 0.36))
	ModelCatalog.draw(self, "botellero_cafe", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -5.85)), func(_tint: Color) -> void: _bottle_shelves_mesh())
	add_sign("CAFÉ LA LUNA", Vector3(0.0, 3.3, -5.86), 0.3, Palette.AMBER_SOFT)
	# El teléfono del café, desde el que el sargento buscó al inspector el primer día.
	ModelCatalog.draw(self, "telefono", Transform3D(Basis.IDENTITY, Vector3(3.9, 1.15, -3.9)), func(_tint: Color) -> void: _phone_mesh())
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
	# Cama con el cabecero a 0,06 m del zócalo de la pared del fondo y la mesilla de noche a su
	# derecha, contra la misma pared. Antes la cama quedaba a 1,1 m de la pared y la mesilla,
	# suelta en (-9,6; -3,2), junto al paso del tabique.
	InteriorKit.bed(self, BED, 0.0, Color("3c4a55"), Vector2(1.6, 2.2))
	ModelCatalog.draw(self, "mesilla", Transform3D(Basis.IDENTITY, NIGHTSTAND), func(_tint: Color) -> void:
		batch.box(NIGHTSTAND + Vector3.UP * NIGHTSTAND_SIZE.y * 0.5, NIGHTSTAND_SIZE, Palette.WOOD_LIGHT.darkened(0.2))
	)
	collider(NIGHTSTAND + Vector3.UP * NIGHTSTAND_SIZE.y * 0.5, NIGHTSTAND_SIZE)
	# La cómoda hace de escritorio: silla delante, algo girada, como si alguien se acabara de levantar.
	InteriorKit.dresser(self, Vector3(-10.0, 0.0, -5.6), 1.4, false)
	InteriorKit.chair(self, DESK_CHAIR, DESK_CHAIR_YAW, Palette.WOOD_LIGHT)
	InteriorKit.rug(self, Vector3(-11.4, 0.0, 1.6), Vector2(4.0, 3.0), Color("3f4a3a"))
	InteriorKit.table(self, Vector3(-13.5, 0.0, 3.8), Vector3(1.2, 0.76, 0.8), Palette.WOOD)
	InteriorKit.floor_lamp(self, Vector3(-9.0, 0.0, 4.8), 2.0)
	InteriorKit.ceiling_lamp(self, Vector3(-11.5, 2.8, 0.0), 2.0, 7.0)
	add_sign("PENSIÓN", Vector3(-8.13, 0.86, 1.2), 0.2, Palette.AMBER_SOFT, -PI * 0.5)
	add_interactable(RestPoint.new(), BED + Vector3(0.0, 0.0, 1.4))


func _build_back_room() -> void:
	PropsKit.cafe_table(self, Vector3(10.4, 0.0, 2.2))
	_papers(Vector3(10.4, 0.8, 2.2), Vector3(0.5, 0.012, 0.32), Palette.PAPER)
	for offset: Vector3 in [Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.2), Vector3(0.0, 0.0, -1.0)]:
		InteriorKit.chair(self, Vector3(10.4, 0.0, 2.2) + offset, 0.0, Palette.WOOD)
	PropsKit.crate(self, Vector3(12.0, 0.0, -5.0), 0.9, 12.0)
	PropsKit.barrel(self, Vector3(10.4, 0.0, -5.2))
	InteriorKit.ceiling_lamp(self, Vector3(10.4, 2.5, 2.2), 2.6, 6.0)


## Barra del café: mueble, encimera y reposapiés. La colisión la pone `_build_bar`.
func _bar_mesh() -> void:
	batch.box(Vector3(0.0, 0.55, -3.9), Vector3(9.0, 1.1, 0.7), Palette.WOOD_DARK)
	batch.box(Vector3(0.0, 1.13, -3.9), Vector3(9.2, 0.06, 0.86), Palette.WOOD_LIGHT)
	batch.box(Vector3(0.0, 0.2, -3.5), Vector3(9.0, 0.08, 0.1), Palette.AMBER_SOFT.darkened(0.45))


func _stool_mesh(where: Vector3) -> void:
	batch.cylinder(where, 0.03, 0.03, 0.72, Palette.IRON, 5)
	batch.cylinder(where + Vector3.UP * 0.72, 0.2, 0.2, 0.06, Palette.WINE.darkened(0.2), 7)


## Estantes de botellas y espejo de detrás de la barra.
func _bottle_shelves_mesh() -> void:
	batch.box(Vector3(0.0, 2.3, -5.85), Vector3(6.6, 1.8, 0.05), Color("586878"))
	for y: float in [1.45, 2.05, 2.65]:
		batch.box(Vector3(0.0, y, -5.72), Vector3(7.0, 0.05, 0.3), Palette.WOOD)
		for index in 13:
			var x := -3.2 + 0.53 * float(index)
			var tint: Color = [Palette.WINE, Color("3d5a3e"), Palette.AMBER.darkened(0.3), Color("7a8ea0")][(index + int(y * 10.0)) % 4]
			batch.cylinder(Vector3(x, y + 0.03, -5.72), 0.06, 0.05, 0.28, tint, 6)
			batch.cylinder(Vector3(x, y + 0.31, -5.72), 0.025, 0.025, 0.1, tint, 5)


func _phone_mesh() -> void:
	batch.box(Vector3(3.9, 1.22, -3.9), Vector3(0.24, 0.14, 0.3), Palette.INK)
	batch.box(Vector3(3.9, 1.34, -3.9), Vector3(0.36, 0.06, 0.1), Palette.INK)
## Papeles, libros y objetos pequeños sobre los muebles. Las medidas son la variante del modelo y
## el color, su tinte: así comparten un único modelo de Blender.
func _papers(center: Vector3, size: Vector3, color: Color) -> void:
	var procedural := func(tint: Color) -> void: batch.box(center, size, tint)
	ModelCatalog.draw(self, "papeles", Transform3D(Basis.IDENTITY, center), procedural, ModelCatalog.size_key(size), color)


func _book(center: Vector3, size: Vector3, color: Color) -> void:
	var procedural := func(tint: Color) -> void: batch.box(center, size, tint)
	ModelCatalog.draw(self, "libro", Transform3D(Basis.IDENTITY, center), procedural, ModelCatalog.size_key(size), color)


func _register_points() -> void:
	add_spawn("desde_plaza", Vector3(0.0, 0.1, 4.4), 0.0)
	add_spawn("cama", BED + Vector3(1.4, 0.1, 1.2), 90.0)
	# Detrás de la barra, de cara a la clientela y no a las botellas.
	for spot: Array in [["barra", 0.0], ["barra_izquierda", -2.8], ["barra_derecha", 2.8]]:
		add_marker(spot[0], Vector3(spot[1], 0.0, -4.95))
		face_marker(spot[0], Vector3(spot[1], 0.0, 0.0))
	# Del lado de los clientes, en los extremos de la barra y sin ocupar los taburetes.
	add_marker("barra_cliente", Vector3(3.6, 0.0, -2.9))
	face_marker("barra_cliente", Vector3(3.6, 0.0, -4.0))
	add_marker("barra_extremo", Vector3(-4.2, 0.0, -2.7))
	face_marker("barra_extremo", Vector3(-4.2, 0.0, -4.0))
	add_marker("mesa_ventana", Vector3(4.2, 0.0, 1.6))
	face_marker("mesa_ventana", Vector3(5.8, 0.0, 1.0))
	add_marker("mesa_fondo", Vector3(-4.0, 0.0, 0.8))
	face_marker("mesa_fondo", Vector3(-5.2, 0.0, 2.0))
	add_marker("trastienda", Vector3(10.4, 0.0, 0.0))
	# El primer día, hasta que llega el inspector: el sargento lo espera junto a la puerta y Rosa
	# ha salido de la barra a hacerle compañía. Quedan a los lados de quien entra, a la vista
	# mientras le hablan (la interfaz de la conversación tapa los bordes y la barra).
	add_marker("puerta_sargento", Vector3(-1.8, 0.0, 5.1))
	face_marker("puerta_sargento", Vector3(0.0, 0.0, 6.0))
	add_marker("sala_rosa", Vector3(1.5, 0.0, 3.1))
	face_marker("sala_rosa", Vector3(0.0, 0.0, 6.0))
