class_name JournalPhoto
extends Control
## Fotografía antigua sujeta con un clip: un marco de papel claro, la imagen virada a sepia con
## viñeta y grano, una sombra y el clip de latón en una esquina. Se inclina un poco, como una foto
## prendida a mano en la carpeta.
##
## Sirve para retratos (siluetas sobre fondo de estudio), fotos reales de la escena y emblemas
## (un icono grande cuando una prueba no tiene imagen propia). El pie de foto es opcional.

const PHOTO_SHADER := preload("res://assets/shaders/sepia_photo.gdshader")
const BORDER := 14.0
const CAPTION_HEIGHT := 40.0

enum Mode { PORTRAIT, PHOTO, EMBLEM }

## Inclinación en grados.
@export var tilt := 3.0:
	set(value):
		tilt = value
		rotation_degrees = value
## Dónde va el clip: 1 arriba a la derecha, -1 arriba a la izquierda, 0 sin clip.
@export var clip_side := 1

var _mode := Mode.EMBLEM
var _image: TextureRect
var _material: ShaderMaterial
var _overlay: Control
var _caption: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = PHOTO_SHADER
	_image = TextureRect.new()
	_image.name = "Image"
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	_caption = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.NOTE_SIZE - 2, JournalStyle.INK_SOFT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.clip_text = true
	_caption.hide()
	add_child(_caption)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _ready() -> void:
	rotation_degrees = tilt
	resized.connect(_on_resized)
	_on_resized()


## Muestra una imagen. Los retratos llevan fondo de estudio y conservan algo de color; las fotos de
## escena se viran del todo; los emblemas son un icono claro sobre el fondo oscuro de la foto.
func set_picture(texture: Texture2D, mode: Mode) -> void:
	_mode = mode
	_image.texture = texture
	match mode:
		Mode.PORTRAIT:
			_image.material = _material
			_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_image.modulate = Color.WHITE
			_material.set_shader_parameter("use_backdrop", true)
			_material.set_shader_parameter("tone", 0.32)
			_material.set_shader_parameter("vignette", 0.85)
			_material.set_shader_parameter("grain", 0.05)
		Mode.PHOTO:
			_image.material = _material
			_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_image.modulate = Color.WHITE
			_material.set_shader_parameter("use_backdrop", false)
			_material.set_shader_parameter("tone", 0.9)
			_material.set_shader_parameter("vignette", 0.75)
			_material.set_shader_parameter("grain", 0.06)
		Mode.EMBLEM:
			_image.material = null
			_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_image.modulate = Color(0.17, 0.11, 0.07, 0.85)
	_on_resized()


func set_caption(text: String) -> void:
	_caption.text = text
	_caption.visible = not text.is_empty()
	_on_resized()


func get_texture() -> Texture2D:
	return _image.texture


func get_mode() -> Mode:
	return _mode


func get_caption() -> String:
	return _caption.text if _caption.visible else ""


## Rectángulo de la imagen dentro del marco de papel.
func get_picture_rect() -> Rect2:
	var bottom := CAPTION_HEIGHT if _caption.visible else BORDER
	return Rect2(Vector2(BORDER, BORDER), Vector2(maxf(size.x - BORDER * 2.0, 0.0), maxf(size.y - BORDER - bottom, 0.0)))


func _on_resized() -> void:
	pivot_offset = size * 0.5
	var picture := get_picture_rect()
	if _mode == Mode.EMBLEM:
		var side := minf(picture.size.x, picture.size.y) * 0.5
		_image.position = picture.get_center() - Vector2(side, side) * 0.5
		_image.size = Vector2(side, side)
	else:
		_image.position = picture.position
		_image.size = picture.size
	_material.set_shader_parameter("draw_size", _image.size)
	_caption.position = Vector2(BORDER, picture.end.y + 2.0)
	_caption.size = Vector2(picture.size.x, CAPTION_HEIGHT - 6.0)
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	queue_redraw()
	_overlay.queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(rect.position + Vector2(5.0, 8.0), rect.size), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), Color(0.0, 0.0, 0.0, 0.25))
	draw_rect(rect, Color("efe3c4"))
	draw_rect(rect, Color(JournalStyle.PARCHMENT_EDGE, 0.8), false, 1.5, true)
	draw_rect(rect.grow(-4.0), Color(JournalStyle.PARCHMENT_STAIN, 0.6), false, 1.0, true)
	var picture := get_picture_rect()
	# Fondo de la foto, como un estudio iluminado desde el centro: lo cubre la imagen, salvo en los
	# emblemas.
	draw_rect(picture, Color("5e4630"))
	for ring in 6:
		var inset := picture.size.x * (0.05 + ring * 0.055)
		draw_rect(picture.grow(-inset), Color(0.78, 0.65, 0.46, 0.16))


## Encima de la imagen: el borde interior gastado y el clip.
func _draw_overlay() -> void:
	var picture := get_picture_rect()
	_overlay.draw_rect(picture, Color(0.12, 0.07, 0.04, 0.85), false, 1.5, true)
	if clip_side != 0:
		var x := size.x - 46.0 if clip_side > 0 else 46.0
		JournalOrnaments.draw_paperclip(_overlay, Vector2(x, -26.0), 24.0, 0.06 * clip_side)
