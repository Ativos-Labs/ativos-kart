// Ruído de valor por textura: uma leitura no lugar das quatro contas de hash do vnoise
// (noise.gdshaderinc). `noise_tex` é ruído branco 256×256 (assets/textures/ruido.png,
// tools/gelo/gerar_ruido.gd): cada texel é um ponto da grade, e a interpolação suave sai
// da filtragem linear com a coordenada deslocada pela curva suave (truque da Inigo
// Quilez). Repete a cada 256 células. Quem usa precisa receber a textura
// (Track.NOISE_TEXTURE).

uniform sampler2D noise_tex : filter_linear, repeat_enable;

// Igual ao vnoise: 0 a 1, uma célula por unidade.
float tnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return textureLod(noise_tex, (i + f + 0.5) * (1.0 / 256.0), 0.0).r;
}

// Igual ao fbm(p, 2).
float tfbm2(vec2 p) {
	float a = tnoise(p);
	float b = tnoise(mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(5.3, 1.7));
	return (a * 0.5 + b * 0.25) * (1.0 / 0.75);
}

// (valor, d/dx, d/dy) por diferenças (3 leituras), no lugar do vnoise_d.
vec3 tnoise_d(vec2 p) {
	float e = 0.12;
	float v = tnoise(p);
	return vec3(v, (tnoise(p + vec2(e, 0.0)) - v) / e, (tnoise(p + vec2(0.0, e)) - v) / e);
}

// Igual às caustics() (noise.gdshaderinc).
float tcaustics(vec2 p, float t) {
	vec2 q = p * 0.42;
	float a = tnoise(q + vec2(t * 0.31, t * 0.17));
	float b = tnoise(q * 1.63 - vec2(t * 0.23, -t * 0.29) + vec2(3.1, 7.7));
	float c = clamp(1.0 - abs(a - b) * 5.0, 0.0, 1.0);
	return c * c * c * c;
}
