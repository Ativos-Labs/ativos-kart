// Gelo de rio congelado, compartilhado pela pista de gelo (snow_road.gdshader) e pela
// água congelada (water.gdshader com `ice`): por cima, gelo liso riscado pelos patins e
// pelos pneus, com geada; por baixo (paralaxe: cada camada é vista pelo raio da câmera
// a uma profundidade), rachaduras, bolhas de ar presas em camadas e o fundo do rio, azul
// escuro, com peixes nadando devagar. Feito para ser barato: o ruído vem da textura
// (tnoise, uma leitura) e as rachaduras são linhas de nível do ruído — a primeira
// versão, com Voronoi e ruído por hash, custava ~2,5 ms por quadro a 1080p na web (M4).
// Precisa de noise.gdshaderinc e noise_tex.gdshaderinc antes.

// Bolhas presas no gelo (0 = nada, 1 = borda clara de uma bolha) numa camada.
float ice_bubbles(vec2 p, float density) {
	vec2 cell = floor(p);
	float h = hash12(cell + 19.7);
	if (h > density) {
		return 0.0;
	}
	vec2 f = fract(p) - 0.5;
	float m = 0.0;
	for (int k = 0; k < 3; k++) {
		vec2 c = (hash22(cell + float(k) * 7.31) - 0.5) * 0.5;
		float r = mix(0.025, 0.1, hash12(cell + float(k) * 3.7 + 1.0));
		float d = length(f - c);
		// Bolha: disco translúcido com a borda clara e um brilho no alto.
		float disc = 1.0 - smoothstep(r * 0.82, r, d);
		float rim = disc - (1.0 - smoothstep(r * 0.45, r * 0.8, d)) * 0.75;
		float glint = 1.0 - smoothstep(0.0, r * 0.3, length(f - c - vec2(-0.3, 0.3) * r));
		m = max(m, rim * 0.8 + glint);
	}
	return clamp(m, 0.0, 1.0);
}

// Silhuetas de peixes nadando em roda (0 a 1), borradas pela profundidade.
float ice_fish(vec2 p, float t) {
	float size = 7.0;
	vec2 cell = floor(p / size);
	float h = hash12(cell + 41.3);
	if (h > 0.45) {
		return 0.0;
	}
	vec2 hh = hash22(cell + 5.1);
	vec2 center = (cell + 0.5) * size;
	float dir = h < 0.22 ? 1.0 : -1.0;
	float w = (0.18 + 0.14 * hh.x) * dir;
	float a = t * w + hh.y * 6.283;
	vec2 rad = vec2(1.9, 1.2);
	vec2 pos = center + vec2(cos(a), sin(a)) * rad;
	vec2 vel = normalize(vec2(-sin(a), cos(a)) * rad * dir);
	vec2 rel = p - pos;
	// No referencial do peixe: x = da cauda para a cabeça.
	vec2 q = vec2(dot(rel, vel), dot(rel, vec2(-vel.y, vel.x)));
	float len = 0.45 + 0.35 * hh.x;
	// O corpo ondula um pouco.
	q.y += sin(q.x * 5.0 - t * 6.0) * 0.04;
	float body = length(q / vec2(len, len * 0.24));
	float fish = 1.0 - smoothstep(0.75, 1.15, body);
	// Cauda em leque atrás do corpo.
	float tx = -q.x - len * 0.8;
	float tail_w = tx * 0.75;
	float tail = smoothstep(-0.02, 0.04, tx) * (1.0 - smoothstep(len * 0.42, len * 0.5, tx))
			* (1.0 - smoothstep(tail_w - 0.03, tail_w + 0.04, abs(q.y)));
	return max(fish, tail);
}

// Ponto da camada a `depth` m abaixo da superfície, visto pelo raio `ray` (unitário,
// da câmera para o ponto, espaço do mundo), no mesmo referencial de `q`: `axis_x`/`axis_y`
// = direções (no plano XZ do mundo) dos eixos de `q`.
vec2 ice_layer(vec2 q, vec3 ray, vec2 axis_x, vec2 axis_y, float depth) {
	vec2 off = ray.xz * (depth / max(-ray.y, 0.22));
	return q + vec2(dot(off, axis_x), dot(off, axis_y));
}

// Cor e acabamento do gelo. `q` = coordenadas (m) com y ao longo da correnteza (as
// riscas seguem y); `edge` = distância (m) até a margem (neve na beira); `lod` = 0 de
// perto, 1 de longe (some o detalhe fino); `t` = TIME; `wear` = quanto o gelo é riscado
// (1 na pista, menos no lago em volta, onde ninguém passa).
void ice_shade(vec2 q, vec3 ray, vec2 axis_x, vec2 axis_y, float edge, float lod, float t, float wear,
		vec3 shallow, vec3 deep, out vec3 col, out float rough, out float spec, out vec3 emit) {
	// Fundo do rio: escuro, com manchas (pedras e areia, poços mais fundos) e peixes.
	vec2 qb = ice_layer(q, ray, axis_x, axis_y, 2.4);
	float bed = tnoise(qb * 0.16);
	float pool = smoothstep(0.3, 0.75, tnoise(qb * 0.085 + 7.0));
	vec3 bottom = deep * (0.7 + 0.45 * bed);
	float fish = ice_fish(qb, t);
	bottom *= 1.0 - fish * 0.55;
	// Caminho da luz dentro do gelo: olhando de lado fica mais azul e escuro.
	float path = 1.0 - exp(-1.6 / max(-ray.y, 0.15));
	col = mix(shallow, bottom, 0.24 + 0.45 * path + 0.07 * pool);
	emit = vec3(0.0);

	// Rachaduras: linhas que serpenteiam (onde o ruído cruza o meio), só em alguns
	// trechos; a funda bem apagada.
	vec2 qc = ice_layer(q, ray, axis_x, axis_y, 0.7);
	float c1 = abs(tnoise(qc * 0.17) - 0.5);
	float crack_deep = (1.0 - smoothstep(0.0, 0.012 + lod * 0.02, c1)) * smoothstep(0.45, 0.65, tnoise(qc * 0.05 + 2.0)) * (1.0 - lod);
	col = mix(col, vec3(0.86, 0.95, 1.0), crack_deep * 0.3);
	if (lod < 1.0) {
		float fade = 1.0 - lod;
		// Luz dançando no fundo.
		emit = shallow * tcaustics(qb, t * 0.7) * 0.05 * fade;
		vec2 qs = ice_layer(q, ray, axis_x, axis_y, 0.2);
		float c2 = abs(tnoise(qs * 0.45 + 4.1) - 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.01, c2)) * smoothstep(0.5, 0.7, tnoise(qs * 0.12 + 9.0));
		col = mix(col, vec3(0.95, 0.99, 1.0), crack * 0.6 * fade);
		// Bolhas de ar presas em camadas (a funda menor e mais azul).
		float b1 = ice_bubbles(ice_layer(q, ray, axis_x, axis_y, 1.1) * 1.6, 0.26);
		float b2 = ice_bubbles(ice_layer(q, ray, axis_x, axis_y, 0.4) * 1.1 + 9.0, 0.16);
		col = mix(col, vec3(0.78, 0.9, 1.0), b1 * 0.5 * fade);
		col = mix(col, vec3(0.97, 1.0, 1.0), b2 * 0.75 * fade);
	}

	// Superfície: manchas largas e claras de gelo polido ao longo da correnteza e
	// riscos finos de patins e pneus (onde não há mancha), em leque.
	float smear = 0.0;
	float scratch = 0.0;
	if (wear > 0.01) {
		for (int k = 0; k < 2; k++) {
			float ang = (float(k) - 0.5) * 0.09;
			float ca = cos(ang);
			float sa = sin(ang);
			vec2 r = vec2(q.x * ca - q.y * sa, q.x * sa + q.y * ca);
			float mask = tnoise(r * vec2(0.3, 0.02) + float(k) * 5.0);
			float wide = tnoise(vec2(r.x * 0.9 + float(k) * 13.1, r.y * 0.025));
			smear = max(smear, (1.0 - smoothstep(0.0, 0.09, abs(wide - 0.5))) * smoothstep(0.35, 0.7, mask));
			float thin = tnoise(vec2(r.x * 6.0 + float(k) * 7.7, r.y * 0.06));
			scratch = max(scratch, (1.0 - smoothstep(0.0, 0.018 + lod * 0.06, abs(thin - 0.5))) * smoothstep(0.4, 0.7, 1.0 - mask));
		}
		smear *= wear;
		scratch *= wear;
		col = mix(col, vec3(0.9, 0.96, 1.0), smear * 0.3);
		col = mix(col, vec3(0.96, 0.99, 1.0), scratch * 0.4 * (1.0 - lod * 0.7));
	}
	// Geada fina em manchas e neve soprada na beira.
	float frost = tfbm2(q * vec2(0.09, 0.05) + 2.0);
	float frost_m = smoothstep(0.55, 0.8, frost);
	float bank = 1.0 - smoothstep(0.3, 2.4, edge + (tnoise(q * 0.5) - 0.5) * 1.6);
	float snow = max(frost_m * 0.5, bank);
	col = mix(col, vec3(0.94, 0.97, 1.0), snow);
	rough = mix(0.04, 0.3, max(scratch, smear * 0.5));
	rough = mix(rough, 0.7, snow);
	spec = mix(0.62, 0.35, snow);
	emit *= 1.0 - snow;
}
