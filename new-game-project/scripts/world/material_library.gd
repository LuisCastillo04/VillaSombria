class_name MaterialLibrary
extends RefCounted
## Materiales compartidos. El mundo usa colores de vértice, de modo que un
## escenario completo se dibuja con muy pocos materiales.

static var _vertex_lit: StandardMaterial3D
static var _glow: ShaderMaterial
static var _marker: StandardMaterial3D


static func vertex_lit() -> StandardMaterial3D:
	if _vertex_lit == null:
		_vertex_lit = StandardMaterial3D.new()
		_vertex_lit.vertex_color_use_as_albedo = true
		_vertex_lit.vertex_color_is_srgb = true
		_vertex_lit.roughness = 0.82
		_vertex_lit.metallic_specular = 0.35
	return _vertex_lit


## Superficies que emiten luz propia: ventanas, faroles, pantallas de lámpara.
static func glow() -> ShaderMaterial:
	if _glow == null:
		_glow = ShaderMaterial.new()
		_glow.shader = load("res://assets/shaders/glow_vertex.gdshader")
	return _glow


static func marker() -> StandardMaterial3D:
	if _marker == null:
		_marker = StandardMaterial3D.new()
		_marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_marker.albedo_color = Palette.AMBER
		_marker.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_marker.no_depth_test = true
		_marker.render_priority = 10
	return _marker
