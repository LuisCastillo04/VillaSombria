class_name MenuScreen
extends Control
## Pantalla de menú que se abre sobre otra (la pausa o el menú principal) sin tapar el escenario:
## aparece y se cierra con un fundido, Escape la cierra y `closed` avisa a quien la abrió para que
## recupere su panel y el foco. Mientras se desvanece no acepta clics ni foco. Los fundidos
## funcionan con el árbol en pausa porque heredan el modo de proceso de la pausa.

signal closed

const FADE_SECONDS := 0.16

## Oscurece lo que queda detrás. La pausa ya trae su propio velo; el menú principal no.
@export_range(0.0, 1.0) var backdrop_dim := 0.0

var _tween: Tween
var _closing := false


func open() -> void:
	_stop_fade()
	_closing = false
	_set_interactive(true)
	show()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_focus_default()


func close() -> void:
	if not is_open():
		return
	_closing = true
	_set_interactive(false)
	_stop_fade()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(_finish_close)
	closed.emit()


## Visible y sin estar cerrándose.
func is_open() -> bool:
	return is_visible_in_tree() and not _closing


func _input(event: InputEvent) -> void:
	if not is_open() or ExitManager.is_dialog_open() or ConfirmDialog.is_open():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _draw() -> void:
	if backdrop_dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(MenuStyle.DIM, backdrop_dim))


## Control que recibe el foco al abrir. Cada pantalla decide cuál.
func _focus_default() -> void:
	pass


func _finish_close() -> void:
	hide()
	modulate.a = 1.0
	_closing = false
	_set_interactive(true)


func _stop_fade() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _set_interactive(interactive: bool) -> void:
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if interactive else Control.MOUSE_BEHAVIOR_DISABLED
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if interactive else Control.FOCUS_BEHAVIOR_DISABLED
