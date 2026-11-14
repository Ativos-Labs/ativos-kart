// Funções de ruído compartilhadas pelos shaders da pista.
// Hash sem seno (Dave Hoskins): estável mesmo com coordenadas grandes.

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Ruído de valor suave, de 0 a 1.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Soma de oitavas (0 a 1).
float fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += vnoise(p) * amp;
		norm += amp;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(5.3, 1.7);
		amp *= 0.5;
	}
	return sum / norm;
}

// Ruído de valor com derivadas analíticas: (valor, d/dx, d/dy).
// Dá o relevo (normal) sem precisar avaliar o ruído de novo em pontos vizinhos.
vec3 vnoise_d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	float k1 = b - a;
	float k2 = c - a;
	float k4 = a - b - c + d;
	return vec3(a + k1 * u.x + k2 * u.y + k4 * u.x * u.y,
			du * vec2(k1 + k4 * u.y, k2 + k4 * u.x));
}

// fbm (igual ao de cima) com o gradiente em relação a `p`: (valor, d/dx, d/dy).
vec3 fbm_d(vec2 p, int octaves) {
	float sum = 0.0;
	vec2 grad = vec2(0.0);
	float amp = 0.5;
	float norm = 0.0;
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	mat2 jac = mat2(1.0);
	for (int i = 0; i < octaves; i++) {
		vec3 n = vnoise_d(p);
		sum += n.x * amp;
		grad += (n.yz * jac) * amp;
		norm += amp;
		p = m * p + vec2(5.3, 1.7);
		jac = m * jac;
		amp *= 0.5;
	}
	return vec3(sum, grad) / norm;
}

// Cor sRGB (ex.: Color.from_hsv / cor de instância do MultiMesh) para linear.
// COLOR de malha e de MultiMesh chega ao shader sem conversão.
vec3 srgb_to_linear(vec3 c) {
	return mix(c * (1.0 / 12.92), pow((c + 0.055) * (1.0 / 1.055), vec3(2.4)), step(0.04045, c));
}
