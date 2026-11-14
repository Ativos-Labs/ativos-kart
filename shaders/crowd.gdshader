shader_type spatial;
render_mode diffuse_burley;
// Torcida da arquibancada: cada pessoa pula num ritmo diferente.
// A cabeça (parte de cima da malha) usa tons de pele; o corpo, a cor da instância.

#include "res://shaders/noise.gdshaderinc"

uniform float head_start = 0.55;

varying float local_y;
varying float person;
varying vec3 shirt;

void vertex() {
	float id = float(INSTANCE_ID);
	float f = fract(sin(id * 12.9898) * 43758.5453);
	float jump = abs(sin(TIME * (5.0 + f * 3.0) + id * 1.7)) * step(0.35, f) * 0.16;
	VERTEX.y += jump;
	local_y = VERTEX.y - jump;
	person = f;
	// Cor da instância vem em sRGB; converte uma vez por vértice.
	shirt = srgb_to_linear(COLOR.rgb);
}

void fragment() {
	vec3 skin = mix(vec3(0.95, 0.58, 0.36), vec3(0.17, 0.065, 0.027), fract(person * 7.13));
	ALBEDO = local_y > head_start ? skin : shirt;
	ROUGHNESS = 0.85;
}
