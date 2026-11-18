shader_type spatial;
// Contrato da Cessão de crédito que o Celerino-fantasma assina no ar: papel creme com a
// faixa do título, linhas de texto, a assinatura surgindo (`reveal`) e o carimbo
// vermelho batendo (`stamp`). Tudo desenhado aqui, sem textura.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always, shadows_disabled;

uniform float alpha = 1.0;
uniform float reveal = 0.0;
uniform float stamp = 0.0;

const vec3 PAPER = vec3(0.98, 0.96, 0.88);
const vec3 NAVY = vec3(0.06, 0.09, 0.22);
const vec3 GRAY = vec3(0.6, 0.63, 0.72);
const vec3 RED = vec3(0.95, 0.2, 0.2);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Rabisco da assinatura: altura da linha em `u` (0..1).
float signature_y(float u) {
	return 0.79 + 0.05 * sin(u * 34.0) * (0.6 + 0.4 * sin(u * 7.0 + 1.0)) + 0.015 * sin(u * 71.0);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = PAPER;
	float aa = fwidth(uv.y) * 1.5;
	// Faixa do título.
	if (uv.y < 0.15) {
		col = NAVY;
		// "letras" do título: blocos amarelos.
		float title = step(0.18, uv.x) * step(uv.x, 0.82) * step(0.055, uv.y) * step(uv.y, 0.1);
		title *= step(0.25, fract(uv.x * 14.0));
		col = mix(col, vec3(1.0, 0.82, 0.1), title);
	}
	// Linhas de texto (comprimentos sorteados por linha).
	float row = floor((uv.y - 0.22) / 0.07);
	float inside = step(0.22, uv.y) * step(uv.y, 0.64);
	float row_v = fract((uv.y - 0.22) / 0.07);
	float row_end = 0.88 - 0.3 * hash(row + 3.0);
	float bar = inside * step(0.1, uv.x) * step(uv.x, row_end) * (1.0 - smoothstep(0.28, 0.36, abs(row_v - 0.5)));
	col = mix(col, GRAY, bar);
	// Linha da assinatura e o rabisco surgindo da esquerda para a direita.
	float base = (1.0 - smoothstep(0.0, aa, abs(uv.y - 0.86) - 0.004)) * step(0.1, uv.x) * step(uv.x, 0.66);
	col = mix(col, GRAY, base);
	float u = (uv.x - 0.12) / 0.5;
	if (u > 0.0 && u < min(reveal, 1.0)) {
		float d = abs(uv.y - signature_y(u));
		col = mix(col, NAVY, 1.0 - smoothstep(0.012, 0.012 + aa, d));
	}
	// Carimbo: anel vermelho que bate grande e assenta.
	if (stamp > 0.0) {
		vec2 c = vec2(0.78, 0.8);
		float r = 0.12 * (1.0 + 1.2 * (1.0 - stamp));
		float d = abs(length((uv - c) * vec2(1.0, 0.78)) - r);
		float ring = 1.0 - smoothstep(0.018, 0.018 + aa, d);
		float dot_c = 1.0 - smoothstep(r * 0.45, r * 0.45 + aa, length((uv - c) * vec2(1.0, 0.78)));
		col = mix(col, RED, max(ring, dot_c * 0.85) * stamp);
	}
	// Borda do papel.
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	col = mix(col, NAVY, 1.0 - smoothstep(0.012, 0.012 + aa, edge));
	// Um toque fantasma: levemente azulado.
	ALBEDO = mix(col, vec3(0.8, 0.9, 1.0), 0.08);
	ALPHA = alpha * 0.95;
}
