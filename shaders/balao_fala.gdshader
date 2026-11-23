shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;
// Balão de fala de quadrinho (PickExtras: a fala do gesto de escolha, "SEXTOUU!"): elipse
// branca com contorno e o rabicho apontando para baixo, para o lado de `tail_side`. O quad
// tem o tamanho do texto mais a margem; o rabicho ocupa a faixa de baixo (`tail_room`).

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 line_color : source_color = vec4(0.07, 0.12, 0.25, 1.0);
// Espessura do contorno (fração da altura da elipse).
uniform float line_width = 0.07;
// Fração da altura do quad embaixo da elipse, onde fica a ponta do rabicho.
uniform float tail_room = 0.28;
// -1 = rabicho à esquerda, 1 = à direita.
uniform float tail_side = -1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// Tamanho do quad (m): a elipse ocupa a largura toda e a altura menos `tail_room`.
uniform vec2 quad_size = vec2(1.0, 0.5);

// Distância (aproximada, em unidades da altura da elipse) até a borda: < 0 dentro.
float shape(vec2 p, float aspect) {
	// Elipse: centro (0, 0), semieixos (aspect/2, 0.5) na altura dela.
	vec2 q = p / vec2(aspect * 0.5, 0.5);
	float ellipse = (length(q) - 1.0) * 0.5;
	// Rabicho: triângulo da borda de baixo até a ponta.
	vec2 a = vec2(tail_side * aspect * 0.12, -0.3);
	vec2 b = vec2(tail_side * aspect * 0.26, -0.25);
	vec2 tip = vec2(tail_side * aspect * 0.36, -0.5 - tail_room / (1.0 - tail_room));
	vec2 e0 = b - a, e1 = tip - b, e2 = a - tip;
	vec2 v0 = p - a, v1 = p - b, v2 = p - tip;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
			vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
			vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	float tri = -sqrt(d.x) * sign(d.y);
	return min(ellipse, tri);
}

void fragment() {
	// Coordenadas na altura da elipse: x para a direita, y para cima, (0, 0) no centro dela.
	float ellipse_h = 1.0 - tail_room;
	float aspect = quad_size.x / (quad_size.y * ellipse_h);
	vec2 p = vec2((UV.x - 0.5) * aspect, (1.0 - UV.y - tail_room - ellipse_h * 0.5) / ellipse_h);
	float d = shape(p, aspect);
	float aa = fwidth(d) * 1.2;
	float outside = smoothstep(-aa, aa, d);
	float line = smoothstep(-aa, aa, d + line_width);
	ALBEDO = mix(fill_color.rgb, line_color.rgb, line);
	ALPHA = (1.0 - outside) * opacity;
}
