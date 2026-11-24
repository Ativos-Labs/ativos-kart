shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Zebras em relevo: blocos vermelhos e brancos com frestas, um pouco brilhantes.
// UV.x = 0..1 de dentro para fora; UV.y = metros ao longo da pista.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.93, 0.1, 0.12);
uniform vec3 color_b : source_color = vec3(0.98, 0.98, 0.98);
uniform float block_length = 2.0;
// Brilho próprio (zebras de neon na cidade à noite). 0 = zebra comum.
uniform float glow = 0.0;

void fragment() {
	float b = mod(floor(UV.y / block_length), 2.0);
	vec3 col = mix(color_a, color_b, b);
	float f = fract(UV.y / block_length);
	float fw = fwidth(UV.y / block_length) * 1.5;
	float groove = smoothstep(0.0, 0.025 + fw, f) * smoothstep(1.0, 0.975 - fw, f);
	col *= 0.62 + 0.38 * groove;
	float dirt = vnoise(vec2(UV.x * 6.0, UV.y * 1.5));
	col *= 0.9 + dirt * 0.1;
	ALBEDO = col;
	ROUGHNESS = 0.38 + dirt * 0.15;
	SPECULAR = 0.55;
	EMISSION = col * glow;
}
