shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Piloto com textura (atlas) numa superfície só (veja scripts/character_mesh.gd).
// Como character.gdshader, mais a textura: cor final = textura * CUSTOM0.rgb (as partes
// de cor lisa usam um ponto branco do atlas). A transparência da textura recorta (logos).
//
// Recoloração (jogador repetindo o personagem): só os pontos com matiz parecida com a de
// referência (o azul do macacão) trocam de matiz; pele, cabelo e branco ficam.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool tint_enabled = false;
uniform float tint_hue = 0.0;
uniform float tint_saturation_ratio = 1.0;
uniform float tint_value_ratio = 1.0;
// Matiz de referência (0 a 1) e quanto pode se afastar dela e ainda recolorir.
uniform float tint_reference_hue = 0.65;
uniform float tint_hue_range = 0.09;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.5;

varying vec3 color_value;
varying float roughness_value;
varying float tintable_value;

#include "res://shaders/character_common.gdshaderinc"

void vertex() {
	color_value = CUSTOM0.rgb;
	tintable_value = step(1.5, CUSTOM0.a);
	roughness_value = CUSTOM0.a - tintable_value * 2.0;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	// As contas de cor são em sRGB, como a cor do vértice. O Compatibility (web) usa as
	// cores como estão, igual ao StandardMaterial3D (veja character.gdshader).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 c = tex.rgb * color_value;
#else
	vec3 c = linear_to_srgb(tex.rgb) * color_value;
#endif
	if (tint_enabled && tintable_value > 0.5) {
		vec3 hsv = rgb_to_hsv(c);
		float dh = abs(fract(hsv.x - tint_reference_hue + 0.5) - 0.5);
		float w = (1.0 - smoothstep(tint_hue_range * 0.6, tint_hue_range, dh)) * smoothstep(0.12, 0.25, hsv.y);
		vec3 t = hsv_to_rgb(vec3(tint_hue, clamp(hsv.y * tint_saturation_ratio, 0.0, 1.0),
				clamp(hsv.z * tint_value_ratio, 0.0, 1.0)));
		c = mix(c, t, w);
	}
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = c;
#else
	ALBEDO = srgb_to_linear(c);
#endif
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
}
