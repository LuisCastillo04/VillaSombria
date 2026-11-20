class_name BoardFrame
extends Control
## Marco de cuero del tablero de deducción. Pinta el cuero marrón con su pespunte y sus esquinas de
## latón, la banda de pergamino del encabezado y el hueco oscuro donde descansan los sospechosos, el
## corcho y la columna de comparación; y coloca encima cada pieza.
##
## Sólo reparte el espacio: las piezas (fila de sospechosos, corcho, comparación y panel de
## hipótesis) las crea quien usa el marco y se las da con `set_parts()`. Todo se recalcula al cambiar
## el tamaño del marco, así sirve para cualquier proporción de pantalla.

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const LEATHER_SHADER := preload("res://assets/shaders/leather.gdshader")
const RADIUS := 14.0
const WELL_INSET := 14.0
## Margen mínimo entre el panel de hipótesis y el borde del corcho.
const EDITOR_MARGIN := Vector2(24.0, 18.0)

var header: BoardHeader
var seal: JournalSeal
var suspects: Control
var canvas: Control
var side: Control
var editor: Control

var _leather: ColorRect
var _well: ColorRect
var _band: ColorRect
var _band_rect := Rect2()
var _well_rect := Rect2()
var _row_rect := Rect2()
var _canvas_rect := Rect2()
var _side_rect := Rect2()
var _editor_rect := Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leather = _shader_rect("Leather", LEATHER_SHADER)
	_well = _shader_rect("Well", LEATHER_SHADER)
	_band = _shader_rect("Band", PARCHMENT_SHADER)
	var leather_material := _leather.material as ShaderMaterial
	leather_material.set_shader_parameter("base_color", BoardStyle.LEATHER)
	leather_material.set_shader_parameter("dark_color", BoardStyle.LEATHER_DARK)
	leather_material.set_shader_parameter("sheen_color", BoardStyle.LEATHER_SHEEN)
	leather_material.set_shader_parameter("corner_radius", RADIUS)
	leather_material.set_shader_parameter("seed", 2.7)
	var well_material := _well.material as ShaderMaterial
	well_material.set_shader_parameter("base_color", BoardStyle.LEATHER_DARK.lerp(BoardStyle.LEATHER, 0.35))
	well_material.set_shader_parameter("dark_color", Color("0f0806"))
	well_material.set_shader_parameter("sheen_color", BoardStyle.LEATHER)
	well_material.set_shader_parameter("corner_radius", 6.0)
	well_material.set_shader_parameter("edge_width", 40.0)
	well_material.set_shader_parameter("seed", 5.3)
	var band_material := _band.material as ShaderMaterial
	band_material.set_shader_parameter("base_color", BoardStyle.PARCHMENT)
	band_material.set_shader_parameter("stain_color", BoardStyle.PARCHMENT_STAIN)
	band_material.set_shader_parameter("edge_color", BoardStyle.PARCHMENT_EDGE)
	band_material.set_shader_parameter("corner_radius", 8.0)
	band_material.set_shader_parameter("edge_width", 36.0)
	band_material.set_shader_parameter("seed", 8.2)
	header = BoardHeader.new()
	header.name = "Header"
	add_child(header)
	seal = JournalSeal.new()
	seal.name = "Seal"
	seal.waves_width = 130.0
	add_child(seal)
	resized.connect(relayout)


## Da al marco las piezas que debe colocar. Las que no tengan padre pasan a ser hijas del marco.
func set_parts(suspects_part: Control, canvas_part: Control, side_part: Control, editor_part: Control = null) -> void:
	suspects = suspects_part
	canvas = canvas_part
	side = side_part
	editor = editor_part
	for part: Control in [suspects, canvas, side, editor]:
		if part != null and part.get_parent() != self:
			if part.get_parent() != null:
				part.get_parent().remove_child(part)
			add_child(part)
	if editor != null:
		move_child(editor, -1)
	relayout()


func get_band_rect() -> Rect2:
	return _band_rect


func get_row_rect() -> Rect2:
	return _row_rect


func get_canvas_rect() -> Rect2:
	return _canvas_rect


func get_side_rect() -> Rect2:
	return _side_rect


func get_editor_rect() -> Rect2:
	return _editor_rect


func relayout() -> void:
	var width := size.x
	var height := size.y
	var border := BoardStyle.FRAME_BORDER
	var inset := BoardStyle.CONTENT_INSET
	_band_rect = Rect2(Vector2(border, border), Vector2(width - border * 2.0, BoardStyle.HEADER_HEIGHT))
	var seal_size := BoardStyle.SEAL_SIZE
	seal.size = seal_size
	seal.position = Vector2(width - border - seal_size.x - 8.0, _band_rect.get_center().y - seal_size.y * 0.5 + 2.0)
	header.position = Vector2(inset, border + 6.0)
	header.size = Vector2(maxf(seal.position.x + 40.0 - inset, 200.0), BoardStyle.HEADER_HEIGHT - 12.0)
	_well_rect = Rect2(Vector2(border + WELL_INSET, _band_rect.end.y + 8.0), Vector2.ZERO)
	_well_rect.size = Vector2(width - _well_rect.position.x * 2.0, height - _well_rect.position.y - border - WELL_INSET)
	var content := _well_rect.grow(-12.0)
	_row_rect = Rect2(content.position + Vector2(0.0, BoardStyle.ROW_TOP_GAP - 12.0), Vector2(content.size.x, BoardStyle.ROW_HEIGHT))
	var body_top := _row_rect.end.y + BoardStyle.BODY_TOP_GAP
	var body := Rect2(Vector2(content.position.x, body_top), Vector2(content.size.x, content.end.y - body_top))
	var side_width := clampf(body.size.x * BoardStyle.SIDE_RATIO, BoardStyle.SIDE_MIN_WIDTH, BoardStyle.SIDE_MAX_WIDTH)
	_canvas_rect = Rect2(body.position, Vector2(maxf(body.size.x - side_width - BoardStyle.BODY_GAP, 0.0), body.size.y))
	_side_rect = Rect2(Vector2(_canvas_rect.end.x + BoardStyle.BODY_GAP, body.position.y), Vector2(side_width, body.size.y))
	var editor_size := BoardStyle.EDITOR_SIZE.min(_canvas_rect.size - EDITOR_MARGIN * 2.0).max(Vector2.ZERO)
	_editor_rect = Rect2(_canvas_rect.get_center() - editor_size * 0.5, editor_size)
	_place(suspects, _row_rect)
	_place(canvas, _canvas_rect)
	_place(side, _side_rect)
	_place(editor, _editor_rect)
	_fit_rect(_leather, Rect2(Vector2.ZERO, size))
	_fit_rect(_well, _well_rect)
	_fit_rect(_band, _band_rect)
	queue_redraw()


static func _place(part: Control, rect: Rect2) -> void:
	if part == null:
		return
	part.position = rect.position
	part.size = rect.size


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
	var border := BoardStyle.FRAME_BORDER
	# Contorno: filete dorado por fuera, pespunte y otro filete por dentro, como la carpeta.
	_rounded_outline(rect.grow(-1.0), Color(BoardStyle.GOLD_DARK, 0.9), 2.0, RADIUS)
	_rounded_outline(rect.grow(-4.0), Color(BoardStyle.GOLD, 0.75), 1.2, RADIUS - 3.0)
	JournalOrnaments.draw_stitches(self, rect.grow(-8.0), Color(BoardStyle.GOLD_LIGHT, 0.32))
	# Banda del encabezado: borde oscuro, filete dorado y la sombra que deja sobre el cuero.
	draw_rect(_band_rect, Color(BoardStyle.FRAME, 0.85), false, 2.0, true)
	draw_rect(_band_rect.grow(-6.0), Color(BoardStyle.GOLD_DARK, 0.6), false, 1.0, true)
	draw_rect(Rect2(Vector2(_band_rect.position.x, _band_rect.end.y), Vector2(_band_rect.size.x, 9.0)), Color(0.0, 0.0, 0.0, 0.3))
	# Hueco hundido, con un filete dorado y la sombra de la banda.
	draw_rect(_well_rect.grow(2.0), Color(BoardStyle.LEATHER_DARK, 0.9), false, 3.0, true)
	draw_rect(_well_rect.grow(-5.0), Color(BoardStyle.GOLD, 0.5), false, 1.2, true)
	draw_rect(Rect2(_well_rect.position, Vector2(_well_rect.size.x, 12.0)), Color(0.0, 0.0, 0.0, 0.25))
	# Bajo la fila de sospechosos, un filete que la separa del cuerpo.
	var rule_y := _row_rect.end.y + BoardStyle.BODY_TOP_GAP * 0.5
	var faded := Color(BoardStyle.GOLD, 0.0)
	var gold := Color(BoardStyle.GOLD, 0.45)
	draw_polyline_colors(PackedVector2Array([Vector2(_row_rect.position.x, rule_y), Vector2(_row_rect.position.x + 120.0, rule_y), Vector2(_row_rect.end.x - 120.0, rule_y), Vector2(_row_rect.end.x, rule_y)]), PackedColorArray([faded, gold, gold, faded]), 1.0, true)
	var inset := border + 8.0
	var corner_color := Color(BoardStyle.GOLD, 0.85)
	JournalOrnaments.draw_folder_corner(self, Vector2(inset, inset), Vector2(1.0, 1.0), 46.0, corner_color)
	JournalOrnaments.draw_folder_corner(self, Vector2(size.x - inset, inset), Vector2(-1.0, 1.0), 46.0, corner_color)
	JournalOrnaments.draw_folder_corner(self, Vector2(inset, size.y - inset), Vector2(1.0, -1.0), 46.0, corner_color)
	JournalOrnaments.draw_folder_corner(self, Vector2(size.x - inset, size.y - inset), Vector2(-1.0, -1.0), 46.0, corner_color)


func _rounded_outline(rect: Rect2, color: Color, width: float, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(int(ceilf(width)))
	style.set_corner_radius_all(int(maxf(radius, 0.0)))
	style.anti_aliasing = true
	draw_style_box(style, rect)
