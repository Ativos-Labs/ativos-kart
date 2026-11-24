shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Rocha da praia (arco de pedra, ilhotas e pedras do baixio): calcário claro com
// manchas e camadas, musgo e grama em cima das partes viradas para cima e uma faixa
// molhada e escura rente à água. Usa a posição no mundo (serve em qualquer malha).

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/noise_tex.gdshaderinc"

uniform vec3 rock_light : source_color = vec3(0.64, 0.58, 0.5);
uniform vec3 rock_dark : source_color = vec3(0.4, 0.36, 0.32);
uniform vec3 moss : source_color = vec3(0.27, 0.48, 0.15);
uniform float moss_amount = 1.0;
uniform float water_level = -1.4;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Ruído projetado nos três planos, misturado pela direção da face (sem esticar).
float tri_noise(vec3 p, vec3 w, float f) {
	return tnoise(p.zy * f) * w.x + tnoise(p.xz * f + 5.3) * w.y + tnoise(p.xy * f + 9.1) * w.z;
}

void fragment() {
	vec3 n = normalize(wnorm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float lod = clamp(length(fwidth(wpos)) * 1.5, 0.0, 1.0);
	float a = tri_noise(wpos, w, 0.28);
	float b = mix(tri_noise(wpos + 3.0, w, 1.2), 0.5, lod);
	float c = mix(tri_noise(wpos + 7.0, w, 3.4), 0.5, lod);
	vec3 col = mix(rock_dark, rock_light, smoothstep(0.15, 0.85, a * 0.6 + b * 0.3 + c * 0.1));
	// Camadas do calcário (deitadas).
	col *= 0.9 + 0.1 * sin(wpos.y * 1.8 + a * 5.0);
	// Furinhos e rachaduras escuras.
	col = mix(col, rock_dark * 0.55, smoothstep(0.74, 0.9, b) * 0.55);
	// Musgo/grama em cima.
	float m = smoothstep(0.5, 0.82, n.y + (b - 0.5) * 0.5) * moss_amount;
	col = mix(col, moss * (0.75 + 0.5 * a), m);
	// Faixa molhada rente à água.
	float wet = 1.0 - smoothstep(water_level + 0.05, water_level + 1.0, wpos.y + (a - 0.5) * 0.5);
	col *= mix(1.0, 0.6, wet);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.45, wet);
	SPECULAR = mix(0.25, 0.6, wet);
}
