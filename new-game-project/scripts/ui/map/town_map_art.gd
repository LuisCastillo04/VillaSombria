class_name TownMapArt
extends Control
## Ilustración del mapa de Villa Sombría, dibujada en código como el resto de la interfaz.
##
## Cada zona exterior se dibuja en metros de su propio escenario, con la misma transformación
## calibrada que sitúa al detective (`MapRegion.transform`): un edificio aparece en el mapa
## exactamente donde está su colisión en el juego, y el marcador nunca se separa del dibujo. Las
## medidas copian las de `scripts/world/locations/plaza.gd` y `estacion.gd`, y las pruebas comprueban
## que sigan coincidiendo con las colisiones reales.
##
## Los edificios se elevan con una proyección oblicua, como los ve la cámara del juego: las
## fachadas que dan al jugador se ven, con ventanas encendidas, y los tejados se desplazan hacia
## arriba según su altura.
##
## Lo que queda fuera de los escenarios (la calle Mayor entre la plaza y la estación, las casas y
## los árboles de los alrededores, la rosa de los vientos y la cartela) es decoración: no tiene
## chinchetas ni posiciones jugables.

## Metros que sube en pantalla cada metro de altura.
const LIFT := 0.42

const INK := Color("3a2614")
const INK_SOFT := Color(0.23, 0.15, 0.08, 0.5)
const INK_FAINT := Color(0.23, 0.15, 0.08, 0.12)
const STREET := Color("bea77c")
const SIDEWALK := Color("cdb88f")
const SQUARE := Color("d9c69f")
const PLATFORM := Color("d2bf98")
const GRASS := Color(0.4, 0.42, 0.24, 0.16)
const GARDEN := Color(0.33, 0.37, 0.2, 0.45)
const STONE := Color("a99d86")
const STONE_DARK := Color("7b7062")
const WALL_WARM := Color("b39470")
const WALL_STONE := Color("a39a88")
const WALL_DARK := Color("6f6455")
const WALL_SLATE := Color("8e8a80")
const WALL_PLASTER := Color("a8a092")
const ROOF_RED := Color("7d3c2b")
const ROOF_SLATE := Color("4b4850")
const ROOF_DARK := Color("3b3330")
const WINDOW_LIT := Color("ffca73")
const WINDOW_DARK := Color(0.2, 0.19, 0.2, 0.85)
const GLOW := Color(1.0, 0.72, 0.3)
const FOLIAGE := Color("66703f")
const FOLIAGE_DARK := Color("434d2a")
const FOLIAGE_AUTUMN := Color("b47a32")
const WATER := Color("5e8088")
const WOOD := Color("5a4128")
const IRON := Color("2b2622")
const WINE := Color("7e2b28")
const TRAIN := Color("2c2726")
const TRAIN_CAR := Color("4a2a28")
const BALLAST := Color(0.36, 0.3, 0.23, 0.55)
const RAIL := Color("4c4741")

## Orden de los lados de un rectángulo y su normal hacia fuera: norte (-Z), este (+X), sur (+Z)
## y oeste (-X).
const SIDE_NORMALS: Array[Vector2] = [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)]

## Edificios de la plaza. `rect` es la planta en X y Z; `collider` indica que el escenario tiene
## una colisión con esa misma planta (lo comprueban las pruebas).
const PLAZA_BUILDINGS: Array[Dictionary] = [
	{"id": "mansion", "rect": Rect2(-27.0, -12.0, 6.0, 18.0), "height": 8.4, "roof": 2.8, "ridge": "z", "wall": WALL_DARK, "roof_color": ROOF_DARK, "floors": [2.0, 5.6], "collider": false},
	{"id": "cafe", "rect": Rect2(-12.5, -21.0, 11.0, 7.0), "height": 6.4, "roof": 2.2, "ridge": "x", "wall": WALL_WARM, "roof_color": ROOF_RED, "floors": [4.9], "collider": true},
	{"id": "casa_estrecha", "rect": Rect2(-1.5, -20.0, 4.2, 6.0), "height": 7.6, "roof": 2.6, "ridge": "x", "wall": WALL_SLATE, "roof_color": ROOF_SLATE, "floors": [2.2, 4.4, 6.4], "collider": true},
	{"id": "archivo", "rect": Rect2(3.0, -22.0, 13.0, 8.0), "height": 6.2, "roof": 1.5, "ridge": "x", "wall": WALL_STONE, "roof_color": ROOF_SLATE, "floors": [2.1], "collider": true},
	{"id": "banco", "rect": Rect2(-20.0, 4.0, 6.0, 10.0), "height": 6.0, "roof": 1.8, "ridge": "z", "wall": WALL_PLASTER, "roof_color": ROOF_SLATE, "floors": [2.3, 4.5], "collider": true},
	{"id": "torre_reloj", "rect": Rect2(13.1, -17.3, 2.6, 2.6), "base": 6.2, "height": 9.2, "roof": 1.9, "ridge": "pyramid", "wall": WALL_STONE, "roof_color": ROOF_SLATE, "floors": [], "collider": false},
]

const STATION_BUILDINGS: Array[Dictionary] = [
	{"id": "estacion", "rect": Rect2(-17.0, -3.25, 6.0, 10.5), "height": 4.6, "roof": 2.0, "ridge": "z", "wall": WALL_WARM, "roof_color": ROOF_RED, "floors": [2.1], "collider": true},
]

## Farolas, como en los escenarios.
const PLAZA_LAMPS: Array[Vector2] = [
	Vector2(-2.1, -3.0), Vector2(9.5, -3.0), Vector2(-2.3, 9.0), Vector2(9.7, 9.0),
	Vector2(-12.2, -9.5), Vector2(-12.2, 5.4), Vector2(0.8, -12.3), Vector2(17.5, -12.3), Vector2(25.0, -7.4),
]
const STATION_LAMPS: Array[Vector2] = [Vector2(-9.0, -2.6), Vector2(8.6, -2.6), Vector2(14.0, 6.6), Vector2(-0.6, 6.6)]

## Árboles: posición, altura y si tienen hojas de otoño.
const PLAZA_TREES: Array[Dictionary] = [
	{"at": Vector2(-5.2, -3.8), "height": 4.0, "autumn": false},
	{"at": Vector2(12.0, -4.0), "height": 3.8, "autumn": true},
	{"at": Vector2(-4.8, 10.0), "height": 3.6, "autumn": true},
	{"at": Vector2(12.4, 9.6), "height": 4.2, "autumn": false},
]

## Casas de los alrededores, sólo decorativas, en metros de la plaza: rectángulo, altura y tejado.
const OUTSKIRTS_PLAZA: Array[Dictionary] = [
	{"rect": Rect2(31.5, -22.0, 6.0, 5.0), "height": 5.2, "roof_color": ROOF_SLATE},
	{"rect": Rect2(38.5, -23.0, 5.0, 6.0), "height": 6.0, "roof_color": ROOF_RED},
	{"rect": Rect2(34.0, -1.0, 6.0, 5.0), "height": 5.0, "roof_color": ROOF_RED},
	{"rect": Rect2(-24.0, 18.0, 7.0, 5.0), "height": 5.0, "roof_color": ROOF_SLATE},
	{"rect": Rect2(-14.0, 19.0, 5.0, 5.0), "height": 5.6, "roof_color": ROOF_RED},
	{"rect": Rect2(18.0, 18.0, 6.0, 5.0), "height": 4.8, "roof_color": ROOF_SLATE},
]
const OUTSKIRTS_STATION: Array[Dictionary] = [
	{"rect": Rect2(-2.0, 17.0, 6.0, 5.0), "height": 5.0, "roof_color": ROOF_SLATE},
	{"rect": Rect2(27.0, 4.0, 5.0, 6.0), "height": 4.6, "roof_color": ROOF_RED},
]
const OUTSKIRTS_TREES: Array[Vector2] = [
	Vector2(120.0, 560.0), Vector2(95.0, 640.0), Vector2(150.0, 700.0), Vector2(1500.0, 150.0),
	Vector2(1545.0, 230.0), Vector2(1460.0, 300.0), Vector2(830.0, 120.0), Vector2(760.0, 175.0),
	Vector2(1010.0, 880.0), Vector2(930.0, 920.0), Vector2(640.0, 905.0), Vector2(1110.0, 930.0),
	Vector2(1530.0, 640.0), Vector2(345.0, 920.0),
]

## Lienzo → píxeles locales; lo actualiza TownMapView al cambiar de tamaño.
var view_transform := Transform2D.IDENTITY:
	set(value):
		view_transform = value
		queue_redraw()

## Transformación de la zona que se está dibujando (metros → píxeles), un metro hacia arriba en
## pantalla y la dirección de las sombras, en metros de la zona.
var _xf := Transform2D.IDENTITY
var _up := Vector2.ZERO
var _shadow := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	var plaza := TownMap.get_region("plaza")
	var station := TownMap.get_region("estacion")
	_draw_map_border()
	for region in [plaza, station]:
		if region != null:
			_begin_region(region)
			_draw_surroundings(region)
	if plaza != null and station != null:
		_draw_main_street(plaza, station)
	_draw_outskirts(plaza, OUTSKIRTS_PLAZA)
	_draw_outskirts(station, OUTSKIRTS_STATION)
	_draw_set_canvas()
	for tree_at in OUTSKIRTS_TREES:
		_draw_canvas_tree(tree_at)
	if plaza != null:
		_begin_region(plaza)
		_draw_plaza()
	if station != null:
		_begin_region(station)
		_draw_station()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_compass(Vector2(190.0, 845.0), 66.0)
	_draw_cartouche(Vector2(1385.0, 900.0))
	if plaza != null:
		_draw_world_label(plaza, Vector2(-10.6, 9.6), "Banco Valdés", 17.0)
	if plaza != null and station != null:
		_draw_street_name(main_street_points(plaza, station), "Calle Mayor")


# --- Transformaciones --------------------------------------------------------------------

func _begin_region(region: MapRegion) -> void:
	_xf = view_transform * region.transform
	draw_set_transform_matrix(_xf)
	var inverse := _xf.affine_inverse()
	_up = inverse.basis_xform(Vector2(0.0, -1.0)).normalized() * LIFT
	_shadow = inverse.basis_xform(Vector2(0.85, 0.5)).normalized()


func _draw_set_canvas() -> void:
	_xf = view_transform
	draw_set_transform_matrix(view_transform)


func _lift(point: Vector2, height: float) -> Vector2:
	return point + _up * height


func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _lifted(points: PackedVector2Array, height: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(_lift(point, height))
	return result


func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


## Si una cara con esta normal mira hacia el jugador (hacia abajo en pantalla).
func _faces_viewer(normal: Vector2) -> bool:
	return _xf.basis_xform(normal).y > 0.001


## Las caras que miran a la izquierda reciben la luz; las de la derecha quedan en sombra.
func _shade(color: Color, normal: Vector2) -> Color:
	var screen := _xf.basis_xform(normal).normalized()
	return color.lightened(0.1) if screen.x < 0.0 else color.darkened(0.24)


# --- Piezas ------------------------------------------------------------------------------

## Caja extruida con tapa plana: muretes, setos, vagones, andenes.
func _draw_box(rect: Rect2, base: float, height: float, color: Color, outline: bool = true) -> void:
	var corners := _corners(rect)
	for side in 4:
		var normal := SIDE_NORMALS[side]
		if not _faces_viewer(normal):
			continue
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var wall := PackedVector2Array([_lift(a, base), _lift(b, base), _lift(b, height), _lift(a, height)])
		draw_colored_polygon(wall, _shade(color, normal))
		if outline:
			_outline(wall, INK_SOFT, 0.06)
	var top := _lifted(corners, height)
	draw_colored_polygon(top, color)
	if outline:
		_outline(top, INK_SOFT, 0.06)


func _draw_ground_shadow(rect: Rect2, height: float, strength: float = 0.2) -> void:
	var corners := _corners(rect)
	var points := PackedVector2Array(corners)
	for corner in corners:
		points.append(corner + _shadow * height * 0.45)
	var hull := Geometry2D.convex_hull(points)
	draw_colored_polygon(hull, Color(0.12, 0.07, 0.03, strength))


## Edificio con paredes, ventanas y tejado a dos aguas (cumbrera en X o en Z) o a cuatro.
func _draw_building(building: Dictionary) -> void:
	var rect: Rect2 = building["rect"]
	var base := float(building.get("base", 0.0))
	var height := float(building["height"])
	var wall_color: Color = building["wall"]
	if base == 0.0:
		_draw_ground_shadow(rect, height + float(building.get("roof", 0.0)) * 0.6)
	var corners := _corners(rect)
	for side in 4:
		var normal := SIDE_NORMALS[side]
		if not _faces_viewer(normal):
			continue
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var wall := PackedVector2Array([_lift(a, base), _lift(b, base), _lift(b, height), _lift(a, height)])
		draw_colored_polygon(wall, _shade(wall_color, normal))
		_draw_windows(building, side, a, b, base)
		_outline(wall, Color(INK, 0.75), 0.07)
	_draw_roof(building, rect.grow(0.25), height)


func _draw_windows(building: Dictionary, side: int, from: Vector2, to: Vector2, base: float) -> void:
	var length := from.distance_to(to)
	if length < 2.4:
		return
	var direction := (to - from) / length
	var count := int((length - 1.2) / 2.4)
	for floor_index in (building["floors"] as Array).size():
		var floor_y := float(building["floors"][floor_index]) + base
		for column in count:
			var along := (length - 2.4 * (count - 1)) * 0.5 + 2.4 * column
			var center := from + direction * along
			var key := "%s/%d/%d/%d" % [building["id"], side, floor_index, column]
			var lit := key.hash() % 100 < 55
			var half := direction * 0.42
			var pane := PackedVector2Array([
				_lift(center - half, floor_y - 0.6), _lift(center + half, floor_y - 0.6),
				_lift(center + half, floor_y + 0.6), _lift(center - half, floor_y + 0.6),
			])
			if lit:
				draw_circle(_lift(center, floor_y), 0.95, Color(GLOW, 0.22), true, -1.0, true)
			draw_colored_polygon(pane, WINDOW_LIT if lit else WINDOW_DARK)


func _draw_roof(building: Dictionary, rect: Rect2, height: float) -> void:
	var rise := float(building.get("roof", 0.0))
	var color: Color = building["roof_color"]
	var gable_color := (building["wall"] as Color).darkened(0.3)
	var ridge: String = building.get("ridge", "flat")
	var faces: Array = []
	var gables: Array = []
	match ridge:
		"x":
			var mid := rect.get_center().y
			var west_ridge := Vector2(rect.position.x, mid)
			var east_ridge := Vector2(rect.end.x, mid)
			faces.append([[Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y)], [east_ridge, west_ridge], Vector2(0.0, -1.0)])
			faces.append([[Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y)], [west_ridge, east_ridge], Vector2(0.0, 1.0)])
			gables.append([Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), east_ridge, Vector2(1.0, 0.0)])
			gables.append([Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.position.y), west_ridge, Vector2(-1.0, 0.0)])
		"z":
			var mid := rect.get_center().x
			var north_ridge := Vector2(mid, rect.position.y)
			var south_ridge := Vector2(mid, rect.end.y)
			faces.append([[Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.position.y)], [north_ridge, south_ridge], Vector2(-1.0, 0.0)])
			faces.append([[Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y)], [south_ridge, north_ridge], Vector2(1.0, 0.0)])
			gables.append([Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y), south_ridge, Vector2(0.0, 1.0)])
			gables.append([Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), north_ridge, Vector2(0.0, -1.0)])
		"pyramid":
			var apex := rect.get_center()
			var corners := _corners(rect)
			for side in 4:
				faces.append([[corners[side], corners[(side + 1) % 4]], [apex, apex], SIDE_NORMALS[side]])
		_:
			var top := _lifted(_corners(rect), height)
			draw_colored_polygon(top, color)
			_outline(top, Color(INK, 0.75), 0.07)
			return
	for gable: Array in gables:
		if _faces_viewer(gable[3]):
			var triangle := PackedVector2Array([_lift(gable[0], height), _lift(gable[1], height), _lift(gable[2], height + rise)])
			draw_colored_polygon(triangle, _shade(gable_color, gable[3]))
			_outline(triangle, Color(INK, 0.7), 0.06)
	# Primero los faldones de atrás, que quedan arriba en pantalla.
	faces.sort_custom(func(left: Array, right: Array) -> bool: return _xf.basis_xform(left[2]).y < _xf.basis_xform(right[2]).y)
	for face: Array in faces:
		var eave: Array = face[0]
		var top_edge: Array = face[1]
		var points := PackedVector2Array([_lift(eave[0], height), _lift(eave[1], height), _lift(top_edge[0], height + rise)])
		if top_edge[0] != top_edge[1]:
			points.append(_lift(top_edge[1], height + rise))
		draw_colored_polygon(points, _shade(color, face[2]))
		_outline(points, Color(INK, 0.75), 0.07)


func _draw_tree(at: Vector2, height: float, autumn: bool) -> void:
	var crown := height * 0.36
	var center := _lift(at, height * 0.72)
	draw_circle(at + _shadow * height * 0.3, crown * 0.9, Color(0.12, 0.07, 0.03, 0.16), true, -1.0, true)
	draw_line(at, center, WOOD, 0.22, true)
	var main := FOLIAGE_AUTUMN if autumn else FOLIAGE
	var light := -_shadow * crown
	draw_circle(center, crown * 1.07, Color(INK, 0.5), true, -1.0, true)
	draw_circle(center, crown, main.darkened(0.2), true, -1.0, true)
	draw_circle(center + light * 0.22, crown * 0.68, main, true, -1.0, true)
	draw_circle(center + light * 0.36, crown * 0.28, main.lightened(0.18), true, -1.0, true)


func _draw_lamp(at: Vector2) -> void:
	draw_circle(at, 2.6, Color(GLOW, 0.1), true, -1.0, true)
	draw_circle(at, 1.4, Color(GLOW, 0.1), true, -1.0, true)
	var head := _lift(at, 3.4)
	draw_line(at, head, IRON, 0.13, true)
	draw_circle(head, 0.95, Color(GLOW, 0.22), true, -1.0, true)
	draw_circle(head, 0.48, Color(GLOW, 0.55), true, -1.0, true)
	draw_circle(head, 0.22, WINDOW_LIT.lightened(0.3), true, -1.0, true)


func _draw_bench(at: Vector2, along_x: bool) -> void:
	var size := Vector2(1.9, 0.5) if along_x else Vector2(0.5, 1.9)
	_draw_box(Rect2(at - size * 0.5, size), 0.0, 0.48, WOOD)


func _draw_glow_quad(center: Vector2, along: Vector2, half_width: float, bottom: float, top: float) -> void:
	var quad := PackedVector2Array([
		_lift(center - along * half_width, bottom), _lift(center + along * half_width, bottom),
		_lift(center + along * half_width, top), _lift(center - along * half_width, top),
	])
	draw_circle(_lift(center, (bottom + top) * 0.5), half_width * 2.2, Color(GLOW, 0.2), true, -1.0, true)
	draw_colored_polygon(quad, WINDOW_LIT)


# --- Plaza -------------------------------------------------------------------------------

func _draw_surroundings(region: MapRegion) -> void:
	for step in 4:
		draw_rect(region.bounds.grow(3.0 + 2.5 * step), Color(GRASS, GRASS.a * (1.0 - step * 0.22)))


func _draw_plaza() -> void:
	# Calle Mayor en L, aceras, plaza y bordillos.
	for street in [Rect2(-14.0, -14.0, 44.0, 7.0), Rect2(-14.0, -7.0, 6.0, 20.0)]:
		draw_rect(street, STREET)
	draw_rect(Rect2(-14.0, -14.0, 44.0, 1.4), SIDEWALK)
	draw_rect(Rect2(-14.0, -12.6, 1.4, 25.6), SIDEWALK)
	draw_rect(Rect2(-8.0, -7.0, 23.0, 20.0), SQUARE)
	for x in range(-6, 15, 2):
		draw_line(Vector2(x, -7.0), Vector2(x, 13.0), INK_FAINT, 0.05, true)
	for z in range(-5, 13, 2):
		draw_line(Vector2(-8.0, z), Vector2(15.0, z), INK_FAINT, 0.05, true)
	_outline(_corners(Rect2(-8.0, -7.0, 23.0, 20.0)), INK_SOFT, 0.12)
	draw_line(Vector2(-12.6, -12.6), Vector2(30.0, -12.6), INK_SOFT, 0.08, true)
	draw_line(Vector2(-12.6, -12.6), Vector2(-12.6, 13.0), INK_SOFT, 0.08, true)
	draw_polyline(PackedVector2Array([Vector2(30.0, -14.0), Vector2(-14.0, -14.0), Vector2(-14.0, 13.0)]), INK_SOFT, 0.12, true)
	draw_line(Vector2(-8.0, -7.0), Vector2(30.0, -7.0), INK_SOFT, 0.1, true)
	# Jardín de la mansión, con el camino de la verja a la puerta.
	draw_rect(Rect2(-21.0, -13.7, 7.0, 21.4), GARDEN)
	draw_rect(Rect2(-21.0, -4.0, 7.0, 2.0), Color(SIDEWALK, 0.9))
	_draw_ground_details()
	_draw_square_props()
	var items: Array = []
	for building in PLAZA_BUILDINGS:
		items.append({"depth": _depth(building["rect"].get_center()), "draw": _draw_building.bind(building)})
	items.append({"depth": _depth(Vector2(-14.0, -3.0)), "draw": _draw_mansion_gate})
	items.append({"depth": _depth(Vector2(9.5, -13.2)), "draw": _draw_archive_portico})
	items.append({"depth": _depth(Vector2(-7.0, -13.0)), "draw": _draw_cafe_front})
	for tree in PLAZA_TREES:
		items.append({"depth": _depth(tree["at"]), "draw": _draw_tree.bind(tree["at"], tree["height"], tree["autumn"])})
	for lamp in PLAZA_LAMPS:
		items.append({"depth": _depth(lamp), "draw": _draw_lamp.bind(lamp)})
	_draw_sorted(items)


## Muretes, setos, coche, quiosco y bultos: piezas bajas que van antes que los edificios.
func _draw_ground_details() -> void:
	_draw_box(Rect2(-14.0, 12.95, 35.0, 0.5), 0.0, 0.6, STONE)
	_draw_box(Rect2(14.95, -7.0, 0.5, 20.0), 0.0, 0.6, STONE)
	_draw_box(Rect2(15.0, -6.95, 15.0, 0.7), 0.0, 0.8, FOLIAGE_DARK)
	_draw_ground_shadow(Rect2(7.45, -9.85, 4.1, 1.7), 1.2, 0.18)
	_draw_box(Rect2(7.45, -9.85, 4.1, 1.7), 0.0, 0.8, IRON)
	_draw_box(Rect2(8.6, -9.75, 2.0, 1.5), 0.8, 1.4, Color("3a4252"))
	draw_circle(_lift(Vector2(7.45, -9.4), 0.7), 0.35, Color(GLOW, 0.6), true, -1.0, true)
	draw_circle(_lift(Vector2(7.45, -8.6), 0.7), 0.35, Color(GLOW, 0.6), true, -1.0, true)
	_draw_box(Rect2(-6.75, 9.3, 1.5, 2.6), 0.0, 2.2, WINE.darkened(0.2))
	_draw_box(Rect2(16.75, -13.65, 0.9, 0.9), 0.0, 0.9, WOOD)
	_draw_box(Rect2(17.75, -13.65, 0.7, 0.7), 0.0, 0.7, WOOD.lightened(0.1))
	draw_circle(Vector2(16.6, -12.2), 0.35, WOOD.darkened(0.2), true, -1.0, true)
	draw_circle(Vector2(-2.2, -12.1), 0.3, WINE, true, -1.0, true)
	draw_line(Vector2(14.5, -6.2), _lift(Vector2(14.5, -6.2), 2.7), WOOD, 0.12, true)
	draw_line(_lift(Vector2(13.6, -6.2), 2.4), _lift(Vector2(15.4, -6.2), 2.4), SIDEWALK.darkened(0.2), 0.3, true)


func _draw_square_props() -> void:
	var fountain := Vector2(3.5, 3.0)
	draw_circle(fountain + _shadow * 0.6, 3.1, Color(0.12, 0.07, 0.03, 0.18), true, -1.0, true)
	draw_circle(fountain, 3.0, STONE_DARK, true, -1.0, true)
	draw_circle(_lift(fountain, 0.62), 2.55, STONE, true, -1.0, true)
	draw_arc(_lift(fountain, 0.62), 2.55, 0.0, TAU, 40, INK_SOFT, 0.1, true)
	draw_circle(_lift(fountain, 0.6), 2.18, WATER, true, -1.0, true)
	draw_arc(_lift(fountain, 0.6), 1.4, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.18), 0.08, true)
	draw_line(_lift(fountain, 0.6), _lift(fountain, 1.85), STONE, 0.5, true)
	draw_circle(_lift(fountain, 1.9), 1.0, STONE, true, -1.0, true)
	draw_arc(_lift(fountain, 1.9), 1.0, 0.0, TAU, 28, INK_SOFT, 0.08, true)
	draw_circle(_lift(fountain, 2.6), 0.3, STONE.lightened(0.2), true, -1.0, true)
	_draw_bench(Vector2(-3.4, 3.0), false)
	_draw_bench(Vector2(10.2, 3.0), false)
	_draw_bench(Vector2(3.5, -3.4), true)
	for table: Vector2 in [Vector2(-9.4, -11.9), Vector2(-3.4, -11.9)]:
		draw_circle(table, 0.5, SIDEWALK.darkened(0.25), true, -1.0, true)
		draw_arc(table, 0.5, 0.0, TAU, 16, INK_SOFT, 0.06, true)


func _draw_mansion_gate() -> void:
	for wall in [Rect2(-14.25, -13.7, 0.5, 8.0), Rect2(-14.25, -0.3, 0.5, 8.0)]:
		_draw_box(wall, 0.0, 2.2, STONE_DARK)
	for pillar_z: float in [-5.4, -0.6]:
		var pillar := Rect2(-14.45, pillar_z - 0.45, 0.9, 0.9)
		_draw_box(pillar, 0.0, 3.4, STONE)
		draw_circle(_lift(Vector2(-13.6, pillar_z), 2.5), 0.9, Color(GLOW, 0.3), true, -1.0, true)
		draw_circle(_lift(Vector2(-13.6, pillar_z), 2.5), 0.3, WINDOW_LIT, true, -1.0, true)
	for index in 9:
		var z := -4.85 + 3.7 * float(index) / 8.0
		draw_line(Vector2(-14.0, z), _lift(Vector2(-14.0, z), 2.4 + 0.5 * sin(PI * index / 8.0)), IRON, 0.08, true)
	draw_line(_lift(Vector2(-14.0, -4.85), 2.15), _lift(Vector2(-14.0, -1.15), 2.15), IRON, 0.08, true)


func _draw_archive_portico() -> void:
	_draw_box(Rect2(5.0, -14.1, 9.0, 1.6), 0.0, 0.2, STONE.lightened(0.1))
	for x: float in [5.9, 8.1, 10.9, 13.1]:
		draw_line(_lift(Vector2(x, -12.9), 0.2), _lift(Vector2(x, -12.9), 4.15), STONE.lightened(0.2), 0.42, true)
		draw_line(_lift(Vector2(x + 0.18, -12.9), 0.2), _lift(Vector2(x + 0.18, -12.9), 4.15), Color(INK, 0.35), 0.08, true)
	_draw_box(Rect2(5.0, -14.0, 9.0, 1.8), 4.15, 4.55, STONE.lightened(0.15))
	var pediment := PackedVector2Array([_lift(Vector2(5.0, -12.3), 4.55), _lift(Vector2(14.0, -12.3), 4.55), _lift(Vector2(9.5, -12.3), 5.9)])
	draw_colored_polygon(pediment, STONE.lightened(0.05))
	_outline(pediment, Color(INK, 0.7), 0.07)
	_draw_glow_quad(Vector2(9.5, -14.0), Vector2.RIGHT, 0.9, 0.0, 2.6)
	# Esfera del reloj en la torre.
	draw_circle(_lift(Vector2(14.4, -14.7), 7.7), 0.85, Color(GLOW, 0.3), true, -1.0, true)
	draw_circle(_lift(Vector2(14.4, -14.7), 7.7), 0.6, WINDOW_LIT, true, -1.0, true)


func _draw_cafe_front() -> void:
	_draw_glow_quad(Vector2(-6.1, -14.0), Vector2.RIGHT, 0.65, 0.0, 2.3)
	# Toldo a rayas granate y crema sobre el escaparate.
	var stripes := 20
	for index in stripes:
		var x0 := -12.0 + 10.0 * index / stripes
		var x1 := -12.0 + 10.0 * (index + 1) / stripes
		var stripe := PackedVector2Array([
			_lift(Vector2(x0, -13.9), 3.5), _lift(Vector2(x1, -13.9), 3.5),
			_lift(Vector2(x1, -12.3), 2.95), _lift(Vector2(x0, -12.3), 2.95),
		])
		draw_colored_polygon(stripe, WINE if index % 2 == 0 else Color("e3d2b0"))
	_outline(PackedVector2Array([
		_lift(Vector2(-12.0, -13.9), 3.5), _lift(Vector2(-2.0, -13.9), 3.5),
		_lift(Vector2(-2.0, -12.3), 2.95), _lift(Vector2(-12.0, -12.3), 2.95),
	]), Color(INK, 0.7), 0.06)


# --- Estación ----------------------------------------------------------------------------

func _draw_station() -> void:
	draw_rect(Rect2(-45.0, -9.5, 90.0, 5.0), BALLAST)
	for x in range(-44, 45, 2):
		draw_rect(Rect2(float(x) - 0.18, -8.7, 0.36, 3.4), Color(WOOD, 0.85))
	for z: float in [-7.8, -6.2]:
		draw_line(Vector2(-45.0, z), Vector2(45.0, z), RAIL, 0.14, true)
	draw_rect(Rect2(-17.0, -4.0, 39.0, 12.0), PLATFORM)
	draw_rect(Rect2(12.0, 8.0, 10.0, 6.0), STREET)
	_outline(_corners(Rect2(-17.0, -4.0, 39.0, 12.0)), INK_SOFT, 0.12)
	for x in range(-16, 22, 2):
		draw_line(Vector2(x, -4.0), Vector2(x, 8.0), INK_FAINT, 0.05, true)
	_draw_box(Rect2(-22.0, -4.25, 44.0, 0.3), 0.0, 0.45, STONE)
	_draw_box(Rect2(-14.4, 8.0, 26.0, 0.4), 0.0, 0.6, STONE)
	_draw_box(Rect2(22.0, -4.0, 0.4, 14.0), 0.0, 0.6, STONE)
	_draw_box(Rect2(11.65, 8.0, 0.7, 6.0), 0.0, 0.8, FOLIAGE_DARK)
	for crate: Rect2 in [Rect2(-6.85, 5.55, 0.9, 0.9), Rect2(-5.85, 6.05, 0.7, 0.7)]:
		_draw_box(crate, 0.0, crate.size.x, WOOD)
	draw_circle(Vector2(-4.6, 6.6), 0.35, WOOD.darkened(0.2), true, -1.0, true)
	_draw_bench(Vector2(-3.0, -2.8), true)
	_draw_bench(Vector2(3.0, -2.8), true)
	var items: Array = []
	for building in STATION_BUILDINGS:
		items.append({"depth": _depth(building["rect"].get_center()), "draw": _draw_building.bind(building)})
	items.append({"depth": _depth(Vector2(-11.0, 2.0)), "draw": _draw_ticket_office})
	items.append({"depth": _depth(Vector2(2.0, -7.0)), "draw": _draw_train})
	items.append({"depth": _depth(Vector2(0.0, -2.8)), "draw": _draw_canopy})
	items.append({"depth": _depth(Vector2(10.6, 0.2)), "draw": _draw_platform_clock})
	for lamp in STATION_LAMPS:
		items.append({"depth": _depth(lamp), "draw": _draw_lamp.bind(lamp)})
	_draw_sorted(items)


func _draw_ticket_office() -> void:
	_draw_glow_quad(Vector2(-11.0, 2.0), Vector2.DOWN, 1.1, 1.15, 2.25)


func _draw_train() -> void:
	_draw_ground_shadow(Rect2(-3.5, -8.25, 26.4, 2.5), 3.0, 0.15)
	_draw_box(Rect2(-3.5, -8.1, 11.0, 2.2), 0.3, 0.65, IRON, false)
	_draw_box(Rect2(-3.5, -8.25, 11.0, 2.5), 0.65, 3.04, TRAIN_CAR)
	_draw_box(Rect2(-3.6, -8.4, 11.2, 2.8), 3.04, 3.24, ROOF_SLATE)
	for x: float in [-4.2, -2.4, -0.6, 1.2, 3.0, 4.6]:
		_draw_glow_quad(Vector2(2.0 + x, -5.75), Vector2.RIGHT, 0.55, 1.75, 2.65)
	_draw_box(Rect2(11.7, -8.15, 8.6, 2.3), 0.35, 0.66, IRON, false)
	_draw_box(Rect2(17.5, -8.1, 5.4, 2.2), 0.66, 2.9, TRAIN)
	_draw_box(Rect2(12.0, -8.25, 3.0, 2.5), 0.66, 3.43, TRAIN)
	_draw_box(Rect2(11.85, -8.4, 3.3, 2.8), 3.43, 3.57, IRON)
	_draw_glow_quad(Vector2(13.6, -5.75), Vector2.RIGHT, 0.5, 2.05, 2.95)
	draw_circle(_lift(Vector2(19.2, -7.0), 3.5), 0.42, IRON, true, -1.0, true)


func _draw_canopy() -> void:
	for x: float in [-6.0, 0.0, 6.0]:
		draw_line(Vector2(x, -2.8), _lift(Vector2(x, -2.8), 3.3), IRON, 0.12, true)
	var roof := _lifted(_corners(Rect2(-7.5, -4.1, 15.0, 2.2)), 3.4)
	draw_colored_polygon(roof, Color(ROOF_SLATE, 0.88))
	_outline(roof, Color(INK, 0.7), 0.07)


func _draw_platform_clock() -> void:
	var at := Vector2(10.6, 0.2)
	draw_line(at, _lift(at, 3.0), IRON, 0.12, true)
	draw_circle(_lift(at, 3.1), 0.7, Color(GLOW, 0.3), true, -1.0, true)
	draw_circle(_lift(at, 3.1), 0.42, WINDOW_LIT, true, -1.0, true)


# --- Calle Mayor y alrededores -----------------------------------------------------------

## La calle Mayor une la salida este de la plaza con la de la estación (veinte minutos a pie). El
## recorrido intermedio no es jugable: se dibuja como una curva suave entre las dos salidas.
func _draw_main_street(plaza: MapRegion, station: MapRegion) -> void:
	_draw_set_canvas()
	var points := main_street_points(plaza, station)
	var width := 7.0 * plaza.map_units_per_meter()
	draw_polyline(points, Color(INK, 0.45), width + 5.0, true)
	draw_polyline(points, STREET, width, true)
	draw_polyline(points, Color(SIDEWALK, 0.55), width * 0.12, true)


## Puntos de la calle Mayor en el lienzo, de la plaza a la estación.
static func main_street_points(plaza: MapRegion, station: MapRegion) -> PackedVector2Array:
	var start := plaza.world_to_map(Vector2(30.0, -10.5))
	var start_out := plaza.map_direction(Vector2(1.0, 0.0))
	var end := station.world_to_map(Vector2(17.0, 14.0))
	var end_out := station.map_direction(Vector2(0.0, 1.0))
	var reach := start.distance_to(end) * 0.38
	var curve := Curve2D.new()
	curve.add_point(start, Vector2.ZERO, start_out * reach)
	curve.add_point(end, end_out * reach, Vector2.ZERO)
	curve.bake_interval = 12.0
	return curve.get_baked_points()


func _draw_outskirts(region: MapRegion, houses: Array[Dictionary]) -> void:
	if region == null:
		return
	_begin_region(region)
	for house in houses:
		var rect: Rect2 = house["rect"]
		var building := {
			"id": "afueras_%d_%d" % [int(rect.position.x), int(rect.position.y)], "rect": rect,
			"height": house["height"], "roof": 1.8, "ridge": "x" if rect.size.x >= rect.size.y else "z",
			"wall": Color(WALL_WARM, 0.9).darkened(0.08), "roof_color": house["roof_color"], "floors": [2.2],
		}
		_draw_building(building)


func _draw_canvas_tree(at: Vector2) -> void:
	var radius := 17.0
	draw_circle(at + Vector2(7.0, 5.0), radius, Color(0.12, 0.07, 0.03, 0.16), true, -1.0, true)
	draw_circle(at, radius * 1.06, Color(INK, 0.5), true, -1.0, true)
	draw_circle(at, radius, FOLIAGE.darkened(0.2), true, -1.0, true)
	draw_circle(at + Vector2(-4.0, -4.0), radius * 0.66, FOLIAGE, true, -1.0, true)
	draw_circle(at + Vector2(-6.0, -6.0), radius * 0.28, FOLIAGE.lightened(0.18), true, -1.0, true)


func _draw_map_border() -> void:
	_draw_set_canvas()
	var canvas := Rect2(Vector2.ZERO, TownMap.canvas_size)
	draw_rect(canvas.grow(-22.0), Color(INK, 0.55), false, 2.4, true)
	draw_rect(canvas.grow(-30.0), Color(INK, 0.3), false, 1.2, true)


## Rosa de los vientos: el norte del mapa es la parte de arriba, que es también hacia donde
## avanza el detective al pulsar «arriba».
func _draw_compass(canvas_center: Vector2, radius_units: float) -> void:
	var scale := view_transform.get_scale().x
	var center := view_transform * canvas_center
	var radius := radius_units * scale
	draw_arc(center, radius * 0.78, 0.0, TAU, 48, Color(INK, 0.6), maxf(1.2, 1.6 * scale), true)
	draw_arc(center, radius * 0.7, 0.0, TAU, 48, Color(INK, 0.35), 1.0, true)
	for index in 8:
		var angle := -PI * 0.5 + PI * 0.25 * index
		var long_point := index % 2 == 0
		var reach := radius * (1.0 if long_point else 0.55)
		var width := radius * (0.16 if long_point else 0.11)
		var direction := Vector2(cos(angle), sin(angle))
		var side := Vector2(-direction.y, direction.x)
		var tip := center + direction * reach
		draw_colored_polygon(PackedVector2Array([center, tip, center + side * width]), Color(INK, 0.85))
		draw_colored_polygon(PackedVector2Array([center, center - side * width, tip]), MapSymbols.GOLD.darkened(0.1))
	draw_circle(center, radius * 0.08, MapSymbols.GOLD_LIGHT, true, -1.0, true)
	var font := CaseFileStyle.display_serif()
	var font_size := maxi(11, roundi(24.0 * scale))
	var letters := {"N": Vector2(0.0, -1.0), "E": Vector2(1.0, 0.0), "S": Vector2(0.0, 1.0), "O": Vector2(-1.0, 0.0)}
	for letter: String in letters:
		var spot: Vector2 = center + (letters[letter] as Vector2) * radius * 1.25
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, spot + Vector2(-text_size.x * 0.5, text_size.y * 0.3), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(INK, 0.9))


## Cartela con el nombre del pueblo y la escala real de los exteriores.
func _draw_cartouche(canvas_center: Vector2) -> void:
	var scale := view_transform.get_scale().x
	var panel := Rect2(canvas_center - Vector2(170.0, 62.0), Vector2(340.0, 124.0))
	var corners := PackedVector2Array([
		view_transform * panel.position, view_transform * Vector2(panel.end.x, panel.position.y),
		view_transform * panel.end, view_transform * Vector2(panel.position.x, panel.end.y),
	])
	draw_colored_polygon(corners, Color("e8d6ae", 0.75))
	_outline(corners, Color(INK, 0.6), maxf(1.2, 2.0 * scale))
	var inner := Rect2(view_transform * (panel.position + Vector2(7.0, 7.0)), (panel.size - Vector2(14.0, 14.0)) * scale)
	draw_rect(inner, Color(INK, 0.3), false, 1.0, true)
	var center := view_transform * canvas_center
	var title_size := maxi(12, roundi(30.0 * scale))
	var subtitle_size := maxi(10, roundi(17.0 * scale))
	_draw_centered(CaseFileStyle.display_serif(), "VILLA SOMBRÍA", center + Vector2(0.0, -26.0 * scale), title_size, Color(INK, 0.9))
	_draw_centered(CaseFileStyle.serif_italic(), "Plano del pueblo · octubre de 1948", center + Vector2(0.0, 2.0 * scale), subtitle_size, Color(INK, 0.75))
	var plaza := TownMap.get_region("plaza")
	if plaza == null:
		return
	# Diez metros de los exteriores, en la escala real de la calibración.
	var ten_meters := 10.0 * plaza.map_units_per_meter() * scale
	var left := center + Vector2(-ten_meters * 0.5, 30.0 * scale)
	for segment in 4:
		var x := left.x + ten_meters * segment / 4.0
		var block := Rect2(Vector2(x, left.y - 3.0 * scale), Vector2(ten_meters / 4.0, 6.0 * scale))
		draw_rect(block, Color(INK, 0.8) if segment % 2 == 0 else Color("f1e3c3"), true)
	draw_rect(Rect2(left - Vector2(0.0, 3.0 * scale), Vector2(ten_meters, 6.0 * scale)), Color(INK, 0.8), false, 1.0, true)
	_draw_centered(CaseFileStyle.serif(), "0", left + Vector2(0.0, 22.0 * scale), subtitle_size, Color(INK, 0.75))
	_draw_centered(CaseFileStyle.serif(), "10 m", left + Vector2(ten_meters, 22.0 * scale), subtitle_size, Color(INK, 0.75))


## Nombre de la calle a lo largo de su tramo central, girado como la calzada.
func _draw_street_name(points: PackedVector2Array, text: String) -> void:
	if points.size() < 3:
		return
	var middle := points.size() / 2
	var from := view_transform * points[middle - 1]
	var to := view_transform * points[middle + 1]
	var angle := (to - from).angle()
	if absf(angle) > PI * 0.5:
		angle += PI
	var scale := view_transform.get_scale().x
	var font := CaseFileStyle.serif_italic()
	var font_size := maxi(11, roundi(22.0 * scale))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_set_transform(view_transform * points[middle], angle, Vector2.ONE)
	draw_string(font, Vector2(-width * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(INK, 0.8))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Nombre de un edificio sin chincheta: está en el escenario pero no se puede visitar.
func _draw_world_label(region: MapRegion, world: Vector2, text: String, size_units: float) -> void:
	var scale := view_transform.get_scale().x
	var spot := view_transform * region.world_to_map(world)
	_draw_centered(CaseFileStyle.serif_italic(), text, spot, maxi(10, roundi(size_units * scale)), Color(INK, 0.8))


func _draw_centered(font: Font, text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, baseline_center - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- Orden de dibujo ---------------------------------------------------------------------

## Profundidad en pantalla: lo que queda más abajo está más cerca y se dibuja después.
func _depth(point: Vector2) -> float:
	return (_xf * point).y


func _draw_sorted(items: Array) -> void:
	items.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left["depth"] < right["depth"])
	for item: Dictionary in items:
		(item["draw"] as Callable).call()
