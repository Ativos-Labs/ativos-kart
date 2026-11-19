shader_type spatial;
// Guia de pagamento verde da RPV que enrola e vira foguete embaixo do kart (RpvRocket).
// A malha é uma folha plana na altura do topo do foguete (x = a volta, z = o
// comprimento); `roll` a enrola num tubo de raio `radius`: 0 = folha esticada, 1 = tubo
// fechado, com o lado impresso para fora. Com `solid` (bico e aletas) a malha fica como
// está e a cor é lisa.
render_mode cull_disabled;

uniform sampler2D guia_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float roll = 1.0;
uniform float radius = 0.2;
uniform float solid = 0.0;
uniform vec3 solid_color : source_color = vec3(0.11, 0.48, 0.27);
// Verso da guia (dentro do tubo): papel verde-claro sem impressão.
uniform vec3 back_color : source_color = vec3(0.74, 0.88, 0.74);

void vertex() {
	if (solid < 0.5) {
		// Curvatura k: o arco de comprimento x vira o ângulo a = x * k em volta do eixo
		// do tubo (que fica em y = radius); o meio da folha continua em cima.
		float k = max(roll, 0.0005) / radius;
		float a = VERTEX.x * k;
		VERTEX.x = sin(a) / k;
		VERTEX.y = 2.0 * radius - (1.0 - cos(a)) / k;
		NORMAL = vec3(sin(a), cos(a), 0.0);
	}
}

void fragment() {
	vec3 col;
	if (solid > 0.5) {
		col = solid_color;
	} else {
		col = FRONT_FACING ? texture(guia_tex, UV).rgb : back_color;
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
