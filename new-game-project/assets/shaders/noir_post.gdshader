shader_type canvas_item;
// Postproceso en pantalla: niebla a la deriva, viñeta y grano de película.
// Sustituye a la niebla volumétrica, que no admite cámaras ortográficas.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.22;
uniform vec3 fog_color : source_color = vec3(0.32, 0.38, 0.5);
uniform float vignette : hint_range(0.0, 2.0) = 0.95;
uniform float grain : hint_range(0.0, 0.2) = 0.035;

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
		total += noise(p) * weight;
		p = p * 2.03 + vec2(1.7, 9.2);
		weight *= 0.5;
	}
	return total;
}

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;

	vec2 drift = vec2(TIME * 0.012, TIME * 0.005);
	float mist = fbm(SCREEN_UV * vec2(2.6, 3.4) + drift);
	mist = smoothstep(0.3, 0.8, mist);
	color = mix(color, fog_color, mist * fog_amount);

	vec2 centered = SCREEN_UV - 0.5;
	float falloff = dot(centered, centered) * vignette * 1.6;
	color *= clamp(1.0 - falloff, 0.0, 1.0);

	float speckle = hash(SCREEN_UV * 913.0 + fract(TIME) * 37.0) - 0.5;
	color += speckle * grain;

	COLOR = vec4(color, 1.0);
}
