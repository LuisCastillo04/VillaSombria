shader_type canvas_item;
// Cuero de la carpeta del expediente: grano fino, poros, vetas suaves y bordes gastados más
// oscuros. `rect_size` se actualiza desde el script para que el grano no se estire.

uniform vec4 base_color : source_color = vec4(0.294, 0.122, 0.09, 1.0);
uniform vec4 dark_color : source_color = vec4(0.12, 0.05, 0.035, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.48, 0.24, 0.16, 1.0);
uniform vec2 rect_size = vec2(1760.0, 990.0);
uniform float corner_radius = 14.0;
uniform float edge_width = 60.0;
uniform float seed = 1.3;

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
		p = p * 2.03 + vec2(5.1, 1.7);
		weight *= 0.5;
	}
	return total;
}

float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 pixel = UV * rect_size;
	vec2 p = pixel / 220.0 + seed;
	float mottling = fbm(p * 0.8);
	float grain = noise(pixel / 2.2 + seed * 13.0);
	float pores = smoothstep(0.82, 0.95, noise(pixel / 3.4 + seed * 7.0));
	vec3 color = mix(base_color.rgb, sheen_color.rgb, smoothstep(0.45, 0.85, mottling) * 0.35);
	color = mix(color, dark_color.rgb, smoothstep(0.55, 0.2, mottling) * 0.35);
	color *= 0.93 + 0.1 * grain;
	color *= 1.0 - pores * 0.18;
	float inside = -rounded_box(pixel - rect_size * 0.5, rect_size * 0.5, corner_radius);
	float wear = 1.0 - smoothstep(0.0, edge_width, inside + (mottling - 0.5) * 24.0);
	color = mix(color, dark_color.rgb, wear * 0.6);
	COLOR = vec4(color, clamp(inside + 0.5, 0.0, 1.0));
}
