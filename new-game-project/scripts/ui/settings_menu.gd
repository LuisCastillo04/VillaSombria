class_name SettingsMenu
extends CategoryMenu
## Configuración por categorías, compartida por la pausa y el menú principal: Audio, Gráficos,
## Jugabilidad, Filtros y Accesibilidad. Cada control lee y escribe una preferencia real de `Settings`,
## que la valida, la aplica y la guarda al momento; si otra pantalla la cambia, el control se pone al día.
##
## Filtros muestra una tarjeta por filtro de `VisualFilters`: elegir una cambia `filtros/activo`, el
## mundo cambia de color en el acto detrás del menú (que sigue abierto para comparar) y sólo la tarjeta
## del filtro aplicado dice «ACTIVO».
##
## Los cambios de pantalla (pantalla completa, modo de ventana y resolución) se prueban y piden
## confirmación (`Settings.request_display_change`): si no se confirman, los controles vuelven a
## mostrar lo que hay. El interruptor de pantalla completa y el selector de modo leen la misma
## preferencia, así que nunca se contradicen.
##
## Para añadir una opción: descríbela en `SettingsSchema`, aplícala donde corresponda y crea su fila
## en la página de su categoría con `_add_switch_row` o `_add_selector`. Ver docs/CONFIGURACION.md.

## Volumen por canal de audio: el canal de `Settings` y cómo se presenta.
const VOLUME_ROWS: Array[Dictionary] = [
	{"bus": "Master", "label": "Volumen general", "icon": "altavoz"},
	{"bus": "Musica", "label": "Música", "icon": "nota"},
	{"bus": "Efectos", "label": "Efectos", "icon": "destellos"},
	{"bus": "Ambiente", "label": "Lluvia y ambiente", "icon": "lluvia"},
]
const MODE_KEY := "graficos/modo_ventana"
const RESOLUTION_KEY := "graficos/resolucion"
const RESOLUTION_DETAIL := "Tamaño de la ventana; la interfaz se escala sin deformarse."
## Nombres cortos de los modos en su selector, para que quepan junto al título; la explicación de
## debajo y la pregunta de confirmación usan los completos de `SettingsSchema`.
const MODE_LABELS := {"ventana": "Ventana", "sin_bordes": "Sin bordes", "pantalla_completa": "Pantalla completa", "exclusiva": "Completa exclusiva"}
const FILTERS_INTRO := "Activa filtros de pantalla que solo cambian los colores del juego."

var _sliders: Dictionary = {}
var _percentages: Dictionary = {}
var _fullscreen: CheckButton
var _vsync: CheckButton
## Interruptores y selectores de cada preferencia, por su clave de `Settings`.
var _switches: Dictionary = {}
var _selectors: Dictionary = {}
## Tarjeta de cada filtro, por su identificador de `VisualFilters`.
var _filter_cards: Dictionary = {}
## Mientras se pone al día con los ajustes, los controles no deben escribir nada.
var _syncing := false


func _ready() -> void:
	super._ready()
	Settings.changed.connect(_on_setting_changed)


## Al abrir se leen los valores vigentes, por si cambiaron desde la otra pantalla.
func open() -> void:
	refresh()
	super.open()


func refresh() -> void:
	_syncing = true
	for bus: String in _sliders:
		var value: float = Settings.volumes[bus]
		(_sliders[bus] as HSlider).set_value_no_signal(value)
		_show_percentage(bus, value)
	for key: String in _switches:
		(_switches[key] as CheckButton).set_pressed_no_signal(bool(Settings.get_value(key)))
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	for key: String in _selectors:
		if key != RESOLUTION_KEY:
			(_selectors[key] as OptionSelector).set_value_no_signal(String(Settings.get_value(key)))
	_refresh_resolution()
	var active := VisualFilters.current()
	for id: String in _filter_cards:
		(_filter_cards[id] as FilterCard).set_active(id == active)
	_syncing = false


func get_volume_slider(bus: String) -> HSlider:
	return _sliders[bus]


func get_volume_text(bus: String) -> String:
	return (_percentages[bus] as Label).text


func get_fullscreen_switch() -> CheckButton:
	return _fullscreen


func get_vsync_switch() -> CheckButton:
	return _vsync


## Interruptor de una preferencia de sí o no («jugabilidad/confirmaciones»).
func get_switch(key: String) -> CheckButton:
	if key == "graficos/vsync":
		return _vsync
	return _switches.get(key)


## Selector de una preferencia de lista («graficos/calidad_efectos»).
func get_selector(key: String) -> OptionSelector:
	return _selectors.get(key)


## Tarjeta de un filtro («noir», «sepia», «cold_night» u «original»).
func get_filter_card(id: String) -> FilterCard:
	return _filter_cards.get(id)


func _build_categories() -> void:
	_build_audio(add_category("Audio", "altavoz"))
	_build_graphics(add_category("Gráficos", "monitor"))
	_build_gameplay(add_category("Jugabilidad", "ajustes"))
	_build_filters(add_category("Filtros", "ajustes"))
	_build_accessibility(add_category("Accesibilidad", "persona"))
	refresh()


func _build_audio(page: VBoxContainer) -> void:
	page.add_theme_constant_override("separation", 18)
	for row: Dictionary in VOLUME_ROWS:
		page.add_child(_volume_row(row["bus"], row["label"], row["icon"]))


func _build_graphics(page: VBoxContainer) -> void:
	_fullscreen = _add_switch_row(page, "Pantalla completa", "Ocupa todo el monitor. Pide confirmación al cambiar.", _on_fullscreen_toggled)
	_vsync = _add_switch_row(page, "Sincronización vertical",
		"Evita cortes en la imagen. Desactivada por defecto.", Settings.set_vsync)
	_add_divider(page)
	var mode := _add_selector(page, MODE_KEY, "Modo de ventana", "Con bordes, sin bordes o pantalla completa (normal o exclusiva).", _on_mode_selected)
	var modes := DisplaySettings.available_modes()
	var mode_labels: Array[String] = []
	for value in modes:
		mode_labels.append(String(MODE_LABELS.get(value, SettingsSchema.label_of(value))))
	mode.set_options(modes, mode_labels)
	_add_selector(page, RESOLUTION_KEY, "Resolución de pantalla", RESOLUTION_DETAIL, _on_resolution_selected)
	_add_selector(page, "graficos/calidad_iluminacion", "Calidad de sombras e iluminación",
		"Sombras de las farolas y de la luz exterior, y su resplandor.")
	_add_selector(page, "graficos/calidad_efectos", "Efectos y partículas",
		"Cantidad de lluvia, detalle de la niebla y grano de película.")


func _build_gameplay(page: VBoxContainer) -> void:
	_add_selector(page, "jugabilidad/velocidad_texto", "Velocidad del texto", "Rapidez con la que aparecen los diálogos.")
	_add_switch_row(page, "Avance automático de diálogos",
		"Pasa de línea cuando ha dado tiempo a leerla. Nunca elige una respuesta.",
		Callable(), "jugabilidad/avance_automatico")
	_add_switch_row(page, "Confirmaciones",
		"Preguntar antes de acciones como dejar pasar una hora. Borrar o sobrescribir partidas pregunta siempre.",
		Callable(), "jugabilidad/confirmaciones")


## Una tarjeta por filtro, en el orden de `VisualFilters.IDS`. Sólo uno puede estar activo porque
## todas leen y escriben la misma preferencia.
func _build_filters(page: VBoxContainer) -> void:
	page.add_theme_constant_override("separation", 14)
	var intro := MenuStyle.make_label(FILTERS_INTRO, 21, MenuStyle.TEXT, CaseFileStyle.serif_italic())
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(intro)
	for id in VisualFilters.IDS:
		var card := FilterCard.new()
		card.setup(id, VisualFilters.label_of(id), VisualFilters.description_of(id))
		card.chosen.connect(_on_filter_chosen)
		page.add_child(card)
		_filter_cards[id] = card


## Elegir el filtro ya activo no cambia nada: `Settings` no escribe ni avisa si el valor se repite.
func _on_filter_chosen(id: String) -> void:
	if not _syncing:
		Settings.set_value(VisualFilters.SETTING_KEY, id)


func _build_accessibility(page: VBoxContainer) -> void:
	_add_selector(page, "accesibilidad/tamano_letra", "Tamaño de letra",
		"Agranda los textos de todas las pantallas y sus recuadros.")
	_add_switch_row(page, "Contraste aumentado",
		"Texto más nítido y un contorno de foco inconfundible.",
		Callable(), "accesibilidad/contraste_alto")
	_add_switch_row(page, "Subtítulos",
		"De voces y sonidos narrados. Las conversaciones se leen siempre.",
		Callable(), "accesibilidad/subtitulos")
	_add_switch_row(page, "Reducir movimiento",
		"Sin deslizamientos, latidos ni balanceos decorativos.",
		Callable(), "accesibilidad/movimiento_reducido")


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


## Interruptor con su explicación debajo. `apply` recibe el nuevo valor; sin él, el interruptor
## escribe directamente la preferencia `key`.
func _add_switch_row(page: VBoxContainer, label_text: String, detail: String, apply: Callable, key: String = "") -> CheckButton:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	var button := CheckButton.new()
	button.text = label_text
	MenuStyle.style_switch(button)
	button.toggled.connect(func(value: bool) -> void:
		if _syncing:
			return
		AudioManager.play("click")
		if apply.is_valid():
			apply.call(value)
		else:
			Settings.set_value(key, value))
	block.add_child(button)
	var explanation := MenuStyle.make_label(detail, 18, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(explanation)
	page.add_child(block)
	if not key.is_empty():
		_switches[key] = button
	return button


## Selector de una preferencia de lista, con los valores y los nombres de `SettingsSchema`. Sin
## `handler`, el valor elegido se escribe directamente en la preferencia.
func _add_selector(page: VBoxContainer, key: String, title: String, detail: String, handler: Callable = Callable()) -> OptionSelector:
	var selector := OptionSelector.new()
	selector.name = "Selector_" + SettingsSchema.name_of(key)
	selector.setup(title, detail)
	var values := SettingsSchema.options(key)
	if not values.is_empty():
		selector.set_options(values, _labels(values))
	if handler.is_valid():
		selector.value_changed.connect(handler)
	else:
		selector.value_changed.connect(_on_selector_changed.bind(key))
	page.add_child(selector)
	_selectors[key] = selector
	return selector


func _add_divider(page: VBoxContainer) -> void:
	var divider := GoldDivider.new()
	divider.custom_minimum_size = Vector2(0.0, 16.0)
	divider.color = Color(MenuStyle.GOLD, 0.45)
	page.add_child(divider)


func _on_selector_changed(value: String, key: String) -> void:
	if not _syncing:
		Settings.set_value(key, value)


## Otra pantalla (o la confirmación de un cambio de pantalla) cambió una preferencia.
func _on_setting_changed(_key: String, _value: Variant) -> void:
	refresh()


# --- Pantalla: se prueba, se confirma o se restaura ---

func _on_fullscreen_toggled(value: bool) -> void:
	var mode := "pantalla_completa" if value else "ventana"
	await _request_display(mode, Settings.get_value(RESOLUTION_KEY))


func _on_mode_selected(mode: String) -> void:
	if not _syncing:
		await _request_display(mode, Settings.get_value(RESOLUTION_KEY))


func _on_resolution_selected(value: String) -> void:
	if not _syncing:
		await _request_display(String(Settings.get_value(MODE_KEY)), SettingsSchema.to_size(value))


## Mientras se pregunta, el interruptor, el modo y la resolución muestran lo que se está probando,
## sin contradecirse; al contestar (o al restaurarse), todos vuelven a mostrar lo que hay de verdad.
func _request_display(mode: String, size: Vector2i) -> void:
	_syncing = true
	_fullscreen.set_pressed_no_signal(DisplaySettings.is_fullscreen_mode(mode))
	(_selectors[MODE_KEY] as OptionSelector).set_value_no_signal(mode)
	_syncing = false
	_refresh_resolution(mode, size)
	await Settings.request_display_change(mode, size)
	refresh()


## Resoluciones del modo vigente (o del que se está probando). En pantalla completa manda el monitor:
## el selector se desactiva y lo explica.
func _refresh_resolution(mode: String = "", trying: Vector2i = Vector2i.ZERO) -> void:
	var selector: OptionSelector = _selectors.get(RESOLUTION_KEY)
	if selector == null:
		return
	if mode.is_empty():
		mode = String(Settings.get_value(MODE_KEY))
	var sizes := DisplaySettings.resolutions_for(mode)
	var values: Array[String] = []
	var labels: Array[String] = []
	for size in sizes:
		values.append("%dx%d" % [size.x, size.y])
		labels.append("%d × %d" % [size.x, size.y])
	var was_syncing := _syncing
	_syncing = true
	selector.set_options(values, labels)
	var current := DisplaySettings.fit(trying if trying != Vector2i.ZERO else Settings.get_value(RESOLUTION_KEY), mode)
	selector.set_value_no_signal("%dx%d" % [current.x, current.y])
	var fullscreen := DisplaySettings.is_fullscreen_mode(mode)
	selector.set_disabled(fullscreen)
	var screen := DisplaySettings.screen_size()
	selector.set_detail("En pantalla completa se usa la del monitor (%d × %d)." % [screen.x, screen.y] if fullscreen else RESOLUTION_DETAIL)
	_syncing = was_syncing


static func _labels(values: Array[String]) -> Array[String]:
	var labels: Array[String] = []
	for value in values:
		labels.append(SettingsSchema.label_of(value))
	return labels
