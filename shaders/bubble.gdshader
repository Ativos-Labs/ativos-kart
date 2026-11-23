shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Bolha (anel claro com um brilho) ou gota de respingo (`drop`), sempre de frente para
// a câmera. Usado pelas partículas do kart debaixo d'água (KartWaterFx) e pelas colunas
// de bolhas do fundo do mar/lago.

uniform vec4 tint : source_color = vec4(0.85, 0.97, 1.0, 0.8);
uniform bool drop = false;

void vertex() {
	// Billboard mantendo a escala de cada partícula.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (r > 1.0) {
		discard;
	}
	float a;
	vec3 col = tint.rgb;
	if (drop) {
		a = 1.0 - smoothstep(0.35, 1.0, r);
		col = mix(col, vec3(1.0), 1.0 - r);
	} else {
		float ring = smoothstep(0.62, 0.86, r) * (1.0 - smoothstep(0.9, 1.0, r));
		float shine = 1.0 - smoothstep(0.0, 0.22, length(q - vec2(-0.35, 0.38)));
		a = max(ring * 0.9, shine) + 0.12;
	}
	ALBEDO = col;
	ALPHA = clamp(a * tint.a * COLOR.a, 0.0, 1.0);
}
