shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Piloto com todas as partes numa superfície só (veja scripts/character_mesh.gd).
// Imita os StandardMaterial3D de cor lisa do modelo: CUSTOM0.rgb = cor (sRGB) e
// CUSTOM0.a = rugosidade, + 2 nas partes que a cor do adversário recolore (mesma conta
// de antes: matiz da cor nova, saturação e brilho proporcionais).

uniform bool tint_enabled = false;
uniform float tint_hue = 0.0;
uniform float tint_saturation_ratio = 1.0;
uniform float tint_value_ratio = 1.0;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.5;

varying vec3 albedo_value;
varying float roughness_value;

#include "res://shaders/character_common.gdshaderinc"

void vertex() {
	vec3 c = CUSTOM0.rgb;
	float tintable = step(1.5, CUSTOM0.a);
	if (tint_enabled && tintable > 0.5) {
		vec3 hsv = rgb_to_hsv(c);
		c = hsv_to_rgb(vec3(tint_hue, clamp(hsv.y * tint_saturation_ratio, 0.0, 1.0),
				clamp(hsv.z * tint_value_ratio, 0.0, 1.0)));
	}
	// O StandardMaterial3D converte a cor (sRGB) para linear no Forward+/Mobile; no
	// Compatibility (web, OpenGL) ele usa a cor como está (medido: com a conversão o
	// piloto ficava bem mais escuro que o original no navegador).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	albedo_value = c;
#else
	albedo_value = srgb_to_linear(c);
#endif
	roughness_value = CUSTOM0.a - tintable * 2.0;
}

void fragment() {
	ALBEDO = albedo_value;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
}
