// Fogo do turbo saindo dos escapamentos (montado por scripts/boost_exhaust_fx.gd).
//
// Cada chama é uma fileira de sprites ao longo do eixo do escapamento, virados para
// a câmera e esticados na direção em que a chama aparece na tela: de lado eles se
// emendam numa língua de fogo; olhando por trás (a câmera da corrida) viram anéis
// concêntricos com o núcleo quente no meio. Duas camadas: a chama externa (comprida,
// esfria da boca para a ponta) e o núcleo (curto, quase branco). A tremulação e o
// comprimento saem do TIME no vertex shader; o script só muda `intensity` e `heat`.
//
// Atributos de cada vértice (um quad por sprite, todas as chamas do kart numa malha).
// Só atributos padrão (VERTEX, NORMAL, UV, UV2, COLOR), iguais em todos os renderizadores.
//   VERTEX  = centro da boca do escapamento (espaço do kart)
//   NORMAL  = direção da chama (unitária)
//   UV      = canto do quad (-1..1)
//   UV2     = (t, comprimento da chama em m)   t: 0 = boca, 1 = ponta
//   COLOR   = (camada: 0 = chama externa, 1 = núcleo; estilo / 2;
//              raio da boca / RADIUS_MAX; semente do sprite)
//             estilo: 0 = fogo, 1 = jato, 2 = plasma (veja KartExhaust.Style)
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform, fog_disabled, shadows_disabled;

// 0 = apagado, 1 = turbo, acima de 1 = estouro da ignição (chama maior e mais clara).
uniform float intensity = 0.0;
// Força do turbo (nível do mini-turbo): chama mais comprida.
uniform float heat = 1.0;

// Fração do comprimento da chama ocupada pelo núcleo (igual a CORE_LEN no script).
const float CORE_LEN = 0.42;
// Escala do raio guardado em COLOR.b (igual a RADIUS_MAX no script).
const float RADIUS_MAX = 0.3;

varying vec2 v_corner;
varying float v_t;
varying float v_core;
varying float v_style;
varying float v_alpha;
varying float v_seed;

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float noise11(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), f);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = i.x + i.y * 57.0;
	return mix(mix(hash11(n), hash11(n + 1.0), f.x), mix(hash11(n + 57.0), hash11(n + 58.0), f.x), f.y);
}

// Degradê de quatro cores: a em 0, b em 0.25, c em 0.6, d em 1.
vec3 ramp4(vec3 a, vec3 b, vec3 c, vec3 d, float t) {
	if (t < 0.25) {
		return mix(a, b, t / 0.25);
	}
	if (t < 0.6) {
		return mix(b, c, (t - 0.25) / 0.35);
	}
	return mix(c, d, (t - 0.6) / 0.4);
}

// Cores em HDR (linear): acima de ~1.6 o glow da pista faz brilhar.
vec3 outer_color(float style, float t) {
	if (style < 0.5) {
		// Fogo: amarelo quase branco na boca, laranja e vermelho escuro na ponta.
		return ramp4(vec3(2.0, 1.15, 0.35), vec3(1.9, 0.6, 0.08), vec3(1.3, 0.22, 0.03), vec3(0.5, 0.05, 0.02), t);
	}
	if (style < 1.5) {
		// Jato: azul-claro que vai a violeta, com uma pontinha alaranjada (pós-combustão).
		return ramp4(vec3(0.8, 1.15, 1.9), vec3(0.3, 0.6, 1.7), vec3(0.5, 0.28, 1.2), vec3(0.7, 0.25, 0.15), t);
	}
	// Plasma: ciano intenso esfriando para violeta.
	return ramp4(vec3(0.9, 1.9, 2.2), vec3(0.2, 1.2, 2.0), vec3(0.6, 0.3, 1.7), vec3(0.4, 0.08, 0.7), t);
}

vec3 core_color(float style, float t) {
	if (style < 0.5) {
		// Fogo: azul na boca (combustão completa), branco e amarelado no fim do núcleo.
		return mix(mix(vec3(1.0, 1.4, 3.0), vec3(2.6, 2.4, 1.9), smoothstep(0.0, 0.5, t)), vec3(2.4, 1.5, 0.5), smoothstep(0.5, 1.0, t));
	}
	if (style < 1.5) {
		return mix(vec3(2.0, 2.3, 2.6), vec3(1.1, 1.7, 2.6), t);
	}
	return mix(vec3(2.4, 2.7, 2.7), vec3(1.2, 2.3, 2.7), t);
}

void vertex() {
	float t = UV2.x;
	vec3 axis_l = normalize(NORMAL) * UV2.y;
	float radius = COLOR.b * RADIUS_MAX;
	float sprite = COLOR.a;
	// Semente da chama inteira pela posição da boca (cada escapamento pulsa diferente).
	float nozzle = fract(dot(VERTEX, vec3(12.9898, 78.233, 37.719))) * 61.0;
	v_core = COLOR.r;
	v_style = floor(COLOR.g * 2.0 + 0.5);
	v_t = t;
	v_seed = sprite;
	v_corner = UV;

	float on = clamp(intensity, 0.0, 1.0);
	// Pulsação da chama inteira (o motor) e lambidas de cada sprite (mais na ponta).
	float pulse = noise11(TIME * 23.0 + nozzle * 7.31);
	float lick = noise11(TIME * 31.0 + sprite * 91.7 + nozzle * 3.1);
	float len_scale = intensity * heat * (0.8 + 0.2 * pulse) * (1.0 + (lick - 0.5) * 0.35 * t);
	vec3 center = VERTEX + axis_l * t * len_scale;

	float model_scale = length(MODEL_MATRIX[0].xyz);
	vec4 cv = MODELVIEW_MATRIX * vec4(center, 1.0);
	// Direção da chama na tela: os sprites esticam nela para se emendarem de lado.
	vec3 axis_v = mat3(MODELVIEW_MATRIX) * axis_l;
	float alen = length(axis_v.xy);
	vec2 dir2 = alen > 1e-5 ? axis_v.xy / alen : vec2(0.0, 1.0);
	vec2 perp2 = vec2(-dir2.y, dir2.x);

	// Perfil: a chama sai do tamanho da boca, abre um pouco e afina até a ponta.
	float r;
	if (v_core > 0.5) {
		r = radius * 0.72 * (1.0 - 0.5 * t / CORE_LEN);
	} else {
		r = radius * (1.0 + 0.9 * t) * pow(max(1.0 - t, 0.0), 0.6);
	}
	r *= model_scale * (0.85 + 0.3 * lick) * mix(0.5, 1.0, on);
	// O sprite some aos poucos até a borda: o raio visível é ~60% do quad.
	float size = r * 1.55;
	float stretch = alen * len_scale * 0.085;
	vec2 offs = dir2 * UV.y * (size + stretch) + perp2 * UV.x * size;
	// A ponta da chama balança para os lados.
	offs += perp2 * (noise11(TIME * 13.0 + nozzle * 5.3 + t * 2.7) - 0.5) * radius * model_scale * t * 2.2;
	cv.xy += offs;
	VERTEX = cv.xyz;

	if (v_core > 0.5) {
		float tc = t / CORE_LEN;
		v_alpha = 1.0 - smoothstep(0.45, 1.0, tc);
		if (v_style > 0.5 && v_style < 1.5) {
			// Jato: "diamantes" de choque, núcleos claros e escuros alternados.
			v_alpha *= mix(0.4, 1.35, 0.5 + 0.5 * cos(tc * 3.14159 * 5.0));
		}
	} else {
		v_alpha = (1.0 - smoothstep(0.5, 1.0, t)) * (0.45 + 0.55 * smoothstep(0.0, 0.15, t));
	}
	v_alpha *= clamp(intensity, 0.0, 1.6);
}

void fragment() {
	float d = length(v_corner);
	float soft = clamp(1.0 - d, 0.0, 1.0);
	soft = soft * soft * (3.0 - 2.0 * soft);
	vec3 col;
	if (v_core > 0.5) {
		col = core_color(v_style, clamp(v_t / CORE_LEN, 0.0, 1.0));
		soft *= soft;
	} else {
		col = outer_color(v_style, v_t);
		// Corpo cheio no meio do sprite, recortado em línguas de fogo por um ruído
		// que corre ao longo da chama. O miolo de cada sprite é um pouco mais quente.
		float wisp = noise21(vec2(v_corner.x * 2.6 + v_seed * 11.0, v_corner.y * 2.0 - TIME * 16.0));
		float body = 1.0 - smoothstep(0.3, 1.0, d);
		float tongue = smoothstep(0.25, 0.75, wisp * 0.8 + body * 0.5);
		soft = body * mix(0.35, 1.3, tongue);
		col *= 0.85 + 0.35 * (1.0 - d);
	}
	ALBEDO = col;
	ALPHA = clamp(soft * v_alpha * 0.5, 0.0, 1.0);
}
