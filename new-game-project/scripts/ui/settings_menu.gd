class_name SettingsMenu
extends CategoryMenu
## Configuración por categorías, compartida por la pausa y el menú principal. Audio y Gráficos
## usan los ajustes reales del autoload `Settings`, que los aplica y los guarda al momento.
## Lo que todavía no existe se muestra desactivado con «Próximamente» y sin conexión alguna.
##
## Para añadir una opción: guárdala y aplícala en `Settings` (scripts/autoload/settings.gd), crea
## su fila en la página que corresponda (`_add_switch_row` u otra) y quítala de `PLANNED_*`.

## Volumen por canal de audio: el canal de `Settings` y cómo se presenta.
const VOLUME_ROWS: Array[Dictionary] = [
	{"bus": "Master", "label": "Volumen general", "icon": "altavoz"},
	{"bus": "Musica", "label": "Música", "icon": "nota"},
	{"bus": "Efectos", "label": "Efectos", "icon": "destellos"},
	{"bus": "Ambiente", "label": "Lluvia y ambiente", "icon": "lluvia"},
]
## Opciones gráficas previstas que aún no existen.
const PLANNED_GRAPHICS: Array[Dictionary] = [
	{"label": "Resolución de pantalla", "detail": "Tamaño de la ventana y escalado"},
	{"label": "Modo de ventana", "detail": "Ventana, ventana sin bordes o pantalla completa"},
	{"label": "Calidad de sombras e iluminación", "detail": "Detalle de las luces de las farolas"},
	{"label": "Efectos y partículas", "detail": "Intensidad del postproceso y de la lluvia"},
]
## Opciones de jugabilidad previstas que aún no existen.
const PLANNED_GAMEPLAY: Array[Dictionary] = [
	{"label": "Velocidad del texto", "detail": "Rapidez con la que aparecen los diálogos"},
	{"label": "Avance automático de diálogos", "detail": "Pasar de línea sin pulsar ninguna tecla"},
	{"label": "Confirmaciones", "detail": "Preguntar antes de acciones como dejar pasar una hora"},
	{"label": "Accesibilidad", "detail": "Tamaño de letra, contraste y subtítulos"},
]

var _sliders: Dictionary = {}
var _percentages: Dictionary = {}
var _fullscreen: CheckButton
var _vsync: CheckButton


## Al abrir se leen los valores vigentes, por si cambiaron desde la otra pantalla.
func open() -> void:
	refresh()
	super.open()


func refresh() -> void:
	for bus: String in _sliders:
		var value: float = Settings.volumes[bus]
		(_sliders[bus] as HSlider).set_value_no_signal(value)
		_show_percentage(bus, value)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_vsync.set_pressed_no_signal(Settings.vsync)


func get_volume_slider(bus: String) -> HSlider:
	return _sliders[bus]


func get_volume_text(bus: String) -> String:
	return (_percentages[bus] as Label).text


func get_fullscreen_switch() -> CheckButton:
	return _fullscreen


func get_vsync_switch() -> CheckButton:
	return _vsync


func _build_categories() -> void:
	_build_audio(add_category("Audio", "altavoz"))
	_build_graphics(add_category("Gráficos", "monitor"))
	_build_gameplay(add_category("Jugabilidad", "ajustes"))
	refresh()


func _build_audio(page: VBoxContainer) -> void:
	page.add_theme_constant_override("separation", 18)
	for row: Dictionary in VOLUME_ROWS:
		page.add_child(_volume_row(row["bus"], row["label"], row["icon"]))


func _build_graphics(page: VBoxContainer) -> void:
	_fullscreen = _add_switch_row(page, "Pantalla completa", "Ocupa todo el monitor.", Settings.set_fullscreen)
	_vsync = _add_switch_row(page, "Sincronización vertical",
		"Desactivada por defecto para evitar caídas de fotogramas.",
		Settings.set_vsync)
	add_planned_section(page, PLANNED_GRAPHICS)


func _build_gameplay(page: VBoxContainer) -> void:
	var note := MenuStyle.make_label("Estas opciones están en preparación y todavía no se pueden cambiar.", 20, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)
	for planned: Dictionary in PLANNED_GAMEPLAY:
		page.add_child(planned_row(planned))


## Icono, nombre, barra de volumen y porcentaje del canal.
func _volume_row(bus: String, label_text: String, icon_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.add_child(MenuStyle.make_icon(icon_name, 30.0))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	column.add_child(MenuStyle.make_label(label_text, 22, MenuStyle.TEXT, CaseFileStyle.serif_bold()))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	var slider := HSlider.new()
	slider.name = "Volumen%s" % bus
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.style_slider(slider)
	slider.value_changed.connect(_on_volume_changed.bind(bus))
	line.add_child(slider)
	var percentage := MenuStyle.make_label("", 21, MenuStyle.TEXT_SECONDARY)
	percentage.custom_minimum_size.x = 64.0
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(percentage)
	column.add_child(line)
	row.add_child(column)
	_sliders[bus] = slider
	_percentages[bus] = percentage
	return row


func _on_volume_changed(value: float, bus: String) -> void:
	Settings.set_volume(bus, value)
	_show_percentage(bus, value)


func _show_percentage(bus: String, value: float) -> void:
	(_percentages[bus] as Label).text = "%d%%" % roundi(value * 100.0)


## Interruptor con su explicación debajo. `apply` recibe el nuevo valor.
func _add_switch_row(page: VBoxContainer, label_text: String, detail: String, apply: Callable) -> CheckButton:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	var button := CheckButton.new()
	button.text = label_text
	MenuStyle.style_switch(button)
	button.toggled.connect(func(value: bool) -> void:
		AudioManager.play("click")
		apply.call(value))
	block.add_child(button)
	var explanation := MenuStyle.make_label(detail, 18, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(explanation)
	page.add_child(block)
	return button

