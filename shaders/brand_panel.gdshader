shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Painel com logo da Ativos: outdoors, pórtico de largada, bandeiras e dirigível.
// Encaixa o logo no painel sem distorcer, pode repetir o logo, trocar as cores
// do ícone (ex.: "at" branco com a seta amarela) e ondular como bandeira.
// UV (0,0) = canto de cima à esquerda, olhando de frente.

uniform vec3 bg_color : source_color = vec3(1.0);
uniform vec3 border_color : source_color = vec3(1.0, 0.82, 0.1);
uniform float border_width = 0.0;
uniform sampler2D logo : source_color, hint_default_transparent, filter_linear_mipmap_anisotropic, repeat_disable;
// Largura / altura da imagem do logo e do painel.
uniform float logo_aspect = 1.64;
uniform float panel_aspect = 3.0;
// Altura do logo em fração da altura do painel.
uniform float logo_fill = 0.7;
// Quantas cópias do logo lado a lado.
uniform int logo_count = 1;
uniform bool recolor = false;
uniform vec3 recolor_main : source_color = vec3(1.0);
uniform vec3 recolor_accent : source_color = vec3(1.0, 0.82, 0.1);
// Ondulação de bandeira (0 = painel rígido). O lado UV.x = 0 fica preso no mastro.
uniform float wave = 0.0;
uniform float emission = 0.0;
// Listras diagonais sutis no fundo.
uniform float stripes = 0.0;

void vertex() {
	if (wave > 0.0) {
		float phase = NODE_POSITION_WORLD.x * 0.37 + NODE_POSITION_WORLD.z * 0.21;
		float k = UV.x;
		VERTEX.z += sin(UV.x * 6.5 - TIME * 5.0 + phase) * wave * k;
		VERTEX.y -= k * k * wave * 0.4;
	}
}

void fragment() {
	vec2 uv = UV;
	if (!FRONT_FACING) {
		uv.x = 1.0 - uv.x;
	}
	vec3 col = bg_color;
	if (stripes > 0.0) {
		float s = fract((uv.x * panel_aspect + uv.y) * 2.0);
		col = mix(col, col * 1.12, step(0.5, s) * stripes);
	}

	// Logo (ou várias cópias) centralizado em cada fatia do painel.
	float count = float(max(logo_count, 1));
	float slice_w = panel_aspect / count;
	float x = uv.x * panel_aspect;
	float slice = min(floor(x / slice_w), count - 1.0);
	float lh = min(logo_fill, slice_w * 0.86 / logo_aspect);
	float lw = lh * logo_aspect;
	float cx = (slice + 0.5) * slice_w;
	vec2 luv = vec2((x - cx) / lw + 0.5, (uv.y - 0.5) / lh + 0.5);
	vec2 gx = vec2(dFdx(x) / lw, dFdx(uv.y) / lh);
	vec2 gy = vec2(dFdy(x) / lw, dFdy(uv.y) / lh);
	vec4 l = textureGrad(logo, clamp(luv, 0.0, 1.0), gx, gy);
	l.a *= step(0.0, luv.x) * step(luv.x, 1.0) * step(0.0, luv.y) * step(luv.y, 1.0);
	vec3 lc = l.rgb;
	if (recolor) {
		lc = mix(recolor_main, recolor_accent, smoothstep(0.05, 0.09, l.r));
	}
	col = mix(col, lc, l.a);

	if (border_width > 0.0) {
		vec2 d = min(uv, 1.0 - uv) * vec2(panel_aspect, 1.0);
		float b = 1.0 - step(border_width, min(d.x, d.y));
		col = mix(col, border_color, b);
	}
	ALBEDO = col;
	EMISSION = col * emission;
	ROUGHNESS = 0.5;
	SPECULAR = 0.35;
}
