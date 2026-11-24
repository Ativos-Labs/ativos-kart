shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;
// Água dos lagos: azul-turquesa que escurece com a profundidade, ondinhas,
// brilho do sol e espuma branca na beirada. Com `ice`, rio/lago congelado (o mesmo gelo
// da pista de gelo, veja ice.gdshaderinc), com neve na margem.

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"
#include "res://shaders/ice.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.22, 0.86, 0.86);
uniform vec3 deep_color : source_color = vec3(0.02, 0.33, 0.72);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform float depth_range = 3.5;
uniform float foam_width = 0.55;
// 1 = gelo (lago congelado): sem ondas, com rachaduras e neve fina por cima.
uniform float ice = 0.0;
// Espuma pela profundidade de verdade (na vertical) e não pela distância até o fundo
// ao longo da vista: no baixio da praia (lâmina de ~20 cm por cima da pista) a água
// rasa ficaria toda branca perto da câmera. Com isso a espuma só aparece na beirada.
uniform bool vertical_foam = false;
// Praia (com vertical_foam): cor pela profundidade de verdade, faixa turquesa entre o
// raso e o fundo, ondinhas de espuma chegando na areia e o brilho do sol na água.
uniform vec3 lagoon_color : source_color = vec3(0.0, 0.55, 0.66);
uniform vec3 sun_dir = vec3(0.43, 0.64, 0.63);
uniform float glitter = 0.0;
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
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// No Compatibility (web) a profundidade vai de 0 a 1 e o NDC de -1 a 1 (no
	// Forward+ o Z já é o do NDC): sem isso a água inteira virava espuma branca.
	scene_depth_raw = scene_depth_raw * 2.0 - 1.0;
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth_raw, 1.0);
	view.xyz /= view.w;
	float water_depth = max(-view.z - (-VERTEX.z), 0.0);
	float depth_f = clamp(water_depth / depth_range, 0.0, 1.0);
	float foam_depth = water_depth;
	if (vertical_foam) {
		foam_depth = max(world_pos.y - (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).y, 0.0);
	}

	vec2 p = world_pos.xz;
	if (ice > 0.5) {
		// Gelo sem correnteza definida: as riscas ficam num ângulo qualquer.
		vec2 ax = vec2(0.8, 0.6);
		vec2 ay = vec2(-0.6, 0.8);
		vec2 q = vec2(dot(p, ax), dot(p, ay));
		vec3 ray = normalize(world_pos - CAMERA_POSITION_WORLD);
		float lod = clamp(length(fwidth(p)) * 5.0, 0.0, 1.0);
		vec3 icol;
		float irough;
		float ispec;
		vec3 iemit;
		// Neve na margem: onde o gelo é raso (perto do chão).
		ice_shade(q, ray, ax, ay, water_depth * 4.0, lod, TIME, 0.3, shallow_color, deep_color, icol, irough, ispec, iemit);
		vec3 inorm = normalize(vec3((vnoise(p * 0.6) - 0.5) * 0.04, 1.0, (vnoise(p * 0.6 + 3.1) - 0.5) * 0.04));
		NORMAL = normalize((VIEW_MATRIX * vec4(inorm, 0.0)).xyz);
		ALBEDO = icol;
		ALPHA = clamp(mix(0.86, 0.98, depth_f), 0.0, 1.0);
		ROUGHNESS = irough;
		SPECULAR = ispec;
		EMISSION = iemit;
	} else {
	vec2 g = wave_slope(p) * 0.35;
	vec3 wn = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	// Fresnel: de lado a água reflete mais o céu e deixa ver menos o fundo.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);

	vec3 col = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, depth_f));
	float ripple = vnoise(p * 1.4 + TIME * 0.35);
	float foam_line = 1.0 - smoothstep(0.0, foam_width, foam_depth + (sin(TIME * 1.6 + p.x * 0.5 + p.y * 0.3) * 0.5 + 0.5) * (vertical_foam ? 0.06 : 0.18));
	float foam = foam_line * smoothstep(0.3, 0.55, ripple + foam_line * 0.4);
	vec3 glint = vec3(0.0);
	if (vertical_foam) {
		// Raso (água-marinha) → turquesa → azul do fundo, pela profundidade na vertical;
		// de lado (caminho longo dentro d'água) puxa um pouco mais para o fundo.
		float vd = foam_depth + depth_f * 1.2;
		col = mix(shallow_color, lagoon_color, smoothstep(0.4, 2.6, vd));
		col = mix(col, deep_color, smoothstep(2.4, 7.0, vd));
		// Ondinhas chegando na areia: faixas de espuma que andam para a beira e somem.
		float wobble = vnoise(p * 0.08 + TIME * 0.05) * 6.0;
		float wave = fract(foam_depth * 1.6 - TIME * 0.28 + wobble);
		float crest = smoothstep(0.78, 0.9, wave) * (1.0 - smoothstep(0.9, 0.97, wave));
		float near_shore = 1.0 - smoothstep(0.15, 1.1, foam_depth);
		foam = max(foam, crest * near_shore * smoothstep(0.25, 0.6, ripple + 0.2) * 0.85);
		// Brilho do sol: pontinhos onde a ondinha reflete o sol direto no olho.
		if (glitter > 0.0) {
			vec2 gs = wave_slope(p * 3.1 + 7.0) * 0.6;
			vec3 gn = normalize(vec3(-g.x - gs.x, 1.0, -g.y - gs.y));
			vec3 view_w = normalize(CAMERA_POSITION_WORLD - world_pos);
			float sp = max(dot(reflect(-normalize(sun_dir), gn), view_w), 0.0);
			float sparkle = pow(sp, 320.0) * step(0.55, vnoise(p * 6.0 + TIME * 1.7));
			glint = vec3(1.0, 0.97, 0.88) * sparkle * glitter * (1.0 - foam);
		}
	}
	ALBEDO = mix(col, foam_color, foam);
	if (vertical_foam) {
		// Praia: água rasa bem transparente (vê-se a areia e as cáusticas do fundo).
		ALPHA = clamp(mix(0.3, 0.94, smoothstep(0.0, 3.5, foam_depth)) + foam + fresnel * 0.25, 0.0, 1.0);
		ROUGHNESS = mix(0.07, 0.5, foam);
		SPECULAR = 0.5;
		EMISSION = glint;
	} else {
		ALPHA = clamp(mix(0.55, 0.96, depth_f) + foam + fresnel * 0.4, 0.0, 1.0);
		ROUGHNESS = mix(0.04, 0.5, foam);
		SPECULAR = 0.7;
	}
	}
}
