class_name BuildingKit
extends RefCounted
## Piezas de arquitectura. Todas trabajan en un sistema local donde X recorre la
## fachada, Y es la altura y +Z sale hacia la calle; `begin` fija ese sistema.
## Ventanas, puertas, toldos, chimeneas y columnas dibujan su parte visual con
## `ModelCatalog.draw` (modelos de Blender con el código de aquí como alternativa). El cuerpo
## (`body`) sigue siendo procedural: su huella la copian el mapa del pueblo y `test_map`.

## Altura del montante de cristal de `double_door`, sobre las hojas.
const DOOR_TRANSOM := 0.45


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
	var procedural := func(_tint: Color) -> void: _window_mesh(location.batch, x, y, width, height, lit, shutters)
	var variant := ModelCatalog.size_key(Vector2(width, height)) + ("_luz" if lit else "") + ("_postigos" if shutters else "")
	ModelCatalog.draw(location, "ventana", Transform3D(Basis.IDENTITY, Vector3(x, y, 0.0)), procedural, variant)


static func _window_mesh(batch: MeshBatcher, x: float, y: float, width: float, height: float, lit: bool, shutters: bool) -> void:
	batch.box(Vector3(x, y, 0.03), Vector3(width + 0.2, height + 0.2, 0.08), Palette.WOOD_DARK)
	if lit:
		batch.box(Vector3(x, y, 0.07), Vector3(width, height, 0.03), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
	else:
		batch.box(Vector3(x, y, 0.07), Vector3(width, height, 0.03), Color("1b2433"))
	# El travesaño queda medio centímetro por delante del parteluz: si los dos compartieran el
	# plano de su cara frontal, el cruce parpadearía (z-fighting) al moverse la cámara.
	batch.box(Vector3(x, y, 0.1), Vector3(0.05, height, 0.02), Palette.WOOD_DARK)
	batch.box(Vector3(x, y, 0.105), Vector3(width, 0.05, 0.02), Palette.WOOD_DARK)
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


## Puerta con su marco, montante iluminado y escalón. Las medidas son la variante y el color de la
## hoja, su tinte. El marco sobresale 13 cm de la fachada: 2 cm más que el zócalo de `body` (11 cm).
## Antes sobresalía lo mismo que el zócalo y sus caras frontales compartían plano: las franjas del
## marco junto a la hoja parpadeaban al caminar (z-fighting) en el archivo y en el café.
static func door(location: LocationBase, x: float, width: float, height: float, color: Color) -> void:
	var procedural := func(tint: Color) -> void: _door_mesh(location.batch, x, width, height, tint)
	ModelCatalog.draw(location, "puerta", Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)), procedural, ModelCatalog.size_key(Vector2(width, height)), color)


static func _door_mesh(batch: MeshBatcher, x: float, width: float, height: float, color: Color) -> void:
	batch.box(Vector3(x, height * 0.5 + 0.1, 0.06), Vector3(width + 0.36, height + 0.3, 0.14), Palette.STONE_LIGHT.darkened(0.15))
	batch.box(Vector3(x, height * 0.5, 0.1), Vector3(width, height, 0.08), color)
	batch.box(Vector3(x, height * 0.72, 0.15), Vector3(width * 0.6, height * 0.3, 0.02), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
	batch.box(Vector3(x + width * 0.35, height * 0.45, 0.17), Vector3(0.07, 0.07, 0.06), Palette.AMBER)
	batch.box(Vector3(x, 0.06, 0.4), Vector3(width + 0.8, 0.12, 0.7), Palette.STONE_LIGHT.darkened(0.1))


## Puerta doble de madera oscura con cuarterones, montante de cristal y escalón, dentro de un
## marco de piedra con cornisa. Es sólo fachada: no lleva salida, y su colisión (marco y escalón)
## impide atravesarla o subirse al escalón. Las medidas de la hoja son la variante del modelo.
static func double_door(location: LocationBase, x: float, width: float, height: float) -> void:
	var procedural := func(_tint: Color) -> void: _double_door_mesh(location.batch, x, width, height)
	ModelCatalog.draw(location, "puerta_doble", Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)), procedural, ModelCatalog.size_key(Vector2(width, height)))
	location.collider(Vector3(x, 0.6, 0.38), Vector3(width + 0.9, 1.2, 0.76))
	location.collider(Vector3(x, (height + DOOR_TRANSOM) * 0.5, 0.11), Vector3(width + 0.5, height + DOOR_TRANSOM, 0.22))


## Capas hacia la calle, sin caras compartidas: zócalo de `body` hasta 11 cm, marco hasta 15,
## hojas y travesaño hasta 21, cuarterones hasta 22 y tiradores hasta 24,5.
static func _double_door_mesh(batch: MeshBatcher, x: float, width: float, height: float) -> void:
	var top := height + DOOR_TRANSOM
	batch.box(Vector3(x, top * 0.5, 0.07), Vector3(width + 0.5, top, 0.16), Palette.STONE_LIGHT.darkened(0.12))
	batch.box(Vector3(x, top + 0.06, 0.09), Vector3(width + 0.7, 0.12, 0.2), Palette.STONE_LIGHT)
	var leaf_width := width * 0.5 - 0.01
	for side: float in [-1.0, 1.0]:
		var leaf_x := x + side * width * 0.25
		batch.box(Vector3(leaf_x, height * 0.5, 0.18), Vector3(leaf_width, height, 0.06), Palette.WOOD_DARK)
		for panel_y: float in [height * 0.27, height * 0.7]:
			batch.box(Vector3(leaf_x + side * 0.02, panel_y, 0.215), Vector3(leaf_width - 0.2, height * 0.3, 0.01), Palette.WOOD.darkened(0.3))
		batch.box(Vector3(x + side * 0.06, height * 0.48, 0.23), Vector3(0.035, 0.16, 0.03), Palette.AMBER)
	batch.box(Vector3(x, height + 0.035, 0.18), Vector3(width, 0.07, 0.06), Palette.WOOD_DARK)
	var glass_height := DOOR_TRANSOM - 0.12
	var glass_y := height + 0.07 + glass_height * 0.5
	batch.box(Vector3(x, glass_y, 0.16), Vector3(width - 0.1, glass_height, 0.02), Palette.WINDOW_WARM, 0.0, MeshBatcher.Layer.GLOW)
	for bar: float in [-1.0, 1.0]:
		batch.box(Vector3(x + bar * (width - 0.1) / 6.0, glass_y, 0.18), Vector3(0.04, glass_height, 0.02), Palette.WOOD_DARK)
	batch.box(Vector3(x, 0.07, 0.4), Vector3(width + 0.9, 0.14, 0.7), Palette.STONE_LIGHT.darkened(0.1))


## Placa clavada en la fachada con un aviso de dos líneas y el dibujo de un martillo y una llave
## cruzados. `center` es el centro de la placa sobre la pared; el texto es un rótulo (Label3D).
static func notice(location: LocationBase, center: Vector3, size: Vector2, text: String) -> void:
	var procedural := func(_tint: Color) -> void: _notice_mesh(location.batch, center, size)
	ModelCatalog.draw(location, "aviso", Transform3D(Basis.IDENTITY, center), procedural, ModelCatalog.size_key(size))
	location.add_sign(text, center + Vector3(0.0, -size.y * 0.14, 0.075), size.y * 0.2, Palette.INK)


static func _notice_mesh(batch: MeshBatcher, center: Vector3, size: Vector2) -> void:
	batch.box(center + Vector3(0.0, 0.0, 0.02), Vector3(size.x + 0.1, size.y + 0.1, 0.04), Palette.WOOD_DARK)
	batch.box(center + Vector3(0.0, 0.0, 0.05), Vector3(size.x - 0.04, size.y - 0.04, 0.02), Palette.PAPER.darkened(0.12))
	# Martillo y llave inglesa cruzados, en la parte de arriba de la placa: dos mangos y sus cabezas.
	for side: float in [-1.0, 1.0]:
		# Cada pieza 3 mm por delante de la otra: donde se cruzan no comparten plano.
		var icon := center + Vector3(0.0, size.y * 0.27, 0.064 + (0.003 if side > 0.0 else 0.0))
		var along := Vector3(cos(PI * 0.25) * side, sin(PI * 0.25), 0.0)
		var across := Vector3(-along.y, along.x, 0.0)
		var half := 0.11
		var thick := 0.014
		batch.face(PackedVector3Array([
			icon - along * half - across * thick, icon + along * half - across * thick,
			icon + along * half + across * thick, icon - along * half + across * thick,
		]), Palette.INK, Vector3.BACK)
		var head := icon + along * (half + 0.012) + Vector3(0.0, 0.0, 0.0015)
		var head_size := 0.04 if side > 0.0 else 0.03
		batch.face(PackedVector3Array([
			head - along * 0.025 - across * head_size, head + along * 0.025 - across * head_size,
			head + along * 0.025 + across * head_size, head - along * 0.025 + across * head_size,
		]), Palette.INK, Vector3.BACK)


## Toldo inclinado de rayas.
static func awning(location: LocationBase, x: float, y: float, width: float, depth: float) -> void:
	var procedural := func(_tint: Color) -> void: _awning_mesh(location.batch, x, y, width, depth)
	ModelCatalog.draw(location, "toldo", Transform3D(Basis.IDENTITY, Vector3(x, y, 0.0)), procedural, ModelCatalog.size_key(Vector2(width, depth)))


static func _awning_mesh(batch: MeshBatcher, x: float, y: float, width: float, depth: float) -> void:
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
	var procedural := func(_tint: Color) -> void: _chimney_mesh(location.batch, where)
	ModelCatalog.draw(location, "chimenea_tejado", Transform3D(Basis.IDENTITY, where), procedural)


static func _chimney_mesh(batch: MeshBatcher, where: Vector3) -> void:
	batch.box(where + Vector3.UP * 0.6, Vector3(0.7, 1.2, 0.7), Palette.BRICK)
	batch.box(where + Vector3.UP * 1.25, Vector3(0.85, 0.12, 0.85), Palette.STONE_DARK)


## Columna clásica con basa y capitel.
static func column(location: LocationBase, base: Vector3, height: float) -> void:
	var procedural := func(_tint: Color) -> void: _column_mesh(location.batch, base, height)
	ModelCatalog.draw(location, "columna", Transform3D(Basis.IDENTITY, base), procedural, ModelCatalog.size_key(height))
	location.collider(base + Vector3.UP * height * 0.5, Vector3(0.5, height, 0.5))


static func _column_mesh(batch: MeshBatcher, base: Vector3, height: float) -> void:
	batch.box(base + Vector3.UP * 0.1, Vector3(0.7, 0.2, 0.7), Palette.STONE_LIGHT)
	batch.cylinder(base + Vector3.UP * 0.2, 0.25, 0.21, height - 0.4, Palette.STONE_LIGHT, 8)
	batch.box(base + Vector3.UP * (height - 0.1), Vector3(0.66, 0.2, 0.66), Palette.STONE_LIGHT)
