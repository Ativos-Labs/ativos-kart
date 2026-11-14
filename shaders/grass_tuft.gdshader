shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled, depth_prepass_alpha;
// Tufos de grama e flores (planos cruzados desenhados por código), com vento.
// Eles encolhem com a distância para economizar e não "piscar" de longe.
// UV.y = 0 em cima, 1 na base. COLOR = cor da instância.

#include "res://shaders/noise.gdshaderinc"

uniform bool flower = false;
uniform vec3 base_color : source_color = vec3(0.12, 0.36, 0.08);
uniform vec3 tip_color : source_color = vec3(0.5, 0.8, 0.22);
uniform float fade_start = 45.0;
uniform float fade_end = 75.0;
uniform float wind_strength = 0.12;

varying vec3 world_pos;
varying vec3 tint;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float top = 1.0 - UV.y;
	float sway = sin(TIME * 2.2 + wp.x * 0.35 + wp.z * 0.27) * wind_strength * top;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.5;
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	float keep = 1.0 - smoothstep(fade_start, fade_end, dist);
	VERTEX.y *= keep;
	world_pos = wp;
	NORMAL = vec3(0.0, 1.0, 0.0);
	// Flores: COLOR é uma cor sRGB da paleta. Grama: COLOR é só um multiplicador.
	tint = flower ? srgb_to_linear(COLOR.rgb) : COLOR.rgb;
}

void fragment() {
	vec2 uv = UV;
	float top = 1.0 - uv.y;
	float alpha;
	vec3 col;
	if (flower) {
		// Caule fino e uma flor de 5 pétalas em cima.
		vec2 c = vec2(0.5, 0.3);
		vec2 d = (uv - c) * vec2(1.0, 1.15);
		float r = length(d);
		float ang = atan(d.y, d.x);
		float petals = 0.2 + 0.07 * cos(ang * 5.0);
		float head = 1.0 - smoothstep(petals - 0.02, petals + 0.02, r);
		float stem = (1.0 - smoothstep(0.02, 0.04, abs(uv.x - 0.5 - (uv.y - 0.3) * 0.08))) * step(0.3, uv.y);
		float center = 1.0 - smoothstep(0.06, 0.08, r);
		alpha = max(head, stem);
		col = mix(base_color * 1.4, tint, head);
		col = mix(col, vec3(1.0, 0.85, 0.2), center);
	} else {
		// Folhas em ponta, com alturas diferentes.
		float blades = 7.0;
		float id = floor(uv.x * blades);
		float fx = fract(uv.x * blades) - 0.5;
		float height = 0.45 + 0.55 * hash12(vec2(id, 3.7));
		float lean = (hash12(vec2(id, 9.1)) - 0.5) * 0.6;
		float w = 0.45 * (1.0 - top / height);
		alpha = step(top, height) * step(abs(fx - lean * top), w);
		col = mix(base_color, tip_color, top / height) * tint;
	}
	ALBEDO = col;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	BACKLIGHT = col * 0.4;
	ROUGHNESS = 0.9;
}
