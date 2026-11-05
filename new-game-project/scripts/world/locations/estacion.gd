extends LocationBase
## Estación de tren: aquí llega el detective. El andén queda delante de las vías y el
## edificio de la taquilla al oeste, de modo que el tren nunca tapa al jugador.

const PLATFORM_TINT := Color("c9c6c0")
const STREET_TINT := Color("8f93a0")
const VERGE_TINT := Color("3f4640")


func build() -> void:
	Atmosphere.add_exterior(self)
	camera_limits = Rect2(-8.0, -5.0, 22.0, 9.0)
	collider(Vector3(5.0, -0.5, 0.0), Vector3(90.0, 1.0, 60.0))
	batch.ground(Vector2(-50.0, -50.0), Vector2(60.0, 50.0), VERGE_TINT, -0.04)
	batch.ground(Vector2(-17.0, -4.0), Vector2(22.0, 8.0), PLATFORM_TINT, 0.01)
	batch.ground(Vector2(12.0, 8.0), Vector2(22.0, 14.0), STREET_TINT, 0.0)
	_build_tracks()
	_build_train()
	_build_station_house()
	_build_platform()
	_build_edges()
	_register_points()


func _build_tracks() -> void:
	batch.box(Vector3(0.0, -0.02, -7.0), Vector3(90.0, 0.1, 5.0), Color("2b2a2a"))
	for x in range(-44, 45, 2):
		batch.box(Vector3(float(x), 0.05, -7.0), Vector3(0.36, 0.08, 3.4), Palette.WOOD_DARK)
	for z: float in [-7.8, -6.2]:
		batch.box(Vector3(0.0, 0.14, z), Vector3(90.0, 0.1, 0.1), Color("6a707a"))
	batch.box(Vector3(0.0, 0.22, -4.1), Vector3(44.0, 0.45, 0.3), Palette.STONE_LIGHT.darkened(0.2))
	collider(Vector3(0.0, 2.0, -4.3), Vector3(90.0, 4.0, 0.5))


func _build_train() -> void:
	var dark := Color("14171d")
	# Locomotora de vapor.
	var engine := Vector3(16.0, 0.0, -7.0)
	batch.box(engine + Vector3(-2.5, 2.0, 0.0), Vector3(3.0, 2.8, 2.5), dark)
	batch.box(engine + Vector3(-2.5, 3.5, 0.0), Vector3(3.3, 0.14, 2.8), Palette.INK)
	batch.box(engine + Vector3(-2.4, 2.5, 1.27), Vector3(1.0, 0.9, 0.04), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
	var boiler := batch.xform
	batch.xform = Transform3D(Basis(Vector3.BACK, PI * 0.5), engine + Vector3(4.2, 1.8, 0.0))
	batch.cylinder(Vector3.ZERO, 1.1, 1.1, 5.4, Color("1b1f27"), 10)
	batch.xform = boiler
	batch.cylinder(engine + Vector3(3.2, 2.9, 0.0), 0.32, 0.46, 1.1, dark, 8)
	batch.cylinder(engine + Vector3(0.8, 2.9, 0.0), 0.34, 0.34, 0.42, Color("7a5a2c"), 8)
	batch.box(engine + Vector3(0.0, 0.5, 0.0), Vector3(8.6, 0.32, 2.3), dark)
	for x: float in [-3.0, -1.0, 1.0, 3.0]:
		_wheel(engine + Vector3(x, 0.6, 1.2), 0.6)
	# Vagón de pasajeros.
	var car := Vector3(2.0, 0.0, -7.0)
	batch.box(car + Vector3(0.0, 1.9, 0.0), Vector3(11.0, 2.3, 2.5), Color("2a1f22"))
	batch.box(car + Vector3(0.0, 3.14, 0.0), Vector3(11.2, 0.2, 2.8), Palette.ROOF)
	batch.box(car + Vector3(0.0, 0.5, 0.0), Vector3(10.6, 0.3, 2.2), dark)
	for x: float in [-4.2, -2.4, -0.6, 1.2, 3.0, 4.6]:
		batch.box(car + Vector3(x, 2.2, 1.26), Vector3(1.1, 0.9, 0.03), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
	for x: float in [-4.0, -2.8, 2.8, 4.0]:
		_wheel(car + Vector3(x, 0.45, 1.2), 0.4)
	add_point_light(car + Vector3(0.0, 2.4, 3.0), Palette.WINDOW_WARM, 2.6, 8.0)


func _wheel(center: Vector3, radius: float) -> void:
	var saved := batch.xform
	batch.xform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center)
	batch.cylinder(Vector3.ZERO, radius, radius, 0.1, Color("2e323a"), 10)
	batch.cylinder(Vector3.UP * 0.1, radius * 0.4, radius * 0.4, 0.04, Palette.STEEL, 8)
	batch.xform = saved


func _build_station_house() -> void:
	BuildingKit.begin(self, Vector3(-11.0, 0.0, 2.0), 90.0)
	BuildingKit.body(self, 10.5, 4.6, 6.0, Palette.PLASTER_WARM, Palette.ROOF_RED, 2.0)
	BuildingKit.window(self, -3.8, 2.1, 1.2, 1.7, true)
	BuildingKit.window(self, 3.8, 2.1, 1.2, 1.7, false)
	# Taquilla con su ventanilla y su repisa.
	batch.box(Vector3(0.0, 1.6, 0.05), Vector3(3.2, 2.2, 0.12), Palette.WOOD_DARK)
	batch.box(Vector3(0.0, 1.7, 0.12), Vector3(2.2, 1.1, 0.04), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
	batch.box(Vector3(0.0, 1.02, 0.34), Vector3(3.0, 0.08, 0.56), Palette.WOOD_LIGHT)
	batch.box(Vector3(0.0, 3.1, 0.1), Vector3(3.6, 0.5, 0.06), Palette.WOOD_DARK)
	add_sign("TAQUILLA Y TELÉGRAFO", Vector3(0.0, 3.1, 0.15), 0.26, Palette.AMBER_SOFT)
	batch.box(Vector3(0.0, 4.15, 0.1), Vector3(6.6, 0.55, 0.06), Palette.PAPER.darkened(0.25))
	add_sign("VILLA SOMBRÍA", Vector3(0.0, 4.15, 0.15), 0.4, Palette.INK)
	add_point_light(Vector3(0.0, 2.8, 1.7), Palette.WINDOW_WARM, 2.6, 6.5)
	BuildingKit.end(self)


func _build_platform() -> void:
	# Marquesina sobre el andén.
	for x: float in [-6.0, 0.0, 6.0]:
		batch.cylinder(Vector3(x, 0.0, -2.8), 0.09, 0.09, 3.3, Palette.IRON, 6)
		collider(Vector3(x, 1.5, -2.8), Vector3(0.22, 3.0, 0.22))
	batch.box(Vector3(0.0, 3.4, -3.0), Vector3(15.0, 0.1, 2.2), Palette.ROOF)
	batch.box(Vector3(0.0, 3.3, -2.0), Vector3(15.0, 0.2, 0.08), Palette.WOOD_DARK)
	PropsKit.bench(self, Vector3(-3.0, 0.0, -2.8), 0.0)
	PropsKit.bench(self, Vector3(3.0, 0.0, -2.8), 0.0)
	PropsKit.street_lamp(self, Vector3(-9.0, 0.0, -2.6))
	PropsKit.street_lamp(self, Vector3(8.6, 0.0, -2.6), true)
	PropsKit.street_lamp(self, Vector3(14.0, 0.0, 6.6))
	PropsKit.street_lamp(self, Vector3(-0.6, 0.0, 6.6))
	PropsKit.crate(self, Vector3(-6.4, 0.0, 6.0), 0.9, 14.0)
	PropsKit.crate(self, Vector3(-5.5, 0.0, 6.4), 0.7, 40.0)
	PropsKit.barrel(self, Vector3(-4.6, 0.0, 6.6))
	# Reloj de andén, puntual como su jefe de estación.
	batch.cylinder(Vector3(10.6, 0.0, 0.2), 0.08, 0.08, 3.0, Palette.IRON, 6)
	var saved := batch.xform
	batch.xform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(10.6, 3.1, 0.25))
	batch.cylinder(Vector3.ZERO, 0.42, 0.42, 0.08, Palette.AMBER_SOFT, 10, MeshBatcher.Layer.GLOW)
	batch.xform = saved
	collider(Vector3(10.6, 1.5, 0.2), Vector3(0.2, 3.0, 0.2))


func _build_edges() -> void:
	PropsKit.low_wall(self, Vector3(-1.4, 0.3, 8.2), Vector3(26.0, 0.6, 0.4))
	PropsKit.low_wall(self, Vector3(22.2, 0.3, 3.0), Vector3(0.4, 0.6, 14.0))
	PropsKit.hedge(self, Vector3(12.0, 0.4, 11.0), Vector3(0.7, 0.8, 6.0))
	collider(Vector3(-16.0, 2.0, 2.0), Vector3(1.0, 4.0, 14.0))
	collider(Vector3(17.0, 2.0, 14.5), Vector3(11.0, 4.0, 1.0))
	collider(Vector3(23.0, 2.0, 10.0), Vector3(1.0, 4.0, 14.0))
	var labels: Array[String] = ["PLAZA MAYOR  >"]
	PropsKit.signpost(self, Vector3(13.5, 0.0, 7.4), labels)
	var road := LocationExit.new("plaza", "desde_estacion", "Ir a la plaza por la calle Mayor")
	road.travel_minutes = 20
	add_interactable(road, Vector3(17.0, 0.0, 12.6))


func _register_points() -> void:
	add_spawn("anden", Vector3(5.0, 0.1, -1.8), 180.0)
	add_spawn("desde_plaza", Vector3(17.0, 0.1, 10.4), 0.0)
	add_marker("taquilla", Vector3(-7.6, 0.0, 2.0))
	add_marker("banco_anden", Vector3(-3.0, 0.0, -1.8))
	add_marker("anden_norte", Vector3(6.0, 0.0, -0.8))
