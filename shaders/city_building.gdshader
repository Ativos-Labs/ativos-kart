shader_type spatial;
render_mode diffuse_burley;
// Prédios da cidade neon (track_city.gd): fachada escura com janelas acesas (quentes,
// frias ou na cor do neon do prédio; parte apagada) e telhado escuro.
// UV.x = metros na horizontal ao longo da fachada, UV.y = metros de altura; no telhado
// UV.y < 0. COLOR.rgb = cor do neon do prédio (sRGB), COLOR.a = sorteio do prédio.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 facade : source_color = vec3(0.07, 0.07, 0.11);
uniform vec3 glass : source_color = vec3(0.02, 0.025, 0.05);
uniform float window_w = 2.4;
uniform float window_h = 3.4;
// Fração das janelas acesas e o brilho delas.
uniform float lit = 0.5;
uniform float window_glow = 1.5;

varying vec4 info;

void vertex() {
	info = COLOR;
}

void fragment() {
	float seed = info.a;
	vec3 base = facade * (0.75 + 0.5 * seed);
	if (UV.y < 0.0) {
		ALBEDO = base * 0.6;
		ROUGHNESS = 0.9;
	} else {
		// Cada prédio com a sua grade (alguns com janelas largas, outros em faixas).
		float wide = step(0.6, seed);
		vec2 size = vec2(window_w * (1.0 + wide * 1.6), window_h);
		vec2 p = UV / size + vec2(seed * 17.0, 0.0);
		vec2 cell = floor(p);
		vec2 f = fract(p);
		float fw = max(fwidth(p.x), fwidth(p.y));
		float win = step(0.16, f.x) * step(f.x, 0.84) * step(0.24, f.y) * step(f.y, 0.8);
		// De longe, a média (a grade fina piscaria).
		float far = smoothstep(0.2, 0.6, fw);
		win = mix(win, 0.45, far);
		float h = hash12(cell + seed * 91.0);
		// Andares inteiros apagados ou acesos, e algumas janelas soltas.
		float floor_on = step(0.25, hash12(vec2(cell.y, seed * 53.0)));
		float on = step(h, lit * (0.55 + 0.9 * seed)) * floor_on;
		on = mix(on, lit * 0.6, far);
		float hc = hash12(cell * 1.7 + seed * 13.0);
		vec3 wcol = hc < 0.55 ? vec3(1.0, 0.72, 0.4) : (hc < 0.85 ? vec3(0.5, 0.78, 1.0) : info.rgb);
		wcol = srgb_to_linear(wcol);
		ALBEDO = mix(base, glass, win);
		ROUGHNESS = mix(0.85, 0.15, win);
		SPECULAR = mix(0.3, 0.6, win);
		EMISSION = wcol * win * on * window_glow * (0.6 + 0.4 * hash12(cell + 5.0));
	}
}
