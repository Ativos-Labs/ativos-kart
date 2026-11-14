shader_type spatial;
render_mode blend_mix, cull_front, depth_draw_never, diffuse_burley, specular_schlick_ggx;
// Caixa de item, faces do fundo vistas através do vidro. Desenhada antes das faces
// da frente (item_box.gdshader) — veja item_box.gdshaderinc.

#define INNER
#include "res://shaders/item_box.gdshaderinc"
