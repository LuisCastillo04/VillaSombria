class_name DialogueText
extends RichTextLabel
## Texto de una intervención. Lo escribe letra a letra, con el sonido de la máquina de escribir, y
## avisa cuando el jugador ya lo puede leer entero.
##
## Si no cabe en las líneas de la ventana, lo reparte en páginas sin tocar una palabra: cada página
## empieza justo donde la anterior partió la línea, así que se lee todo y nada se repite. Las
## líneas se calculan con la maquetación real de la etiqueta y del texto completo
## (`VC_CHARS_AFTER_SHAPING`), de modo que una palabra nunca salta de renglón mientras se escribe.
## Si la ventana cambia de ancho, el texto se vuelve a repartir sin perder lo leído.
##
## No conoce `DialogueManager`: la interfaz le da el texto y decide qué hacer al terminar.

signal completed

## Letras por segundo del efecto de escritura. Con 0, cada página aparece de golpe; si se pone a 0
## mientras se escribe, lo que falta aparece en el acto.
@export var characters_per_second := DialogueStyle.CHARACTERS_PER_SECOND:
	set(value):
		characters_per_second = maxf(value, 0.0)
		if characters_per_second <= 0.0 and _typing:
			complete()
## Cada cuántas letras suena una tecla.
@export var sound_every := 3
## Líneas que caben en la ventana; un texto más largo se reparte en páginas.
@export var max_lines := DialogueStyle.TEXT_LINES
## Pausas breves tras un punto o una coma, para que la lectura respire.
@export var sentence_pause := DialogueStyle.SENTENCE_PAUSE
@export var clause_pause := DialogueStyle.CLAUSE_PAUSE

var _full := ""
var _pages: PackedStringArray = []
## Posición en el texto completo donde empieza cada página.
var _starts: PackedInt32Array = []
var _page := 0
var _progress := 0.0
var _hold := 0.0
var _typing := false
var _narration := false
var _layout_width := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	scroll_active = false
	bbcode_enabled = false
	fit_content = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_constant_override("line_separation", DialogueStyle.LINE_SPACING)
	add_theme_font_size_override("normal_font_size", DialogueStyle.TEXT_SIZE)
	_apply_voice()
	resized.connect(_on_resized)
	set_process(false)


func _process(delta: float) -> void:
	if not _typing:
		set_process(false)
		return
	if _hold > 0.0:
		_hold -= delta
		if _hold > 0.0:
			return
		delta = -_hold
		_hold = 0.0
	var total := get_total_character_count()
	var before := maxi(visible_characters, 0)
	_progress += delta * characters_per_second
	var shown := mini(int(_progress), total)
	# Tras un punto o una coma se respira un instante; se muestra hasta ese signo, sin saltar nada.
	for index in range(before, shown):
		var pause := _pause_after(index)
		if pause > 0.0 and index + 1 < total:
			shown = index + 1
			_progress = float(shown)
			_hold = pause
			break
	if sound_every > 0 and floori(shown / float(sound_every)) > floori(before / float(sound_every)):
		AudioManager.play("tecla")
	visible_characters = shown
	if shown >= total:
		complete()


## Empieza a escribir una intervención. `narration` la pone en la letra de la narración; `delay`
## espera antes de la primera letra (por ejemplo, mientras la ventana aparece).
func show_line(line: String, narration: bool = false, delay: float = 0.0) -> void:
	_full = line
	_narration = narration
	_apply_voice()
	_paginate()
	_show_page(0, delay)


## Muestra de golpe lo que falta de la página actual.
func complete() -> void:
	if not _typing:
		return
	_typing = false
	_hold = 0.0
	visible_characters = -1
	set_process(false)
	completed.emit()


## Si después de la página actual queda otra de la misma intervención.
func has_next_page() -> bool:
	return _page + 1 < _pages.size()


## Pasa a la página siguiente y la empieza a escribir.
func next_page() -> void:
	if has_next_page():
		_show_page(_page + 1, 0.0)


## Deja de escribir sin mostrar el resto (al pasar a las respuestas o al cerrar).
func stop() -> void:
	_typing = false
	_hold = 0.0
	set_process(false)


func clear_line() -> void:
	stop()
	_full = ""
	_pages = PackedStringArray()
	_starts = PackedInt32Array()
	_page = 0
	text = ""


func is_typing() -> bool:
	return _typing


## Letras de la página actual.
func get_page_length() -> int:
	return get_total_character_count()


## Si la página actual ya se ve entera.
func is_complete() -> bool:
	return not _typing and visible_characters == -1


func get_full_text() -> String:
	return _full


func get_page_count() -> int:
	return _pages.size()


func get_page_index() -> int:
	return _page


## Texto de cada página, en orden.
func get_pages() -> PackedStringArray:
	return _pages.duplicate()


func is_narration() -> bool:
	return _narration


## Alto que ocupan `lines` líneas con la letra de los personajes: la ventana se mide con él.
func get_area_height(lines: int = -1) -> float:
	var count: int = max_lines if lines < 0 else lines
	var font := DialogueStyle.speech_font()
	var line_height: float = font.get_height(DialogueStyle.TEXT_SIZE) + DialogueStyle.LINE_SPACING
	return line_height * count


func _apply_voice() -> void:
	add_theme_font_override("normal_font", DialogueStyle.narration_font() if _narration else DialogueStyle.speech_font())
	add_theme_color_override("default_color", DialogueStyle.INK_SOFT if _narration else DialogueStyle.INK)


func _show_page(index: int, delay: float) -> void:
	_page = index
	text = _pages[index] if index < _pages.size() else ""
	visible_characters = 0
	_progress = 0.0
	_hold = delay
	_typing = true
	set_process(true)
	if characters_per_second <= 0.0 or get_total_character_count() == 0:
		complete()


## Reparte el texto completo en páginas de `max_lines` líneas, cortando donde la etiqueta parte las
## líneas con su ancho actual. Sin ancho todavía, se queda en una página y se reparte al tenerlo.
func _paginate() -> void:
	_pages = PackedStringArray()
	_starts = PackedInt32Array()
	text = _full
	visible_characters = -1
	_layout_width = size.x
	var lines := get_line_count()
	if max_lines <= 0 or lines <= max_lines or size.x < 1.0:
		_pages.append(_full)
		_starts.append(0)
		return
	var start := 0
	var line := max_lines
	while line < lines:
		var next := get_line_range(line).x
		_pages.append(_full.substr(start, next - start).strip_edges())
		_starts.append(start)
		start = next
		line += max_lines
	_pages.append(_full.substr(start).strip_edges())
	_starts.append(start)


## Con otro ancho las líneas se parten en otro sitio: se reparte de nuevo y se sigue por la página
## que contiene el principio de la que se estaba leyendo.
func _on_resized() -> void:
	if _full.is_empty() or is_equal_approx(size.x, _layout_width):
		return
	var offset: int = _starts[_page] if _page < _starts.size() else 0
	var was_typing := _typing
	_paginate()
	var index := 0
	for candidate in _starts.size():
		if _starts[candidate] <= offset:
			index = candidate
	if was_typing:
		_show_page(index, 0.0)
	else:
		_page = index
		text = _pages[index]
		visible_characters = -1


## Pausa tras el signo de `index`, sólo si cierra una frase o una cláusula (le sigue un espacio):
## así no se detiene en «22:15» ni en los puntos suspensivos intermedios.
func _pause_after(index: int) -> float:
	if index < 0 or index >= text.length():
		return 0.0
	var next := text[index + 1] if index + 1 < text.length() else " "
	if next != " " and next != "\n":
		return 0.0
	var character := text[index]
	if character in ".!?…":
		return sentence_pause
	if character in ",;:":
		return clause_pause
	return 0.0
