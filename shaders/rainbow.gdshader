shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Arco-íris na névoa da cachoeira. UV.x = 0..1 ao longo do arco, UV.y = 0 (por fora,
// vermelho) a 1 (por dentro, violeta).

uniform float strength = 0.33;

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	float band = UV.y;
	vec3 col = hue(band * 0.78);
	float across = smoothstep(0.0, 0.18, band) * smoothstep(1.0, 0.82, band);
	float ends = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	ALBEDO = col * across * ends * strength;
	ALPHA = 1.0;
}
