shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Telhado de sapê (quiosques, palafitas e portal da praia): palha em camadas, com os
// fios descendo pela água do telhado e uma sombra embaixo da beirada de cada camada.
// UV.x = metros ao longo da beirada; UV.y = metros descendo do topo (track_beach.gd).

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"

uniform vec3 straw_light : source_color = vec3(0.88, 0.72, 0.43);
uniform vec3 straw_dark : source_color = vec3(0.56, 0.41, 0.22);
// Altura (m, pela água do telhado) de cada camada de palha.
uniform float tier = 0.6;

void fragment() {
	vec2 p = UV;
	float lod = clamp(length(fwidth(p)) * 4.0, 0.0, 1.0);
	// Fios de palha: ruído esticado na direção da água do telhado.
	float strand = mix(tnoise(vec2(p.x * 16.0, p.y * 0.8)), 0.5, lod);
	float fine = mix(tnoise(vec2(p.x * 41.0, p.y * 1.6) + 9.0), 0.5, lod);
	float clump = tnoise(p * vec2(1.2, 0.5) + 7.0);
	// Camadas: a ponta de cada camada fica por cima do começo da de baixo (sombra).
	float t = fract(p.y / tier + (clump - 0.5) * 0.25);
	float shade = 0.62 + 0.38 * smoothstep(0.0, 0.3, t);
	vec3 col = mix(straw_dark, straw_light, clamp(0.2 + 0.55 * strand + 0.25 * fine + 0.35 * (clump - 0.5), 0.0, 1.0));
	col *= shade;
	// Palha mais nova (clara) e mais velha (cinzenta) em manchas.
	col = mix(col, col * vec3(0.86, 0.86, 0.9), smoothstep(0.6, 0.85, tnoise(p * 0.35 + 3.0)) * 0.6);
	if (!FRONT_FACING) {
		// Por baixo do telhado: palha na sombra.
		col *= 0.55;
	}
	vec2 slope = vec2((strand - 0.5) * 0.5, -0.35 * (1.0 - smoothstep(0.0, 0.25, t))) * (1.0 - lod);
	NORMAL_MAP = normalize(vec3(-slope.x, -slope.y, 1.0)) * 0.5 + 0.5;
	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.18;
}
