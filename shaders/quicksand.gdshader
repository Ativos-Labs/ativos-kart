shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, blend_mix, depth_draw_opaque, cull_back;
// Redemoinho de areia movediça: espiral de areia girando para o meio (mais escuro e
// fundo no centro), que some na borda para casar com a areia da pista.
// Malha: disco com UV = posição (-1..1).

#include "res://shaders/noise.gdshaderinc"

uniform vec3 sand_light : source_color = vec3(0.93, 0.76, 0.5);
uniform vec3 sand_dark : source_color = vec3(0.55, 0.36, 0.2);
uniform float spin = 0.9;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) {
		discard;
	}
	float a = atan(q.y, q.x);
	float spiral = sin(a * 3.0 + log(r + 0.05) * 7.0 + TIME * spin * 3.0);
	float grain = vnoise(q * 9.0 + vec2(TIME * 0.2, 0.0));
	vec3 col = mix(sand_dark, sand_light, smoothstep(-0.6, 0.9, spiral) * 0.55 + 0.25 + grain * 0.15);
	col *= mix(0.45, 1.0, smoothstep(0.0, 0.75, r));
	// Normal inclinada para o centro: parece um funil.
	vec3 n_world = normalize(vec3(-q.x * 0.6 * (1.0 - r), 1.0, -q.y * 0.6 * (1.0 - r)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.82, 1.0, r);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
