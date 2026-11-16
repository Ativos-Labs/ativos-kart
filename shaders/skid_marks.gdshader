shader_type spatial;
// Marcas de pneu no chão (veja scripts/skid_marks.gd). Cada vértice já vem no espaço
// do mundo. COLOR = cor da marca (alfa = força), UV.x = atravessando a faixa (0..1),
// UV.y = instante em que o trecho foi riscado. A marca some aos poucos com a idade.
render_mode blend_mix, depth_draw_never, cull_disabled, world_vertex_coords, specular_disabled, shadows_disabled;

// Relógio da corrida (s), atualizado pelo script.
uniform float now = 0.0;
// Tempo de vida da marca (s): começa a sumir em 55% disso.
uniform float life = 9.0;

#include "res://shaders/noise.gdshaderinc"

varying float v_alpha;
varying vec3 v_color;

void vertex() {
	float age = now - UV.y;
	v_alpha = COLOR.a * (1.0 - smoothstep(life * 0.55, life, age));
	if (age > life || COLOR.a <= 0.0) {
		// Trecho vencido (ou ainda vazio): triângulo sem área, nada é desenhado.
		VERTEX = vec3(0.0);
	} else {
		// Um pouco na direção da câmera: não briga com o asfalto (z-fighting).
		VERTEX += normalize(CAMERA_POSITION_WORLD - VERTEX) * 0.04;
	}
	NORMAL = vec3(0.0, 1.0, 0.0);
	// A cor vem em sRGB; o Compatibility (web) usa a cor como está (veja character.gdshader).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	v_color = COLOR.rgb;
#else
	v_color = srgb_to_linear(COLOR.rgb);
#endif
}

void fragment() {
	// Bordas da faixa suaves.
	float edge = smoothstep(0.0, 0.32, UV.x) * smoothstep(1.0, 0.68, UV.x);
	ALBEDO = v_color;
	ROUGHNESS = 0.95;
	ALPHA = v_alpha * edge;
}
