shader_type spatial;
// Piso da tela de seleção: grade que some com a distância e anel brilhante.

uniform vec3 base_color : source_color = vec3(0.06, 0.07, 0.18);
uniform vec3 line_color : source_color = vec3(0.38, 0.33, 0.85);
uniform vec3 glow_color : source_color = vec3(1.0, 0.79, 0.24);
uniform float ring_radius = 2.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(world_pos.xz);
	vec2 g = abs(fract(world_pos.xz / 1.5) - 0.5);
	float grid = 1.0 - smoothstep(0.0, 0.035, min(g.x, g.y));
	float fade = 1.0 - smoothstep(3.0, 16.0, r);
	float ring = smoothstep(0.22, 0.0, abs(r - ring_radius));
	ALBEDO = base_color * (0.55 + 0.45 * fade);
	EMISSION = line_color * grid * fade * 0.45 + glow_color * ring * 0.6;
	ROUGHNESS = 0.3;
}
