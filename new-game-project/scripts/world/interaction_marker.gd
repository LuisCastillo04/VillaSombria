class_name InteractionMarker
extends Node3D
## Rombo flotante que señala un elemento interactivo. Con `emphasis` (un personaje con preguntas
## recién desbloqueadas) es algo mayor, más claro y late despacio; sin él, el rombo de siempre.

const EMPHASIS_COLOR := Color(1.0, 0.86, 0.55)
const EMPHASIS_PULSE := 2.2

var _mesh: MeshInstance3D
var _clock := randf() * TAU
var _focused := false
var _attention := false
var _emphasis := false


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var batch := MeshBatcher.new()
	batch.color_jitter = 0.0
	batch.cylinder(Vector3.ZERO, 0.0, 0.13, 0.17, Color.WHITE, 4)
	batch.cylinder(Vector3.UP * 0.17, 0.13, 0.0, 0.17, Color.WHITE, 4)
	_mesh.mesh = batch.build_mesh()
	_mesh.material_override = _emphasis_material() if _emphasis else MaterialLibrary.marker()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_refresh()


func set_focused(value: bool) -> void:
	_focused = value
	_refresh()


func set_attention(value: bool) -> void:
	_attention = value
	_refresh()


func set_emphasis(value: bool) -> void:
	if _emphasis == value:
		return
	_emphasis = value
	if _mesh != null:
		_mesh.material_override = _emphasis_material() if value else MaterialLibrary.marker()
	_refresh()


func has_emphasis() -> bool:
	return _emphasis


func is_shown() -> bool:
	return visible


func _process(delta: float) -> void:
	_clock += delta
	if _mesh == null:
		return
	_mesh.position.y = sin(_clock * 2.6) * 0.07
	_mesh.rotation.y += delta * 1.6
	if _emphasis and not _focused:
		var pulse := 0.06 * sin(_clock * EMPHASIS_PULSE) * UiAccessibility.motion()
		_mesh.scale = Vector3.ONE * (0.9 + pulse)


func _refresh() -> void:
	if _mesh == null:
		return
	visible = _focused or _attention
	_mesh.scale = Vector3.ONE * (1.15 if _focused else (0.9 if _emphasis else 0.75))


static var _emphasis_mat: StandardMaterial3D


## El mismo material del rombo, en un dorado más claro.
static func _emphasis_material() -> StandardMaterial3D:
	if _emphasis_mat == null:
		_emphasis_mat = MaterialLibrary.marker().duplicate()
		_emphasis_mat.albedo_color = EMPHASIS_COLOR
	return _emphasis_mat
