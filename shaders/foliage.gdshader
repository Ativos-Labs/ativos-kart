shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// Copas de árvores e arbustos: cor de cada instância (MultiMesh), mais escura
// embaixo, luz "atravessando" as folhas e balanço suave com o vento.
// A normal é puxada para a de uma esfera em volta da copa: assim a copa inteira
// tem um lado claro e um lado na sombra, em vez de cada bolota acesa igual.

#include "res://shaders/noise.gdshaderinc"

uniform float wind_strength = 0.08;
uniform float base_height = 1.5;
uniform float top_height = 7.0;
// Neve no alto das copas (0 = sem neve).
uniform float snow_cover = 0.0;
// Centro da copa (espaço do objeto) e quanto a normal vira "esfera" (0 = normal da malha).
uniform vec3 canopy_center = vec3(0.0, 4.2, 0.0);
uniform float canopy_normal_blend : hint_range(0.0, 1.0) = 0.55;

varying vec3 tint;
varying float height_f;
varying vec3 world_pos;

void vertex() {
	// A cor da instância vem em sRGB (Color.from_hsv); o shader trabalha em linear.
	tint = srgb_to_linear(COLOR.rgb);
	height_f = smoothstep(base_height, top_height, VERTEX.y);
	vec3 sphere_n = normalize(VERTEX - canopy_center + vec3(0.0, 0.001, 0.0));
	NORMAL = normalize(mix(NORMAL, sphere_n, canopy_normal_blend));
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.4 + wp.x * 0.13 + wp.z * 0.09) * wind_strength * max(VERTEX.y - base_height * 0.5, 0.0);
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	world_pos = wp;
}

void fragment() {
	float n = vnoise(world_pos.xz * 0.9 + world_pos.y * 0.7);
	// Embaixo e por dentro da copa fica mais escuro (oclusão falsa, sem custo de luz).
	vec3 albedo = tint * (0.55 + 0.6 * height_f) * (0.88 + 0.24 * n);
	ALBEDO = albedo;
	// Folhas deixam passar luz quando o sol está atrás (tom mais quente/amarelado).
	BACKLIGHT = albedo * vec3(0.5, 0.55, 0.3);
	if (snow_cover > 0.0) {
		vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float snow = smoothstep(0.2, 0.5, wn.y + (n - 0.5) * 0.35) * snow_cover;
		ALBEDO = mix(ALBEDO, vec3(0.86, 0.9, 0.97), snow);
		BACKLIGHT *= 1.0 - snow;
	}
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	RIM = 0.15;
	RIM_TINT = 0.7;
}
