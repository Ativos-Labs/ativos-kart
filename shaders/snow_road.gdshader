shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Pista de neve e gelo (Track.snow_track), no lugar do asfalto:
// - neve batida: sulcos finos da máquina de neve, trilhas de pneu compactadas (mais
//   azuladas e lisas), neve soprada pelo vento por cima, neve fofa nas bordas e cristais
//   que brilham contra o sol;
// - rio congelado (COLOR.b, trechos de GELO): gelo liso e transparente, com rachaduras,
//   bolhas e peixes embaixo (veja ice.gdshaderinc), e a neve entrando nele em manchas.
// Largada: linha quadriculada, marcas do grid e o logo "at" tingidos na neve.
// UV.x = 0..1 de uma borda à outra; UV.y = metros ao longo da pista.

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"
#include "res://shaders/ice.gdshaderinc"

uniform vec3 snow_light : source_color = vec3(0.91, 0.94, 0.99);
uniform vec3 snow_shade : source_color = vec3(0.74, 0.81, 0.93);
uniform vec3 rut_color : source_color = vec3(0.58, 0.68, 0.86);
uniform vec3 powder_color : source_color = vec3(0.95, 0.97, 1.0);
uniform vec3 ice_shallow : source_color = vec3(0.6, 0.86, 0.97);
uniform vec3 ice_deep : source_color = vec3(0.09, 0.33, 0.52);
uniform vec3 dye_blue : source_color = vec3(0.149, 0.239, 0.749);
uniform vec3 dye_navy : source_color = vec3(0.06, 0.09, 0.22);
uniform vec3 paint_accent : source_color = vec3(1.0, 0.8, 0.1);
// Direção (mundo) para o sol: os cristais da neve brilham quando refletem ele.
uniform vec3 sun_dir = vec3(0.43, 0.64, 0.63);
uniform float sparkle = 5.0;
uniform float road_width = 15.0;
uniform float track_length = 1000.0;
uniform float grid_offset = 10.0;

uniform sampler2D logo_texture : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float logo_start = 16.0;
uniform float logo_length = 12.0;
uniform float logo_width = 10.0;

varying vec3 special;
varying vec3 world_pos;
varying vec3 world_right;

void vertex() {
	special = COLOR.rgb;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_right = (MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz;
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
	vec3 ray = normalize(world_pos - CAMERA_POSITION_WORLD);

	float ice_f = special.b;
	vec2 pr = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	float n_big = tnoise(p * vec2(0.07, 0.025));
	float n_mid = tfbm2(pr * 0.35);
	vec3 col = snow_light;
	float rough = 0.8;
	float spec = 0.45;
	vec2 slope = vec2(0.0);
	vec3 emit = vec3(0.0);

	// --- Neve batida (pulada onde a pista é só gelo) --------------------------------
	if (ice_f < 0.999) {
		vec3 fine = vec3(0.5, 0.0, 0.0);
		if (lod < 1.0) {
			fine = tnoise_d(pr * 2.4);
		}
		col = mix(snow_shade, snow_light, clamp(0.4 + 0.4 * n_mid + 0.25 * n_big + (fine.x - 0.5) * 0.2 * (1.0 - lod), 0.0, 1.0));
		slope = fine.yz * (0.05 * 2.4) * (1.0 - lod);

		// Sulcos da máquina de neve (ao longo da pista), em passadas de ~4,2 m de largura
		// com uma emenda entre elas; de longe viram só um leve listrado.
		float pass_x = across + sin(along * 0.013) * 0.8;
		float seam = abs(fract(pass_x / 4.2) - 0.5) * 4.2;
		float cord_k = (1.0 - smoothstep(0.15, 0.6, lod)) * smoothstep(0.08, 0.25, seam);
		float cord_ph = pass_x * (6.2831 / 0.12);
		slope.x += cos(cord_ph) * 0.12 * cord_k;
		col *= 1.0 - (1.0 - smoothstep(0.0, 0.12, abs(seam - 2.1) - 1.9)) * 0.04;
		col = mix(col, col * 0.965, smoothstep(0.55, 0.7, fract(pass_x / 4.2 + 0.5)) * 0.4 * (1.0 - cord_k));

		// Trilhas de pneu: pares de sulcos compactados que serpenteiam pela pista, mais
		// marcados no meio (onde todo mundo passa).
		float ruts = 0.0;
		float rut_slope = 0.0;
		for (int k = 0; k < 5; k++) {
			float fk = float(k);
			float center = (fk - 2.0) * 1.75 + sin(along * 0.021 + fk * 1.9) * 1.1 + sin(along * 0.067 + fk * 4.3) * 0.3;
			float dx = lateral - center;
			float d = abs(abs(dx) - 0.37);
			float w = 0.13 + aa * 0.5;
			float presence = smoothstep(0.3, 0.6, 0.5 + 0.35 * sin(along * 0.029 + fk * 2.3) + 0.15 * sin(along * 0.011 + fk * 4.1)) * (k == 2 ? 1.0 : 0.75);
			float rk = (1.0 - smoothstep(w * 0.5, w, d)) * presence;
			if (rk > ruts) {
				ruts = rk;
				// Beirada do sulco: a neve sobe dos dois lados.
				rut_slope = sign(abs(dx) - 0.37) * sign(dx) * smoothstep(w * 0.3, w, d) * presence;
			}
		}
		// Desenho da banda de rodagem dentro da trilha.
		float tread = step(0.5, fract(along * 4.0 + abs(lateral) * 2.0));
		// Neve soprada pelo vento: faixas na diagonal que cobrem as trilhas aqui e ali.
		vec2 pw = mat2(vec2(0.9, 0.44), vec2(-0.44, 0.9)) * p;
		float drift = smoothstep(0.56, 0.8, tfbm2(pw * vec2(0.045, 0.32)));
		ruts *= 1.0 - drift * 0.85;
		col = mix(col, rut_color * (0.93 + 0.07 * tread * (1.0 - lod)), ruts * 0.62);
		col = mix(col, snow_light, drift * 0.6);
		slope.x += rut_slope * 0.35 * (1.0 - lod);
		rough = mix(0.78, 0.42, ruts);
		rough = mix(rough, 0.88, drift);

		// Neve fofa nas bordas (combina com o chão do lado de fora).
		float powder = 1.0 - smoothstep(0.25, 1.6, edge + (n_mid - 0.5) * 0.9);
		col = mix(col, powder_color, powder);
		rough = mix(rough, 0.92, powder);
		slope *= 1.0 + powder * 1.5;

		// Cristais brilhando: algumas faces viradas para refletir o sol na câmera.
		if (lod < 0.95) {
			vec2 sp = p * 8.0;
			vec2 cell = floor(sp);
			vec2 o = hash22(cell + 3.1) * 0.6 + 0.2;
			float crystal = step(0.72, hash12(cell));
			vec3 facet = normalize(vec3((o.x - 0.5) * 1.4, 1.0, (o.y - 0.5) * 1.4));
			float mirror = dot(reflect(ray, facet), normalize(sun_dir));
			float dot_mask = 1.0 - smoothstep(0.14, 0.26, length(fract(sp) - o));
			float glint = smoothstep(0.972, 0.99, mirror) * dot_mask * crystal * (1.0 - smoothstep(0.55, 0.95, lod));
			vec3 tint = mix(vec3(1.0), 0.5 + 0.5 * cos(6.2831 * (hash12(cell + 9.4) + vec3(0.0, 0.33, 0.67))), 0.65);
			emit += tint * glint * sparkle * (1.0 - ruts * 0.6);
		}
	}

	// --- Rio congelado ----------------------------------------------------------
	if (ice_f > 0.001) {
		vec2 ax = vec2(1.0, 0.0);
		if (abs(world_right.y) < 0.7) {
			ax = normalize(world_right.xz);
		}
		vec2 ay = vec2(ax.y, -ax.x);
		vec3 icol;
		float irough;
		float ispec;
		vec3 iemit;
		ice_shade(p, ray, ax, ay, edge, lod, TIME, 1.0, ice_shallow, ice_deep, icol, irough, ispec, iemit);
		// A neve entra no gelo em manchas irregulares (não numa linha reta).
		float m = ice_f >= 0.999 ? 1.0 : smoothstep(0.38, 0.62, ice_f + (n_mid - 0.5) * 0.7 + (n_big - 0.5) * 0.3);
		col = mix(col, icol, m);
		rough = mix(rough, irough, m);
		spec = mix(spec, ispec, m);
		emit = mix(emit, iemit, m);
		slope *= 1.0 - m * 0.85;
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
		// Tinta borrifada: falha um pouco onde a neve é mais fofa.
		float worn = 0.7 + 0.3 * smoothstep(0.3, 0.7, tnoise(p * 3.0));
		float mk = logo.a * worn;
		paint_col = mix(dye_blue, paint_accent, chevron * step(0.01, mk));
		paint = max(paint, mk);
	}
	col = mix(col, paint_col * (0.92 + 0.08 * n_mid), paint);
	emit *= 1.0 - paint;
	rough = mix(rough, 0.7, paint);
	if (abs(s) < 1.25 && edge > 0.6) {
		float sq = 0.62;
		float chk = mod(floor(lateral / sq) + floor((s + 0.93) / sq), 2.0);
		vec3 chk_col = chk < 0.5 ? dye_navy : snow_light;
		if (abs(s) > 0.93) {
			chk_col = dye_blue;
		}
		col = chk_col * (0.94 + 0.06 * n_mid);
		emit = vec3(0.0);
		rough = 0.7;
	}

	NORMAL_MAP = normalize(vec3(-slope.x, -slope.y, 1.0)) * 0.5 + 0.5;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
}
