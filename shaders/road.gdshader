shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Asfalto: granulado com relevo, trilho mais gasto no meio, faixas brancas,
// linha de chegada quadriculada, grid de largada e o logo "at" pintado no chão.
// UV.x = 0..1 de uma borda à outra; UV.y = metros ao longo da pista.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 asphalt_light : source_color = vec3(0.44, 0.44, 0.46);
uniform vec3 asphalt_dark : source_color = vec3(0.25, 0.25, 0.27);
uniform vec3 line_color : source_color = vec3(0.97, 0.97, 0.95);
uniform vec3 paint_accent : source_color = vec3(1.0, 0.8, 0.1);
uniform float road_width = 15.0;
uniform float track_length = 1000.0;
// Largura mínima das zebras (a faixa branca fica logo depois delas).
uniform float curb_min = 0.6;
// Distância da linha de chegada até a posição de largada do jogador.
uniform float grid_offset = 10.0;

uniform sampler2D logo_texture : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float logo_start = 16.0;
uniform float logo_length = 12.0;
uniform float logo_width = 10.0;

float box(vec2 p, vec2 center, vec2 half_size, float aa) {
	vec2 d = abs(p - center) - half_size;
	float dist = max(d.x, d.y);
	return 1.0 - smoothstep(-aa, aa, dist);
}

// Marca de posição de largada ("U" aberto para trás).
float grid_slot(vec2 q, vec2 slot, float aa) {
	float w = 1.5;
	float t = 0.08;
	float m = box(q, slot + vec2(0.0, 1.75), vec2(w, t), aa);
	m = max(m, box(q, slot + vec2(-w, 1.0), vec2(t, 0.75), aa));
	m = max(m, box(q, slot + vec2(w, 1.0), vec2(t, 0.75), aa));
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

	// Granulado do asfalto (fino e suave) com pedrinhas claras.
	vec2 pr = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	float n_big = vnoise(p * vec2(0.08, 0.03));
	float n_mid = fbm(pr * 0.45, 2);
	// Detalhe fino (granulado, pedrinhas e relevo) só onde aparece: de longe
	// (lod = 1) ele some de qualquer jeito, então nem é calculado.
	float n_fine = 0.5;
	vec2 fine_grad = vec2(0.0);
	float speck = 0.0;
	if (lod < 1.0) {
		vec3 nf = fbm_d(pr * 3.2, 2);
		n_fine = nf.x;
		fine_grad = nf.yz;
		vec2 sp = pr * 11.0;
		vec2 cell = floor(sp);
		vec2 dot_pos = hash22(cell) * 0.6 + 0.2;
		speck = (1.0 - smoothstep(0.06, 0.12, length(fract(sp) - dot_pos))) * step(0.7, hash12(cell + 7.0)) * (1.0 - lod);
	}
	// Variação da tinta: some junto com o detalhe, sem degrau no limite.
	float n_paint = mix(n_fine, 0.5, lod);
	float grain = 0.5 + (n_mid - 0.5) * 0.5 + (n_fine - 0.5) * 0.28 * (1.0 - lod);
	vec3 col = mix(asphalt_dark, asphalt_light, grain);
	col *= 0.94 + n_big * 0.12;
	col = mix(col, vec3(0.6, 0.6, 0.61), speck * 0.18);

	// Trilho dos pneus (mais escuro e liso).
	float wear = exp(-pow((abs(lateral) - 1.7) / 1.5, 2.0)) * (0.7 + 0.3 * n_big);
	col *= 1.0 - wear * 0.12;
	float rough = mix(0.8, 0.62, wear) - speck * 0.15;

	// Faixa branca contínua perto das bordas e tracejado discreto no meio.
	float paint = 0.0;
	float line_pos = curb_min + 0.28;
	paint = max(paint, 1.0 - smoothstep(0.11 - aa, 0.11 + aa, abs(edge - line_pos)));
	float dash = step(fract(along / 6.0), 0.45);
	paint = max(paint, dash * (1.0 - smoothstep(0.1 - aa, 0.1 + aa, abs(lateral))) * 0.55);

	// Posição relativa à linha de chegada (negativo = atrás dela).
	float s = along > track_length * 0.5 ? along - track_length : along;
	vec2 q = vec2(lateral, s);

	// Grid de largada: o jogador larga na pole (no meio), os outros atrás em zigue-zague.
	if (s < -grid_offset + 3.0 && s > -grid_offset - 38.0) {
		float slots = grid_slot(q, vec2(0.0, -grid_offset), aa);
		for (int k = 1; k < 6; k++) {
			float side = mod(float(k), 2.0) < 0.5 ? 1.0 : -1.0;
			slots = max(slots, grid_slot(q, vec2(3.6 * side, -grid_offset - 7.0 * float(k)), aa));
		}
		paint = max(paint, slots * 0.92);
	}

	// Logo "at" pintado no chão, logo depois da largada (alongado para ler de longe).
	vec3 paint_col = line_color;
	if (s > logo_start && s < logo_start + logo_length && abs(lateral) < logo_width * 0.5) {
		vec2 luv = vec2((lateral + logo_width * 0.5) / logo_width, 1.0 - (s - logo_start) / logo_length);
		vec4 logo = texture(logo_texture, luv);
		float chevron = smoothstep(0.05, 0.09, logo.r);
		float worn = 0.78 + 0.22 * smoothstep(0.25, 0.7, vnoise(p * 2.5));
		float m = logo.a * worn;
		paint_col = mix(line_color, paint_accent, chevron * step(0.01, m));
		paint = max(paint, m);
	}

	col = mix(col, paint_col * (0.92 + n_paint * 0.08), paint);
	rough = mix(rough, 0.5, paint);

	// Linha de chegada quadriculada com bordas brancas.
	if (abs(s) < 1.25 && edge > curb_min) {
		float sq = 0.62;
		float chk = mod(floor(lateral / sq) + floor((s + 0.93) / sq), 2.0);
		vec3 chk_col = chk < 0.5 ? vec3(0.04, 0.045, 0.06) : vec3(0.97);
		if (abs(s) > 0.93) {
			chk_col = vec3(0.97);
		}
		col = chk_col * (0.92 + n_paint * 0.08);
		rough = 0.5;
	}

	// Relevo fino (some com a distância). Mesma inclinação de antes (diferença
	// finita com passo de 0,06 m), agora pela derivada analítica do ruído.
	float k = (1.0 - lod) * (1.0 - paint * 0.7);
	vec2 h = fine_grad * (0.06 * 3.2);
	NORMAL_MAP = normalize(vec3(-h.x * 1.6 * k, -h.y * 1.6 * k, 1.0)) * 0.5 + 0.5;

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.45;
}
