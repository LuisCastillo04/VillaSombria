class_name SavePreview
extends RefCounted
## Imagen de una partida para su ranura. Se renderiza el mundo 3D desde una copia de la
## cámara del juego en un SubViewport propio, con el mismo postproceso noir, de modo que la
## imagen es la escena real y nunca incluye la pausa, los menús, el HUD ni los diálogos.

const SIZE := Vector2i(384, 216)
const JPG_QUALITY := 0.82
const POST_SHADER := preload("res://assets/shaders/noir_post.gdshader")


## Prepara el SubViewport que hará la foto en el siguiente fotograma. Quien lo llama lo añade
## al árbol, espera a `RenderingServer.frame_post_draw` y lee la textura. Devuelve null si no
## hay cámara o si el juego corre sin ventana (no se puede renderizar).
static func build_viewport(source_camera: Camera3D, fog_amount: float) -> SubViewport:
	if source_camera == null or not source_camera.is_inside_tree():
		return null
	if DisplayServer.get_name() == "headless":
		return null
	var viewport := SubViewport.new()
	viewport.name = "VistaPreviaPartida"
	viewport.size = SIZE
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.positional_shadow_atlas_size = 2048
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.projection = source_camera.projection
	camera.size = source_camera.size
	camera.fov = source_camera.fov
	camera.near = source_camera.near
	camera.far = source_camera.far
	camera.keep_aspect = source_camera.keep_aspect
	camera.transform = source_camera.global_transform
	camera.current = true
	viewport.add_child(camera)
	var material := ShaderMaterial.new()
	material.shader = POST_SHADER
	material.set_shader_parameter("fog_amount", fog_amount)
	var post := ColorRect.new()
	post.material = material
	post.size = Vector2(SIZE)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(post)
	return viewport


## Lee la imagen ya renderizada. Devuelve null si el renderizador no produjo nada.
static func read_image(viewport: SubViewport) -> Image:
	var texture := viewport.get_texture()
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	return image
