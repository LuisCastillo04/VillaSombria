shader_type spatial;
render_mode unshaded;

uniform float energy = 2.4;

void fragment() {
	vec3 linear_color = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = linear_color * energy;
}
