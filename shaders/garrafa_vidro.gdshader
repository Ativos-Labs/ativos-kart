shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Vidro verde da garrafa do Rafael (scripts/garrafa_cerveja.gd). Opaco, mas com cara de
// vidro: mais claro de frente (a luz atravessa) e escuro nas bordas (mais vidro no
// caminho), duas faixas de reflexo verticais (as janelas do estúdio), a borda acesa e
// gotinhas de água gelada. UV.x dá a volta na garrafa e UV.y vai do fundo (0) à tampa (1).

uniform vec3 glass_color : source_color = vec3(0.07, 0.5, 0.17);
uniform vec3 edge_color : source_color = vec3(0.01, 0.12, 0.04);
// Gotinhas por volta (x) e por altura (y) da garrafa; 0 em `droplets` desliga.
uniform vec2 droplet_grid = vec2(22.0, 34.0);
uniform float droplets : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = 1.0 - facing;
	vec3 color = mix(glass_color, edge_color, smoothstep(0.15, 0.9, edge));
	// Reflexos: faixas claras onde a normal (espaço da câmera) aponta para os lados.
	float streak = smoothstep(0.14, 0.0, abs(NORMAL.x + 0.52)) + 0.45 * smoothstep(0.07, 0.0, abs(NORMAL.x - 0.6));
	streak *= smoothstep(-0.75, -0.35, NORMAL.y);
	// Gotinhas: uma por célula (metade das células), com um brilho pequeno em cima.
	vec2 grid = UV * droplet_grid;
	vec2 cell = floor(grid);
	vec2 f = fract(grid) - 0.5 - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.4;
	float h = hash(cell);
	float r = mix(0.14, 0.3, fract(h * 7.3));
	float d = length(f * vec2(1.0, 0.8));
	float aa = fwidth(d) * 1.5;
	float drop = (1.0 - smoothstep(r - aa, r + aa, d)) * step(0.5, h) * droplets;
	float glint = (1.0 - smoothstep(0.0, r * 0.5 + aa, length(f - vec2(-0.3, 0.3) * r))) * drop;
	ALBEDO = mix(color, color * 1.4 + vec3(0.03, 0.06, 0.04), drop * 0.8);
	ROUGHNESS = mix(0.09, 0.03, drop);
	SPECULAR = 0.75;
	EMISSION = vec3(0.8, 1.0, 0.85) * streak * 0.5 + glass_color * pow(edge, 3.0) * 0.5 + vec3(0.9) * glint * 0.7;
}
