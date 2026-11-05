shader_type spatial;
// Empedrado procedural mojado. Calcula celdas de Voronoi en espacio de mundo para
// que las piedras encajen entre mallas distintas.

uniform float stones_per_meter = 3.6;
uniform vec3 stone_color : source_color = vec3(0.42, 0.43, 0.47);
uniform vec3 grout_color : source_color = vec3(0.09, 0.10, 0.12);

varying vec3 world_position;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(cell).x;
	float b = hash2(cell + vec2(1.0, 0.0)).x;
	float c = hash2(cell + vec2(0.0, 1.0)).x;
	float d = hash2(cell + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_position.xz * stones_per_meter;
	vec2 cell = floor(uv);
	vec2 local_uv = fract(uv);
	float nearest = 8.0;
	float second = 8.0;
	vec2 nearest_cell = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 jitter = hash2(cell + neighbor) * 0.8 + 0.1;
			float distance_to = length(neighbor + jitter - local_uv);
			if (distance_to < nearest) {
				second = nearest;
				nearest = distance_to;
				nearest_cell = cell + neighbor;
			} else if (distance_to < second) {
				second = distance_to;
			}
		}
	}
	float edge = smoothstep(0.03, 0.14, second - nearest);
	float variation = 0.72 + 0.5 * hash2(nearest_cell).y;
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	vec3 stone = stone_color * variation * tint;
	ALBEDO = mix(grout_color * tint, stone, edge);

	// Los charcos son zonas amplias de baja rugosidad que recogen la luz de las farolas.
	float puddles = smoothstep(0.52, 0.68, value_noise(world_position.xz * 0.28));
	ROUGHNESS = mix(mix(0.92, 0.5, edge), 0.14, puddles);
	SPECULAR = mix(0.4, 0.75, puddles);
	ALBEDO *= mix(1.0, 0.72, puddles);
}
