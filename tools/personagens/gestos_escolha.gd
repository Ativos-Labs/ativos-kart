extends RefCounted
## Gestos de escolha: a animação do corpo inteiro que cada piloto faz ao ser escolhido na
## seleção de personagem (CharacterData.pick_gesture, tocada por
## CharacterRig.play_body_gesture). Usado por gerar_animacoes.gd, que grava as animações
## na biblioteca do personagem.
##
## Cada gesto é uma coreografia: curvas de parâmetros com chaves no tempo (deslocamento e
## giro do quadril, giro do peito, da cabeça e das clavículas, onde fica cada punho, para
## onde apontam os dedos, a palma e o cotovelo, e quanto cada dedo fecha). A cada quadro
## (30 por segundo) as curvas viram a pose:
## - o quadril desloca e gira; a coluna leva o giro do peito aos poucos; o pescoço e a
##   cabeça somam o giro da cabeça;
## - as pernas seguem por IK de dois ossos, com os pés plantados e o joelho para a frente;
## - cada braço por IK de dois ossos: o cotovelo aponta para o lado pedido e a dobra fica
##   no plano certo (na pose T a dobra do cotovelo é para a frente nos dois esqueletos); a
##   mão fica na orientação pedida e metade da torção vai para o antebraço;
## - os dedos fecham entre o repouso (mão aberta) e o punho fechado do volante.
##
## Pontos e direções ficam no espaço do personagem em repouso (+X = esquerda dele, +Y =
## cima, +Z = frente; metros, no modelo). Os dos braços podem seguir o peito ou a cabeça
## (`space`, com a curva `follow_l`/`follow_r` de 0 a 1 dizendo quanto): a mão no cabelo
## acompanha a cabeça que inclina, a guitarra acompanha o corpo. Os ângulos são em graus (x = para a frente, y = para a esquerda dele, z = para a
## direita dele). Vale para o esqueleto Mixamo (Jarbas, Henrique, Ulysses) e para o do
## Celerino (folha de papel).
##
## Com a curva `limp_l`/`limp_r` (0 a 1) a mão deixa de seguir os dedos e a palma pedidos e
## acompanha o antebraço, com o punho reto (mão solta, ao baixar o braço).
##
## O ponto de cada braço é o punho (`wrist_l`/`wrist_r`) ou, com `touch_l`/`touch_r`, o meio
## da palma encostando em alguma coisa (o cabelo, o quadril).
##
## Curvas: lista de chaves [tempo, valor] ou [tempo, valor, true]. A curva para em cada
## chave (entra e sai devagar), menos nas marcadas com true, por onde passa direto.

const FPS := 30.0
## Dedos meio fechados (mão solta): indicador, médio, anelar e mindinho, polegar.
const RELAXED := Vector4(0.3, 0.35, 0.4, 0.2)

## Esqueleto lido do modelo.
var sk: Skeleton3D
## Papéis dos ossos (veja mixamo() e celerino()).
var r: Dictionary
## Caminho das trilhas até o Skeleton3D (o mesmo das animações do modelo).
var prefix := ""
var parent := PackedInt32Array()
var rest_pos := PackedVector3Array()
var rest_rot: Array[Quaternion] = []
var rest_g: Array[Transform3D] = []
## Giro de cada osso de dedo na mão fechada (osso → Quaternion local).
var fist := {}
## Medidas do corpo para as coreografias (veja _measure).
var m := {}
## Pose do quadro atual (giros, posições e escalas locais).
var rot: Array[Quaternion] = []
var pos := PackedVector3Array()
var scl := PackedVector3Array()
var _g := {}
## O que conferir no último gesto: maior dobra do punho e torção do antebraço (graus) e
## quantos quadros o punho ou o pé não alcançaram o alvo.
var stats := {}


## Esqueleto Mixamo (Jarbas, Henrique, Ulysses).
static func mixamo() -> Dictionary:
	var out := {
		"hips": &"Hips", "spine": [&"Spine", &"Spine1", &"Spine2"], "share": [0.35, 0.7, 1.0],
		"neck": &"Neck", "head": &"Head", "neck_share": 0.4, "chest": &"Spine2",
		"clavicles": [&"LeftShoulder", &"RightShoulder"], "arms": [], "legs": [], "fingers": [],
		"hand_ref": [], "torso": [&"Hips", &"Spine", &"Spine1", &"Spine2"],
		"palm_depth": 0.015, "stretch": 1.0,
	}
	for side in ["Left", "Right"]:
		out.arms.append([StringName(side + "Arm"), StringName(side + "ForeArm"), StringName(side + "Hand")])
		out.legs.append([StringName(side + "UpLeg"), StringName(side + "Leg"), StringName(side + "Foot")])
		var fingers := []
		for pair in [["Index", 0], ["Middle", 1], ["Ring", 2], ["Pinky", 2], ["Thumb", 3]]:
			for k in range(1, 4):
				fingers.append([StringName("%sHand%s%d" % [side, pair[0], k]), pair[1]])
		out.fingers.append(fingers)
		out.hand_ref.append([StringName(side + "HandMiddle1"), StringName(side + "HandIndex1"),
				StringName(side + "HandPinky1")])
	return out


## Esqueleto do Celerino: o body_01 faz de quadril (carrega as pernas), o body_04 de
## pescoço (os olhos) e o body_05 de cabeça (as sobrancelhas). Sem clavículas nem anelar.
## Braço elástico, como no kart: um ponto fora do alcance estica o braço reto (até
## `stretch` vezes o comprimento), só o osso do braço (o antebraço desfaz a escala).
static func celerino() -> Dictionary:
	var out := {
		"hips": &"body_01", "spine": [&"body_02", &"body_03"], "share": [0.5, 1.0],
		"neck": &"body_04", "head": &"body_05", "neck_share": 0.6, "chest": &"body_03",
		"clavicles": [], "arms": [], "legs": [], "fingers": [], "hand_ref": [],
		"torso": [&"body_01", &"body_02", &"body_03"],
		"palm_depth": 0.03, "stretch": 2.4,
	}
	for side in ["L", "R"]:
		out.arms.append([StringName("upper_arm." + side), StringName("forearm." + side), StringName("hand." + side)])
		out.legs.append([StringName("thigh." + side), StringName("shin." + side), StringName("foot." + side)])
		var fingers := []
		for pair in [["index", 0], ["middle", 1], ["pinky", 2], ["thumb", 3]]:
			for k in range(1, 4):
				fingers.append([StringName("%s_0%d.%s" % [pair[0], k, side]), pair[1]])
		out.fingers.append(fingers)
		out.hand_ref.append([StringName("middle_01." + side), StringName("index_01." + side),
				StringName("pinky_01." + side)])
	return out


## `fist_pose` e `idle_pose`: giros locais de todos os ossos na mão fechada e na animação
## parada (braços caídos). `model`: o modelo instanciado (mede a malha).
func _init(skeleton: Skeleton3D, roles: Dictionary, track_prefix: String, fist_pose: Array[Quaternion],
		idle_pose: Array[Quaternion], model: Node) -> void:
	sk = skeleton
	r = roles
	prefix = track_prefix
	var n := sk.get_bone_count()
	parent.resize(n)
	for i in n:
		parent[i] = sk.get_bone_parent(i)
		var rest := sk.get_bone_rest(i)
		rest_pos.append(rest.origin)
		rest_rot.append(rest.basis.get_rotation_quaternion())
		if not rest.basis.get_scale().is_equal_approx(Vector3.ONE):
			push_warning("osso %s com escala %s no repouso" % [sk.get_bone_name(i), rest.basis.get_scale()])
	for i in n:
		rest_g.append(sk.get_bone_global_rest(i))
	for side in 2:
		for f in r.fingers[side]:
			var b := _b(f[0])
			fist[b] = fist_pose[b]
	_measure(idle_pose, model)


func _ones() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(rest_pos.size())
	out.fill(Vector3.ONE)
	return out


func _b(bone_name: StringName) -> int:
	var i := sk.find_bone(bone_name)
	if i < 0:
		push_error("osso não encontrado: %s" % bone_name)
	return i


## Transformação global (espaço do esqueleto) do osso na pose do quadro.
func glob(i: int) -> Transform3D:
	if i < 0:
		return Transform3D.IDENTITY
	if _g.has(i):
		return _g[i]
	var t := Transform3D(Basis(rot[i]) * Basis.from_scale(scl[i]), pos[i])
	if parent[i] >= 0:
		t = glob(parent[i]) * t
	_g[i] = t
	return t


## Põe o osso com esta base global (espaço do esqueleto).
func _put(i: int, basis: Basis) -> void:
	var parent_basis := glob(parent[i]).basis.orthonormalized()
	rot[i] = (parent_basis.inverse() * basis.orthonormalized()).get_rotation_quaternion()
	_g.clear()


# --- Medidas ---------------------------------------------------------------------------

## Ombros, alcance dos braços, os braços caídos da animação parada (ponto de partida dos
## gestos), a mão em repouso, a frente do peito e a caixa da cabeça e do quadril (malha).
func _measure(idle_pose: Array[Quaternion], model: Node) -> void:
	m.shoulder = []
	m.reach = []
	m.idle = []
	m.hand_rest = []
	m.hand_len = []
	for side in 2:
		var ch: Array = r.arms[side]
		var up := _b(ch[0])
		var fo := _b(ch[1])
		var ha := _b(ch[2])
		m.shoulder.append(rest_g[up].origin)
		m.reach.append(rest_g[up].origin.distance_to(rest_g[fo].origin) + rest_g[fo].origin.distance_to(rest_g[ha].origin))
		m.hand_rest.append(_hand_frame(side, func(i: int) -> Vector3: return rest_g[i].origin))
		m.hand_len.append(rest_g[ha].origin.distance_to(rest_g[_b(r.hand_ref[side][0])].origin))
	rot = idle_pose.duplicate()
	pos = rest_pos.duplicate()
	scl = _ones()
	_g.clear()
	for side in 2:
		var ch: Array = r.arms[side]
		var shoulder := glob(_b(ch[0])).origin
		var elbow := glob(_b(ch[1])).origin
		var wrist := glob(_b(ch[2])).origin
		var frame := _hand_frame(side, func(i: int) -> Vector3: return glob(i).origin)
		var line := (wrist - shoulder).normalized()
		var out := elbow - shoulder
		out -= line * out.dot(line)
		m.idle.append({"wrist": wrist, "fingers": frame.x, "palm": frame.z,
				"elbow": out.normalized() if out.length() > 1e-4 else Vector3.BACK})
	# Malha: caixa de cada grupo de ossos e a frente do tronco no meio do corpo.
	var groups := {"head": [r.head, r.neck], "hips": [r.hips], "torso": r.torso}
	var boxes := {}
	var front := -INF
	var head_side := 0.0
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin == null or mi.mesh == null:
			continue
		var names := []
		for b in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_bone(b)
			if bone < 0:
				bone = sk.find_bone(mi.skin.get_bind_name(b))
			names.append(StringName(sk.get_bone_name(bone)))
		var xf := _to_skeleton(mi)
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / verts.size()
			for i in verts.size():
				var best := -1
				var w := 0.0
				for k in per:
					if weights[i * per + k] > w:
						w = weights[i * per + k]
						best = bones[i * per + k]
				if best < 0:
					continue
				var bone_name: StringName = names[best]
				var v := xf * verts[i]
				for g in groups:
					if (groups[g] as Array).has(bone_name):
						boxes[g] = (boxes[g] as AABB).expand(v) if boxes.has(g) else AABB(v, Vector3.ZERO)
				if (r.torso as Array).has(bone_name) and absf(v.x) < 0.3 * absf(m.shoulder[0].x):
					front = maxf(front, v.z)
	m.head_box = boxes.get("head", AABB())
	m.hips_box = boxes.get("hips", AABB())
	m.torso_box = boxes.get("torso", AABB())
	m.chest_front = front
	print("medidas: ombro %s alcance %.3f punho parado %s | cabeça %s..%s | quadril |x| %.3f | frente do peito %.3f" % [
		_v(m.shoulder[0]), m.reach[0], _v(m.idle[0].wrist), _v(m.head_box.position), _v(m.head_box.end),
		m.hips_box.end.x, m.chest_front])


## Transformação de um nó do modelo para o espaço do esqueleto (o modelo não está na cena).
func _to_skeleton(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != sk:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	if n == sk:
		return t
	var s := Transform3D.IDENTITY
	n = sk
	while n != null:
		if n is Node3D:
			s = (n as Node3D).transform * s
		n = n.get_parent()
	return s.affine_inverse() * t


## Referencial da mão (espaço do esqueleto): x = dedos, y = lado do polegar, z = palma.
## `at` dá a posição global de um osso.
func _hand_frame(side: int, at: Callable) -> Basis:
	var ref: Array = r.hand_ref[side]
	var hand: Vector3 = at.call(_b(r.arms[side][2]))
	var fingers: Vector3 = ((at.call(_b(ref[0])) as Vector3) - hand).normalized()
	var thumb: Vector3 = (at.call(_b(ref[1])) as Vector3) - (at.call(_b(ref[2])) as Vector3)
	thumb = (thumb - fingers * thumb.dot(fingers)).normalized()
	var palm := fingers.cross(thumb) * (1.0 if side == 0 else -1.0)
	return Basis(fingers, thumb, palm)


## Base da mão com os dedos para `fingers` e a palma para `palm` (mesmo referencial).
func _hand_target(side: int, fingers: Vector3, palm: Vector3) -> Basis:
	var f := fingers.normalized()
	var p := (palm - f * palm.dot(f)).normalized()
	var thumb := p.cross(f) if side == 0 else f.cross(p)
	return Basis(f, thumb, p)


# --- Curvas ------------------------------------------------------------------------------

## Valor da curva `name` no tempo `t` (spline de Hermite: para nas chaves, menos nas
## marcadas como passagem, onde a velocidade é a da Catmull-Rom).
static func _val(c: Dictionary, name: String, t: float, default: Variant) -> Variant:
	var keys: Array = c.get(name, [])
	if keys.is_empty():
		return default
	if keys.size() == 1 or t <= keys[0][0]:
		return keys[0][1]
	if t >= keys[-1][0]:
		return keys[-1][1]
	var i := 0
	while keys[i + 1][0] < t:
		i += 1
	var t0: float = keys[i][0]
	var t1: float = keys[i + 1][0]
	var h := t1 - t0
	var s := (t - t0) / h
	var s2 := s * s
	var s3 := s2 * s
	var m0: Variant = _tangent(keys, i) * h
	var m1: Variant = _tangent(keys, i + 1) * h
	return keys[i][1] * (2.0 * s3 - 3.0 * s2 + 1.0) + m0 * (s3 - 2.0 * s2 + s) \
			+ keys[i + 1][1] * (-2.0 * s3 + 3.0 * s2) + m1 * (s3 - s2)


static func _tangent(keys: Array, i: int) -> Variant:
	var zero: Variant = keys[i][1] * 0.0
	if i == 0 or i == keys.size() - 1 or keys[i].size() < 3 or not keys[i][2]:
		return zero
	return (keys[i + 1][1] - keys[i - 1][1]) / (keys[i + 1][0] - keys[i - 1][0])


static func _euler(deg: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))


# --- Pose de um quadro ---------------------------------------------------------------------

func _pose(c: Dictionary, t: float) -> void:
	rot = rest_rot.duplicate()
	pos = rest_pos.duplicate()
	scl = _ones()
	_g.clear()
	# Quadril, coluna, pescoço e cabeça.
	var hips := _b(r.hips)
	var hips_b := _euler(_val(c, "hips_rot", t, Vector3.ZERO))
	var chest_rel: Vector3 = _val(c, "chest", t, Vector3.ZERO)
	var head_rel: Vector3 = _val(c, "head", t, Vector3.ZERO)
	var hips_offset: Vector3 = _val(c, "hips_pos", t, Vector3.ZERO)
	pos[hips] = glob(parent[hips]).affine_inverse() * (rest_g[hips].origin + hips_offset)
	_g.clear()
	_put(hips, hips_b * rest_g[hips].basis)
	var spine: Array = r.spine
	for k in spine.size():
		var b := _b(spine[k])
		_put(b, hips_b * _euler(chest_rel * float(r.share[k])) * rest_g[b].basis)
	var chest_b := hips_b * _euler(chest_rel)
	var neck := _b(r.neck)
	var head := _b(r.head)
	_put(neck, chest_b * _euler(head_rel * float(r.neck_share)) * rest_g[neck].basis)
	_put(head, chest_b * _euler(head_rel) * rest_g[head].basis)
	# Clavículas: (sobe, para a frente) em graus.
	var clavicles: Array = r.clavicles
	for side in clavicles.size():
		var b := _b(clavicles[side])
		var sg := 1.0 if side == 0 else -1.0
		var v: Vector3 = _val(c, "clav_" + ("l" if side == 0 else "r"), t, Vector3.ZERO)
		var lift := Basis(Vector3.UP, -sg * deg_to_rad(v.y)) * Basis(Vector3.BACK, sg * deg_to_rad(v.x))
		_put(b, chest_b * lift * rest_g[b].basis)
	for side in 2:
		_leg(side, _val(c, "foot_" + ("l" if side == 0 else "r"), t, Vector3.ZERO))
	var spaces: Array = c.get("space", ["root", "root"])
	for side in 2:
		_arm(side, c, t, spaces[side])
		var curl: Vector4 = _val(c, "curl_" + ("l" if side == 0 else "r"), t, RELAXED)
		for f in r.fingers[side]:
			var b := _b(f[0])
			rot[b] = rest_rot[b].slerp(fist[b], clampf(curl[f[1]], 0.0, 1.0))
		_g.clear()


## Perna com o pé plantado (repouso + `offset`), joelho para a frente.
func _leg(side: int, offset: Vector3) -> void:
	var ch: Array = r.legs[side]
	var up := _b(ch[0])
	var lo := _b(ch[1])
	var ft := _b(ch[2])
	var hip_rest := rest_g[up].origin
	var knee_rest := rest_g[lo].origin
	var ankle_rest := rest_g[ft].origin
	var a := hip_rest.distance_to(knee_rest)
	var b := knee_rest.distance_to(ankle_rest)
	var hip := glob(up).origin
	var ankle := ankle_rest + offset
	var to := ankle - hip
	if to.length() > (a + b) * 0.9995:
		stats.leg_short = stats.get("leg_short", 0) + 1
	var d := minf(to.length(), (a + b) * 0.9995)
	var dir := to.normalized()
	var pole := Vector3(0.15 * (1.0 if side == 0 else -1.0), 0.0, 1.0)
	var cos_h := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var knee := hip + dir * a * cos_h + (pole - dir * pole.dot(dir)).normalized() * a * sqrt(1.0 - cos_h * cos_h)
	var ankle_p := hip + dir * d
	_put(up, _swing(knee_rest - hip_rest, knee - hip, pole) * rest_g[up].basis)
	_put(lo, _swing(ankle_rest - knee_rest, ankle_p - knee, pole) * rest_g[lo].basis)
	_put(ft, rest_g[ft].basis)


## Braço por IK de dois ossos (veja o começo do arquivo).
func _arm(side: int, c: Dictionary, t: float, space_name: String) -> void:
	var s := "l" if side == 0 else "r"
	var idle: Dictionary = m.idle[side]
	var space := Transform3D.IDENTITY
	if space_name == "chest":
		var b := _b(r.chest)
		space = glob(b) * rest_g[b].affine_inverse()
	elif space_name == "head":
		var b := _b(r.head)
		space = glob(b) * rest_g[b].affine_inverse()
	# Quanto o ponto segue o peito ou a cabeça (0 = fica no espaço do personagem).
	space = Transform3D.IDENTITY.interpolate_with(space, _val(c, "follow_" + s, t, 1.0))
	var wrist: Vector3 = space * (_val(c, "wrist_" + s, t, idle.wrist) as Vector3)
	var fingers: Vector3 = space.basis * (_val(c, "fingers_" + s, t, idle.fingers) as Vector3)
	var palm: Vector3 = space.basis * (_val(c, "palm_" + s, t, idle.palm) as Vector3)
	var pole: Vector3 = space.basis * (_val(c, "elbow_" + s, t, idle.elbow) as Vector3)
	# Com a curva `touch_*`, o ponto é o meio da palma (encostando em alguma coisa) e o
	# punho fica atrás dele.
	if c.has("touch_" + s):
		var f := fingers.normalized()
		var p := (palm - f * palm.dot(f)).normalized()
		wrist = space * (_val(c, "touch_" + s, t, Vector3.ZERO) as Vector3) - f * float(m.hand_len[side]) * 0.5 \
				- p * float(r.palm_depth)

	var ch: Array = r.arms[side]
	var up := _b(ch[0])
	var fo := _b(ch[1])
	var ha := _b(ch[2])
	var a := rest_g[up].origin.distance_to(rest_g[fo].origin)
	var b := rest_g[fo].origin.distance_to(rest_g[ha].origin)
	var shoulder := glob(up).origin
	var to := wrist - shoulder
	var dist := maxf(to.length(), 1e-4)
	var dir := to / dist
	var stretch := 1.0
	if dist > (a + b) * 0.999:
		var max_upper := (float(r.stretch) * (a + b) - b) / a
		if max_upper > 1.0:
			stretch = clampf((dist - b) / a, 1.0, max_upper)
			stats.stretch = maxf(stats.get("stretch", 1.0), (a * stretch + b) / (a + b))
		if dist > a * stretch + b:
			stats.arm_short = stats.get("arm_short", 0) + 1
		dist = minf(dist, a * stretch + b) if stretch > 1.0 else (a + b) * 0.999
		wrist = shoulder + dir * dist
	var side_dir := pole - dir * pole.dot(dir)
	if side_dir.length_squared() < 1e-8:
		side_dir = Vector3.DOWN - dir * dir.y
	side_dir = side_dir.normalized()
	var elbow := shoulder + dir * a * stretch
	if stretch <= 1.0:
		var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
		elbow = shoulder + (dir * cos_a + side_dir * sqrt(1.0 - cos_a * cos_a)) * a
	# Braço: a dobra (para onde o antebraço sai) fica onde estava a frente na pose T.
	var up_dir := (elbow - shoulder).normalized()
	var bend := (wrist - elbow) - up_dir * (wrist - elbow).dot(up_dir)
	bend = bend.normalized() if bend.length() > 1e-4 else -side_dir
	var dir0 := (rest_g[fo].origin - rest_g[up].origin).normalized()
	var bend0 := (Vector3.BACK - dir0 * dir0.z).normalized()
	_put(up, _frame(up_dir, bend) * _frame(dir0, bend0).inverse() * rest_g[up].basis)
	# Esticado, o braço fica reto: o antebraço gira só em volta do próprio eixo e não entorta.
	scl[up] = Vector3(1.0, stretch, 1.0)
	scl[fo] = Vector3(1.0, 1.0 / stretch, 1.0)
	_g.clear()
	# Antebraço: gira em volta da dobra do cotovelo.
	var fo_dir := (wrist - elbow).normalized()
	var fo_dir0 := (rest_g[ha].origin - rest_g[fo].origin).normalized()
	var turn := _frame(fo_dir, up_dir.cross(bend)) * _frame(fo_dir0, dir0.cross(bend0)).inverse()
	# Mão: a orientação pedida; metade da torção em volta do antebraço vai para ele.
	var hand_b := _hand_target(side, fingers, palm) * (m.hand_rest[side] as Basis).inverse() * rest_g[ha].basis
	var natural := turn * rest_g[ha].basis
	# Mão solta (`limp_*` = 1): segue o antebraço, com o punho reto.
	var limp: float = _val(c, "limp_" + s, t, 0.0)
	if limp > 0.0:
		hand_b = Basis(hand_b.get_rotation_quaternion().slerp(natural.get_rotation_quaternion(), clampf(limp, 0.0, 1.0)))
	var d := (hand_b * natural.inverse()).get_rotation_quaternion()
	var twist := wrapf(2.0 * atan2(Vector3(d.x, d.y, d.z).dot(fo_dir), d.w), -PI, PI)
	var fore_turn := Basis(fo_dir, twist * 0.5) * turn
	_put(fo, fore_turn * rest_g[fo].basis)
	_put(ha, hand_b)
	var bend_left := (hand_b * (fore_turn * rest_g[ha].basis).inverse()).get_rotation_quaternion()
	if bend_left.w < 0.0:
		bend_left = -bend_left
	stats.wrist = maxf(stats.get("wrist", 0.0), rad_to_deg(bend_left.get_angle()))
	stats.twist = maxf(stats.get("twist", 0.0), absf(rad_to_deg(twist * 0.5)))


## Giro que leva o osso da direção `from` para `to`, sem torcer em volta de `pole`.
static func _swing(from: Vector3, to: Vector3, pole: Vector3) -> Basis:
	return _frame(to, pole) * _frame(from, pole).inverse()


static func _frame(dir: Vector3, pole: Vector3) -> Basis:
	var y := dir.normalized()
	var z := (pole - y * pole.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


# --- Animação -------------------------------------------------------------------------------

## Animação `gesture_name` (veja GESTURES), amostrada a 30 quadros por segundo. Sem loop:
## o último quadro é a pose que fica parada.
func bake(gesture_name: StringName) -> Animation:
	var c: Dictionary
	match gesture_name:
		&"gesture_point_forward":
			c = _point_forward()
		&"gesture_arms_crossed":
			c = _arms_crossed()
		&"gesture_hair_fix":
			c = _hair_fix()
		&"gesture_air_guitar":
			c = _air_guitar()
		_:
			push_error("gesto desconhecido: %s" % gesture_name)
			return null
	stats = {}
	var length: float = c.length
	var count := int(round(length * FPS))
	var bones: Array[int] = [_b(r.hips), _b(r.neck), _b(r.head)]
	for list in [r.spine, r.clavicles]:
		for bone_name in list:
			bones.append(_b(bone_name))
	for side in 2:
		for list in [r.arms[side], r.legs[side]]:
			for bone_name in list:
				bones.append(_b(bone_name))
		for f in r.fingers[side]:
			bones.append(_b(f[0]))
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_NONE
	var hips := _b(r.hips)
	var pt := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pt, NodePath("%s:%s" % [prefix, sk.get_bone_name(hips)]))
	var tracks := {}
	bones.sort()
	for b in bones:
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath("%s:%s" % [prefix, sk.get_bone_name(b)]))
		tracks[b] = tr
	# Braço elástico: escala do braço e do antebraço.
	var scaled := {}
	if float(r.stretch) > 1.0:
		for side in 2:
			for k in 2:
				var b := _b(r.arms[side][k])
				var tr := anim.add_track(Animation.TYPE_SCALE_3D)
				anim.track_set_path(tr, NodePath("%s:%s" % [prefix, sk.get_bone_name(b)]))
				scaled[b] = tr
	for k in count + 1:
		var t := minf(k / FPS, length)
		_pose(c, t)
		anim.position_track_insert_key(pt, t, pos[hips])
		for b in bones:
			anim.rotation_track_insert_key(tracks[b], t, rot[b])
		for b in scaled:
			anim.scale_track_insert_key(scaled[b], t, scl[b])
	print("%s: %.2f s, %d quadros, %d ossos | punho dobra até %.0f°, antebraço torce até %.0f°, braço estica até %.2f× | punho fora do alcance em %d quadros, pé em %d" % [
		gesture_name, length, count + 1, bones.size(), stats.get("wrist", 0.0), stats.get("twist", 0.0),
		stats.get("stretch", 1.0), stats.get("arm_short", 0), stats.get("leg_short", 0)])
	return anim


# --- Coreografias ---------------------------------------------------------------------------

static func _mx(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Meio da palma na pose parada (ponto de partida das curvas `touch_*`).
func _idle_touch(side: int) -> Vector3:
	var idle: Dictionary = m.idle[side]
	return idle.wrist + (idle.fingers as Vector3) * float(m.hand_len[side]) * 0.5 + (idle.palm as Vector3) * float(r.palm_depth)


## Henrique: aponta para a frente (para quem está escolhendo). Puxa o braço direito para
## trás (antecipação, o tronco gira para a direita), estica o braço de uma vez com o
## indicador, passa um pouco e volta; o tronco vai junto e a cabeça fica olhando para a
## frente. Depois dá mais uma "cutucada" e segura a pose. O braço esquerdo fica solto ao
## lado do corpo (segue o peito) e balança um pouco para trás quando o direito estica.
## O braço aponta um pouco para o lado e para cima: bem de frente para a câmera o dedo
## sumiria atrás da mão.
func _point_forward() -> Dictionary:
	var il: Dictionary = m.idle[0]
	var ir: Dictionary = m.idle[1]
	var sh: Vector3 = m.shoulder[1]
	var reach: float = m.reach[1]
	var aim := Vector3(-0.45, 0.25, 1.0).normalized()
	var point := sh + aim * reach * 0.94
	var cocked := sh + Vector3(-0.03, -0.09, 0.1)
	var pointing := Vector4(0.0, 1.0, 1.0, 0.55)
	return {
		"length": 2.0,
		"space": ["chest", "root"],
		"hips_pos": [[0.0, Vector3.ZERO], [0.3, Vector3(0.0, -0.007, -0.012)], [0.5, Vector3(0.0, -0.004, 0.012)],
				[0.75, Vector3(0.0, -0.004, 0.008)]],
		"hips_rot": [[0.0, Vector3.ZERO], [0.3, Vector3(0, -7, 0)], [0.52, Vector3(0, 6, 0)], [0.8, Vector3(0, 5, 0)]],
		"chest": [[0.0, Vector3.ZERO], [0.3, Vector3(-4, -10, 0)], [0.5, Vector3(7, 10, -2)], [0.68, Vector3(4, 8, -1)],
				[1.12, Vector3(4, 8, -1)], [1.24, Vector3(7, 9, -1)], [1.42, Vector3(4, 8, -1)]],
		"head": [[0.0, Vector3.ZERO], [0.32, Vector3(4, 9, -2)], [0.52, Vector3(-5, -13, 4)], [0.75, Vector3(-3, -12, 6)],
				[1.2, Vector3(-3, -12, 7)], [1.3, Vector3(-6, -13, 7)], [1.5, Vector3(-3, -12, 8)]],
		"clav_r": [[0.0, Vector3.ZERO], [0.3, Vector3(5, -8, 0)], [0.5, Vector3(4, 10, 0)], [0.7, Vector3(3, 8, 0)]],
		"wrist_r": [[0.0, ir.wrist], [0.28, cocked], [0.4, sh + aim * reach * 0.55, true], [0.48, point + aim * 0.015],
				[0.62, point], [1.12, point], [1.22, point - aim * 0.04], [1.32, point + aim * 0.01], [1.45, point]],
		"fingers_r": [[0.0, ir.fingers], [0.28, Vector3(-0.1, 0.4, 1.0)], [0.46, aim + Vector3(0, 0.05, 0)], [0.62, aim]],
		"palm_r": [[0.0, ir.palm], [0.28, Vector3(1.0, 0.0, -0.2)], [0.46, Vector3(0.5, -1.0, 0.0)]],
		"elbow_r": [[0.0, ir.elbow], [0.28, Vector3(-0.6, -0.3, -1.0)], [0.46, Vector3(-0.5, -1.0, 0.0)]],
		"curl_r": [[0.0, RELAXED], [0.25, Vector4(0.65, 0.8, 0.85, 0.55)], [0.4, pointing]],
		# Braço esquerdo solto: vai um pouco para a frente na antecipação e para trás no
		# esticão do direito, e assenta.
		"wrist_l": [[0.0, il.wrist], [0.3, il.wrist + Vector3(0.0, 0.006, 0.025)],
				[0.52, il.wrist + Vector3(0.004, 0.01, -0.035)], [0.85, il.wrist + Vector3(0.0, 0.003, -0.01)]],
	}


## Jarbas: cruza os braços, se achando. Respira fundo (ombros sobem), os braços vêm pela
## frente e cruzam na frente do peito (o esquerdo por cima, a mão em cima do antebraço
## direito; a direita escondida embaixo do braço esquerdo), o peito estufa, o queixo sobe e
## a cabeça vira de lado; o peso vai para a perna esquerda. Depois olha de volta para a
## frente com um aceno curto de cabeça e fica assim.
func _arms_crossed() -> Dictionary:
	var il: Dictionary = m.idle[0]
	var ir: Dictionary = m.idle[1]
	var front: float = m.chest_front
	var sh_y: float = m.shoulder[0].y
	var top_l := Vector3(0.03, sh_y - 0.06, front + 0.085)
	var low_r := Vector3(-0.03, sh_y - 0.1, front + 0.06)
	return {
		"length": 2.1,
		"space": ["chest", "chest"],
		"hips_pos": [[0.0, Vector3.ZERO], [0.2, Vector3(0.0, -0.002, 0.0)], [0.6, Vector3(0.018, -0.008, -0.004)],
				[0.9, Vector3(0.016, -0.007, -0.004)]],
		"hips_rot": [[0.0, Vector3.ZERO], [0.6, Vector3(0, 4, 3)], [0.9, Vector3(0, 3, 2.5)]],
		"chest": [[0.0, Vector3.ZERO], [0.22, Vector3(-3, 0, 0)], [0.62, Vector3(-9, -3, -3)], [0.85, Vector3(-6, -2, -2.5)],
				[2.1, Vector3(-6, -2, -2.5)]],
		"head": [[0.0, Vector3.ZERO], [0.25, Vector3(-2, 0, 0)], [0.6, Vector3(-11, 20, -4)], [0.95, Vector3(-10, 18, -5)],
				[1.25, Vector3(-9, 3, -4)], [1.4, Vector3(-3, 2, -4)], [1.6, Vector3(-10, 2, -4)]],
		"clav_l": [[0.0, Vector3.ZERO], [0.22, Vector3(6, 0, 0)], [0.6, Vector3(2, 6, 0)], [0.85, Vector3(0, 5, 0)]],
		"clav_r": [[0.0, Vector3.ZERO], [0.22, Vector3(6, 0, 0)], [0.6, Vector3(2, 6, 0)], [0.85, Vector3(0, 5, 0)]],
		"wrist_l": [[0.0, il.wrist], [0.22, il.wrist + Vector3(0.0, 0.03, 0.07)],
				[0.42, Vector3(0.1, sh_y - 0.09, front + 0.1), true], [0.6, top_l + Vector3(0, 0.012, 0)], [0.8, top_l]],
		"fingers_l": [[0.0, il.fingers], [0.22, Vector3(0.2, -0.7, 1.0)], [0.6, Vector3(-1.0, -0.15, -0.25)]],
		"palm_l": [[0.0, il.palm], [0.22, Vector3(-1.0, 0.0, 0.0)], [0.6, Vector3(0.0, -0.8, -0.6)]],
		"elbow_l": [[0.0, il.elbow], [0.3, Vector3(1.0, -0.5, -0.3)], [0.6, Vector3(1.0, -0.6, 0.1)]],
		"curl_l": [[0.0, RELAXED], [0.6, Vector4(0.25, 0.3, 0.35, 0.2)]],
		"wrist_r": [[0.0, ir.wrist], [0.22, ir.wrist + Vector3(0.0, 0.03, 0.07)],
				[0.42, Vector3(-0.1, sh_y - 0.13, front + 0.08), true], [0.6, low_r + Vector3(0, 0.01, 0)], [0.8, low_r]],
		"fingers_r": [[0.0, ir.fingers], [0.22, Vector3(-0.2, -0.7, 1.0)], [0.6, Vector3(1.0, 0.25, -0.35)]],
		"palm_r": [[0.0, ir.palm], [0.22, Vector3(1.0, 0.0, 0.0)], [0.6, Vector3(0.0, 0.3, -1.0)]],
		"elbow_r": [[0.0, ir.elbow], [0.3, Vector3(-1.0, -0.5, -0.3)], [0.6, Vector3(-1.0, -0.6, 0.1)]],
		"curl_r": [[0.0, RELAXED], [0.6, Vector4(0.55, 0.6, 0.65, 0.5)]],
	}


## Ulysses: arruma o cabelo com a mão direita. A mão sobe pela frente do ombro, a palma
## encosta na frente do cabelo, no alto da cabeça, e desliza para trás por cima da orelha
## até a nuca, com os dedos deitados no cabelo e a cabeça inclinando para o lado da mão
## (o queixo sobe quando a mão vai para trás). A mão volta pelo ar, passa de novo mais
## curto e desce; no fim ele olha para a frente de queixo erguido. A mão segue a cabeça
## enquanto está no cabelo (`follow_r`).
func _hair_fix() -> Dictionary:
	var il: Dictionary = m.idle[0]
	var ir: Dictionary = m.idle[1]
	var box: AABB = m.head_box
	var side := box.end.x
	var top := box.end.y
	var front := box.end.z
	var back := box.position.z
	# Pontos da palma no cabelo (lado direito da cabeça, espaço da cabeça em repouso).
	var start := Vector3(-(side + 0.006), top - 0.065, front - 0.06)
	var middle := Vector3(-(side + 0.016), top - 0.08, (front + back) * 0.5 - 0.03)
	var finish := Vector3(-(side + 0.006), top - 0.11, back + 0.03)
	var start2 := Vector3(-(side + 0.01), top - 0.085, front - 0.065)
	var finish2 := Vector3(-(side + 0.01), top - 0.13, back + 0.045)
	var lay_front := Vector3(0.3, 0.15, -0.95)
	var lay_mid := Vector3(0.3, 0.0, -1.0)
	var lay_back := Vector3(0.25, -0.5, -0.85)
	var comb := Vector4(0.15, 0.2, 0.25, 0.1)
	return {
		"length": 2.4,
		"space": ["chest", "head"],
		"hips_pos": [[0.0, Vector3.ZERO], [0.5, Vector3(0.012, -0.005, 0.0)], [2.4, Vector3(0.012, -0.005, 0.0)]],
		"hips_rot": [[0.0, Vector3.ZERO], [0.5, Vector3(0, 0, 2)], [2.4, Vector3(0, 0, 2)]],
		"chest": [[0.0, Vector3.ZERO], [0.5, Vector3(-2, -6, 4)], [1.0, Vector3(-4, -4, 3)], [1.4, Vector3(-2, -6, 4)],
				[1.75, Vector3(-4, -4, 3)], [2.15, Vector3(-3, 2, -1)]],
		"head": [[0.0, Vector3.ZERO], [0.45, Vector3(6, -5, 12)], [0.75, Vector3(0, -3, 9), true], [1.0, Vector3(-8, -2, 6)],
				[1.15, Vector3(-6, -2, 5)], [1.4, Vector3(3, -4, 10)], [1.7, Vector3(-9, 0, 5)], [2.1, Vector3(-9, 8, -3)],
				[2.4, Vector3(-7, 7, -3)]],
		"clav_r": [[0.0, Vector3.ZERO], [0.45, Vector3(14, 4, 0)], [1.0, Vector3(12, -2, 0)], [1.4, Vector3(14, 4, 0)],
				[1.75, Vector3(12, -2, 0)], [2.15, Vector3.ZERO]],
		"follow_r": [[0.0, 0.0], [0.45, 1.0], [1.8, 1.0], [2.3, 0.0]],
		"limp_r": [[0.0, 0.0], [1.75, 0.0], [1.98, 1.0], [2.12, 1.0], [2.3, 0.0]],
		"touch_r": [[0.0, _idle_touch(1)], [0.14, Vector3(-(side + 0.05), top - 0.45, front + 0.03), true],
				[0.28, Vector3(-(side + 0.06), top - 0.2, front + 0.02), true],
				[0.45, start], [0.75, middle, true], [1.0, finish],
				[1.12, finish + Vector3(-0.025, 0.005, 0.0)], [1.27, start2 + Vector3(-0.03, 0.0, -0.02), true],
				[1.4, start2], [1.7, finish2], [1.95, Vector3(-(side + 0.06), top - 0.36, back + 0.12), true],
				[2.3, _idle_touch(1)]],
		"fingers_r": [[0.0, ir.fingers], [0.14, Vector3(0.0, 0.7, 0.7)], [0.28, Vector3(0.1, 1.0, 0.2)], [0.45, lay_front],
				[0.75, lay_mid, true], [1.0, lay_back], [1.27, Vector3(0.3, 0.3, -0.9)], [1.4, lay_front], [1.7, lay_back],
				[1.95, Vector3(0.15, 0.5, -0.8), true], [2.15, Vector3(0.1, -0.6, -0.3), true], [2.3, ir.fingers]],
		"palm_r": [[0.0, ir.palm], [0.14, Vector3(1.0, 0.0, -0.2)], [0.28, Vector3(1.0, 0.0, -0.3)], [0.45, Vector3(1.0, -0.45, 0.1)],
				[1.0, Vector3(1.0, -0.2, 0.4)], [1.4, Vector3(1.0, -0.45, 0.1)], [1.7, Vector3(1.0, -0.2, 0.4)],
				[1.95, Vector3(1.0, 0.0, 0.2)], [2.3, ir.palm]],
		"elbow_r": [[0.0, ir.elbow], [0.14, Vector3(-0.8, -0.6, -0.3)], [0.28, Vector3(-1.0, -0.4, 0.1)],
				[0.45, Vector3(-1.0, 0.25, 0.35)],
				[1.0, Vector3(-1.0, 0.2, 0.0)], [1.4, Vector3(-1.0, 0.25, 0.35)], [1.7, Vector3(-1.0, 0.2, 0.0)],
				[1.95, Vector3(-0.6, -1.0, -0.4)], [2.3, ir.elbow]],
		"curl_r": [[0.0, RELAXED], [0.4, comb], [1.0, Vector4(0.3, 0.35, 0.4, 0.2)], [1.35, comb],
				[1.7, Vector4(0.3, 0.35, 0.4, 0.2)], [2.3, RELAXED]],
		"wrist_l": [[0.0, il.wrist], [2.4, il.wrist]],
	}


## Celerino: guitarra invisível. Pega a guitarra (abaixa o corpo, dobra os joelhos e
## inclina para trás), toca rápido com a mão direita balançando a cabeça no ritmo e a
## esquerda correndo pelo braço da guitarra; estica o braço direito bem alto (braço
## elástico), gira o braço pelo lado num moinho até uma palhetada grande, e termina com o
## braço esticado para cima fazendo chifrinho.
func _air_guitar() -> Dictionary:
	var il: Dictionary = m.idle[0]
	var ir: Dictionary = m.idle[1]
	var sl: Vector3 = m.shoulder[0]
	var sr: Vector3 = m.shoulder[1]
	var front: float = m.chest_front
	var top: float = m.head_box.end.y
	# Ponto da palhetada (em frente à barriga, do lado direito dele) e do braço da guitarra.
	var strum := Vector3(sr.x + 0.19, sr.y - 0.2, front + 0.17)
	var neck_dir := Vector3(1.0, 0.32, -0.05).normalized()
	var fret := Vector3(sl.x + 0.32, sl.y + 0.03, front + 0.15)
	var claw := Vector4(0.7, 0.75, 0.8, 0.5)
	var c := {
		"length": 2.6,
		"space": ["chest", "chest"],
		"wrist_l": [[0.0, il.wrist], [0.28, fret]],
		"fingers_l": [[0.0, il.fingers], [0.28, Vector3(0.1, 0.75, 0.65)]],
		"palm_l": [[0.0, il.palm], [0.28, Vector3(-0.5, 0.35, -0.6)]],
		"elbow_l": [[0.0, il.elbow], [0.28, Vector3(0.1, -1.0, -0.5)]],
		"curl_l": [[0.0, RELAXED], [0.28, claw]],
		"elbow_r": [[0.0, ir.elbow], [0.28, Vector3(-1.0, -0.3, -0.5)], [1.26, Vector3(-1.0, -0.3, -0.5)],
				[1.66, Vector3(-1.0, -0.3, -0.3)], [1.9, Vector3(-1.0, -0.5, -0.2)]],
	}
	var wrist_r := [[0.0, ir.wrist]]
	var fingers_r := [[0.0, ir.fingers]]
	var palm_r := [[0.0, ir.palm]]
	var curl_r := [[0.0, RELAXED]]
	var hips_pos := [[0.0, Vector3.ZERO]]
	var head := [[0.0, Vector3.ZERO], [0.28, Vector3(-4, 0, 0)]]
	var wrist_l: Array = c.wrist_l
	var curl_l: Array = c.curl_l
	# Palhetadas: sobe e desce a cada 0,24 s; o corpo afunda e a cabeça bate a cada duas.
	var beat := 0.24
	var t0 := 0.3
	for k in 4:
		var t := t0 + k * beat
		wrist_r.append([t, strum + Vector3(0.0, 0.065, 0.0)])
		wrist_r.append([t + beat * 0.5, strum + Vector3(0.015, -0.075, 0.01)])
		fingers_r.append([t, Vector3(0.6, -0.5, 0.35)])
		fingers_r.append([t + beat * 0.5, Vector3(0.35, -0.95, 0.05)])
		palm_r.append([t, Vector3(0.0, 0.3, -1.0)])
		curl_r.append([t, Vector4(0.6, 0.8, 0.85, 0.6)])
		hips_pos.append([t + beat * 0.5, Vector3(0.0, -0.1, 0.0)])
		hips_pos.append([t + beat, Vector3(0.0, -0.075, 0.0)])
		if k % 2 == 0:
			head.append([t + beat * 0.5, Vector3(18, 0, 4)])
			head.append([t + beat * 1.5, Vector3(-8, 0, -4)])
		# A mão esquerda corre pelo braço da guitarra e os dedos mexem.
		var slide: float = [0.0, -0.07, -0.02, -0.09][k]
		wrist_l.append([t + beat * 0.5, fret + neck_dir * slide])
		curl_l.append([t + beat * 0.25, Vector4(0.85, 0.55, 0.8, 0.5)])
		curl_l.append([t + beat * 0.75, Vector4(0.55, 0.85, 0.6, 0.45)])
	# Moinho: estica o braço bem alto, gira pelo lado e desce numa palhetada grande; depois
	# estica para cima com o chifrinho.
	wrist_r.append_array([[1.42, Vector3(sr.x - 0.05, top, front + 0.05)],
			[1.52, Vector3(sr.x - 0.5, sr.y + 0.3, front + 0.3), true],
			[1.62, strum + Vector3(0.03, -0.12, 0.02)], [1.72, strum + Vector3(0.0, -0.1, 0.03)],
			[1.95, Vector3(sr.x - 0.15, top - 0.05, front + 0.12)], [2.15, Vector3(sr.x - 0.15, top - 0.07, front + 0.12)]])
	fingers_r.append_array([[1.42, Vector3(0.0, 1.0, 0.2)], [1.52, Vector3(-0.7, -0.3, 0.6), true],
			[1.62, Vector3(0.4, -0.95, 0.0)], [1.95, Vector3(-0.15, 1.0, 0.15)]])
	palm_r.append_array([[1.42, Vector3(0.0, 0.0, 1.0)], [1.62, Vector3(0.0, 0.3, -1.0)], [1.95, Vector3(0.0, 0.0, 1.0)]])
	curl_r.append_array([[1.42, Vector4(0.6, 0.8, 0.85, 0.6)], [1.8, Vector4(0.6, 0.8, 0.85, 0.6)],
			[1.95, Vector4(0.0, 1.0, 0.0, 1.0)]])
	hips_pos.append_array([[1.42, Vector3(0.0, -0.05, 0.0)], [1.64, Vector3(0.0, -0.14, 0.0)],
			[1.95, Vector3(0.0, -0.06, 0.0)], [2.2, Vector3(0.0, -0.07, 0.0)]])
	head.append_array([[1.3, Vector3(-4, 0, 0)], [1.42, Vector3(-14, 0, 0)], [1.64, Vector3(20, 0, 0)],
			[1.95, Vector3(-14, 4, 5)], [2.3, Vector3(-12, 4, 5)]])
	wrist_l.append_array([[1.4, fret], [1.64, fret + Vector3(0.0, -0.04, 0.0)], [1.95, fret + Vector3(0.02, 0.05, 0.0)]])
	c.wrist_r = wrist_r
	c.fingers_r = fingers_r
	c.palm_r = palm_r
	c.curl_r = curl_r
	c.hips_pos = hips_pos
	c.head = head
	c.chest = [[0.0, Vector3.ZERO], [0.28, Vector3(-8, 4, 0)], [1.26, Vector3(-8, 4, 0)], [1.42, Vector3(-16, 6, 0)],
			[1.64, Vector3(8, 0, 0)], [1.95, Vector3(-14, 2, 3)], [2.3, Vector3(-12, 2, 3)]]
	return c


func _v(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]
