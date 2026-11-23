shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
// Alga comprida (fita) balançando debaixo d'água: o pé fica preso e a ponta dança.
// UV.y = 0 no pé, 1 na ponta. Cor da instância (MultiMesh) multiplica a cor.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.1, 0.32, 0.12);
uniform vec3 tip_color : source_color = vec3(0.5, 0.72, 0.2);
uniform float sway = 0.55;

varying vec3 tint;

void vertex() {
	tint = color_to_albedo(COLOR.rgb);
	float phase = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.23;
	float k = UV.y * UV.y;
	VERTEX.x += sin(TIME * 1.1 + phase + UV.y * 3.0) * sway * k;
	VERTEX.z += cos(TIME * 0.8 + phase * 1.3 + UV.y * 2.0) * sway * 0.6 * k;
}

void fragment() {
	// Folha com borda ondulada (corta o que passa da largura).
	float w = 0.5 * (0.55 + 0.45 * sin(UV.y * 3.14159)) * (0.8 + 0.2 * sin(UV.y * 40.0));
	if (abs(UV.x - 0.5) > w) {
		discard;
	}
	vec3 col = mix(base_color, tip_color, UV.y) * tint;
	ALBEDO = col;
	BACKLIGHT = col * 0.6;
	ROUGHNESS = 0.6;
}
