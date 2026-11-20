class_name JournalPhotoStack
extends Control
## Fotografías y papeles prendidos con un clip en la esquina de la carpeta: dos hojas del legajo
## asoman por detrás y delante va una foto de la escena del crimen, la mansión Valdés, virada a sepia.
## Sobresale un poco por encima del borde de la carpeta, como un papel mal guardado.

const SCENE_PHOTO := preload("res://assets/ui/mansion_grabado.svg")

var _photo: JournalPhoto


func _init() -> void:
	custom_minimum_size = Vector2(196.0, 132.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo = JournalPhoto.new()
	_photo.tilt = -4.0
	_photo.clip_side = 0
	_photo.set_picture(SCENE_PHOTO, JournalPhoto.Mode.PORTRAIT)
	add_child(_photo)


func _ready() -> void:
	# El clip va por encima de la foto: lo dibuja un hijo propio, el último.
	var clip := Control.new()
	clip.name = "Clip"
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.draw.connect(func() -> void: JournalOrnaments.draw_paperclip(clip, Vector2(size.x * 0.62, -34.0), 22.0, -0.12))
	add_child(clip)
	resized.connect(_place_photo)
	_place_photo()


func get_photo() -> JournalPhoto:
	return _photo


func _place_photo() -> void:
	_photo.position = Vector2(26.0, -10.0)
	_photo.size = Vector2(size.x - 40.0, size.y - 6.0)
	queue_redraw()


func _draw() -> void:
	# Hojas del legajo, por detrás de la foto.
	_sheet(Rect2(Vector2(4.0, -20.0), Vector2(size.x - 34.0, size.y + 6.0)), -9.0, Color("e2d1a6"))
	_sheet(Rect2(Vector2(18.0, -16.0), Vector2(size.x - 24.0, size.y + 4.0)), 5.0, Color("ead9b2"))


func _sheet(rect: Rect2, degrees: float, color: Color) -> void:
	var center := rect.get_center()
	draw_set_transform(center, deg_to_rad(degrees), Vector2.ONE)
	var local := Rect2(-rect.size * 0.5, rect.size)
	draw_rect(Rect2(local.position + Vector2(3.0, 5.0), local.size), Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(local, color)
	draw_rect(local, Color(JournalStyle.PARCHMENT_EDGE, 0.8), false, 1.2, true)
	for row in 5:
		var y := local.position.y + 18.0 + row * 12.0
		draw_line(Vector2(local.position.x + 14.0, y), Vector2(local.end.x - 20.0 - (row % 2) * 24.0, y), Color(JournalStyle.INK, 0.25), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

