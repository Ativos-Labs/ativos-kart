shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Tubos e faixas de neon (cidade neon, track_city.gd e track_stadium.gd): cor de vértice
// (sRGB) acesa acima de 1, para o brilho (glow) da tela espalhar a luz em volta.

#include "res://shaders/noise.gdshaderinc"

uniform float energy = 3.0;

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb) * energy;
}
