class_name InteractionDetector
extends Area3D
## Elige el elemento interactivo más cercano y lo anuncia a la interfaz.

var _nearby: Array[Interactable] = []
var _focused: Interactable


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func get_focused() -> Interactable:
	return _focused


func trigger(actor: Node) -> bool:
	if _focused == null or not _focused.can_interact():
		return false
	_focused.interact(actor)
	return true


func _physics_process(_delta: float) -> void:
	var best: Interactable = null
	var best_distance := INF
	if not GameState.is_player_locked():
		for candidate in _nearby:
			if not is_instance_valid(candidate) or not candidate.can_interact():
				continue
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	_set_focused(best)


func _set_focused(next: Interactable) -> void:
	if next == _focused:
		return
	if is_instance_valid(_focused):
		_focused.set_focused(false)
	_focused = next
	if _focused != null:
		_focused.set_focused(true)
	EventBus.interaction_focus_changed.emit(_focused.get_prompt() if _focused != null else "")


func _on_area_entered(area: Area3D) -> void:
	if area is Interactable:
		_nearby.append(area)


func _on_area_exited(area: Area3D) -> void:
	if area is Interactable:
		_nearby.erase(area)
