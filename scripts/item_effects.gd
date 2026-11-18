class_name ItemEffects
extends Node3D
## Efeitos 3D dos itens (a lógica fica em RaceItems):
## - Deságio: um raio cai em cada rival e um "−%" gigante aparece no céu. O "−%" é um
##   texto preso a cada câmera de jogador, alto e longe (sempre no céu da tela dele),
##   numa camada que só aquela câmera vê.
## - Juridiquês: um "§" de tinta flutua em cima de quem levou (o dono não vê o dele).
## - Cessão de crédito: o Celerino-fantasma (CessaoGhost).
## Os nós 3D mexem só em passos de física (Tween de física), por causa da interpolação.

## Camadas de desenho do "−%" de cada jogador (15 = J1 ... 18 = J4).
const SKY_LAYER := 15
## Onde o "−%" fica, no espaço da câmera (m): alto e bem à frente. A altura e o tamanho
## são acertados pelo campo de visão de cada câmera (_fit_sky_sign); estes valores
## valem para SKY_REFERENCE_FOV (vertical, um jogador parado).
const SKY_SIGN_POS := Vector3(0.0, 19.5, -58.0)
const SKY_PIXEL_SIZE := 0.135
const SKY_REFERENCE_FOV := 62.0
## Raios guardados para cair ao mesmo tempo.
const BOLTS := 8
const BOLT_HEIGHT := 42.0
const MARK_HEIGHT := 2.4

var ghost: CessaoGhost
var _signs: Array[Label3D] = []
var _bolt_meshes: Array[ArrayMesh] = []
var _bolts: Array[MeshInstance3D] = []
var _marks := {}
var _tweens := {}


## `cameras` = câmera de cada jogador (J1 primeiro).
func setup(cameras: Array[Camera3D]) -> void:
	name = "EfeitosItens"
	for i in cameras.size():
		var cam := cameras[i]
		for j in 4:
			cam.set_cull_mask_value(SKY_LAYER + j, j == i)
		var sign_label := _make_sky_sign()
		sign_label.layers = 1 << (SKY_LAYER + i - 1)
		cam.add_child(sign_label)
		_signs.append(sign_label)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Mistura normal (somar luz some no céu claro do dia).
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 3:
		_bolt_meshes.append(_make_bolt_mesh(mat))
	for i in BOLTS:
		var bolt := MeshInstance3D.new()
		bolt.name = "Raio%d" % i
		bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt.visible = false
		add_child(bolt)
		_bolts.append(bolt)
	ghost = CessaoGhost.new()
	add_child(ghost)
	ghost.build()


# --- Deságio ---------------------------------------------------------------------

## O "−%" gigante no céu de todos os jogadores.
func sky_sign() -> void:
	for label in _signs:
		_kill_tween(label)
		_fit_sky_sign(label)
		label.visible = true
		label.scale = Vector3.ONE * 0.2
		label.modulate = Color.WHITE
		label.outline_modulate = UiKit.NAVY
		var tw := _tween(label)
		tw.tween_property(label, "scale", Vector3.ONE * 1.12, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(label, "scale", Vector3.ONE, 0.12)
		# Pisca com os relâmpagos (branco ↔ amarelo).
		for i in 3:
			tw.tween_property(label, "modulate", RaceItem.BOLT, 0.07)
			tw.tween_property(label, "modulate", Color.WHITE, 0.07)
		tw.tween_property(label, "modulate", RaceItem.BOLT, 0.1)
		tw.tween_interval(1.1)
		tw.tween_property(label, "position:y", label.position.y + 6.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
		tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.5)
		tw.tween_callback(label.hide)


## Um raio cai em cima do kart.
func strike(k: Kart) -> void:
	for bolt in _bolts:
		if bolt.visible:
			continue
		bolt.mesh = _bolt_meshes.pick_random()
		bolt.global_position = k.global_position
		bolt.reset_physics_interpolation()
		bolt.visible = true
		var tw := _tween(bolt)
		# Cai, apaga um instante e volta (o pisca do relâmpago).
		tw.tween_interval(0.14)
		tw.tween_callback(bolt.hide)
		tw.tween_interval(0.05)
		tw.tween_callback(bolt.show)
		tw.tween_interval(0.26)
		tw.tween_callback(bolt.hide)
		return


## Põe o "−%" no alto da tela da câmera dele com o mesmo tamanho na tela em qualquer
## enquadramento (a tela dividida em 2 é larga e baixa: o céu visível é bem menor).
func _fit_sky_sign(label: Label3D) -> void:
	var cam := label.get_parent() as Camera3D
	var tan_v := tan(deg_to_rad(SKY_REFERENCE_FOV * 0.5))
	if cam:
		var vp := cam.get_viewport().get_visible_rect().size
		var aspect := vp.x / maxf(vp.y, 1.0)
		var half := tan(deg_to_rad(cam.fov * 0.5))
		tan_v = half if cam.keep_aspect == Camera3D.KEEP_HEIGHT else half / aspect
	var depth := -SKY_SIGN_POS.z
	# Centro a 55% da metade de cima da tela.
	label.position = Vector3(0.0, depth * tan_v * 0.55, -depth)
	label.pixel_size = SKY_PIXEL_SIZE * tan_v / tan(deg_to_rad(SKY_REFERENCE_FOV * 0.5))


func _make_sky_sign() -> Label3D:
	var label := Label3D.new()
	label.name = "Desagio"
	label.text = "−%"
	label.font = UiKit.FONT_ITALIC
	label.font_size = 180
	label.outline_size = 34
	label.pixel_size = SKY_PIXEL_SIZE
	label.modulate = RaceItem.BOLT
	label.outline_modulate = UiKit.NAVY
	label.no_depth_test = true
	label.shaded = false
	label.double_sided = true
	label.render_priority = 2
	label.outline_render_priority = 1
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = SKY_SIGN_POS
	label.visible = false
	return label


## Raio em zigue-zague do céu até o chão: uma fita amarela por fora e uma clara e fina
## no meio, sempre de frente para a câmera (billboard no eixo vertical).
func _make_bolt_mesh(mat: Material) -> ArrayMesh:
	var path := PackedVector3Array()
	var steps := 9
	var swing := 1.0 if randf() < 0.5 else -1.0
	for i in steps + 1:
		var y := BOLT_HEIGHT * (1.0 - float(i) / steps)
		var x := 0.0
		if i > 0 and i < steps:
			swing = -swing
			x = swing * randf_range(1.0, 2.6)
		path.append(Vector3(x, y, 0.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer: Array in [[1.25, Color(1.0, 0.82, 0.12, 0.85)], [0.4, Color(1.0, 0.98, 0.78, 1.0)]]:
		var half: float = layer[0] * 0.5
		var color: Color = layer[1]
		for i in steps:
			var a := path[i]
			var b := path[i + 1]
			var side := Vector3(-(b - a).y, (b - a).x, 0.0).normalized() * half
			# A ponta de baixo afina (encosta no kart).
			var tip := 0.35 if i == steps - 1 else 1.0
			for v: Vector3 in [a - side, a + side, b + side * tip, a - side, b + side * tip, b - side * tip]:
				st.set_color(color)
				st.add_vertex(v)
	st.set_material(mat)
	var mesh := st.commit()
	mesh.custom_aabb = AABB(Vector3(-4.0, 0.0, -4.0), Vector3(8.0, BOLT_HEIGHT + 1.0, 8.0))
	return mesh


# --- Juridiquês --------------------------------------------------------------------

## "§" de tinta flutuando em cima do kart por `duration` s. `layers` = camadas de
## desenho (a do jogador dono do kart fica de fora da câmera dele).
func ink_mark(k: Kart, duration: float, layers := 1) -> void:
	var label: Label3D = _marks.get(k)
	if label == null or not is_instance_valid(label):
		label = Label3D.new()
		label.name = "Tinta"
		label.text = "§"
		label.font = UiKit.FONT_TITLE
		label.font_size = 110
		label.outline_size = 22
		label.pixel_size = 0.011
		label.modulate = RaceItem.INK_BLOB
		label.outline_modulate = Color.WHITE
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.shaded = false
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		k.add_child(label)
		_marks[k] = label
	label.layers = layers
	label.visible = true
	label.position = Vector3(0.0, MARK_HEIGHT, 0.0)
	label.scale = Vector3.ONE * 0.2
	label.modulate.a = 1.0
	label.outline_modulate.a = 1.0
	label.reset_physics_interpolation()
	var tw := _tween(label)
	tw.tween_property(label, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bobs := maxi(int((duration - 0.6) / 0.3), 1)
	for i in bobs:
		tw.tween_property(label, "position:y", MARK_HEIGHT + (0.18 if i % 2 == 0 else 0.0), 0.3) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.35)
	tw.tween_callback(label.hide)


# --- Compilar shaders -----------------------------------------------------------------

## Liga todos os efeitos perto de `near` (e o fantasma em `ghost_xf`) por uns quadros,
## atrás da tela de carregamento (Race.warm_up), para os shaders compilarem antes.
func prewarm(on: bool, near: Kart = null, ghost_xf := Transform3D.IDENTITY) -> void:
	for label in _signs:
		_kill_tween(label)
		label.visible = on
		if on:
			label.position = SKY_SIGN_POS
			label.scale = Vector3.ONE
			label.modulate = RaceItem.BOLT
			label.outline_modulate = UiKit.NAVY
	if not _bolts.is_empty():
		_kill_tween(_bolts[0])
		_bolts[0].visible = on and near != null
		if on and near:
			_bolts[0].mesh = _bolt_meshes[0]
			_bolts[0].global_position = near.global_position + near.get_forward() * 8.0
	if near:
		if on:
			ink_mark(near, 0.1)
			_kill_tween(_marks[near])
			_marks[near].scale = Vector3.ONE
		elif _marks.has(near):
			_kill_tween(_marks[near])
			_marks[near].hide()
	if ghost:
		ghost.prewarm(on, ghost_xf)


func _tween(node: Node) -> Tween:
	_kill_tween(node)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tweens[node] = tw
	return tw


func _kill_tween(node: Node) -> void:
	var tw: Tween = _tweens.get(node)
	if tw:
		tw.kill()
		_tweens.erase(node)
