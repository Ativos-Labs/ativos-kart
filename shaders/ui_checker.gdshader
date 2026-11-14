shader_type canvas_item;
// Painel claro quadriculado com borda inclinada, usado no lado esquerdo dos menus.

uniform vec4 color_a : source_color = vec4(1.0, 1.0, 1.0, 0.94);
uniform vec4 color_b : source_color = vec4(0.87, 0.9, 0.95, 0.94);
uniform vec4 edge_color : source_color = vec4(1.0, 0.82, 0.1, 1.0);
// Onde o painel termina (fração da largura, no meio da altura).
uniform float edge = 0.42;
// Inclinação da borda: positivo = mais largo embaixo.
uniform float slant = 0.12;
// Quantas linhas de quadrados cabem na altura.
uniform float rows = 12.0;
uniform float scroll_speed = 0.35;
// Animação de entrada (0 = escondido, 1 = aberto).
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

vec4 over(vec4 src, vec4 dst) {
	float a = src.a + dst.a * (1.0 - src.a);
	vec3 rgb = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(a, 0.0001);
	return vec4(rgb, a);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float edge_x = (edge + slant * (UV.y - 0.5)) * reveal - (1.0 - reveal) * 0.2;
	float d = edge_x - UV.x;
	float aa = max(fwidth(d), 0.0005);
	float inside = smoothstep(-aa, aa, d);
	float band = smoothstep(-aa, aa, d + 0.008) * (1.0 - inside);
	float shadow = smoothstep(-0.05, 0.0, d + 0.008) * (1.0 - smoothstep(-aa, aa, d + 0.008)) * 0.3;

	vec2 p = vec2(UV.x * aspect, UV.y) * rows + vec2(TIME * scroll_speed, TIME * scroll_speed * 0.5);
	float chk = mod(floor(p.x) + floor(p.y), 2.0);
	// O quadriculado some aos poucos perto da borda.
	float fade = smoothstep(0.0, 0.25, d);
	vec4 col = mix(color_a, color_b, chk * (0.35 + 0.65 * fade));

	vec4 c = vec4(0.0, 0.0, 0.0, shadow);
	c = over(vec4(edge_color.rgb, edge_color.a * band), c);
	c = over(vec4(col.rgb, col.a * inside), c);
	COLOR = c;
}
