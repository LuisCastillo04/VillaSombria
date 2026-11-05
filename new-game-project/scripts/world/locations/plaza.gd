extends LocationBase
## Plaza Mayor de Villa Sombría: el nudo que conecta todos los escenarios.
## Los edificios ocupan los lados -Z y -X para que sus fachadas miren a la cámara; los
## lados cercanos sólo llevan muretes y setos, de modo que nada tape al jugador.

const STREET_TINT := Color("8f93a0")
const SQUARE_TINT := Color("c9c6c0")
const SIDEWALK_TINT := Color("e3ddd2")
const VERGE_TINT := Color("3f4640")


func build() -> void:
	Atmosphere.add_exterior(self)
	camera_limits = Rect2(-9.0, -9.0, 24.0, 19.0)
	_build_ground()
	_build_cafe()
	_build_narrow_house()
	_build_archive()
	_build_mansion_gate()
	_build_bank()
	_build_square()
	_build_street_furniture()
	_build_edges()
	_register_points()


func _build_ground() -> void:
	collider(Vector3(5.0, -0.5, 0.0), Vector3(90.0, 1.0, 90.0))
	batch.ground(Vector2(-60.0, -60.0), Vector2(60.0, 60.0), VERGE_TINT, -0.04)
	# Calle Mayor, en forma de L, que rodea la plaza y sale hacia la estación.
	batch.ground(Vector2(-14.0, -14.0), Vector2(30.0, -7.0), STREET_TINT, 0.0)
	batch.ground(Vector2(-14.0, -7.0), Vector2(-8.0, 13.0), STREET_TINT, 0.0)
	# Aceras frente a las fachadas.
	batch.ground(Vector2(-14.0, -14.0), Vector2(30.0, -12.6), SIDEWALK_TINT, 0.015)
	batch.ground(Vector2(-14.0, -12.6), Vector2(-12.6, 13.0), SIDEWALK_TINT, 0.015)
	# Plaza central.
	batch.ground(Vector2(-8.0, -7.0), Vector2(15.0, 13.0), SQUARE_TINT, 0.01)
	for z: float in [-12.6]:
		batch.box(Vector3(8.0, 0.02, z), Vector3(44.0, 0.05, 0.14), Palette.STONE_LIGHT)
	batch.box(Vector3(-12.6, 0.02, 0.2), Vector3(0.14, 0.05, 25.6), Palette.STONE_LIGHT)
	batch.box(Vector3(3.5, 0.03, -7.0), Vector3(23.0, 0.06, 0.2), Palette.STONE_LIGHT.darkened(0.2))
	batch.box(Vector3(-8.0, 0.03, 3.0), Vector3(0.2, 0.06, 20.0), Palette.STONE_LIGHT.darkened(0.2))


func _build_cafe() -> void:
	BuildingKit.begin(self, Vector3(-7.0, 0.0, -14.0))
	BuildingKit.body(self, 11.0, 6.4, 7.0, Palette.PLASTER_WARM, Palette.ROOF_RED)
	# Escaparate iluminado y puerta de entrada.
	batch.box(Vector3(0.0, 1.75, 0.04), Vector3(10.4, 2.9, 0.1), Palette.WOOD_DARK)
	for x: float in [-3.6, -1.4, 3.0]:
		batch.box(Vector3(x, 1.8, 0.1), Vector3(1.9, 2.1, 0.04), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
		batch.box(Vector3(x, 2.2, 0.13), Vector3(1.9, 0.05, 0.03), Palette.WOOD_DARK)
	BuildingKit.door(self, 0.9, 1.3, 2.4, Palette.WOOD)
	BuildingKit.awning(self, 0.0, 3.5, 10.0, 1.7)
	BuildingKit.window_grid(self, 10.0, [4.9], 4, Vector2(1.0, 1.4), [true, false, false, true], true)
	batch.box(Vector3(0.0, 3.75, 0.1), Vector3(6.0, 0.62, 0.08), Palette.WOOD_DARK)
	add_sign("CAFÉ LA LUNA", Vector3(0.0, 3.75, 0.16), 0.46, Palette.AMBER_SOFT)
	add_point_light(Vector3(0.0, 2.2, 1.8), Palette.WINDOW_WARM, 3.0, 8.5)
	BuildingKit.chimney(self, Vector3(3.2, 7.4, -3.5))
	add_interactable(LocationExit.new("cafe", "desde_plaza", "Entrar en la cafetería"), Vector3(0.9, 0.0, 0.9))
	BuildingKit.end(self)

	PropsKit.cafe_table(self, Vector3(-9.4, 0.0, -11.9))
	PropsKit.cafe_table(self, Vector3(-3.4, 0.0, -11.9))


func _build_narrow_house() -> void:
	BuildingKit.begin(self, Vector3(0.6, 0.0, -14.0))
	BuildingKit.body(self, 4.2, 7.6, 6.0, Palette.SLATE.lightened(0.14), Palette.ROOF, 2.6)
	BuildingKit.window_grid(self, 4.0, [2.2, 4.4, 6.4], 2, Vector2(0.9, 1.3), [false, false, true, false, false, false])
	BuildingKit.end(self)


func _build_archive() -> void:
	BuildingKit.begin(self, Vector3(9.5, 0.0, -14.0))
	BuildingKit.body(self, 13.0, 6.2, 8.0, Palette.STONE, Palette.ROOF, 1.5)
	# Pórtico con columnas y frontón.
	batch.box(Vector3(0.0, 0.1, 0.7), Vector3(9.0, 0.2, 1.6), Palette.STONE_LIGHT)
	for x: float in [-3.6, -1.4, 1.4, 3.6]:
		BuildingKit.column(self, Vector3(x, 0.15, 1.1), 4.1)
	batch.box(Vector3(0.0, 4.35, 0.8), Vector3(9.0, 0.4, 1.8), Palette.STONE_LIGHT)
	batch.face(
		PackedVector3Array([Vector3(-4.6, 4.55, 1.72), Vector3(4.6, 4.55, 1.72), Vector3(0.0, 5.9, 1.72)]),
		Palette.STONE_LIGHT,
		Vector3.BACK
	)
	batch.face(
		PackedVector3Array([Vector3(-4.6, 4.55, 1.72), Vector3(0.0, 5.9, 1.72), Vector3(0.0, 5.9, 0.0), Vector3(-4.6, 4.55, 0.0)]),
		Palette.ROOF,
		Vector3(-0.3, 1.0, 0.0)
	)
	batch.face(
		PackedVector3Array([Vector3(4.6, 4.55, 1.72), Vector3(4.6, 4.55, 0.0), Vector3(0.0, 5.9, 0.0), Vector3(0.0, 5.9, 1.72)]),
		Palette.ROOF,
		Vector3(0.3, 1.0, 0.0)
	)
	add_sign("ARCHIVO MUNICIPAL", Vector3(0.0, 4.35, 1.72), 0.3, Palette.INK)
	BuildingKit.door(self, 0.0, 1.8, 3.0, Palette.WOOD_DARK)
	BuildingKit.window(self, -2.5, 2.1, 1.0, 2.0, true)
	BuildingKit.window(self, 2.5, 2.1, 1.0, 2.0, false)
	BuildingKit.window(self, -5.4, 2.1, 1.0, 2.0, false)
	BuildingKit.window(self, 5.4, 2.1, 1.0, 2.0, true)
	# Torre del reloj, visible desde toda la plaza.
	var tower := Vector3(4.9, 0.0, -2.0)
	batch.box(tower + Vector3.UP * 7.6, Vector3(2.6, 3.0, 2.6), Palette.STONE)
	batch.box(tower + Vector3.UP * 9.2, Vector3(2.9, 0.2, 2.9), Palette.STONE_LIGHT)
	batch.pyramid(tower + Vector3.UP * 9.3, Vector3(2.9, 1.9, 2.9), Palette.ROOF)
	_add_clock_face(tower + Vector3(0.0, 7.7, 1.33))
	add_point_light(Vector3(0.0, 3.6, 2.4), Palette.AMBER_SOFT, 2.0, 6.5)
	add_interactable(LocationExit.new("archivo", "desde_plaza", "Entrar en el archivo"), Vector3(0.0, 0.0, 1.2))
	BuildingKit.end(self)


func _add_clock_face(center: Vector3) -> void:
	var saved := batch.xform
	batch.xform = saved * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center)
	batch.cylinder(Vector3.ZERO, 0.85, 0.85, 0.06, Palette.AMBER_SOFT, 12, MeshBatcher.Layer.GLOW)
	batch.xform = saved
	batch.box(center + Vector3(0.0, 0.28, 0.06), Vector3(0.05, 0.56, 0.03), Palette.INK)
	batch.box(center + Vector3(0.2, 0.0, 0.06), Vector3(0.4, 0.05, 0.03), Palette.INK)


func _build_mansion_gate() -> void:
	BuildingKit.begin(self, Vector3(-14.0, 0.0, -3.0), 90.0)
	# La mansión asoma tras la verja, al fondo de su jardín.
	var mansion := Vector3(0.0, 0.0, -10.0)
	batch.box(mansion + Vector3.UP * 4.2, Vector3(18.0, 8.4, 6.0), Palette.STONE_DARK)
	batch.gable(mansion + Vector3.UP * 8.4, Vector3(6.8, 2.8, 18.6), Palette.ROOF, PI * 0.5, Palette.STONE_DARK)
	var saved := batch.xform
	batch.xform = saved * Transform3D(Basis.IDENTITY, mansion + Vector3(0.0, 0.0, 3.0))
	for y: float in [2.0, 5.6]:
		for x: float in [-7.0, -4.2, -1.4, 1.4, 4.2, 7.0]:
			BuildingKit.window(self, x, y, 1.1, 1.9, (int(x) + int(y)) % 3 == 0)
	batch.xform = saved
	# Tapia, pilares y verja de hierro.
	for x: float in [-6.7, 6.7]:
		solid(Vector3(x, 1.1, 0.0), Vector3(8.0, 2.2, 0.5), Palette.STONE_DARK)
		batch.box(Vector3(x, 2.26, 0.0), Vector3(8.2, 0.12, 0.66), Palette.STONE)
	for x: float in [-2.4, 2.4]:
		solid(Vector3(x, 1.7, 0.0), Vector3(0.9, 3.4, 0.9), Palette.STONE)
		batch.box(Vector3(x, 3.48, 0.0), Vector3(1.1, 0.16, 1.1), Palette.STONE_LIGHT)
		batch.sphere(Vector3(x, 3.8, 0.0), 0.28, Palette.STONE_LIGHT, 7, 4)
		batch.box(Vector3(x, 2.5, 0.48), Vector3(0.3, 0.42, 0.08), Palette.AMBER_SOFT, 0.0, MeshBatcher.Layer.GLOW)
		add_point_light(Vector3(x, 2.6, 1.1), Color("ffb765"), 2.2, 6.0)
	for index in 15:
		var x := -1.85 + 3.7 * float(index) / 14.0
		var bar_height := 2.4 + 0.5 * sin(PI * float(index) / 14.0)
		batch.box(Vector3(x, bar_height * 0.5, 0.0), Vector3(0.05, bar_height, 0.05), Palette.IRON)
	batch.box(Vector3(0.0, 1.1, 0.0), Vector3(3.8, 0.08, 0.06), Palette.IRON)
	batch.box(Vector3(0.0, 2.15, 0.0), Vector3(3.8, 0.08, 0.06), Palette.IRON)
	collider(Vector3(0.0, 1.5, 0.0), Vector3(3.9, 3.0, 0.3))
	add_sign("MANSIÓN VALDÉS", Vector3(0.0, 3.42, 0.08), 0.3, Palette.AMBER_SOFT)
	add_interactable(LocationExit.new("mansion", "desde_plaza", "Entrar en la mansión Valdés"), Vector3(0.0, 0.0, 0.9))
	BuildingKit.end(self)


func _build_bank() -> void:
	BuildingKit.begin(self, Vector3(-14.0, 0.0, 9.0), 90.0)
	BuildingKit.body(self, 10.0, 6.0, 6.0, Palette.PLASTER, Palette.ROOF, 1.8)
	BuildingKit.window_grid(self, 9.0, [2.3, 4.5], 3, Vector2(1.1, 1.5), [false, true, false, false, false, true])
	batch.box(Vector3(0.0, 5.45, 0.1), Vector3(5.0, 0.55, 0.06), Palette.STONE_DARK)
	add_sign("BANCO VALDÉS", Vector3(0.0, 5.45, 0.16), 0.36, Palette.PAPER)
	BuildingKit.end(self)


func _build_square() -> void:
	var fountain := Vector3(3.5, 0.0, 3.0)
	batch.cylinder(fountain, 3.0, 3.0, 0.14, Palette.STONE_DARK, 12)
	batch.cylinder(fountain, 2.5, 2.42, 0.62, Palette.STONE, 10)
	batch.cylinder(fountain + Vector3.UP * 0.6, 2.18, 2.18, 0.05, Color("1d3550"), 10)
	batch.cylinder(fountain + Vector3.UP * 0.56, 0.5, 0.26, 1.3, Palette.STONE, 8)
	batch.cylinder(fountain + Vector3.UP * 1.82, 0.95, 1.08, 0.14, Palette.STONE, 8)
	batch.cylinder(fountain + Vector3.UP * 1.96, 0.24, 0.16, 0.5, Palette.STONE_LIGHT, 6)
	batch.sphere(fountain + Vector3.UP * 2.6, 0.26, Palette.STONE_LIGHT, 7, 4)
	collider(fountain + Vector3.UP * 0.6, Vector3(3.4, 1.2, 3.4))
	collider(fountain + Vector3.UP * 0.6, Vector3(3.4, 1.2, 3.4), PI * 0.25)

	for offset: Vector3 in [Vector3(-5.6, 0.0, -6.0), Vector3(6.0, 0.0, -6.0), Vector3(-5.8, 0.0, 6.0), Vector3(6.2, 0.0, 6.0)]:
		PropsKit.street_lamp(self, fountain + offset, true)

	PropsKit.bench(self, Vector3(-3.4, 0.0, 3.0), 90.0)
	PropsKit.bench(self, Vector3(10.2, 0.0, 3.0), -90.0)
	PropsKit.bench(self, Vector3(3.5, 0.0, -3.4), 0.0)
	PropsKit.tree(self, Vector3(-5.2, 0.0, -3.8), 4.0)
	PropsKit.tree(self, Vector3(12.0, 0.0, -4.0), 3.8, true)
	PropsKit.tree(self, Vector3(-4.8, 0.0, 10.0), 3.6, true)
	PropsKit.tree(self, Vector3(12.4, 0.0, 9.6), 4.2)


func _build_street_furniture() -> void:
	PropsKit.street_lamp(self, Vector3(-12.2, 0.0, -9.5))
	PropsKit.street_lamp(self, Vector3(-12.2, 0.0, 5.4))
	PropsKit.street_lamp(self, Vector3(0.8, 0.0, -12.3))
	PropsKit.street_lamp(self, Vector3(17.5, 0.0, -12.3))
	PropsKit.street_lamp(self, Vector3(25.0, 0.0, -7.4))
	PropsKit.car(self, Vector3(9.5, 0.0, -9.0), 90.0)
	PropsKit.newsstand(self, Vector3(-6.0, 0.0, 10.6), 90.0)
	PropsKit.mailbox(self, Vector3(-2.2, 0.0, -12.1))
	PropsKit.crate(self, Vector3(17.2, 0.0, -13.2), 0.9, 12.0)
	PropsKit.crate(self, Vector3(18.1, 0.0, -13.3), 0.7, 35.0)
	PropsKit.barrel(self, Vector3(16.6, 0.0, -12.2))
	var labels: Array[String] = ["ESTACIÓN  >", "ARCHIVO  ^", "CAFÉ  ^"]
	PropsKit.signpost(self, Vector3(14.5, 0.0, -6.2), labels)


func _build_edges() -> void:
	PropsKit.low_wall(self, Vector3(3.5, 0.3, 13.2), Vector3(35.0, 0.6, 0.5))
	PropsKit.low_wall(self, Vector3(15.2, 0.3, 3.0), Vector3(0.5, 0.6, 20.0))
	PropsKit.hedge(self, Vector3(22.5, 0.4, -6.6), Vector3(15.0, 0.8, 0.7))
	# Límites invisibles del área jugable.
	collider(Vector3(29.6, 2.0, -10.0), Vector3(1.0, 4.0, 10.0))
	collider(Vector3(8.0, 2.0, -14.5), Vector3(50.0, 4.0, 1.0))
	collider(Vector3(-14.5, 2.0, 0.0), Vector3(1.0, 4.0, 30.0))
	collider(Vector3(3.0, 2.0, 14.0), Vector3(36.0, 4.0, 1.0))
	add_interactable(LocationExit.new("estacion", "desde_plaza", "Ir a la estación de tren"), Vector3(28.4, 0.0, -10.0))


func _register_points() -> void:
	add_spawn("inicio", Vector3(0.5, 0.1, -3.2), 135.0)
	add_spawn("desde_cafe", Vector3(-6.1, 0.1, -12.0), 180.0)
	add_spawn("desde_archivo", Vector3(9.5, 0.1, -11.4), 180.0)
	add_spawn("desde_mansion", Vector3(-12.2, 0.1, -3.0), -90.0)
	add_spawn("desde_estacion", Vector3(26.5, 0.1, -10.0), 90.0)
	add_marker("banco_fuente", Vector3(3.5, 0.0, -2.4))
	add_marker("fuente_oeste", Vector3(-1.4, 0.0, 3.0))
	add_marker("fuente_este", Vector3(8.6, 0.0, 3.0))
	add_marker("kiosco", Vector3(-4.5, 0.0, 10.5))
	add_marker("terraza", Vector3(-4.6, 0.0, -11.2))
	add_marker("calle_oeste", Vector3(-10.0, 0.0, -9.0))
	add_marker("calle_este", Vector3(13.0, 0.0, -9.4))
	add_marker("puerta_banco", Vector3(-11.8, 0.0, 9.0))
