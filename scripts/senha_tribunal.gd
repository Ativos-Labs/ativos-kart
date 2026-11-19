class_name SenhaTribunal
extends Node3D
## Fila do tribunal em 3D: a senha "AGUARDE SUA VEZ" que o piloto segura levantada
## enquanto o kart fica parado. Em cima dela, um painel vermelho de LED chama as senhas
## ("CHAMANDO 084", "085"…) até chegar no número dele; aí o painel fica verde, a senha
## voa para longe e o kart é liberado (Kart.queue_time). Fica no KartVisual (o mesmo
## espaço das mãos do piloto: KartVisual.raised_hand_point) virada para trás, para a
## câmera que vem atrás. Um por kart, criado na primeira vez (ItemAttacks).

## Emitido quando a senha é chamada (o som do "plim-plom" fica com quem chamou play).
signal called

const TEX := preload("res://assets/textures/itens/senha.png")
## Tamanho do papel (m) e onde fica o número nele (fração da altura, a partir de cima).
const SIZE := Vector2(0.56, 0.875)
const NUMBER_AT := 0.525
## Quantas senhas o painel chama antes da do piloto.
const CALLS_BEFORE := 3
const LED := Color("ff3b30")
const LED_GO := Color("3dff7a")
const LED_BACK := Color("1a0d10")

static var _paper_mesh: QuadMesh
static var _back_mesh: QuadMesh

var kart: Kart
var number := 87
var _paper: Node3D
var _number: Label3D
var _panel: Label3D
var _calls := 0
var _step := 0.0
var _left := 0.0
var _t := 0.0
var _tween: Tween


func build(k: Kart) -> void:
	name = "Senha"
	kart = k
	_paper = Node3D.new()
	_paper.name = "Papel"
	add_child(_paper)
	var front := MeshInstance3D.new()
	front.name = "Frente"
	front.mesh = _get_paper_mesh()
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paper.add_child(front)
	var back := MeshInstance3D.new()
	back.name = "Verso"
	back.mesh = _get_back_mesh()
	back.rotation.y = PI
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paper.add_child(back)
	_number = _label("Numero", 96, Color("1d2550"), Color.WHITE, 4)
	_number.position = Vector3(0.0, SIZE.y * (0.5 - NUMBER_AT), 0.004)
	_number.pixel_size = 0.0026
	_paper.add_child(_number)
	_panel = _label("Painel", 64, LED, LED_BACK, 26)
	_panel.position = Vector3(0.0, SIZE.y * 0.5 + 0.2, 0.0)
	_panel.pixel_size = 0.0032
	_panel.render_priority = 3
	_panel.outline_render_priority = 2
	add_child(_panel)
	visible = false
	set_physics_process(false)


func is_busy() -> bool:
	return _left > 0.0


## O piloto levanta a senha por `duration` s; o painel chama as anteriores e, no fim,
## a dele.
func play(duration: float) -> void:
	number = randi_range(12, 498)
	_number.text = "%03d" % number
	_calls = 0
	_step = duration / float(CALLS_BEFORE + 1)
	_left = duration
	_t = 0.0
	_show_call(number - CALLS_BEFORE)
	_place()
	visible = true
	scale = Vector3.ONE * 0.15
	_paper.position = Vector3.ZERO
	_paper.rotation = Vector3.ZERO
	_paper.scale = Vector3.ONE
	_panel.visible = true
	reset_physics_interpolation()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_physics_process(true)


## Some na hora (o kart foi reposicionado, a corrida acabou...).
func stop() -> void:
	_left = 0.0
	visible = false
	set_physics_process(false)
	if kart and kart.kart_visual:
		kart.kart_visual.hand_raise = 0.0


func _physics_process(delta: float) -> void:
	if kart == null or not is_instance_valid(kart):
		return
	var kv := kart.kart_visual
	_t += delta
	if _left > 0.0:
		_left -= delta
		if kart.queue_time <= 0.0 and _left > 0.12:
			# O kart saiu da fila antes (Trânsito em julgado, reposicionado...).
			_left = 0.0
		if kv:
			kv.hand_raise = move_toward(kv.hand_raise, 1.0, delta * 5.0)
		_place()
		# A senha balança na mão.
		_paper.rotation = Vector3(0.05 * sin(_t * 3.1), 0.12 * sin(_t * 1.7), 0.09 * sin(_t * 4.3))
		var due := mini(int(_t / _step), CALLS_BEFORE)
		if due > _calls:
			_calls = due
			_show_call(number - CALLS_BEFORE + _calls)
		if _left <= 0.0:
			_finish()
		return
	# Depois de chamada: a mão volta para o volante.
	if kv:
		kv.hand_raise = move_toward(kv.hand_raise, 0.0, delta * 4.0)
		if kv.hand_raise <= 0.0 and not visible:
			set_physics_process(false)
	elif not visible:
		set_physics_process(false)


## Fica na mão levantada (o papel em pé em cima do punho). Segue a mão de verdade do
## piloto (o braço nem sempre alcança o ponto pedido); sem piloto, o ponto pedido.
func _place() -> void:
	var kv := kart.kart_visual
	if kv == null:
		return
	if get_parent() != kv:
		get_parent().remove_child(self)
		kv.add_child(self)
	var fist := kv.raised_hand_point()
	var d := kart.driver
	if d and d.visible:
		var hand := d.hand_global(1)
		if hand.is_finite():
			fist = fist.lerp(kv.to_local(hand), clampf(kv.hand_raise, 0.0, 1.0))
	position = fist + Vector3(0.0, SIZE.y * 0.5 + 0.04, 0.02)


func _show_call(value: int) -> void:
	_panel.text = "CHAMANDO %03d" % value
	var mine := value == number
	_panel.modulate = LED_GO if mine else LED
	_panel.scale = Vector3.ONE * 1.18
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_panel, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A senha foi chamada: o painel fica verde e a senha voa para longe.
func _finish() -> void:
	_show_call(number)
	called.emit()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_interval(0.35)
	_tween.tween_callback(func(): _panel.visible = false)
	_tween.set_parallel()
	_tween.tween_property(_paper, "position", Vector3(0.6, 2.2, 0.8), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_paper, "rotation", Vector3(0.8, 2.5, 3.5), 0.6)
	_tween.tween_property(_paper, "scale", Vector3.ONE * 0.05, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)


## Mostra a senha parada na mão (compilar os shaders atrás da tela de carregamento).
func prewarm(on: bool) -> void:
	if on:
		_number.text = "087"
		_show_call(84)
		_place()
		_paper.scale = Vector3.ONE
		scale = Vector3.ONE
	visible = on


func _label(node_name: String, size: int, color: Color, outline: Color, outline_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.font = UiKit.FONT_TITLE
	label.font_size = size
	label.outline_size = outline_size
	label.modulate = color
	label.outline_modulate = outline
	label.shaded = false
	label.double_sided = false
	label.render_priority = 1
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return label


static func _get_paper_mesh() -> QuadMesh:
	if _paper_mesh == null:
		_paper_mesh = QuadMesh.new()
		_paper_mesh.size = SIZE
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = TEX
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.roughness = 0.9
		# Um pouco de brilho próprio: a senha é lida de longe, mesmo na sombra.
		mat.emission_enabled = true
		mat.emission_texture = TEX
		mat.emission_energy_multiplier = 0.25
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_paper_mesh.material = mat
	return _paper_mesh


static func _get_back_mesh() -> QuadMesh:
	if _back_mesh == null:
		_back_mesh = QuadMesh.new()
		_back_mesh.size = SIZE * Vector2(1.0, 0.96)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("ece6d2")
		mat.roughness = 0.95
		_back_mesh.material = mat
	return _back_mesh
