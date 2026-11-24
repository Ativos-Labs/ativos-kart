shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Muretas com placas de patrocínio da Ativos (logo e marca) do lado da pista
// e listras azuis e brancas do lado de fora.
// UV.x = altura em metros; UV.y = metros ao longo da pista.

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D logo_icon : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D wordmark_light : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D wordmark_dark : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float icon_aspect = 1.64;
uniform float wordmark_aspect = 3.6;

uniform vec3 brand_blue : source_color = vec3(0.149, 0.239, 0.749);
uniform vec3 brand_light : source_color = vec3(0.373, 0.447, 0.851);
uniform vec3 navy : source_color = vec3(0.06, 0.09, 0.22);
uniform vec3 yellow : source_color = vec3(1.0, 0.82, 0.1);
uniform vec3 base_color : source_color = vec3(0.12, 0.13, 0.17);
uniform vec3 trim_color : source_color = vec3(0.97, 0.97, 0.98);

uniform float wall_height = 1.1;
// 1 = muro do lado esquerdo, -1 = do lado direito (para o texto não sair espelhado).
uniform float mirror = 1.0;
// false = placas viradas para a pista; true = lado de fora e topo.
uniform bool outer_side = false;
// Placas acesas como painel de LED (cidade à noite). 0 = placas comuns.
uniform float glow = 0.0;

const float BANNER_BOTTOM = 0.14;
const float PERIOD = 36.0;

// gx/gy = derivadas de (u, h) na tela, calculadas fora dos "if".
vec4 sample_logo(sampler2D tex, float x, float h, float cx, float aspect, float lh, vec2 gx, vec2 gy) {
	float lw = lh * aspect;
	float hc = (BANNER_BOTTOM + wall_height - 0.12) * 0.5;
	vec2 uv = vec2((x - cx) / lw + 0.5, 0.5 - (h - hc) / lh);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	vec2 scale = vec2(1.0 / lw, -1.0 / lh);
	return textureGrad(tex, uv, gx * scale, gy * scale);
}

// Seta ">" no formato da seta do logo, apontando no sentido da corrida.
float chevrons(float x, float h, float aa) {
	float hc = (BANNER_BOTTOM + wall_height - 0.12) * 0.5;
	float y = (h - hc) / 0.32;
	float c = fract(x / 1.0) - abs(y) * 0.35;
	return smoothstep(0.38 - aa, 0.38 + aa, c) * (1.0 - smoothstep(0.7 - aa, 0.7 + aa, c)) * step(abs(y), 1.0);
}

void fragment() {
	float h = UV.x;
	float along = UV.y;
	float u = along * mirror;
	vec2 gx = vec2(dFdx(u), dFdx(h));
	vec2 gy = vec2(dFdy(u), dFdy(h));
	float aa = fwidth(u) * 1.5;
	float n = vnoise(vec2(along * 0.8, h * 6.0));
	vec3 col;
	float rough = 0.55;

	if (outer_side) {
		float block = mod(floor(along / 3.0), 2.0);
		col = mix(brand_blue, trim_color, block);
		if (h > wall_height - 0.13) {
			col = trim_color;
		}
		col *= 0.92 + n * 0.08;
	} else {
		float x = mod(u, PERIOD);
		float lh = 0.56;
		if (x < 13.0) {
			col = trim_color;
			float cx = 2.17 + floor(x / 4.333) * 4.333;
			vec4 l = sample_logo(wordmark_light, x, h, cx, wordmark_aspect, lh, gx, gy);
			col = mix(col, l.rgb, l.a);
		} else if (x < 17.0) {
			col = brand_blue;
			float arrows = chevrons(along, h, aa);
			col = mix(col, brand_light, arrows);
		} else if (x < 30.0) {
			col = navy;
			float cx = 17.0 + 2.17 + floor((x - 17.0) / 4.333) * 4.333;
			vec4 l = sample_logo(wordmark_dark, x, h, cx, wordmark_aspect, lh, gx, gy);
			col = mix(col, l.rgb, l.a);
		} else {
			col = yellow;
			float cx = x < 33.0 ? 31.5 : 34.5;
			vec4 l = sample_logo(logo_icon, x, h, cx, icon_aspect, lh + 0.1, gx, gy);
			col = mix(col, l.rgb, l.a);
		}
		// Fresta entre as placas.
		float seam = min(abs(x - 13.0), min(abs(x - 17.0), min(abs(x - 30.0), min(x, PERIOD - x))));
		col *= mix(0.25, 1.0, smoothstep(0.03, 0.03 + aa, seam));
		// Base escura e friso branco em cima.
		if (h < BANNER_BOTTOM) {
			col = base_color * (0.9 + n * 0.2);
			rough = 0.8;
		} else if (h > wall_height - 0.12) {
			col = trim_color * (0.94 + n * 0.06);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	EMISSION = col * glow * step(BANNER_BOTTOM, h);
}
