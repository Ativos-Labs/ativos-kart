class_name AntecipacaoCeler
extends Node3D
## Antecipação Celer em 3D: o Celerino aparece voando ao lado do kart de quem usou, de
## frente para trás (para a câmera), segurando uma maleta dourada com as duas mãos. A
## maleta abre (a tampa desce como uma bandeja e aparecem os maços de notas) e cada
## toque solta um jato de notas para trás do kart. No fim ele fecha a maleta, acena e
## voa embora.
## Montado uma vez na carga da corrida (ItemEffects), escondido e parado até ser usado
## (só uma Antecipação por vez na pista, veja RaceItem.INFO "single").

const CELERINO := "res://data/personagens/celerino.tres"
const NOTE_TEX := preload("res://assets/textures/itens/nota.png")
## Tamanho do Celerino (o modelo tem 2 m).
const RIG_SCALE := 0.6
## Onde ele fica no espaço do kart: à esquerda (a direita do alto da tela é do mapa),
## um pouco acima e atrás.
const OFFSET := Vector3(-1.65, 0.9, 0.0) * KartScale.ITEMS
## Escala do nó todo (o Celerino e a maleta foram feitos para os karts de antes do encaixe
## piloto × kart).
const NODE_SCALE := KartScale.ITEMS
## Maleta: tamanho (m) e onde fica, na frente da barriga (este nó olha para +Z).
const CASE_SIZE := Vector3(0.6, 0.42, 0.1)
const CASE_POS := Vector3(0.0, 0.6, 0.3)
## Tampa aberta (rad em volta do eixo X, pendurada para a câmera).
const LID_OPEN := 1.75
## Duração de um jato de notas (s).
const JET_TIME := 0.3

var rig: CharacterRig
var case_root: Node3D
var lid: Node3D
var notes: GPUParticles3D
var _kart: Kart
var _home: Node3D
var _t := -1.0
var _leaving := false
var _jet := 0.0
var _kick := 0.0
var _tween: Tween


## Monta o Celerino, a maleta e as notas (escondidos). `home` = onde ele fica parado.
func build(home: Node3D) -> void:
	name = "CelerinoMaleta"
	_home = home
	var data := load(CELERINO) as CharacterData
	if data:
		rig = data.instantiate_rig()
		rig.setup_stand(RIG_SCALE)
		add_child(rig)
		for node in rig.find_children("*", "GeometryInstance3D", true, false):
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_case()
	_build_notes()
	if rig:
		# Mãos nas laterais da maleta, punho fechado em volta da borda (polegar para cima).
		var side := CASE_SIZE.x * 0.5 + 0.02
		rig.hand_target_l = CASE_POS + Vector3(side, -0.04, 0.0)
		rig.hand_target_r = CASE_POS + Vector3(-side, -0.04, 0.0)
		rig.hand_grip_l = Vector3(0.0, 1.0, 0.25).normalized()
		rig.hand_grip_r = Vector3(0.0, 1.0, 0.25).normalized()
		rig.has_hand_targets = true
	_park()


func is_busy() -> bool:
	return _t >= 0.0


## Aparece ao lado de `k` e abre a maleta.
func open(k: Kart) -> void:
	_kart = k
	_t = 0.0
	_leaving = false
	_jet = 0.0
	if get_parent() != k:
		if get_parent():
			get_parent().remove_child(self)
		k.add_child(self)
	position = OFFSET
	rotation = Vector3.ZERO
	scale = Vector3.ONE * 0.2 * NODE_SCALE
	visible = true
	reset_physics_interpolation()
	if rig:
		rig.process_mode = Node.PROCESS_MODE_INHERIT
		rig.set_face(&"face_happy")
	lid.rotation.x = 0.0
	_kill_tween()
	_tween = _new_tween()
	_tween.tween_property(self, "scale", Vector3.ONE * NODE_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "position:y", OFFSET.y + 0.25 * KartScale.ITEMS, 0.2).from(OFFSET.y - 0.5 * KartScale.ITEMS)
	_tween.tween_property(self, "position:y", OFFSET.y, 0.25).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(lid, "rotation:x", LID_OPEN, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_physics_process(true)


## Um jato de notas para trás (e a maleta dá um tranco).
func jet() -> void:
	if not is_busy() or _leaving:
		return
	_jet = JET_TIME
	_kick = 1.0
	notes.emitting = true
	if rig:
		rig.set_face(&"face_screaming" if randf() < 0.4 else &"face_smiling", 0.5)


## Fecha a maleta, acena e voa embora.
func close() -> void:
	if not is_busy() or _leaving:
		return
	_leaving = true
	_jet = 0.0
	notes.emitting = false
	var keep := global_transform
	if get_parent() != _home:
		get_parent().remove_child(self)
		_home.add_child(self)
	global_transform = keep
	reset_physics_interpolation()
	if rig:
		rig.play_gesture(&"gesture_wave", 1.2, 2)
		rig.set_face(&"face_smiling")
	_kill_tween()
	_tween = _new_tween()
	_tween.tween_property(lid, "rotation:x", 0.0, 0.2)
	_tween.tween_interval(0.45)
	var up := position + Vector3.UP * 5.0
	_tween.tween_property(self, "position", up, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "scale", Vector3.ONE * 0.2 * NODE_SCALE, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_park)


## Mostra tudo parado em `xf` (compila os shaders atrás da tela de carregamento).
func prewarm(on: bool, xf := Transform3D.IDENTITY) -> void:
	if is_busy():
		return
	if on:
		if get_parent() != _home:
			get_parent().remove_child(self)
			_home.add_child(self)
		visible = true
		global_transform = xf
		lid.rotation.x = LID_OPEN
		notes.emitting = true
		reset_physics_interpolation()
	else:
		notes.emitting = false
		notes.restart()
		notes.emitting = false
		_park()


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		set_physics_process(false)
		return
	_t += delta
	if _jet > 0.0:
		_jet -= delta
		if _jet <= 0.0:
			notes.emitting = false
	# Tranco da maleta a cada jato e um balanço de quem está voando.
	_kick = move_toward(_kick, 0.0, delta * 5.0)
	case_root.rotation.x = -0.25 * _kick * _kick
	case_root.position = CASE_POS + Vector3(0.0, 0.0, -0.06 * _kick)
	if not _leaving and _t > 0.45:
		position.y = OFFSET.y + sin((_t - 0.45) * 4.2) * 0.06 * KartScale.ITEMS
		rotation.z = sin(_t * 2.3) * 0.06
	if not is_instance_valid(_kart) and not _leaving:
		_park()


func _park() -> void:
	_kill_tween()
	_t = -1.0
	_leaving = false
	_kart = null
	visible = false
	if notes:
		notes.emitting = false
	if get_parent() and get_parent() != _home:
		get_parent().remove_child(self)
		_home.add_child(self)
	set_physics_process(false)
	if rig:
		rig.process_mode = Node.PROCESS_MODE_DISABLED


func _new_tween() -> Tween:
	return create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null


# --- Montagem --------------------------------------------------------------------------

## Maleta dourada: o fundo (com os maços de notas na frente), a tampa articulada na
## borda de baixo, a alça em cima e os fechos.
func _build_case() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.76, 0.22)
	gold.metallic = 0.85
	gold.roughness = 0.3
	var gold_dark := StandardMaterial3D.new()
	gold_dark.albedo_color = Color(0.62, 0.4, 0.08)
	gold_dark.metallic = 0.7
	gold_dark.roughness = 0.4
	var money := StandardMaterial3D.new()
	money.albedo_texture = NOTE_TEX
	money.uv1_scale = Vector3(2.0, 3.0, 1.0)
	money.roughness = 0.9
	case_root = Node3D.new()
	case_root.name = "Maleta"
	case_root.position = CASE_POS
	add_child(case_root)
	var s := CASE_SIZE
	_box(case_root, Vector3(s.x, s.y, s.z * 0.6), Vector3(0.0, 0.0, -s.z * 0.2), gold)
	# Moldura (as bordas do fundo) e os maços de notas lá dentro.
	var rim := 0.035
	_box(case_root, Vector3(s.x, rim, s.z * 0.5), Vector3(0.0, s.y * 0.5 - rim * 0.5, s.z * 0.25), gold_dark)
	_box(case_root, Vector3(s.x, rim, s.z * 0.5), Vector3(0.0, -s.y * 0.5 + rim * 0.5, s.z * 0.25), gold_dark)
	_box(case_root, Vector3(rim, s.y, s.z * 0.5), Vector3(s.x * 0.5 - rim * 0.5, 0.0, s.z * 0.25), gold_dark)
	_box(case_root, Vector3(rim, s.y, s.z * 0.5), Vector3(-s.x * 0.5 + rim * 0.5, 0.0, s.z * 0.25), gold_dark)
	var cash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(s.x - rim * 2.0, s.y - rim * 2.0)
	cash.mesh = quad
	cash.material_override = money
	cash.position = Vector3(0.0, 0.0, s.z * 0.12)
	case_root.add_child(cash)
	# Alça em cima.
	_box(case_root, Vector3(0.2, 0.035, 0.04), Vector3(0.0, s.y * 0.5 + 0.075, -s.z * 0.2), gold_dark)
	for x: float in [-0.085, 0.085]:
		_box(case_root, Vector3(0.03, 0.07, 0.03), Vector3(x, s.y * 0.5 + 0.035, -s.z * 0.2), gold_dark)
	# Tampa: gira na borda de baixo da frente; fechada, cobre a frente.
	lid = Node3D.new()
	lid.name = "Tampa"
	lid.position = Vector3(0.0, -s.y * 0.5, s.z * 0.5)
	case_root.add_child(lid)
	_box(lid, Vector3(s.x, s.y, s.z * 0.35), Vector3(0.0, s.y * 0.5, s.z * 0.175), gold)
	for x: float in [-0.18, 0.18]:
		_box(lid, Vector3(0.07, 0.05, 0.03), Vector3(x, s.y * 0.88, s.z * 0.38), gold_dark)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Notas voando: partículas soltas no mundo (ficam para trás do kart), girando.
func _build_notes() -> void:
	notes = GPUParticles3D.new()
	notes.name = "Notas"
	notes.amount = 56
	notes.lifetime = 1.4
	notes.local_coords = false
	notes.emitting = false
	notes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	notes.visibility_aabb = AABB(Vector3(-12.0, -6.0, -12.0), Vector3(24.0, 12.0, 30.0))
	notes.position = Vector3(0.0, 0.0, CASE_SIZE.z * 0.5)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 0.45, 1.0)
	pm.spread = 30.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 10.0
	pm.inherit_velocity_ratio = 0.8
	pm.gravity = Vector3(0.0, -4.5, 0.0)
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	pm.particle_flag_rotate_y = true
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -720.0
	pm.angular_velocity_max = 720.0
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(CASE_SIZE.x * 0.4, CASE_SIZE.y * 0.3, 0.02)
	notes.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.17)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = NOTE_TEX
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	quad.material = mat
	notes.draw_pass_1 = quad
	case_root.add_child(notes)
