class_name JournalFolder
extends Control
## Carpeta de cuero del expediente. Pinta el cuero rojizo con su pespunte y sus esquinas de latón,
## la banda de pergamino del encabezado (con los bordes quemados) y el hueco oscuro donde descansan
## las páginas; y coloca encima el encabezado, el sello, las pestañas, el cuerpo y el pie.
##
## Las pestañas montan a caballo entre el pergamino y el cuero, como las de una carpeta real: la
## banda termina a media altura de ellas. Todo se recalcula al cambiar el tamaño de la carpeta.

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const LEATHER_SHADER := preload("res://assets/shaders/leather.gdshader")
const RADIUS := 14.0
const CONTENT_INSET := 30.0
const SEAL_SIZE := Vector2(310.0, 168.0)
const WELL_INSET := 16.0
const BODY_INSET := 18.0

var header: JournalHeader
var seal: JournalSeal
var tabs: JournalTabs
## Donde van las secciones, una encima de otra: un contenedor que las ajusta a su tamaño.
var body: MarginContainer
var footer: JournalFooter

var _leather: ColorRect
var _band: ColorRect
var _well: ColorRect
var _band_rect := Rect2()
var _well_rect := Rect2()
var _footer_left := 0.0
var _body_rect := Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leather = _shader_rect("Leather", LEATHER_SHADER)
	_well = _shader_rect("Well", LEATHER_SHADER)
	_band = _shader_rect("Band", PARCHMENT_SHADER)
	var well_material := _well.material as ShaderMaterial
	well_material.set_shader_parameter("base_color", JournalStyle.LEATHER_DARK)
	well_material.set_shader_parameter("dark_color", JournalStyle.LEATHER_DEEP)
	well_material.set_shader_parameter("sheen_color", JournalStyle.LEATHER)
	well_material.set_shader_parameter("corner_radius", 6.0)
	well_material.set_shader_parameter("edge_width", 40.0)
	well_material.set_shader_parameter("seed", 4.1)
	var band_material := _band.material as ShaderMaterial
	band_material.set_shader_parameter("base_color", JournalStyle.PARCHMENT)
	band_material.set_shader_parameter("stain_color", JournalStyle.PARCHMENT_STAIN)
	band_material.set_shader_parameter("edge_color", JournalStyle.PARCHMENT_EDGE)
	band_material.set_shader_parameter("corner_radius", 8.0)
	band_material.set_shader_parameter("edge_width", 40.0)
	band_material.set_shader_parameter("seed", 6.6)
	header = JournalHeader.new()
	header.name = "Header"
	add_child(header)
	seal = JournalSeal.new()
	seal.name = "Seal"
	add_child(seal)
	tabs = JournalTabs.new()
	tabs.name = "Tabs"
	add_child(tabs)
	body = MarginContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	# Una etiqueta con ajuste de línea puede pedir de paso más alto del que acaba usando: cuando el
	# mínimo vuelve a bajar, el cuerpo recupera su tamaño.
	body.minimum_size_changed.connect(_restore_body.call_deferred)
	body.resized.connect(_place_footer)
	footer = JournalFooter.new()
	footer.name = "Footer"
	add_child(footer)
	resized.connect(relayout)


## Rectángulo del cuerpo, donde van las secciones, dentro de la carpeta.
func get_body_rect() -> Rect2:
	return Rect2(body.position, body.size)


func get_band_rect() -> Rect2:
	return _band_rect


func get_well_rect() -> Rect2:
	return _well_rect


## Dónde empieza el pie, medido desde la izquierda del cuerpo: debajo de la página de la ficha.
func set_footer_left(left: float) -> void:
	if is_equal_approx(left, _footer_left):
		return
	_footer_left = left
	_place_footer()


func relayout() -> void:
	var width := size.x
	var height := size.y
	var border := JournalStyle.FOLDER_BORDER
	var top := border + 10.0
	var seal_position := Vector2(width - border - SEAL_SIZE.x - 6.0, border - 4.0)
	seal.position = seal_position
	seal.size = SEAL_SIZE
	header.position = Vector2(CONTENT_INSET, top)
	header.size = Vector2(maxf(seal_position.x - CONTENT_INSET + 40.0, 300.0), JournalStyle.HEADER_HEIGHT)
	var tabs_left := CONTENT_INSET + 22.0
	var tabs_top := top + JournalStyle.HEADER_HEIGHT - 4.0
	# Las pestañas terminan antes del sello; en pantallas estrechas pasan por debajo de él.
	var tabs_width := maxf(seal_position.x + 56.0 - tabs_left, 400.0)
	if not tabs.fits(tabs_width):
		tabs_width = maxf(tabs_width, width - tabs_left - CONTENT_INSET)
	tabs.fit_width(tabs_width)
	tabs.position = Vector2(tabs_left, tabs_top)
	tabs.size = Vector2(tabs_width, JournalStyle.TAB_HEIGHT)
	_band_rect = Rect2(Vector2(border, border), Vector2(width - border * 2.0, tabs_top + JournalStyle.TAB_HEIGHT * 0.5 - border))
	var well_top := tabs_top + JournalStyle.TAB_HEIGHT + 8.0
	_well_rect = Rect2(Vector2(border + WELL_INSET, well_top), Vector2(width - (border + WELL_INSET) * 2.0, height - well_top - border - WELL_INSET))
	_body_rect = _well_rect.grow(-BODY_INSET)
	_restore_body()
	_fit_rect(_leather, Rect2(Vector2.ZERO, size))
	_fit_rect(_band, _band_rect)
	_fit_rect(_well, _well_rect)
	_place_footer()
	queue_redraw()


func _restore_body() -> void:
	body.position = _body_rect.position
	body.size = _body_rect.size


func _place_footer() -> void:
	var footer_height := JournalStyle.FOOTER_HEIGHT
	footer.position = body.position + Vector2(_footer_left, body.size.y - footer_height + 6.0)
	footer.size = Vector2(maxf(body.size.x - _footer_left, 0.0), footer_height)


func _shader_rect(node_name: String, shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	rect.show_behind_parent = true
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect, false, Node.INTERNAL_MODE_FRONT)
	return rect


static func _fit_rect(rect: ColorRect, area: Rect2) -> void:
	rect.position = area.position
	rect.size = area.size
	(rect.material as ShaderMaterial).set_shader_parameter("rect_size", area.size)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var border := JournalStyle.FOLDER_BORDER
	# Contorno de la carpeta: filete dorado por fuera, pespunte y otro filete por dentro.
	_rounded_outline(rect.grow(-1.0), Color(JournalStyle.GOLD_DARK, 0.9), 2.0, RADIUS)
	_rounded_outline(rect.grow(-4.0), Color(JournalStyle.GOLD, 0.75), 1.2, RADIUS - 3.0)
	JournalOrnaments.draw_stitches(self, rect.grow(-8.0), Color(JournalStyle.GOLD_LIGHT, 0.35))
	# Banda del encabezado: un borde oscuro que la asienta sobre el cuero y un filete dorado.
	draw_rect(_band_rect, Color(JournalStyle.FRAME, 0.85), false, 2.0, true)
	draw_rect(_band_rect.grow(-6.0), Color(JournalStyle.GOLD_DARK, 0.6), false, 1.0, true)
	var band_bottom := _band_rect.end.y
	draw_rect(Rect2(Vector2(_band_rect.position.x, band_bottom), Vector2(_band_rect.size.x, 10.0)), Color(0.0, 0.0, 0.0, 0.28))
	# Hueco de las páginas: hundido, con un filete dorado.
	draw_rect(_well_rect.grow(2.0), Color(JournalStyle.LEATHER_DEEP, 0.9), false, 3.0, true)
	draw_rect(_well_rect.grow(-5.0), Color(JournalStyle.GOLD, 0.55), false, 1.2, true)
	draw_rect(Rect2(_well_rect.position, Vector2(_well_rect.size.x, 14.0)), Color(0.0, 0.0, 0.0, 0.25))
	var inset := border + 8.0
	JournalOrnaments.draw_folder_corner(self, Vector2(inset, inset), Vector2(1.0, 1.0), 46.0, Color(JournalStyle.GOLD, 0.85))
	JournalOrnaments.draw_folder_corner(self, Vector2(size.x - inset, inset), Vector2(-1.0, 1.0), 46.0, Color(JournalStyle.GOLD, 0.85))
	JournalOrnaments.draw_folder_corner(self, Vector2(inset, size.y - inset), Vector2(1.0, -1.0), 46.0, Color(JournalStyle.GOLD, 0.85))
	JournalOrnaments.draw_folder_corner(self, Vector2(size.x - inset, size.y - inset), Vector2(-1.0, -1.0), 46.0, Color(JournalStyle.GOLD, 0.85))


func _rounded_outline(rect: Rect2, color: Color, width: float, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(int(ceilf(width)))
	style.set_corner_radius_all(int(maxf(radius, 0.0)))
	style.anti_aliasing = true
	draw_style_box(style, rect)
