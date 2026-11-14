shader_type spatial;
// Kart fantasma do contra-relógio: translúcido, de uma cor só, com a borda brilhando.
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled;

uniform vec4 ghost_color : source_color = vec4(0.45, 0.8, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float base_alpha = 0.38;
uniform float rim_alpha = 0.5;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(ghost_color.rgb, rim_color.rgb, rim);
	ALPHA = base_alpha + rim_alpha * rim;
}
