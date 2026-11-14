// Caixa de item (veja item_box.gdshader e item_box_inner.gdshader): cubo de
// vidro furta-cor com retícula de pontinhos, moldura branca nas quinas e o logo
// "at" da Ativos em branco (seta amarela) com contorno azul-marinho em cada face.
// Gira em volta de um eixo inclinado e flutua — tudo no vertex shader, então a
// caixa não precisa de script rodando por quadro.
// UV = 0..1 em cada face, (0,0) no canto de cima à esquerda olhando de fora.
// COLOR.r = 1 nos chanfros das quinas (moldura).

uniform sampler2D logo : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float logo_aspect = 1.643;
// Largura do logo em fração da face.
uniform float logo_size = 0.7;
uniform vec3 logo_color : source_color = vec3(1.0);
uniform vec3 logo_accent : source_color = vec3(1.0, 0.82, 0.1);
uniform vec3 outline_color : source_color = vec3(0.06, 0.09, 0.24);
uniform vec3 frame_color : source_color = vec3(1.0);
uniform float saturation = 0.85;
uniform float spin_speed = 1.25;
uniform float bob = 0.1;
uniform float glow = 0.55;

varying float v_frame;
varying float v_hue;

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	// Fase diferente para cada caixa (pela posição), assim a fileira não gira igual.
	float phase = dot(NODE_POSITION_WORLD.xz, vec2(0.37, 0.61));
	v_hue = dot(NORMAL, vec3(0.11, 0.23, 0.37));
	v_frame = COLOR.r;
	float a = TIME * spin_speed + phase;
	float ca = cos(a);
	float sa = sin(a);
	mat3 spin = mat3(vec3(ca, 0.0, -sa), vec3(0.0, 1.0, 0.0), vec3(sa, 0.0, ca));
	const float TX = 0.46;
	const float TZ = 0.34;
	mat3 tilt_x = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(TX), sin(TX)), vec3(0.0, -sin(TX), cos(TX)));
	mat3 tilt_z = mat3(vec3(cos(TZ), sin(TZ), 0.0), vec3(-sin(TZ), cos(TZ), 0.0), vec3(0.0, 0.0, 1.0));
	mat3 r = spin * tilt_x * tilt_z;
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
	VERTEX.y += sin(TIME * 2.2 + phase) * bob;
}

float logo_alpha(vec2 luv) {
	vec2 inside = step(vec2(0.0), luv) * step(luv, vec2(1.0));
	return texture(logo, clamp(luv, 0.0, 1.0)).a * inside.x * inside.y;
}

void fragment() {
	vec2 uv = UV;
	// Vista de dentro (faces do fundo através do vidro): desespelha o logo.
	if (!FRONT_FACING) {
		uv.x = 1.0 - uv.x;
	}
	vec2 c = uv - 0.5;
	float ndv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);

	// Furta-cor: arco-íris girando em volta do centro da face, que muda com o
	// ângulo de visão e com o tempo.
	float hue = atan(c.y, c.x) * 0.159155 + TIME * 0.07 + v_hue + (1.0 - ndv) * 0.45;
	vec3 rainbow = hsv_to_rgb(vec3(fract(hue), saturation, 1.0));

	// Retícula de pontinhos.
	vec2 g = fract(uv * 14.0) - 0.5;
	float d = length(g);
	float aa = max(fwidth(d), 1e-4);
	float dots = 1.0 - smoothstep(0.2 - aa, 0.2 + aa, d);

	// Moldura nas bordas da face (continua nos chanfros).
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float ew = max(fwidth(edge), 1e-4);
	float frame = max(1.0 - smoothstep(0.04 - ew, 0.04 + ew, edge), v_frame);

	// Logo centralizado, com contorno (8 amostras em volta).
	vec2 lsz = vec2(logo_size, logo_size / logo_aspect);
	vec2 luv = c / lsz + 0.5;
	vec4 l = texture(logo, clamp(luv, 0.0, 1.0));
	l.a *= step(0.0, luv.x) * step(luv.x, 1.0) * step(0.0, luv.y) * step(luv.y, 1.0);
	float halo = 0.0;
	vec2 o = vec2(0.03) / lsz;
	halo = max(halo, logo_alpha(luv + vec2(o.x, 0.0)));
	halo = max(halo, logo_alpha(luv - vec2(o.x, 0.0)));
	halo = max(halo, logo_alpha(luv + vec2(0.0, o.y)));
	halo = max(halo, logo_alpha(luv - vec2(0.0, o.y)));
	halo = max(halo, logo_alpha(luv + o * 0.7));
	halo = max(halo, logo_alpha(luv - o * 0.7));
	halo = max(halo, logo_alpha(luv + vec2(o.x, -o.y) * 0.7));
	halo = max(halo, logo_alpha(luv + vec2(-o.x, o.y) * 0.7));
	vec3 lc = mix(logo_color, logo_accent, smoothstep(0.05, 0.09, l.r));

	vec3 col = rainbow * mix(0.78, 1.0, dots);
	float alpha = mix(0.45, 0.58, dots) + fres * 0.3;
	col = mix(col, frame_color, frame * 0.9);
	alpha = mix(alpha, 0.88, frame);
	float outline = halo * (1.0 - frame);
	col = mix(col, outline_color, outline * 0.9);
	alpha = mix(alpha, 0.94, outline);
	col = mix(col, lc, l.a);
	alpha = mix(alpha, 0.98, l.a);

#ifdef INNER
	// Faces do fundo: mais apagadas, só para dar volume ao vidro.
	col *= 0.75;
	alpha *= 0.5;
#endif
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
	EMISSION = col * glow * (0.7 + 0.3 * max(l.a, frame));
	ROUGHNESS = 0.12;
	SPECULAR = 0.35;
	RIM = 0.2;
	RIM_TINT = 0.8;
}
