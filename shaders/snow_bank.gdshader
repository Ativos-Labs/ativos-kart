shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Montes de neve da pista de neve e gelo (Track.snow_track): os barrancos no lugar das
// muretas (com blocos de gelo azul com a marca da Ativos congelada dentro, a cada
// trecho) e a leira baixa de neve empurrada no lugar das zebras (`lip`).
// UV.x = metros pelo perfil, de dentro (pé virado para a pista) para fora;
// UV.y = metros ao longo da pista. COLOR.r = gelo (trecho de rio congelado).

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"

uniform vec3 snow_light : source_color = vec3(0.96, 0.98, 1.0);
uniform vec3 snow_shade : source_color = vec3(0.78, 0.85, 0.95);
uniform vec3 slush : source_color = vec3(0.62, 0.7, 0.82);
uniform vec3 ice_light : source_color = vec3(0.62, 0.86, 0.98);
uniform vec3 ice_dark : source_color = vec3(0.13, 0.4, 0.66);
uniform vec3 sun_dir = vec3(0.43, 0.64, 0.63);
uniform float sparkle = 5.0;
// Leira baixa da borda da pista (sem placas).
uniform bool lip = false;
uniform sampler2D wordmark : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wordmark_aspect = 3.6;
// 1 = barranco da esquerda, -1 = da direita (o texto não sai espelhado).
uniform float mirror = 1.0;
// Distância entre os blocos com a marca e o comprimento de cada um (m).
uniform float panel_period = 54.0;
uniform float panel_length = 4.2;

varying vec3 world_pos;
varying float ice_f;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ice_f = COLOR.r;
}

void fragment() {
	float u = UV.x;
	float along = UV.y;
	vec2 p = vec2(u * 3.0, along);
	float lod = clamp(length(fwidth(p)) * 4.0, 0.0, 1.0);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 ray = normalize(world_pos - CAMERA_POSITION_WORLD);

	float n_big = tnoise(vec2(along * 0.09, u * 0.6));
	float n_mid = tnoise(vec2(along * 0.6, u * 2.2));
	vec3 fine = vec3(0.5, 0.0, 0.0);
	if (lod < 1.0) {
		fine = tnoise_d(vec2(along, u * 1.3) * 2.6);
	}
	// Mais azulado onde a encosta é íngreme (a neve funda e compactada).
	float steep = 1.0 - clamp(wn.y, 0.0, 1.0);
	vec3 col = mix(snow_light, snow_shade, clamp(steep * 0.55 + (0.5 - n_mid) * 0.35 + (0.5 - fine.x) * 0.15, 0.0, 1.0));
	vec2 slope = fine.yz * 0.16 * (1.0 - lod);
	float rough = 0.85;
	float spec = 0.35;

	if (!lip) {
		// Camadas da neve cortada pela máquina na face virada para a pista.
		float layers = sin(world_pos.y * 9.0 + n_big * 6.0) * 0.5 + 0.5;
		col *= 1.0 - steep * layers * 0.06;
		// Lama de neve borrifada pelos karts no pé do barranco.
		float spray = (1.0 - smoothstep(0.1, 0.55, u + (n_mid - 0.5) * 0.3)) * (0.6 + 0.4 * n_big);
		col = mix(col, slush, spray * 0.45);
		// No rio congelado o pé do barranco vira gelo.
		col = mix(col, mix(ice_dark, ice_light, 0.6 + 0.4 * n_mid), ice_f * (1.0 - smoothstep(0.05, 0.4, u)) * 0.8);

		// Bloco de gelo com a marca congelada dentro, na face de dentro.
		float x = mod(along * mirror, panel_period);
		if (x < panel_length && u > 0.12 && u < 1.25) {
			float aa = fwidth(along) * 1.5 + 0.01;
			float inside = smoothstep(0.0, 0.08 + aa, x) * smoothstep(panel_length, panel_length - 0.08 - aa, x)
					* smoothstep(0.12, 0.2, u) * smoothstep(1.25, 1.15, u);
			// Gelo azul com brilho no alto e um fundo mais escuro (parece fundo).
			vec3 block = mix(ice_dark, ice_light, smoothstep(0.15, 1.2, u) * 0.45 + n_mid * 0.2);
			float lh = 0.52;
			float lw = lh * wordmark_aspect;
			vec2 luv = vec2((x - panel_length * 0.5) / lw + 0.5, 0.5 - (u - 0.68) / lh);
			vec4 l = vec4(0.0);
			if (luv.x > 0.0 && luv.x < 1.0 && luv.y > 0.0 && luv.y < 1.0) {
				l = texture(wordmark, luv);
			}
			// A marca aparece branca e leitosa, como se estivesse dentro do gelo.
			block = mix(block, vec3(0.97, 0.99, 1.0), l.a * 0.92);
			col = mix(col, block, inside);
			rough = mix(rough, 0.12, inside);
			spec = mix(spec, 0.7, inside);
			slope *= 1.0 - inside;
		}
	}

	// Cristais brilhando contra o sol.
	vec3 emit = vec3(0.0);
	if (lod < 0.95) {
		vec2 sp = vec2(along, u) * 8.0;
		vec2 cell = floor(sp);
		vec2 o = hash22(cell + 1.7) * 0.6 + 0.2;
		vec3 facet = normalize(wn + vec3(o.x - 0.5, 0.0, o.y - 0.5) * 1.3);
		float mirror_k = dot(reflect(ray, facet), normalize(sun_dir));
		float dot_mask = 1.0 - smoothstep(0.14, 0.26, length(fract(sp) - o));
		vec3 tint = mix(vec3(1.0), 0.5 + 0.5 * cos(6.2831 * (hash12(cell + 9.4) + vec3(0.0, 0.33, 0.67))), 0.65);
		emit = tint * smoothstep(0.972, 0.99, mirror_k) * dot_mask
				* step(0.72, hash12(cell)) * sparkle * (1.0 - smoothstep(0.55, 0.95, lod)) * (1.0 - spec + 0.35);
	}

	NORMAL_MAP = normalize(vec3(-slope.x, -slope.y, 1.0)) * 0.5 + 0.5;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
}
