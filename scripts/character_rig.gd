class_name CharacterRig
extends Node3D
## Personagem animado a partir do .glb (esqueleto do Celerino, 65 ossos).
##
## As animações do arquivo trazem trilhas para quase todos os ossos, então elas são
## misturadas aqui por código, em camadas, cada uma limitada a um grupo de ossos:
## corpo → pernas → mãos → gestos → rosto → olhos → piscada.
##
## Modo STAND (telas de seleção): em pé, respirando, acenando, com expressões.
## Modo DRIVE (no kart): sentado no banco, mãos no volante (IK com braço "elástico" de
## desenho animado), inclina nas curvas, reage a turbo, batidas e chegada.

## Emitido quando a expressão muda (o retrato do HUD imita o piloto).
signal face_changed(face_name: StringName)

enum Mode { STAND, DRIVE }

# --- Grupos de ossos ------------------------------------------------------------
const BODY := [&"body_01", &"body_02", &"body_03", &"body_04", &"body_05"]
const ARM_L := [&"upper_arm.L", &"forearm.L", &"hand.L"]
const ARM_R := [&"upper_arm.R", &"forearm.R", &"hand.R"]
const LEGS := [&"thigh.L", &"shin.L", &"foot.L", &"toe.L", &"thigh.R", &"shin.R", &"foot.R", &"toe.R"]
const FACE := [&"brow.L", &"brow.R", &"eye.L", &"eye.R", &"eyelid.L", &"eyelid.R", &"mouth", &"jaw",
		&"teeth_lower", &"teeth_upper", &"tongue", &"lip_corner.L", &"lip_corner.R"]
const EYES := [&"eye.L", &"eye.R"]
const LIDS := [&"eyelid.L", &"eyelid.R"]
const FINGERS := [&"index_01", &"index_02", &"index_03", &"middle_01", &"middle_02", &"middle_03",
		&"pinky_01", &"pinky_02", &"pinky_03", &"thumb_01", &"thumb_02", &"thumb_03"]

## Ordem de aplicação das camadas (menor primeiro).
const ORDER := {
	&"body": 0, &"body_add": 1, &"legs": 2, &"hands": 3, &"gesture": 4,
	&"face": 5, &"eyes": 6, &"blink": 7,
}

## Pálpebra: deslocamento em Y que fecha o olho (veja RIG.md).
const EYELID_CLOSED := -0.332


class Layer:
	var name: StringName
	var group: StringName
	var anim: Animation
	var bones := PackedInt32Array()
	var tracks: Array[Vector3i] = []
	var time := 0.0
	var speed := 1.0
	var loop := false
	var weight := 0.0
	var target := 1.0
	var fade_speed := 8.0
	var additive := false
	## Camadas controladas diretamente (peso definido a cada quadro).
	var manual := false


var data: CharacterData
var mode := Mode.STAND
## Expressão padrão (volta para ela depois de uma reação).
var default_face := &"face_happy"

@export_group("Pose de piloto")
## Ponto da mão esquerda fechada (espaço do osso hand.L) por onde passa a barra do
## volante: o vão entre a palma (+X) e os dedos dobrados, perto dos nós dos dedos (+Y).
## O eixo Z do osso vai do mindinho para o polegar. A mão direita usa o espelho em X.
@export var grip_point := Vector3(0.03, 0.18, 0.0)
## Quanto o braço todo pode esticar (1 = tamanho normal).
@export var max_arm_stretch := 2.6
## Quanto o punho pode dobrar (graus) para a mão acompanhar a barra. Se precisar de
## mais, a mão fica um pouco atravessada na barra em vez de quebrar o punho.
@export var max_wrist_bend_degrees := 35.0
## Direção das coxas e canelas (espaço do personagem: +Z = frente).
@export var thigh_direction := Vector3(0.12, -0.12, 1.0)
@export var shin_direction := Vector3(0.05, -1.0, 0.45)
## Inclinação para a frente ao pilotar (0 a 1).
@export var lean_forward := 0.25

# --- Entradas do modo piloto (atualizadas pelo kart) --------------------------------
## -1 a 1 (positivo = esquerda).
var steer := 0.0
## -1, 0 ou 1 durante o drift.
var drift_dir := 0
## Alvos das mãos no espaço do nó pai do personagem (o kart): o ponto da barra que
## passa por dentro do punho e a direção da barra para o lado do polegar.
var hand_target_l := Vector3.ZERO
var hand_target_r := Vector3.ZERO
var hand_grip_l := Vector3.UP
var hand_grip_r := Vector3.UP
var has_hand_targets := false

var skeleton: Skeleton3D
var model: Node3D
## Refaz a pose só a cada N quadros (piloto longe da câmera). 1 = todo quadro.
var update_every := 1

var _anims := {}
var _layers: Array[Layer] = []
var _masks := {}
var _parent := PackedInt32Array()
var _rest_pos := PackedVector3Array()
var _rest_rot: Array[Quaternion] = []
var _rest_scl := PackedVector3Array()
var _pos := PackedVector3Array()
var _rot: Array[Quaternion] = []
var _scl := PackedVector3Array()
var _bone := {}

var _model_scale := 1.0
var _model_base := Vector3.ZERO
var _blink: Layer
var _look := {}
var _body_add := {}
var _blink_timer := 2.0
var _face_hold := 0.0
var _gesture_hold := 0.0
var _gesture_arms := 0
var _ik_l := 1.0
var _ik_r := 1.0
var _steer_s := 0.0
var _drift_s := 0.0
var _boost_lean := 0.0
## Pose de manobra (strike_pose): alvo, valor suavizado e quanto tempo ainda segura.
var _pose_target := Vector3.ZERO
var _pose := Vector3.ZERO
var _pose_hold := 0.0
var _bounce := 0.0
var _bounce_vel := 0.0
var _glance_timer := 3.0
var _glance := Vector2.ZERO
var _time := 0.0
var _skipped := 0
var _skipped_delta := 0.0

## Trilhas de cada animação por osso (id da animação -> {osso: Vector3i(pos, rot, escala)}).
static var _track_cache := {}


func _ready() -> void:
	if data and data.model_scene:
		model = data.model_scene.instantiate() as Node3D
	if model == null:
		push_warning("CharacterRig sem modelo.")
		return
	model.name = "Modelo"
	add_child(model)
	# Uma malha só no lugar das 10 do modelo, com a recoloração dos adversários no
	# material (veja CharacterMesh: na web era o maior custo da corrida).
	var merged := CharacterMesh.apply(model, data)
	if data.model_tint.a > 0.0 and not merged:
		_apply_tint(data.model_tint, data.tint_materials)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		player.active = false
		for anim_name in player.get_animation_list():
			_anims[StringName(anim_name)] = player.get_animation(anim_name)
	_setup_skeleton()
	_apply_mode()
	# Cada piloto começa numa fase diferente: com `update_every` > 1 eles não refazem a
	# pose (e a deformação da malha na GPU) todos no mesmo quadro.
	_skipped = randi() % 6


# --- Configuração ------------------------------------------------------------------

## Personagem em pé (seleção). `scale_value` = escala do modelo.
func setup_stand(scale_value := 1.0) -> void:
	mode = Mode.STAND
	_model_scale = scale_value
	_model_base = Vector3.ZERO
	if is_node_ready():
		_apply_mode()


## Personagem sentado: a base do corpo fica na origem deste nó.
func setup_drive(scale_value: float, seat_height: float) -> void:
	mode = Mode.DRIVE
	_model_scale = scale_value
	_model_base = Vector3(0.0, -seat_height * scale_value, 0.0)
	if is_node_ready():
		_apply_mode()


func _setup_skeleton() -> void:
	var count := skeleton.get_bone_count()
	_parent.resize(count)
	_rest_pos.resize(count)
	_rest_scl.resize(count)
	_rest_rot.resize(count)
	for i in count:
		_parent[i] = skeleton.get_bone_parent(i)
		var rest := skeleton.get_bone_rest(i)
		_rest_pos[i] = rest.origin
		_rest_rot[i] = rest.basis.get_rotation_quaternion()
		_rest_scl[i] = rest.basis.get_scale()
		_bone[StringName(skeleton.get_bone_name(i))] = i
	_pos = _rest_pos.duplicate()
	_rot = _rest_rot.duplicate()
	_scl = _rest_scl.duplicate()

	var fingers_l: Array = []
	var fingers_r: Array = []
	for f in FINGERS:
		fingers_l.append(StringName(f + ".L"))
		fingers_r.append(StringName(f + ".R"))
	_masks[&"body"] = _ids(BODY)
	_masks[&"legs"] = _ids(LEGS)
	_masks[&"arms"] = _ids(ARM_L + ARM_R)
	_masks[&"body_arms"] = _ids(BODY + ARM_L + ARM_R)
	_masks[&"body_arms_legs"] = _ids(BODY + ARM_L + ARM_R + LEGS)
	_masks[&"fingers_l"] = _ids(fingers_l)
	_masks[&"fingers_r"] = _ids(fingers_r)
	_masks[&"arms_fingers"] = _ids(ARM_L + ARM_R + fingers_l + fingers_r)
	_masks[&"arm_fingers_l"] = _ids(ARM_L + fingers_l)
	_masks[&"arm_fingers_r"] = _ids(ARM_R + fingers_r)
	_masks[&"face"] = _ids(FACE)
	_masks[&"eyes"] = _ids(EYES)
	_masks[&"lids"] = _ids(LIDS)


## Recolore o modelo: os materiais da lista trocam a matiz para a de `tint`. O
## primeiro da lista vira a própria `tint`; os outros mantêm o quanto eram mais
## claros ou escuros que ele (o azul-claro vira a versão clara da cor nova etc.).
func _apply_tint(tint: Color, names: PackedStringArray) -> void:
	if names.is_empty():
		return
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var originals := {}
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat and names.has(mat.resource_name):
				originals[mat.resource_name] = mat
	var base: BaseMaterial3D = originals.get(names[0])
	if base == null:
		push_warning("Recolorir: material '%s' não encontrado no modelo." % names[0])
		return
	var ref := base.albedo_color
	var s_ratio := tint.s / maxf(ref.s, 0.01)
	var v_ratio := tint.v / maxf(ref.v, 0.01)
	var tinted := {}
	for mat_name in originals:
		var mat: BaseMaterial3D = originals[mat_name]
		var c := mat.albedo_color
		var copy := mat.duplicate() as BaseMaterial3D
		copy.albedo_color = Color.from_hsv(tint.h, clampf(c.s * s_ratio, 0.0, 1.0),
				clampf(c.v * v_ratio, 0.0, 1.0), c.a)
		tinted[mat] = copy
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if tinted.has(mat):
				mi.set_surface_override_material(s, tinted[mat])


func _ids(names: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in names:
		if _bone.has(StringName(n)):
			out.append(_bone[StringName(n)])
	return out


func _apply_mode() -> void:
	if skeleton == null:
		return
	model.scale = Vector3.ONE * _model_scale
	model.position = _model_base
	_layers.clear()
	_look.clear()
	_body_add.clear()
	_gesture_arms = 0
	_ik_l = 1.0
	_ik_r = 1.0
	if mode == Mode.STAND:
		_set_layer(&"body", &"idle", &"body_arms", 100.0)
		_set_layer(&"hands", &"hand_relaxed_L", &"fingers_l", 100.0)
		_add_layer(&"hand_relaxed_R", &"fingers_r", &"hands").weight = 1.0
	else:
		var breathing := _set_layer(&"body", &"idle", &"body", 100.0)
		if breathing:
			breathing.target = 0.5
			breathing.weight = 0.5
		for clip in [&"body_lean_forward", &"body_lean_back", &"body_bend_left", &"body_bend_right",
				&"body_twist_left", &"body_twist_right"]:
			var layer := _add_layer(clip, &"body", &"body_add", true)
			if layer:
				layer.manual = true
				_body_add[clip] = layer
		_set_layer(&"hands", &"hand_fist_L", &"fingers_l", 100.0)
		_add_layer(&"hand_fist_R", &"fingers_r", &"hands").weight = 1.0
	_set_layer(&"face", default_face, &"face", 100.0)
	for clip in [&"eyes_look_left", &"eyes_look_right", &"eyes_look_up", &"eyes_look_down"]:
		var layer := _add_layer(clip, &"eyes", &"eyes")
		if layer:
			layer.manual = true
			layer.weight = 0.0
			_look[clip] = layer
	_blink = _add_layer(&"blink", &"lids", &"blink", true)
	if _blink:
		_blink.manual = true
		_blink.weight = 0.0
	_process(0.0)


# --- Camadas ---------------------------------------------------------------------------

static func _track_map(anim: Animation) -> Dictionary:
	var key := anim.get_instance_id()
	if _track_cache.has(key):
		return _track_cache[key]
	var map := {}
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D \
				and type != Animation.TYPE_SCALE_3D:
			continue
		var bone := StringName(anim.track_get_path(t).get_concatenated_subnames())
		var v: Vector3i = map.get(bone, Vector3i(-1, -1, -1))
		match type:
			Animation.TYPE_POSITION_3D:
				v.x = t
			Animation.TYPE_ROTATION_3D:
				v.y = t
			Animation.TYPE_SCALE_3D:
				v.z = t
		map[bone] = v
	_track_cache[key] = map
	return map


func _add_layer(anim_name: StringName, mask: StringName, group: StringName, additive := false) -> Layer:
	var anim: Animation = _anims.get(anim_name)
	if anim == null:
		push_warning("Animação não encontrada: %s" % anim_name)
		return null
	var layer := Layer.new()
	layer.name = anim_name
	layer.group = group
	layer.anim = anim
	layer.additive = additive
	layer.loop = anim.loop_mode != Animation.LOOP_NONE
	var map := _track_map(anim)
	for b in _masks[mask]:
		var key := StringName(skeleton.get_bone_name(b))
		if map.has(key):
			layer.bones.append(b)
			layer.tracks.append(map[key])
	# Insere depois da última camada de mesma ordem (ou menor).
	var order: int = ORDER.get(group, 99)
	var at := _layers.size()
	for i in _layers.size():
		if ORDER.get(_layers[i].group, 99) > order:
			at = i
			break
	_layers.insert(at, layer)
	return layer


## Troca a animação de um grupo com transição suave.
func _set_layer(group: StringName, anim_name: StringName, mask: StringName, fade := 8.0) -> Layer:
	for i in range(_layers.size() - 1, -1, -1):
		var l := _layers[i]
		if l.group == group and not l.manual:
			if l.name == anim_name and l.target > 0.0:
				return l
			break
	var layer := _add_layer(anim_name, mask, group)
	if layer:
		layer.weight = 0.0 if fade < 50.0 else 1.0
		layer.fade_speed = fade
	return layer


func _fade_group(group: StringName, fade := 6.0) -> void:
	for l in _layers:
		if l.group == group and not l.manual:
			l.target = 0.0
			l.fade_speed = fade


func _update_layers(delta: float) -> void:
	for l in _layers:
		l.time += delta * l.speed
		if l.loop and l.anim.length > 0.0:
			l.time = fposmod(l.time, l.anim.length)
		else:
			l.time = minf(l.time, l.anim.length)
		if not l.manual:
			l.weight = move_toward(l.weight, l.target, l.fade_speed * delta)
	# Remove camadas que sumiram ou que ficaram escondidas embaixo de outra completa.
	var covered := {}
	for i in range(_layers.size() - 1, -1, -1):
		var l := _layers[i]
		if l.manual:
			continue
		if (l.target <= 0.0 and l.weight <= 0.0) or covered.has(l.group):
			_layers.remove_at(i)
			continue
		if l.weight >= 1.0 and l.target >= 1.0 and l.group != &"hands":
			covered[l.group] = true


func _apply_layer(l: Layer) -> void:
	var w := l.weight
	if w <= 0.001:
		return
	var t := l.time
	for k in l.bones.size():
		var b := l.bones[k]
		var tr := l.tracks[k]
		if tr.y >= 0:
			var q := l.anim.rotation_track_interpolate(tr.y, t)
			if l.additive:
				var d := _rest_rot[b].inverse() * q
				_rot[b] = _rot[b] * Quaternion.IDENTITY.slerp(d, w)
			else:
				_rot[b] = _rot[b].slerp(q, w)
		if tr.x >= 0:
			var p := l.anim.position_track_interpolate(tr.x, t)
			if l.additive:
				_pos[b] += (p - _rest_pos[b]) * w
			else:
				_pos[b] = _pos[b].lerp(p, w)
		if tr.z >= 0 and not l.additive:
			_scl[b] = _scl[b].lerp(l.anim.scale_track_interpolate(tr.z, t), w)


# --- API: expressões e gestos -----------------------------------------------------------

## Troca a expressão do rosto. Com `hold` > 0, volta para a padrão depois desse tempo.
func set_face(face_name: StringName, hold := 0.0) -> void:
	if skeleton == null:
		return
	_set_layer(&"face", face_name, &"face", 14.0)
	_face_hold = hold
	face_changed.emit(face_name)


## Gesto com os braços (`gesture_*`). `arms`: 0 = os dois, 1 = só o esquerdo, 2 = só o direito.
func play_gesture(gesture_name: StringName, duration := 1.5, arms := 0) -> void:
	if skeleton == null:
		return
	var mask: StringName = &"arms_fingers"
	if arms == 1:
		mask = &"arm_fingers_l"
	elif arms == 2:
		mask = &"arm_fingers_r"
	_fade_group(&"gesture", 10.0)
	var layer := _add_layer(gesture_name, mask, &"gesture")
	if layer:
		layer.weight = 0.0
		layer.fade_speed = 7.0
	_gesture_hold = duration
	_gesture_arms = 3 if arms == 0 else arms


func blink() -> void:
	if _blink:
		_blink.time = 0.0
		_blink.weight = 1.0


## Pulinho do corpo (pulo, batida, aterrissagem).
func bounce(amount := 1.0) -> void:
	_bounce_vel += amount * 2.2


func react_boost(power := 1) -> void:
	set_face(&"face_surprised" if power >= 3 else &"face_happy", 0.9)
	_boost_lean = 1.0
	bounce(0.6)


## Joga o corpo numa pose (manobras no pulo) e volta sozinho depois de `hold` s.
## `pose`: x = para trás (+) ou para a frente (-), y = dobra para a esquerda (+) ou
## direita (-), z = torce para a esquerda (+) ou direita (-). Lados do piloto. De -1 a 1.
func strike_pose(pose: Vector3, hold: float) -> void:
	_pose_target = pose.clampf(-1.0, 1.0)
	_pose_hold = hold


func react_bump(strength := 0.5) -> void:
	set_face(&"face_surprised", 0.8)
	bounce(0.8 + strength)


func react_drift(level: int) -> void:
	if level >= 2:
		set_face(&"face_angry", 0.0)


func react_drift_end() -> void:
	if _face_hold <= 0.0:
		set_face(default_face)


func celebrate() -> void:
	set_face(&"face_happy", 0.0)
	play_gesture(&"gesture_cheer", 2.6)


# --- Atualização ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if skeleton == null:
		return
	if update_every > 1:
		_skipped += 1
		_skipped_delta += delta
		if _skipped < update_every:
			return
		delta = _skipped_delta
		_skipped = 0
		_skipped_delta = 0.0
	elif _skipped > 0:
		delta += _skipped_delta
		_skipped = 0
		_skipped_delta = 0.0
	_time += delta
	_update_timers(delta)
	_update_layers(delta)

	_steer_s = lerpf(_steer_s, steer, 1.0 - exp(-7.0 * delta))
	_drift_s = lerpf(_drift_s, float(drift_dir), 1.0 - exp(-6.0 * delta))
	_boost_lean = move_toward(_boost_lean, 0.0, delta * 1.6)
	if _pose_hold > 0.0:
		_pose_hold -= delta
		if _pose_hold <= 0.0:
			_pose_target = Vector3.ZERO
	_pose = _pose.lerp(_pose_target, 1.0 - exp(-10.0 * delta))
	_update_manual_layers()

	# Pose base = repouso + camadas.
	for i in _pos.size():
		_pos[i] = _rest_pos[i]
		_rot[i] = _rest_rot[i]
		_scl[i] = _rest_scl[i]
	for l in _layers:
		_apply_layer(l)
	_clamp_eyelids()

	if mode == Mode.DRIVE:
		_pose_legs()
		_pose_arms(delta)
		_update_bounce(delta)
	for i in _pos.size():
		skeleton.set_bone_pose_position(i, _pos[i])
		skeleton.set_bone_pose_rotation(i, _rot[i])
		skeleton.set_bone_pose_scale(i, _scl[i])


func _update_timers(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		blink()
		_blink_timer = randf_range(2.0, 4.5)
		if randf() < 0.15:
			_blink_timer = 0.32  # piscada dupla
	if _blink and _blink.weight > 0.0 and _blink.time >= _blink.anim.length:
		_blink.weight = 0.0
	if _face_hold > 0.0:
		_face_hold -= delta
		if _face_hold <= 0.0:
			set_face(default_face)
	if _gesture_hold > 0.0:
		_gesture_hold -= delta
		if _gesture_hold <= 0.0:
			_fade_group(&"gesture", 5.0)
			_gesture_arms = 0
	_glance_timer -= delta
	if _glance_timer <= 0.0:
		_glance_timer = randf_range(1.5, 4.0)
		_glance = Vector2.ZERO if randf() < 0.5 else Vector2(randf_range(-0.6, 0.6), randf_range(-0.3, 0.4))


func _update_manual_layers() -> void:
	var look := Vector2(_glance.x, _glance.y)
	if mode == Mode.DRIVE:
		look = Vector2(_steer_s * 0.9 + _drift_s * 0.3, -0.1)
	_set_weight(_look, &"eyes_look_left", maxf(look.x, 0.0))
	_set_weight(_look, &"eyes_look_right", maxf(-look.x, 0.0))
	_set_weight(_look, &"eyes_look_up", maxf(look.y, 0.0))
	_set_weight(_look, &"eyes_look_down", maxf(-look.y, 0.0))
	if mode != Mode.DRIVE:
		return
	# A pose de manobra soma por cima (e tira a curvada para a frente ao ir para trás).
	var bend := _steer_s * 0.55 + _drift_s * 0.35 + _pose.y
	var twist := _drift_s * 0.35 + _pose.z
	var back := maxf(_pose.x, 0.0)
	_set_weight(_body_add, &"body_lean_forward", lean_forward * (1.0 - _boost_lean) * (1.0 - back) + maxf(-_pose.x, 0.0))
	_set_weight(_body_add, &"body_lean_back", _boost_lean * 0.7 + back)
	_set_weight(_body_add, &"body_bend_left", maxf(bend, 0.0))
	_set_weight(_body_add, &"body_bend_right", maxf(-bend, 0.0))
	_set_weight(_body_add, &"body_twist_left", maxf(twist, 0.0))
	_set_weight(_body_add, &"body_twist_right", maxf(-twist, 0.0))


func _set_weight(dict: Dictionary, key: StringName, value: float) -> void:
	var layer: Layer = dict.get(key)
	if layer:
		layer.weight = clampf(value, 0.0, 1.0)


func _clamp_eyelids() -> void:
	for b in _masks[&"lids"]:
		_pos[b].y = clampf(_pos[b].y, _rest_pos[b].y + EYELID_CLOSED, _rest_pos[b].y)


func _update_bounce(delta: float) -> void:
	# Mola simples: o corpo afunda e volta. Em passos de no máximo 1/60 s: com o
	# piloto longe da câmera a pose só é refeita a cada vários quadros (update_every)
	# e, com o jogo a 30 fps, um passo único de ~0,2 s fazia a mola explodir (NaN).
	var remaining := minf(delta, 0.5)
	while remaining > 0.0:
		var dt := minf(remaining, 1.0 / 60.0)
		_bounce_vel += (-_bounce * 90.0 - _bounce_vel * 9.0) * dt
		_bounce += _bounce_vel * dt
		remaining -= dt
	model.position = _model_base + Vector3(0.0, _bounce * 0.05 * _model_scale, 0.0)


# --- Pose de piloto ------------------------------------------------------------------------

## Transformação global (espaço do esqueleto) de um osso a partir da pose atual. A
## escala é local, como no Skeleton3D (gira depois de escalar).
func _global(i: int) -> Transform3D:
	var t := _local(i)
	var p := _parent[i]
	while p >= 0:
		t = _local(p) * t
		p = _parent[p]
	return t


func _local(i: int) -> Transform3D:
	return Transform3D(Basis(_rot[i]) * Basis.from_scale(_scl[i]), _pos[i])


## Gira o osso para que o eixo Y dele aponte para `dir` (espaço do esqueleto).
func _aim(i: int, dir: Vector3, weight := 1.0) -> void:
	var parent_basis := Basis.IDENTITY
	if _parent[i] >= 0:
		parent_basis = _global(_parent[i]).basis.orthonormalized()
	var current := parent_basis * Basis(_rot[i])
	var from := current.y.normalized()
	var to := dir.normalized()
	if from.dot(to) > 0.99999:
		return
	var aimed := Basis(Quaternion(from, to)) * current
	var local := (parent_basis.inverse() * aimed).get_rotation_quaternion()
	_rot[i] = _rot[i].slerp(local, weight)


func _pose_legs() -> void:
	for side in [["thigh.L", "shin.L", 1.0], ["thigh.R", "shin.R", -1.0]]:
		var thigh: int = _bone.get(StringName(side[0]), -1)
		var shin: int = _bone.get(StringName(side[1]), -1)
		if thigh < 0 or shin < 0:
			continue
		var s: float = side[2]
		_aim(thigh, Vector3(thigh_direction.x * s, thigh_direction.y, thigh_direction.z))
		_aim(shin, Vector3(shin_direction.x * s, shin_direction.y, shin_direction.z))


func _pose_arms(delta: float) -> void:
	var want_l := 0.0 if (_gesture_arms == 1 or _gesture_arms == 3) else 1.0
	var want_r := 0.0 if (_gesture_arms == 2 or _gesture_arms == 3) else 1.0
	_ik_l = move_toward(_ik_l, want_l, delta * 5.0)
	_ik_r = move_toward(_ik_r, want_r, delta * 5.0)
	if not has_hand_targets:
		return
	var to_skel := _parent_to_skeleton()
	var grip_r := Vector3(-grip_point.x, grip_point.y, grip_point.z)
	_arm_ik(&"upper_arm.L", &"forearm.L", &"hand.L", to_skel * hand_target_l,
			(to_skel.basis * hand_grip_l).normalized(), grip_point, _ik_l)
	_arm_ik(&"upper_arm.R", &"forearm.R", &"hand.R", to_skel * hand_target_r,
			(to_skel.basis * hand_grip_r).normalized(), grip_r, _ik_r)


## Braço reto do ombro ao punho, com a mão fechada em volta da barra: o eixo Z da mão
## (mindinho → polegar) segue a barra (`thumb`) e o vão do punho (`grip`, espaço da mão)
## fica em cima de `target`. Tudo no espaço do esqueleto.
##
## Braço elástico: só o osso do braço estica (escala em Y); o antebraço desfaz essa
## escala e fica do tamanho normal. Escala não uniforme num osso entorta os filhos que
## giram em relação a ele, então assim a mão pode dobrar no punho sem deformar.
func _arm_ik(upper_name: StringName, fore_name: StringName, hand_name: StringName,
		target: Vector3, thumb: Vector3, grip: Vector3, weight: float) -> void:
	if weight <= 0.0:
		return
	var upper: int = _bone.get(upper_name, -1)
	var fore: int = _bone.get(fore_name, -1)
	var hand: int = _bone.get(hand_name, -1)
	if upper < 0 or fore < 0 or hand < 0:
		return
	var shoulder := _global(upper).origin
	# A orientação da mão depende da direção do braço, que depende de onde fica o punho.
	var hand_basis := Basis.IDENTITY
	var wrist := target
	for i in 2:
		hand_basis = _grip_basis((wrist - shoulder).normalized(), thumb)
		wrist = target - hand_basis * grip
	var to := wrist - shoulder
	var upper_len := _rest_pos[fore].length()
	var fore_len := _rest_pos[hand].length()
	var max_stretch := (max_arm_stretch * (upper_len + fore_len) - fore_len) / upper_len
	var stretch := lerpf(1.0, clampf((to.length() - fore_len) / upper_len, 0.5, max_stretch), weight)

	# Braço apontado para o punho, com o antebraço reto.
	_rot[fore] = _rot[fore].slerp(_rest_rot[fore], weight)
	_aim(upper, to, weight)
	# O giro que a mão precisa em volta do braço fica metade no ombro e metade no
	# cotovelo: o tubo do braço torce pouco em cada junta.
	var fore_rest := _global(upper).basis.orthonormalized() * Basis(_rest_rot[fore])
	var q := ((fore_rest * Basis(_rest_rot[hand])).inverse() * hand_basis).get_rotation_quaternion()
	if q.w < 0.0:
		q = -q
	var half := atan2(q.y, q.w) * weight
	_rot[upper] = _rot[upper] * Quaternion(Vector3.UP, half)
	_rot[fore] = _rot[fore].slerp(_rest_rot[fore] * Quaternion(Vector3.UP, half), weight)
	_scl[upper] = Vector3(1.0, stretch, 1.0)
	_scl[fore] = Vector3(1.0, 1.0 / stretch, 1.0)
	# A mão termina o giro e dobra no punho.
	var local := (_global(fore).basis.orthonormalized().inverse() * hand_basis).get_rotation_quaternion()
	_rot[hand] = _rot[hand].slerp(local, weight)


## Base da mão fechada numa barra: Z (lado do polegar) ao longo da barra e Y (punho →
## dedos) o mais perto possível da direção do braço, dobrando o punho no máximo
## `max_wrist_bend_degrees` (depois disso a mão fica um pouco atravessada na barra).
func _grip_basis(arm_dir: Vector3, thumb: Vector3) -> Basis:
	var z := thumb
	var y := arm_dir - z * arm_dir.dot(z)
	if y.length_squared() < 1e-6:
		y = z.cross(Vector3.RIGHT if absf(z.x) < 0.9 else Vector3.FORWARD)
	y = y.normalized()
	var bend := y.angle_to(arm_dir)
	var max_bend := deg_to_rad(max_wrist_bend_degrees)
	if bend > max_bend:
		y = arm_dir.slerp(y, max_bend / bend).normalized()
		z = (z - y * z.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


## Converte do espaço do nó pai deste personagem para o espaço do esqueleto.
func _parent_to_skeleton() -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return (transform * t).affine_inverse()
