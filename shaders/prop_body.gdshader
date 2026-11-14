shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Corpo dos balões e do dirigível, com gomos coloridos e o logo da Ativos
// projetado nas laterais. Malha base: esfera de raio 1 (escala no nó).
// mode 0 = balão (formato de gota, gomos), 1 = dirigível (faixa azul embaixo).

uniform int mode = 0;
uniform vec3 color_a : source_color = vec3(0.149, 0.239, 0.749);
uniform vec3 color_b : source_color = vec3(1.0);
uniform vec3 color_c : source_color = vec3(1.0, 0.82, 0.1);
uniform int gores = 12;
uniform sampler2D logo : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float logo_aspect = 1.64;
// Tamanho do logo em unidades do objeto (largura) e escala do nó (para não distorcer).
uniform float logo_width = 1.0;
uniform float logo_center_y = 0.1;
uniform vec3 body_scale = vec3(1.0);
uniform bool recolor_logo = false;
uniform vec3 logo_main : source_color = vec3(1.0);
uniform vec3 logo_accent : source_color = vec3(1.0, 0.82, 0.1);

varying vec3 obj;

void vertex() {
	if (mode == 0) {
		float squeeze = mix(0.38, 1.0, smoothstep(-1.0, 0.15, VERTEX.y));
		VERTEX.xz *= squeeze;
		VERTEX.y *= 1.12;
	}
	obj = VERTEX;
}

void fragment() {
	vec3 col;
	if (mode == 0) {
		float ang = atan(obj.x, obj.z) / TAU + 0.5;
		float g = floor(ang * float(gores));
		float k = mod(g, 3.0);
		col = k < 0.5 ? color_a : (k < 1.5 ? color_b : color_c);
		float seam = abs(fract(ang * float(gores)) - 0.5);
		col *= 0.8 + 0.2 * smoothstep(0.5, 0.42, seam);
		if (obj.y < -0.75) {
			col = color_a * 0.8;
		}
	} else {
		col = color_b;
		col = mix(col, color_a, step(obj.y, -0.42));
		col = mix(col, color_c, step(abs(obj.y + 0.42), 0.05));
		col = mix(col, color_a, step(0.93, abs(obj.z)));
	}

	// Logo nas duas laterais (lado +X e -X), lendo certo dos dois lados.
	float side = sign(obj.x);
	float lw = logo_width;
	float lh = lw * body_scale.z / body_scale.y / logo_aspect;
	vec2 luv = vec2(0.5 - obj.z * side / lw, 0.5 - (obj.y - logo_center_y) / lh);
	if (mode == 0 && abs(obj.x) > 0.2) {
		// Selo branco atrás do logo do balão.
		float badge = length((luv - 0.5) / vec2(0.66, 0.72));
		col = mix(col, color_a, 1.0 - smoothstep(1.0, 1.02, badge));
		col = mix(col, vec3(1.0), 1.0 - smoothstep(0.9, 0.92, badge));
	}
	if (abs(obj.x) > 0.25 && luv.x > 0.0 && luv.x < 1.0 && luv.y > 0.0 && luv.y < 1.0) {
		vec4 l = texture(logo, luv);
		vec3 lc = l.rgb;
		if (recolor_logo) {
			lc = mix(logo_main, logo_accent, smoothstep(0.05, 0.09, l.r));
		}
		col = mix(col, lc, l.a);
	}
	ALBEDO = col;
	ROUGHNESS = mode == 0 ? 0.6 : 0.35;
	SPECULAR = 0.45;
	RIM = 0.2;
}
