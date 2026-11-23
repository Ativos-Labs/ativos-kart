shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_never, shadows_disabled;
// Superfície da água vista de baixo (só a face de baixo aparece): clara olhando para
// cima (a janela do céu) e espelhada de lado, com a ondulação brilhando.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.05, 0.4, 0.5);
uniform vec3 bright_color : source_color = vec3(0.75, 0.97, 1.0);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float up = abs(dot(normalize(NORMAL), VIEW));
	float c = caustics(wp.xz * 0.8, TIME * 0.8);
	float window = smoothstep(0.45, 0.95, up);
	vec3 col = mix(deep_color, bright_color, window * 0.75 + c * 0.35);
	ALBEDO = col;
	ALPHA = mix(0.75, 0.92, 1.0 - window);
}
