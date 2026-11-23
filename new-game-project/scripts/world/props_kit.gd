class_name PropsKit
extends RefCounted
## Atrezo de exteriores reutilizable por todos los escenarios. Las piezas migradas a Blender
## dibujan su parte visual con `ModelCatalog.draw` y conservan aquí su colisión y su luz.

## Ángulos (radianes) de los dos taburetes alrededor de la mesa de terraza.
const CAFE_SEAT_ANGLES: Array[float] = [0.5, 3.6]

## Jardinera octogonal (metros desde el centro de su base). Un lado mira a la cámara.
const PLANTER_APOTHEM := 1.2
const PLANTER_WALL := 0.2
const PLANTER_PLINTH := 0.08
const PLANTER_TOP := 0.36
const PLANTER_CAP := 0.06
const PLANTER_SOIL := 0.3
const PLANTER_COLLISION_HEIGHT := 0.8
const PLANTER_SOIL_COLOR := Color("33261c")
const PLANTER_BUSH_COLOR := Color("3d5a3e")
const PLANTER_FLOWER_COLOR := Color("e6dfcc")
## Arbustos de la jardinera: ángulo (grados), distancia al centro y radio.
const PLANTER_BUSHES: Array[Vector3] = [
	Vector3(0.0, 0.6, 0.3), Vector3(72.0, 0.62, 0.27), Vector3(144.0, 0.6, 0.3),
	Vector3(216.0, 0.62, 0.28), Vector3(288.0, 0.6, 0.29),
]
## Matas de flores blancas, entre los arbustos: ángulo (grados) y distancia al centro.
const PLANTER_FLOWERS: Array[Vector2] = [
	Vector2(36.0, 0.74), Vector2(108.0, 0.72), Vector2(180.0, 0.74), Vector2(252.0, 0.72), Vector2(324.0, 0.74),
]


static func street_lamp(location: LocationBase, where: Vector3, shadows: bool = false) -> void:
	var procedural := func(_tint: Color) -> void: _street_lamp_mesh(location.batch, where)
	ModelCatalog.draw(location, "farola", Transform3D(Basis.IDENTITY, where), procedural)
	location.collider(where + Vector3.UP * 1.5, Vector3(0.3, 3.0, 0.3))
	location.add_point_light(where + Vector3.UP * 3.3, Color("ffb765"), 5.0, 9.5, shadows)


static func bench(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(_tint: Color) -> void: _bench_mesh(location.batch)
	ModelCatalog.draw(location, "banco", Transform3D.IDENTITY, procedural)
	location.collider(Vector3(0.0, 0.45, 0.0), Vector3(1.9, 0.9, 0.5))
	location.batch.xform = previous


## Árbol estilizado. `autumn` añade copas ámbar para romper la paleta fría. La altura y la estación
## son la variante del modelo.
static func tree(location: LocationBase, where: Vector3, height: float = 3.6, autumn: bool = false) -> void:
	var procedural := func(_tint: Color) -> void: _tree_mesh(location.batch, where, height, autumn)
	var variant := ModelCatalog.size_key(height) + ("_otono" if autumn else "")
	ModelCatalog.draw(location, "arbol", Transform3D(Basis.IDENTITY, where), procedural, variant)
	location.collider(where + Vector3.UP * 1.0, Vector3(0.4, 2.0, 0.4))


static func _tree_mesh(batch: MeshBatcher, where: Vector3, height: float, autumn: bool) -> void:
	batch.cylinder(where, 0.2, 0.12, height * 0.55, Palette.WOOD_DARK, 6)
	var main := Color("6b4a24") if autumn else Palette.FOLIAGE
	var side := Color("7a3a24") if autumn else Palette.FOLIAGE_LIGHT
	var top := where + Vector3.UP * height * 0.72
	batch.sphere(top, height * 0.32, main, 6, 4, Vector3(1.0, 0.85, 1.0))
	batch.sphere(top + Vector3(0.5, -0.3, 0.2), height * 0.21, side, 6, 4)
	batch.sphere(top + Vector3(-0.42, -0.2, -0.35), height * 0.2, side, 6, 4)
	batch.sphere(top + Vector3(0.05, 0.55, 0.05), height * 0.16, main.lightened(0.05), 6, 4)


## Jardinera octogonal de piedra con arbustos y flores, para plantar un árbol en la plaza.
## Devuelve el punto de la tierra donde va el tronco (hundido 2 cm: ni flota ni comparte plano con
## la tierra). La colisión son ocho cuñas, una por lado, que cubren el octógono entero: el detective
## la rodea sin atravesar el bordillo y la navegación no deja huecos dentro.
static func planter(location: LocationBase, where: Vector3) -> Vector3:
	var procedural := func(_tint: Color) -> void: _planter_mesh(location.batch, where)
	ModelCatalog.draw(location, "jardinera", Transform3D(Basis.IDENTITY, where), procedural)
	var side := 2.0 * PLANTER_APOTHEM * tan(PI / 8.0)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var middle := where + Vector3(cos(angle), 0.0, sin(angle)) * PLANTER_APOTHEM * 0.5
		var size := Vector3(side, PLANTER_COLLISION_HEIGHT, PLANTER_APOTHEM)
		location.collider(middle + Vector3.UP * PLANTER_COLLISION_HEIGHT * 0.5, size, PI * 0.5 - angle)
	return where + Vector3.UP * (PLANTER_SOIL - 0.02)


## Zócalo oscuro, bordillo de piedra con albardilla clara, tierra, arbustos y matas de flores.
## Sólo lleva las caras que pueden verse: ni bases ni la parte de arriba del muro, que tapa la albardilla.
static func _planter_mesh(batch: MeshBatcher, where: Vector3) -> void:
	var inner := PLANTER_APOTHEM - PLANTER_WALL
	var cap_top := PLANTER_TOP + PLANTER_CAP
	_octagon_sides(batch, where, PLANTER_APOTHEM + 0.05, 0.0, PLANTER_PLINTH, Palette.STONE_DARK)
	_octagon_ring(batch, where, PLANTER_APOTHEM + 0.05, PLANTER_APOTHEM, PLANTER_PLINTH, Palette.STONE_DARK)
	_octagon_sides(batch, where, PLANTER_APOTHEM, PLANTER_PLINTH, PLANTER_TOP, Palette.STONE)
	_octagon_sides(batch, where, PLANTER_APOTHEM + 0.04, PLANTER_TOP, cap_top, Palette.STONE_LIGHT)
	_octagon_ring(batch, where, PLANTER_APOTHEM + 0.04, inner - 0.04, cap_top, Palette.STONE_LIGHT)
	_octagon_sides(batch, where, inner - 0.04, PLANTER_TOP, cap_top, Palette.STONE_LIGHT, true)
	_octagon_sides(batch, where, inner, PLANTER_SOIL, PLANTER_TOP, Palette.STONE_DARK, true)
	batch.face(_octagon(where, inner, PLANTER_SOIL), PLANTER_SOIL_COLOR, Vector3.UP)
	var soil := where + Vector3.UP * PLANTER_SOIL
	for index in PLANTER_BUSHES.size():
		var bush := PLANTER_BUSHES[index]
		var color := PLANTER_BUSH_COLOR if index % 2 == 0 else Palette.FOLIAGE_LIGHT
		var center := soil + _planter_offset(bush.x, bush.y) + Vector3.UP * 0.12
		batch.sphere(center, bush.z, color, 6, 4, Vector3(1.0, 0.8, 1.0))
	for flower in PLANTER_FLOWERS:
		var mound := soil + _planter_offset(flower.x, flower.y)
		batch.sphere(mound + Vector3.UP * 0.04, 0.16, Palette.FOLIAGE_LIGHT, 6, 3, Vector3(1.0, 0.65, 1.0))
		for petal in 3:
			var spot := _planter_offset(flower.x + 120.0 * float(petal), 0.07)
			batch.sphere(mound + spot + Vector3.UP * (0.15 + 0.02 * float(petal)), 0.06, PLANTER_FLOWER_COLOR, 4, 2)


static func _planter_offset(angle_degrees: float, distance: float) -> Vector3:
	var angle := deg_to_rad(angle_degrees)
	return Vector3(cos(angle), 0.0, sin(angle)) * distance


## Vértices de un octógono horizontal con los lados a `apothem` metros del centro y uno de ellos
## mirando a cada eje y a cada diagonal (los vértices quedan a 22,5° de ellos).
static func _octagon(center: Vector3, apothem: float, height: float) -> PackedVector3Array:
	var radius := apothem / cos(PI / 8.0)
	var points := PackedVector3Array()
	for index in 8:
		var angle := PI / 8.0 + TAU * float(index) / 8.0
		points.append(center + Vector3(cos(angle) * radius, height, sin(angle) * radius))
	return points


## Caras laterales de un prisma octogonal entre dos alturas, hacia fuera o hacia dentro.
static func _octagon_sides(
	batch: MeshBatcher, center: Vector3, apothem: float, bottom: float, top: float, color: Color, inward: bool = false
) -> void:
	var low := _octagon(center, apothem, bottom)
	var high := _octagon(center, apothem, top)
	for index in 8:
		var next := (index + 1) % 8
		var outward := Vector3(cos(TAU * float(index + 1) / 8.0), 0.0, sin(TAU * float(index + 1) / 8.0))
		var points := PackedVector3Array([low[index], low[next], high[next], high[index]])
		batch.face(points, color, -outward if inward else outward)


## Corona horizontal entre dos octógonos concéntricos, mirando hacia arriba.
static func _octagon_ring(batch: MeshBatcher, center: Vector3, outer: float, inner: float, height: float, color: Color) -> void:
	var outside := _octagon(center, outer, height)
	var inside := _octagon(center, inner, height)
	for index in 8:
		var next := (index + 1) % 8
		batch.face(PackedVector3Array([outside[index], outside[next], inside[next], inside[index]]), color, Vector3.UP)


static func hedge(location: LocationBase, center: Vector3, size: Vector3) -> void:
	location.solid(center, size, Palette.FOLIAGE)
	var count := int(maxf(size.x, size.z) / 1.1)
	for index in count:
		var ratio := (float(index) + 0.5) / float(count) - 0.5
		var offset := Vector3(size.x * ratio, size.y * 0.5, size.z * ratio)
		if size.x > size.z:
			offset.z = 0.0
		else:
			offset.x = 0.0
		location.batch.sphere(center + offset, 0.5, Palette.FOLIAGE_LIGHT, 5, 3, Vector3(1.1, 0.55, 1.1))


## Murete de piedra con remate, usado en los bordes cercanos a la cámara.
static func low_wall(location: LocationBase, center: Vector3, size: Vector3) -> void:
	location.solid(center, size, Palette.STONE_DARK)
	location.batch.box(
		center + Vector3.UP * (size.y * 0.5 + 0.05),
		Vector3(size.x + 0.14, 0.1, size.z + 0.14),
		Palette.STONE
	)


## Caja de madera. El lado es la variante del modelo.
static func crate(location: LocationBase, where: Vector3, size: float = 0.8, yaw_degrees: float = 0.0) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	var procedural := func(_tint: Color) -> void: _crate_mesh(location.batch, where, size, yaw)
	ModelCatalog.draw(location, "caja", Transform3D(Basis(Vector3.UP, yaw), where), procedural, ModelCatalog.size_key(size))
	location.collider(where + Vector3.UP * size * 0.5, Vector3.ONE * size, yaw)


static func _crate_mesh(batch: MeshBatcher, where: Vector3, size: float, yaw: float) -> void:
	batch.box(where + Vector3.UP * size * 0.5, Vector3.ONE * size, Palette.WOOD_LIGHT, yaw)
	batch.box(where + Vector3.UP * size * 0.5, Vector3(size + 0.03, 0.09, size + 0.03), Palette.WOOD, yaw)


static func barrel(location: LocationBase, where: Vector3) -> void:
	var procedural := func(_tint: Color) -> void: _barrel_mesh(location.batch, where)
	ModelCatalog.draw(location, "barril", Transform3D(Basis.IDENTITY, where), procedural)
	location.collider(where + Vector3.UP * 0.45, Vector3(0.65, 0.9, 0.65))


static func _barrel_mesh(batch: MeshBatcher, where: Vector3) -> void:
	batch.cylinder(where, 0.3, 0.37, 0.45, Palette.WOOD, 8)
	batch.cylinder(where + Vector3.UP * 0.45, 0.37, 0.3, 0.45, Palette.WOOD, 8)
	batch.cylinder(where + Vector3.UP * 0.42, 0.38, 0.38, 0.06, Palette.IRON, 8)


## Velador de café con sus dos taburetes.
static func cafe_table(location: LocationBase, where: Vector3) -> void:
	var procedural := func(_tint: Color) -> void: _cafe_table_mesh(location.batch, where)
	ModelCatalog.draw(location, "mesa_cafe", Transform3D(Basis.IDENTITY, where), procedural)
	location.collider(where + Vector3.UP * 0.4, Vector3(0.6, 0.8, 0.6))
	for angle: float in CAFE_SEAT_ANGLES:
		var seat := where + Vector3(cos(angle), 0.0, sin(angle)) * 0.72
		location.collider(seat + Vector3.UP * 0.23, Vector3(0.34, 0.46, 0.34))


static func _cafe_table_mesh(batch: MeshBatcher, where: Vector3) -> void:
	batch.cylinder(where, 0.24, 0.04, 0.08, Palette.IRON, 6)
	batch.cylinder(where + Vector3.UP * 0.08, 0.035, 0.035, 0.64, Palette.IRON, 5)
	batch.cylinder(where + Vector3.UP * 0.72, 0.42, 0.42, 0.04, Palette.PAPER.darkened(0.35), 8)
	for angle: float in CAFE_SEAT_ANGLES:
		var seat := where + Vector3(cos(angle), 0.0, sin(angle)) * 0.72
		batch.cylinder(seat, 0.03, 0.03, 0.42, Palette.IRON, 5)
		batch.cylinder(seat + Vector3.UP * 0.42, 0.18, 0.18, 0.04, Palette.WOOD, 6)


## Sedán de los años cuarenta. `yaw_degrees` orienta el morro.
static func car(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	var local := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	location.batch.xform = previous * local
	var procedural := func(_tint: Color) -> void: _car_mesh(location.batch)
	ModelCatalog.draw(location, "coche", Transform3D.IDENTITY, procedural)
	location.collider(Vector3(0.0, 0.7, 0.0), Vector3(1.9, 1.4, 4.2))
	location.batch.xform = previous


static func _car_mesh(batch: MeshBatcher) -> void:
	var paint := Color("15181f")
	batch.box(Vector3(0.0, 0.55, 0.0), Vector3(1.7, 0.5, 4.1), paint)
	batch.box(Vector3(0.0, 0.76, -1.2), Vector3(1.3, 0.34, 1.6), paint.lightened(0.04))
	batch.box(Vector3(0.0, 1.08, 0.3), Vector3(1.5, 0.58, 1.9), paint)
	batch.box(Vector3(0.0, 1.1, 0.3), Vector3(1.54, 0.34, 1.5), Color("243045"))
	batch.box(Vector3(0.0, 1.1, -0.65), Vector3(1.3, 0.36, 0.04), Color("2c3a52"))
	batch.box(Vector3(0.0, 0.42, -2.08), Vector3(1.8, 0.14, 0.1), Color("7c828c"))
	batch.box(Vector3(0.0, 0.42, 2.08), Vector3(1.8, 0.14, 0.1), Color("7c828c"))
	for x: float in [-0.55, 0.55]:
		batch.sphere(Vector3(x, 0.72, -2.02), 0.13, Palette.AMBER_SOFT, 6, 3, Vector3.ONE, MeshBatcher.Layer.GLOW)
		batch.box(Vector3(x, 0.66, 2.06), Vector3(0.16, 0.1, 0.03), Palette.WINE, 0.0, MeshBatcher.Layer.GLOW)
	for x: float in [-0.86, 0.86]:
		for z: float in [-1.3, 1.3]:
			batch.box(Vector3(x, 0.31, z), Vector3(0.24, 0.62, 0.62), Color("0c0d10"))
			batch.box(Vector3(x * 1.02, 0.31, z), Vector3(0.22, 0.26, 0.26), Color("565b64"))


## Puesto de prensa con su toldo y su pila de periódicos.
static func newsstand(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(_tint: Color) -> void: _newsstand_mesh(location.batch)
	ModelCatalog.draw(location, "quiosco", Transform3D.IDENTITY, procedural)
	location.collider(Vector3(0.0, 1.05, 0.0), Vector3(2.6, 2.1, 1.5))
	location.add_sign("PRENSA", Vector3(0.0, 2.42, 1.16), 0.3, Palette.PAPER)
	location.batch.xform = previous


static func _newsstand_mesh(batch: MeshBatcher) -> void:
	batch.box(Vector3(0.0, 1.05, 0.0), Vector3(2.6, 2.1, 1.5), Palette.WOOD)
	batch.box(Vector3(0.0, 2.2, 0.15), Vector3(3.0, 0.14, 2.0), Palette.WINE.darkened(0.25))
	batch.box(Vector3(0.0, 1.45, 0.77), Vector3(2.2, 0.8, 0.04), Palette.PAPER.darkened(0.2))
	for x: float in [-0.8, -0.2, 0.4, 0.95]:
		batch.box(Vector3(x, 1.45, 0.8), Vector3(0.44, 0.62, 0.03), Palette.PAPER.lightened(0.1))
		batch.box(Vector3(x, 1.62, 0.82), Vector3(0.36, 0.06, 0.02), Palette.INK)
		batch.box(Vector3(x, 1.4, 0.82), Vector3(0.36, 0.24, 0.02), Palette.STEEL)
	batch.box(Vector3(0.0, 0.75, 0.86), Vector3(2.4, 0.12, 0.34), Palette.WOOD_LIGHT)


## Buzón de correos. Se dibuja con su modelo de Blender (`buzon`) y, si falta, con el código de
## `_mailbox_mesh`; la colisión es la misma en los dos casos.
static func mailbox(location: LocationBase, where: Vector3) -> void:
	var procedural := func(_tint: Color) -> void: _mailbox_mesh(location.batch, where)
	ModelCatalog.draw(location, "buzon", Transform3D(Basis.IDENTITY, where), procedural)
	location.collider(where + Vector3.UP * 0.6, Vector3(0.5, 1.2, 0.5))


static func _mailbox_mesh(batch: MeshBatcher, where: Vector3) -> void:
	batch.cylinder(where, 0.26, 0.26, 1.1, Palette.WINE.darkened(0.2), 8)
	batch.cylinder(where + Vector3.UP * 1.1, 0.3, 0.1, 0.14, Palette.WINE.darkened(0.3), 8)
	batch.box(where + Vector3(0.0, 0.85, 0.26), Vector3(0.28, 0.05, 0.04), Palette.IRON)


## Poste con flechas de dirección. El número de tableros es la variante del modelo; los rótulos
## siguen siendo texto (`Label3D`).
static func signpost(location: LocationBase, where: Vector3, labels: Array[String]) -> void:
	var procedural := func(_tint: Color) -> void: _signpost_mesh(location.batch, where, labels.size())
	ModelCatalog.draw(location, "poste_indicador", Transform3D(Basis.IDENTITY, where), procedural, str(labels.size()))
	location.collider(where + Vector3.UP * 1.2, Vector3(0.2, 2.4, 0.2))
	for index in labels.size():
		var y := 2.4 - 0.44 * float(index)
		location.add_sign(labels[index], where + Vector3(0.0, y, 0.1), 0.22, Palette.INK)


static func _signpost_mesh(batch: MeshBatcher, where: Vector3, boards: int) -> void:
	batch.cylinder(where, 0.07, 0.06, 2.7, Palette.WOOD_DARK, 6)
	for index in boards:
		var y := 2.4 - 0.44 * float(index)
		batch.box(where + Vector3(0.0, y, 0.06), Vector3(1.9, 0.36, 0.05), Palette.PAPER.darkened(0.35))


static func _street_lamp_mesh(batch: MeshBatcher, where: Vector3) -> void:
	batch.cylinder(where, 0.18, 0.13, 0.3, Palette.IRON, 6)
	batch.cylinder(where + Vector3.UP * 0.3, 0.075, 0.055, 3.0, Palette.IRON, 6)
	batch.box(where + Vector3.UP * 3.3, Vector3(0.42, 0.05, 0.42), Palette.IRON)
	batch.cylinder(
		where + Vector3.UP * 3.34, 0.13, 0.2, 0.44, Palette.AMBER_SOFT, 6, MeshBatcher.Layer.GLOW
	)
	batch.cylinder(where + Vector3.UP * 3.78, 0.26, 0.04, 0.2, Palette.IRON, 6)


static func _bench_mesh(batch: MeshBatcher) -> void:
	for x: float in [-0.75, 0.75]:
		batch.box(Vector3(x, 0.22, 0.0), Vector3(0.08, 0.44, 0.46), Palette.IRON)
		batch.box(Vector3(x, 0.66, -0.2), Vector3(0.08, 0.5, 0.06), Palette.IRON)
	for z: float in [-0.14, 0.0, 0.14]:
		batch.box(Vector3(0.0, 0.46, z), Vector3(1.8, 0.05, 0.12), Palette.WOOD)
	for y: float in [0.68, 0.84]:
		batch.box(Vector3(0.0, y, -0.2), Vector3(1.8, 0.1, 0.04), Palette.WOOD)
