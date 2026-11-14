shader_type sky;
render_mode use_debanding;
// Céu de desenho: degradê azul forte, sol com brilho e nuvens fofas.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 zenith_color : source_color = vec3(0.07, 0.36, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.86, 1.0);
uniform vec3 ground_color : source_color = vec3(0.52, 0.72, 0.88);
// "GI falso": a metade de baixo do mapa de radiância (que gera a luz ambiente e os
// reflexos) recebe a cor da luz rebatida pela grama. Só entra no cubemap, que é
// calculado uma vez (o céu não usa TIME), então não custa nada por frame.
uniform vec3 bounce_color : source_color = vec3(0.5, 0.68, 0.36);
uniform float bounce_energy : hint_range(0.0, 2.0) = 0.9;
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform float sun_size : hint_range(0.0, 0.2) = 0.028;
uniform float sun_glow : hint_range(0.0, 2.0) = 0.7;
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.6, 0.72, 0.92);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.4;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.035;
uniform float cloud_scale = 1.6;
uniform float energy = 1.0;

float cloud_density(vec2 p) {
	vec2 q = vec2(fbm(p * 0.45 + vec2(3.1, 1.7), 3), fbm(p * 0.45 + vec2(8.3, 2.8), 3));
	return fbm(p + q * 0.9, 5);
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color, zenith_color, pow(clamp(h, 0.0, 1.0), 0.45));
	vec3 ground = AT_CUBEMAP_PASS ? bounce_color * bounce_energy : ground_color;
	col = mix(col, ground, smoothstep(0.0, -0.25, h));
	col += vec3(1.0) * 0.08 * exp(-abs(h) * 18.0);

	float sd = LIGHT0_ENABLED ? dot(dir, LIGHT0_DIRECTION) : -1.0;
	if (LIGHT0_ENABLED) {
		float s = max(sd, 0.0);
		col += sun_color * (pow(s, 10.0) * 0.22 + pow(s, 180.0) * 0.9) * sun_glow;
		if (!AT_CUBEMAP_PASS) {
			float disk = smoothstep(cos(sun_size), cos(sun_size * 0.75), sd);
			col = mix(col, sun_color * 5.0, disk);
		}
	}

	// Abaixo de h = 0,05 as nuvens somem (fade abaixo), então nem calcula o ruído ali;
	// e o fade entra antes do teste para pular a 2ª amostra onde a nuvem é invisível.
	if (h > 0.05 && !AT_CUBEMAP_PASS) {
		vec2 p = dir.xz / (h + 0.22) * cloud_scale;
		float d = cloud_density(p);
		float edge = 1.0 - cloud_coverage;
		float a = smoothstep(edge, edge + cloud_softness, d) * smoothstep(0.05, 0.3, h);
		if (a > 0.001) {
			// Lado virado para o sol fica claro, o resto azulado.
			vec2 to_sun = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) * 0.12;
			float d2 = cloud_density(p + to_sun);
			float lit = clamp(0.62 + (d - d2) * 6.0, 0.0, 1.0);
			float core = smoothstep(edge + cloud_softness, edge + 0.32, d);
			vec3 ccol = mix(cloud_light, cloud_shadow, (1.0 - lit) * 0.8 + core * 0.18);
			ccol += sun_color * pow(max(sd, 0.0), 6.0) * 0.25 * (1.0 - core);
			col = mix(col, ccol, a);
		}
	}
	COLOR = col * energy;
}
