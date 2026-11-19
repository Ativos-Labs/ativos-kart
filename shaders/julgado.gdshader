shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
// Trânsito em julgado — um shader só para compilar, com materiais diferentes por `part`:
// 0 = a aura dourada em volta do kart (esfera achatada: borda forte, faixas de luz
//     subindo e um véu dourado por cima do kart);
// 1 = os brilhos de quatro pontas (quadrados virados para a câmera);
// 2 = o brilho no chão embaixo do kart (quadrado deitado, mancha redonda pulsando);
// 3 = o banho dourado por cima do kart e do piloto (material_overlay das malhas deles):
//     borda dourada e um reflexo que passa varrendo.

uniform int part = 0;
uniform vec3 color : source_color = vec3(1.0, 0.76, 0.12);
uniform vec3 core : source_color = vec3(1.0, 0.96, 0.62);
// 0..1: some no fim (pisca nos últimos segundos, veja TransitoJulgado).
uniform float fade = 1.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
	if (part == 1) {
		// Brilho: sempre de frente para a câmera (mantendo a escala do nó).
		mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * bb;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	if (part == 1) {
		vec2 c = UV * 2.0 - 1.0;
		// Estrela de quatro pontas: duas faixas finas cruzadas e um miolo redondo.
		float star = max(1.0 - smoothstep(0.0, 0.16, abs(c.x)), 1.0 - smoothstep(0.0, 0.16, abs(c.y)));
		star *= 1.0 - smoothstep(0.35, 1.0, length(c));
		float glow = 1.0 - smoothstep(0.0, 0.45, length(c));
		ALBEDO = mix(color, core, glow);
		ALPHA = clamp(star + glow, 0.0, 1.0) * fade;
	} else if (part == 2) {
		float r = length(UV * 2.0 - 1.0);
		float disc = 1.0 - smoothstep(0.3, 1.0, r);
		float ring = 1.0 - smoothstep(0.0, 0.07, abs(r - (0.45 + 0.4 * fract(TIME * 1.4))));
		ALBEDO = mix(color, core, disc * 0.7 + ring * 0.3);
		ALPHA = clamp(disc * 0.85 + ring * 0.6 * (1.0 - r), 0.0, 1.0) * (0.85 + 0.15 * sin(TIME * 9.0)) * fade;
	} else if (part == 3) {
		float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = pow(1.0 - ndv, 2.0);
		float sweep = smoothstep(0.7, 1.0, 0.5 + 0.5 * sin((v_local.x + v_local.y * 1.6 + v_local.z) * 3.0 - TIME * 8.0));
		ALBEDO = mix(color, core, sweep * 0.8 + rim * 0.2);
		ALPHA = clamp(0.3 + rim * 0.55 + sweep * 0.45, 0.0, 0.88) * fade;
	} else {
		float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = pow(1.0 - ndv, 1.6);
		// Faixas de luz subindo pela aura.
		float bands = 0.5 + 0.5 * sin(v_local.y * 9.0 - TIME * 7.0 + atan(v_local.z, v_local.x) * 3.0);
		bands = smoothstep(0.55, 1.0, bands);
		float pulse = 0.85 + 0.15 * sin(TIME * 9.0);
		ALBEDO = mix(color, core, rim * 0.5 + bands * 0.35);
		ALPHA = clamp(rim * 1.1 + bands * 0.3 + 0.16, 0.0, 0.9) * pulse * fade;
	}
}
