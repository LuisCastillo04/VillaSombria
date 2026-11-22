shader_type canvas_item;
// Postproceso en pantalla: niebla a la deriva, filtro de color, viñeta y grano de película.
// Sustituye a la niebla volumétrica, que no admite cámaras ortográficas.
// Se dibuja en una capa por debajo de toda la interfaz (PostFx), así que sólo transforma el mundo.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.22;
uniform vec3 fog_color : source_color = vec3(0.32, 0.38, 0.5);
uniform float vignette : hint_range(0.0, 2.0) = 0.95;
uniform float grain : hint_range(0.0, 0.2) = 0.035;
// Capas de ruido de la niebla. Con 4 (calidad alta) el resultado es el original; con menos se
// calcula menos y se compensa la suma para que la niebla cubra lo mismo.
uniform int fog_octaves : hint_range(1, 4) = 4;

// --- Filtro de color (Configuración → Filtros) ---
// Los valores de cada filtro están en VisualFilters (scripts/settings/visual_filters.gd), que los
// cambia en este mismo material: ni pasada ni textura extra. Los valores por defecto dejan la imagen
// tal cual, y con grade_amount a 0 (Colores originales, y las imágenes de las ranuras, que crean su
// propio material) no se calcula nada.
// Cuánto se aplica el filtro: 0 nada, 1 entero.
uniform float grade_amount : hint_range(0.0, 1.0) = 0.0;
// Parte del color original que se conserva: 0 es blanco y negro; 1, el color de siempre.
uniform float grade_saturation : hint_range(0.0, 1.0) = 1.0;
// Pendiente de la curva en S de la luminancia en grade_pivot: más de 1 hunde las sombras y aclara las
// luces sin recortar el negro ni el blanco; 1 no cambia nada.
uniform float grade_contrast : hint_range(0.5, 3.0) = 1.0;
uniform float grade_pivot : hint_range(0.05, 0.95) = 0.5;
// Luminancia a la que llegan el negro y el blanco: un negro algo levantado envejece la imagen.
uniform float grade_lift : hint_range(0.0, 0.3) = 0.0;
uniform float grade_gain : hint_range(0.5, 1.2) = 1.0;
// Tono de las sombras y de las luces. Multiplican la luminancia y la suya es casi 1, así que tiñen
// sin aclarar ni oscurecer.
uniform vec3 grade_shadow_tint = vec3(1.0);
uniform vec3 grade_highlight_tint = vec3(1.0);
// Luminancia en la que los dos tintes pesan lo mismo. Más baja, el tinte de las sombras se queda en
// las sombras y los tonos medios (las farolas) toman el de las luces.
uniform float grade_balance : hint_range(0.1, 0.9) = 0.5;

// Pesos de la luminancia (Rec. 709) sobre los valores de pantalla.
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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
		if (octave >= fog_octaves) {
			break;
		}
		total += noise(p) * weight;
		p = p * 2.03 + vec2(1.7, 9.2);
		weight *= 0.5;
	}
	// Peso máximo de las 4 capas (0.9375) entre el de las usadas: 1.0 con las 4.
	return total * 0.9375 / (1.0 - pow(0.5, float(fog_octaves)));
}

// Curva en S partida en el pivote: dos potencias que se unen allí con la misma pendiente, de modo
// que el contraste crece sin escalones y el 0 y el 1 se quedan donde están.
float contrast_curve(float x) {
	float below = grade_pivot * pow(x / grade_pivot, grade_contrast);
	float above = 1.0 - (1.0 - grade_pivot) * pow((1.0 - x) / (1.0 - grade_pivot), grade_contrast);
	return x < grade_pivot ? below : above;
}

// Corrección de color: la luminancia pasa por la curva, se lleva al negro y al blanco elegidos y se
// tiñe según sea sombra o luz; encima se suma la parte del color original que se conserva, en
// proporción a la nueva luminancia para no cambiar su tono. Las diferencias de luz entre materiales
// se mantienen porque la curva nunca se aplana.
vec3 color_grade(vec3 color) {
	float luma = dot(color, LUMA);
	float tone = mix(grade_lift, grade_gain, contrast_curve(clamp(luma, 0.0, 1.0)));
	vec3 tint = mix(grade_shadow_tint, grade_highlight_tint, smoothstep(0.0, 2.0 * grade_balance, tone));
	vec3 chroma = (color - vec3(luma)) * grade_saturation * clamp(tone / max(luma, 0.001), 0.0, 2.0);
	return clamp(tone * tint + chroma, 0.0, 1.0);
}

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;

	vec2 drift = vec2(TIME * 0.012, TIME * 0.005);
	float mist = fbm(SCREEN_UV * vec2(2.6, 3.4) + drift);
	mist = smoothstep(0.3, 0.8, mist);
	color = mix(color, fog_color, mist * fog_amount);

	// El filtro va después de la niebla (que es parte del mundo) y antes de la viñeta y el grano,
	// para que estos se vean igual con cualquier filtro.
	if (grade_amount > 0.0) {
		color = mix(color, color_grade(color), grade_amount);
	}

	vec2 centered = SCREEN_UV - 0.5;
	float falloff = dot(centered, centered) * vignette * 1.6;
	color *= clamp(1.0 - falloff, 0.0, 1.0);

	if (grain > 0.0) {
		float speckle = hash(SCREEN_UV * 913.0 + fract(TIME) * 37.0) - 0.5;
		color += speckle * grain;
	}

	COLOR = vec4(color, 1.0);
}
