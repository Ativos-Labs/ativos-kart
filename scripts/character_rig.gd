class_name CharacterRig
extends Node3D
## Personagem animado a partir do .glb (esqueleto do Celerino, 65 ossos).
##
## As animações do arquivo trazem trilhas para quase todos os ossos, então elas são
## misturadas aqui por código, em camadas, cada uma limitada a um grupo de ossos:
## corpo → pernas → mãos → gestos → rosto → olhos → piscada.
##
## Modo STAND (telas de seleção): em pé, respirando, acenando, com expressões. Com
## `stand_idle` no esqueleto, o corpo todo se mexe (quadril, pernas, clavículas).
## Modo DRIVE (no kart): sentado no banco, mãos no volante, inclina nas curvas, reage a
## turbo, batidas e chegada. As mãos seguem o volante por IK: braço reto e "elástico" de
## desenho animado (Celerino) ou braço com cotovelo, com o tronco inclinando para
## alcançar o volante (personagens de proporção humana, como o Jarbas).
##
## Os nomes dos ossos e o jeito de pilotar vêm do CharacterSkeleton do personagem
## (padrão: o esqueleto do Celerino, 65 ossos).

## Emitido quando a expressão muda (o retrato do HUD imita o piloto).
signal face_changed(face_name: StringName)

enum Mode { STAND, DRIVE }

## Camadas que mexem nos blend shapes do rosto (modelos com shape keys).
const SHAPE_GROUPS := [&"face", &"blink"]
## Ordem de aplicação das camadas (menor primeiro).
const ORDER := {
	&"body": 0, &"body_add": 1, &"legs": 2, &"hands": 3, &"gesture": 4,
	&"face": 5, &"eyes": 6, &"blink": 7,
}


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
	## Pose parada (todas as trilhas usadas são constantes, ex.: punho fechado, rosto):
	## os valores são lidos uma vez só (s_*) em vez de interpolados a cada quadro. Nas
	## camadas aditivas s_rot e s_pos já guardam a diferença para a pose de repouso.
	var static_pose := false
	var s_pos := PackedVector3Array()
	var s_rot: Array[Quaternion] = []
	var s_scl := PackedVector3Array()
	## Blend shapes (rosto por shape keys): índice em CharacterRig._shape_w, trilha da
	## animação e, na pose parada, o valor.
	var shapes := PackedInt32Array()
	var shape_tracks := PackedInt32Array()
	var s_shape := PackedFloat32Array()


var data: CharacterData
var mode := Mode.STAND
## Expressão padrão (volta para ela depois de uma reação).
var default_face := &"face_happy"
## Ossos e jeito de pilotar (CharacterData.skeleton, ou o padrão do Celerino).
var skeleton_data: CharacterSkeleton

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
## Alvos dos tornozelos no espaço do nó pai (KartData.foot_point): as pernas esticam por
## IK até eles, com o quadril e o plano do joelho da pose sentada.
var foot_target_l := Vector3.ZERO
var foot_target_r := Vector3.ZERO
var has_foot_targets := false
## Medidas do banco e do assoalho do kart (KartData.cockpit(), espaço do nó pai). Com
## `skeleton_data.fit_seat`, a pose sentada é montada a partir delas.
var cockpit := {}:
	set(value):
		cockpit = value
		_cp_corner = value.get("seat_back_point", Vector3.ZERO)
		_cp_back_angle = deg_to_rad(float(value.get("seat_back_angle", 0.0)))
		_cp_seat_front = float(value.get("seat_front_z", 0.0))
		_cp_floor = float(value.get("floor_height", 0.0))
		_cp_foot_limit = float(value.get("foot_limit_z", 0.0))
		_cp_foot_spread = float(value.get("foot_spread", 0.12))
var _cp_corner := Vector3.ZERO
var _cp_back_angle := 0.0
var _cp_seat_front := 0.0
var _cp_floor := 0.0
var _cp_foot_limit := 0.0
var _cp_foot_spread := 0.12

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
## Sentado numa moto (usa a pose de moto do esqueleto, se houver).
var _bike := false
var _blink: Layer
var _look := {}
var _body_add := {}
var _blink_timer := 2.0
var _face_hold := 0.0
var _gesture_hold := 0.0
## Rapidez com que o gesto se desfaz quando `_gesture_hold` acaba.
var _gesture_fade := 5.0
var _gesture_arms := 0
## Objeto na mão e balão de fala do gesto de escolha (play_pick_gesture), enquanto ele dura.
var _pick_extras: PickExtras
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
## Coxa e canela de cada lado (L, L, R, R) para _pose_legs (-1 = osso não existe).
var _leg_bones := PackedInt32Array([-1, -1, -1, -1])
## Braço, antebraço e mão de cada lado (-1 = osso não existe).
var _arm_bones: Array[PackedInt32Array] = [PackedInt32Array([-1, -1, -1]), PackedInt32Array([-1, -1, -1])]
## Coxa, canela e pé de cada lado, o quadril e os dois últimos ossos da coluna (pescoço e
## cabeça), para montar a pose sentada (-1 = osso não existe).
var _leg_chain: Array[PackedInt32Array] = [PackedInt32Array([-1, -1, -1]), PackedInt32Array([-1, -1, -1])]
var _hips_bone := -1
var _neck_bones := PackedInt32Array()
## Ossos auxiliares (CharacterSkeleton.follow_bones): x = auxiliar, y = osso seguido.
var _followers: Array[Vector2i] = []
## Blend shapes do rosto (CharacterSkeleton "Rosto por shape keys"): nome → índice; por
## índice, as malhas que têm ele ([MeshInstance3D, índice nela]...), o valor do quadro e o
## último aplicado (só muda a malha quando ele muda).
var _shape_index := {}
var _shape_targets: Array[Array] = []
var _shape_w := PackedFloat32Array()
var _shape_set := PackedFloat32Array()
## Corretivos: x = índice do corretivo, y = índice do blend shape de origem.
var _correctives: Array[Vector2i] = []
## Pálpebras que giram: eixo e ângulo de fechar de cada uma (tirados da piscada).
var _lid_axis := {}
var _lid_closed := {}
## Braço com cotovelo: giro da mão em relação ao antebraço na pose sentada (a pegada
## medida) e a base global de repouso do pai de cada braço (o cotovelo acompanha o peito).
var _neutral_hand: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY]
var _arm_parent_rest: Array[Basis] = [Basis.IDENTITY, Basis.IDENTITY]
## Inclinação extra do tronco para alcançar o volante (peso de body_lean_forward) e
## quanto o corpo deslizou para a frente no banco (no modelo, em metros).
var _reach_lean := 0.0
var _reach_slide := 0.0
## Quanto faltou (+) ou sobrou (-) de braço em cada lado no último quadro, para o punho
## ficar a 95% do braço esticado (no modelo, em metros; NAN = sem medida).
var _arm_excess := PackedFloat32Array([NAN, NAN])
## Fração do braço esticado que a pose busca (um pouco dobrado parece mais natural).
const REACH_EXTENSION := 0.95
## Quanto body_lean_forward inclina o tronco inteiro (rad, com peso 1).
var _lean_angle := deg_to_rad(20.0)

## Trilhas de cada animação por osso (id da animação -> {osso: Vector3i(pos, rot, escala)}).
static var _track_cache := {}
## Trilhas constantes de cada animação (id da animação -> PackedByteArray, 1 = constante).
static var _constant_cache := {}
## Trilhas de blend shape de cada animação (id da animação -> {nome do blend shape: trilha}).
static var _shape_cache := {}


func _ready() -> void:
	skeleton_data = data.skeleton if data and data.skeleton else CharacterSkeleton.new()
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
	# As do esqueleto completam (ou trocam) as do modelo.
	var library := skeleton_data.animations
	if library:
		for anim_name in library.get_animation_list():
			_anims[anim_name] = library.get_animation(anim_name)
	_setup_skeleton()
	_setup_shapes()
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


## Personagem sentado: a base do corpo fica na origem deste nó. `seat_forward` (no
## modelo) adianta o corpo no banco; `bike` = montado numa moto.
func setup_drive(scale_value: float, seat_height: float, bike := false, seat_forward := 0.0) -> void:
	mode = Mode.DRIVE
	_model_scale = scale_value
	_model_base = Vector3(0.0, -seat_height, seat_forward) * scale_value
	_bike = bike
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
	var sd := skeleton_data
	var legs := sd.legs
	if legs.size() >= 6:
		_leg_bones = PackedInt32Array([_bone.get(StringName(legs[0]), -1), _bone.get(StringName(legs[1]), -1),
				_bone.get(StringName(legs[legs.size() / 2]), -1), _bone.get(StringName(legs[legs.size() / 2 + 1]), -1)])
	for side in 2:
		var names := sd.arm_left if side == 0 else sd.arm_right
		for k in mini(names.size(), 3):
			_arm_bones[side][k] = _bone.get(StringName(names[k]), -1)
		var half := legs.size() / 2
		if half >= 3:
			for k in 3:
				_leg_chain[side][k] = _bone.get(StringName(legs[side * half + k]), -1)
	_hips_bone = _bone.get(StringName(sd.hips[0]), -1) if not sd.hips.is_empty() else -1
	_neck_bones.clear()
	for k in range(maxi(sd.body.size() - 2, 0), sd.body.size()):
		_neck_bones.append(_bone.get(StringName(sd.body[k]), -1))
	_followers.clear()
	for helper in sd.follow_bones:
		var h: int = _bone.get(StringName(helper), -1)
		var s: int = _bone.get(StringName(sd.follow_bones[helper]), -1)
		if h >= 0 and s >= 0:
			_followers.append(Vector2i(h, s))
		else:
			push_warning("Osso auxiliar não encontrado: %s → %s" % [helper, sd.follow_bones[helper]])

	var body := Array(sd.body)
	var arms := Array(sd.arm_left) + Array(sd.arm_right)
	var fingers_l := Array(sd.fingers_left)
	var fingers_r := Array(sd.fingers_right)
	_masks[&"body"] = _ids(body)
	_masks[&"legs"] = _ids(Array(sd.legs))
	_masks[&"arms"] = _ids(arms)
	_masks[&"body_arms"] = _ids(body + arms)
	_masks[&"body_arms_legs"] = _ids(body + arms + Array(sd.legs))
	_masks[&"stand"] = _ids(Array(sd.hips) + body + Array(sd.shoulders) + arms + Array(sd.legs))
	# Tudo menos o rosto: a pose sentada e os gestos do corpo inteiro (play_body_gesture).
	_masks[&"drive"] = _ids(Array(sd.hips) + body + Array(sd.shoulders) + arms + Array(sd.legs) + fingers_l + fingers_r)
	_masks[&"whole_body"] = _masks[&"drive"]
	_masks[&"fingers_l"] = _ids(fingers_l)
	_masks[&"fingers_r"] = _ids(fingers_r)
	_masks[&"arms_fingers"] = _ids(arms + fingers_l + fingers_r)
	_masks[&"arm_fingers_l"] = _ids(Array(sd.arm_left) + fingers_l)
	_masks[&"arm_fingers_r"] = _ids(Array(sd.arm_right) + fingers_r)
	_masks[&"face"] = _ids(Array(sd.face))
	_masks[&"eyes"] = _ids(Array(sd.eyes))
	_masks[&"lids"] = _ids(Array(sd.lids))
	_setup_lid_limits()
	for side in 2:
		var upper := _arm_bones[side][0]
		if upper >= 0 and _parent[upper] >= 0:
			_arm_parent_rest[side] = _rest_global_basis(_parent[upper])


## Blend shapes do modelo (pelo nome, em todas as malhas: juntas pelo CharacterMesh ou não).
func _setup_shapes() -> void:
	_shape_index.clear()
	_shape_targets.clear()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh as ArrayMesh
		if mesh == null:
			continue
		for k in mesh.get_blend_shape_count():
			var shape := mesh.get_blend_shape_name(k)
			if not _shape_index.has(shape):
				_shape_index[shape] = _shape_targets.size()
				_shape_targets.append([])
			_shape_targets[_shape_index[shape]].append([mi, k])
	_shape_w.resize(_shape_targets.size())
	_shape_w.fill(0.0)
	_shape_set.resize(_shape_targets.size())
	_shape_set.fill(-1.0)
	_correctives.clear()
	for shape in skeleton_data.corrective_shapes:
		var c: int = _shape_index.get(StringName(shape), -1)
		var src: int = _shape_index.get(StringName(skeleton_data.corrective_shapes[shape]), -1)
		if c >= 0 and src >= 0:
			_correctives.append(Vector2i(c, src))


## Aplica os blend shapes do quadro: os corretivos saem do de origem, todos ficam entre 0
## e 1 (a piscada soma por cima de uma expressão que já aperta os olhos) e só os que
## mudaram vão para as malhas.
func _apply_shapes() -> void:
	for c in _correctives:
		var w := clampf(_shape_w[c.y], 0.0, 1.0)
		_shape_w[c.x] = 4.0 * w * (1.0 - w)
	for i in _shape_w.size():
		var w := clampf(_shape_w[i], 0.0, 1.0)
		if absf(w - _shape_set[i]) < 0.002:
			continue
		_shape_set[i] = w
		for target in _shape_targets[i]:
			(target[0] as MeshInstance3D).set_blend_shape_value(target[1], w)


## Base global (espaço do esqueleto) de um osso na pose de repouso.
func _rest_global_basis(i: int) -> Basis:
	var b := Basis(_rest_rot[i])
	var p := _parent[i]
	while p >= 0:
		b = Basis(_rest_rot[p]) * b
		p = _parent[p]
	return b


## Pálpebras que fecham girando: o eixo e o ângulo de fechar saem do quadro mais
## fechado da animação `blink` (para a piscada não passar do fechado em cima de uma
## expressão que já aperta os olhos).
func _setup_lid_limits() -> void:
	_lid_axis.clear()
	_lid_closed.clear()
	var blink_anim: Animation = _anims.get(&"blink")
	if skeleton_data.eyelid_closed_offset != 0.0 or blink_anim == null:
		return
	var map := _track_map(blink_anim)
	for b in _masks[&"lids"]:
		var tr: Vector3i = map.get(StringName(skeleton.get_bone_name(b)), Vector3i(-1, -1, -1))
		if tr.y < 0:
			continue
		var best := Quaternion.IDENTITY
		for k in blink_anim.track_get_key_count(tr.y):
			var d := _rest_rot[b].inverse() * (blink_anim.track_get_key_value(tr.y, k) as Quaternion)
			if d.w < 0.0:
				d = -d
			if d.get_angle() > best.get_angle():
				best = d
		if best.get_angle() > 0.05:
			_lid_axis[b] = best.get_axis().normalized()
			_lid_closed[b] = best.get_angle()


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
		if skeleton_data.stand_idle != &"" and _anims.has(skeleton_data.stand_idle):
			_set_layer(&"body", skeleton_data.stand_idle, &"stand", 100.0)
		else:
			_set_layer(&"body", &"idle", &"body_arms", 100.0)
		_set_layer(&"hands", &"hand_relaxed_L", &"fingers_l", 100.0)
		_add_layer(&"hand_relaxed_R", &"fingers_r", &"hands").weight = 1.0
	elif skeleton_data.drive_pose != &"":
		# Pose sentada pronta (quadril, pernas, braços e dedos) com a respiração somada.
		var pose_name := skeleton_data.drive_pose
		if _bike and skeleton_data.bike_pose != &"":
			pose_name = skeleton_data.bike_pose
		_set_layer(&"body", pose_name, &"drive", 100.0)
		var breathing := _add_layer(&"idle", &"body", &"body_add", true)
		if breathing:
			breathing.manual = true
			breathing.weight = 0.5
		_store_neutral_hands(_anims.get(pose_name))
	else:
		var breathing := _set_layer(&"body", &"idle", &"body", 100.0)
		if breathing:
			breathing.target = 0.5
			breathing.weight = 0.5
	if mode == Mode.DRIVE:
		for clip in [&"body_lean_forward", &"body_lean_back", &"body_bend_left", &"body_bend_right",
				&"body_twist_left", &"body_twist_right"]:
			var layer := _add_layer(clip, &"body", &"body_add", true)
			if layer:
				layer.manual = true
				_body_add[clip] = layer
		_reach_lean = 0.0
		_reach_slide = 0.0
		_arm_excess = PackedFloat32Array([NAN, NAN])
		var lean: Layer = _body_add.get(&"body_lean_forward")
		if lean and lean.static_pose and _arm_bones[0][0] >= 0:
			# Só contam os ossos entre o quadril e o ombro (o pescoço não leva o braço).
			var net := Quaternion.IDENTITY
			for k in lean.bones.size():
				var p := _parent[_arm_bones[0][0]]
				while p >= 0 and p != lean.bones[k]:
					p = _parent[p]
				if p >= 0:
					net = net * lean.s_rot[k]
			_lean_angle = maxf(net.get_angle(), 0.05)
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


## Giro de cada mão em relação ao antebraço na pose sentada: é a pegada "neutra" da
## mão no volante (os valores do esqueleto foram medidos nessa pose).
func _store_neutral_hands(pose: Animation) -> void:
	for side in 2:
		var hand := _arm_bones[side][2]
		if hand < 0:
			continue
		_neutral_hand[side] = _rest_rot[hand]
		if pose == null:
			continue
		var tr: Vector3i = _track_map(pose).get(StringName(skeleton.get_bone_name(hand)), Vector3i(-1, -1, -1))
		if tr.y >= 0:
			_neutral_hand[side] = pose.rotation_track_interpolate(tr.y, 0.0)


# --- Camadas ---------------------------------------------------------------------------

## Trilhas de blend shape da animação: nome do blend shape → trilha.
static func _shape_track_map(anim: Animation) -> Dictionary:
	var key := anim.get_instance_id()
	if _shape_cache.has(key):
		return _shape_cache[key]
	var map := {}
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_BLEND_SHAPE:
			map[StringName(anim.track_get_path(t).get_concatenated_subnames())] = t
	_shape_cache[key] = map
	return map


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


## Quais trilhas da animação têm o mesmo valor em todas as chaves (1 = constante).
static func _constant_tracks(anim: Animation) -> PackedByteArray:
	var key := anim.get_instance_id()
	if _constant_cache.has(key):
		return _constant_cache[key]
	var out := PackedByteArray()
	out.resize(anim.get_track_count())
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		var count := anim.track_get_key_count(t)
		var same := true
		if count > 1:
			match type:
				Animation.TYPE_POSITION_3D:
					var first := anim.position_track_interpolate(t, anim.track_get_key_time(t, 0))
					for k in range(1, count):
						if not anim.position_track_interpolate(t, anim.track_get_key_time(t, k)).is_equal_approx(first):
							same = false
							break
				Animation.TYPE_ROTATION_3D:
					var first := anim.rotation_track_interpolate(t, anim.track_get_key_time(t, 0))
					for k in range(1, count):
						if not anim.rotation_track_interpolate(t, anim.track_get_key_time(t, k)).is_equal_approx(first):
							same = false
							break
				Animation.TYPE_SCALE_3D:
					var first := anim.scale_track_interpolate(t, anim.track_get_key_time(t, 0))
					for k in range(1, count):
						if not anim.scale_track_interpolate(t, anim.track_get_key_time(t, k)).is_equal_approx(first):
							same = false
							break
				Animation.TYPE_BLEND_SHAPE:
					var first := anim.blend_shape_track_interpolate(t, anim.track_get_key_time(t, 0))
					for k in range(1, count):
						if not is_equal_approx(anim.blend_shape_track_interpolate(t, anim.track_get_key_time(t, k)), first):
							same = false
							break
				_:
					same = false
		out[t] = 1 if same else 0
	_constant_cache[key] = out
	return out


## Se todas as trilhas usadas pela camada são constantes, guarda a pose de uma vez.
func _bake_static(layer: Layer) -> void:
	var constant := _constant_tracks(layer.anim)
	for tr in layer.tracks:
		for t in [tr.x, tr.y, tr.z]:
			if t >= 0 and constant[t] == 0:
				return
	for t in layer.shape_tracks:
		if constant[t] == 0:
			return
	layer.s_shape.resize(layer.shapes.size())
	for k in layer.shapes.size():
		layer.s_shape[k] = layer.anim.blend_shape_track_interpolate(layer.shape_tracks[k], 0.0)
	var count := layer.bones.size()
	layer.s_pos.resize(count)
	layer.s_rot.resize(count)
	layer.s_scl.resize(count)
	for k in count:
		var tr := layer.tracks[k]
		var b := layer.bones[k]
		var p := layer.anim.position_track_interpolate(tr.x, 0.0) if tr.x >= 0 else Vector3.ZERO
		var q := layer.anim.rotation_track_interpolate(tr.y, 0.0) if tr.y >= 0 else Quaternion.IDENTITY
		if layer.additive:
			p -= _rest_pos[b]
			q = _rest_rot[b].inverse() * q
		layer.s_pos[k] = p
		layer.s_rot[k] = q
		layer.s_scl[k] = layer.anim.scale_track_interpolate(tr.z, 0.0) if tr.z >= 0 else Vector3.ONE
	layer.static_pose = true


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
	if not _shape_index.is_empty() and SHAPE_GROUPS.has(group):
		var shape_map := _shape_track_map(anim)
		for shape in shape_map:
			var i: int = _shape_index.get(shape, -1)
			if i >= 0 and not skeleton_data.corrective_shapes.has(String(shape)):
				layer.shapes.append(i)
				layer.shape_tracks.append(shape_map[shape])
	_bake_static(layer)
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
	# `covered` = um bit por grupo (ORDER).
	var covered := 0
	for i in range(_layers.size() - 1, -1, -1):
		var l := _layers[i]
		if l.manual:
			continue
		var bit := 1 << int(ORDER.get(l.group, 30))
		if (l.target <= 0.0 and l.weight <= 0.0) or (covered & bit) != 0:
			_layers.remove_at(i)
			continue
		if l.weight >= 1.0 and l.target >= 1.0 and l.group != &"hands":
			covered |= bit


func _apply_layer(l: Layer) -> void:
	var w := l.weight
	if w <= 0.001:
		return
	if not l.shapes.is_empty():
		_apply_layer_shapes(l, w)
	if l.static_pose:
		_apply_static_layer(l, w)
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


## Blend shapes da camada: somados (aditiva: a piscada) ou misturados pelo peso.
func _apply_layer_shapes(l: Layer, w: float) -> void:
	for k in l.shapes.size():
		var v := l.s_shape[k] if l.static_pose else l.anim.blend_shape_track_interpolate(l.shape_tracks[k], l.time)
		var i := l.shapes[k]
		if l.additive:
			_shape_w[i] += v * w
		else:
			_shape_w[i] = lerpf(_shape_w[i], v, w)


## Mesmo que _apply_layer, com a pose parada já lida (Layer.static_pose).
func _apply_static_layer(l: Layer, w: float) -> void:
	var full := w >= 1.0
	for k in l.bones.size():
		var b := l.bones[k]
		var tr := l.tracks[k]
		if tr.y >= 0:
			var q := l.s_rot[k]
			if l.additive:
				_rot[b] = _rot[b] * Quaternion.IDENTITY.slerp(q, w)
			else:
				_rot[b] = q if full else _rot[b].slerp(q, w)
		if tr.x >= 0:
			var p := l.s_pos[k]
			if l.additive:
				_pos[b] += p * w
			else:
				_pos[b] = p if full else _pos[b].lerp(p, w)
		if tr.z >= 0 and not l.additive:
			_scl[b] = l.s_scl[k] if full else _scl[b].lerp(l.s_scl[k], w)


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
	_gesture_fade = 5.0
	_gesture_arms = 3 if arms == 0 else arms


## Gesto do corpo inteiro (quadril, coluna, ombros, braços, dedos e pernas; o rosto fica
## com set_face), por cima da animação parada em pé: o jeito de cada piloto comemorar ao
## ser escolhido (CharacterData.pick_gesture). A animação termina numa pose que fica
## parada por mais `hold` segundos; depois volta para a animação parada. Devolve a
## duração da animação (0 se ela não existe).
func play_body_gesture(gesture_name: StringName, hold := 1.5) -> float:
	if skeleton == null:
		return 0.0
	_fade_group(&"gesture", 10.0)
	var layer := _add_layer(gesture_name, &"whole_body", &"gesture")
	if layer == null:
		return 0.0
	layer.weight = 0.0
	layer.fade_speed = 7.0
	_gesture_hold = layer.anim.length + hold
	# O corpo inteiro volta mais devagar (os braços cruzados não passam pelo peito).
	_gesture_fade = 2.5
	_gesture_arms = 3
	return layer.anim.length


## Gesto de escolha do personagem (CharacterData.pick_gesture, corpo inteiro), com a
## expressão dele (pick_face, que pode ser animada: a fala), o objeto na mão (pick_prop) e o
## balão de fala (pick_shout). A pose final fica parada por `hold` s e depois tudo volta: o
## corpo para a animação parada, o rosto para a expressão padrão, objeto e balão somem.
## Devolve a duração da animação (0 = ele não tem gesto próprio).
func play_pick_gesture(hold := 1.5) -> float:
	if skeleton == null or data == null or data.pick_gesture == &"":
		return 0.0
	var length := play_body_gesture(data.pick_gesture, hold)
	if length <= 0.0:
		return 0.0
	set_face(data.pick_face, length + hold)
	_end_pick_extras()
	if data.pick_prop or data.pick_shout != "":
		_pick_extras = PickExtras.new()
		add_child(_pick_extras)
		_pick_extras.setup(self, _anims[data.pick_gesture], data)
	return length


func _end_pick_extras() -> void:
	if is_instance_valid(_pick_extras):
		_pick_extras.end()
	_pick_extras = null


## Desfaz o gesto (de braços ou do corpo inteiro) aos poucos.
func end_gesture(fade := 3.0) -> void:
	_fade_group(&"gesture", fade)
	_gesture_hold = 0.0
	_gesture_arms = 0
	_end_pick_extras()


## Posição global da mão (`side`: 0 = esquerda, 1 = direita) na pose atual, para prender
## coisas nela (a senha da Fila do tribunal). Vector3.INF sem esqueleto ou sem o osso.
func hand_global(side: int) -> Vector3:
	if skeleton == null:
		return Vector3.INF
	var hand := _arm_bones[side][2]
	if hand < 0:
		return Vector3.INF
	return skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin


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
	_shape_w.fill(0.0)
	for l in _layers:
		_apply_layer(l)
	_clamp_eyelids()
	if not _shape_w.is_empty():
		_apply_shapes()

	if mode == Mode.DRIVE:
		var fit := _fitting()
		if fit:
			# O pulinho entra antes: o quadril sobe com ele e os pés e as mãos ficam presos
			# no kart.
			_update_bounce(delta)
			_fit_seat()
		elif skeleton_data.drive_pose == &"":
			_pose_legs()
		if has_foot_targets and not _bike:
			_pose_legs_to_targets()
		_pose_arms(delta)
		if not fit:
			_update_bounce(delta)
	elif has_hand_targets:
		# Em pé segurando alguma coisa (a maleta da Antecipação Celer).
		_pose_arms(delta)
	_pose_followers()
	for i in _pos.size():
		skeleton.set_bone_pose_position(i, _pos[i])
		skeleton.set_bone_pose_rotation(i, _rot[i])
		skeleton.set_bone_pose_scale(i, _scl[i])
	for child in get_children():
		# O que está sumindo depois de end() também precisa do tempo.
		if child is PickExtras:
			(child as PickExtras).advance(delta)


## Ossos auxiliares: a fração `follow_share` do giro do osso seguido (a partir do
## repouso, como a restrição do Blender) e a mesma escala (o braço que estica).
func _pose_followers() -> void:
	var share := skeleton_data.follow_share
	for f in _followers:
		var turn := (_rest_rot[f.y].inverse() * _rot[f.y]).normalized()
		_rot[f.x] = _rest_rot[f.x] * Quaternion.IDENTITY.slerp(turn, share)
		_scl[f.x] = _scl[f.y]


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
			_fade_group(&"gesture", _gesture_fade)
			_gesture_arms = 0
			_end_pick_extras()
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
	# A inclinação para alcançar o volante entra aqui (coluna) ou no quadril (_fit_seat).
	var reach := 0.0 if _fitting() else _reach_lean
	_set_weight(_body_add, &"body_lean_forward", skeleton_data.lean_forward * (1.0 - _boost_lean) * (1.0 - back)
			+ maxf(-_pose.x, 0.0) + reach * (1.0 - back))
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
	var closed := skeleton_data.eyelid_closed_offset
	if closed != 0.0:
		for b in _masks[&"lids"]:
			_pos[b].y = clampf(_pos[b].y, _rest_pos[b].y + closed, _rest_pos[b].y)
		return
	# Pálpebras que giram: o giro em volta do eixo de fechar fica entre "bem aberta"
	# (metade do ângulo para o outro lado) e fechada.
	for b in _lid_axis:
		var axis: Vector3 = _lid_axis[b]
		var limit: float = _lid_closed[b]
		var d := _rest_rot[b].inverse() * _rot[b]
		if d.w < 0.0:
			d = -d
		var angle := 2.0 * atan2(Vector3(d.x, d.y, d.z).dot(axis), d.w)
		var clamped := clampf(angle, -0.5 * limit, limit)
		if not is_equal_approx(angle, clamped):
			_rot[b] = _rest_rot[b] * Quaternion(axis, clamped)


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
	var slide := 0.0 if _fitting() else _reach_slide
	model.position = _model_base + Vector3(0.0, _bounce * 0.05, slide) * _model_scale


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
	_aim_in(i, parent_basis, dir, weight)


## Como _aim, com a base global (sem escala) do pai já calculada.
func _aim_in(i: int, parent_basis: Basis, dir: Vector3, weight := 1.0) -> void:
	var current := parent_basis * Basis(_rot[i])
	var from := current.y.normalized()
	var to := dir.normalized()
	if from.dot(to) > 0.99999:
		return
	var aimed := Basis(Quaternion(from, to)) * current
	var local := (parent_basis.inverse() * aimed).get_rotation_quaternion()
	_rot[i] = _rot[i].slerp(local, weight)


## Monta a pose sentada no kart a partir das medidas do cockpit (veja fit_seat).
func _fitting() -> bool:
	return mode == Mode.DRIVE and skeleton_data.fit_seat and not cockpit.is_empty() and _hips_bone >= 0


func _fit_seat() -> void:
	var sd := skeleton_data
	var hips := _hips_bone
	var to_skel := _parent_to_skeleton()
	var from_skel := to_skel.affine_inverse()
	var s := _model_scale
	var corner := _cp_corner
	# Tronco: paralelo ao encosto e inclinado a partir do quadril para alcançar o volante.
	# Giro em volta do X do personagem: + = para a frente.
	var lean := deg_to_rad(sd.max_hip_lean) * _reach_lean
	var recline := 0.0 if _bike else _cp_back_angle - deg_to_rad(sd.pose_recline)
	var pitch := lean - recline
	_rotate_global(hips, Basis(Vector3.RIGHT, pitch))
	# O pescoço e a cabeça desfazem parte da inclinação (olhando a pista).
	if lean > 0.0:
		for b in _neck_bones:
			if b >= 0:
				_rotate_global(b, Basis(Vector3.RIGHT, -lean * sd.head_counter / _neck_bones.size()))
	# Quadril: o bumbum apoia no estofado com as costas no encosto (ou deslizou para a
	# frente); a inclinação gira em volta do ponto de apoio, embaixo da articulação.
	var fwd := Vector3.FORWARD
	var seat_point := corner + fwd * (sd.hip_ahead_of_back + _reach_slide) * s
	var hip_k := seat_point + (Vector3.UP * cos(pitch) + fwd * sin(pitch)) * sd.hip_above_seat * s
	var hip_s := to_skel * hip_k + Vector3(0.0, _bounce * 0.05, 0.0)
	var parent_g := _global(_parent[hips]) if _parent[hips] >= 0 else Transform3D.IDENTITY
	_pos[hips] = parent_g.affine_inverse() * hip_s
	if _bike:
		return
	var hips_g := parent_g * _local(hips)
	for side in 2:
		_fit_leg(side, hips_g, to_skel, from_skel)


## Perna esticada para a frente até o calcanhar apoiar no estofado ou no assoalho, o mais
## longe que ela alcança (`leg_extension`), sem a ponta do pé passar dos pedais.
func _fit_leg(side: int, hips_g: Transform3D, to_skel: Transform3D, from_skel: Transform3D) -> void:
	var chain := _leg_chain[side]
	var upleg := chain[0]
	var leg := chain[1]
	var foot := chain[2]
	if upleg < 0 or leg < 0 or foot < 0:
		return
	var sd := skeleton_data
	var s := _model_scale
	var parent_g := hips_g if _parent[upleg] == _hips_bone else _global(_parent[upleg])
	var hip_k := from_skel * (parent_g * _local(upleg)).origin
	var reach := (_rest_pos[leg].length() + _rest_pos[foot].length()) * s * sd.leg_extension
	var pitch := deg_to_rad(sd.foot_pitch)
	var lift := sd.ankle_lift * s
	var out := signf(hip_k.x) if hip_k.x != 0.0 else (-1.0 if side == 0 else 1.0)
	var x := out * maxf(absf(hip_k.x), _cp_foot_spread)
	var z_stop := _cp_foot_limit + sd.foot_length * s * cos(pitch)
	# O ponto mais à frente ao alcance: primeiro no estofado; se a perna passa da frente
	# dele, no assoalho. A ponta do pé não passa dos pedais (z_stop).
	var dx2 := (x - hip_k.x) * (x - hip_k.x)
	var z := hip_k.z
	var y := _cp_corner.y + lift
	var dy := y - hip_k.y
	var room := reach * reach - dx2 - dy * dy
	if room > 0.0:
		z = hip_k.z - sqrt(room)
	if z <= _cp_seat_front:
		var floor_y := _cp_floor + lift
		var fdy := floor_y - hip_k.y
		var froom := reach * reach - dx2 - fdy * fdy
		if froom > 0.0 and hip_k.z - sqrt(froom) < _cp_seat_front:
			y = floor_y
			z = hip_k.z - sqrt(froom)
		else:
			z = _cp_seat_front
	z = minf(maxf(z, z_stop), hip_k.z)
	var ankle := Vector3(x, y, z)
	var kp := sd.knee_pole
	var pole := (to_skel.basis * Vector3(out * kp.x, kp.y, -kp.z)).normalized()
	var foot_dir := (to_skel.basis * Vector3(out * 0.15, sin(pitch), -cos(pitch))).normalized()
	_leg_ik(parent_g, upleg, leg, foot, to_skel * ankle, pole, foot_dir)


## IK de dois ossos da perna (espaço do esqueleto; `parent_g` = transformação global do
## pai da coxa): joelho para o lado de `pole`, pé apontando para `foot_dir`.
func _leg_ik(parent_g: Transform3D, upleg: int, leg: int, foot: int, ankle: Vector3, pole: Vector3, foot_dir: Vector3) -> void:
	var upper_g := parent_g * _local(upleg)
	var hip := upper_g.origin
	var a := _rest_pos[leg].length()
	var b := _rest_pos[foot].length()
	var to := ankle - hip
	var dist := maxf(to.length(), 1e-5)
	var dir := to / dist
	var knee := hip + dir * a
	if dist < (a + b) * 0.9995:
		var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
		var side_dir := pole - dir * pole.dot(dir)
		if side_dir.length_squared() < 1e-8:
			side_dir = Vector3.UP - dir * dir.y
		knee = hip + (dir * cos_a + side_dir.normalized() * sqrt(1.0 - cos_a * cos_a)) * a
	_aim_in(upleg, parent_g.basis.orthonormalized(), knee - hip)
	upper_g = parent_g * _local(upleg)
	_aim_in(leg, upper_g.basis.orthonormalized(), ankle - (upper_g * _local(leg)).origin)
	var leg_g := upper_g * _local(leg)
	_aim_in(foot, leg_g.basis.orthonormalized(), foot_dir)


## Gira um osso no espaço do esqueleto (por cima da rotação que ele já tem).
func _rotate_global(i: int, rotation_basis: Basis) -> void:
	var parent_basis := Basis.IDENTITY
	if _parent[i] >= 0:
		parent_basis = _global(_parent[i]).basis.orthonormalized()
	_rot[i] = Quaternion(parent_basis.inverse() * rotation_basis * parent_basis).normalized() * _rot[i]


## Pernas esticadas até os alvos dos tornozelos (foot_target_l/r): IK de dois ossos a
## partir do quadril da pose, com o joelho dobrando no mesmo plano em que dobra na pose. O
## pé mantém o giro que tinha em relação à canela (na POSE_Kart, apoiado nos pedais).
func _pose_legs_to_targets() -> void:
	var to_skel := _parent_to_skeleton()
	for side in 2:
		var chain := _leg_chain[side]
		var upleg := chain[0]
		var leg := chain[1]
		var foot := chain[2]
		if upleg < 0 or leg < 0 or foot < 0:
			continue
		var parent_g := _global(_parent[upleg]) if _parent[upleg] >= 0 else Transform3D.IDENTITY
		var upper_g := parent_g * _local(upleg)
		var hip := upper_g.origin
		var knee_now := (upper_g * _local(leg)).origin
		var ankle := to_skel * (foot_target_l if side == 0 else foot_target_r)
		var a := _rest_pos[leg].length()
		var b := _rest_pos[foot].length()
		var to := ankle - hip
		var dist := maxf(to.length(), 1e-5)
		var dir := to / dist
		var pole := (knee_now - hip) - dir * (knee_now - hip).dot(dir)
		if pole.length_squared() < 1e-8:
			pole = to_skel.basis * Vector3.UP
		pole = pole.normalized()
		var knee := hip + dir * a
		if dist < (a + b) * 0.9995:
			var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
			knee = hip + (dir * cos_a + pole * sqrt(1.0 - cos_a * cos_a)) * a
		else:
			ankle = hip + dir * (a + b) * 0.9995
		_aim_in(upleg, parent_g.basis.orthonormalized(), knee - hip)
		upper_g = parent_g * _local(upleg)
		_aim_in(leg, upper_g.basis.orthonormalized(), ankle - (upper_g * _local(leg)).origin)


func _pose_legs() -> void:
	for side in 2:
		var thigh := _leg_bones[side * 2]
		var shin := _leg_bones[side * 2 + 1]
		if thigh < 0 or shin < 0:
			continue
		var s := 1.0 if side == 0 else -1.0
		var thigh_dir := skeleton_data.thigh_direction
		var shin_dir := skeleton_data.shin_direction
		_aim(thigh, Vector3(thigh_dir.x * s, thigh_dir.y, thigh_dir.z))
		_aim(shin, Vector3(shin_dir.x * s, shin_dir.y, shin_dir.z))


func _pose_arms(delta: float) -> void:
	var want_l := 0.0 if (_gesture_arms == 1 or _gesture_arms == 3) else 1.0
	var want_r := 0.0 if (_gesture_arms == 2 or _gesture_arms == 3) else 1.0
	_ik_l = move_toward(_ik_l, want_l, delta * 5.0)
	_ik_r = move_toward(_ik_r, want_r, delta * 5.0)
	if not has_hand_targets:
		return
	var to_skel := _parent_to_skeleton()
	var target_l := to_skel * hand_target_l
	var target_r := to_skel * hand_target_r
	var thumb_l := (to_skel.basis * hand_grip_l).normalized()
	var thumb_r := (to_skel.basis * hand_grip_r).normalized()
	var sd := skeleton_data
	if sd.bend_elbows:
		_update_reach_lean(delta)
		_arm_ik_bend(0, target_l, thumb_l, _ik_l)
		_arm_ik_bend(1, target_r, thumb_r, _ik_r)
		return
	var grip_r := Vector3(-sd.grip_point.x, sd.grip_point.y, sd.grip_point.z)
	_arm_ik(_arm_bones[0], target_l, thumb_l, sd.grip_point, _ik_l)
	_arm_ik(_arm_bones[1], target_r, thumb_r, grip_r, _ik_r)


## Braço reto do ombro ao punho, com a mão fechada em volta da barra: o eixo Z da mão
## (mindinho → polegar) segue a barra (`thumb`) e o vão do punho (`grip`, espaço da mão)
## fica em cima de `target`. Tudo no espaço do esqueleto.
##
## Braço elástico: só o osso do braço estica (escala em Y); o antebraço desfaz essa
## escala e fica do tamanho normal. Escala não uniforme num osso entorta os filhos que
## giram em relação a ele, então assim a mão pode dobrar no punho sem deformar.
func _arm_ik(arm: PackedInt32Array, target: Vector3, thumb: Vector3, grip: Vector3, weight: float) -> void:
	if weight <= 0.0:
		return
	var upper := arm[0]
	var fore := arm[1]
	var hand := arm[2]
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
	var max_stretch := (skeleton_data.max_arm_stretch * (upper_len + fore_len) - fore_len) / upper_len
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
	var max_bend := deg_to_rad(skeleton_data.max_wrist_bend_degrees)
	if bend > max_bend:
		y = arm_dir.slerp(y, max_bend / bend).normalized()
		z = (z - y * z.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


## Leva os ombros para perto do volante até os punhos ficarem ao alcance dos braços
## (só braços com cotovelo): primeiro o corpo desliza no banco, depois o tronco
## inclina. Mede com a pose deste quadro (média das duas mãos, para o corpo não ir e
## vir quando o volante gira) e corrige aos poucos; vale no quadro seguinte.
func _update_reach_lean(delta: float) -> void:
	var sd := skeleton_data
	if sd.max_reach_lean <= 0.0 and sd.max_seat_slide <= 0.0:
		_reach_lean = 0.0
		_reach_slide = 0.0
		return
	var fit := _fitting()
	var excess := 0.0
	var hands := 0.0
	var radius := 0.3
	for side in 2:
		var arm := _arm_bones[side]
		if arm[0] < 0 or arm[1] < 0 or arm[2] < 0 or is_nan(_arm_excess[side]):
			continue
		var weight := _ik_l if side == 0 else _ik_r
		if weight <= 0.0:
			continue
		excess += _arm_excess[side] * weight
		hands += weight
		# Distância do quadril ao ombro: quanto o ombro anda por unidade de inclinação.
		var shoulder := _global(arm[0]).origin
		var base := arm[0]
		while _parent[base] >= 0 and _parent[_parent[base]] >= 0:
			base = _parent[base]
		radius = maxf(_global(base).origin.distance_to(shoulder), 0.05)
	if hands <= 0.0:
		return
	excess /= hands
	var rate := 1.0 - exp(-10.0 * minf(delta, 0.1))
	if fit:
		# Sentado no banco do kart: primeiro inclina a partir do quadril (gira em volta do
		# apoio no estofado), depois desliza, sem o bumbum passar da frente do estofado.
		radius += sd.hip_above_seat
		var lean_unit := radius * deg_to_rad(sd.max_hip_lean)
		var room := (_cp_corner.z - _cp_seat_front) / maxf(_model_scale, 0.01) - 2.0 * sd.hip_ahead_of_back
		var max_slide := clampf(room, 0.0, sd.max_seat_slide)
		# Etapas: inclina até `first`, desliza até o máximo, inclina o resto.
		var first := sd.max_reach_lean * sd.lean_before_slide
		var lean := _reach_lean
		var slide := _reach_slide
		var left := excess
		if left > 0.0:
			var add := clampf(left / lean_unit, 0.0, maxf(first - lean, 0.0))
			lean += add
			left -= add * lean_unit
			var add_slide := clampf(left, 0.0, maxf(max_slide - slide, 0.0))
			slide += add_slide
			left -= add_slide
			lean = minf(lean + maxf(left, 0.0) / lean_unit, sd.max_reach_lean)
		else:
			# Sobrando braço: desfaz na ordem contrária.
			var cut := clampf(-left / lean_unit, 0.0, maxf(lean - first, 0.0))
			lean -= cut
			left += cut * lean_unit
			var cut_slide := clampf(-left, 0.0, slide)
			slide -= cut_slide
			left += cut_slide
			lean = maxf(lean + minf(left, 0.0) / lean_unit, 0.0)
		_reach_lean = lerpf(_reach_lean, lean, rate)
		_reach_slide = lerpf(_reach_slide, minf(slide, max_slide), rate)
		return
	# 1 de peso = a inclinação inteira da animação ≈ radius * ângulo de avanço do ombro.
	var lean_per_unit := radius * _lean_angle
	if excess > 0.0:
		var slide := minf(_reach_slide + excess, sd.max_seat_slide)
		var rest := excess - (slide - _reach_slide)
		_reach_slide = lerpf(_reach_slide, slide, rate)
		var lean := clampf(_reach_lean + rest / lean_per_unit, 0.0, sd.max_reach_lean)
		_reach_lean = lerpf(_reach_lean, lean, rate)
	else:
		# Sobrando braço: desfaz na ordem contrária (primeiro a inclinação).
		var lean := maxf(_reach_lean + excess / lean_per_unit, 0.0)
		var rest := excess + (_reach_lean - lean) * lean_per_unit
		_reach_lean = lerpf(_reach_lean, lean, rate)
		_reach_slide = lerpf(_reach_slide, maxf(_reach_slide + minf(rest, 0.0), 0.0), rate)


## Braço com cotovelo (IK de dois ossos): o ombro fica onde a pose do corpo deixou, o
## cotovelo dobra para o lado de `elbow_pole` e a mão fecha na barra com a pegada da
## pose sentada. Se o volante estiver longe demais, o braço fica reto e o osso do
## braço estica (no máximo `max_arm_stretch`, como no braço elástico).
func _arm_ik_bend(side: int, target: Vector3, thumb: Vector3, weight: float) -> void:
	if weight <= 0.0:
		return
	var arm := _arm_bones[side]
	var upper := arm[0]
	var fore := arm[1]
	var hand := arm[2]
	if upper < 0 or fore < 0 or hand < 0:
		return
	var sd := skeleton_data
	var mirror := Vector3(1.0 if side == 0 else -1.0, 1.0, 1.0)
	var grip := sd.grip_point * mirror
	var bar := (sd.grip_axis * mirror).normalized()
	if side == 1 and sd.grip_axis_right != Vector3.ZERO:
		grip = sd.grip_point_right
		bar = sd.grip_axis_right.normalized()
	var neutral := _neutral_hand[side]
	var a := _rest_pos[fore].length()
	var b := _rest_pos[hand].length()
	# O pai do braço não muda aqui: a transformação dele é calculada uma vez só.
	var parent_g := _global(_parent[upper]) if _parent[upper] >= 0 else Transform3D.IDENTITY
	var parent_basis := parent_g.basis.orthonormalized()
	var upper_g := parent_g * _local(upper)
	var shoulder := upper_g.origin
	# O lado do cotovelo acompanha o peito (inclinações e torções do corpo).
	var chest := parent_basis * _arm_parent_rest[side].inverse()
	var pole := chest * (sd.elbow_pole * mirror)

	# A mão depende do antebraço, que depende de onde fica o punho: algumas voltas.
	var fore_basis := (upper_g * _local(fore)).basis.orthonormalized()
	var hand_basis := Basis.IDENTITY
	var wrist := target
	var elbow := shoulder
	var stretch := 1.0
	for i in 3:
		hand_basis = _grip_hand_basis(fore_basis, thumb, neutral, bar)
		wrist = target - hand_basis * grip
		var to := wrist - shoulder
		var dist := maxf(to.length(), 1e-5)
		var dir := to / dist
		_arm_excess[side] = dist - (a + b) * REACH_EXTENSION
		if dist >= (a + b) * 0.9995:
			stretch = clampf((dist - b) / a, 1.0, sd.max_arm_stretch)
			elbow = shoulder + dir * a * stretch
		else:
			stretch = 1.0
			var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
			var side_dir := pole - dir * pole.dot(dir)
			if side_dir.length_squared() < 1e-8:
				side_dir = Vector3.DOWN - dir * dir.y
			side_dir = side_dir.normalized()
			elbow = shoulder + (dir * cos_a + side_dir * sqrt(1.0 - cos_a * cos_a)) * a
		var fore_dir := (wrist - elbow).normalized()
		fore_basis = Basis(Quaternion(fore_basis.y.normalized(), fore_dir)) * fore_basis

	_aim_in(upper, parent_basis, elbow - shoulder, weight)
	stretch = lerpf(1.0, stretch, weight)
	_scl[upper] = Vector3(1.0, stretch, 1.0)
	_scl[fore] = Vector3(1.0, 1.0 / stretch, 1.0)
	upper_g = parent_g * _local(upper)
	_aim_in(fore, upper_g.basis.orthonormalized(), wrist - (upper_g * _local(fore)).origin, weight)
	# Metade da torção que a mão precisa vai para o antebraço (o pulso não "embrulha").
	var fore_global := (upper_g * _local(fore)).basis.orthonormalized()
	var local := (fore_global.inverse() * hand_basis).get_rotation_quaternion()
	var d := neutral.inverse() * local
	var twist := 2.0 * atan2(d.y, d.w)
	twist = wrapf(twist, -PI, PI)
	_rot[fore] = _rot[fore] * Quaternion(Vector3.UP, twist * 0.5 * weight)
	fore_global = (upper_g * _local(fore)).basis.orthonormalized()
	local = (fore_global.inverse() * hand_basis).get_rotation_quaternion()
	_rot[hand] = _rot[hand].slerp(local, weight)


## Mão fechada na barra a partir da pegada da pose sentada (`neutral`, relativa ao
## antebraço): gira o mínimo para a barra (`bar`, espaço da mão) seguir `thumb`. A
## torção em volta do antebraço é livre (até 100°); a dobra do punho para no máximo
## `max_wrist_bend_degrees` (depois disso a mão fica um pouco atravessada na barra).
func _grip_hand_basis(fore_basis: Basis, thumb: Vector3, neutral: Quaternion, bar: Vector3) -> Basis:
	var pref := fore_basis * Basis(neutral)
	var now := (pref * bar).normalized()
	if now.dot(thumb) < -0.999:
		return pref
	var r := Quaternion(now, thumb)
	var f := fore_basis.y.normalized()
	var v := Vector3(r.x, r.y, r.z)
	var along := f * v.dot(f)
	var twist := Quaternion(along.x, along.y, along.z, r.w)
	twist = twist.normalized() if twist.length_squared() > 1e-9 else Quaternion.IDENTITY
	var swing := r * twist.inverse()
	var max_twist := deg_to_rad(100.0)
	if twist.get_angle() > max_twist:
		twist = Quaternion.IDENTITY.slerp(twist, max_twist / twist.get_angle())
	var max_bend := deg_to_rad(skeleton_data.max_wrist_bend_degrees)
	if swing.get_angle() > max_bend:
		swing = Quaternion.IDENTITY.slerp(swing, max_bend / swing.get_angle())
	return Basis(swing * twist) * pref


## Converte do espaço do nó pai deste personagem para o espaço do esqueleto.
func _parent_to_skeleton() -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return (transform * t).affine_inverse()
