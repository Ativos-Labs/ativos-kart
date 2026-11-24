shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Terreno: grama cortada em listras perto da pista, campos com manchas, areia na
// beira dos lagos, pedra nas encostas e neve no alto das montanhas.
// COLOR.r = 1 perto da pista (grama aparada), 0 longe. COLOR.g = dunas (mar de areia
// em volta do trecho de areia da pista). COLOR.b = paredão de vale (pedra). COLOR.a =
// chão de mata em volta da trilha da mata da praia (grama escura, folhas e terra).
// Debaixo d'água, cáusticas no fundo.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.22, 0.58, 0.11);
uniform vec3 grass_b : source_color = vec3(0.42, 0.7, 0.15);
uniform vec3 grass_dark : source_color = vec3(0.12, 0.4, 0.11);
uniform vec3 mowed_light : source_color = vec3(0.36, 0.72, 0.18);
uniform vec3 mowed_dark : source_color = vec3(0.26, 0.58, 0.14);
uniform vec3 sand : source_color = vec3(0.96, 0.85, 0.6);
uniform vec3 rock : source_color = vec3(0.6, 0.55, 0.5);
uniform vec3 rock_dark : source_color = vec3(0.4, 0.37, 0.36);
uniform vec3 snow : source_color = vec3(0.83, 0.87, 0.94);
uniform float water_level = -1.4;
uniform float snow_height = 105.0;
uniform float stripe_size = 7.0;
// Força das listras da grama aparada (0 = cor lisa).
uniform float stripe_strength = 1.0;
// Altura (acima da água) até onde vai a areia da beira.
uniform float sand_band = 1.25;
// Inclinação a partir da qual o chão vira pedra.
uniform float rock_slope = 0.3;
// Camadas da pedra: força, frequência e uma segunda cor em faixas (cânions).
uniform float strata = 0.1;
uniform float strata_freq = 0.9;
uniform vec3 rock_band : source_color = vec3(0.6, 0.55, 0.5);
uniform float band_mix = 0.0;
// Força das cáusticas (luz dançando no fundo debaixo d'água; 0 = sem, como no gelo).
uniform float caustic_strength = 0.6;
uniform vec3 dune_light : source_color = vec3(0.96, 0.8, 0.55);
uniform vec3 dune_dark : source_color = vec3(0.84, 0.6, 0.36);
// Grama verde na beira da água (oásis e margens do rio no deserto): até `grass_band` m
// acima da água (0 = sem).
uniform vec3 shore_grass : source_color = vec3(0.34, 0.58, 0.16);
uniform float grass_band = 0.0;
// Debaixo d'água o fundo puxa para o turquesa (praia: areia clara no raso), 0 = sem.
uniform float underwater_tint = 0.0;
// Faixa de areia molhada (mais escura e brilhante) logo acima da água (m), 0 = sem.
uniform float wet_band = 0.0;
// Chão de mata (COLOR.a).
uniform vec3 jungle_grass : source_color = vec3(0.17, 0.36, 0.1);
uniform vec3 jungle_grass_light : source_color = vec3(0.33, 0.56, 0.17);
uniform vec3 jungle_litter : source_color = vec3(0.4, 0.3, 0.17);
uniform vec3 jungle_dirt : source_color = vec3(0.6, 0.39, 0.2);

varying vec3 world_pos;
varying vec3 world_normal;
varying float near_track;
varying float dune;
varying float cliff;
varying float jungle;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	near_track = COLOR.r;
	dune = COLOR.g;
	cliff = COLOR.b;
	jungle = COLOR.a;
}

void fragment() {
	vec2 p = world_pos.xz;
	float lod = clamp(length(fwidth(p)) * 0.6, 0.0, 1.0);
	float n_big = fbm(p * 0.012, 3);
	float n_mid = vnoise(p * 0.09);
	float n_fine = lod < 1.0 ? mix(vnoise(p * 0.7), 0.5, lod) : 0.5;

	// Campos de grama com manchas claras e escuras.
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.38, 0.72, n_big));
	grass = mix(grass, grass_dark, smoothstep(0.55, 0.9, n_mid) * 0.4);
	grass *= 0.9 + n_fine * 0.2;

	// Grama aparada em listras perto da pista.
	float stripe_coord = (p.x * 0.8 + p.y * 0.6) / (stripe_size * 2.0);
	float sw = fwidth(stripe_coord) * 1.5;
	float stripe = smoothstep(0.5 - sw, 0.5 + sw, fract(stripe_coord)) - smoothstep(1.0 - sw, 1.0, fract(stripe_coord));
	vec3 mowed = mix(mowed_dark, mowed_light, mix(0.5, stripe, stripe_strength)) * (0.95 + n_fine * 0.1);
	vec3 col = mix(grass, mowed, near_track);

	// Encostas íngremes viram pedra (com camadas).
	vec3 wn = normalize(world_normal);
	float slope = 1.0 - wn.y;
	float rock_mask = smoothstep(rock_slope, rock_slope + 0.16, slope + (n_mid - 0.5) * 0.18);
	// Paredões dos vales da asa-delta são sempre de pedra (COLOR.b).
	rock_mask = max(rock_mask, smoothstep(0.15, 0.6, cliff + (n_mid - 0.5) * 0.3));
	if (rock_mask > 0.0) {
		// Ruído projetado no plano da encosta (e não no chão XZ), senão ele estica
		// e vira listras verticais nas paredes das montanhas.
		vec2 side = normalize(wn.xz + vec2(0.0001));
		vec2 rp = vec2(dot(world_pos.xz, vec2(-side.y, side.x)), world_pos.y - dot(world_pos.xz, side));
		float n_rock = vnoise(rp * 0.11) * 0.7 + (lod < 1.0 ? mix(vnoise(rp * 0.45), 0.5, lod) : 0.5) * 0.3;
		float layer = world_pos.y * strata_freq + n_big * 9.0 + n_rock * 3.0;
		vec3 rock_col = mix(rock_dark, rock, smoothstep(0.25, 0.75, n_rock)) * (1.0 - strata + strata * sin(layer));
		// Faixas de outra cor (paredões de cânion).
		rock_col = mix(rock_col, rock_band * (0.9 + 0.1 * n_rock), band_mix * smoothstep(0.35, 0.65, sin(layer * 0.37 + 1.3) * 0.5 + 0.5));
		col = mix(col, rock_col, rock_mask);
	}

	// Chão de mata: grama escura com folhas caídas e a terra da trilha na beirada.
	if (jungle > 0.001) {
		float litter = smoothstep(0.4, 0.7, n_mid + (n_big - 0.5) * 0.5);
		vec3 jg = mix(jungle_grass, jungle_grass_light, smoothstep(0.3, 0.8, n_big)) * (0.85 + 0.3 * n_fine);
		jg = mix(jg, jungle_litter * (0.85 + 0.3 * n_fine), litter * 0.55);
		float trail = near_track * smoothstep(0.35, 0.8, n_mid * 0.6 + near_track * 0.55);
		jg = mix(jg, jungle_dirt * (0.9 + 0.15 * n_fine), trail);
		col = mix(col, jg, jungle * (1.0 - rock_mask * 0.7));
	}

	// Neve no alto (só onde a encosta não é muito íngreme).
	float snow_line = world_pos.y + (n_big - 0.5) * 36.0 + (n_mid - 0.5) * 10.0;
	float snow_mask = smoothstep(snow_height - 1.2, snow_height + 1.2, snow_line)
			* (1.0 - smoothstep(0.6, 0.7, slope + (n_fine - 0.5) * 0.1));
	col = mix(col, snow * (0.92 + n_fine * 0.08), snow_mask);

	// Areia na beira da água.
	float shore = 1.0 - smoothstep(water_level + 0.45, water_level + sand_band, world_pos.y + (n_fine - 0.5) * 0.35);
	col = mix(col, sand * (0.92 + n_fine * 0.1), shore * (1.0 - near_track));

	// Mar de dunas: areia lisa com marcas do vento, mais escura na face à sombra.
	if (dune > 0.001) {
		float warp = vnoise(p * 0.03) * 8.0;
		float ripple = sin((p.x * 0.8 + p.y * 0.6) * 1.9 + warp) * 0.5 + 0.5;
		vec3 dcol = mix(dune_dark, dune_light, smoothstep(0.25, 0.85, n_big + (1.0 - slope) * 0.3));
		dcol *= 0.95 + 0.07 * ripple * (1.0 - lod);
		col = mix(col, dcol, dune * (1.0 - rock_mask * 0.6));
	}

	if (grass_band > 0.0) {
		float above = world_pos.y - water_level + (n_mid - 0.5) * 1.4;
		float g = smoothstep(0.1, 0.5, above) * (1.0 - smoothstep(grass_band * 0.55, grass_band, above)) * (1.0 - rock_mask);
		vec3 gc = mix(shore_grass * 0.7, shore_grass * 1.15, n_fine) * (0.88 + 0.24 * n_big);
		col = mix(col, gc, g * (1.0 - near_track * 0.6));
	}

	if (underwater_tint > 0.0) {
		float under = smoothstep(water_level - 0.05, water_level - 1.6, world_pos.y);
		col = mix(col, col * vec3(0.5, 0.82, 0.8), under * underwater_tint);
	}
	float wet = 0.0;
	if (wet_band > 0.0) {
		float above = world_pos.y - water_level + (n_fine - 0.5) * 0.12;
		wet = (1.0 - smoothstep(wet_band * 0.4, wet_band, above)) * step(-0.3, above) * (1.0 - rock_mask);
		col = mix(col, col * vec3(0.72, 0.7, 0.68), wet * 0.85);
	}
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.92, 0.55, snow_mask), 0.35, wet);
	SPECULAR = 0.3;
	if (caustic_strength > 0.0 && world_pos.y < water_level - 0.15) {
		float depth = water_level - world_pos.y;
		float fade = smoothstep(0.15, 1.2, depth) * (1.0 - smoothstep(9.0, 22.0, depth));
		EMISSION = vec3(0.5, 0.8, 0.75) * caustics(p, TIME) * fade * caustic_strength;
	}
}
