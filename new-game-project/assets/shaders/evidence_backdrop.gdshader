shader_type canvas_item;
// Fondo de las evidencias: el escenario desenfocado y oscurecido, más hondo en los bordes, para
// que el documento destaque sin perder del todo la escena (la lluvia y las farolas siguen ahí).
// Lee la pantalla ya dibujada con sus mipmaps, así que el desenfoque cuesta unas pocas lecturas.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.02, 0.025, 0.035, 0.72);
// Nivel de mipmap del que se lee: cuanto más alto, más desenfocado.
uniform float blur = 2.6;
// Oscurecimiento añadido en las esquinas.
uniform float vignette = 0.22;

void fragment() {
	vec2 step = SCREEN_PIXEL_SIZE * exp2(blur) * 0.75;
	vec3 scene = textureLod(screen_texture, SCREEN_UV, blur).rgb * 0.4;
	scene += textureLod(screen_texture, SCREEN_UV + vec2(step.x, step.y), blur).rgb * 0.15;
	scene += textureLod(screen_texture, SCREEN_UV + vec2(-step.x, step.y), blur).rgb * 0.15;
	scene += textureLod(screen_texture, SCREEN_UV + vec2(step.x, -step.y), blur).rgb * 0.15;
	scene += textureLod(screen_texture, SCREEN_UV - step, blur).rgb * 0.15;
	float edge = smoothstep(0.3, 0.9, length((UV - 0.5) * vec2(1.0, 0.78)) * 1.4);
	float amount = clamp(tint.a + edge * vignette, 0.0, 1.0);
	COLOR = vec4(mix(scene, tint.rgb, amount), 1.0);
}
