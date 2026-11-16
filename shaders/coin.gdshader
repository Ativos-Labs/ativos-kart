shader_type spatial;
// Moeda Ativos (assets/models/moeda/moeda.glb). Gira no próprio eixo e balança no
// vertex shader, sem script por moeda: na pista todas são um MultiMesh só (veja
// scripts/track_coins.gd). Cada moeda começa o giro num ângulo diferente.
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float spin_speed = 2.4;
uniform float bob_height = 0.07;
uniform float metallic_amount = 0.55;
uniform float roughness_amount = 0.3;
// Brilho próprio (a moeda aparece de longe e na sombra) e contorno mais claro.
uniform vec3 glow_color : source_color = vec3(1.0, 0.72, 0.18);
uniform float glow = 0.18;
uniform float rim_glow = 0.55;
// Giro extra (rad) e fase própria, para a moeda que voa ao ser pega.
uniform float extra_spin = 0.0;

void vertex() {
	float phase = float(INSTANCE_ID) * 2.39996;
	float a = TIME * spin_speed + phase + extra_spin;
	float c = cos(a);
	float s = sin(a);
	mat3 r = mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
	VERTEX.y += sin(TIME * 2.1 + phase) * bob_height;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_color * (glow + rim * rim_glow);
}
