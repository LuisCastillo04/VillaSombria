class_name JournalListColumn
extends JournalPage
## Página izquierda de una sección: la cinta con el título y el recuento, una línea opcional bajo
## ella (la fecha, en Objetivos), la lista desplazable y un grabado sepia al pie. El grabado sólo
## ocupa el hueco que deja la lista: se encoge cuando la lista crece y desaparece si no le queda
## sitio, de modo que nunca tapa una ficha.

const ART_MAX_HEIGHT := 330.0
## Margen que se deja por encima y por debajo de una ficha al desplazar la lista hasta ella.
const REVEAL_MARGIN := 12.0

var banner: JournalBanner
## Bajo la cinta: lo que la sección quiera poner (la fecha del día, por ejemplo).
var header: VBoxContainer
var scroll: ScrollContainer
## Contenido desplazable: la `JournalList` o las tarjetas de la sección.
var content: VBoxContainer
## Nota que sustituye a la lista cuando está vacía.
var empty_note: Label

var _box: VBoxContainer


func _init(title: String = "", icon_name: String = "") -> void:
	super._init()
	padding = Vector4(20.0, 20.0, 20.0, 20.0)
	art_corner = ArtCorner.BOTTOM_CENTER
	art_alpha = 0.62
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = JournalBanner.new(title, JournalStyle.icon(icon_name) if not icon_name.is_empty() else null)
	_box.add_child(banner)
	header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.hide()
	_box.add_child(header)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# El desplazamiento lo lleva `reveal`, que deja ver la ficha entera con su brillo.
	scroll.follow_focus = false
	JournalStyle.style_scroll(scroll)
	_box.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(JournalStyle.ROW_GAP))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Margen para que el brillo de la ficha elegida y el anillo del foco no se recorten.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)
	scroll.add_child(margin)
	empty_note = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.NOTE_SIZE, JournalStyle.INK_SOFT, true)
	empty_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_note.hide()
	content.add_child(empty_note)
	add_child(_box)


func _ready() -> void:
	super._ready()
	scroll.resized.connect(_fit_art)
	content.minimum_size_changed.connect(_fit_art.call_deferred)
	_fit_art()


func set_title(title: String) -> void:
	banner.text = title


## Muestra u oculta la nota de lista vacía.
func set_empty_text(text: String) -> void:
	empty_note.text = text
	empty_note.visible = not text.is_empty()


## Desplaza la lista lo justo para que `control` se vea entero, con su brillo y su anillo de foco.
## La primera ficha deja la lista arriba del todo.
func reveal(control: Control) -> void:
	if control == null or not control.is_inside_tree() or not scroll.is_inside_tree():
		return
	var origin := (content.get_parent() as Control).global_position.y
	var top := control.global_position.y - origin - REVEAL_MARGIN
	var bottom := control.global_position.y - origin + control.size.y + REVEAL_MARGIN
	if top <= REVEAL_MARGIN:
		scroll.scroll_vertical = 0
	elif top < scroll.scroll_vertical:
		scroll.scroll_vertical = int(top)
	elif bottom > scroll.scroll_vertical + scroll.size.y:
		scroll.scroll_vertical = int(ceilf(bottom - scroll.size.y))


## Altura libre bajo la lista: la que puede ocupar el grabado.
func get_free_height() -> float:
	var used := content.get_combined_minimum_size().y + 16.0
	return maxf(scroll.size.y - used, 0.0)


func is_art_shown() -> bool:
	return art != null and art_alpha > 0.0 and get_art_rect().size.y >= JournalStyle.ART_MIN_HEIGHT


func _fit_art() -> void:
	if art == null:
		return
	var free := get_free_height() - 12.0
	art_size = Vector2(size.x - padding.x - padding.z, minf(free, ART_MAX_HEIGHT))
	art_alpha = 0.62 if free >= JournalStyle.ART_MIN_HEIGHT else 0.0
	queue_redraw()
