shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Obstáculos que rolam pela pista (veja scripts/track_obstacles.gd). Um shader para
// os três (um só para compilar na web), escolhido por `mode`:
//   0 = fardo de feno (CylinderMesh, eixo Y): palha com espiral nas pontas e duas
//       cintas azuis da Ativos;
//   1 = bola de neve (SphereMesh de raio 1): neve irregular com brilhos e pedrinhas;
//   2 = pneu gigante (TorusMesh, eixo Y): borracha com sulcos e uma faixa amarela.
// Tudo no espaço do objeto: o desenho gira junto quando ele rola.

#include "res://shaders/noise.gdshaderinc"

uniform int mode = 0;
uniform vec3 straw_light : source_color = vec3(0.95, 0.8, 0.42);
uniform vec3 straw_dark : source_color = vec3(0.7, 0.5, 0.2);
uniform vec3 band_color : source_color = vec3(0.149, 0.239, 0.749);
uniform vec3 snow_color : source_color = vec3(0.96, 0.98, 1.0);
uniform vec3 snow_shade : source_color = vec3(0.72, 0.8, 0.95);
uniform vec3 rubber_color : source_color = vec3(0.07, 0.07, 0.08);
uniform vec3 stripe_color : source_color = vec3(1.0, 0.82, 0.1);

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
	if (mode == 0) {
		float cap = step(0.7, abs(obj_n.y));
		float r = length(obj.xz);
		float ang = atan(obj.z, obj.x);
		// Pontas: palha enrolada em espiral. Lateral: fios ao redor do fardo.
		float spiral = sin(r * 46.0 + ang * 1.0 + vnoise(obj.xz * 9.0) * 3.0) * 0.5 + 0.5;
		float strands = vnoise(vec2(ang * 24.0, obj.y * 5.0)) * 0.7 + vnoise(vec2(ang * 70.0, obj.y * 14.0)) * 0.3;
		float t = mix(strands, spiral, cap);
		col = mix(straw_dark, straw_light, smoothstep(0.2, 0.85, t));
		// Fios soltos mais claros.
		col = mix(col, straw_light * 1.08, step(0.86, vnoise(vec2(ang * 120.0, obj.y * 30.0))) * (1.0 - cap));
		float band = (1.0 - cap) * (1.0 - smoothstep(0.035, 0.06, abs(abs(obj.y) - 0.42)));
		col = mix(col, band_color, band);
		rough = mix(0.95, 0.6, band);
		spec = 0.15;
	} else if (mode == 1) {
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
