class_name AccusationPlateButton
extends Button
## Botón de la acusación: una placa con las esquinas en chaflán, filete dorado y otro más fino por
## dentro, con su icono. «Presentar la acusación» (`primary`) es burdeos y destaca más; «Seguir
## investigando», carbón. Desactivada, la placa se apaga y el filete interior desaparece.

const INNER_INSET := 5.0
const INNER_CUT := 8.0

@export var primary := true:
	set(value):
		primary = value
		if is_inside_tree():
			AccusationStyle.apply_plate_button(self, primary)
@export var icon_name := "":
	set(value):
		icon_name = value
		icon = AccusationStyle.icon(value) if not value.is_empty() else null


func _ready() -> void:
	AccusationStyle.apply_plate_button(self, primary)
	custom_minimum_size.y = maxf(custom_minimum_size.y, AccusationStyle.BUTTON_HEIGHT)
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	if disabled:
		return
	var rect := Rect2(Vector2.ZERO, size).grow(-INNER_INSET)
	var color := Color(AccusationStyle.GOLD_LIGHT if is_hovered() else AccusationStyle.GOLD, 0.55)
	draw_polyline(HudOrnaments.closed(HudOrnaments.chamfered(rect, INNER_CUT)), color, 1.0, true)
