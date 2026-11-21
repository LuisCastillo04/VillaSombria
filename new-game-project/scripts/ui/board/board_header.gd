class_name BoardHeader
extends HBoxContainer
## Encabezado del tablero, sobre la banda de pergamino: la fotografía del inspector prendida con un
## clip, el rótulo «TABLERO DE DEDUCCIÓN» en burdeos, «[B] Cerrar» (que también se pulsa con el ratón)
## y la ayuda «Pulsa un sospechoso para anotar tu hipótesis». El sello va aparte: lo coloca el marco.
##
## La tecla sale del InputMap cada vez que se abre el tablero. Si no cabe todo (por ejemplo, con la
## letra grande de Accesibilidad), la ayuda pasa a dos líneas, sólo se recorta si ni así cabe, y el
## rótulo reduce la letra hasta `BoardStyle.TITLE_MIN_SIZE`.

signal close_pressed

const TITLE := "TABLERO DE DEDUCCIÓN"
const HELP := "Pulsa un sospechoso para anotar tu hipótesis"
const PHOTO_SIZE := Vector2(116.0, 94.0)
const DETECTIVE := "res://assets/siluetas/detective.svg"
## Ancho que se reserva para la ayuda antes de reducir el rótulo.
const HELP_MIN_WIDTH := 260.0

var _photo_holder: Control
var _photo: JournalPhoto
var _title: Label
var _close: Button
var _help: Label


func _init() -> void:
	add_theme_constant_override("separation", 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_photo_holder = Control.new()
	_photo_holder.name = "Photo"
	_photo_holder.custom_minimum_size = Vector2(PHOTO_SIZE.x + 14.0, PHOTO_SIZE.y)
	_photo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo = JournalPhoto.new()
	_photo.tilt = -5.0
	_photo.clip_side = -1
	_photo.set_picture(JournalInfo.portrait(DETECTIVE, JournalInfo.PORTRAIT_BUST), JournalPhoto.Mode.PORTRAIT)
	_photo.position = Vector2(2.0, -12.0)
	_photo.size = PHOTO_SIZE
	_photo_holder.add_child(_photo)
	add_child(_photo_holder)
	_title = BoardStyle.make_label(TITLE, BoardStyle.title_font(), BoardStyle.TITLE_SIZE, BoardStyle.BURGUNDY_INK)
	_title.name = "Title"
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.add_theme_color_override("font_shadow_color", Color(1.0, 0.97, 0.88, 0.45))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_title)
	add_child(_dot())
	_close = Button.new()
	_close.name = "Close"
	_close.focus_mode = Control.FOCUS_NONE
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	BoardStyle.apply_text_button(_close, BoardStyle.body_font(), BoardStyle.HEADER_SIZE)
	_close.pressed.connect(func() -> void: close_pressed.emit())
	add_child(_close)
	add_child(_dot())
	_help = BoardStyle.make_label(HELP, BoardStyle.italic_font(), BoardStyle.HELP_SIZE, BoardStyle.INK_SOFT)
	_help.name = "Help"
	_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.max_lines_visible = 2
	_help.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_help)
	refresh_keys()
	resized.connect(_fit_title)


## Vuelve a leer la tecla del InputMap, por si se ha reasignado.
func refresh_keys() -> void:
	var key := BoardInfo.key_name("open_board")
	_close.text = "[%s] Cerrar" % key if not key.is_empty() else "Cerrar"
	_fit_title()


func get_title() -> String:
	return _title.text


func get_title_font_size() -> int:
	return _title.get_theme_font_size("font_size")


func get_close_button() -> Button:
	return _close


func get_close_text() -> String:
	return _close.text


func get_help() -> Label:
	return _help


func get_photo() -> JournalPhoto:
	return _photo


## Si el rótulo no cabe con la ayuda al lado, la letra se reduce hasta `TITLE_MIN_SIZE`.
func _fit_title() -> void:
	var separation := get_theme_constant("separation")
	var fixed := _photo_holder.custom_minimum_size.x + _close.get_combined_minimum_size().x + 2.0 * 14.0 + 5.0 * separation
	var available := size.x - fixed - HELP_MIN_WIDTH
	var font := BoardStyle.title_font()
	var font_size := BoardStyle.TITLE_SIZE
	while font_size > BoardStyle.TITLE_MIN_SIZE and font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 2
	_title.add_theme_font_size_override("font_size", font_size)


## Rombo de tinta entre las partes del encabezado.
func _dot() -> Control:
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(14.0, 14.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.draw.connect(func() -> void: HudOrnaments.draw_diamond(dot, dot.size * 0.5, 4.0, Color(BoardStyle.INK, 0.75)))
	return dot
