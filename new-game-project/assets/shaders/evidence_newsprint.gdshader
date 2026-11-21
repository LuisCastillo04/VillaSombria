shader_type canvas_item;
// Impresión de periódico de los años cuarenta a partir de un grabado con fondo transparente
// (`art_texture`): trama de puntos a 45° en tinta sobre papel.
//
// Con `night` a 1 es una fotografía nocturna que llena todo el rectángulo: lo que el grabado deja
// transparente pasa a ser un cielo oscuro con nubes, los muros y tejados se oscurecen y las ventanas
// amarillas quedan encendidas. Con `night` a 0 es una viñeta impresa: sólo se entinta el dibujo y el
// resto queda transparente, para asentarla sobre el papel del periódico.
//
// `art_rect` coloca el grabado dentro del rectángulo (posición y tamaño en píxeles del documento) y
// `rect_size` es el tamaño del rectángulo. La trama se calcula en esos mismos píxeles, así que el
// punto mide siempre lo mismo respecto al papel, se escale como se escale el documento.

uniform sampler2D art_texture : source_color, filter_linear_mipmap;
uniform vec4 art_rect = vec4(0.0, 0.0, 420.0, 320.0);
uniform vec2 rect_size = vec2(420.0, 320.0);
uniform vec4 ink_color : source_color = vec4(0.12, 0.09, 0.07, 1.0);
uniform vec4 paper_color : source_color = vec4(0.84, 0.77, 0.62, 1.0);
uniform float night = 1.0;
// Separación de los puntos de la trama, en píxeles del documento.
uniform float dot_spacing = 4.4;
uniform float seed = 2.0;

varying vec2 local;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 art_uv = (local - art_rect.xy) / art_rect.zw;
	vec4 art = vec4(0.0);
	if (art_uv.x >= 0.0 && art_uv.x <= 1.0 && art_uv.y >= 0.0 && art_uv.y <= 1.0) {
		art = texture(art_texture, art_uv);
	}
	float luminance = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	float saturation = max(art.r, max(art.g, art.b)) - min(art.r, min(art.g, art.b));
	// Las ventanas y su resplandor son lo único amarillo y saturado del grabado.
	float lit = smoothstep(0.22, 0.42, saturation) * smoothstep(0.6, 0.85, art.r) * art.a;
	vec2 uv = local / rect_size;

	// Tono de 0 (papel) a 1 (tinta).
	float tone;
	if (night > 0.5) {
		float clouds = noise(local / 70.0 + seed) * 0.6 + noise(local / 26.0 - seed) * 0.4;
		float sky = mix(0.9, 0.62, uv.y) - clouds * 0.2;
		float building = clamp(0.95 - luminance * 0.68, 0.0, 1.0);
		tone = mix(sky, building, art.a);
		tone = mix(tone, 0.05, lit);
		// Viñeta de fotografía antigua.
		tone = mix(tone, 1.0, smoothstep(0.38, 0.78, length(uv - 0.5)) * 0.55);
	} else {
		tone = clamp((1.0 - luminance) * 1.15, 0.0, 1.0) * art.a;
	}

	// Trama a 45°: puntos cuyo área crece con el tono, suavizados un píxel de pantalla.
	vec2 grid = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * local / dot_spacing;
	float distance_to_dot = length(fract(grid) - 0.5);
	float radius = sqrt(clamp(tone, 0.0, 1.0)) * 0.68;
	float aa = max(fwidth(distance_to_dot), 0.02);
	float dot_cover = 1.0 - smoothstep(radius - aa, radius + aa, distance_to_dot);
	// Donde la tinta casi cubre del todo, se cierra la trama.
	dot_cover = max(dot_cover, smoothstep(0.88, 0.98, tone));

	if (night > 0.5) {
		COLOR = vec4(mix(paper_color.rgb, ink_color.rgb, dot_cover), 1.0);
	} else {
		COLOR = vec4(ink_color.rgb, dot_cover * smoothstep(0.02, 0.12, tone));
	}
}
