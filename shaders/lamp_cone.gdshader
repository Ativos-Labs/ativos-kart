shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Facho de luz dos postes da cidade neon (TrackCity._build_lamps): cone aberto da
// luminária até o chão, com UV.y = 0 na luminária e 1 no chão e a cor no vértice (sRGB).
// Some perto da luminária (a ponta não fica dura), apaga até o chão (sem linha onde o
// cone corta o asfalto) e fica mais forte nas bordas do cone, como luz em neblina.
// A névoa somaria a cor dela no aditivo: `fog_disabled`.

#include "res://shaders/noise.gdshaderinc"

uniform float intensity = 0.2;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	// Meio do cone (de frente) mais fraco, bordas (de raspão) mais fortes: parece volume.
	float rim = mix(1.0, 0.45, facing * facing);
	float fade = smoothstep(0.0, 0.12, along) * pow(1.0 - along, 1.8);
	ALBEDO = srgb_to_linear(COLOR.rgb) * intensity * fade * rim;
}
