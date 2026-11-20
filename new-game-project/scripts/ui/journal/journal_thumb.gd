class_name JournalThumb
extends Control
## Miniatura de una fila del expediente: un recorte de retrato en un marquito oscuro, como una foto
## de carné, o un icono en tinta sobre el pergamino. No recibe el ratón.

const PHOTO_SHADER := preload("res://assets/shaders/sepia_photo.gdshader")

var _picture: TextureRect
var _icon_name := ""


func _init(thumb_size: float = JournalStyle.THUMB_SIZE) -> void:
	custom_minimum_size = Vector2(thumb_size, thumb_size)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.resized.connect(_on_picture_resized)
	add_child(_picture)


func _on_picture_resized() -> void:
	var material := _picture.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("draw_size", _picture.size)


## Retrato recortado, en sepia con fondo de estudio.
func set_portrait(texture: Texture2D) -> void:
	_icon_name = ""
	var material := ShaderMaterial.new()
	material.shader = PHOTO_SHADER
	material.set_shader_parameter("use_backdrop", true)
	material.set_shader_parameter("tone", 0.45)
	material.set_shader_parameter("vignette", 0.9)
	material.set_shader_parameter("grain", 0.0)
	_picture.material = material
	_picture.texture = texture
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.modulate = Color.WHITE
	_picture.offset_left = 3.0
	_picture.offset_top = 3.0
	_picture.offset_right = -3.0
	_picture.offset_bottom = -3.0
	_on_picture_resized()
	queue_redraw()


## Icono en tinta, sin marco de foto.
func set_icon(icon_name: String, color: Color = JournalStyle.INK) -> void:
	_icon_name = icon_name
	_picture.material = null
	_picture.texture = JournalStyle.icon(icon_name)
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.modulate = color
	var inset := custom_minimum_size.x * 0.1
	_picture.offset_left = inset
	_picture.offset_top = inset
	_picture.offset_right = -inset
	_picture.offset_bottom = -inset
	queue_redraw()


func get_texture() -> Texture2D:
	return _picture.texture


func get_icon_name() -> String:
	return _icon_name


func _draw() -> void:
	if not _icon_name.is_empty():
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, JournalStyle.FRAME)
	draw_rect(rect.grow(-1.5), Color(JournalStyle.GOLD_DARK, 0.9), false, 1.0, true)
