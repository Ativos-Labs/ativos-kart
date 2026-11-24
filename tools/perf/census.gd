extends SceneTree
## Censo da cena da corrida (headless): o que existe para desenhar, o que faz sombra, e
## uma câmera simulada andando pela pista (frustum + alcance de visibilidade) para achar
## as vistas mais pesadas e quem pesa nelas. Sem GPU: conta superfícies (≈ draw calls)
## e triângulos (sem LOD; o LOD de um MultiMesh usa a caixa dele inteira).
## Uso (copie para _probe/): Godot --headless --audio-driver Dummy --path . \
##     -s res://_probe/census.gd -- track=0 [step=12] [top=14]
## Headless: Camera3D.get_frustum() ignora a posição da câmera, por isso os planos são
## montados à mão (FOV 75°, 16:9). Sombra: uma esfera por cascata, esticada na direção
## da luz (aproximação; serve para comparar, não para contar exato).

var frame := 0
var race: Node
var args := {"track": "0", "step": "12", "top": "14"}
var _wait := 0

const FOV := 75.0
const ASPECT := 16.0 / 9.0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		var gs = root.get_node("GameState")
		gs.selected_track_index = int(args.track)
		gs.mode = 1
		gs.laps = 99
		gs.speed_class = 1
		gs.difficulty = 1
		gs.cpu_enabled = true
		var devs: Array[int] = []
		gs.set_players(devs)
		race = load("res://scenes/race.tscn").instantiate()
		root.add_child(race)
		current_scene = race
	elif frame > 2 and race and race.get("track") != null and race.track and race.state >= 1:
		_wait += 1
		if _wait == 30:
			_census()
			return true
	return frame > 3000


func _cat(n: Node) -> String:
	var tr: Node = race.track
	var p := String(tr.get_path_to(n)) if tr.is_ancestor_of(n) else "RACE/" + String(race.get_path_to(n))
	var parts := p.split("/")
	var out: PackedStringArray = []
	for i in mini(parts.size(), 3):
		var s := parts[i]
		var r := RegEx.create_from_string("[0-9@]+")
		s = r.sub(s, "", true)
		out.append(s)
	return "/".join(out)


func _mesh_tris(m: Mesh) -> Array:
	# [surfaces, tris]
	if m == null:
		return [0, 0]
	var s := m.get_surface_count()
	var t := 0
	if m is ArrayMesh:
		var am := m as ArrayMesh
		for i in s:
			var il := am.surface_get_array_index_len(i)
			t += (il if il > 0 else am.surface_get_array_len(i)) / 3
	else:
		for i in s:
			var arr := m.surface_get_arrays(i)
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null and arr[Mesh.ARRAY_INDEX].size() > 0:
				t += arr[Mesh.ARRAY_INDEX].size() / 3
			elif arr.size() > 0 and arr[0] != null:
				t += arr[0].size() / 3
	return [s, t]


func _transparent(gi: GeometryInstance3D, m: Mesh) -> bool:
	var mats: Array = []
	if gi.material_override:
		mats.append(gi.material_override)
	elif m:
		for i in m.get_surface_count():
			var mm: Material = null
			if gi is MeshInstance3D:
				mm = (gi as MeshInstance3D).get_active_material(i)
			else:
				mm = m.surface_get_material(i)
			if mm:
				mats.append(mm)
	for mm in mats:
		if mm is BaseMaterial3D and (mm as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				and (mm as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			return true
		if mm is ShaderMaterial and (mm as ShaderMaterial).shader:
			var code := (mm as ShaderMaterial).shader.code
			if code.contains("blend_add") or code.contains("ALPHA =") or code.contains("ALPHA=") or code.contains("depth_draw_never"):
				return true
	return false


func _shader_names(gi: GeometryInstance3D, m: Mesh) -> PackedStringArray:
	var out: PackedStringArray = []
	var mats: Array = []
	if gi.material_override:
		mats.append(gi.material_override)
	elif m:
		for i in m.get_surface_count():
			var mm: Material = (gi as MeshInstance3D).get_active_material(i) if gi is MeshInstance3D else m.surface_get_material(i)
			if mm:
				mats.append(mm)
	for mm in mats:
		if mm is ShaderMaterial and (mm as ShaderMaterial).shader:
			out.append((mm as ShaderMaterial).shader.resource_path.get_file())
		elif mm:
			out.append(mm.get_class())
	return out


func _census() -> void:
	var items: Array = []  # dicts
	var tr: Node3D = race.track
	var by_cat := {}
	var lights := {"omni": 0, "omni_sh": 0, "spot": 0, "spot_sh": 0}
	var particles := 0
	var particles_amt := 0
	var shaders := {}
	var phys := {"static": 0, "anim": 0, "area": 0, "rigid": 0, "char": 0, "shapes": {}}
	for n in root.find_children("*", "", true, false):
		if n is CollisionObject3D:
			if n is Area3D: phys.area += 1
			elif n is AnimatableBody3D: phys.anim += 1
			elif n is StaticBody3D: phys.static += 1
			elif n is RigidBody3D: phys.rigid += 1
			elif n is CharacterBody3D: phys.char += 1
		if n is CollisionShape3D and n.shape:
			var c: String = n.shape.get_class()
			phys.shapes[c] = phys.shapes.get(c, 0) + 1
			if n.shape is ConcavePolygonShape3D:
				phys.shapes["concave_tris"] = phys.shapes.get("concave_tris", 0) + n.shape.get_faces().size() / 3
		if n is OmniLight3D:
			lights.omni += 1
			if n.shadow_enabled: lights.omni_sh += 1
		elif n is SpotLight3D:
			lights.spot += 1
			if n.shadow_enabled: lights.spot_sh += 1
		if n is GPUParticles3D or n is CPUParticles3D:
			if n.visible:
				particles += 1
				particles_amt += n.amount
			continue
		if not (n is GeometryInstance3D):
			continue
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var surf := 1
		var tris := 2
		var inst := 1
		var m: Mesh = null
		if gi is MeshInstance3D:
			m = (gi as MeshInstance3D).mesh
			var r := _mesh_tris(m)
			surf = r[0]; tris = r[1]
		elif gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm == null: continue
			m = mm.mesh
			var r := _mesh_tris(m)
			inst = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			surf = r[0]; tris = r[1] * inst
		var aabb: AABB = gi.global_transform * gi.get_aabb()
		var shadow := gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var only_shadow := gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var transp := _transparent(gi, m)
		var lod := false
		if m is ArrayMesh:
			# ArrayMesh com LOD gerado (não exposto direto): heurística pelo nome não dá; marca "?"
			pass
		for s in _shader_names(gi, m):
			shaders[s] = shaders.get(s, 0) + 1
		var it := {"cat": _cat(gi), "surf": surf, "tris": tris, "inst": inst, "aabb": aabb,
			"shadow": shadow, "only_shadow": only_shadow, "transp": transp,
			"vr": gi.visibility_range_end, "name": gi.name, "cls": gi.get_class()}
		items.append(it)
		var c: Dictionary = by_cat.get(it.cat, {"n": 0, "surf": 0, "tris": 0, "sh_tris": 0, "transp": 0, "vr": 0})
		c.n += 1; c.surf += surf; c.tris += tris
		if shadow: c.sh_tris += tris
		if transp: c.transp += surf
		if it.vr > 0: c.vr += 1
		by_cat[it.cat] = c

	var tot_s := 0
	var tot_t := 0
	var tot_sh := 0
	for it in items:
		tot_s += it.surf; tot_t += it.tris
		if it.shadow: tot_sh += it.tris
	print("CENSUS|track=%s len=%.0f m|instances=%d surfaces=%d tris=%d shadow_tris=%d|particles=%d amount=%d|lights=%s" % [
		args.track, tr.length, items.size(), tot_s, tot_t, tot_sh, particles, particles_amt, lights])
	print("PHYS|%s" % phys)
	var cats := by_cat.keys()
	cats.sort_custom(func(a, b): return by_cat[a].tris > by_cat[b].tris)
	for k in cats.slice(0, int(args.top) + 10):
		var c = by_cat[k]
		print("CAT|%-46s n=%4d surf=%5d tris=%8d sh_tris=%8d transp=%3d vr=%d" % [k, c.n, c.surf, c.tris, c.sh_tris, c.transp, c.vr])
	var sk := shaders.keys()
	sk.sort_custom(func(a, b): return shaders[a] > shaders[b])
	print("SHADERS|%s" % ", ".join(sk.map(func(k): return "%s×%d" % [k, shaders[k]])))

	# --- câmera simulada -------------------------------------------------------------
	var light: DirectionalLight3D = null
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		light = n
	var sh_max := light.directional_shadow_max_distance if light else 0.0
	var splits := [light.directional_shadow_split_1, light.directional_shadow_split_2, light.directional_shadow_split_3, 1.0] if light else []
	var nsplit := 4
	if light and light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS: nsplit = 2
	elif light and light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL: nsplit = 1
	var to_light := light.global_transform.basis.z.normalized() if light else Vector3.UP
	print("LIGHT|max=%.0f mode_splits=%d splits=%s blend=%s angular=%.2f" % [sh_max, nsplit, splits, light.directional_shadow_blend_splits if light else false, light.light_angular_distance if light else 0.0])
	var step := float(args.step)
	var views: Array = []
	var d := 0.0
	var cat_view := {}
	while d < tr.length:
		var t: Transform3D = tr.global_transform * tr.get_transform_at(d)
		var ahead: Vector3 = tr.global_transform * tr.get_point_at(d + 15.0)
		var fwd := (ahead - t.origin).normalized()
		var cam_pos := t.origin - fwd * 5.5 + Vector3.UP * 2.6
		var cam := Transform3D.IDENTITY.looking_at(ahead - cam_pos + Vector3.UP * 0.5, Vector3.UP)
		cam.origin = cam_pos
		var planes: Array[Plane] = []
		var hv := deg_to_rad(FOV * 0.5)
		var hh := atan(tan(hv) * ASPECT)
		for lp in [Plane(Vector3(0, 0, 1), -0.05), Plane(Vector3(0, 0, -1), 4000.0),
				Plane(Vector3(-cos(hh), 0, sin(hh)), 0.0), Plane(Vector3(cos(hh), 0, sin(hh)), 0.0),
				Plane(Vector3(0, cos(hv), sin(hv)), 0.0), Plane(Vector3(0, -cos(hv), sin(hv)), 0.0)]:
			planes.append(cam * lp)
		var v := {"d": d, "surf": 0, "tris": 0, "transp": 0, "sh_surf": 0, "sh_tris": 0, "cats": {}}
		for it in items:
			var aabb: AABB = it.aabb
			var center: Vector3 = aabb.get_center()
			var dist: float = center.distance_to(cam_pos)
			var visible_main: bool = not it.only_shadow and (it.vr <= 0.0 or dist <= it.vr) and _in_frustum(aabb, planes)
			if visible_main:
				v.surf += it.surf; v.tris += it.tris
				if it.transp: v.transp += it.surf
				var cv: Dictionary = v.cats.get(it.cat, {"surf": 0, "tris": 0})
				cv.surf += it.surf; cv.tris += it.tris
				v.cats[it.cat] = cv
			if it.shadow and light and (it.vr <= 0.0 or dist <= it.vr):
				# cada cascata: esfera do pedaço do frustum, estendida na direção da luz
				var prev := 0.0
				var r_c: float = aabb.size.length() * 0.5
				for ci in nsplit:
					var far_c: float = sh_max * (splits[ci] if nsplit == 4 else (splits[0] if ci == 0 and nsplit == 2 else 1.0))
					var near_c := prev
					prev = far_c
					var mid := (near_c + far_c) * 0.5
					var half_h := tan(deg_to_rad(FOV * 0.5)) * far_c
					var half_w := half_h * ASPECT
					var R := Vector3(half_w, half_h, (far_c - near_c) * 0.5).length()
					var S := cam_pos - cam.basis.z * mid
					var vv := center - S
					var tl := vv.dot(to_light)
					if tl < -(R + r_c):
						continue
					var perp := (vv - to_light * tl).length()
					if perp < R + r_c:
						v.sh_surf += it.surf; v.sh_tris += it.tris
						var cvs: Dictionary = v.cats.get(it.cat, {"surf": 0, "tris": 0})
						cvs["sh"] = cvs.get("sh", 0) + it.tris
						v.cats[it.cat] = cvs
		views.append(v)
		for k in v.cats:
			var a: Dictionary = cat_view.get(k, {"surf": 0, "tris": 0, "sh": 0})
			a.surf += v.cats[k].surf; a.tris += v.cats[k].tris; a.sh += v.cats[k].get("sh", 0)
			cat_view[k] = a
		d += step
	var n := float(views.size())
	var avg_s := 0.0; var avg_t := 0.0; var avg_ss := 0.0; var avg_st := 0.0
	for v in views:
		avg_s += v.surf; avg_t += v.tris; avg_ss += v.sh_surf; avg_st += v.sh_tris
	print("VIEW|avg main surf=%.0f tris=%.0f | shadow surf=%.0f tris=%.0f (views=%d)" % [avg_s / n, avg_t / n, avg_ss / n, avg_st / n, views.size()])
	var worst := views.duplicate()
	worst.sort_custom(func(a, b): return a.surf + a.sh_surf > b.surf + b.sh_surf)
	for v in worst.slice(0, 3):
		print("WORST|d=%.0f (%.2f) main surf=%d tris=%d transp=%d | shadow surf=%d tris=%d" % [v.d, v.d / tr.length, v.surf, v.tris, v.transp, v.sh_surf, v.sh_tris])
	var ck := cat_view.keys()
	ck.sort_custom(func(a, b): return cat_view[a].surf * 1000 + cat_view[a].tris / 50 > cat_view[b].surf * 1000 + cat_view[b].tris / 50)
	for k in ck.slice(0, int(args.top)):
		var a = cat_view[k]
		print("VCAT|%-46s avg surf=%6.1f tris=%8.0f shadow_tris=%8.0f" % [k, a.surf / n, a.tris / n, a.sh / n])


func _in_frustum(aabb: AABB, planes: Array[Plane]) -> bool:
	for p in planes:
		# vértice mais "para dentro" (contra a normal, que aponta para fora)
		var v := aabb.position
		if p.normal.x < 0.0: v.x += aabb.size.x
		if p.normal.y < 0.0: v.y += aabb.size.y
		if p.normal.z < 0.0: v.z += aabb.size.z
		if p.distance_to(v) > 0.0:
			return false
	return true
