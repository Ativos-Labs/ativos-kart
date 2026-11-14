class_name SplitScreen
extends CanvasLayer
## Tela dividida do multijogador local: uma SubViewport por jogador, todas vendo o
## mesmo mundo 3D (cada uma com a sua câmera e o seu HUD dentro dela).
## 2 jogadores: uma tela em cima da outra. 3 ou 4: quatro quadrantes (com 3, o
## quarto fica livre para o mapa da pista).
##
## Cada SubViewport renderiza no tamanho real em pixels do pedaço da janela que ela
## ocupa (nítida em qualquer resolução) e o HUD dentro dela é desenhado numa altura
## virtual de HUD_HEIGHT, igual para todos os formatos.

## Altura virtual (unidades de interface) do HUD de cada jogador.
const HUD_HEIGHT := 520.0
## Espessura das divisórias (unidades de interface).
const DIVIDER := 4.0
const DIVIDER_COLOR := Color(0.04, 0.06, 0.16)

var count := 0
var viewports: Array[SubViewport] = []
var _views: Array[TextureRect] = []
var _root: Control


func setup(p_count: int) -> void:
	count = clampi(p_count, 1, 4)
	layer = -1
	_root = Control.new()
	_root.name = "Telas"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = DIVIDER_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var main := get_viewport()
	for i in count:
		var vp := SubViewport.new()
		vp.name = "TelaJ%d" % (i + 1)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		# Cada tela ouve o som 3D da posição da câmera dela.
		vp.audio_listener_enable_3d = true
		vp.msaa_3d = main.msaa_3d
		vp.screen_space_aa = main.screen_space_aa
		vp.use_taa = main.use_taa
		vp.use_debanding = main.use_debanding
		vp.scaling_3d_mode = main.scaling_3d_mode
		vp.scaling_3d_scale = main.scaling_3d_scale
		# Na web a resolução do 3D muda com o desempenho (RenderScale).
		vp.add_to_group(RenderScale.GROUP)
		vp.anisotropic_filtering_level = main.anisotropic_filtering_level
		vp.mesh_lod_threshold = main.mesh_lod_threshold
		vp.size_2d_override_stretch = true
		add_child(vp)
		viewports.append(vp)
		var view := TextureRect.new()
		view.name = "VistaJ%d" % (i + 1)
		view.texture = vp.get_texture()
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_SCALE
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(view)
		_views.append(view)
	main.size_changed.connect(_layout)
	_layout()


## Pedaço da tela (unidades de interface) do jogador `i` (ou do quadrante livre, com
## i = 3 e 3 jogadores).
func rect_for(i: int) -> Rect2:
	var full := get_viewport().get_visible_rect()
	var half := full.size * 0.5
	if count == 1:
		return full
	if count == 2:
		return Rect2(full.position + Vector2(0.0, half.y * i), Vector2(full.size.x, half.y))
	return Rect2(full.position + Vector2(half.x * (i % 2), half.y * (i / 2)), half)


## Quadrante sem jogador (só com 3 jogadores).
func free_rect() -> Rect2:
	return rect_for(3) if count == 3 else Rect2()


## Formato (largura / altura) da tela de cada jogador.
func aspect() -> float:
	var r := rect_for(0)
	return r.size.x / maxf(r.size.y, 1.0)


func _layout() -> void:
	var full := get_viewport().get_visible_rect()
	var window := get_window()
	var px := Vector2(window.size) / full.size if window and full.size.x > 0.0 else Vector2.ONE
	for i in count:
		var r := _inset(rect_for(i), i)
		var view := _views[i]
		view.position = r.position
		view.size = r.size
		var vp := viewports[i]
		vp.size = Vector2i(maxi(int(round(r.size.x * px.x)), 16), maxi(int(round(r.size.y * px.y)), 16))
		vp.size_2d_override = Vector2i(roundi(r.size.x * HUD_HEIGHT / r.size.y), int(HUD_HEIGHT))


## Tira meia divisória de cada lado que encosta em outra tela.
func _inset(r: Rect2, i: int) -> Rect2:
	var d := DIVIDER * 0.5
	var full := get_viewport().get_visible_rect()
	var left := r.position.x > full.position.x + 0.5
	var top := r.position.y > full.position.y + 0.5
	var right := r.end.x < full.end.x - 0.5
	var bottom := r.end.y < full.end.y - 0.5
	if count == 3 and i == 2:
		right = true
	return Rect2(r.position + Vector2(d if left else 0.0, d if top else 0.0),
			r.size - Vector2((d if left else 0.0) + (d if right else 0.0), (d if top else 0.0) + (d if bottom else 0.0)))
