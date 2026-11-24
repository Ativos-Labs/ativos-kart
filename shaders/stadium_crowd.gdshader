shader_type spatial;
render_mode diffuse_burley;
// Torcida pintada nos degraus da arquibancada do estádio (track_stadium.gd): cada
// cadeira tem um torcedor (ou fica vazia), com camisa de uma cor e tom de pele próprios;
// parte da torcida pula e levanta os braços. Nada de malha por pessoa: é só o desenho
// nos espelhos (parte em pé) e nos pisos dos degraus.
// UV.x = metros ao longo do anel. Espelho do degrau: UV.y = fila + altura (0..1, de
// baixo para cima). Piso: UV.y = -(fila + profundidade (0..1, da frente para trás)) - 1.

#include "res://shaders/noise.gdshaderinc"

uniform vec3 seat_a : source_color = vec3(0.15, 0.24, 0.75);
uniform vec3 seat_b : source_color = vec3(1.0, 0.82, 0.1);
uniform vec3 step_color : source_color = vec3(0.66, 0.67, 0.7);
// Largura de uma cadeira, altura do espelho e profundidade do piso (m).
uniform float seat_width = 0.62;
uniform float riser_height = 0.9;
uniform float tread_depth = 1.6;
// Cadeiras ocupadas e torcedores que pulam.
uniform float fill = 0.88;
uniform float cheer = 0.4;
// Uma escada (corredor sem torcida) a cada tantas cadeiras.
uniform float aisle_every = 26.0;
// Noite (cidade neon): tudo mais escuro, com bastões de luz neon e flashes de celular
// piscando na torcida. 0 = dia.
uniform float night = 0.0;

const vec3 SHIRTS[10] = vec3[10](
	vec3(0.15, 0.24, 0.75), vec3(1.0, 0.82, 0.1), vec3(0.95, 0.95, 0.96), vec3(0.94, 0.17, 0.18),
	vec3(0.37, 0.45, 0.85), vec3(0.06, 0.09, 0.22), vec3(1.0, 0.55, 0.15), vec3(0.2, 0.7, 0.4),
	vec3(0.15, 0.24, 0.75), vec3(1.0, 0.82, 0.1));

vec3 shirt_of(float h) {
	return srgb_to_linear(SHIRTS[int(h * 9.99)]);
}

void fragment() {
	vec2 uv = UV;
	bool riser = uv.y >= 0.0;
	float r = riser ? uv.y : -uv.y - 1.0;
	float row = floor(r);
	float t = fract(r);
	float cell = floor(uv.x / seat_width);
	float lx = fract(uv.x / seat_width);
	float bx = abs(lx - 0.5) * seat_width;
	// Bloco de cadeiras azul ou amarelo, com as escadas entre os blocos.
	float block = floor(cell / aisle_every);
	float in_block = cell - block * aisle_every;
	bool aisle = in_block < 1.5;
	vec3 seat = srgb_to_linear(mod(block + floor(row / 4.0), 2.0) < 1.0 ? seat_a : seat_b);
	vec3 steps = srgb_to_linear(step_color);
	vec3 col = riser ? steps * 0.9 : mix(seat, steps, step(0.42, t));
	float h = hash12(vec2(cell, row) + 3.7);
	bool present = !aisle && h < fill;
	vec3 people = vec3(0.0);
	float person = 0.0;
	vec3 glow = vec3(0.0);
	if (present) {
		float h2 = hash12(vec2(row * 1.31, cell * 0.71) + 11.0);
		vec3 shirt = shirt_of(h2);
		vec3 skin = mix(vec3(0.89, 0.55, 0.36), vec3(0.2, 0.09, 0.04), hash12(vec2(cell * 1.7, row * 3.1)));
		skin = srgb_to_linear(skin);
		vec3 hair = srgb_to_linear(mix(vec3(0.08, 0.05, 0.03), vec3(0.55, 0.38, 0.18), step(0.8, hash12(vec2(cell, row * 7.0)))));
		bool cheering = hash12(vec2(cell * 0.37, row * 5.3)) < cheer;
		float beat = abs(sin(TIME * (4.5 + h * 3.0) + h * 40.0));
		float hop = cheering ? beat * 0.11 : 0.0;
		// À noite: bastão de luz (cor neon) ou celular (branco, piscando).
		float lights = hash12(vec2(cell * 2.3, row * 0.9) + 31.0);
		vec3 stick = lights < 0.5 ? vec3(0.1, 0.95, 1.0) : vec3(1.0, 0.15, 0.75);
		bool has_stick = night > 0.0 && lights < 0.24;
		bool has_phone = night > 0.0 && lights > 0.95 && fract(TIME * 0.4 + h * 7.0) < 0.55;
		if (riser) {
			float y = t * riser_height - hop;
			// Tronco com ombros arredondados, cabeça e (de quem comemora) os braços para cima.
			float shoulder = 0.21 - max(y - 0.44, 0.0) * 0.9;
			if (y > 0.0 && y < 0.55 && bx < shoulder) {
				people = shirt;
				person = 1.0;
			}
			float head = length(vec2(bx, (y - 0.7) * 0.92));
			if (head < 0.12) {
				people = y > 0.76 && bx < 0.1 ? hair : skin;
				person = 1.0;
			}
			if (cheering && beat > 0.35 && bx > 0.15 && bx < 0.22 && y > 0.4 && y < 0.92) {
				people = y > 0.84 ? skin : shirt;
				person = 1.0;
			}
			// Bastão erguido ao lado da cabeça; o celular é um ponto na altura do rosto.
			if (has_stick && abs(lx - 0.5) * seat_width > 0.15 && abs(lx - 0.5) * seat_width < 0.2 && y > 0.6 && y < 0.98) {
				glow = stick;
			}
			if (has_phone && length(vec2(bx - 0.14, y - 0.78)) < 0.05) {
				glow = vec3(1.0);
			}
		} else {
			// Visto de cima: ombros (camisa) e a cabeça no meio.
			vec2 p = vec2(bx, (t - 0.32) * tread_depth);
			if (length(p * vec2(1.0, 1.7)) < 0.23) {
				people = shirt;
				person = 1.0;
			}
			if (length(p) < 0.12) {
				people = hair;
				person = 1.0;
			}
			if ((has_stick || has_phone) && length(p - vec2(0.16, -0.1)) < 0.07) {
				glow = has_phone ? vec3(1.0) : stick;
			}
		}
	}
	col = mix(col, people, person);
	// De longe os detalhes piscariam: mistura com a cor média da torcida.
	float fw = fwidth(uv.x) / seat_width;
	vec3 crowd_avg = mix(steps * 0.8, srgb_to_linear(vec3(0.55, 0.5, 0.55)), aisle ? 0.0 : fill * 0.75);
	float blend = smoothstep(0.35, 0.9, fw);
	col = mix(col, crowd_avg, blend);
	// À noite, como sob os refletores: só um pouco mais escuro.
	col *= 1.0 - night * 0.25;
	ALBEDO = col;
	ROUGHNESS = 0.9;
	// De longe as luzinhas viram um brilho médio (não piscam).
	vec3 glow_avg = vec3(0.45, 0.35, 0.9) * 0.05 * (aisle ? 0.0 : 1.0);
	EMISSION = mix(glow * 2.2, glow_avg, blend) * night;
}
