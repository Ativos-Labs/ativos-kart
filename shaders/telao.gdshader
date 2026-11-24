shader_type spatial;
render_mode unshaded, cull_back;
// Telão de LED do estádio (track_stadium.gd): alterna a marca da Ativos, o ícone "at"
// e uma bandeirada quadriculada, trocando com uma cortina; de perto aparecem os LEDs.

uniform sampler2D logo_a : source_color, filter_linear_mipmap, repeat_disable;
uniform float logo_a_aspect = 4.0;
uniform sampler2D logo_b : source_color, filter_linear_mipmap, repeat_disable;
uniform float logo_b_aspect = 1.0;
uniform float panel_aspect = 1.78;
uniform vec3 bg_a : source_color = vec3(0.15, 0.24, 0.75);
uniform vec3 bg_b : source_color = vec3(1.0, 0.82, 0.1);
uniform vec3 accent : source_color = vec3(1.0, 0.82, 0.1);
uniform float energy = 1.4;
uniform float period = 5.0;
uniform float leds = 96.0;

vec3 logo_on(sampler2D tex, float aspect, vec2 uv, vec3 bg, float fill, bool recolor) {
	float x = (uv.x - 0.5) * panel_aspect;
	float lh = min(fill, panel_aspect * 0.86 / aspect);
	float lw = lh * aspect;
	vec2 luv = vec2(x / lw + 0.5, (uv.y - 0.5) / lh + 0.5);
	vec4 l = texture(tex, clamp(luv, 0.0, 1.0));
	l.a *= step(0.0, luv.x) * step(luv.x, 1.0) * step(0.0, luv.y) * step(luv.y, 1.0);
	vec3 lc = recolor ? mix(vec3(1.0), accent, smoothstep(0.05, 0.09, l.r)) : l.rgb;
	return mix(bg, lc, l.a);
}

vec3 scene(int k, vec2 uv) {
	if (k == 0) {
		return logo_on(logo_a, logo_a_aspect, uv, bg_a, 0.42, false);
	} else if (k == 1) {
		return logo_on(logo_b, logo_b_aspect, uv, vec3(0.06, 0.09, 0.22), 0.72, true);
	}
	// Bandeirada quadriculada ondulando, com a faixa amarela.
	vec2 p = vec2(uv.x * panel_aspect, uv.y) * 7.0;
	p.y += sin(p.x * 0.9 + TIME * 3.0) * 0.35;
	float c = mod(floor(p.x) + floor(p.y), 2.0);
	vec3 col = mix(vec3(0.05), vec3(0.97), c);
	return mix(col, bg_b, step(0.86, uv.y) + step(uv.y, 0.14));
}

void fragment() {
	vec2 uv = vec2(UV.x, UV.y);
	float cycle = TIME / period;
	int k = int(mod(floor(cycle), 3.0));
	int next = int(mod(floor(cycle) + 1.0, 3.0));
	// Cortina nos últimos 12% de cada cena.
	float wipe = smoothstep(0.88, 1.0, fract(cycle));
	vec3 col = uv.x < wipe ? scene(next, uv) : scene(k, uv);
	col = mix(col, vec3(1.0), smoothstep(0.012, 0.0, abs(uv.x - wipe)) * step(0.001, wipe) * step(wipe, 0.999));
	// LEDs: pontos redondos de perto, cor cheia de longe.
	vec2 g = fract(vec2(uv.x * panel_aspect, uv.y) * leds) - 0.5;
	float dot_mask = smoothstep(0.5, 0.3, length(g));
	float far = smoothstep(0.25, 0.7, fwidth(uv.y * leds));
	col *= mix(0.25 + dot_mask * 1.05, 1.0, far);
	// As cores (source_color) já chegam lineares.
	ALBEDO = col * energy;
}
