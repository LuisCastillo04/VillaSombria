extends TestCase
## Lote de geometría: la variación de tono de cada cara no depende del orden en que se añaden.

const SQUARE := [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]


func test_shade_does_not_depend_on_previous_faces() -> void:
	var alone := MeshBatcher.new()
	alone.face(PackedVector3Array(SQUARE), Palette.STONE, Vector3.UP)
	var after_others := MeshBatcher.new()
	for index in 5:
		after_others.box(Vector3(float(index) * 3.0, 4.0, 0.0), Vector3.ONE, Palette.WOOD)
	after_others.face(PackedVector3Array(SQUARE), Palette.STONE, Vector3.UP)
	var first := _colors(alone)[0]
	var colors := _colors(after_others)
	var last := colors[colors.size() - 1]
	check(first.is_equal_approx(last), "La misma cara debe tener el mismo tono aunque antes haya otras (%s, %s)" % [first, last])


func test_shade_stays_within_the_jitter() -> void:
	var batch := MeshBatcher.new()
	for index in 40:
		batch.box(Vector3(float(index) * 0.37, 0.5, float(index % 7) * 0.61), Vector3(0.3, 0.3, 0.3), Palette.STONE)
	var shades := {}
	for color in _colors(batch):
		var shade := color.r - Palette.STONE.r
		# La malla guarda el color con 8 bits por canal: hasta 1/255 de redondeo.
		check(absf(shade) <= batch.color_jitter + 1.0 / 255.0, "Variación fuera de ±%.3f: %.4f" % [batch.color_jitter, shade])
		shades[snappedf(shade, 0.001)] = true
	# ±0,035 con 8 bits por canal da unos 18 tonos posibles.
	check(shades.size() >= 12, "Las caras deben variar de tono entre sí (%d tonos distintos)" % shades.size())


func test_seed_and_glow_layer() -> void:
	var one := MeshBatcher.new(7)
	var other := MeshBatcher.new(8)
	one.face(PackedVector3Array(SQUARE), Palette.STONE, Vector3.UP)
	other.face(PackedVector3Array(SQUARE), Palette.STONE, Vector3.UP)
	check(not _colors(one)[0].is_equal_approx(_colors(other)[0]), "Otra semilla debe dar otro tono")
	var glow := MeshBatcher.new()
	glow.face(PackedVector3Array(SQUARE), Palette.AMBER, Vector3.UP, MeshBatcher.Layer.GLOW)
	check(_colors(glow, MeshBatcher.Layer.GLOW)[0].is_equal_approx(Palette.AMBER), "La capa de brillo no varía de tono")


func test_shade_survives_float_noise() -> void:
	var batch := MeshBatcher.new()
	var center := Vector3(-2.2, 0.875, -12.1)
	var base := batch.shaded(Palette.WINE, center)
	for offset: Vector3 in [Vector3(1e-5, 0.0, 0.0), Vector3(0.0, -1e-5, 0.0), Vector3(0.0, 0.0, 1e-5)]:
		check(batch.shaded(Palette.WINE, center + offset).is_equal_approx(base), "Un error de coma flotante no debe cambiar el tono")


func _colors(batch: MeshBatcher, layer: MeshBatcher.Layer = MeshBatcher.Layer.OPAQUE) -> PackedColorArray:
	return batch.build_mesh(layer).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
