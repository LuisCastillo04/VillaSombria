class_name DialogueText
extends RichTextLabel
## Texto de una intervención. Lo escribe letra a letra, con el sonido de la máquina de escribir, y
## avisa cuando el jugador ya lo puede leer entero.
##
## No conoce `DialogueManager`: la interfaz le da el texto y decide qué hacer después. Así el mismo
## componente sirve para cualquier personaje, escena o narración.

signal completed

## Letras por segundo del efecto de escritura.
@export var characters_per_second := 48.0
## Cada cuántas letras suena una tecla.
@export var sound_every := 3

var _progress := 0.0
var _typing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	scroll_active = false
	bbcode_enabled = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_process(false)


func _process(delta: float) -> void:
	if not _typing:
		set_process(false)
		return
	var before := visible_characters
	_progress += delta * characters_per_second
	var shown := mini(int(_progress), get_total_character_count())
	if sound_every > 0 and shown / sound_every > before / sound_every:
		AudioManager.play("tecla")
	visible_characters = shown
	if shown >= get_total_character_count():
		complete()


## Empieza a escribir una intervención desde la primera letra.
func show_line(line: String) -> void:
	text = line
	visible_characters = 0
	_progress = 0.0
	_typing = true
	set_process(true)


## Muestra de golpe lo que falta por escribir.
func complete() -> void:
	if not _typing:
		return
	_typing = false
	visible_characters = -1
	set_process(false)
	completed.emit()


## Deja de escribir sin mostrar el resto (al pasar a las respuestas o al cerrar).
func stop() -> void:
	_typing = false
	set_process(false)


func clear_line() -> void:
	stop()
	text = ""


func is_typing() -> bool:
	return _typing


## Si el texto actual ya se ve entero.
func is_complete() -> bool:
	return not _typing and visible_characters == -1
