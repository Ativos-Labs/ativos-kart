class_name ItemEffects
extends Node3D
## Efeitos 3D dos itens (a lógica fica em RaceItems):
## - Deságio: um raio cai em cada rival e um "deságio" vermelho gigante, com um "−%"
##   amarelo pequeno embaixo, aparece no céu. São textos presos a cada câmera de jogador,
##   altos e longe (sempre no céu da tela dele), numa camada que só aquela câmera vê.
## - Juridiquês: um "§" de tinta flutua em cima de quem levou (o dono não vê o dele).
## - Cessão de crédito: o Celerino-fantasma (CessaoGhost).
## - RPV: a guia verde que vira foguete embaixo do kart (RpvRocket, um por kart).
## - Antecipação Celer: o Celerino com a maleta de notas (AntecipacaoCeler).
## - Superpreferência: o ofício gigante com o carimbo PRIORIDADE (OficioSuper).
## - Correção monetária: moedas com "%" caindo dentro do kart (chuva de moedas).
## - Trânsito em julgado: aura dourada e o martelo de juiz girando (TransitoJulgado, um
##   por kart).
## Os nós 3D mexem só em passos de física (Tween de física), por causa da interpolação.

## Camadas de desenho do "deságio" de cada jogador (15 = J1 ... 18 = J4).
const SKY_LAYER := 15
## Onde o "deságio" fica, no espaço da câmera (m): alto e bem à frente. A altura e o tamanho
## são acertados pelo campo de visão de cada câmera (_fit_sky_sign); estes valores
## valem para SKY_REFERENCE_FOV (vertical, um jogador parado).
const SKY_SIGN_POS := Vector3(0.0, 19.5, -58.0)
const SKY_PIXEL_SIZE := 0.135
const SKY_REFERENCE_FOV := 62.0
## Largura máxima do "deságio" do céu (fração da largura da tela de cada jogador) e o
## tamanho do "−%" embaixo dele (fração da fonte do "deságio").
const SKY_MAX_WIDTH := 0.5
const SKY_MINUS_SIZE := 0.45
## Raios guardados para cair ao mesmo tempo.
const BOLTS := 8
const BOLT_HEIGHT := 42.0
const MARK_HEIGHT := 2.4 * KartScale.ITEMS
## Correção monetária: moedas da chuva (quantas podem cair juntas), tamanho, altura de
## onde caem (m, acima do kart) e intervalo entre elas (s).
const SHOWER_COINS := 6
const SHOWER_SCALE := 0.5 * KartScale.ITEMS
const SHOWER_HEIGHT := 1.85 * KartScale.ITEMS
const SHOWER_GAP := 0.16

var ghost: CessaoGhost
var celer: AntecipacaoCeler
var oficio: OficioSuper
## Foguete da RPV de cada kart (criado na primeira RPV dele).
var _rockets := {}
## Aura do Trânsito em julgado de cada kart (criada na primeira vez).
var _judged := {}
var _shower: Array[MeshInstance3D] = []
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
		_minus_of(sign_label).layers = sign_label.layers
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
	celer = AntecipacaoCeler.new()
	add_child(celer)
	celer.build(self)
	oficio = OficioSuper.new()
	add_child(oficio)
	oficio.build(self)
	var coin_mat := TrackCoins.coin_material().duplicate() as ShaderMaterial
	coin_mat.set_shader_parameter("spin_speed", 6.0)
	coin_mat.set_shader_parameter("bob_height", 0.0)
	coin_mat.set_shader_parameter("glow", 0.4)
	for i in SHOWER_COINS:
		var coin := MeshInstance3D.new()
		coin.name = "MoedaCorrecao%d" % i
		coin.mesh = TrackCoins.coin_mesh()
		coin.material_override = coin_mat
		coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		coin.visible = false
		add_child(coin)
		_shower.append(coin)


# --- Deságio ---------------------------------------------------------------------

## O "deságio" gigante (e o "−%" embaixo) no céu de todos os jogadores.
func sky_sign() -> void:
	for label in _signs:
		_kill_tween(label)
		_fit_sky_sign(label)
		var minus := _minus_of(label)
		label.visible = true
		label.scale = Vector3.ONE * 0.2
		label.modulate = RaceItem.BADGE
		label.outline_modulate = UiKit.NAVY
		minus.modulate = RaceItem.BOLT
		minus.outline_modulate = UiKit.NAVY
		var tw := _tween(label)
		tw.tween_property(label, "scale", Vector3.ONE * 1.12, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(label, "scale", Vector3.ONE, 0.12)
		# Vermelho, com três piscadas brancas junto com os relâmpagos.
		for i in 3:
			tw.tween_property(label, "modulate", Color.WHITE, 0.05)
			tw.tween_property(label, "modulate", RaceItem.BADGE, 0.09)
		tw.tween_interval(1.2)
		tw.tween_property(label, "position:y", label.position.y + 6.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for node: Label3D in [label, minus]:
			tw.parallel().tween_property(node, "modulate:a", 0.0, 0.5)
			tw.parallel().tween_property(node, "outline_modulate:a", 0.0, 0.5)
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


## Põe o "deságio" no alto da tela da câmera dele com o mesmo tamanho na tela em qualquer
## enquadramento (a tela dividida em 2 é larga e baixa: o céu visível é bem menor).
func _fit_sky_sign(label: Label3D) -> void:
	var cam := label.get_parent() as Camera3D
	var tan_v := tan(deg_to_rad(SKY_REFERENCE_FOV * 0.5))
	var aspect := 16.0 / 9.0
	if cam:
		var vp := cam.get_viewport().get_visible_rect().size
		aspect = vp.x / maxf(vp.y, 1.0)
		var half := tan(deg_to_rad(cam.fov * 0.5))
		tan_v = half if cam.keep_aspect == Camera3D.KEEP_HEIGHT else half / aspect
	var depth := -SKY_SIGN_POS.z
	var px := SKY_PIXEL_SIZE * tan_v / tan(deg_to_rad(SKY_REFERENCE_FOV * 0.5))
	# O "deságio" é comprido: no máximo SKY_MAX_WIDTH da largura da tela.
	var font := label.font
	var text_w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x \
			+ label.outline_size * 2.0
	px = minf(px, SKY_MAX_WIDTH * 2.0 * depth * tan_v * aspect / text_w)
	label.pixel_size = px
	# O "−%" logo embaixo (encostando no espaço vazio abaixo da palavra).
	var minus := _minus_of(label)
	minus.pixel_size = px
	var word_h := font.get_height(label.font_size)
	var minus_h := font.get_height(minus.font_size)
	var overlap := font.get_descent(label.font_size) * 0.4
	minus.position = Vector3(0.0, -(word_h + minus_h) * 0.5 * px + overlap * px, 0.0)
	# Centro do conjunto a 55% da metade de cima da tela.
	var lift := (minus_h - overlap) * 0.5 * px
	label.position = Vector3(0.0, depth * tan_v * 0.55 + lift, -depth)


func _make_sky_sign() -> Label3D:
	var label := Label3D.new()
	label.name = "Desagio"
	label.text = RaceItem.DESAGIO_TEXT
	label.font = UiKit.FONT_ITALIC
	label.font_size = 180
	label.outline_size = 34
	label.pixel_size = SKY_PIXEL_SIZE
	label.modulate = RaceItem.BADGE
	label.outline_modulate = UiKit.NAVY
	label.no_depth_test = true
	label.shaded = false
	label.double_sided = true
	label.render_priority = 2
	label.outline_render_priority = 1
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = SKY_SIGN_POS
	label.visible = false
	# O "−%" pequeno, filho da palavra (pula, sobe e some junto); _fit_sky_sign o põe embaixo.
	var minus := Label3D.new()
	minus.name = "Menos"
	minus.text = RaceItem.DESAGIO_MINUS
	minus.font = label.font
	minus.font_size = int(label.font_size * SKY_MINUS_SIZE)
	minus.outline_size = int(label.outline_size * 0.6)
	minus.modulate = RaceItem.BOLT
	minus.outline_modulate = UiKit.NAVY
	for prop in [&"pixel_size", &"no_depth_test", &"shaded", &"double_sided", &"render_priority",
			&"outline_render_priority", &"cast_shadow"]:
		minus.set(prop, label.get(prop))
	minus.position = Vector3(0.0, -18.0, 0.0)
	label.add_child(minus)
	return label


## O "−%" embaixo do "deságio" do céu.
func _minus_of(label: Label3D) -> Label3D:
	return label.get_child(0) as Label3D


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
		label.pixel_size = 0.011 * KartScale.CAMERA
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
		tw.tween_property(label, "position:y", MARK_HEIGHT + (0.18 * KartScale.ITEMS if i % 2 == 0 else 0.0), 0.3) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.35)
	tw.tween_callback(label.hide)


# --- Velocidade ---------------------------------------------------------------------

## RPV: a guia vira foguete embaixo de `k` por `duration` s.
func rpv(k: Kart, duration: float) -> void:
	_rocket_of(k).play(duration)


func _rocket_of(k: Kart) -> RpvRocket:
	var rocket: RpvRocket = _rockets.get(k)
	if rocket == null or not is_instance_valid(rocket):
		rocket = RpvRocket.new()
		k.add_child(rocket)
		rocket.build(k)
		_rockets[k] = rocket
	return rocket


## Trânsito em julgado: a aura e o martelo em volta de `k` (somem sozinhos quando o
## Kart.judged_time acaba).
func julgado(k: Kart) -> void:
	_judged_of(k).play()


func _judged_of(k: Kart) -> TransitoJulgado:
	var fx: TransitoJulgado = _judged.get(k)
	if fx == null or not is_instance_valid(fx):
		fx = TransitoJulgado.new()
		k.add_child(fx)
		fx.build(k)
		_judged[k] = fx
	return fx


## Correção monetária: `count` moedas com "%" aparecem em cima de `k` e caem dentro dele,
## uma depois da outra; `on_coin` é chamado quando cada uma entra.
func coin_shower(k: Kart, count: int, on_coin: Callable) -> void:
	var used := 0
	for coin in _shower:
		if used >= count:
			break
		if coin.visible:
			continue
		var delay := used * SHOWER_GAP
		var side := (used - (count - 1) * 0.5) * 0.7 * KartScale.ITEMS
		used += 1
		if coin.get_parent() != k:
			coin.get_parent().remove_child(coin)
			k.add_child(coin)
		coin.position = Vector3(side, SHOWER_HEIGHT, 0.3 * KartScale.ITEMS)
		coin.scale = Vector3.ONE * 0.01
		coin.visible = true
		coin.reset_physics_interpolation()
		var tw := _tween(coin)
		tw.tween_property(coin, "scale", Vector3.ONE * SHOWER_SCALE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.12 + delay)
		tw.tween_property(coin, "position", Vector3(0.0, 0.7 * KartScale.ITEMS, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(coin, "scale", Vector3.ONE * SHOWER_SCALE * 0.4, 0.22)
		tw.tween_callback(_coin_landed.bind(coin, on_coin))
	# Sem moeda livre na chuva (muitas juntas): as que faltam entram direto.
	for i in count - used:
		on_coin.call()


func _coin_landed(coin: MeshInstance3D, on_coin: Callable) -> void:
	coin.visible = false
	if coin.get_parent() != self:
		coin.get_parent().remove_child(coin)
		add_child(coin)
	on_coin.call()


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
			label.modulate = RaceItem.BADGE
			label.outline_modulate = UiKit.NAVY
			_minus_of(label).modulate = RaceItem.BOLT
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
	# Antecipação ao lado do fantasma, o ofício e a chuva de moedas na frente do kart.
	if celer:
		celer.prewarm(on, ghost_xf.translated_local(Vector3(2.2, 0.0, 0.0)))
	if oficio:
		oficio.prewarm(on, ghost_xf.translated_local(Vector3(0.0, 0.6, 2.5)))
	if near:
		_rocket_of(near).prewarm(on)
		_judged_of(near).prewarm(on)
		for i in _shower.size():
			var coin := _shower[i]
			_kill_tween(coin)
			coin.visible = on
			if on:
				coin.global_position = near.global_position + near.get_forward() * 5.0 + Vector3(i * 0.6 - 1.5, 1.4, 0.0)
				coin.scale = Vector3.ONE * SHOWER_SCALE


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
