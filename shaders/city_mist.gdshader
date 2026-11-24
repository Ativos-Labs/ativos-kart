shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Bancos de neblina baixa da cidade neon (track_city.gd): planos na altura da rua com
// manchas de ruído que andam devagar, tingidas pelo neon da cidade. Somem suavemente onde
// encostam nos prédios e no chão (pela profundidade da cena) e perto da câmera (sem a
// "parede" de neblina quando o kart passa por dentro).

#include "res://shaders/noise.gdshaderinc"

uniform vec3 mist_color : source_color = vec3(0.4, 0.2, 0.6);
uniform vec3 glow_color : source_color = vec3(1.0, 0.3, 0.8);
uniform float density = 0.5;
// Tamanho das manchas (1/m) e o vento.
uniform float scale = 0.02;
uniform vec2 drift = vec2(0.012, 0.007);
// Distância (m) em que a neblina some ao encostar em algo e perto da câmera.
uniform float soft = 3.0;
uniform float near_fade = 16.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz * scale;
	float n = fbm(p + TIME * drift, 3);
	float n2 = vnoise(p * 2.7 - TIME * drift * 1.7);
	float m = smoothstep(0.36, 0.74, n * 0.78 + n2 * 0.32);
	float raw = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// No Compatibility (web) a profundidade vai de 0 a 1 e o NDC de -1 a 1.
	raw = raw * 2.0 - 1.0;
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	view.xyz /= view.w;
	float behind = max(VERTEX.z - view.z, 0.0);
	float edge = smoothstep(0.0, soft, behind);
	float cam = smoothstep(near_fade * 0.3, near_fade, -VERTEX.z);
	ALBEDO = mix(mist_color, glow_color, smoothstep(0.4, 0.9, n2) * 0.4);
	// COLOR.a: 0 nos cantos da beirada (a neblina some aos poucos, sem borda reta).
	ALPHA = clamp(m * density * edge * cam * COLOR.a, 0.0, 1.0);
}
