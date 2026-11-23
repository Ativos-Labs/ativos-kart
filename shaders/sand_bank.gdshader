shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Montes de areia da pista do deserto (Track.sand_track): os barrancos no lugar das
// muretas — com um bloco de arenito meio enterrado a cada trecho, entalhado com a marca
// da Ativos e uma fileira de hieróglifos pintados — e a leira baixa de areia empurrada
// no lugar das zebras (`lip`).
// UV.x = metros pelo perfil, de dentro (pé virado para a pista) para fora;
// UV.y = metros ao longo da pista. COLOR.r = debaixo d'água (oásis), COLOR.g = dunas.

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"
#include "res://shaders/glyphs.gdshaderinc"

uniform vec3 sand_light : source_color = vec3(0.91, 0.73, 0.47);
uniform vec3 sand_shade : source_color = vec3(0.8, 0.58, 0.35);
uniform vec3 sand_dark : source_color = vec3(0.68, 0.46, 0.27);
uniform vec3 stone_light : source_color = vec3(0.86, 0.68, 0.46);
uniform vec3 stone_dark : source_color = vec3(0.66, 0.48, 0.31);
uniform vec3 lapis : source_color = vec3(0.12, 0.22, 0.62);
uniform vec3 gold : source_color = vec3(1.0, 0.78, 0.22);
uniform vec3 algae_color : source_color = vec3(0.3, 0.42, 0.18);
// Leira baixa da borda da pista (sem blocos).
uniform bool lip = false;
uniform sampler2D wordmark : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wordmark_aspect = 3.6;
// 1 = barranco da esquerda, -1 = da direita (o texto não sai espelhado).
uniform float mirror = 1.0;
// Distância entre os blocos de arenito e o comprimento de cada um (m).
uniform float panel_period = 48.0;
uniform float panel_length = 4.6;

varying vec3 world_pos;
varying float under_f;
varying float dune_f;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	under_f = COLOR.r;
	dune_f = COLOR.g;
}

void fragment() {
	float u = UV.x;
	float along = UV.y;
	vec2 p = vec2(u * 3.0, along);
	float lod = clamp(length(fwidth(p)) * 4.0, 0.0, 1.0);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;

	float n_big = tnoise(vec2(along * 0.08, u * 0.6));
	float n_mid = tnoise(vec2(along * 0.6, u * 2.2));
	vec3 fine = vec3(0.5, 0.0, 0.0);
	if (lod < 1.0) {
		fine = tnoise_d(vec2(along, u * 1.3) * 2.4);
	}
	// A face à sombra (mais íngreme) fica mais escura e alaranjada.
	float steep = 1.0 - clamp(wn.y, 0.0, 1.0);
	vec3 col = mix(sand_light, sand_shade, clamp(steep * 0.7 + (0.5 - n_mid) * 0.35 + (0.5 - fine.x) * 0.15, 0.0, 1.0));
	col = mix(col, sand_dark, smoothstep(0.55, 0.9, steep) * 0.4);
	vec2 slope = fine.yz * 0.12 * (1.0 - lod);
	float rough = 0.95;

	// Ondinhas do vento no alto e na face de fora (mais suave).
	float rip_k = (1.0 - smoothstep(0.15, 0.6, lod)) * clamp(wn.y * 1.4 - 0.3, 0.0, 1.0);
	if (rip_k > 0.001) {
		float r = world_pos.x * 0.85 + world_pos.z * 0.53 + n_big * 4.0;
		float w = fract(r / 0.7);
		float hgt = smoothstep(0.0, 0.75, w) - smoothstep(0.75, 1.0, w);
		col *= 1.0 + (hgt - 0.5) * 0.1 * rip_k;
		slope.x += cos(r * 8.98) * 0.18 * rip_k;
	}

	// Derivadas para os blocos (fora dos "if").
	vec2 gx = vec2(dFdx(along * mirror), dFdx(u));
	vec2 gy = vec2(dFdy(along * mirror), dFdy(u));
	if (!lip) {
		// Areia escorrida no pé do barranco (mais escura onde os karts passam raspando).
		float spray = (1.0 - smoothstep(0.1, 0.5, u + (n_mid - 0.5) * 0.3)) * (0.6 + 0.4 * n_big);
		col = mix(col, sand_dark, spray * 0.3 * (1.0 - dune_f));

		// Bloco de arenito meio enterrado, com a marca e uma fileira de hieróglifos.
		float x = mod(along * mirror, panel_period);
		if (x < panel_length && u > 0.1 && u < 1.55) {
			float aa = fwidth(along) * 1.5 + 0.01;
			// A areia cobre as pontas e o pé do bloco de um jeito irregular.
			float bury = 0.18 + 0.22 * tnoise(vec2(x * 1.3, floor(along / panel_period) * 3.1));
			float inside = smoothstep(0.0, 0.1 + aa, x) * smoothstep(panel_length, panel_length - 0.1 - aa, x)
					* smoothstep(bury, bury + 0.08, u) * smoothstep(1.55, 1.45, u);
			vec3 stone = mix(stone_dark, stone_light, 0.55 + 0.35 * n_mid + 0.1 * fine.x);
			// Juntas dos blocos.
			float joint = 1.0 - smoothstep(0.0, 0.03 + aa, abs(fract(x / (panel_length / 3.0) + 0.5) - 0.5) * (panel_length / 3.0));
			stone = mix(stone, stone_dark * 0.7, joint * 0.5);
			// Faixa de cima: a marca em lápis-lazúli entre filetes dourados.
			float lh = 0.4;
			float lw = lh * wordmark_aspect;
			vec2 luv = vec2((x - panel_length * 0.5) / lw + 0.5, 0.5 - (u - 1.12) / lh);
			vec4 l = vec4(0.0);
			if (luv.x > 0.0 && luv.x < 1.0 && luv.y > 0.0 && luv.y < 1.0) {
				vec2 sc = vec2(1.0 / lw, -1.0 / lh);
				l = textureGrad(wordmark, luv, gx * sc, gy * sc);
			}
			stone = mix(stone, lapis, l.a * 0.92);
			float band = smoothstep(0.02 + aa, 0.0, abs(u - 0.88)) + smoothstep(0.02 + aa, 0.0, abs(u - 1.38));
			stone = mix(stone, gold * 0.9, band * 0.8);
			// Fileira de hieróglifos embaixo da marca.
			float carve = 0.0;
			float row = smoothstep(0.32, 0.36, u) * smoothstep(0.84, 0.8, u);
			vec2 gs = vec2(1.0 / 0.46, -1.0 / 0.46);
			stone = glyph_paint_over(stone, vec2(x / 0.46, (0.82 - u) / 0.46), gx * gs, gy * gs,
					floor(along / panel_period) + mirror * 7.0, row, 0.9, carve);
			col = mix(col, stone, inside);
			rough = mix(rough, 0.85, inside);
			slope = mix(slope, vec2(0.0), inside * 0.8);
		}
	}

	// Debaixo d'água: areia molhada com algas.
	if (under_f > 0.001) {
		float algae = smoothstep(0.5, 0.78, tnoise(vec2(along * 0.15, u * 0.8) + 4.0));
		col = mix(col, mix(col * vec3(0.72, 0.76, 0.72), algae_color, algae * 0.5), under_f);
	}

	NORMAL_MAP = normalize(vec3(-slope.x, -slope.y, 1.0)) * 0.5 + 0.5;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
}
