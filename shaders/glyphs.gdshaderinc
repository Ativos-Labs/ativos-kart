// Hieróglifos entalhados e pintados (assets/textures/hieroglifos.png, grade 4×4 feita
// por tools/deserto/gerar_hieroglifos.py): R = desenho, G = linhas entre as colunas de
// escrita, B = número do símbolo. Precisa de noise.gdshaderinc (hash12) antes e de
// `glyph_tex` (Track.GLYPHS).

uniform sampler2D glyph_tex : filter_linear_mipmap_anisotropic, repeat_enable;

// Tintas das pedras do Egito (lápis-lazúli, ocre vermelho, malaquita e ouro).
vec3 glyph_paint(float k) {
	float m = mod(k, 4.0);
	if (m < 0.5) {
		return vec3(0.12, 0.24, 0.66);
	} else if (m < 1.5) {
		return vec3(0.66, 0.2, 0.1);
	} else if (m < 2.5) {
		return vec3(0.16, 0.48, 0.36);
	}
	return vec3(0.95, 0.72, 0.2);
}

// `q` em células (uma célula = um símbolo; x e y contínuos). Cada célula sorteia um dos
// 16 símbolos com `seed`. `qx`/`qy` = derivadas de `q` na tela, calculadas fora de "if"
// (dentro de um desvio elas não valem na web). Devolve (desenho, linha de coluna,
// número do símbolo 0..15).
vec3 glyph_cell(vec2 q, vec2 qx, vec2 qy, float seed) {
	vec2 c = floor(q);
	float idx = floor(hash12(c * vec2(1.0, 1.37) + vec2(seed, seed * 0.61)) * 16.0);
	vec2 cell = vec2(mod(idx, 4.0), floor(idx / 4.0));
	vec2 uv = (cell + fract(q)) * 0.25;
	// Derivadas da coordenada contínua: sem costura de mipmap na borda das células.
	vec3 g = textureGrad(glyph_tex, uv, qx * 0.25, qy * 0.25).rgb;
	return vec3(g.r, g.g, idx);
}

// Pinta um painel de hieróglifos em `col`: `q` em células, `amount` = força (0 fora do
// painel). Entalhe mais escuro com tinta desbotada; devolve a cor e, em `carve`, o quanto
// o ponto está entalhado (para escurecer o relevo / rugosidade).
vec3 glyph_paint_over(vec3 col, vec2 q, vec2 qx, vec2 qy, float seed, float amount, float fade, out float carve) {
	vec3 g = glyph_cell(q, qx, qy, seed);
	carve = g.x * amount;
	vec3 paint = glyph_paint(g.z + floor(q.x));
	vec3 carved = mix(col * 0.62, paint, 0.55 * fade);
	col = mix(col, carved, carve);
	// Linhas das colunas de escrita, entalhadas mais leves.
	col = mix(col, col * 0.78, g.y * amount * 0.6);
	return col;
}
