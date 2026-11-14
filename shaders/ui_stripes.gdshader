shader_type canvas_item;
// Fundo animado das telas de seleção: degradê, faixas diagonais, brilho e quadriculado.

uniform vec4 color_top : source_color = vec4(0.16, 0.5, 1.0, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.03, 0.12, 0.42, 1.0);
uniform vec4 stripe_color : source_color = vec4(1.0, 1.0, 1.0, 0.07);
uniform float stripes = 9.0;
uniform float speed = 0.05;
uniform vec4 glow_color : source_color = vec4(0.6, 0.9, 1.0, 0.5);
uniform vec2 glow_center = vec2(0.7, 0.45);

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = mix(color_top.rgb, color_bottom.rgb, smoothstep(0.0, 1.0, UV.y));
	float s = fract((UV.x * aspect + UV.y) * stripes * 0.5 - TIME * speed * stripes);
	float aa = fwidth(s) * 1.5;
	float band = smoothstep(0.5 - aa, 0.5 + aa, s) * (1.0 - smoothstep(1.0 - aa, 1.0, s));
	col = mix(col, stripe_color.rgb, band * stripe_color.a);
	// Faixa quadriculada embaixo.
	vec2 p = vec2(UV.x * aspect, UV.y) * 16.0 + vec2(TIME * 0.8, 0.0);
	float chk = mod(floor(p.x) + floor(p.y), 2.0);
	float strip = smoothstep(0.86, 0.9, UV.y);
	col = mix(col, mix(vec3(0.95), vec3(0.08, 0.1, 0.18), chk), strip * 0.55);
	// Brilho atrás do personagem.
	vec2 d = (UV - glow_center) * vec2(aspect, 1.0);
	col += glow_color.rgb * glow_color.a * exp(-dot(d, d) * 4.0);
	COLOR = vec4(col, 1.0);
}
