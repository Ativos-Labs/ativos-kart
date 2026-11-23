shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Pista de areia do deserto (Track.sand_track), no lugar do asfalto:
// - areia batida: ondinhas do vento atravessando a pista, trilhas de pneu compactadas
//   (mais escuras e lisas) que serpenteiam, areia solta soprada por cima delas,
//   pedrinhas e areia fofa nas bordas;
// - dunas (COLOR.r): mais ondinhas e areia solta, menos trilhas;
// - fundo do oásis (COLOR.g): areia molhada com algas e a luz dançando (cáusticas).
// Largada: linha quadriculada, marcas do grid e o logo "at" tingidos na areia.
// UV.x = 0..1 de uma borda à outra; UV.y = metros ao longo da pista.

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"

uniform vec3 sand_light : source_color = vec3(0.89, 0.71, 0.45);
uniform vec3 sand_shade : source_color = vec3(0.79, 0.58, 0.35);
uniform vec3 packed_color : source_color = vec3(0.66, 0.46, 0.27);
uniform vec3 loose_color : source_color = vec3(0.93, 0.77, 0.51);
uniform vec3 pebble_color : source_color = vec3(0.46, 0.32, 0.2);
uniform vec3 algae_color : source_color = vec3(0.3, 0.42, 0.18);
uniform vec3 dye_blue : source_color = vec3(0.149, 0.239, 0.749);
uniform vec3 dye_navy : source_color = vec3(0.06, 0.09, 0.22);
uniform vec3 dye_cream : source_color = vec3(0.98, 0.94, 0.84);
uniform vec3 paint_accent : source_color = vec3(1.0, 0.8, 0.1);
uniform float road_width = 15.0;
uniform float track_length = 1000.0;
uniform float grid_offset = 10.0;
// Faixa de areia fofa junto das bordas nas dunas (m).
uniform float soft_edge = 2.2;

uniform sampler2D logo_texture : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float logo_start = 16.0;
uniform float logo_length = 12.0;
uniform float logo_width = 10.0;

varying vec3 special;
varying vec3 world_pos;

void vertex() {
	special = COLOR.rgb;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float box(vec2 p, vec2 center, vec2 half_size, float aa) {
	vec2 d = abs(p - center) - half_size;
	float dist = max(d.x, d.y);
	return 1.0 - smoothstep(-aa, aa, dist);
}

// Marca de posição de largada ("U" aberto para trás), como no asfalto.
float grid_slot(vec2 q, vec2 slot, float aa) {
	float k = 0.55;
	float w = 1.5 * k;
	float t = 0.08 * k;
	float m = box(q, slot + vec2(0.0, 1.75 * k), vec2(w, t), aa);
	m = max(m, box(q, slot + vec2(-w, 1.0 * k), vec2(t, 0.75 * k), aa));
	m = max(m, box(q, slot + vec2(w, 1.0 * k), vec2(t, 0.75 * k), aa));
	return m;
}

void fragment() {
	float across = UV.x * road_width;
	float along = UV.y;
	float lateral = across - road_width * 0.5;
	float edge = min(across, road_width - across);
	vec2 p = vec2(across, along);
	float lod = clamp(length(fwidth(p)) * 5.0, 0.0, 1.0);
	float aa = max(length(fwidth(p)) * 0.75, 0.01);
	float dune_f = special.r;
	float under_f = special.g;

	vec2 pr = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	float n_big = tnoise(p * vec2(0.07, 0.025));
	float n_mid = tfbm2(pr * 0.35);
	vec3 fine = vec3(0.5, 0.0, 0.0);
	if (lod < 1.0) {
		fine = tnoise_d(pr * 2.2);
	}
	vec3 col = mix(sand_shade, sand_light, clamp(0.3 + 0.45 * n_mid + 0.3 * n_big + (fine.x - 0.5) * 0.25 * (1.0 - lod), 0.0, 1.0));
	vec2 slope = fine.yz * (0.04 * 2.2) * (1.0 - lod);
	float rough = 0.9;

	// Trilhas de pneu: pares de sulcos compactados que serpenteiam pela pista (mais
	// marcados no meio, onde todo mundo passa). Nas dunas quase somem.
	float ruts = 0.0;
	float rut_slope = 0.0;
	for (int k = 0; k < 5; k++) {
		float fk = float(k);
		float center = (fk - 2.0) * 1.8 + sin(along * 0.019 + fk * 1.7) * 1.2 + sin(along * 0.061 + fk * 4.1) * 0.35;
		float dx = lateral - center;
		float d = abs(abs(dx) - 0.36);
		float w = 0.14 + aa * 0.5;
		float presence = smoothstep(0.25, 0.6, 0.5 + 0.35 * sin(along * 0.027 + fk * 2.3) + 0.15 * sin(along * 0.013 + fk * 3.7)) * (k == 2 ? 1.0 : 0.8);
		float rk = (1.0 - smoothstep(w * 0.5, w, d)) * presence;
		if (rk > ruts) {
			ruts = rk;
			rut_slope = sign(abs(dx) - 0.36) * sign(dx) * smoothstep(w * 0.3, w, d) * presence;
		}
	}
	ruts *= 1.0 - dune_f * 0.6;

	// Areia solta soprada pelo vento: faixas na diagonal que cobrem as trilhas aqui e ali.
	vec2 pw = mat2(vec2(0.9, 0.44), vec2(-0.44, 0.9)) * p;
	float drift = smoothstep(0.55, 0.8, tfbm2(pw * vec2(0.05, 0.3)));
	drift = max(drift, dune_f * 0.35 * n_mid);
	ruts *= 1.0 - drift * 0.85;
	float tread = step(0.5, fract(along * 3.6 + abs(lateral) * 2.0));
	col = mix(col, packed_color * (0.94 + 0.06 * tread * (1.0 - lod)) * (0.95 + 0.1 * n_big), ruts * 0.55);
	col = mix(col, loose_color, drift * 0.55);
	slope.x += rut_slope * 0.3 * (1.0 - lod);
	rough = mix(rough, 0.72, ruts);

	// Ondinhas do vento atravessando a pista (somem onde a areia está compactada).
	float rip_k = (1.0 - smoothstep(0.15, 0.55, lod)) * (1.0 - ruts * 0.85) * (0.55 + 0.45 * dune_f + 0.4 * drift);
	if (rip_k > 0.001) {
		vec2 rd = normalize(vec2(0.85, 0.53));
		float r = dot(p, rd) + tnoise(p * vec2(0.09, 0.05)) * 3.2;
		float ph = r * (6.2831 / 0.62);
		// Crista assimétrica: subida longa, descida curta.
		float w = fract(r / 0.62);
		float hgt = smoothstep(0.0, 0.75, w) - smoothstep(0.75, 1.0, w);
		col *= 1.0 + (hgt - 0.5) * 0.09 * rip_k;
		slope += rd * cos(ph) * 0.16 * rip_k;
	}

	// Pedrinhas espalhadas (de perto), em grupos: some onde a areia está solta.
	if (lod < 0.9) {
		vec2 sp = pr * 2.2;
		vec2 cell = floor(sp);
		vec2 o = hash22(cell) * 0.6 + 0.2;
		float dd = length((fract(sp) - o) * vec2(1.0, 1.4));
		float patch = smoothstep(0.45, 0.7, n_mid + (n_big - 0.5) * 0.6);
		float size = 0.04 + 0.05 * hash12(cell + 9.0);
		float stone = (1.0 - smoothstep(size, size + 0.05, dd)) * step(0.9 - patch * 0.25, hash12(cell + 5.0))
				* (1.0 - lod) * (1.0 - drift) * (1.0 - dune_f * 0.8);
		col = mix(col, mix(pebble_color, sand_shade, 0.35 + 0.4 * hash12(cell + 2.0)), stone * 0.7);
		slope += (fract(sp) - o) * stone * 0.8;
	}

	// Areia fofa nas bordas (combina com o chão do lado de fora).
	float soft = 1.0 - smoothstep(0.2, 1.4 + soft_edge * dune_f * 0.6, edge + (n_mid - 0.5) * 0.8);
	col = mix(col, loose_color * (0.95 + 0.07 * n_mid), soft * 0.8);
	rough = mix(rough, 0.95, soft);

	// Fundo do oásis: areia molhada, algas em manchas e a luz dançando.
	vec3 emit = vec3(0.0);
	if (under_f > 0.001) {
		float algae = smoothstep(0.55, 0.78, tfbm2(p * 0.12 + 3.0));
		vec3 bed = col * vec3(0.72, 0.76, 0.72);
		bed = mix(bed, algae_color * (0.8 + 0.4 * n_mid), algae * 0.6);
		col = mix(col, bed, under_f);
		rough = mix(rough, 0.6, under_f);
		emit = vec3(0.55, 0.85, 0.8) * tcaustics(world_pos.xz, TIME) * under_f * 0.5;
	}

	// --- Largada -----------------------------------------------------------------
	float s = along > track_length * 0.5 ? along - track_length : along;
	vec2 q = vec2(lateral, s);
	float paint = 0.0;
	vec3 paint_col = dye_blue;
	if (s < -grid_offset + 3.0 && s > -grid_offset - 38.0) {
		float slots = grid_slot(q, vec2(0.0, -grid_offset), aa);
		for (int k = 1; k < 6; k++) {
			float side = mod(float(k), 2.0) < 0.5 ? 1.0 : -1.0;
			slots = max(slots, grid_slot(q, vec2(3.6 * side, -grid_offset - 7.0 * float(k)), aa));
		}
		paint = max(paint, slots * 0.85);
	}
	if (s > logo_start && s < logo_start + logo_length && abs(lateral) < logo_width * 0.5) {
		vec2 luv = vec2((lateral + logo_width * 0.5) / logo_width, 1.0 - (s - logo_start) / logo_length);
		vec4 logo = texture(logo_texture, luv);
		float chevron = smoothstep(0.05, 0.09, logo.r);
		// Tinta borrifada na areia: falha onde a areia solta cobriu.
		float worn = 0.72 + 0.28 * smoothstep(0.3, 0.7, tnoise(p * 3.0));
		float mk = logo.a * worn * (1.0 - drift * 0.3);
		paint_col = mix(dye_blue, paint_accent, chevron * step(0.01, mk));
		paint = max(paint, mk);
	}
	col = mix(col, paint_col * (0.92 + 0.08 * n_mid), paint);
	rough = mix(rough, 0.8, paint);
	if (abs(s) < 1.25 && edge > 0.6) {
		float sq = 0.62;
		float chk = mod(floor(lateral / sq) + floor((s + 0.93) / sq), 2.0);
		vec3 chk_col = chk < 0.5 ? dye_navy : dye_cream;
		if (abs(s) > 0.93) {
			chk_col = dye_blue;
		}
		col = chk_col * (0.92 + 0.08 * n_mid);
		rough = 0.85;
		slope *= 0.3;
	}

	NORMAL_MAP = normalize(vec3(-slope.x, -slope.y, 1.0)) * 0.5 + 0.5;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.28;
	EMISSION = emit;
}
