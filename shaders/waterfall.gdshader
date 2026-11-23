shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx, shadows_disabled;
// Cachoeira do vale: lâmina de água caindo (listras e espuma descendo) com as bordas
// esfiapadas. `frozen` = cascata congelada (colunas de gelo paradas, brilhantes).
// UV.x = 0..1 de um lado ao outro; UV.y = metros de queda (0 = no alto).

#include "res://shaders/noise.gdshaderinc"

uniform vec3 water_color : source_color = vec3(0.62, 0.86, 0.92);
uniform vec3 ice_color : source_color = vec3(0.62, 0.82, 0.96);
uniform bool frozen = false;
uniform float fall_speed = 5.0;
uniform float height = 20.0;

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float edge_noise = vnoise(vec2(y * 0.35, 2.0)) * 0.08;
	float edge = smoothstep(0.0 + edge_noise, 0.14 + edge_noise, x) * smoothstep(1.0 - edge_noise, 0.86 - edge_noise, x);
	if (frozen) {
		float cols = vnoise(vec2(x * 14.0, y * 0.08));
		float fine = vnoise(vec2(x * 45.0, y * 0.3));
		vec3 col = mix(ice_color * 0.7, vec3(0.95, 0.98, 1.0), smoothstep(0.3, 0.8, cols * 0.7 + fine * 0.3));
		ALBEDO = col;
		ALPHA = edge * 0.96;
		ROUGHNESS = 0.12;
		SPECULAR = 0.8;
		RIM = 0.4;
	} else {
		float t = TIME * fall_speed;
		float s1 = vnoise(vec2(x * 22.0, y * 0.22 - t * 0.5));
		float s2 = vnoise(vec2(x * 55.0 + 3.0, y * 0.6 - t * 1.1));
		float foam = smoothstep(0.42, 0.82, s1 * 0.6 + s2 * 0.4);
		// Mais branca no alto (onde a água vira) e embaixo (espuma).
		float top = 1.0 - smoothstep(0.0, 2.5, y);
		float bottom = smoothstep(height - 4.0, height, y);
		foam = max(foam, max(top, bottom) * 0.9);
		ALBEDO = mix(water_color * 0.8, vec3(1.0), foam);
		ALPHA = edge * clamp(0.5 + 0.45 * foam, 0.0, 1.0);
		ROUGHNESS = 0.2;
		SPECULAR = 0.6;
		EMISSION = vec3(0.12) * foam;
	}
}
