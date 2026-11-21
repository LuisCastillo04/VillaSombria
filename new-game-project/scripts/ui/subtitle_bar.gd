class_name SubtitleBar
extends CanvasLayer
## Subtítulos opcionales: el texto de una voz o de un sonido narrado, centrado sobre la barra de
## controles, con el nombre de quien habla.
##
## Son lo que el jugador puede ocultar en Configuración (`accesibilidad/subtitulos`). El texto de
## las conversaciones no pasa por aquí: está escrito en su ventana, es obligatorio para jugar y se
## muestra siempre.
##
## Hoy el juego no tiene voces, así que nada pide subtítulos todavía. Cuando las tenga, quien
## reproduzca una voz (por ejemplo, un comentario del detective al entrar en un lugar) emitirá
## `EventBus.subtitle_requested(personaje, texto, segundos)` y esta barra lo mostrará si el jugador
## los quiere. Al desactivarlos, lo que hubiera en pantalla desaparece en el acto.

const LAYER := 5
## Ancho máximo del texto y distancia al pie de la pantalla, en el lienzo de 1920 × 1080: queda
## por encima de la barra de controles del HUD.
const MAX_WIDTH := 1240.0
const BOTTOM := 140.0
const TEXT_SIZE := 30
const NAME_SIZE := 22
## Sin duración indicada, el subtítulo dura lo que se tarda en leerlo, entre estos límites.
const READING_SPEED := 15.0
const MIN_SECONDS := 2.0
const MAX_SECONDS := 9.0

var _root: Control
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _remaining := 0.0


func _ready() -> void:
	layer = LAYER
	_build()
	_panel.hide()
	set_process(false)
	EventBus.subtitle_requested.connect(show_subtitle)
	Settings.changed.connect(_on_settings_changed)


## Muestra un subtítulo si el jugador los tiene activados. `speaker_id` es un personaje de
## `characters.json` (vacío para un sonido sin hablante) y `seconds`, cuánto dura (0: lo que se
## tarda en leerlo). Devuelve si se muestra.
func show_subtitle(speaker_id: String, text: String, seconds: float = 0.0) -> bool:
	if not UiAccessibility.subtitles_enabled() or text.strip_edges().is_empty():
		return false
	var speaker_name := GameData.get_character_name(speaker_id) if not speaker_id.is_empty() else ""
	_speaker.text = speaker_name
	_speaker.visible = not speaker_name.is_empty()
	_text.text = text
	_remaining = seconds if seconds > 0.0 else clampf(float(text.length()) / READING_SPEED, MIN_SECONDS, MAX_SECONDS)
	_layout()
	_panel.show()
	set_process(true)
	return true


func clear() -> void:
	_remaining = 0.0
	_panel.hide()
	set_process(false)


func is_showing() -> bool:
	return _panel.visible


func get_text() -> String:
	return _text.text if _panel.visible else ""


func get_speaker_text() -> String:
	return _speaker.text if _panel.visible and _speaker.visible else ""


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		clear()


func _on_settings_changed(key: String, value: Variant) -> void:
	if key == "accesibilidad/subtitulos" and not bool(value):
		clear()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.resized.connect(_layout)
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "Subtitle"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := CaseFileStyle.box(Color(0.03, 0.03, 0.05, 0.78), Color(MenuStyle.GOLD, 0.45), 1, 6, 0.0)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_speaker = MenuStyle.make_label("", NAME_SIZE, MenuStyle.GOLD, CaseFileStyle.serif_bold())
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_speaker)
	_text = MenuStyle.make_label("", TEXT_SIZE, MenuStyle.TEXT, CaseFileStyle.serif())
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)


## Centrado abajo, con el ancho del texto sin pasar del máximo.
func _layout() -> void:
	if _root == null or _text == null:
		return
	var view := _root.size
	var font := _text.get_theme_font("font")
	var natural := font.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	var width := minf(maxf(natural, 200.0), minf(MAX_WIDTH, view.x - 120.0))
	_text.custom_minimum_size.x = width
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_panel.position = Vector2((view.x - panel_size.x) * 0.5, view.y - BOTTOM - panel_size.y)
