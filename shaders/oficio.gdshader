shader_type spatial;
// Ofício gigante da Superpreferência (OficioSuper): uma folha A4 voando como um tapete,
// com uma onda que corre da frente para trás e a ponta da frente curvada para cima. A
// malha é plana (x = largura, z = comprimento, frente em -z); o topo da página fica na
// frente, então da câmera de trás o texto aparece em pé. O carimbo PRIORIDADE (`stamp`,
// 0 → 1) cai grande e assenta em cima do papel.
render_mode cull_disabled;

uniform sampler2D paper_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D stamp_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 sheet_size = vec2(3.0, 4.24);
uniform float wave = 0.1;
uniform float wave_speed = 9.0;
uniform float curl = 0.5;
uniform float stamp = 1.0;
// Centro do carimbo (UV), giro (rad) e largura (fração da largura da folha).
uniform vec2 stamp_center = vec2(0.5, 0.6);
uniform float stamp_angle = 0.28;
uniform float stamp_width = 0.86;
uniform vec3 stamp_color : source_color = vec3(0.86, 0.12, 0.16);
uniform vec3 back_color : source_color = vec3(0.9, 0.89, 0.84);

// Altura da folha no ponto p = (x, z).
float lift(vec2 p) {
	float half_len = sheet_size.y * 0.5;
	float t = (p.y + half_len) / sheet_size.y;
	float w = sin(p.y * 2.1 - TIME * wave_speed + p.x * 0.3) * wave * (0.3 + t);
	float front = clamp((0.95 - (p.y + half_len)) / 0.95, 0.0, 1.0);
	float edge = abs(p.x) / (sheet_size.x * 0.5);
	return w + curl * front * front - 0.08 * edge * edge;
}

void vertex() {
	vec2 p = VERTEX.xz;
	float h = lift(p);
	float e = 0.05;
	float dx = (lift(p + vec2(e, 0.0)) - h) / e;
	float dz = (lift(p + vec2(0.0, e)) - h) / e;
	VERTEX.y += h;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	if (!FRONT_FACING) {
		ALBEDO = back_color;
		ROUGHNESS = 0.9;
	} else {
		vec3 col = texture(paper_tex, UV).rgb;
		if (stamp > 0.0) {
			// Espaço do carimbo em metros, girado; ele cai 2,4x maior e assenta.
			vec2 m = (UV - stamp_center) * sheet_size;
			float c = cos(stamp_angle);
			float s = sin(stamp_angle);
			m = vec2(c * m.x + s * m.y, -s * m.x + c * m.y);
			float e = clamp(stamp, 0.0, 1.0);
			float grow = mix(2.4, 1.0, 1.0 - (1.0 - e) * (1.0 - e));
			vec2 sz = vec2(stamp_width * sheet_size.x, stamp_width * sheet_size.x * 224.0 / 512.0) * grow;
			vec2 suv = m / sz + 0.5;
			if (suv.x > 0.0 && suv.x < 1.0 && suv.y > 0.0 && suv.y < 1.0) {
				float a = texture(stamp_tex, suv).a * clamp(stamp * 3.0, 0.0, 1.0);
				col = mix(col, stamp_color, a * 0.92);
			}
		}
		ALBEDO = col;
		ROUGHNESS = 0.85;
	}
}
