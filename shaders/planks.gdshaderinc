// Tábuas de madeira atravessadas na pista (píer e passarela da praia, Track.beach_track).
// `p` = (metros de uma borda à outra, metros ao longo da pista). Devolve a cor e acumula
// a inclinação do relevo e a rugosidade. Usado pelo piso da pista (beach_road) e pelo
// tabuleiro da passarela, com o mesmo desenho (as tábuas continuam de um no outro).

const float PLANK_W = 0.34;
const float PLANK_GAP = 0.035;
const float PLANK_LEN = 4.2;

vec3 plank_color(vec2 p, float lod, float aa, inout vec2 slope, inout float rough) {
	// Tábua: fileira ao longo da pista; cada fileira emenda em pontos diferentes.
	float row = floor(p.y / PLANK_W);
	float shift = hash12(vec2(row, 3.7)) * PLANK_LEN;
	float seg = floor((p.x + shift) / PLANK_LEN);
	vec2 id = vec2(row, seg);
	float h = hash12(id);
	float h2 = hash12(id + 11.3);
	// Madeira de praia: castanho quente, umas mais claras (sol) e outras mais escuras.
	vec3 dark = vec3(0.44, 0.26, 0.14);
	vec3 mid = vec3(0.62, 0.4, 0.23);
	vec3 light = vec3(0.76, 0.56, 0.36);
	vec3 col = mix(dark, mid, smoothstep(0.0, 0.6, h));
	col = mix(col, light, smoothstep(0.65, 1.0, h) * 0.8);
	// Veios ao comprido da tábua (atravessando a pista).
	float vy = fract(p.y / PLANK_W);
	float grain = tnoise(vec2(p.x * 0.9 + h * 40.0, vy * 9.0 + row * 1.7));
	grain += 0.5 * tnoise(vec2(p.x * 3.1 + h2 * 20.0, vy * 26.0 + row));
	col *= 0.86 + 0.2 * grain * (1.0 - lod * 0.6);
	// Nós da madeira de vez em quando.
	vec2 kc = vec2(fract((p.x + shift) / PLANK_LEN) * PLANK_LEN - 0.6 - h2 * 2.6, (vy - 0.5) * PLANK_W);
	float knot = 1.0 - smoothstep(0.02, 0.06, length(kc * vec2(0.7, 1.4)));
	col = mix(col, dark * 0.7, knot * step(0.55, h2) * (1.0 - lod));
	// Desgaste no meio, onde os karts passam (mais claro e liso).
	float center = 1.0 - smoothstep(2.0, 6.5, abs(p.x));
	col = mix(col, col * 1.12 + vec3(0.03, 0.025, 0.015), center * 0.35);
	// Frestas entre as fileiras e as emendas.
	float gy = abs(vy - 0.5) * PLANK_W;
	float gap_row = smoothstep(PLANK_W * 0.5 - PLANK_GAP - aa, PLANK_W * 0.5 - PLANK_GAP + aa, gy);
	float ex = abs(fract((p.x + shift) / PLANK_LEN) - 0.5) * PLANK_LEN;
	float gap_end = smoothstep(PLANK_LEN * 0.5 - 0.02 - aa, PLANK_LEN * 0.5 - 0.02 + aa, ex);
	float gap = max(gap_row, gap_end) * (1.0 - lod * 0.7);
	col = mix(col, vec3(0.08, 0.05, 0.03), gap);
	// Pregos perto das pontas de cada tábua, em cima das vigas (a cada 1,4 m).
	if (lod < 0.8) {
		float bx = fract((p.x + 0.7) / 1.4) * 1.4 - 0.7;
		vec2 nail_a = vec2(bx, (vy - 0.27) * PLANK_W);
		vec2 nail_b = vec2(bx, (vy - 0.73) * PLANK_W);
		float nail = 1.0 - smoothstep(0.008, 0.016, min(length(nail_a), length(nail_b)));
		col = mix(col, vec3(0.22, 0.22, 0.24), nail * (1.0 - lod));
	}
	// Cada tábua levemente torta: a luz pega diferente.
	slope += vec2((h - 0.5) * 0.06, (vy - 0.5) * 0.12 * (1.0 - gap));
	rough = mix(0.78, 0.92, gap) - center * 0.08;
	return col;
}
