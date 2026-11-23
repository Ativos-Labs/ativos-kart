extends SceneTree
## Gera o ícone da tela de carregamento: o Celerino no kart padrão visto de lado, em
## silhueta branca (alfa da renderização, cor branca), indo para a direita.
##
##   godot --path . -s res://tools/loading/render_icone.gd
##
## Grava res://assets/ui/carregando_celerino.png. Precisa de janela (não --headless).

const OUT := "res://assets/ui/carregando_celerino.png"
const SIZE := Vector2i(512, 512)

var _f := 0
var _vp: SubViewport
var _kv: KartVisual


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_build()
	elif _f > 2 and _f < 40:
		_kv.update_motion(1.0 / 30.0, 0.0, 0.0)
	elif _f == 40:
		_save()
		return true
	return false


func _build() -> void:
	var gs: Node = root.get_node("GameState")
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_kv = KartVisual.new()
	_vp.add_child(_kv)
	_kv.setup(gs.karts[0], load("res://data/personagens/celerino.tres"))
	# Enquadra pelo AABB do conjunto, câmera ortográfica do lado direito, um pouco à frente (o Celerino é uma folha: de lado puro vira um risco)
	# (frente = -Z do kart aparece para a direita na tela).
	var box := _aabb(_kv)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = box.get_longest_axis_size() * 1.1
	_vp.add_child(cam)
	var c := box.get_center()
	cam.look_at_from_position(c + Vector3(10.0, 0.4, -1.2), c, Vector3.UP)
	var light := DirectionalLight3D.new()
	_vp.add_child(light)


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m: Node in n.find_children("*", "VisualInstance3D", true, false):
		var vi := m as VisualInstance3D
		var b: AABB = vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _save() -> void:
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	img = img.get_region(used.grow(4).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, Color(1, 1, 1, img.get_pixel(x, y).a))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	img.save_png(OUT)
	print("salvo ", OUT, " ", img.get_size())
