shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Arenito dos monumentos do Egito (pirâmides, obeliscos, portais e colunas do templo):
// blocos em fiadas (pela posição no mundo), manchas do tempo escorrendo, areia
// acumulada no que fica virado para cima, colunas de hieróglifos pintados e faixas de
// cor (capitéis). As malhas do TrackEgypt têm UV.x = 0..1 de um lado ao outro da face
// (ou a volta inteira na coluna) e UV.y = altura em metros.

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"
#include "res://shaders/glyphs.gdshaderinc"

uniform vec3 stone_light : source_color = vec3(0.87, 0.7, 0.47);
uniform vec3 stone_dark : source_color = vec3(0.69, 0.5, 0.32);
uniform vec3 joint_color : source_color = vec3(0.47, 0.33, 0.2);
uniform vec3 sand_color : source_color = vec3(0.91, 0.73, 0.47);
uniform float block_w = 1.8;
uniform float block_h = 0.9;
// Força das juntas entre os blocos (0 = pedra lisa, como num obelisco de uma peça).
uniform float joints = 1.0;
// Areia acumulada nas faces viradas para cima.
uniform float sand_cover = 0.7;
// Colunas de hieróglifos: quantas cabem entre glyph_u.x e glyph_u.y (0 = sem), da
// altura glyph_v.x até glyph_v.y (m), com símbolos de glyph_size m.
uniform float glyph_cols = 0.0;
uniform vec2 glyph_u = vec2(0.0, 1.0);
uniform vec2 glyph_v = vec2(0.0, 0.0);
uniform float glyph_size = 0.8;
// Faixas pintadas (capitel): de band_v.x até band_v.y m, band_v.z listras por metro,
// band_v.w = força.
uniform vec4 band_v = vec4(0.0);

varying vec3 wpos;
varying vec3 wnorm;
varying float obj_seed;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 o = MODEL_MATRIX[3].xyz;
	obj_seed = floor(o.x * 0.37) + floor(o.z * 0.53) * 7.0;
}

void fragment() {
	vec3 n = normalize(wnorm);
	vec2 q;
	if (abs(n.y) > 0.75) {
		q = wpos.xz;
	} else {
		vec2 t = normalize(vec2(-n.z, n.x) + vec2(0.0001));
		q = vec2(dot(wpos.xz, t), wpos.y);
	}
	vec2 bq = q / vec2(block_w, block_h);
	float row = floor(bq.y);
	bq.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(bq);
	vec2 f = fract(bq);
	float lod = clamp(length(fwidth(bq)) * 2.5, 0.0, 1.0);
	float h = hash12(cell + vec2(row * 17.0, 3.0));
	float grain = tnoise(q * 1.6);
	vec3 col = mix(stone_dark, stone_light, clamp(0.35 + 0.45 * h + 0.25 * (grain - 0.5) * 2.0, 0.0, 1.0));
	// Manchas do tempo escorrendo pela pedra.
	float streak = tnoise(vec2(q.x * 0.9, q.y * 0.08));
	col *= 0.9 + 0.14 * streak;
	vec2 fw = fwidth(bq) * 1.2;
	vec2 e = smoothstep(vec2(0.0), vec2(0.04) + fw, f) * smoothstep(vec2(0.0), vec2(0.04) + fw, 1.0 - f);
	float joint = (1.0 - e.x * e.y) * joints * (1.0 - lod * 0.85);
	col = mix(col, joint_color, joint * 0.7);
	float rough = 0.88;

	// Derivadas fora dos "if" (veja glyphs.gdshaderinc).
	float gw = max(glyph_u.y - glyph_u.x, 0.001);
	vec2 gq = vec2((UV.x - glyph_u.x) / gw * glyph_cols, (glyph_v.y - UV.y) / glyph_size);
	vec2 gqx = dFdx(gq);
	vec2 gqy = dFdy(gq);
	if (glyph_cols > 0.0 && abs(n.y) < 0.75) {
		float inside = step(glyph_u.x, UV.x) * step(UV.x, glyph_u.y) * step(glyph_v.x, UV.y) * step(UV.y, glyph_v.y);
		if (inside > 0.0) {
			float carve = 0.0;
			col = glyph_paint_over(col, gq, gqx, gqy, obj_seed, 1.0 - lod * 0.7, 0.85, carve);
			rough = mix(rough, 0.95, carve);
		}
	}
	if (band_v.w > 0.0 && UV.y > band_v.x && UV.y < band_v.y) {
		float stripe = mod(floor((UV.y - band_v.x) * band_v.z), 3.0);
		vec3 paint = stripe < 0.5 ? vec3(0.12, 0.26, 0.66) : (stripe < 1.5 ? vec3(0.95, 0.74, 0.22) : vec3(0.18, 0.5, 0.36));
		col = mix(col, paint * (0.85 + 0.25 * grain), band_v.w);
	}

	// Areia acumulada no que fica virado para cima.
	float sand = smoothstep(0.55, 0.9, n.y + (tnoise(wpos.xz * 0.8) - 0.5) * 0.4) * sand_cover;
	col = mix(col, sand_color * (0.94 + 0.08 * grain), sand);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
}
