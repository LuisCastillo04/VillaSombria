class_name JournalUi
extends CanvasLayer
## Expediente del detective: objetivos, pistas, testimonios, sospechosos y deducciones, en una carpeta
## de cuero con páginas de pergamino.
##
## Este nodo sólo coordina: abre y cierra la carpeta (con un fundido breve), cambia de sección,
## atiende el teclado y mantiene las secciones al día con las señales de `EventBus`. Lo que se ve lo
## pinta cada sección (`scripts/ui/journal/`) con los datos que lee `JournalInfo`. Las secciones se
## crean una vez y se conservan entre aperturas, así el expediente recuerda la pestaña y la ficha
## elegidas.

enum Tab { OBJECTIVES, CLUES, TESTIMONIES, SUSPECTS, DEDUCTIONS }

const TAB_TITLES: Array[String] = ["Objetivos", "Pistas", "Testimonios", "Sospechosos", "Deducciones"]
const TAB_ICONS: Array[String] = ["objetivo", "lupa", "testigos", "antifaz", "cerebro"]
## Lo usa también el tablero para las valoraciones de los sospechosos.
const STATUS_LABELS := JournalInfo.STATUS_LABELS
## Desplazamiento de una ficha larga con Av Pág y Re Pág.
const PAGE_SCROLL := 260.0

var is_open := false
var _current_tab := Tab.OBJECTIVES
var _sections: Array[JournalSection] = []
var _transition: Tween
var _refresh_pending := false
var _photo_busy := false

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _folder: JournalFolder = $Root/Folder
@onready var _shield: Control = $Root/Shield


func _ready() -> void:
	_dim.color = JournalStyle.DIM
	_build_sections()
	_folder.tabs.tab_changed.connect(_on_tab_changed)
	_folder.footer.close_pressed.connect(close)
	_root.resized.connect(_layout)
	Controls.input_device_changed.connect(_on_input_device_changed.unbind(1))
	EventBus.clue_discovered.connect(_on_state_changed.unbind(1))
	EventBus.testimony_recorded.connect(_on_state_changed.unbind(1))
	EventBus.deduction_made.connect(_on_state_changed.unbind(1))
	EventBus.hypothesis_changed.connect(_on_state_changed.unbind(1))
	EventBus.objectives_changed.connect(_on_state_changed)
	EventBus.time_changed.connect(_on_state_changed.unbind(2))
	EventBus.day_changed.connect(_on_state_changed.unbind(1))
	EventBus.location_changed.connect(_on_state_changed.unbind(1))
	_shield.hide()
	_root.hide()
	_layout()


## Abre el expediente en una sección. Sin sección, vuelve a la última que se miró.
func open(tab: int = -1) -> void:
	if tab >= 0 and tab < _sections.size():
		_current_tab = tab as Tab
	is_open = true
	GameState.lock_player("expediente")
	_folder.footer.refresh_keys()
	_show_section(_current_tab, false)
	_root.show()
	_shield.hide()
	_layout()
	_focus_current()
	_animate_open()
	_take_location_photo()


func close() -> void:
	if not is_open:
		return
	is_open = false
	GameState.unlock_player("expediente")
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_animate_close()


func get_current_tab() -> int:
	return _current_tab


func get_section(tab: int) -> JournalSection:
	return _sections[tab]


func get_folder() -> JournalFolder:
	return _folder


## Cambia de sección como lo haría el jugador: la pestaña, el contenido y el foco.
func select_tab(tab: int) -> void:
	if tab < 0 or tab >= _sections.size():
		return
	var focus_was_on_tabs := _is_focus_in(_folder.tabs)
	_show_section(tab, true)
	if focus_was_on_tabs:
		_folder.tabs.get_tab(tab).grab_focus()
	else:
		_focus_current()


## Al pasar del teclado al mando (o al revés), el pie cambia de rótulos.
func _on_input_device_changed() -> void:
	if is_open:
		_folder.footer.refresh_keys()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	# Su tecla, Esc o el botón de volver del mando lo cierran.
	if event.is_action_pressed("open_journal") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode < KEY_1 + _sections.size():
		get_viewport().set_input_as_handled()
		select_tab(key.keycode - KEY_1)
		return
	if event.is_action_pressed("ui_page_down", true):
		get_viewport().set_input_as_handled()
		_sections[_current_tab].scroll_detail(PAGE_SCROLL)
	elif event.is_action_pressed("ui_page_up", true):
		get_viewport().set_input_as_handled()
		_sections[_current_tab].scroll_detail(-PAGE_SCROLL)
	elif _is_focus_in(_folder.tabs) and event.is_action_pressed("ui_down", true):
		# Desde las pestañas, abajo lleva siempre a la ficha elegida de la sección.
		if _sections[_current_tab].focus_content():
			get_viewport().set_input_as_handled()
	elif _is_focus_in(_folder.body) or _nothing_focused():
		# Dentro de una sección, izquierda y derecha cambian de sección; arriba y abajo, de ficha.
		if event.is_action_pressed("ui_left", true):
			get_viewport().set_input_as_handled()
			select_tab(wrapi(_current_tab - 1, 0, _sections.size()))
		elif event.is_action_pressed("ui_right", true):
			get_viewport().set_input_as_handled()
			select_tab(wrapi(_current_tab + 1, 0, _sections.size()))
		elif _nothing_focused() and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up")):
			get_viewport().set_input_as_handled()
			_focus_current()


# --- Secciones ---

func _build_sections() -> void:
	_sections = [
		JournalObjectivesSection.new(),
		JournalCluesSection.new(),
		JournalTestimoniesSection.new(),
		JournalSuspectsSection.new(),
		JournalDeductionsSection.new(),
	]
	var definitions: Array[Dictionary] = []
	for index in _sections.size():
		definitions.append({"title": TAB_TITLES[index], "icon": TAB_ICONS[index]})
		var section := _sections[index]
		section.hide()
		_folder.body.add_child(section)
		# El pie va bajo la ficha: se recoloca cuando la columna derecha cambia de sitio.
		section.side.item_rect_changed.connect(_update_footer)
	_folder.tabs.setup(definitions)


func _show_section(tab: int, animate: bool) -> void:
	var changed := tab != _current_tab or not _sections[tab].visible
	_current_tab = tab as Tab
	_folder.tabs.select(tab)
	for index in _sections.size():
		_sections[index].visible = index == tab
	var section := _sections[tab]
	section.refresh()
	section.link_focus(_folder.tabs.get_tab(tab))
	_update_footer()
	if animate and changed:
		section.modulate.a = 0.0
		var tween := section.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(section, "modulate:a", 1.0, JournalStyle.PAGE_SECONDS)
	else:
		section.modulate.a = 1.0


func _on_tab_changed(tab: int) -> void:
	_show_section(tab, true)


## Algo ha cambiado en la partida: si el expediente está abierto, la sección visible se pone al día
## (una sola vez por fotograma aunque lleguen varias señales).
func _on_state_changed() -> void:
	if not is_open or _refresh_pending:
		return
	_refresh_pending = true
	_refresh_current.call_deferred()


func _refresh_current() -> void:
	_refresh_pending = false
	if is_open:
		var section := _sections[_current_tab]
		section.refresh()
		section.link_focus(_folder.tabs.get_tab(_current_tab))


# --- Foco ---

## El foco va a la ficha elegida de la sección o, si no hay fichas, a su pestaña.
func _focus_current() -> void:
	if not _sections[_current_tab].focus_content():
		_folder.tabs.get_tab(_current_tab).grab_focus()


func _is_focus_in(container: Control) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and container.is_ancestor_of(focused)


func _nothing_focused() -> bool:
	return get_viewport().gui_get_focus_owner() == null


# --- Composición y animaciones ---

## La carpeta ocupa la pantalla con un margen y sin pasar de un ancho máximo, centrada.
func _layout() -> void:
	var screen := _root.size
	var width := minf(screen.x - JournalStyle.FOLDER_MARGIN.x * 2.0, JournalStyle.FOLDER_MAX_WIDTH)
	var height := screen.y - JournalStyle.FOLDER_MARGIN.y * 2.0
	_folder.position = Vector2((screen.x - width) * 0.5, JournalStyle.FOLDER_MARGIN.y)
	_folder.size = Vector2(width, height)
	_folder.pivot_offset = _folder.size * 0.5
	_folder.relayout()
	_update_footer()


func _update_footer() -> void:
	if not _sections.is_empty():
		_folder.set_footer_left(_sections[_current_tab].get_footer_left())


func _animate_open() -> void:
	if _transition != null:
		_transition.kill()
	_root.modulate.a = 0.0
	_folder.scale = Vector2.ONE * JournalStyle.OPEN_SCALE
	_transition = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_root, "modulate:a", 1.0, JournalStyle.OPEN_SECONDS)
	_transition.tween_property(_folder, "scale", Vector2.ONE, JournalStyle.OPEN_SECONDS)


## Se desvanece y después se oculta. Mientras tanto, una capa transparente recoge los clics para que
## nada del expediente responda ya cerrado.
func _animate_close() -> void:
	if _transition != null:
		_transition.kill()
	_shield.show()
	_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transition.tween_property(_root, "modulate:a", 0.0, JournalStyle.CLOSE_SECONDS)
	_transition.tween_callback(_finish_close)


func _finish_close() -> void:
	if is_open:
		return
	_root.hide()
	_shield.hide()
	_root.modulate.a = 1.0


## Fotografía sepia del lugar donde está el detective, para la sección de objetivos. Se hace con la
## misma cámara que las imágenes de las ranuras (`SavePreview`) y una sola vez por lugar.
func _take_location_photo() -> void:
	var objectives := _sections[Tab.OBJECTIVES] as JournalObjectivesSection
	var location_id := GameState.location_id
	if _photo_busy or objectives.get_photo_location() == location_id:
		return
	var game := get_parent() as Game
	if game == null:
		return
	var post_fx := game.get_node_or_null("PostFx") as PostFx
	var fog := post_fx.get_fog_amount() if post_fx != null else 0.0
	var viewport := SavePreview.build_viewport(game.camera.camera, fog)
	if viewport == null:
		return
	_photo_busy = true
	add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := SavePreview.read_image(viewport)
	viewport.queue_free()
	_photo_busy = false
	if image != null and GameState.location_id == location_id:
		objectives.set_location_photo(ImageTexture.create_from_image(image), location_id)
