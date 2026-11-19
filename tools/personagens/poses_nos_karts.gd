extends SceneTree
## Confere a pose de um piloto em cada veículo (sem janela): monta o kart com o piloto,
## deixa a pose assentar com o volante reto e virado todo para cada lado e imprime o
## quanto ele inclinou e deslizou no banco, o erro das mãos no volante, quanto o braço
## esticou, o ângulo de cotovelo e joelho (180° = reto), a distância do joelho ao aro e
## onde ficaram os pés (assoalho, estofado, no limite dos pedais). Grava também um glb
## por veículo com a cena posada (malhas deformadas na CPU), para ver de fora do Godot
## (render_poses.py, no Blender).
##
##   Godot --headless --path . -s res://tools/personagens/poses_nos_karts.gd -- <pasta> <personagem>
##
## <personagem> = nome do .tres em res://data/personagens/ (henrique, jarbas, ulysses...).

var _f := 0
var _out := "/tmp"
var _who := "henrique"


func _process(_d: float) -> bool:
	_f += 1
	if _f < 2:
		return false
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "/tmp"
	_who = args[1] if args.size() > 1 else "henrique"
	_run()
	return true


func _run() -> void:
	CharacterMesh.enabled = false
	var gs: Node = root.get_node("GameState")
	var data: CharacterData = load("res://data/personagens/%s.tres" % _who)
	for k: KartData in gs.karts:
		var kv := KartVisual.new()
		root.add_child(kv)
		kv.setup(k, data)
		var rig := kv.driver
		rig.set_process(false)
		var out := {}
		for steer in [0.0, 1.0, -1.0]:
			for i in 150:
				kv.update_motion(1.0 / 30.0, 0.0, steer)
				rig._process(1.0 / 30.0)
			out[steer] = _measure(kv, rig, k)
		# Volta para o volante reto e grava a cena.
		for i in 150:
			kv.update_motion(1.0 / 30.0, 0.0, 0.0)
			rig._process(1.0 / 30.0)
		_report(k, data, out)
		_export(kv, "%s/%s_%s.glb" % [_out, _who, k.resource_path.get_file().get_basename()])
		kv.free()
	CharacterMesh.clear_cache()


func _kart_point(kv: KartVisual, rig: CharacterRig, bone: int, local := Vector3.ZERO) -> Vector3:
	var sk := rig.skeleton
	return kv.to_local(sk.global_transform * (sk.get_bone_global_pose(bone) * local))


func _measure(kv: KartVisual, rig: CharacterRig, k: KartData) -> Dictionary:
	var sd := rig.skeleton_data
	var r := {}
	r.lean = rad_to_deg(deg_to_rad(sd.max_hip_lean) * rig._reach_lean)
	r.slide = rig._reach_slide
	var errs := []
	var stretch := []
	var elbows := []
	for side in 2:
		var arm: PackedInt32Array = rig._arm_bones[side]
		var grip := sd.grip_point * Vector3(1.0 if side == 0 else -1.0, 1.0, 1.0)
		var actual := _kart_point(kv, rig, arm[2], grip)
		var target := rig.hand_target_l if side == 0 else rig.hand_target_r
		errs.append(actual.distance_to(target) * 100.0)
		stretch.append(rig._scl[arm[0]].y)
		var sh := _kart_point(kv, rig, arm[0])
		var el := _kart_point(kv, rig, arm[1])
		var wr := _kart_point(kv, rig, arm[2])
		elbows.append(180.0 - rad_to_deg((el - sh).angle_to(wr - el)))
	r.hand_err = errs
	r.stretch = stretch
	r.elbow = elbows
	var legs := []
	for side in 2:
		var chain: PackedInt32Array = rig._leg_chain[side]
		var hip := _kart_point(kv, rig, chain[0])
		var knee := _kart_point(kv, rig, chain[1])
		var ankle := _kart_point(kv, rig, chain[2])
		var toe_bone := rig._bone.get(StringName(sd.legs[side * 4 + 3]), -1) as int
		var toe := _kart_point(kv, rig, toe_bone)
		# Distância do joelho ao aro do volante (círculo no plano do volante).
		var c := k.steering_wheel_center
		var ax := k.steering_wheel_axis.normalized()
		var rel := knee - c
		var along := rel.dot(ax)
		var radial := (rel - ax * along).length()
		var rim := sqrt(along * along + pow(radial - k.steering_wheel_radius, 2.0))
		legs.append({"hip": hip, "knee": knee, "ankle": ankle, "toe": toe,
				"knee_angle": 180.0 - rad_to_deg((knee - hip).angle_to(ankle - knee)), "knee_rim": rim})
	r.legs = legs
	var head := rig._bone.get(&"Head", -1) as int
	r.head = _kart_point(kv, rig, head)
	r.hips = _kart_point(kv, rig, rig._hips_bone)
	return r


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _report(k: KartData, data: CharacterData, out: Dictionary) -> void:
	var r: Dictionary = out[0.0]
	var cp := k.cockpit()
	print("== %s (%s) escala %.2f" % [k.display_name, k.resource_path.get_file(), data.kart_scale])
	print("   cockpit: canto %s encosto %.0f° frente estofado %.2f assoalho %.2f limite pés %.2f" % [
		_v(k.seat_back_point), k.seat_back_angle, k.seat_front_z, k.floor_height, k.foot_limit_z])
	print("   inclinou %.1f° deslizou %.3f | mãos erro %.1f/%.1f cm esticou %.2f/%.2f cotovelo %.0f°/%.0f°" % [
		r.lean, r.slide, r.hand_err[0], r.hand_err[1], r.stretch[0], r.stretch[1], r.elbow[0], r.elbow[1]])
	for side in 2:
		var l: Dictionary = r.legs[side]
		var where := "?"
		var a: Vector3 = l.ankle
		if not cp.is_empty():
			if absf(a.y - (k.floor_height + data.skeleton.ankle_lift * data.kart_scale)) < 0.01:
				where = "assoalho"
			elif absf(a.y - (k.seat_back_point.y + data.skeleton.ankle_lift * data.kart_scale)) < 0.01:
				where = "estofado"
			else:
				where = "outro (y %.2f)" % a.y
			if a.z <= k.foot_limit_z + data.skeleton.foot_length * data.kart_scale * cos(deg_to_rad(data.skeleton.foot_pitch)) + 0.005:
				where += ", no limite (pedais/parede)"
		print("   perna %s: quadril %s joelho %s (%.0f° dobrado, %.0f cm do aro) tornozelo %s ponta %s → %s" % [
			"E" if side == 0 else "D", _v(l.hip), _v(l.knee), l.knee_angle, l.knee_rim * 100.0, _v(l.ankle), _v(l.toe), where])
	print("   cabeça %s quadril %s" % [_v(r.head), _v(r.hips)])
	for steer in [1.0, -1.0]:
		var s: Dictionary = out[steer]
		print("   volante %s: inclinou %.1f° deslizou %.3f mãos erro %.1f/%.1f cm esticou %.2f/%.2f cotovelo %.0f°/%.0f°" % [
			"esq" if steer > 0 else "dir", s.lean, s.slide, s.hand_err[0], s.hand_err[1], s.stretch[0], s.stretch[1],
			s.elbow[0], s.elbow[1]])


## Copia a cena (kart + piloto) com as malhas com esqueleto deformadas na CPU e grava glb.
func _export(kv: KartVisual, path: String) -> void:
	var scene := Node3D.new()
	scene.name = "Cena"
	for n in kv.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.name = mi.name
		var xf := kv.global_transform.affine_inverse() * mi.global_transform
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin else null
		if sk:
			copy.mesh = _skinned(mi, sk, kv)
			copy.transform = Transform3D.IDENTITY
		else:
			copy.mesh = mi.mesh
			copy.transform = xf
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s)
				if m:
					copy.set_surface_override_material(s, m)
		scene.add_child(copy)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(scene, state)
	var err := doc.write_to_filesystem(state, path)
	print("   glb: %s (%s)" % [path, error_string(err)])
	scene.free()


func _skinned(mi: MeshInstance3D, sk: Skeleton3D, kv: KartVisual) -> ArrayMesh:
	var skin := mi.skin
	var to_kart := kv.global_transform.affine_inverse() * sk.global_transform
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = sk.find_bone(skin.get_bind_name(b))
		mats.append(to_kart * sk.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	var out := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		nv.resize(verts.size())
		nn.resize(verts.size())
		for i in verts.size():
			var p := Vector3.ZERO
			var q := Vector3.ZERO
			for k in per:
				var w := weights[i * per + k]
				if w <= 0.0:
					continue
				var m := mats[bones[i * per + k]]
				p += (m * verts[i]) * w
				q += (m.basis * normals[i]) * w
			nv[i] = p
			nn[i] = q.normalized()
		var plain := []
		plain.resize(Mesh.ARRAY_MAX)
		plain[Mesh.ARRAY_VERTEX] = nv
		plain[Mesh.ARRAY_NORMAL] = nn
		plain[Mesh.ARRAY_TEX_UV] = arrays[Mesh.ARRAY_TEX_UV]
		plain[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plain)
		var mat := mi.get_active_material(s)
		if mat:
			out.surface_set_material(s, mat)
	return out
