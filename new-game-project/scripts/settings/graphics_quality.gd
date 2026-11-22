class_name GraphicsQuality
extends RefCounted
## Niveles de calidad gráfica de Configuración: «Sombras e iluminación» y «Efectos y partículas».
##
## «Alto» es el aspecto original del juego: los valores del proyecto y lo que cada escenario pide al
## crear sus luces. Los niveles inferiores reducen lo que más cuesta dibujar sin apagar ninguna luz
## (las farolas, las ventanas y las lámparas siguen iluminando lo mismo) ni tocar lo que pasa en la
## historia: la lluvia sigue cayendo y su sonido no cambia, sólo se dibujan menos gotas.
##
## Lo que se ajusta existe de verdad en el juego:
## - Iluminación: las sombras de la luz exterior (`DirectionalLight3D`) y de las farolas y lámparas
##   que las proyectan (`OmniLight3D`), el modo de sombra de estas, el tamaño de los atlas de sombras,
##   el filtro de suavizado y el resplandor (`glow`) del entorno.
## - Efectos: la cantidad de gotas de lluvia (`RainEffect`), las capas de niebla del postproceso
##   (`noir_post.gdshader`) y su grano de película.
##
## Las luces, los entornos, la lluvia y el postproceso se registran al crearse (con lo que pedía su
## escenario) y se ajustan solos al nivel vigente; al cambiar de nivel se ajustan todos los que hay
## en el árbol, sin recrear nada.

const LIGHT_GROUP := &"calidad_luces"
const ENVIRONMENT_GROUP := &"calidad_entornos"
const RAIN_GROUP := &"calidad_lluvia"
const POST_GROUP := &"calidad_postproceso"
## Lo que pedía cada nodo al crearse, para volver a ello en «Alto».
const DESIGNED_SHADOW := &"sombra_prevista"
const DESIGNED_GLOW := &"resplandor_previsto"

## Cada nivel de iluminación. `atlas_scale` multiplica el tamaño de los atlas de sombras del
## proyecto; `filter` es la calidad del suavizado (-1: la del proyecto).
const LIGHTING := {
	"bajo": {"shadows": false, "glow": false, "omni_mode": OmniLight3D.SHADOW_DUAL_PARABOLOID,
		"atlas_scale": 0.25, "filter": RenderingServer.SHADOW_QUALITY_HARD},
	"medio": {"shadows": true, "glow": true, "omni_mode": OmniLight3D.SHADOW_DUAL_PARABOLOID,
		"atlas_scale": 0.5, "filter": RenderingServer.SHADOW_QUALITY_HARD},
	"alto": {"shadows": true, "glow": true, "omni_mode": OmniLight3D.SHADOW_CUBE,
		"atlas_scale": 1.0, "filter": -1},
}
## Cada nivel de efectos. `rain` es la parte de las gotas que se dibuja; `fog_octaves`, las capas
## de ruido de la niebla del postproceso (4 es la original).
const EFFECTS := {
	"bajo": {"rain": 0.3, "fog_octaves": 2, "grain": false},
	"medio": {"rain": 0.6, "fog_octaves": 3, "grain": true},
	"alto": {"rain": 1.0, "fog_octaves": 4, "grain": true},
}
const MIN_ATLAS := 512

const DIRECTIONAL_SIZE := "rendering/lights_and_shadows/directional_shadow/size"
const DIRECTIONAL_16_BITS := "rendering/lights_and_shadows/directional_shadow/16_bits"
const DIRECTIONAL_FILTER := "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
const POSITIONAL_SIZE := "rendering/lights_and_shadows/positional_shadow/atlas_size"
const POSITIONAL_16_BITS := "rendering/lights_and_shadows/positional_shadow/atlas_16_bits"
const POSITIONAL_FILTER := "rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality"


static func lighting_level() -> String:
	return _valid_level(Settings.get_value("graficos/calidad_iluminacion"), LIGHTING)


static func effects_level() -> String:
	return _valid_level(Settings.get_value("graficos/calidad_efectos"), EFFECTS)


# --- Registro: cada pieza se apunta al crearse y toma el nivel vigente ---

## Una luz de un escenario, con las sombras que pide su escenario.
static func register_light(light: Light3D) -> void:
	light.set_meta(DESIGNED_SHADOW, light.shadow_enabled)
	light.add_to_group(LIGHT_GROUP)
	configure_light(light, lighting_level())


## El entorno de un escenario, con el resplandor que pide su escenario.
static func register_environment(node: WorldEnvironment) -> void:
	if node.environment != null:
		node.set_meta(DESIGNED_GLOW, node.environment.glow_enabled)
	node.add_to_group(ENVIRONMENT_GROUP)
	configure_environment(node, lighting_level())


static func register_rain(rain: RainEffect) -> void:
	rain.add_to_group(RAIN_GROUP)
	configure_rain(rain, effects_level())


static func register_post(post: PostFx) -> void:
	post.add_to_group(POST_GROUP)
	configure_post(post, effects_level())


# --- Aplicación de un nivel ---

## Aplica un nivel de iluminación a todo el juego: atlas y filtros del servidor de dibujo y cada luz
## y entorno registrados.
static func apply_lighting(tree: SceneTree, level: String) -> void:
	level = _valid_level(level, LIGHTING)
	var settings: Dictionary = LIGHTING[level]
	var scale: float = settings["atlas_scale"]
	RenderingServer.directional_shadow_atlas_set_size(
		_atlas_size(DIRECTIONAL_SIZE, scale), bool(ProjectSettings.get_setting(DIRECTIONAL_16_BITS, true)))
	RenderingServer.directional_soft_shadow_filter_set_quality(_filter(settings, DIRECTIONAL_FILTER))
	RenderingServer.positional_soft_shadow_filter_set_quality(_filter(settings, POSITIONAL_FILTER))
	if tree != null:
		tree.root.positional_shadow_atlas_size = _atlas_size(POSITIONAL_SIZE, scale)
		for node in tree.get_nodes_in_group(LIGHT_GROUP):
			configure_light(node as Light3D, level)
		for node in tree.get_nodes_in_group(ENVIRONMENT_GROUP):
			configure_environment(node as WorldEnvironment, level)


static func apply_effects(tree: SceneTree, level: String) -> void:
	level = _valid_level(level, EFFECTS)
	if tree == null:
		return
	for node in tree.get_nodes_in_group(RAIN_GROUP):
		configure_rain(node as RainEffect, level)
	for node in tree.get_nodes_in_group(POST_GROUP):
		configure_post(node as PostFx, level)


static func configure_light(light: Light3D, level: String) -> void:
	if light == null:
		return
	var settings: Dictionary = LIGHTING[_valid_level(level, LIGHTING)]
	var designed := bool(light.get_meta(DESIGNED_SHADOW, light.shadow_enabled))
	light.shadow_enabled = designed and bool(settings["shadows"])
	var omni := light as OmniLight3D
	if omni != null:
		omni.omni_shadow_mode = settings["omni_mode"]


static func configure_environment(node: WorldEnvironment, level: String) -> void:
	if node == null or node.environment == null:
		return
	var settings: Dictionary = LIGHTING[_valid_level(level, LIGHTING)]
	var designed := bool(node.get_meta(DESIGNED_GLOW, node.environment.glow_enabled))
	node.environment.glow_enabled = designed and bool(settings["glow"])


static func configure_rain(rain: RainEffect, level: String) -> void:
	if rain == null:
		return
	var target := rain_amount(RainEffect.FULL_AMOUNT, level)
	# Cambiar la cantidad reinicia el sistema; sólo se hace si de verdad cambia. El preproceso de
	# la lluvia la vuelve a llenar en el acto, sin un hueco sin gotas.
	if rain.amount != target:
		rain.amount = target


static func configure_post(post: PostFx, level: String) -> void:
	if post == null:
		return
	var settings: Dictionary = EFFECTS[_valid_level(level, EFFECTS)]
	post.set_quality(int(settings["fog_octaves"]), bool(settings["grain"]))


## Gotas de lluvia que se dibujan en un nivel, de las `full` del nivel alto.
static func rain_amount(full: int, level: String = "") -> int:
	if level.is_empty():
		level = effects_level()
	var ratio := float((EFFECTS[_valid_level(level, EFFECTS)] as Dictionary)["rain"])
	return maxi(roundi(full * ratio), 1)


static func _atlas_size(setting: String, scale: float) -> int:
	var full := int(ProjectSettings.get_setting(setting, 4096))
	return maxi(nearest_po2(roundi(full * scale)), MIN_ATLAS)


static func _filter(settings: Dictionary, setting: String) -> RenderingServer.ShadowQuality:
	var quality := int(settings["filter"])
	if quality < 0:
		quality = int(ProjectSettings.get_setting(setting, RenderingServer.SHADOW_QUALITY_SOFT_LOW))
	return quality as RenderingServer.ShadowQuality


static func _valid_level(level: Variant, table: Dictionary) -> String:
	var text := String(level) if typeof(level) == TYPE_STRING or typeof(level) == TYPE_STRING_NAME else ""
	return text if table.has(text) else "alto"
