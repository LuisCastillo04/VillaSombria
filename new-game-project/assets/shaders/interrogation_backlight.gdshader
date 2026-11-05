shader_type canvas_item;
// Ventana esmerilada a contraluz detrás de la silueta: halo ámbar y sombras de persiana.

uniform vec3 warm_color : source_color = vec3(0.95, 0.62, 0.24);
uniform vec3 cold_color : source_color = vec3(0.08, 0.1, 0.16);
uniform float intensity : hint_range(0.0, 1.5) = 1.0;
uniform float blinds : hint_range(0.0, 60.0) = 26.0;

void fragment() {
	vec2 centered = UV - vec2(0.5, 0.46);
	centered.x *= 1.15;
	float halo = 1.0 - smoothstep(0.05, 0.62, length(centered));
	float slats = smoothstep(0.32, 0.5, abs(fract(UV.y * blinds) - 0.5));
	float flicker = 0.97 + 0.03 * sin(TIME * 2.3) * sin(TIME * 0.9);
	vec3 color = mix(cold_color, warm_color, halo * halo * flicker);
	color *= mix(0.72, 1.0, slats);
	float edge = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x);
	edge *= smoothstep(0.0, 0.1, UV.y) * smoothstep(1.0, 0.92, UV.y);
	COLOR = vec4(color, edge * intensity * (0.35 + 0.65 * halo));
}
