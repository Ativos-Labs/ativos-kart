shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Pista de praia (Track.beach_track), no lugar do asfalto:
// - areia branca de praia: trilhas de pneu compactadas que serpenteiam, ondinhas do
//   vento, areia solta por cima e conchinhas espalhadas;
// - trilha da mata (COLOR.r): terra batida alaranjada, trilhas de pneu mais escuras,
//   pedrinhas e manchas úmidas;
// - baixio (COLOR.g): areia molhada com marcas de onda no fundo e a luz dançando
//   (cáusticas), debaixo da lâmina d'água da TrackSection RASO;
// - píer (COLOR.b): tábuas de madeira atravessadas (planks.gdshaderinc), com um pouco de
//   areia trazida pelos karts nas pontas. Com `all_planks` (o tabuleiro da passarela)
//   é tudo tábua.
// Largada: linha quadriculada, marcas do grid e o logo "at" pintados na areia.
// UV.x = 0..1 de uma borda à outra; UV.y = metros ao longo da pista.

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"
#include "res://shaders/planks.gdshaderinc"

uniform vec3 sand_light : source_color = vec3(0.76, 0.67, 0.49);
uniform vec3 sand_shade : source_color = vec3(0.68, 0.58, 0.41);
uniform vec3 packed_color : source_color = vec3(0.6, 0.5, 0.36);
uniform vec3 loose_color : source_color = vec3(0.78, 0.69, 0.51);
uniform vec3 wet_color : source_color = vec3(0.44, 0.52, 0.42);
uniform vec3 dirt_light : source_color = vec3(0.68, 0.44, 0.22);
uniform vec3 dirt_shade : source_color = vec3(0.56, 0.35, 0.17);
uniform vec3 dirt_packed : source_color = vec3(0.47, 0.29, 0.14);
uniform vec3 shell_a : source_color = vec3(1.0, 0.97, 0.93);
uniform vec3 shell_b : source_color = vec3(0.98, 0.72, 0.66);
uniform vec3 dye_blue : source_color = vec3(0.149, 0.239, 0.749);
uniform vec3 dye_navy : source_color = vec3(0.06, 0.09, 0.22);
uniform vec3 dye_cream : source_color = vec3(0.98, 0.96, 0.9);
uniform vec3 paint_accent : source_color = vec3(1.0, 0.8, 0.1);
uniform float road_width = 15.0;
uniform float track_length = 1000.0;
uniform float grid_offset = 10.0;
// Faixa de areia fofa junto das bordas (m).
uniform float soft_edge = 2.2;
// Tabuleiro da passarela: tudo tábua, sem largada.
uniform bool all_planks = false;

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
	float wet_f = all_planks ? 0.0 : special.g;
	float plank_f = all_planks ? 1.0 : special.b;
	float dirt_f = all_planks ? 0.0 : special.r;

	vec2 pr = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	float n_big = tnoise(p * vec2(0.07, 0.025));
	float n_mid = tfbm2(pr * 0.35);
	vec3 fine = vec3(0.5, 0.0, 0.0);
	if (lod < 1.0) {
		fine = tnoise_d(pr * 2.6);
	}
	vec3 col = mix(sand_shade, sand_light, clamp(0.35 + 0.4 * n_mid + 0.3 * n_big + (fine.x - 0.5) * 0.25 * (1.0 - lod), 0.0, 1.0));
	vec2 slope = fine.yz * (0.035 * 2.6) * (1.0 - lod);
	float rough = 0.92;

	// Trilhas de pneu: sulcos compactados (mais escuros e lisos) que serpenteiam.
	float ruts = 0.0;
	float rut_slope = 0.0;
	for (int k = 0; k < 5; k++) {
		float fk = float(k);
		float center = (fk - 2.0) * 1.8 + sin(along * 0.021 + fk * 1.3) * 1.1 + sin(along * 0.057 + fk * 3.9) * 0.3;
		float dx = lateral - center;
		float d = abs(abs(dx) - 0.36);
		float w = 0.15 + aa * 0.5;
		float presence = smoothstep(0.25, 0.6, 0.5 + 0.35 * sin(along * 0.025 + fk * 2.1) + 0.15 * sin(along * 0.011 + fk * 3.3)) * (k == 2 ? 1.0 : 0.8);
		float rk = (1.0 - smoothstep(w * 0.5, w, d)) * presence;
		if (rk > ruts) {
			ruts = rk;
			rut_slope = sign(abs(dx) - 0.36) * sign(dx) * smoothstep(w * 0.3, w, d) * presence;
		}
	}
	// Areia solta soprada pelo vento por cima das trilhas, aqui e ali.
	vec2 pw = mat2(vec2(0.9, 0.44), vec2(-0.44, 0.9)) * p;
	float drift = smoothstep(0.55, 0.8, tfbm2(pw * vec2(0.05, 0.3)));
	ruts *= 1.0 - drift * 0.85;
	col = mix(col, packed_color * (0.95 + 0.1 * n_big), ruts * 0.45);
	col = mix(col, loose_color, drift * 0.5);
	slope.x += rut_slope * 0.25 * (1.0 - lod);
	rough = mix(rough, 0.8, ruts);

	// Ondinhas do vento (somem nas trilhas).
	float rip_k = (1.0 - smoothstep(0.15, 0.55, lod)) * (1.0 - ruts * 0.85) * (0.5 + 0.4 * drift);
	if (rip_k > 0.001) {
		vec2 rd = normalize(vec2(0.85, 0.53));
		float r = dot(p, rd) + tnoise(p * vec2(0.09, 0.05)) * 3.2;
		float ph = r * (6.2831 / 0.7);
		float w = fract(r / 0.7);
		float hgt = smoothstep(0.0, 0.75, w) - smoothstep(0.75, 1.0, w);
		col *= 1.0 + (hgt - 0.5) * 0.07 * rip_k;
		slope += rd * cos(ph) * 0.13 * rip_k;
	}

	// Conchinhas espalhadas (de perto): brancas e rosadas.
	if (lod < 0.9) {
		vec2 sp = pr * 1.6;
		vec2 cell = floor(sp);
		vec2 o = hash22(cell) * 0.6 + 0.2;
		vec2 dv = fract(sp) - o;
		float ang = hash12(cell + 3.0) * 6.2831;
		dv = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * dv;
		float dd = length(dv * vec2(1.0, 1.6));
		float size = 0.03 + 0.04 * hash12(cell + 9.0);
		float shell = (1.0 - smoothstep(size, size + 0.03, dd)) * step(0.86, hash12(cell + 5.0))
				* (1.0 - lod) * (1.0 - ruts * 0.7) * (1.0 - dirt_f);
		vec3 sc = mix(shell_a, shell_b, step(0.6, hash12(cell + 7.0)));
		// Listrinhas da concha.
		sc *= 0.9 + 0.1 * sin(atan(dv.y, dv.x) * 9.0);
		col = mix(col, sc, shell);
		slope += dv * shell * 1.2;
		rough = mix(rough, 0.5, shell);
	}

	// Areia fofa nas bordas (combina com o chão do lado de fora).
	float soft = 1.0 - smoothstep(0.2, 1.4 + soft_edge * 0.3, edge + (n_mid - 0.5) * 0.8);
	col = mix(col, loose_color * (0.96 + 0.06 * n_mid), soft * 0.7 * (1.0 - dirt_f));
	rough = mix(rough, 0.95, soft);

	// Trilha da mata: terra batida alaranjada, trilhas de pneu compactadas (mais escuras),
	// pedrinhas e manchas úmidas na sombra.
	if (dirt_f > 0.001) {
		vec3 dirt = mix(dirt_shade, dirt_light, clamp(0.3 + 0.45 * n_mid + 0.35 * (n_big - 0.5) + (fine.x - 0.5) * 0.3 * (1.0 - lod), 0.0, 1.0));
		dirt = mix(dirt, dirt_packed * (0.95 + 0.1 * n_big), ruts * 0.6);
		float damp = smoothstep(0.62, 0.8, tfbm2(p * 0.09 + 4.0));
		dirt *= 1.0 - damp * 0.18;
		if (lod < 0.9) {
			vec2 sp = pr * 2.4;
			vec2 cell = floor(sp);
			vec2 o = hash22(cell + 1.7) * 0.6 + 0.2;
			float dd = length(fract(sp) - o);
			float size = 0.035 + 0.04 * hash12(cell + 9.0);
			float stone = (1.0 - smoothstep(size, size + 0.03, dd)) * step(0.82, hash12(cell + 5.0)) * (1.0 - lod);
			dirt = mix(dirt, vec3(0.46, 0.42, 0.38) * (0.8 + 0.4 * hash12(cell)), stone * 0.8);
			slope += (fract(sp) - o) * stone * dirt_f * 0.8;
		}
		// Beirada: terra solta e um pouco de grama invadindo.
		float grassy = soft * smoothstep(0.45, 0.7, n_mid + (fine.x - 0.5) * 0.4);
		dirt = mix(dirt, dirt_light * 1.05, soft * 0.4);
		dirt = mix(dirt, vec3(0.24, 0.45, 0.14) * (0.85 + 0.3 * n_big), grassy * 0.75);
		col = mix(col, dirt, dirt_f);
		rough = mix(rough, 0.95, dirt_f);
	}

	// Baixio: areia molhada com marcas de onda no fundo e a luz dançando.
	vec3 emit = vec3(0.0);
	if (wet_f > 0.001) {
		vec2 wd = normalize(vec2(0.3, 1.0));
		float wr = dot(p, wd) + tnoise(p * 0.08) * 4.0;
		float wave_mark = smoothstep(0.35, 0.5, abs(fract(wr / 1.1) - 0.5) * 2.0);
		vec3 bed = mix(wet_color, wet_color * 1.12, n_mid) * (0.94 + 0.08 * wave_mark);
		col = mix(col, bed, wet_f * (1.0 - plank_f));
		slope = mix(slope, slope * 0.4 + wd * (wave_mark - 0.5) * 0.12, wet_f);
		rough = mix(rough, 0.35, wet_f);
		emit = vec3(0.6, 0.95, 0.9) * tcaustics(world_pos.xz * 1.3, TIME * 1.4) * wet_f * 0.35;
	}

	// Píer: tábuas, com areia nas pontas (trazida pelos pneus).
	if (plank_f > 0.001) {
		vec2 ps = slope;
		float pk_rough = rough;
		vec3 wood = plank_color(vec2(lateral, along), lod, aa, ps, pk_rough);
		float sandy = all_planks ? 0.0 : smoothstep(0.55, 0.95, (1.0 - plank_f) * 2.4 + (n_mid - 0.5) * 0.9);
		float m = smoothstep(0.35, 0.55, plank_f);
		col = mix(col, mix(wood, loose_color * 0.95, sandy * 0.8), m);
		slope = mix(slope, ps, m * (1.0 - sandy));
		rough = mix(rough, pk_rough, m);
	}

	// --- Largada -----------------------------------------------------------------
	if (!all_planks) {
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
			paint = max(paint, slots * 0.9);
			paint_col = dye_cream;
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
	}

	NORMAL_MAP = normalize(vec3(-slope.x, -slope.y, 1.0)) * 0.5 + 0.5;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.28, 0.6, wet_f);
	EMISSION = emit;
}
