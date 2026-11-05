class_name BuildingKit
extends RefCounted
## Piezas de arquitectura. Todas trabajan en un sistema local donde X recorre la
## fachada, Y es la altura y +Z sale hacia la calle; `begin` fija ese sistema.


static func begin(location: LocationBase, origin: Vector3, yaw_degrees: float = 0.0) -> void:
	location.batch.xform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), origin)


static func end(location: LocationBase) -> void:
	location.batch.xform = Transform3D.IDENTITY


## Cuerpo del edificio con zócalo, cornisa y tejado a dos aguas.
static func body(
	location: LocationBase,
	width: float,
	height: float,
	depth: float,
	wall: Color,
	roof: Color = Palette.ROOF,
	roof_height: float = 2.2
) -> void:
	var batch := location.batch
	location.solid(Vector3(0.0, height * 0.5, -depth * 0.5), Vector3(width, height, depth), wall)
	batch.box(Vector3(0.0, 0.35, 0.05), Vector3(width + 0.1, 0.7, 0.12), Palette.STONE_DARK)
	batch.box(Vector3(0.0, height, 0.08), Vector3(width + 0.3, 0.26, 0.2), Palette.STONE_LIGHT.darkened(0.2))
	batch.gable(
		Vector3(0.0, height + 0.1, -depth * 0.5),
		Vector3(depth + 0.7, roof_height, width + 0.5),
		roof,
		PI * 0.5,
		wall.darkened(0.15)
	)


static func window(
	location: LocationBase, x: float, y: float, width: float, height: float, lit: bool, shutters: bool = false
) -> void:
	var batch := location.batch
	batch.box(Vector3(x, y, 0.03), Vector3(width + 0.2, height + 0.2, 0.08), Palette.WOOD_DARK)
	if lit:
		batch.box(Vector3(x, y, 0.07), Vector3(width, height, 0.03), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
	else:
		batch.box(Vector3(x, y, 0.07), Vector3(width, height, 0.03), Color("1b2433"))
	batch.box(Vector3(x, y, 0.1), Vector3(0.05, height, 0.02), Palette.WOOD_DARK)
	batch.box(Vector3(x, y, 0.1), Vector3(width, 0.05, 0.02), Palette.WOOD_DARK)
	batch.box(Vector3(x, y - height * 0.5 - 0.12, 0.1), Vector3(width + 0.34, 0.08, 0.2), Palette.STONE_LIGHT.darkened(0.25))
	if shutters:
		batch.box(Vector3(x - width * 0.75, y, 0.05), Vector3(width * 0.45, height + 0.1, 0.05), Palette.SLATE)
		batch.box(Vector3(x + width * 0.75, y, 0.05), Vector3(width * 0.45, height + 0.1, 0.05), Palette.SLATE)


## Filas de ventanas repartidas por la fachada. `lit_pattern` decide cuáles se encienden.
static func window_grid(
	location: LocationBase,
	width: float,
	floors: Array[float],
	columns: int,
	size: Vector2,
	lit_pattern: Array[bool],
	shutters: bool = false
) -> void:
	var index := 0
	for y in floors:
		for column in columns:
			var x := -width * 0.5 + width * (float(column) + 0.5) / float(columns)
			window(location, x, y, size.x, size.y, lit_pattern[index % lit_pattern.size()], shutters)
			index += 1


static func door(location: LocationBase, x: float, width: float, height: float, color: Color) -> void:
	var batch := location.batch
	batch.box(Vector3(x, height * 0.5 + 0.1, 0.05), Vector3(width + 0.36, height + 0.3, 0.12), Palette.STONE_LIGHT.darkened(0.15))
	batch.box(Vector3(x, height * 0.5, 0.1), Vector3(width, height, 0.08), color)
	batch.box(Vector3(x, height * 0.72, 0.15), Vector3(width * 0.6, height * 0.3, 0.02), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
	batch.box(Vector3(x + width * 0.35, height * 0.45, 0.17), Vector3(0.07, 0.07, 0.06), Palette.AMBER)
	batch.box(Vector3(x, 0.06, 0.4), Vector3(width + 0.8, 0.12, 0.7), Palette.STONE_LIGHT.darkened(0.1))


## Toldo inclinado de rayas.
static func awning(location: LocationBase, x: float, y: float, width: float, depth: float) -> void:
	var batch := location.batch
	var stripes := int(width / 0.5)
	for index in stripes:
		var stripe_x := x - width * 0.5 + (float(index) + 0.5) * width / float(stripes)
		var color := Palette.WINE if index % 2 == 0 else Palette.PAPER.darkened(0.25)
		var points := PackedVector3Array([
			Vector3(stripe_x - 0.25, y, 0.1),
			Vector3(stripe_x + 0.25, y, 0.1),
			Vector3(stripe_x + 0.25, y - 0.55, depth),
			Vector3(stripe_x - 0.25, y - 0.55, depth),
		])
		batch.face(points, color, Vector3(0.0, 1.0, 0.5))
		batch.face(points, color.darkened(0.3), Vector3(0.0, -1.0, -0.5))
		batch.box(Vector3(stripe_x, y - 0.68, depth), Vector3(0.5, 0.26, 0.03), color)


static func chimney(location: LocationBase, where: Vector3) -> void:
	var batch := location.batch
	batch.box(where + Vector3.UP * 0.6, Vector3(0.7, 1.2, 0.7), Palette.BRICK)
	batch.box(where + Vector3.UP * 1.25, Vector3(0.85, 0.12, 0.85), Palette.STONE_DARK)


## Columna clásica con basa y capitel.
static func column(location: LocationBase, base: Vector3, height: float) -> void:
	var batch := location.batch
	batch.box(base + Vector3.UP * 0.1, Vector3(0.7, 0.2, 0.7), Palette.STONE_LIGHT)
	batch.cylinder(base + Vector3.UP * 0.2, 0.25, 0.21, height - 0.4, Palette.STONE_LIGHT, 8)
	batch.box(base + Vector3.UP * (height - 0.1), Vector3(0.66, 0.2, 0.66), Palette.STONE_LIGHT)
	location.collider(base + Vector3.UP * height * 0.5, Vector3(0.5, height, 0.5))
