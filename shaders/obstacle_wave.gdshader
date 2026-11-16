shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
// Onda do mar que atravessa a pista na Ilha (veja scripts/track_obstacles.gd).
// Malha: perfil da onda (UV.x: 0 = costas, ~0.85 = crista, 1 = frente) ao longo do
// trecho (UV.y: 0..1). A crista e a frente espumam; as costas e as pontas somem
// transparentes. `strength` (0..1) vem do script: a onda nasce, quebra e some.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.24, 0.93, 0.86);
uniform vec3 deep_color : source_color = vec3(0.0, 0.42, 0.78);
uniform vec3 foam_color : source_color = vec3(0.97, 0.99, 1.0);
uniform float strength = 1.0;

void vertex() {
	// Ondulação da crista ao longo do trecho.
	float wob = sin(UV.y * 19.0 + TIME * 3.1) * 0.5 + sin(UV.y * 7.0 - TIME * 1.7) * 0.5;
	VERTEX.y += wob * 0.06 * smoothstep(0.4, 0.9, UV.x);
}

void fragment() {
	float x = UV.x;
	float along = UV.y;
	// Corpo: escuro embaixo, turquesa claro perto da crista (luz atravessando).
	float lift = smoothstep(0.1, 0.85, x);
	vec3 col = mix(deep_color, shallow_color, lift);
	// Espuma na crista e escorrendo pela frente, mexendo com o tempo.
	float n = fbm(vec2(along * 26.0 - TIME * 0.6, x * 9.0 + TIME * 1.4), 3);
	float crest = smoothstep(0.7, 0.86, x) * smoothstep(0.35, 0.6, n + 0.25);
	float front = smoothstep(0.9, 1.0, x) * smoothstep(0.3, 0.55, n);
	float streaks = smoothstep(0.62, 0.7, vnoise(vec2(along * 60.0, x * 4.0 - TIME * 0.8))) * smoothstep(0.45, 0.8, x);
	float foam = clamp(crest + front + streaks * 0.6, 0.0, 1.0);
	col = mix(col, foam_color, foam);
	ALBEDO = col;
	ROUGHNESS = mix(0.06, 0.7, foam);
	SPECULAR = 0.6;
	// Some nas costas e nas pontas do trecho.
	float ends = smoothstep(0.0, 0.18, along) * smoothstep(1.0, 0.82, along);
	float back = smoothstep(0.0, 0.3, x);
	ALPHA = clamp((0.72 + foam * 0.28) * back * ends * strength, 0.0, 1.0);
}
