class_name HudToast
extends ParchmentPanel
## Notificación del HUD sobre el mismo pergamino que los paneles: un icono según el tipo, el título
## (en burdeos para pistas, deducciones e historia; en tinta para los avisos) y el detalle debajo.
## Los tipos son los de `EventBus.notification_requested`: "pista", "historia" e "info".

const ICONS := {"pista": "lupa", "historia": "nota"}
const ICON_SIZE := 30.0
const GAP := 12

var kind := ""
var _title := ""
var _body := ""


func _init(title: String = "", body: String = "", toast_kind: String = "info") -> void:
	kind = toast_kind
	_title = title
	_body = body
	padding = Vector4(18.0, 11.0, 20.0, 13.0)
	# Cada aviso con sus propias manchas, siempre las mismas para el mismo texto.
	paper_seed = float(hash(title) % 97) * 0.37
	custom_minimum_size.x = HudStyle.TOAST_WIDTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_width := HudStyle.TOAST_WIDTH - padding.x - padding.z
	if ICONS.has(kind):
		var icon := HudStyle.make_icon(HudStyle.icon(ICONS[kind]), ICON_SIZE, HudStyle.BURGUNDY)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		text_width -= ICON_SIZE + GAP
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 2)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var highlighted := kind != "info"
	var heading := HudStyle.make_label(title, HudStyle.title_font(), HudStyle.TOAST_TITLE_SIZE, HudStyle.BURGUNDY if highlighted else HudStyle.INK)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x = text_width
	text_box.add_child(heading)
	if not body.is_empty():
		var detail := HudStyle.make_label(body, HudStyle.body_font(), HudStyle.TOAST_BODY_SIZE, HudStyle.INK)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size.x = text_width
		text_box.add_child(detail)
	row.add_child(text_box)
	add_child(row)


func get_title() -> String:
	return _title


func get_body() -> String:
	return _body
