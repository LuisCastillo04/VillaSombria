class_name InteriorKit
extends RefCounted
## Piezas de interiores. Los escenarios interiores usan un corte de casa de muñecas: las
## paredes del fondo son altas y las que quedan entre la cámara y el jugador, bajas.
## El mobiliario dibuja su parte visual con `ModelCatalog.draw` (modelo de Blender o, si no lo
## hay, el código `_<pieza>_mesh`); colisiones y luces se quedan aquí. Suelos, paredes, alfombras
## y barreras siguen siendo procedurales (medidas por escenario, sonido de pasos, bordes).

const BACK_WALL := 3.7
const PARTITION := 1.05
const COLLISION_HEIGHT := 3.0
## Estantería: separación entre baldas, grosor de balda y de lateral, y hueco mínimo sobre los libros.
const BOOKSHELF_SPACING := 0.5
const BOOKSHELF_BOARD := 0.05
const BOOKSHELF_SIDE := 0.08
const BOOKSHELF_HEADROOM := 0.03


## Suelo de tablones. `along_x` orienta las tablas.
static func plank_floor(location: LocationBase, from: Vector2, to: Vector2, color: Color, along_x: bool = true) -> void:
	location.register_surface(from, to, "madera")
	var batch := location.batch
	var width := 0.55
	var span := (to.y - from.y) if along_x else (to.x - from.x)
	var count := int(ceil(span / width))
	for index in count:
		var start := index * width
		var finish := minf(start + width, span)
		var shade := color.darkened(0.12 * float((index * 7) % 3) / 2.0)
		var points: PackedVector3Array
		if along_x:
			points = PackedVector3Array([
				Vector3(from.x, 0.0, from.y + start),
				Vector3(to.x, 0.0, from.y + start),
				Vector3(to.x, 0.0, from.y + finish),
				Vector3(from.x, 0.0, from.y + finish),
			])
		else:
			points = PackedVector3Array([
				Vector3(from.x + start, 0.0, from.y),
				Vector3(from.x + finish, 0.0, from.y),
				Vector3(from.x + finish, 0.0, to.y),
				Vector3(from.x + start, 0.0, to.y),
			])
		batch.face(points, shade, Vector3.UP)


## Baldosas ajedrezadas.
static func tile_floor(location: LocationBase, from: Vector2, to: Vector2, light: Color, dark: Color, tile: float = 1.0) -> void:
	location.register_surface(from, to, "baldosa")
	var columns := int(ceil((to.x - from.x) / tile))
	var rows := int(ceil((to.y - from.y) / tile))
	for row in rows:
		for column in columns:
			var x0 := from.x + float(column) * tile
			var z0 := from.y + float(row) * tile
			var x1 := minf(x0 + tile, to.x)
			var z1 := minf(z0 + tile, to.y)
			location.batch.face(
				PackedVector3Array([Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z0), Vector3(x1, 0.0, z1), Vector3(x0, 0.0, z1)]),
				light if (row + column) % 2 == 0 else dark,
				Vector3.UP
			)


## Pared recta alineada con los ejes, con huecos de puerta. Cada hueco es un Vector2
## con el centro y la anchura medidos sobre el eje de la pared.
static func wall(
	location: LocationBase,
	from: Vector2,
	to: Vector2,
	height: float,
	color: Color,
	gaps: Array[Vector2] = [],
	trim: Color = Palette.WOOD_DARK
) -> void:
	var along_x := is_equal_approx(from.y, to.y)
	var start := from.x if along_x else from.y
	var finish := to.x if along_x else to.y
	var cursor := start
	for gap in gaps:
		_wall_segment(location, from, along_x, cursor, gap.x - gap.y * 0.5, height, color, trim)
		cursor = gap.x + gap.y * 0.5
		location.add_doorway(Vector3(gap.x, 0.0, from.y) if along_x else Vector3(from.x, 0.0, gap.x))
	_wall_segment(location, from, along_x, cursor, finish, height, color, trim)


## Cierra por fuera el hueco de la puerta que da a la calle. Detrás de esa pared no hay
## escenario: el detective puede llegar al umbral para usar la salida (con E), pero no cruzarlo.
## `outward` es el sentido (+1 o -1) hacia fuera del edificio en el eje perpendicular a la pared.
static func seal_street_door(location: LocationBase, from: Vector2, to: Vector2, gap: Vector2, outward: float = 1.0) -> void:
	var along_x := is_equal_approx(from.y, to.y)
	# La barrera queda justo detrás del grosor de la pared y la solapa por los dos lados.
	var offset := outward * 0.35
	var half := gap.y * 0.5 + 0.3
	if along_x:
		location.block_passage(Vector2(gap.x - half, from.y + offset), Vector2(gap.x + half, from.y + offset))
	else:
		location.block_passage(Vector2(from.x + offset, gap.x - half), Vector2(from.x + offset, gap.x + half))


static func _wall_segment(
	location: LocationBase,
	origin: Vector2,
	along_x: bool,
	start: float,
	finish: float,
	height: float,
	color: Color,
	trim: Color
) -> void:
	var length := finish - start
	if length <= 0.01:
		return
	var middle := (start + finish) * 0.5
	var thickness := 0.24
	var center := Vector3(middle, 0.0, origin.y) if along_x else Vector3(origin.x, 0.0, middle)
	var size := Vector3(length, height, thickness) if along_x else Vector3(thickness, height, length)
	location.batch.box(center + Vector3.UP * height * 0.5, size, color)
	var skirt_height := minf(0.9, height)
	var skirt := Vector3(length, skirt_height, thickness + 0.04) if along_x else Vector3(thickness + 0.04, skirt_height, length)
	location.batch.box(center + Vector3.UP * skirt_height * 0.5, skirt, color.darkened(0.3))
	var cap := Vector3(length, 0.08, thickness + 0.1) if along_x else Vector3(thickness + 0.1, 0.08, length)
	location.batch.box(center + Vector3.UP * (height + 0.02), cap, trim)
	var collision := Vector3(length, COLLISION_HEIGHT, thickness) if along_x else Vector3(thickness, COLLISION_HEIGHT, length)
	location.collider(center + Vector3.UP * COLLISION_HEIGHT * 0.5, collision)


static func rug(location: LocationBase, center: Vector3, size: Vector2, color: Color) -> void:
	location.register_surface(Vector2(center.x, center.z) - size * 0.5, Vector2(center.x, center.z) + size * 0.5, "alfombra")
	var batch := location.batch
	batch.box(center + Vector3.UP * 0.01, Vector3(size.x, 0.02, size.y), color)
	batch.box(center + Vector3.UP * 0.022, Vector3(size.x - 0.5, 0.02, size.y - 0.5), color.lightened(0.14))
	batch.box(center + Vector3.UP * 0.034, Vector3(size.x - 0.8, 0.02, size.y - 0.8), color)


## Mesa de cuatro patas. Las medidas son la variante del modelo y `color`, su tinte.
static func table(location: LocationBase, center: Vector3, size: Vector3, color: Color = Palette.WOOD) -> void:
	var procedural := func(tint: Color) -> void: _table_mesh(location.batch, center, size, tint)
	ModelCatalog.draw(location, "mesa", Transform3D(Basis.IDENTITY, center), procedural, ModelCatalog.size_key(size), color)
	location.collider(center + Vector3.UP * size.y * 0.5, size)


static func _table_mesh(batch: MeshBatcher, center: Vector3, size: Vector3, color: Color) -> void:
	batch.box(center + Vector3.UP * (size.y - 0.04), Vector3(size.x, 0.08, size.z), color)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var leg := center + Vector3(sx * (size.x * 0.5 - 0.08), (size.y - 0.08) * 0.5, sz * (size.z * 0.5 - 0.08))
			batch.box(leg, Vector3(0.08, size.y - 0.08, 0.08), color.darkened(0.25))


## Escritorio macizo con cajones.
static func desk(location: LocationBase, center: Vector3, size: Vector3) -> void:
	var procedural := func(_tint: Color) -> void: _desk_mesh(location.batch, center, size)
	ModelCatalog.draw(location, "escritorio", Transform3D(Basis.IDENTITY, center), procedural, ModelCatalog.size_key(size))
	location.collider(center + Vector3.UP * size.y * 0.5, size)


static func _desk_mesh(batch: MeshBatcher, center: Vector3, size: Vector3) -> void:
	batch.box(center + Vector3.UP * size.y * 0.5, size, Palette.WOOD_DARK)
	batch.box(center + Vector3.UP * (size.y + 0.02), Vector3(size.x + 0.1, 0.05, size.z + 0.1), Palette.WOOD)
	batch.box(center + Vector3(0.0, size.y + 0.05, 0.0), Vector3(size.x * 0.5, 0.012, size.z * 0.6), Color("243a2c"))
	for x: float in [-size.x * 0.3, size.x * 0.3]:
		batch.box(center + Vector3(x, size.y * 0.5, size.z * 0.5 + 0.01), Vector3(size.x * 0.32, size.y * 0.7, 0.02), Palette.WOOD)


static func chair(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0, color: Color = Palette.WOOD) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(tint: Color) -> void: _chair_mesh(location.batch, tint)
	ModelCatalog.draw(location, "silla", Transform3D.IDENTITY, procedural, "", color)
	location.collider(Vector3(0.0, 0.5, 0.0), Vector3(0.5, 1.0, 0.5))
	location.batch.xform = previous


static func _chair_mesh(batch: MeshBatcher, color: Color) -> void:
	batch.box(Vector3(0.0, 0.46, 0.0), Vector3(0.5, 0.06, 0.5), color)
	batch.box(Vector3(0.0, 0.8, -0.22), Vector3(0.5, 0.62, 0.06), color)
	for sx: float in [-0.2, 0.2]:
		for sz: float in [-0.2, 0.2]:
			batch.box(Vector3(sx, 0.22, sz), Vector3(0.05, 0.44, 0.05), color.darkened(0.3))


static func armchair(location: LocationBase, where: Vector3, yaw_degrees: float, color: Color) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(tint: Color) -> void: _armchair_mesh(location.batch, tint)
	ModelCatalog.draw(location, "sillon", Transform3D.IDENTITY, procedural, "", color)
	location.collider(Vector3(0.0, 0.55, 0.0), Vector3(1.0, 1.1, 0.95))
	location.batch.xform = previous


## El respaldo es 2 cm más estrecho que el asiento y los brazos, 2 cm más largos: ninguna cara
## comparte plano con otra de distinto tono (antes los costados y el frente parpadeaban).
static func _armchair_mesh(batch: MeshBatcher, color: Color) -> void:
	batch.box(Vector3(0.0, 0.26, 0.0), Vector3(0.95, 0.42, 0.9), color)
	batch.box(Vector3(0.0, 0.62, -0.36), Vector3(0.93, 0.9, 0.22), color.darkened(0.1))
	for x: float in [-0.42, 0.42]:
		batch.box(Vector3(x, 0.56, 0.0), Vector3(0.18, 0.36, 0.92), color.darkened(0.14))


static func sofa(location: LocationBase, where: Vector3, yaw_degrees: float, color: Color, length: float = 2.4) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(tint: Color) -> void: _sofa_mesh(location.batch, tint, length)
	ModelCatalog.draw(location, "sofa", Transform3D.IDENTITY, procedural, ModelCatalog.size_key(length), color)
	location.collider(Vector3(0.0, 0.55, 0.0), Vector3(length + 0.2, 1.1, 0.98))
	location.batch.xform = previous


static func _sofa_mesh(batch: MeshBatcher, color: Color, length: float) -> void:
	batch.box(Vector3(0.0, 0.26, 0.0), Vector3(length, 0.42, 0.95), color)
	batch.box(Vector3(0.0, 0.66, -0.38), Vector3(length, 0.8, 0.22), color.darkened(0.1))
	# Brazos 2 cm más largos que el asiento: con la misma medida, sus frentes se pisaban.
	for x: float in [-length * 0.5, length * 0.5]:
		batch.box(Vector3(x, 0.56, 0.0), Vector3(0.2, 0.42, 0.97), color.darkened(0.14))


## Estantería de libros pegada a una pared que mira hacia +Z local.
static func bookshelf(location: LocationBase, where: Vector3, width: float, height: float = 2.6, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(_tint: Color) -> void: _bookshelf_mesh(location.batch, width, height)
	ModelCatalog.draw(location, "estanteria", Transform3D.IDENTITY, procedural, ModelCatalog.size_key(Vector2(width, height)))
	location.collider(Vector3(0.0, height * 0.5, 0.1), Vector3(width, height, 0.45))
	location.batch.xform = previous


## Las baldas están a 0,5 m y miden 5 cm: entre una y otra caben 45 cm. Los libros miden de 26 a
## 41 cm y, en la última balda, nunca sobresalen del mueble. Antes llegaban a 55 cm: atravesaban la
## balda de encima y su cara frontal compartía plano con la de los libros de arriba, que parpadeaban
## (z-fighting). Baldas y fondo van entre los laterales, sin pisar su canto ni su remate.
static func _bookshelf_mesh(batch: MeshBatcher, width: float, height: float) -> void:
	var inner := width - BOOKSHELF_SIDE
	batch.box(Vector3(0.0, height * 0.5, -0.05), Vector3(inner, height, 0.1), Palette.WOOD_DARK)
	for x: float in [-width * 0.5, width * 0.5]:
		batch.box(Vector3(x, height * 0.5, 0.15), Vector3(BOOKSHELF_SIDE, height, 0.4), Palette.WOOD)
	var shelves := int(height / BOOKSHELF_SPACING)
	var colors := [Palette.WINE, Palette.STEEL, Color("3d4a33"), Palette.PAPER.darkened(0.3), Color("5a4630"), Palette.SLATE]
	for shelf in shelves:
		var y := 0.1 + float(shelf) * BOOKSHELF_SPACING
		batch.box(Vector3(0.0, y, 0.15), Vector3(inner, BOOKSHELF_BOARD, 0.4), Palette.WOOD)
		var x := -width * 0.5 + 0.1
		var index := shelf * 3
		var room := minf(BOOKSHELF_SPACING - BOOKSHELF_BOARD, height - y - BOOKSHELF_BOARD * 0.5) - BOOKSHELF_HEADROOM
		while x < width * 0.5 - 0.16:
			var book := 0.08 + 0.05 * float(index % 3)
			var tall := minf(0.26 + 0.05 * float(index % 4), room)
			batch.box(Vector3(x + book * 0.5, y + tall * 0.5 + 0.025, 0.17), Vector3(book, tall, 0.26), colors[index % colors.size()])
			x += book + 0.012
			index += 1


## Archivador de cajones, para el archivo municipal.
static func filing_cabinet(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(_tint: Color) -> void: _filing_cabinet_mesh(location.batch)
	ModelCatalog.draw(location, "archivador", Transform3D.IDENTITY, procedural)
	location.collider(Vector3(0.0, 0.9, 0.0), Vector3(0.9, 1.8, 0.6))
	location.batch.xform = previous


static func _filing_cabinet_mesh(batch: MeshBatcher) -> void:
	batch.box(Vector3(0.0, 0.9, 0.0), Vector3(0.9, 1.8, 0.6), Palette.STEEL.darkened(0.2))
	for y: float in [0.3, 0.75, 1.2, 1.65]:
		batch.box(Vector3(0.0, y, 0.31), Vector3(0.78, 0.38, 0.02), Palette.STEEL)
		batch.box(Vector3(0.0, y, 0.33), Vector3(0.2, 0.05, 0.03), Palette.AMBER_SOFT.darkened(0.3))


static func fireplace(location: LocationBase, where: Vector3, width: float = 2.4) -> void:
	var procedural := func(_tint: Color) -> void: _fireplace_mesh(location.batch, where, width)
	ModelCatalog.draw(location, "chimenea", Transform3D(Basis.IDENTITY, where), procedural, ModelCatalog.size_key(width))
	location.collider(where + Vector3(0.0, 1.0, 0.0), Vector3(width, 2.0, 0.6))
	location.add_point_light(where + Vector3(0.0, 0.7, 1.2), Color("ff8f3f"), 3.0, 6.5)


static func _fireplace_mesh(batch: MeshBatcher, where: Vector3, width: float) -> void:
	batch.box(where + Vector3(0.0, 1.0, 0.0), Vector3(width, 2.0, 0.6), Palette.STONE)
	batch.box(where + Vector3(0.0, 2.04, 0.08), Vector3(width + 0.4, 0.12, 0.8), Palette.WOOD_DARK)
	batch.box(where + Vector3(0.0, 0.62, 0.31), Vector3(width * 0.6, 1.0, 0.02), Color("100b09"))
	batch.box(where + Vector3(0.0, 0.3, 0.33), Vector3(width * 0.44, 0.36, 0.04), Color("ff7a24"), 0.0, MeshBatcher.Layer.GLOW)


## Lámpara de pie con pantalla cálida.
static func floor_lamp(location: LocationBase, where: Vector3, energy: float = 2.6) -> void:
	var procedural := func(_tint: Color) -> void: _floor_lamp_mesh(location.batch, where)
	ModelCatalog.draw(location, "lampara_pie", Transform3D(Basis.IDENTITY, where), procedural)
	location.collider(where + Vector3.UP * 0.6, Vector3(0.28, 1.2, 0.28))
	location.add_point_light(where + Vector3.UP * 1.7, Color("ffb765"), energy, 7.0)


static func _floor_lamp_mesh(batch: MeshBatcher, where: Vector3) -> void:
	batch.cylinder(where, 0.2, 0.05, 0.08, Palette.IRON, 6)
	batch.cylinder(where + Vector3.UP * 0.08, 0.03, 0.03, 1.5, Palette.IRON, 5)
	batch.cylinder(where + Vector3.UP * 1.58, 0.32, 0.18, 0.34, Palette.AMBER_SOFT, 7, MeshBatcher.Layer.GLOW)


## Lámpara colgante sin colisión, para iluminar una estancia entera.
static func ceiling_lamp(location: LocationBase, where: Vector3, energy: float = 3.4, light_range: float = 9.0, shadows: bool = false) -> void:
	var procedural := func(_tint: Color) -> void: _ceiling_lamp_mesh(location.batch, where)
	ModelCatalog.draw(location, "lampara_techo", Transform3D(Basis.IDENTITY, where), procedural)
	location.add_point_light(where - Vector3.UP * 0.1, Color("ffbd72"), energy, light_range, shadows)


static func _ceiling_lamp_mesh(batch: MeshBatcher, where: Vector3) -> void:
	batch.cylinder(where + Vector3.UP * 0.3, 0.02, 0.02, 0.6, Palette.IRON, 4)
	batch.cylinder(where, 0.34, 0.12, 0.3, Palette.AMBER_SOFT, 8, MeshBatcher.Layer.GLOW)


## Cama. Las medidas son la variante del modelo y la colcha, su tinte.
static func bed(location: LocationBase, where: Vector3, yaw_degrees: float, blanket: Color, size: Vector2 = Vector2(1.5, 2.1)) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(tint: Color) -> void: _bed_mesh(location.batch, tint, size)
	ModelCatalog.draw(location, "cama", Transform3D.IDENTITY, procedural, ModelCatalog.size_key(size), blanket)
	location.collider(Vector3(0.0, 0.4, 0.0), Vector3(size.x, 0.8, size.y))
	location.batch.xform = previous


static func _bed_mesh(batch: MeshBatcher, blanket: Color, size: Vector2) -> void:
	batch.box(Vector3(0.0, 0.2, 0.0), Vector3(size.x, 0.4, size.y), Palette.WOOD_DARK)
	batch.box(Vector3(0.0, 0.46, 0.0), Vector3(size.x - 0.08, 0.14, size.y - 0.08), Palette.PAPER.darkened(0.15))
	batch.box(Vector3(0.0, 0.53, 0.26), Vector3(size.x, 0.1, size.y * 0.72), blanket)
	batch.box(Vector3(0.0, 0.6, -size.y * 0.5 + 0.28), Vector3(size.x - 0.3, 0.14, 0.38), Palette.PAPER)
	batch.box(Vector3(0.0, 0.7, -size.y * 0.5), Vector3(size.x, 1.0, 0.1), Palette.WOOD)


## Mueble bajo con espejo: tocador o aparador, pegado a una pared.
static func dresser(location: LocationBase, where: Vector3, width: float, with_mirror: bool, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(_tint: Color) -> void: _dresser_mesh(location.batch, width, with_mirror)
	var variant := ModelCatalog.size_key(width) + ("_espejo" if with_mirror else "")
	ModelCatalog.draw(location, "comoda", Transform3D.IDENTITY, procedural, variant)
	location.collider(Vector3(0.0, 0.42, 0.0), Vector3(width, 0.84, 0.5))
	location.batch.xform = previous


static func _dresser_mesh(batch: MeshBatcher, width: float, with_mirror: bool) -> void:
	batch.box(Vector3(0.0, 0.42, 0.0), Vector3(width, 0.84, 0.5), Palette.WOOD)
	batch.box(Vector3(0.0, 0.86, 0.0), Vector3(width + 0.06, 0.04, 0.54), Palette.WOOD_LIGHT)
	for x: float in [-width * 0.25, width * 0.25]:
		batch.box(Vector3(x, 0.42, 0.26), Vector3(width * 0.42, 0.6, 0.02), Palette.WOOD_DARK)
	if with_mirror:
		batch.box(Vector3(0.0, 1.45, -0.2), Vector3(width * 0.7, 1.1, 0.05), Palette.WOOD_DARK)
		batch.box(Vector3(0.0, 1.45, -0.17), Vector3(width * 0.6, 1.0, 0.02), Color("6f8092"))


## Cuadro colgado en una pared que mira hacia +Z local. El lienzo toma el color `color` (tinte).
static func painting(location: LocationBase, where: Vector3, size: Vector2, color: Color, yaw_degrees: float = 0.0) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	var procedural := func(tint: Color) -> void: _painting_mesh(location.batch, where, size, tint, yaw)
	ModelCatalog.draw(location, "cuadro", Transform3D(Basis(Vector3.UP, yaw), where), procedural, ModelCatalog.size_key(size), color)


static func _painting_mesh(batch: MeshBatcher, where: Vector3, size: Vector2, color: Color, yaw: float) -> void:
	batch.box(where, Vector3(size.x + 0.14, size.y + 0.14, 0.05), Palette.WOOD_LIGHT.darkened(0.2), yaw)
	var forward := Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 0.03)
	batch.box(where + forward, Vector3(size.x, size.y, 0.03), color, yaw)


## Ventana del fondo por la que entra la luz fría de la calle.
static func back_window(location: LocationBase, where: Vector3, size: Vector2, yaw_degrees: float = 0.0) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	var procedural := func(_tint: Color) -> void: _back_window_mesh(location.batch, where, size, yaw)
	ModelCatalog.draw(location, "ventana_interior", Transform3D(Basis(Vector3.UP, yaw), where), procedural, ModelCatalog.size_key(size))


static func _back_window_mesh(batch: MeshBatcher, where: Vector3, size: Vector2, yaw: float) -> void:
	var outward := Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 0.04)
	batch.box(where, Vector3(size.x + 0.2, size.y + 0.2, 0.06), Palette.WOOD_DARK, yaw)
	batch.box(where + outward, Vector3(size.x, size.y, 0.02), Color("4a6585"), yaw, MeshBatcher.Layer.GLOW)
	# Travesaño medio centímetro por delante del parteluz, para que el cruce no parpadee.
	batch.box(where + outward * 2.0, Vector3(0.05, size.y, 0.02), Palette.WOOD_DARK, yaw)
	batch.box(where + outward * 2.25, Vector3(size.x, 0.05, 0.02), Palette.WOOD_DARK, yaw)


static func plant(location: LocationBase, where: Vector3) -> void:
	var procedural := func(_tint: Color) -> void: _plant_mesh(location.batch, where)
	ModelCatalog.draw(location, "planta", Transform3D(Basis.IDENTITY, where), procedural)
	location.collider(where + Vector3.UP * 0.4, Vector3(0.5, 0.8, 0.5))


static func _plant_mesh(batch: MeshBatcher, where: Vector3) -> void:
	batch.cylinder(where, 0.2, 0.26, 0.42, Palette.BRICK, 7)
	batch.sphere(where + Vector3.UP * 0.8, 0.42, Palette.FOLIAGE_LIGHT, 6, 4, Vector3(1.0, 1.1, 1.0))


## Reloj de pie, recurrente en la mansión por razones evidentes.
static func grandfather_clock(location: LocationBase, where: Vector3, yaw_degrees: float = 0.0) -> void:
	var previous := location.batch.xform
	location.batch.xform = previous * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), where)
	var procedural := func(_tint: Color) -> void: _grandfather_clock_mesh(location.batch)
	ModelCatalog.draw(location, "reloj_pie", Transform3D.IDENTITY, procedural)
	location.collider(Vector3(0.0, 1.1, 0.0), Vector3(0.6, 2.2, 0.4))
	location.batch.xform = previous


static func _grandfather_clock_mesh(batch: MeshBatcher) -> void:
	batch.box(Vector3(0.0, 1.1, 0.0), Vector3(0.6, 2.2, 0.4), Palette.WOOD_DARK)
	batch.box(Vector3(0.0, 2.3, 0.0), Vector3(0.7, 0.2, 0.46), Palette.WOOD)
	var saved := batch.xform
	batch.xform = saved * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 1.85, 0.22))
	batch.cylinder(Vector3.ZERO, 0.22, 0.22, 0.03, Palette.PAPER, 10)
	batch.xform = saved
	batch.box(Vector3(0.0, 0.8, 0.21), Vector3(0.32, 1.0, 0.02), Color("1a1512"))
	batch.box(Vector3(0.0, 0.55, 0.23), Vector3(0.14, 0.14, 0.02), Palette.AMBER_SOFT.darkened(0.2))
