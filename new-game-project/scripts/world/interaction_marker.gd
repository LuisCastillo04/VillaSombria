class_name InteractionMarker
extends Node3D
## Rombo flotante que señala un elemento interactivo.

var _mesh: MeshInstance3D
var _clock := randf() * TAU
var _focused := false
var _attention := false


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var batch := MeshBatcher.new()
	batch.color_jitter = 0.0
	batch.cylinder(Vector3.ZERO, 0.0, 0.13, 0.17, Color.WHITE, 4)
	batch.cylinder(Vector3.UP * 0.17, 0.13, 0.0, 0.17, Color.WHITE, 4)
	_mesh.mesh = batch.build_mesh()
	_mesh.material_override = MaterialLibrary.marker()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_refresh()


func set_focused(value: bool) -> void:
	_focused = value
	_refresh()


func set_attention(value: bool) -> void:
	_attention = value
	_refresh()


func _process(delta: float) -> void:
	_clock += delta
	if _mesh == null:
		return
	_mesh.position.y = sin(_clock * 2.6) * 0.07
	_mesh.rotation.y += delta * 1.6


func _refresh() -> void:
	if _mesh == null:
		return
	visible = _focused or _attention
	_mesh.scale = Vector3.ONE * (1.15 if _focused else 0.75)
