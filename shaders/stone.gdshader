shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Pedra em blocos (viadutos e chalés): fiadas desencontradas, juntas escuras e
// cor variando de bloco para bloco. Funciona em qualquer malha (usa a posição no mundo).

#include "res://shaders/noise.gdshaderinc"

uniform vec3 stone_a : source_color = vec3(0.74, 0.7, 0.64);
uniform vec3 stone_b : source_color = vec3(0.56, 0.53, 0.49);
uniform vec3 mortar : source_color = vec3(0.36, 0.34, 0.32);
uniform float block_w = 1.4;
uniform float block_h = 0.7;
// Neve por cima das superfícies viradas para cima (0 = sem neve).
uniform float snow_cover = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnorm);
	vec2 q;
	if (abs(n.y) > 0.7) {
		q = wpos.xz;
	} else {
		vec2 t = normalize(vec2(-n.z, n.x) + vec2(0.0001));
		q = vec2(dot(wpos.xz, t), wpos.y);
	}
	q /= vec2(block_w, block_h);
	float row = floor(q.y);
	q.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float h = hash12(cell + vec2(row * 17.0, 3.0));
	vec3 col = mix(stone_a, stone_b, h) * (0.88 + 0.24 * vnoise(wpos.xz * 1.7 + wpos.y * 1.3));
	vec2 fw = fwidth(q) * 1.2;
	vec2 edge = smoothstep(vec2(0.0), vec2(0.05) + fw, f) * smoothstep(vec2(0.0), vec2(0.05) + fw, 1.0 - f);
	float joint = 1.0 - edge.x * edge.y;
	col = mix(col, mortar, joint * 0.85);
	if (snow_cover > 0.0) {
		float snow = smoothstep(0.55, 0.8, n.y + (vnoise(wpos.xz * 0.8) - 0.5) * 0.3) * snow_cover;
		col = mix(col, vec3(0.93, 0.95, 1.0), snow);
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
