shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;
// Água dos lagos: azul-turquesa que escurece com a profundidade, ondinhas,
// brilho do sol e espuma branca na beirada.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.22, 0.86, 0.86);
uniform vec3 deep_color : source_color = vec3(0.02, 0.33, 0.72);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform float depth_range = 3.5;
uniform float foam_width = 0.55;
// 1 = gelo (lago congelado): sem ondas, com rachaduras e neve fina por cima.
uniform float ice = 0.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Inclinação das ondas (d/dx, d/dz): derivada analítica das 3 camadas de ruído.
// Antes eram 3 avaliações da altura (9 ruídos) para uma diferença finita.
vec2 wave_slope(vec2 p) {
	vec2 g = vnoise_d(p * 0.35 + TIME * vec2(0.18, 0.11)).yz * (0.6 * 0.35);
	g += vnoise_d(p * 0.9 - TIME * vec2(0.22, 0.3)).yz * (0.3 * 0.9);
	g += vnoise_d(p * 2.3 + TIME * vec2(0.4, -0.25)).yz * (0.1 * 2.3);
	return g;
}

void fragment() {
	float scene_depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth_raw, 1.0);
	view.xyz /= view.w;
	float water_depth = max(-view.z - (-VERTEX.z), 0.0);
	float depth_f = clamp(water_depth / depth_range, 0.0, 1.0);

	vec2 p = world_pos.xz;
	if (ice > 0.5) {
		vec3 icol = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, depth_f));
		float frost = fbm(p * 0.08, 3);
		icol = mix(icol, vec3(0.95, 0.97, 1.0), smoothstep(0.45, 0.75, frost) * 0.7);
		// Rachaduras: linhas finas onde o ruído passa pelo meio.
		float c1 = abs(vnoise(p * 0.11) - 0.5);
		float c2 = abs(vnoise(p * 0.27 + 7.3) - 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.012, c1)) * 0.6 + (1.0 - smoothstep(0.0, 0.008, c2)) * 0.35;
		icol = mix(icol, deep_color * 0.7, crack * (1.0 - smoothstep(0.55, 0.8, frost)));
		vec3 inorm = normalize(vec3((vnoise(p * 0.6) - 0.5) * 0.06, 1.0, (vnoise(p * 0.6 + 3.1) - 0.5) * 0.06));
		NORMAL = normalize((VIEW_MATRIX * vec4(inorm, 0.0)).xyz);
		ALBEDO = icol;
		ALPHA = clamp(mix(0.82, 0.98, depth_f), 0.0, 1.0);
		ROUGHNESS = mix(0.12, 0.6, smoothstep(0.45, 0.75, frost));
		SPECULAR = 0.6;
	} else {
	vec2 g = wave_slope(p) * 0.35;
	vec3 wn = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	// Fresnel: de lado a água reflete mais o céu e deixa ver menos o fundo.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);

	vec3 col = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, depth_f));
	float ripple = vnoise(p * 1.4 + TIME * 0.35);
	float foam_line = 1.0 - smoothstep(0.0, foam_width, water_depth + (sin(TIME * 1.6 + p.x * 0.5 + p.y * 0.3) * 0.5 + 0.5) * 0.18);
	float foam = foam_line * smoothstep(0.3, 0.55, ripple + foam_line * 0.4);
	ALBEDO = mix(col, foam_color, foam);
	ALPHA = clamp(mix(0.55, 0.96, depth_f) + foam + fresnel * 0.4, 0.0, 1.0);
	ROUGHNESS = mix(0.04, 0.5, foam);
	SPECULAR = 0.7;
	}
}
