shader_type spatial;
// Moeda Ativos (assets/models/moeda/moeda.glb). Gira no próprio eixo e balança no
// vertex shader, sem script por moeda: na pista todas são um MultiMesh só (veja
// scripts/track_coins.gd). Cada moeda começa o giro num ângulo diferente.
// Frente (+Z): o "at" em relevo. Verso (-Z): um disco liso (tools/moeda/build_moeda.py)
// onde este shader grava o "%" da Correção monetária.
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float spin_speed = 2.4;
uniform float bob_height = 0.07;
uniform float metallic_amount = 0.55;
uniform float roughness_amount = 0.3;
// Brilho próprio (a moeda aparece de longe e na sombra) e contorno mais claro.
uniform vec3 glow_color : source_color = vec3(1.0, 0.72, 0.18);
uniform float glow = 0.3;
uniform float rim_glow = 1.0;
// Giro extra (rad) e fase própria, para a moeda que voa ao ser pega.
uniform float extra_spin = 0.0;
// Verso: raio do disco liso (m, espaço da moeda) e a cor dele (sem a textura).
uniform float engrave_radius = 0.325;
uniform vec3 field_color : source_color = vec3(0.93, 0.7, 0.14);

varying vec3 v_local;
varying vec3 v_local_normal;

void vertex() {
	v_local = VERTEX;
	v_local_normal = NORMAL;
	float phase = float(INSTANCE_ID) * 2.39996;
	float a = TIME * spin_speed + phase + extra_spin;
	float c = cos(a);
	float s = sin(a);
	mat3 r = mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
	VERTEX.y += sin(TIME * 2.1 + phase) * bob_height;
}

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Distância até o "%" (negativa dentro), em metros, olhando o verso de frente.
float percent(vec2 p) {
	float ring_a = abs(length(p - vec2(-0.115, 0.13)) - 0.066) - 0.026;
	float ring_b = abs(length(p - vec2(0.115, -0.13)) - 0.066) - 0.026;
	float slash = segment(p, vec2(-0.15, -0.235), vec2(0.15, 0.235)) - 0.03;
	return min(min(ring_a, ring_b), slash);
}

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb;
	if (v_local_normal.z < -0.9 && length(v_local.xy) < engrave_radius) {
		// Visto de trás, a direita da tela é -X.
		vec2 p = vec2(-v_local.x, v_local.y);
		float aa = max(fwidth(p.x), 0.002);
		float inside = 1.0 - smoothstep(-aa, aa, percent(p));
		// Sulco: a parede de cima fica na sombra e a de baixo pega luz.
		float top_wall = inside * smoothstep(-aa, aa, percent(p + vec2(0.0, 0.02)));
		float low_wall = inside * smoothstep(-aa, aa, percent(p - vec2(0.0, 0.02)));
		albedo = field_color;
		albedo = mix(albedo, field_color * 0.5, inside);
		albedo = mix(albedo, field_color * 0.22, top_wall);
		albedo = mix(albedo, min(field_color * 1.35, vec3(1.0)), low_wall);
	}
	ALBEDO = albedo;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_color * (glow + rim * rim_glow);
}
