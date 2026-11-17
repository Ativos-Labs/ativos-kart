extends SceneTree
## Monta as animações que o jogo usa para o Jarbas e grava em
## res://assets/models/personagens/jarbas_animacoes.res (AnimationLibrary), com os
## mesmos nomes das do Celerino (idle, gesture_*, hand_*, face_*, body_*, eyes_look_*,
## blink) e mais as poses sentadas drive_kart e drive_moto.
##
## - Expressões, piscada e poses sentadas: copiadas das animações do modelo
##   (EXP_*, ANIM_Piscar, POSE_Kart, POSE_Moto), só com os ossos de cada grupo.
## - Gestos, respiração, olhar e formatos de mão: transferidos das animações do
##   Celerino. Os dois estão em pose T, de frente para +Z, com a palma para baixo: cada
##   osso do braço (e da coluna, e os olhos) recebe o mesmo giro, no espaço do
##   personagem, que o osso equivalente do Celerino. Os dedos dobram na mesma
##   proporção (0 = esticado, 1 = a mão fechada da POSE_Kart, que segura o volante).
##   Diferença: na pose T o Celerino tem a palma para a frente e o Jarbas para baixo.
##   Nos gestos a mão do Jarbas gira junto (polegar e palma para os mesmos lados que
##   os do Celerino), com o giro espalhado por braço, antebraço e mão; na respiração
##   (braços caídos) não, e as palmas ficam viradas para o corpo, como numa pessoa.
## - Inclinações do corpo: geradas aqui, espalhadas pela coluna, com o pescoço
##   compensando um pouco para o Jarbas continuar olhando para a frente.
##
## Rode de novo depois de mudar o jarbas.glb (build_jarbas.py) ou as animações do
## Celerino:
##   Godot --headless --path . -s res://tools/personagens/gerar_animacoes.gd

const JARBAS := "res://assets/models/personagens/jarbas.glb"
const CELERINO := "res://assets/models/personagens/celerino.glb"
const OUT := "res://assets/models/personagens/jarbas_animacoes.res"
## Duração das poses paradas (um quadro, como as do Celerino).
const POSE_LEN := 1.0 / 24.0
## Amostragem das animações com movimento.
const FPS := 30.0

const ARM_MAP := {
	&"upper_arm.L": &"LeftArm", &"forearm.L": &"LeftForeArm", &"hand.L": &"LeftHand",
	&"upper_arm.R": &"RightArm", &"forearm.R": &"RightForeArm", &"hand.R": &"RightHand",
}
const SPINE_MAP := {&"body_02": &"Spine", &"body_03": &"Spine1", &"body_04": &"Spine2", &"body_05": &"Neck"}
const EYE_MAP := {&"eye.L": &"Olho.L", &"eye.R": &"Olho.R"}
## Dedo do Celerino → dedos do Jarbas (o Celerino não tem anelar: segue o médio).
const FINGER_MAP := {"index": ["Index"], "middle": ["Middle", "Ring"], "pinky": ["Pinky"], "thumb": ["Thumb"]}
## Quanto do giro palma-para-baixo → palma-para-a-frente cada osso do braço leva.
const ROLL_SHARE := {&"LeftArm": 0.25, &"LeftForeArm": 0.75, &"LeftHand": 1.0,
		&"RightArm": 0.25, &"RightForeArm": 0.75, &"RightHand": 1.0}
## Animações transferidas sem alinhar a mão (braços caídos, palmas para o corpo).
const NO_HAND_ALIGN := [&"idle", &"gesture_arms_down"]

const FACE := [&"Canto_Boca.L", &"Canto_Boca.R", &"Labio_Sup", &"Labio_Inf", &"Mandibula",
		&"Palpebra_Inf.L", &"Palpebra_Inf.R", &"Palpebra_Sup.L", &"Palpebra_Sup.R",
		&"Sobrancelha_Ext.L", &"Sobrancelha_Ext.R", &"Sobrancelha_Int.L", &"Sobrancelha_Int.R"]
const LIDS := [&"Palpebra_Inf.L", &"Palpebra_Inf.R", &"Palpebra_Sup.L", &"Palpebra_Sup.R"]
const FACE_CLIPS := {
	&"face_neutral": &"EXP_Neutro", &"face_happy": &"EXP_Alegria", &"face_surprised": &"EXP_Surpresa",
	&"face_angry": &"EXP_Raiva", &"face_confused": &"EXP_Tristeza", &"face_sad": &"EXP_Tristeza",
	&"face_eepy": &"EXP_Olhos_Fechados", &"face_sleeping": &"EXP_Olhos_Fechados",
}
const DRIVE_CLIPS := {&"drive_kart": &"POSE_Kart", &"drive_moto": &"POSE_Moto"}
const RETARGET_CLIPS := [&"idle", &"gesture_arms_down", &"gesture_thumbs_up", &"gesture_point",
	&"gesture_cheer", &"gesture_shrug", &"gesture_jazz_hands", &"gesture_angry_fists",
	&"gesture_hands_on_cheeks", &"gesture_wave",
	&"eyes_center", &"eyes_look_left", &"eyes_look_right", &"eyes_look_up", &"eyes_look_down"]
const HAND_SHAPES := [&"open", &"relaxed", &"fist", &"point", &"thumbs_up", &"peace"]
## Inclinações do corpo: eixo no espaço do personagem (+X = esquerda dele, +Z = frente),
## ângulo total na coluna e quanto o pescoço e a cabeça desfazem (fração do ângulo).
const BODY_CLIPS := {
	&"body_lean_forward": [Vector3.RIGHT, 30.0, 0.8],
	&"body_lean_back": [Vector3.LEFT, 15.0, 0.3],
	&"body_bend_left": [Vector3.BACK, 20.0, 0.35],
	&"body_bend_right": [Vector3.FORWARD, 20.0, 0.35],
	&"body_twist_left": [Vector3.UP, 30.0, 0.0],
	&"body_twist_right": [Vector3.DOWN, 30.0, 0.0],
}
const SPINE := [&"Spine", &"Spine1", &"Spine2"]
const SPINE_SHARE := [0.3, 0.35, 0.35]


## Esqueleto lido do modelo: nomes, pais e repouso.
class Skel:
	var sk: Skeleton3D
	var index := {}
	var parent := PackedInt32Array()
	var rest_rot: Array[Quaternion] = []
	var rest_global: Array[Basis] = []
	var depth := PackedInt32Array()

	func _init(skeleton: Skeleton3D) -> void:
		sk = skeleton
		var n := sk.get_bone_count()
		parent.resize(n)
		depth.resize(n)
		for i in n:
			index[StringName(sk.get_bone_name(i))] = i
			parent[i] = sk.get_bone_parent(i)
			rest_rot.append(sk.get_bone_rest(i).basis.get_rotation_quaternion())
		rest_global = globals(rest_rot)
		for i in n:
			var d := 0
			var p := parent[i]
			while p >= 0:
				d += 1
				p = parent[p]
			depth[i] = d

	func bone(name: StringName) -> int:
		return index.get(name, -1)

	## Bases globais (espaço do esqueleto) para rotações locais `rots`.
	func globals(rots: Array[Quaternion]) -> Array[Basis]:
		var out: Array[Basis] = []
		out.resize(rots.size())
		var done := PackedByteArray()
		done.resize(rots.size())
		for i in rots.size():
			_global(i, rots, out, done)
		return out

	func _global(i: int, rots: Array[Quaternion], out: Array[Basis], done: PackedByteArray) -> Basis:
		if done[i]:
			return out[i]
		var b := Basis(rots[i])
		if parent[i] >= 0:
			b = _global(parent[i], rots, out, done) * b
		out[i] = b
		done[i] = 1
		return b

	## Pose (rotações locais de todos os ossos) de uma animação no tempo `t`.
	func sample(anim: Animation, t: float) -> Array[Quaternion]:
		var rots := rest_rot.duplicate()
		for tr in anim.get_track_count():
			if anim.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
				continue
			var b := bone(StringName(anim.track_get_path(tr).get_concatenated_subnames()))
			if b >= 0:
				rots[b] = anim.rotation_track_interpolate(tr, t)
		return rots

	## Rotações locais que deixam os ossos de `wanted` (osso → base global) nessas
	## bases, a partir de `rots` (os outros ossos ficam como estão).
	func solve(rots: Array[Quaternion], wanted: Dictionary) -> Array[Quaternion]:
		var out := rots.duplicate()
		var bones := wanted.keys()
		bones.sort_custom(func(a: int, b: int) -> bool: return depth[a] < depth[b])
		for b in bones:
			var parent_global := Basis.IDENTITY
			if parent[b] >= 0:
				parent_global = globals(out)[parent[b]]
			out[b] = (parent_global.inverse() * (wanted[b] as Basis)).get_rotation_quaternion()
		return out


var _jarbas: Node
var _celerino: Node
var j: Skel
var c: Skel
var j_anims := {}
var c_anims := {}
var _prefix := ""
var _frames := 0
## Giro (espaço do personagem) que leva a mão do Jarbas em repouso para a orientação
## da mão do Celerino em repouso, por lado ("L"/"R").
var _hand_align := {}


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	_run()
	_jarbas.free()
	_celerino.free()
	return true


func _run() -> void:
	_jarbas = (load(JARBAS) as PackedScene).instantiate()
	_celerino = (load(CELERINO) as PackedScene).instantiate()
	j = Skel.new(_jarbas.find_child("Skeleton3D", true, false) as Skeleton3D)
	c = Skel.new(_celerino.find_child("Skeleton3D", true, false) as Skeleton3D)
	for pair in [[_jarbas, j_anims], [_celerino, c_anims]]:
		var player := (pair[0] as Node).find_child("AnimationPlayer", true, false) as AnimationPlayer
		for anim_name in player.get_animation_list():
			(pair[1] as Dictionary)[StringName(anim_name)] = player.get_animation(anim_name)
	var sample_anim: Animation = j_anims[&"EXP_Neutro"]
	_prefix = str(sample_anim.track_get_path(0)).split(":")[0]
	_check_rest_poses()
	for side in ["L", "R"]:
		var long_side := "Left" if side == "L" else "Right"
		var kc := _hand_frame(c, "hand." + side, "middle_01." + side, "index_01." + side, "pinky_01." + side)
		var kj := _hand_frame(j, long_side + "Hand", long_side + "HandMiddle1", long_side + "HandIndex1", long_side + "HandPinky1")
		_hand_align[side] = (kc * kj.inverse()).get_rotation_quaternion()
		print("alinhamento da mão %s: %.0f°" % [side, rad_to_deg((_hand_align[side] as Quaternion).get_angle())])

	var lib := AnimationLibrary.new()
	# Expressões, piscada e poses sentadas do próprio modelo.
	for clip in FACE_CLIPS:
		lib.add_animation(clip, _copy(j_anims[FACE_CLIPS[clip]], FACE))
	lib.add_animation(&"face_smiling", _mixed_face(&"EXP_Alegria", {&"Mandibula": [&"EXP_Neutro", 1.0]}))
	lib.add_animation(&"face_screaming", _mixed_face(&"EXP_Surpresa", {&"Mandibula": [&"EXP_Boca_Aberta", 1.0]}))
	lib.add_animation(&"blink", _copy(j_anims[&"ANIM_Piscar"], LIDS))
	var drive_bones: Array = []
	for i in j.parent.size():
		var name := StringName(j.sk.get_bone_name(i))
		if not FACE.has(name) and not EYE_MAP.values().has(name) and j.parent[i] >= 0:
			drive_bones.append(name)
	for clip in DRIVE_CLIPS:
		lib.add_animation(clip, _copy(j_anims[DRIVE_CLIPS[clip]], drive_bones))

	# Do Celerino.
	for clip in RETARGET_CLIPS:
		lib.add_animation(clip, _retarget(c_anims[clip], not NO_HAND_ALIGN.has(clip)))
	for shape in HAND_SHAPES:
		for side in ["L", "R"]:
			var clip := StringName("hand_%s_%s" % [shape, side])
			lib.add_animation(clip, _retarget(c_anims[clip]))

	# Inclinações.
	for clip in BODY_CLIPS:
		var spec: Array = BODY_CLIPS[clip]
		lib.add_animation(clip, _body_bend(spec[0], deg_to_rad(spec[1]), spec[2]))

	var err := ResourceSaver.save(lib, OUT)
	print("gravado %s (%d animações): %s" % [OUT, lib.get_animation_list().size(), error_string(err)])


## Confere a premissa da transferência: braços em pose T, palma para baixo, nos dois.
func _check_rest_poses() -> void:
	# Palma: +X do osso da mão no Celerino, -Z no Jarbas (esqueleto Mixamo).
	for pair in [[c, &"hand.L", &"upper_arm.L", Vector3.RIGHT], [j, &"LeftHand", &"LeftArm", Vector3.BACK]]:
		var s: Skel = pair[0]
		var hand: Basis = s.rest_global[s.bone(pair[1])]
		var arm: Basis = s.rest_global[s.bone(pair[2])]
		print("%-10s braço %s  mão: dedos %s palma %s" % [pair[1], _v(arm.y.normalized()),
				_v(hand.y.normalized()), _v((hand * (pair[3] as Vector3)).normalized())])


## Referencial da mão em repouso (espaço do esqueleto): dedos, lado do polegar e palma,
## pelas posições dos ossos (vale para qualquer esqueleto).
func _hand_frame(s: Skel, hand: String, middle: String, index: String, pinky: String) -> Basis:
	var pos := func(name: String) -> Vector3:
		var b := s.bone(StringName(name))
		var t := Transform3D.IDENTITY
		while b >= 0:
			t = s.sk.get_bone_rest(b) * t
			b = s.parent[b]
		return t.origin
	var hand_p: Vector3 = pos.call(hand)
	var fingers := ((pos.call(middle) as Vector3) - hand_p).normalized()
	var thumb_side := (pos.call(index) as Vector3) - (pos.call(pinky) as Vector3)
	thumb_side = (thumb_side - fingers * thumb_side.dot(fingers)).normalized()
	return Basis(fingers, thumb_side, fingers.cross(thumb_side))


# --- Cópias das animações do modelo ------------------------------------------------------

## Cópia de `src` só com as trilhas dos ossos de `bones`.
func _copy(src: Animation, bones: Array) -> Animation:
	var anim := src.duplicate(true) as Animation
	for t in range(anim.get_track_count() - 1, -1, -1):
		var bone_name := StringName(anim.track_get_path(t).get_concatenated_subnames())
		if not bones.has(bone_name):
			anim.remove_track(t)
	return anim


## Expressão `base` com alguns ossos trocados: osso → [animação, quanto do giro dela].
func _mixed_face(base: StringName, swaps: Dictionary) -> Animation:
	var anim := _copy(j_anims[base], FACE)
	for bone_name in swaps:
		var b := j.bone(bone_name)
		var src: Animation = j_anims[swaps[bone_name][0]]
		var amount: float = swaps[bone_name][1]
		var q: Quaternion = j.sample(src, 0.0)[b]
		var d := j.rest_rot[b].inverse() * q
		if amount != 1.0 and d.get_angle() > 1e-3:
			q = j.rest_rot[b] * Quaternion(d.get_axis().normalized(), d.get_angle() * amount)
		var path := NodePath("%s:%s" % [_prefix, bone_name])
		var t := anim.find_track(path, Animation.TYPE_ROTATION_3D)
		if t < 0:
			t = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, path)
		for k in range(anim.track_get_key_count(t) - 1, -1, -1):
			anim.track_remove_key(t, k)
		anim.rotation_track_insert_key(t, 0.0, q)
	return anim


# --- Transferência do Celerino --------------------------------------------------------------

## `align`: gira a mão (e o braço) do Jarbas para a palma e o polegar ficarem como os
## do Celerino.
func _retarget(src: Animation, align := true) -> Animation:
	var times := PackedFloat32Array([0.0])
	if src.length > POSE_LEN * 1.5:
		times.clear()
		var count := int(round(src.length * FPS))
		for k in count + (0 if src.loop_mode != Animation.LOOP_NONE else 1):
			times.append(minf(k / FPS, src.length))
	var fist_c := {}
	for side in ["L", "R"]:
		var fist := c.sample(c_anims[StringName("hand_fist_" + side)], 0.0)
		fist_c[side] = fist
	var fist_j := j.sample(j_anims[&"POSE_Kart"], 0.0)

	var frames: Array[Array] = []
	var used := {}
	var touched := _touched_bones(src)
	for t in times:
		var cp := c.sample(src, t)
		var cg := c.globals(cp)
		var wanted := {}
		for maps in [ARM_MAP, SPINE_MAP, EYE_MAP]:
			for cb_name in maps:
				var cb := c.bone(cb_name)
				var jb := j.bone(maps[cb_name])
				if cb < 0 or jb < 0 or not touched.has(cb):
					continue
				var delta := cg[cb] * c.rest_global[cb].inverse()
				var roll := Quaternion.IDENTITY
				var jb_name: StringName = maps[cb_name]
				if align and ROLL_SHARE.has(jb_name):
					var side := "L" if String(jb_name).begins_with("Left") else "R"
					roll = Quaternion.IDENTITY.slerp(_hand_align[side], ROLL_SHARE[jb_name])
				wanted[jb] = delta * Basis(roll) * j.rest_global[jb]
		var rots := j.solve(j.rest_rot, wanted)
		for jb in wanted:
			used[jb] = true
		# Dedos: a mesma proporção de dobra.
		for side in ["L", "R"]:
			var long_side := "Left" if side == "L" else "Right"
			for finger in FINGER_MAP:
				for k in range(1, 4):
					var cb := c.bone(StringName("%s_0%d.%s" % [finger, k, side]))
					if cb < 0 or not touched.has(cb):
						continue
					var ratio := _curl_ratio(c.rest_rot[cb], cp[cb], (fist_c[side] as Array)[cb])
					for jf in FINGER_MAP[finger]:
						var jb := j.bone(StringName("%sHand%s%d" % [long_side, jf, k]))
						if jb < 0:
							continue
						rots[jb] = j.rest_rot[jb].slerp(fist_j[jb], ratio)
						used[jb] = true
		frames.append(rots)

	var anim := Animation.new()
	anim.length = src.length if times.size() > 1 else POSE_LEN
	anim.loop_mode = src.loop_mode
	var bones := used.keys()
	bones.sort()
	for jb in bones:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [_prefix, j.sk.get_bone_name(jb)]))
		for f in frames.size():
			anim.rotation_track_insert_key(t, times[f], (frames[f] as Array)[jb])
	return anim


## Ossos que têm trilha na animação do Celerino (mesmo parados no repouso: a mão
## aberta de um gesto é o repouso dos dedos e precisa valer por cima da mão fechada do
## volante). O CharacterRig só usa os ossos do grupo de cada camada.
func _touched_bones(src: Animation) -> Dictionary:
	var out := {}
	for tr in src.get_track_count():
		if src.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
			continue
		var b := c.bone(StringName(src.track_get_path(tr).get_concatenated_subnames()))
		if b >= 0:
			out[b] = true
	return out


## Quanto o dedo dobrou em relação à mão fechada (0 = esticado, 1 = fechado): o giro do
## repouso até a pose, projetado no eixo do giro do repouso até o punho fechado.
func _curl_ratio(rest: Quaternion, pose: Quaternion, fist: Quaternion) -> float:
	var full := rest.inverse() * fist
	var full_angle := full.get_angle()
	if full_angle < 0.01:
		return 0.0
	var d := rest.inverse() * pose
	if d.w < 0.0:
		d = -d
	var angle_along := 2.0 * atan2(Vector3(d.x, d.y, d.z).dot(full.get_axis()), d.w)
	return clampf(angle_along / full_angle, 0.0, 1.0)


# --- Inclinações do corpo ----------------------------------------------------------------

## Giro de `angle` em volta de `axis` (espaço do personagem) espalhado pela coluna; o
## pescoço e a cabeça desfazem `head_counter` do ângulo.
func _body_bend(axis: Vector3, angle: float, head_counter: float) -> Animation:
	var wanted := {}
	var acc := 0.0
	for k in SPINE.size():
		acc += SPINE_SHARE[k]
		var b := j.bone(SPINE[k])
		wanted[b] = Basis(axis, angle * acc) * j.rest_global[b]
	var neck := j.bone(&"Neck")
	var head := j.bone(&"Head")
	wanted[neck] = Basis(axis, angle * (1.0 - head_counter * 0.6)) * j.rest_global[neck]
	wanted[head] = Basis(axis, angle * (1.0 - head_counter)) * j.rest_global[head]
	var rots := j.solve(j.rest_rot, wanted)
	var anim := Animation.new()
	anim.length = POSE_LEN
	for b in wanted:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [_prefix, j.sk.get_bone_name(b)]))
		anim.rotation_track_insert_key(t, 0.0, rots[b])
	return anim


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
