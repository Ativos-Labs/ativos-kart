extends SceneTree
## Grava glb de um piloto em pé (como na tela de seleção) em vários instantes do gesto de
## escolha (CharacterData.pick_gesture, com a pick_face), para ver de fora do Godot
## (render_gestos.py, no Blender). As malhas são deformadas na CPU; o piloto não pisca nem
## olha em volta.
##
##   Godot --headless --path . -s res://tools/personagens/quadros_gesto.gd -- <pasta> <personagem> [tempos] [gesto]
##
## <personagem> = nome do .tres em res://data/personagens/; [tempos] = instantes em segundos
## separados por vírgula (padrão: 12 quadros do começo ao fim do gesto); [gesto] = outra
## animação do esqueleto no lugar da pick_gesture. Grava <pasta>/<personagem>_NN.glb.

var _f := 0


func _process(_d: float) -> bool:
	_f += 1
	if _f < 2:
		return false
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("uso: -- <pasta> <personagem> [tempos] [gesto]")
		return true
	_run(args[0], args[1], args[2] if args.size() > 2 else "", args[3] if args.size() > 3 else "")
	return true


func _run(out: String, who: String, times_arg: String, gesture: String) -> void:
	CharacterMesh.enabled = false
	var data: CharacterData = load("res://data/personagens/%s.tres" % who)
	var holder := Node3D.new()
	root.add_child(holder)
	var rig := data.instantiate_rig()
	rig.setup_stand(data.showcase_scale)
	holder.add_child(rig)
	rig.set_process(false)
	rig._blink_timer = INF
	rig._glance_timer = INF
	rig._glance = Vector2.ZERO
	var dt := 1.0 / 30.0
	for i in 30:
		rig._process(dt)
	var anim_name := StringName(gesture) if gesture != "" else data.pick_gesture
	rig.set_face(data.pick_face)
	var length := rig.play_body_gesture(anim_name, 99.0)
	print("%s: %s, %.2f s" % [who, anim_name, length])
	var times: Array[float] = []
	if times_arg != "":
		for s in times_arg.split(","):
			times.append(float(s))
	else:
		for k in 12:
			times.append(length * k / 11.0)
	var t := 0.0
	for k in times.size():
		while t + dt * 0.5 < times[k]:
			rig._process(dt)
			t += dt
		_export(rig, "%s/%s_%02d.glb" % [out, who, k])
	print("%d quadros em %s (%s s)" % [times.size(), out, ", ".join(times.map(func(x): return "%.2f" % x))])
	holder.free()
	CharacterMesh.clear_cache()


## Copia as malhas do piloto deformadas na CPU (espaço do rig) e grava glb.
func _export(rig: CharacterRig, path: String) -> void:
	var scene := Node3D.new()
	scene.name = "Cena"
	for n in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.name = mi.name
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin else null
		if sk:
			copy.mesh = _skinned(mi, sk, rig)
		else:
			copy.mesh = mi.mesh
			copy.transform = rig.global_transform.affine_inverse() * mi.global_transform
		scene.add_child(copy)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(scene, state)
	doc.write_to_filesystem(state, path)
	scene.free()


func _skinned(mi: MeshInstance3D, sk: Skeleton3D, rig: Node3D) -> ArrayMesh:
	var skin := mi.skin
	var to_rig := rig.global_transform.affine_inverse() * sk.global_transform
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = sk.find_bone(skin.get_bind_name(b))
		mats.append(to_rig * sk.get_bone_global_pose(bone) * skin.get_bind_pose(b))
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
