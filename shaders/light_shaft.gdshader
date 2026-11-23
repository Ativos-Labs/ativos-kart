shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Raio de sol entrando na água (quads cruzados): claro no alto, sumindo para o fundo e
// nas bordas, tremulando devagar. UV.y = 0 na superfície, 1 no fundo. Só aparece com
// a câmera debaixo d'água (de cima a água já mostra o brilho do sol).

#include "res://shaders/noise.gdshaderinc"

uniform vec3 color : source_color = vec3(0.55, 0.9, 0.95);
uniform float strength = 0.11;
uniform float water_level = 0.0;

varying float seed;

void vertex() {
	seed = MODEL_MATRIX[3].x * 0.13 + MODEL_MATRIX[3].z * 0.07;
}

void fragment() {
	if (INV_VIEW_MATRIX[3].y > water_level) {
		discard;
	}
	float x = UV.x * 2.0 - 1.0;
	float across = exp(-x * x * 6.0);
	float stripes = vnoise(vec2(UV.x * 5.0 + seed, TIME * 0.22 + seed));
	float fade = (1.0 - smoothstep(0.0, 1.0, UV.y)) * smoothstep(0.0, 0.08, UV.y);
	// Some de perto (sem "placa" na frente da câmera).
	float near = smoothstep(2.0, 9.0, length(VERTEX));
	float a = across * fade * fade * (0.35 + 0.65 * stripes) * near;
	ALBEDO = color * a * strength;
	ALPHA = 1.0;
}
