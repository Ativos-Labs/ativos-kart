shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Rampa de pulo: topo azul com o logo "at" pintado no começo e setas amarelas no
// formato da seta do logo apontando para a borda (na rampa de turbo, setas laranja
// acesas correndo), faixas brancas nas laterais e zebrado na borda.
// COLOR.r = topo, COLOR.g = saias laterais, COLOR.b = face da borda.
// Topo: UV.x = 0..1 da esquerda para a direita; UV.y = metros desde o começo.
// Saias: UV.x = metros descendo a partir do topo; UV.y = metros desde o começo.
// Borda: UV.x = metros ao longo da borda; UV.y = metros de altura.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.149, 0.239, 0.749);
uniform vec3 navy : source_color = vec3(0.059, 0.094, 0.22);
uniform vec3 yellow : source_color = vec3(1.0, 0.824, 0.102);
uniform vec3 white : source_color = vec3(0.95, 0.96, 1.0);
uniform vec3 turbo_a : source_color = vec3(1.0, 0.42, 0.0);
uniform vec3 turbo_b : source_color = vec3(1.0, 0.9, 0.2);
uniform float ramp_length = 10.0;
uniform float ramp_width = 13.6;
uniform bool turbo = false;
uniform float turbo_glow = 1.3;
uniform sampler2D logo : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float logo_aspect = 1.643;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Onda quadrada 0/1 (meio período cada) com as bordas suavizadas.
float square(float x) {
	float w = max(fwidth(x) * 1.2, 1e-4);
	return clamp((0.25 - abs(fract(x) - 0.5)) / w + 0.5, 0.0, 1.0);
}

// 1 dentro de [a, b] com as bordas suavizadas.
float span(float x, float a, float b) {
	float w = max(fwidth(x), 1e-4);
	return clamp((x - a) / w + 0.5, 0.0, 1.0) * clamp((b - x) / w + 0.5, 0.0, 1.0);
}

void fragment() {
	vec3 part = COLOR.rgb;
	vec3 col;
	vec3 emit = vec3(0.0);
	float rough = 0.55;
	if (part.r > 0.5) {
		// --- Topo -----------------------------------------------------------------
		float v = UV.y;
		float x = (UV.x - 0.5) * ramp_width;
		col = turbo ? navy * 1.4 : base_color;
		// Setas (bico no meio, apontando para a borda).
		float from = turbo ? ramp_length * 0.08 : ramp_length * 0.45;
		float region = span(v, from, ramp_length - 0.75) * span(abs(x), -1.0, ramp_width * 0.5 - 0.7);
		float arrows = square((v + abs(x) * 0.55) / 1.7 - (turbo ? TIME * 1.8 : 0.0)) * region;
		if (turbo) {
			vec3 lit = mix(turbo_a, turbo_b, arrows);
			float pulse = 0.85 + 0.15 * sin(TIME * 8.0);
			col = mix(col, lit, region);
			emit += lit * region * (0.5 + arrows * 0.7) * turbo_glow * pulse;
		} else {
			col = mix(col, yellow, arrows);
		}
		// Logo "at" pintado no começo (lido por quem vem chegando: o topo do logo
		// aponta para a borda).
		float lh = min(ramp_length * 0.3, ramp_width * 0.5 / logo_aspect);
		vec2 luv = vec2(x / (lh * logo_aspect) + 0.5, 0.5 - (v - ramp_length * 0.22) / lh);
		vec4 l = texture(logo, clamp(luv, 0.0, 1.0));
		l.a *= span(luv.x, 0.0, 1.0) * span(luv.y, 0.0, 1.0);
		vec3 lc = mix(white, yellow, smoothstep(0.05, 0.09, l.r));
		col = mix(col, lc, l.a * 0.95);
		// Faixas brancas nas laterais e zebrado na borda.
		float to_edge = (0.5 - abs(UV.x - 0.5)) * ramp_width;
		col = mix(col, white, span(to_edge, 0.12, 0.42));
		float lip = span(v, ramp_length - 0.6, ramp_length + 1.0);
		col = mix(col, mix(navy, yellow, square((x + v) / 1.3)), lip);
		// Desgaste: marcas de pneu e sujeira leves.
		float grime = fbm(world_pos.xz * vec2(0.9, 0.35), 3);
		col *= mix(0.86, 1.04, grime);
		rough = 0.5 + grime * 0.15;
	} else if (part.g > 0.5) {
		// --- Saias laterais: listras diagonais azuis e azul-marinho, filete amarelo.
		col = mix(navy, base_color, square((UV.y + UV.x * 1.4) / 1.6));
		col = mix(col, yellow, 1.0 - smoothstep(0.1, 0.13, UV.x));
		rough = 0.5;
	} else {
		// --- Face da borda: zebrado amarelo e azul-marinho.
		col = mix(navy, yellow, square((UV.x + UV.y) / 0.9));
		rough = 0.6;
	}
	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
}
