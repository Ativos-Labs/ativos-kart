shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Caixa de item, faces da frente (o vidro de fora). Desenhada depois de
// item_box_inner.gdshader (render_priority maior) — veja item_box.gdshaderinc.

#include "res://shaders/item_box.gdshaderinc"
