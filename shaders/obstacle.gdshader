shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Obstáculos que rolam pela pista (veja scripts/track_obstacles.gd). Um shader para
// os três (um só para compilar na web), escolhido por `mode`:
//   1 = bola de neve (SphereMesh de raio 1): neve irregular com brilhos e pedrinhas;
//   2 = pneu gigante (TorusMesh, eixo Y): borracha com sulcos e uma faixa amarela;
//   3 = tambor de coluna de templo (CylinderMesh, eixo Y): arenito com caneluras, faixas
//       de lápis-lazúli e ouro e marcas entalhadas e pintadas.
// Tudo no espaço do objeto: o desenho gira junto quando ele rola.

#include "res://shaders/noise.gdshaderinc"

uniform int mode = 2;
uniform vec3 snow_color : source_color = vec3(0.96, 0.98, 1.0);
uniform vec3 snow_shade : source_color = vec3(0.72, 0.8, 0.95);
uniform vec3 rubber_color : source_color = vec3(0.07, 0.07, 0.08);
uniform vec3 stripe_color : source_color = vec3(1.0, 0.82, 0.1);
uniform vec3 stone_light : source_color = vec3(0.87, 0.7, 0.47);
uniform vec3 stone_dark : source_color = vec3(0.66, 0.48, 0.31);
uniform vec3 lapis_color : source_color = vec3(0.11, 0.22, 0.62);

varying vec3 obj;
varying vec3 obj_n;

void vertex() {
	if (mode == 1) {
		// Bola de neve um pouco irregular (montes de neve grudada).
		float lump = vnoise(VERTEX.xy * 2.3 + VERTEX.z * 1.7) * 0.6 + vnoise(VERTEX.zx * 4.1) * 0.4;
		VERTEX += NORMAL * (lump - 0.5) * 0.12;
	}
	obj = VERTEX;
	obj_n = NORMAL;
}

void fragment() {
	vec3 col;
	float rough = 0.9;
	float spec = 0.3;
	if (mode == 1) {
		float n = fbm(obj.xy * 3.0 + obj.z * 2.0, 3);
		col = mix(snow_shade, snow_color, smoothstep(0.25, 0.75, n));
		// Pedrinhas e gravetos presos na neve.
		float speck = step(0.93, vnoise(obj.yz * 11.0 + obj.x * 5.0));
		col = mix(col, vec3(0.28, 0.25, 0.24), speck * 0.85);
		rough = 0.75;
		spec = 0.45;
		// Brilhinhos de gelo.
		float glint = step(0.985, hash12(floor(obj.xz * 60.0 + obj.y * 37.0)));
		EMISSION = vec3(0.5, 0.6, 0.7) * glint * 0.8;
	} else if (mode == 3) {
		float cap = step(0.7, abs(obj_n.y));
		float r = length(obj.xz);
		float ang = atan(obj.z, obj.x);
		float n = vnoise(vec2(ang * 5.0, obj.y * 3.0)) * 0.6 + vnoise(obj.xz * 6.0 + obj.y * 4.0) * 0.4;
		col = mix(stone_dark, stone_light, 0.35 + 0.55 * n);
		// Caneluras (sulcos em volta) e, nas pontas, o anel do encaixe dos tambores.
		float flute = smoothstep(0.75, 1.0, sin(ang * 16.0) * 0.5 + 0.5) * (1.0 - cap);
		col *= 1.0 - flute * 0.18;
		col = mix(col, stone_dark * 0.75, cap * (1.0 - smoothstep(0.02, 0.05, abs(r - 0.55))));
		// Faixas pintadas perto das pontas.
		float y = abs(obj.y);
		float lap = (1.0 - cap) * step(0.6, y) * step(y, 0.74);
		float gold = (1.0 - cap) * step(0.78, y) * step(y, 0.86);
		col = mix(col, lapis_color, lap * 0.9);
		col = mix(col, stripe_color * 0.95, gold * 0.9);
		// Marcas entalhadas e pintadas no meio (como hieróglifos de longe).
		vec2 g = vec2(ang * 12.0 / 6.2831, obj.y * 3.2);
		vec2 gc = floor(g);
		vec2 gf = fract(g);
		float h = hash12(gc + 4.0);
		float mark = (1.0 - cap) * step(y, 0.5) * step(0.35, h)
				* step(0.25, gf.x) * step(gf.x, 0.75) * step(0.2, gf.y) * step(gf.y, 0.8)
				* step(0.5, fract(gf.x * 3.0 + gf.y * 2.0 * h));
		vec3 paint = h < 0.55 ? lapis_color : (h < 0.75 ? vec3(0.66, 0.2, 0.1) : stripe_color);
		col = mix(col, mix(col * 0.6, paint, 0.5), mark);
		rough = 0.9;
		spec = 0.2;
	} else {
		float ang = atan(obj.z, obj.x);
		float r = length(obj.xz);
		// Banda de rodagem: sulcos em "V" na parte de fora.
		float outer = smoothstep(0.88, 0.98, r);
		float tread = step(0.5, fract(ang * 9.0 + abs(obj.y) * 1.6));
		col = rubber_color * mix(1.0, mix(0.55, 1.25, tread), outer);
		// Faixa amarela no flanco (dos dois lados).
		float stripe = (1.0 - outer) * (1.0 - smoothstep(0.02, 0.035, abs(r - 0.78))) * step(0.2, abs(obj_n.y));
		col = mix(col, stripe_color, stripe);
		rough = mix(0.8, 0.5, stripe);
		spec = 0.25;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
