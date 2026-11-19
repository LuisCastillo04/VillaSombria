shader_type canvas_item;
// Pergamino envejecido para el expediente de guardar y cargar: manchas suaves, fibras,
// bordes oscurecidos y esquinas redondeadas. `rect_size` se actualiza desde el script.

uniform vec4 base_color : source_color = vec4(0.914, 0.843, 0.702, 1.0);
uniform vec4 stain_color : source_color = vec4(0.62, 0.46, 0.27, 1.0);
uniform vec4 edge_color : source_color = vec4(0.42, 0.27, 0.14, 1.0);
uniform vec2 rect_size = vec2(1360.0, 940.0);
uniform float corner_radius = 18.0;
uniform float edge_width = 70.0;
uniform float seed = 3.7;

// Hash sin `sin()`: con fract(sin(x) * 43758.5) la GPU pierde precisión en argumentos grandes y
// el ruido se vuelve escalonado, con bloques de bordes rectos sobre el pergamino.
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
	for (int octave = 0; octave < 5; octave++) {
		total += noise(p) * weight;
		p = p * 2.07 + vec2(3.1, 7.7);
		weight *= 0.5;
	}
	return total;
}

// Distancia con signo a un rectángulo de esquinas redondeadas centrado en el origen.
float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 pixel = UV * rect_size;
	vec2 p = pixel / 140.0 + seed;
	float blotch = fbm(p * 0.7);
	float fine = fbm(p * 7.0);
	float fibers = noise(vec2(pixel.x / 3.0, pixel.y / 60.0) + seed);
	vec3 color = base_color.rgb;
	color = mix(color, stain_color.rgb, smoothstep(0.42, 0.9, blotch) * 0.32);
	color *= 0.955 + 0.09 * fine;
	color *= 0.99 + 0.025 * fibers;
	float inside = -rounded_box(pixel - rect_size * 0.5, rect_size * 0.5, corner_radius);
	float burn = 1.0 - smoothstep(0.0, edge_width, inside + (blotch - 0.5) * 30.0);
	color = mix(color, edge_color.rgb, burn * 0.55);
	float alpha = clamp(inside + 0.5, 0.0, 1.0);
	COLOR = vec4(color, alpha);
}
