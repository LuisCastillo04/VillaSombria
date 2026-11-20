shader_type canvas_item;
// Fotografía antigua del expediente: virado a sepia, fondo de estudio para las siluetas, viñeta y
// grano. `tone` decide cuánto color original se pierde: 1 es sepia puro y 0 deja
// los colores (la corbata roja de una silueta sigue siendo roja con un virado parcial).

uniform float tone : hint_range(0.0, 1.0) = 0.85;
uniform bool use_backdrop = false;
uniform vec4 backdrop_light : source_color = vec4(0.86, 0.74, 0.55, 1.0);
uniform vec4 backdrop_dark : source_color = vec4(0.42, 0.3, 0.19, 1.0);
uniform vec4 sepia_dark : source_color = vec4(0.16, 0.1, 0.06, 1.0);
uniform vec4 sepia_light : source_color = vec4(0.93, 0.84, 0.66, 1.0);
uniform float vignette = 0.7;
uniform float fade = 0.08;
uniform float grain = 0.06;
uniform float seed = 2.0;

// Tamaño del rectángulo dibujado, en píxeles. Los efectos se calculan sobre él y no sobre la UV de
// la textura, que en un recorte (AtlasTexture) o en un encuadre ampliado no va de 0 a 1.
uniform vec2 draw_size = vec2(1.0, 1.0);

// Color del vértice (la modulación del nodo): en el fragmento, COLOR ya viene multiplicado por la
// textura y su alfa borraría el fondo de estudio.
varying vec4 tint;
varying vec2 local_uv;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	tint = COLOR;
	local_uv = VERTEX / max(draw_size, vec2(1.0));
}

void fragment() {
	vec4 picture = texture(TEXTURE, UV);
	vec3 color = picture.rgb;
	float alpha = picture.a;
	if (use_backdrop) {
		// Luz de estudio detrás del retratado: clara arriba y en el centro, oscura en los bordes.
		float glow = 1.0 - smoothstep(0.0, 0.75, distance(local_uv, vec2(0.55, 0.35)));
		vec3 backdrop = mix(backdrop_dark.rgb, backdrop_light.rgb, glow);
		color = mix(backdrop, picture.rgb, picture.a);
		alpha = 1.0;
	}
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 sepia = mix(sepia_dark.rgb, sepia_light.rgb, luminance);
	color = mix(color, sepia, tone);
	color = mix(color, sepia_light.rgb, fade);
	vec2 centered = local_uv - 0.5;
	color *= 1.0 - vignette * dot(centered, centered) * 1.4;
	vec2 cell = floor(local_uv * vec2(260.0, 320.0));
	color += (hash(cell + seed) - 0.5) * grain;
	COLOR = vec4(clamp(color, 0.0, 1.0), alpha * tint.a);
}
