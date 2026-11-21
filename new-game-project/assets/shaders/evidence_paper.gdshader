shader_type canvas_item;
// Papel antiguo de las evidencias: claro en el centro, manchado, con fibras, motas de humedad,
// pliegues, bordes rasgados y quemados, un cerco de café opcional y una sombra suave alrededor.
//
// El nodo es más grande que el papel: deja `shadow_margin` píxeles por cada lado para la sombra.
// `rect_size` es el tamaño del nodo y lo actualiza `EvidencePaper` al cambiar de tamaño. Todas las
// medidas están en píxeles del documento, así que el papel se ve igual a cualquier escala.

uniform vec4 base_color : source_color = vec4(0.87, 0.77, 0.58, 1.0);
uniform vec4 light_color : source_color = vec4(0.95, 0.88, 0.72, 1.0);
uniform vec4 stain_color : source_color = vec4(0.66, 0.5, 0.3, 1.0);
uniform vec4 edge_color : source_color = vec4(0.38, 0.24, 0.12, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);
uniform vec2 rect_size = vec2(1400.0, 900.0);
uniform float shadow_margin = 40.0;
uniform vec2 shadow_offset = vec2(0.0, 10.0);
uniform float seed = 1.0;
// Profundidad de los rasgados del borde y de los mordiscos más grandes, en píxeles.
uniform float tear = 9.0;
uniform float chunks = 1.0;
// Ancho de la franja quemada junto al borde.
uniform float edge_width = 70.0;
// Pliegues: posición de cada uno entre 0 y 1 a lo ancho (x) o a lo alto (y); un valor negativo
// significa que no hay pliegue.
uniform vec4 folds_x = vec4(0.5, -1.0, -1.0, -1.0);
uniform vec4 folds_y = vec4(-1.0, -1.0, -1.0, -1.0);
uniform float fold_strength = 1.0;
// Cerco de café: centro (0-1), radio en píxeles e intensidad (0, sin cerco).
uniform vec4 ring = vec4(0.0, 0.0, 0.0, 0.0);
// Mancha grande de humedad: centro (0-1), radio en píxeles e intensidad.
uniform vec4 blot = vec4(0.0, 0.0, 0.0, 0.0);
// Motas de óxido repartidas por el papel.
uniform float foxing = 1.0;

// Hash sin `sin()`, como el del pergamino: evita el ruido escalonado en argumentos grandes.
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

// Cada octava gira el dominio: sin el giro, las manchas grandes dejan aristas rectas en las
// juntas de la rejilla del ruido.
float fbm(vec2 p) {
	const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float total = 0.0;
	float weight = 0.5;
	p = turn * p;
	for (int octave = 0; octave < 4; octave++) {
		total += noise(p) * weight;
		p = turn * p * 2.07 + vec2(3.1, 7.7);
		weight *= 0.5;
	}
	return total;
}

// Distancia con signo a un rectángulo centrado en el origen: negativa dentro.
float box(vec2 p, vec2 half_size) {
	vec2 q = abs(p) - half_size;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// Pliegue a una distancia `d` (con signo) de su línea: el surco oscuro, el brillo del lomo y una
// leve sombra a un lado, como un papel que se ha doblado y vuelto a abrir.
vec3 crease(vec3 color, float d, float fine, vec3 light) {
	float groove = exp(-d * d / 3.2);
	float ridge = exp(-(d - 2.6) * (d - 2.6) / 5.0);
	float broad = exp(-abs(d) / 38.0);
	color *= 1.0 - 0.2 * groove * fold_strength;
	color = mix(color, light, 0.22 * ridge * fold_strength);
	color *= 1.0 - (d < 0.0 ? 0.06 : -0.025) * broad * fold_strength;
	// El papel se gasta a lo largo del pliegue.
	color = mix(color, light, 0.1 * exp(-d * d / 60.0) * fine * fold_strength);
	return color;
}

void fragment() {
	vec2 pixel = UV * rect_size;
	vec2 paper_size = max(rect_size - vec2(shadow_margin) * 2.0, vec2(1.0));
	vec2 p = pixel - vec2(shadow_margin);
	vec2 center = paper_size * 0.5;
	vec2 offset = vec2(seed * 37.0, seed * 19.0);

	// Borde rasgado: el contorno entra más o menos según el ruido, con algún mordisco mayor.
	float edge_noise = fbm(p / 24.0 + offset);
	float fiber_noise = noise(p / 5.0 + offset * 1.7);
	float bite = smoothstep(0.6, 0.78, fbm(p / 95.0 + offset * 0.5)) * chunks;
	float recess = tear * (0.55 + 0.9 * edge_noise) + tear * 0.35 * (fiber_noise - 0.5) + tear * 2.2 * bite;
	float inside = -box(p - center, center) - recess;
	float paper_alpha = smoothstep(-0.7, 0.7, inside);

	// Papel: más claro en el centro, con manchas amplias, grano, fibras y motas.
	vec2 from_center = (p - center) / center;
	float glow = 1.0 - smoothstep(0.15, 1.15, length(from_center * vec2(0.85, 1.0)));
	vec3 color = mix(base_color.rgb, light_color.rgb, glow * 0.7);
	float blotch = fbm(p / 170.0 + offset * 0.3);
	color = mix(color, stain_color.rgb, smoothstep(0.42, 0.85, blotch) * 0.38);
	float fine = fbm(p / 3.2 + offset);
	color *= 0.94 + 0.11 * fine;
	color *= 0.985 + 0.03 * noise(vec2(p.x / 2.2, p.y / 38.0) + offset);
	// Motas de óxido: puntos redondos de tamaño variable, agrupados en algunas zonas.
	vec2 spot_cell = floor(p / 24.0);
	vec2 spot_center = (spot_cell + 0.2 + 0.6 * vec2(hash(spot_cell + 3.1 + seed), hash(spot_cell + 7.7 + seed))) * 24.0;
	float spot_radius = mix(1.2, 4.2, hash(spot_cell + 11.0 + seed));
	float spot = step(0.8, hash(spot_cell + 17.0 + seed)) * (1.0 - smoothstep(spot_radius * 0.45, spot_radius, length(p - spot_center)));
	spot *= smoothstep(0.38, 0.62, fbm(p / 90.0 - offset));
	color = mix(color, mix(stain_color.rgb, edge_color.rgb, 0.45), spot * 0.55 * foxing);

	// Pliegues verticales y horizontales, con un leve temblor para que no parezcan reglas.
	for (int i = 0; i < 4; i++) {
		if (folds_x[i] >= 0.0) {
			float d = p.x - folds_x[i] * paper_size.x + (noise(vec2(p.y / 55.0, float(i) * 3.0 + seed)) - 0.5) * 4.0;
			color = crease(color, d, fine, light_color.rgb);
		}
		if (folds_y[i] >= 0.0) {
			float d = p.y - folds_y[i] * paper_size.y + (noise(vec2(p.x / 55.0, float(i) * 5.0 + seed)) - 0.5) * 4.0;
			color = crease(color, d, fine, light_color.rgb);
		}
	}

	// Mancha grande de humedad, con la marca más oscura donde se secó el agua.
	if (blot.w > 0.0) {
		float wobble = (fbm(p / 45.0 + offset) - 0.5) * blot.z * 0.7;
		float distance_to_blot = length(p - blot.xy * paper_size) + wobble;
		float body = 1.0 - smoothstep(blot.z * 0.55, blot.z, distance_to_blot);
		float tide = exp(-pow((distance_to_blot - blot.z * 0.88) / (blot.z * 0.05), 2.0));
		color = mix(color, stain_color.rgb * 0.72, (body * 0.4 + tide * 0.35) * blot.w);
	}

	// Cerco de una taza: un anillo irregular, interrumpido, con el interior apenas teñido.
	if (ring.w > 0.0) {
		vec2 to_ring = p - ring.xy * paper_size;
		float radius = length(to_ring);
		float angle = atan(to_ring.y, to_ring.x);
		float wobble = (noise(vec2(angle * 2.5, seed * 11.0)) - 0.5) * ring.z * 0.06;
		float band = abs(radius - ring.z - wobble);
		float stroke = exp(-band * band / 9.0) + 0.5 * exp(-pow(abs(radius - ring.z * 0.93 - wobble), 2.0) / 4.0);
		float gaps = smoothstep(0.2, 0.55, noise(vec2(angle * 1.6 + 4.0, seed * 3.0)));
		float tint = (1.0 - smoothstep(ring.z * 0.7, ring.z, radius)) * 0.12;
		color = mix(color, stain_color.rgb * 0.7, clamp(stroke * gaps * 0.55 + tint, 0.0, 1.0) * ring.w);
	}

	// Borde quemado y envejecido, más hondo en las esquinas, con un filo oscuro.
	float burn = 1.0 - smoothstep(0.0, edge_width, inside + (blotch - 0.5) * edge_width * 0.7);
	color = mix(color, edge_color.rgb, burn * burn * 0.62);
	float rim = 1.0 - smoothstep(0.0, 2.8, inside);
	color = mix(color, edge_color.rgb * 0.7, rim * 0.55);

	// Sombra suave alrededor, desplazada hacia abajo.
	float shadow_inside = -box(pixel - vec2(shadow_margin) - shadow_offset - center, center);
	float shadow = clamp(1.0 + shadow_inside / (shadow_margin * 0.85), 0.0, 1.0);
	float shadow_alpha = shadow * shadow * shadow_color.a * (1.0 - paper_alpha);
	float alpha = paper_alpha + shadow_alpha;
	COLOR = vec4(mix(shadow_color.rgb, color, paper_alpha / max(alpha, 0.0001)), alpha);
}
