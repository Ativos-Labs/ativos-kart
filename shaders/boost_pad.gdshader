shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Placa de turbo: setas no formato da seta do logo da Ativos, correndo no sentido
// da corrida, com brilho forte (o glow da câmera faz ela "acender").
// UV.y cresce no sentido da corrida.

uniform vec3 color_a : source_color = vec3(1.0, 0.42, 0.0);
uniform vec3 color_b : source_color = vec3(1.0, 0.9, 0.2);
uniform vec3 border_color : source_color = vec3(0.1, 0.1, 0.14);
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.6);
uniform float speed = 1.8;
uniform float glow = 2.2;

void fragment() {
	vec2 uv = UV;
	float aa = fwidth(uv.y) * 4.0;
	float chev = fract((uv.y - abs(uv.x - 0.5) * 0.9) * 3.0 - TIME * speed);
	float band = smoothstep(0.15, 0.15 + aa, chev) * (1.0 - smoothstep(0.55, 0.55 + aa, chev));
	vec3 col = mix(color_a, color_b, band);
	float pulse = 0.85 + 0.15 * sin(TIME * 8.0);
	float inside = step(0.07, uv.x) * step(uv.x, 0.93) * step(0.05, uv.y) * step(uv.y, 0.95);
	float rim = (step(0.04, uv.x) * step(uv.x, 0.96) * step(0.03, uv.y) * step(uv.y, 0.97)) - inside;
	vec3 albedo = mix(border_color, col, inside);
	albedo = mix(albedo, rim_color, rim);
	ALBEDO = albedo * 0.4;
	EMISSION = (col * inside * (0.6 + band * 0.6) + rim_color * rim) * glow * pulse;
	ROUGHNESS = 0.3;
}
