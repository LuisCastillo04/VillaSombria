class_name PropsKit
extends RefCounted
## Atrezo de exteriores reutilizable por todos los escenarios.


static func street_lamp(location: LocationBase, where: Vector3, shadows: bool = false) -> void:
	var batch := location.batch
	batch.cylinder(where, 0.18, 0.13, 0.3, Palette.IRON, 6)
	batch.cylinder(where + Vector3.UP * 0.3, 0.075, 0.055, 3.0, Palette.IRON, 6)
	batch.box(where + Vector3.UP * 3.3, Vector3(0.42, 0.05, 0.42), Palette.IRON)
	batch.cylinder(
		where + Vector3.UP * 3.34, 0.13, 0.2, 0.44, Palette.AMBER_SOFT, 6, MeshBatcher.Layer.GLOW
	)
	batch.cylinder(where + Vector3.UP * 3.78, 0.26, 0.04, 0.2, Palette.IRON, 6)
	location.collider(where + Vector3.UP * 1.5, Vector3(0.3, 3.0, 0.3))
	location.add_point_light(where + Vector3.UP * 3.3, Color("ffb765"), 5.0, 9.5, shadows)


static func bench(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var batch := location.batch
	for x: float in [-0.75, 0.75]:
		batch.box(Vector3(x, 0.22, 0.0), Vector3(0.08, 0.44, 0.46), Palette.IRON)
		batch.box(Vector3(x, 0.66, -0.2), Vector3(0.08, 0.5, 0.06), Palette.IRON)
	for z: float in [-0.14, 0.0, 0.14]:
		batch.box(Vector3(0.0, 0.46, z), Vector3(1.8, 0.05, 0.12), Palette.WOOD)
	for y: float in [0.68, 0.84]:
		batch.box(Vector3(0.0, y, -0.2), Vector3(1.8, 0.1, 0.04), Palette.WOOD)
	location.collider(Vector3(0.0, 0.45, 0.0), Vector3(1.9, 0.9, 0.5))
	location.batch.xform = previous


## Árbol estilizado. `autumn` añade copas ámbar para romper la paleta fría.
static func tree(location: LocationBase, where: Vector3, height: float = 3.6, autumn: bool = false) -> void:
	var batch := location.batch
	batch.cylinder(where, 0.2, 0.12, height * 0.55, Palette.WOOD_DARK, 6)
	var main := Color("6b4a24") if autumn else Palette.FOLIAGE
	var side := Color("7a3a24") if autumn else Palette.FOLIAGE_LIGHT
	var top := where + Vector3.UP * height * 0.72
	batch.sphere(top, height * 0.32, main, 6, 4, Vector3(1.0, 0.85, 1.0))
	batch.sphere(top + Vector3(0.5, -0.3, 0.2), height * 0.21, side, 6, 4)
	batch.sphere(top + Vector3(-0.42, -0.2, -0.35), height * 0.2, side, 6, 4)
	batch.sphere(top + Vector3(0.05, 0.55, 0.05), height * 0.16, main.lightened(0.05), 6, 4)
	location.collider(where + Vector3.UP * 1.0, Vector3(0.4, 2.0, 0.4))


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


static func crate(location: LocationBase, where: Vector3, size: float = 0.8, yaw_degrees: float = 0.0) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	location.solid(where + Vector3.UP * size * 0.5, Vector3.ONE * size, Palette.WOOD_LIGHT, yaw)
	location.batch.box(where + Vector3.UP * size * 0.5, Vector3(size + 0.03, 0.09, size + 0.03), Palette.WOOD, yaw)


static func barrel(location: LocationBase, where: Vector3) -> void:
	var batch := location.batch
	batch.cylinder(where, 0.3, 0.37, 0.45, Palette.WOOD, 8)
	batch.cylinder(where + Vector3.UP * 0.45, 0.37, 0.3, 0.45, Palette.WOOD, 8)
	batch.cylinder(where + Vector3.UP * 0.42, 0.38, 0.38, 0.06, Palette.IRON, 8)
	location.collider(where + Vector3.UP * 0.45, Vector3(0.65, 0.9, 0.65))


static func cafe_table(location: LocationBase, where: Vector3) -> void:
	var batch := location.batch
	batch.cylinder(where, 0.24, 0.04, 0.08, Palette.IRON, 6)
	batch.cylinder(where + Vector3.UP * 0.08, 0.035, 0.035, 0.64, Palette.IRON, 5)
	batch.cylinder(where + Vector3.UP * 0.72, 0.42, 0.42, 0.04, Palette.PAPER.darkened(0.35), 8)
	location.collider(where + Vector3.UP * 0.4, Vector3(0.6, 0.8, 0.6))
	for angle: float in [0.5, 3.6]:
		var seat := where + Vector3(cos(angle), 0.0, sin(angle)) * 0.72
		batch.cylinder(seat, 0.03, 0.03, 0.42, Palette.IRON, 5)
		batch.cylinder(seat + Vector3.UP * 0.42, 0.18, 0.18, 0.04, Palette.WOOD, 6)


## Sedán de los años cuarenta. `yaw_degrees` orienta el morro.
static func car(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	var local := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	location.batch.xform = previous * local
	var batch := location.batch
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
	location.collider(Vector3(0.0, 0.7, 0.0), Vector3(1.9, 1.4, 4.2))
	location.batch.xform = previous


## Puesto de prensa con su toldo y su pila de periódicos.
static func newsstand(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var batch := location.batch
	location.solid(Vector3(0.0, 1.05, 0.0), Vector3(2.6, 2.1, 1.5), Palette.WOOD)
	batch.box(Vector3(0.0, 2.2, 0.15), Vector3(3.0, 0.14, 2.0), Palette.WINE.darkened(0.25))
	batch.box(Vector3(0.0, 1.45, 0.77), Vector3(2.2, 0.8, 0.04), Palette.PAPER.darkened(0.2))
	for x: float in [-0.8, -0.2, 0.4, 0.95]:
		batch.box(Vector3(x, 1.45, 0.8), Vector3(0.44, 0.62, 0.03), Palette.PAPER.lightened(0.1))
		batch.box(Vector3(x, 1.62, 0.82), Vector3(0.36, 0.06, 0.02), Palette.INK)
		batch.box(Vector3(x, 1.4, 0.82), Vector3(0.36, 0.24, 0.02), Palette.STEEL)
	batch.box(Vector3(0.0, 0.75, 0.86), Vector3(2.4, 0.12, 0.34), Palette.WOOD_LIGHT)
	location.add_sign("PRENSA", Vector3(0.0, 2.42, 1.16), 0.3, Palette.PAPER)
	location.batch.xform = previous


static func mailbox(location: LocationBase, where: Vector3) -> void:
	var batch := location.batch
	batch.cylinder(where, 0.26, 0.26, 1.1, Palette.WINE.darkened(0.2), 8)
	batch.cylinder(where + Vector3.UP * 1.1, 0.3, 0.1, 0.14, Palette.WINE.darkened(0.3), 8)
	batch.box(where + Vector3(0.0, 0.85, 0.26), Vector3(0.28, 0.05, 0.04), Palette.IRON)
	location.collider(where + Vector3.UP * 0.6, Vector3(0.5, 1.2, 0.5))


## Poste con flechas de dirección.
static func signpost(location: LocationBase, where: Vector3, labels: Array[String]) -> void:
	var batch := location.batch
	batch.cylinder(where, 0.07, 0.06, 2.7, Palette.WOOD_DARK, 6)
	location.collider(where + Vector3.UP * 1.2, Vector3(0.2, 2.4, 0.2))
	for index in labels.size():
		var y := 2.4 - 0.44 * float(index)
		batch.box(where + Vector3(0.0, y, 0.06), Vector3(1.9, 0.36, 0.05), Palette.PAPER.darkened(0.35))
		location.add_sign(labels[index], where + Vector3(0.0, y, 0.1), 0.22, Palette.INK)
