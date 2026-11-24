shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Facho de holofote varrendo o céu da cidade neon (track_city.gd). A malha é um cone ao
// longo de +Y centrado na origem (CylinderMesh, ponta embaixo); o shader sobe o cone
// para a ponta ficar na origem do nó e gira em volta dela. A névoa somaria a cor dela no aditivo: `fog_disabled`.

uniform vec3 color : source_color = vec3(0.6, 0.8, 1.0);
uniform float intensity = 0.22;
uniform float beam_length = 220.0;
uniform float speed = 0.25;
uniform float sweep = 0.45;
uniform float tilt = 0.35;
uniform float phase = 0.0;

varying float along;

mat3 rot_x(float a) {
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(a), sin(a)), vec3(0.0, -sin(a), cos(a)));
}

mat3 rot_y(float a) {
	return mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
}

void vertex() {
	VERTEX.y += beam_length * 0.5;
	along = clamp(VERTEX.y / beam_length, 0.0, 1.0);
	mat3 r = rot_y(TIME * speed * 0.7 + phase) * rot_x(tilt + sin(TIME * speed + phase * 1.7) * sweep);
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fade = (1.0 - along) * smoothstep(0.0, 0.04, along);
	ALBEDO = color * intensity * fade * pow(facing, 2.0);
}
