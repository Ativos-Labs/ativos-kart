shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Placa de curva: setas no formato da seta do logo correndo para o lado da curva.

uniform vec3 bg_color : source_color = vec3(0.149, 0.239, 0.749);
uniform vec3 arrow_color : source_color = vec3(1.0, 0.85, 0.12);
uniform vec3 border_color : source_color = vec3(1.0);
// 1 = curva para a direita, -1 = para a esquerda (de quem olha a placa).
uniform float direction = 1.0;
uniform float panel_aspect = 3.2;
uniform float speed = 0.8;

void fragment() {
	vec2 uv = UV;
	if (!FRONT_FACING) {
		uv.x = 1.0 - uv.x;
	}
	float x = uv.x * panel_aspect * direction;
	float y = (uv.y - 0.5) * 2.0;
	float aa = fwidth(x) * 1.5;
	float c = fract(x * 0.8 + abs(y) * 0.32 - TIME * speed);
	float arrow = smoothstep(0.2 - aa, 0.2 + aa, c) * (1.0 - smoothstep(0.62 - aa, 0.62 + aa, c)) * step(abs(y), 0.78);
	vec3 col = mix(bg_color, arrow_color, arrow);
	vec2 d = min(uv, 1.0 - uv) * vec2(panel_aspect, 1.0);
	float border = 1.0 - step(0.07, min(d.x, d.y));
	col = mix(col, border_color, border);
	ALBEDO = col;
	EMISSION = col * (0.35 + arrow * 0.5);
	ROUGHNESS = 0.4;
}
