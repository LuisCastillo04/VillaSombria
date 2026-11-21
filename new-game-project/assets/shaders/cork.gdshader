shader_type canvas_item;
// Corcho del tablero de deducción: gránulos de varios tamaños, poros oscuros, motas claras, manchas
// suaves de envejecimiento y una sombra interior junto al marco. `rect_size` se actualiza desde el
// script para que el grano tenga siempre el mismo tamaño en pantalla y no se estire.

uniform vec4 base_color : source_color = vec4(0.753, 0.624, 0.439, 1.0);
uniform vec4 dark_color : source_color = vec4(0.525, 0.392, 0.243, 1.0);
uniform vec4 light_color : source_color = vec4(0.863, 0.773, 0.608, 1.0);
uniform vec2 rect_size = vec2(1200.0, 700.0);
uniform float seed = 2.3;
// Oscurecimiento de las esquinas y ancho de la sombra que proyecta el marco, en píxeles.
uniform float vignette = 0.42;
uniform float inner_shadow = 30.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		total += noise(p) * weight;
		p = p * 2.11 + vec2(4.7, 2.3);
		weight *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 pixel = UV * rect_size;
	float blotch = fbm(pixel / 160.0 + seed);
	float granule = noise(pixel / 2.4 + seed * 3.1);
	float granule_large = noise(pixel / 6.0 + seed * 5.3);
	float pores = smoothstep(0.8, 0.94, noise(pixel / 3.2 + seed * 9.7));
	float flecks = smoothstep(0.84, 0.97, noise(pixel / 4.4 + seed * 1.9));
	vec3 color = mix(base_color.rgb, light_color.rgb, smoothstep(0.42, 0.78, blotch) * 0.45);
	color = mix(color, dark_color.rgb, smoothstep(0.62, 0.3, blotch) * 0.22);
	color *= 0.9 + 0.12 * granule + 0.08 * granule_large;
	color = mix(color, dark_color.rgb * 0.8, pores * 0.5);
	color = mix(color, light_color.rgb, flecks * 0.3);
	vec2 centered = UV - 0.5;
	color *= 1.0 - vignette * dot(centered, centered) * 1.5;
	float edge = min(min(pixel.x, rect_size.x - pixel.x), min(pixel.y, rect_size.y - pixel.y));
	color *= mix(0.62, 1.0, smoothstep(0.0, inner_shadow, edge));
	COLOR = vec4(color, 1.0);
}
