shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Gelo maciço (cristais e arcos de gelo da pista de neve): opaco, mas parece
// translúcido — azul fundo no meio, claro nas beiradas vistas de lado e com um brilho
// de dentro. VERTEX.y (local) vai de 0 no pé a `top` no alto (clareia para cima).

uniform vec3 deep : source_color = vec3(0.03, 0.24, 0.52);
uniform vec3 light : source_color = vec3(0.6, 0.9, 1.0);
uniform float top = 1.6;
uniform float glow = 0.16;

varying float rise;

void vertex() {
	rise = clamp(VERTEX.y / top, 0.0, 1.0);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	vec3 col = mix(deep, light, clamp(rise * 0.3 + rim * 0.8, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.06;
	SPECULAR = 0.8;
	// Luz "atravessando" o gelo: mais forte nas beiradas.
	EMISSION = light * (rim * 0.6 + 0.15) * glow;
}
