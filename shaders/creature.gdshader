shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Bichos do cenário em MultiMesh, cada um dando voltas sozinho (sem script):
// mode 0 = peixe (cardume nadando em círculo, rabo balançando), 1 = pássaro (voando
// em círculo, batendo as asas), 2 = golfinho (pulando para fora da água em arcos),
// 3 = pinguim (patinando em círculo no gelo, gingando).
// A malha olha para +Z. INSTANCE_CUSTOM: x = raio da volta (m), y = velocidade
// (rad/s, o sinal é o sentido), z = fase, w = altura dos pulos / do sobe-e-desce.
// Cor: a da malha (vértice) vezes a da instância.

#include "res://shaders/noise.gdshaderinc"

uniform int mode = 0;

varying vec3 tint;

void vertex() {
	tint = color_to_albedo(COLOR.rgb);
	float r = INSTANCE_CUSTOM.x;
	float w = INSTANCE_CUSTOM.y;
	float ang = INSTANCE_CUSTOM.z + TIME * w;
	float dir = w < 0.0 ? -1.0 : 1.0;
	vec3 offset = vec3(cos(ang), 0.0, sin(ang)) * r;
	vec3 tang = vec3(-sin(ang), 0.0, cos(ang)) * dir;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float pitch = 0.0;
	float roll = 0.0;
	float t = TIME * 1.0 + INSTANCE_CUSTOM.z * 7.0;
	if (mode == 0) {
		// Rabo (z < 0) balança de lado.
		v.x += sin(t * 9.0) * 0.18 * max(-v.z, 0.0);
		offset.y += sin(t * 0.7) * INSTANCE_CUSTOM.w;
	} else if (mode == 1) {
		// Asas (|x| grande) sobem e descem; inclina para dentro da curva.
		v.y += sin(t * 8.0) * abs(v.x) * 0.55;
		roll = -0.35 * dir;
		offset.y += sin(t * 0.4) * INSTANCE_CUSTOM.w;
	} else if (mode == 2) {
		// Arcos: metade do tempo fora d'água, de bico para cima subindo e para baixo
		// descendo.
		float k = 3.0;
		float s = ang * k;
		offset.y += sin(s) * INSTANCE_CUSTOM.w - INSTANCE_CUSTOM.w * 0.35;
		pitch = -atan(INSTANCE_CUSTOM.w * k * cos(s) / max(r, 0.1));
		v.y += sin(t * 6.0) * 0.06 * max(-v.z, 0.0);
	} else {
		// Pinguim: ginga de um lado para o outro.
		roll = sin(t * 7.0) * 0.14;
		offset.y += abs(sin(t * 7.0)) * INSTANCE_CUSTOM.w;
	}
	// Roll (em z), pitch (em x) e depois o rumo (em y).
	mat3 rz = mat3(vec3(cos(roll), sin(roll), 0.0), vec3(-sin(roll), cos(roll), 0.0), vec3(0.0, 0.0, 1.0));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(pitch), sin(pitch)), vec3(0.0, -sin(pitch), cos(pitch)));
	float yaw = atan(tang.x, tang.z);
	mat3 ry = mat3(vec3(cos(yaw), 0.0, -sin(yaw)), vec3(0.0, 1.0, 0.0), vec3(sin(yaw), 0.0, cos(yaw)));
	mat3 rot = ry * rx * rz;
	VERTEX = rot * v + offset;
	NORMAL = rot * n;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = mode == 2 ? 0.3 : 0.55;
	SPECULAR = mode == 2 ? 0.6 : 0.35;
}
