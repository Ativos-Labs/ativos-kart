extends Node
## Probe de performance TEMPORÁRIO (só entra no export de teste; nunca no projeto).
## Percorre menu, corridas e seleção de pistas medindo fps, CPU e draw calls, e faz
## A/B de cada recurso gráfico com o jogo pausado (quadro determinístico).
## Cenário pela URL: ?s=full | ?s=quick | ?s=ab

const RACE := "res://scenes/race.tscn"
const TRACK_SELECT := "res://scenes/track_select.tscn"

var _last_us := 0
var _rec := false
var _ft := PackedFloat32Array()
var _acc := {}
var _ai_keep: Array = []
var _query := ""
var _phase := "boot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	if OS.has_feature("web"):
		_query = str(JavaScriptBridge.eval("location.search"))
	_run.call_deferred()


func _gs() -> Node:
	return get_node("/root/GameState")


func _out(s: String) -> void:
	print("PERF|", s)


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var dt := (now - _last_us) / 1000.0
		if dt > 80.0:
			_out("STALL|%s|%.0f" % [_phase, dt])
		if _rec:
			_ft.append(dt)
			_acc.proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			_acc.phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			_acc.dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			_acc.obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			_acc.prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			_acc.setup += RenderingServer.get_frame_setup_time_cpu()
			_acc.n += 1
	_last_us = now
	if _ins_on:
		_ins_frames += 1
		_ins_run("p", _d)


# --- Instrumentação de CPU: o probe chama os _process/_physics_process de cada
# script e cronometra (agrupado pelo arquivo do script).
var _ins_on := false
var _ins: Dictionary = {}  # arquivo -> {"p": [nodes], "pp": [nodes], "us": int}
var _ins_frames := 0
var _ins_pframes := 0
var _ins_ai_us := [0]
var _ins_phys_total := 0.0


func _script_has(sc: Script, m: String) -> bool:
	while sc:
		for d in sc.get_script_method_list():
			if d.name == m:
				return true
		sc = sc.get_base_script()
	return false


func _instrument(root: Node) -> void:
	_ins.clear()
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for n in nodes:
		var sc: Script = n.get_script()
		if sc == null or n == self:
			continue
		var key: String = sc.resource_path.get_file()
		if key == "":
			key = "builtin:" + n.get_class()
		var g: Dictionary = _ins.get(key, {"p": [], "pp": [], "us": 0})
		if n.is_processing() and _script_has(sc, "_process"):
			n.set_process(false)
			g.p.append(n)
		if n.is_physics_processing() and _script_has(sc, "_physics_process"):
			n.set_physics_process(false)
			g.pp.append(n)
		if not g.p.is_empty() or not g.pp.is_empty():
			_ins[key] = g
	_ins_frames = 0
	_ins_pframes = 0
	_ins_phys_total = 0.0
	_ins_ai_us[0] = 0
	_ins_on = true


func _uninstrument() -> void:
	_ins_on = false
	for key in _ins:
		for n in _ins[key].p:
			if is_instance_valid(n):
				n.set_process(true)
		for n in _ins[key].pp:
			if is_instance_valid(n):
				n.set_physics_process(true)


func _ins_run(list_key: String, delta: float) -> void:
	for key in _ins:
		var g: Dictionary = _ins[key]
		var t0 := Time.get_ticks_usec()
		for n in g[list_key]:
			if is_instance_valid(n) and n.is_inside_tree():
				if list_key == "p":
					n._process(delta)
				else:
					n._physics_process(delta)
		g.us += Time.get_ticks_usec() - t0


func _physics_process(delta: float) -> void:
	if _ins_on:
		_ins_pframes += 1
		_ins_phys_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_ins_run("pp", delta)


## Embrulha o piloto automático de todos os karts para medir a IA.
func _wrap_ai(race: Node) -> void:
	for r in race.racers:
		var k = r.kart
		if not k.autopilot.is_valid():
			continue
		var inner: Callable = k.autopilot
		var acc: Array = _ins_ai_us
		k.autopilot = func(kk) -> Dictionary:
			var t0 := Time.get_ticks_usec()
			var out: Dictionary = inner.call(kk)
			acc[0] += Time.get_ticks_usec() - t0
			return out


func _cpu_breakdown(race: Node, label: String, secs := 4.0) -> void:
	_instrument(race)
	await _wait(secs)
	_uninstrument()
	var f := maxi(_ins_frames, 1)
	var pf := maxi(_ins_pframes, 1)
	var rows: Array = []
	var total := 0.0
	for key in _ins:
		var g: Dictionary = _ins[key]
		var ms: float = g.us / 1000.0 / f
		total += ms
		rows.append([ms, key, g.p.size(), g.pp.size()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows:
		if r[0] >= 0.01:
			_out("CPU|%s|%s|%.3f ms/frame|nodes p=%d pp=%d" % [label, r[1], r[0], r[2], r[3]])
	_out("CPU|%s|TOTAL scripts|%.3f ms/frame|ai(dentro de kart.gd)=%.3f|phys_step_mon=%.3f ms/tick|frames=%d ticks=%d" % [
		label, total, _ins_ai_us[0] / 1000.0 / f, _ins_phys_total / pf, f, pf])


func _arg(key: String, def: String) -> String:
	for part in _query.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == key:
			return kv[1]
	return def


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _measure(label: String, secs: float) -> Dictionary:
	_ft = PackedFloat32Array()
	_acc = {"proc": 0.0, "phys": 0.0, "dc": 0.0, "obj": 0.0, "prim": 0.0, "setup": 0.0, "n": 0}
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_usec()
	_rec = true
	await _wait(secs)
	_rec = false
	var frames := Engine.get_frames_drawn() - f0
	var el := (Time.get_ticks_usec() - t0) / 1e6
	var s := _ft.duplicate()
	s.sort()
	var n := maxi(int(_acc.n), 1)
	var pick := func(q: float) -> float: return s[clampi(int(q * (s.size() - 1)), 0, s.size() - 1)] if s.size() > 0 else 0.0
	var r := {
		"fps": frames / el, "p50": pick.call(0.5), "p95": pick.call(0.95), "p99": pick.call(0.99),
		"max": pick.call(1.0), "proc": _acc.proc / n, "phys": _acc.phys / n, "setup": _acc.setup / n,
		"dc": _acc.dc / n, "obj": _acc.obj / n, "prim": _acc.prim / n,
	}
	_out("M|%s|fps=%.1f|p50=%.2f|p95=%.2f|p99=%.2f|max=%.1f|proc=%.2f|phys=%.2f|setup=%.2f|dc=%d|obj=%d|prim=%d" % [
		label, r.fps, r.p50, r.p95, r.p99, r.max, r.proc, r.phys, r.setup, r.dc, r.obj, r.prim])
	return r


func _wait_scene(path: String, old: Node) -> Node:
	while true:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs != old and is_instance_valid(cs) and cs.scene_file_path == path and cs.is_node_ready():
			return cs
	return null


func _goto(path: String) -> Node:
	var old := get_tree().current_scene
	_gs().goto_scene(path)
	var scene := await _wait_scene(path, old)
	# Espera o fade terminar.
	while _gs()._changing_scene:
		await get_tree().process_frame
	return scene


func _start_race(track_idx: int, players: int, cls := 1) -> Node:
	_gs().mode = 1
	_gs().cpu_enabled = true
	_gs().speed_class = cls
	_gs().selected_track_index = track_idx
	var devs: Array[int] = []
	if players > 1:
		for i in players:
			devs.append(i)
	_gs().set_players(devs)
	_gs().laps = 99
	_phase = "load_race_t%d_%dp" % [track_idx, players]
	var race: Node = await _goto(RACE)
	_phase = "countdown_t%d_%dp" % [track_idx, players]
	while race.state != 1:
		await get_tree().process_frame
	var line: RacingLine = RacingLine.build(race.track)
	for r in race.humans:
		var ai := KartAI.new()
		ai.setup(r.kart, race.track, line, race._karts, 0.85)
		r.kart.autopilot = ai.drive
		_ai_keep.append(ai)
	_phase = "race_t%d_%dp" % [track_idx, players]
	return race


func _toggles(race: Node) -> Array:
	var vp := get_viewport()
	var envs: Array = race.track.find_children("*", "WorldEnvironment", true, false)
	var env: Environment = (envs[0] as WorldEnvironment).environment
	var sun: DirectionalLight3D = race.track.find_children("*", "DirectionalLight3D", true, false)[0]
	var msaa := vp.msaa_3d
	var parts: Array = race.find_children("*", "GPUParticles3D", true, false)
	var mms: Array = race.track.find_children("*", "MultiMeshInstance3D", true, false)
	var karts: Array = race._karts
	var hud: Node = race.hud
	var subvps: Array = hud.find_children("*", "SubViewport", true, false)
	var drivers: Array = []
	for k in karts:
		if k.driver:
			drivers.append(k.driver)
	var track_meshes: Array = []
	for c in race.track.get_children():
		if c is MeshInstance3D:
			track_meshes.append(c)
	var set_vis := func(nodes: Array, v: bool) -> void:
		for n in nodes:
			n.visible = v
	var mm_by_name := {}
	for m in mms:
		var nm := String(m.name).rstrip("0123456789").trim_suffix("@")
		if not mm_by_name.has(nm):
			mm_by_name[nm] = []
		mm_by_name[nm].append(m)
	var driver_geo: Array = []
	for d in drivers:
		driver_geo.append_array(d.find_children("*", "GeometryInstance3D", true, false))
	var kart_geo: Array = []
	for k in karts:
		for g in k.find_children("*", "MeshInstance3D", true, false):
			if not driver_geo.has(g):
				kart_geo.append(g)
	var shadow_off := func(nodes: Array) -> void:
		for n in nodes:
			n.set_meta("cs", n.cast_shadow)
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow_on := func(nodes: Array) -> void:
		for n in nodes:
			n.cast_shadow = n.get_meta("cs", GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	var dist := sun.directional_shadow_max_distance
	var t: Array = [
		["no_shadow", func(): sun.shadow_enabled = false, func(): sun.shadow_enabled = true],
		["shadow_2split", func(): sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
				func(): sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS],
		["shadow_dist_100", func(): sun.directional_shadow_max_distance = 100.0, func(): sun.directional_shadow_max_distance = dist],
		["shadow_dist_60", func(): sun.directional_shadow_max_distance = 60.0, func(): sun.directional_shadow_max_distance = dist],
		["driver_noshadow", shadow_off.bind(driver_geo), shadow_on.bind(driver_geo)],
		["kartbody_noshadow", shadow_off.bind(kart_geo), shadow_on.bind(kart_geo)],
		["mm_noshadow", shadow_off.bind(mms), shadow_on.bind(mms)],
		["lod_2", func(): vp.mesh_lod_threshold = 2.0, func(): vp.mesh_lod_threshold = 1.0],
		["lod_8", func(): vp.mesh_lod_threshold = 8.0, func(): vp.mesh_lod_threshold = 1.0],
		["no_msaa", func(): vp.msaa_3d = Viewport.MSAA_DISABLED, func(): vp.msaa_3d = msaa],
		["scale_0.5", func(): vp.scaling_3d_scale = 0.5, func(): vp.scaling_3d_scale = 1.0],
		["no_particles", set_vis.bind(parts, false), set_vis.bind(parts, true)],
		["no_drivers", set_vis.bind(drivers, false), set_vis.bind(drivers, true)],
		["no_karts", set_vis.bind(karts, false), set_vis.bind(karts, true)],
		["no_multimesh", set_vis.bind(mms, false), set_vis.bind(mms, true)],
		["no_trackmesh", set_vis.bind(track_meshes, false), set_vis.bind(track_meshes, true)],
		["no_portrait", _set_vp_update.bind(subvps, SubViewport.UPDATE_DISABLED),
				_set_vp_update.bind(subvps, SubViewport.UPDATE_ALWAYS)],
		["no_hud", func(): hud.visible = false, func(): hud.visible = true],
	]
	for nm in mm_by_name:
		t.append(["mm_" + nm, set_vis.bind(mm_by_name[nm], false), set_vis.bind(mm_by_name[nm], true)])
	return t


func _set_vp_update(vps: Array, mode: int) -> void:
	for v in vps:
		(v as SubViewport).render_target_update_mode = mode


func _ab(race: Node, tag: String, secs := 1.5) -> void:
	# Pausa: o quadro fica igual e a comparação é limpa.
	get_tree().paused = true
	await _wait(0.6)
	var base := await _measure("%s|base" % tag, secs)
	for item in _toggles(race):
		var name: String = item[0]
		(item[1] as Callable).call()
		await _wait(1.2)
		var v := await _measure("%s|%s" % [tag, name], secs)
		(item[2] as Callable).call()
		await _wait(1.2)
		var b := await _measure("%s|base_after_%s" % [tag, name], secs)
		var mean_base: float = (base.p50 + b.p50) * 0.5
		_out("AB|%s|%s|base_ms=%.2f|var_ms=%.2f|saved_ms=%.2f|dc %d->%d" % [
			tag, name, mean_base, v.p50, mean_base - v.p50, b.dc, v.dc])
		base = b
	get_tree().paused = false


## A/B com a corrida andando (alternando base/variação duas vezes).
func _live_ab(race: Node, tag: String, secs := 2.0) -> void:
	var rigs: Array = []
	for n in get_tree().root.find_children("*", "", true, false):
		if n is CharacterRig:
			rigs.append(n)
	var drivers: Array = []
	for k in race._karts:
		if k.driver:
			drivers.append(k.driver)
	var parts: Array = race.find_children("*", "GPUParticles3D", true, false)
	var mms: Array = race.track.find_children("*", "MultiMeshInstance3D", true, false)
	var subvps: Array = race.hud.find_children("*", "SubViewport", true, false)
	var sun: DirectionalLight3D = race.track.find_children("*", "DirectionalLight3D", true, false)[0]
	var set_vis := func(nodes: Array, v: bool) -> void:
		for n in nodes:
			n.visible = v
	var set_proc := func(nodes: Array, v: bool) -> void:
		for n in nodes:
			n.set_process(v)
	var toggles: Array = [
		["rigs_frozen", set_proc.bind(rigs, false), set_proc.bind(rigs, true)],
		["drivers_hidden", set_vis.bind(drivers, false), set_vis.bind(drivers, true)],
		["portrait_off", _set_vp_update.bind(subvps, SubViewport.UPDATE_DISABLED), _set_vp_update.bind(subvps, SubViewport.UPDATE_ALWAYS)],
		["particles_hidden", set_vis.bind(parts, false), set_vis.bind(parts, true)],
		["karts_hidden", set_vis.bind(race._karts, false), set_vis.bind(race._karts, true)],
		["multimesh_hidden", set_vis.bind(mms, false), set_vis.bind(mms, true)],
		["no_shadow", func(): sun.shadow_enabled = false, func(): sun.shadow_enabled = true],
	]
	for item in toggles:
		var bs: Array = []
		var vs: Array = []
		for rep in 2:
			var b := await _measure("%s|live_base_%s" % [tag, item[0]], secs)
			bs.append(b.p50)
			(item[1] as Callable).call()
			await _wait(1.0)
			var v := await _measure("%s|live_%s" % [tag, item[0]], secs)
			vs.append(v.p50)
			(item[2] as Callable).call()
			await _wait(1.0)
		var mb: float = (bs[0] + bs[1]) * 0.5
		var mv: float = (vs[0] + vs[1]) * 0.5
		_out("AB|live_%s|%s|base_ms=%.2f|var_ms=%.2f|saved_ms=%.2f|runs b=%s v=%s" % [tag, item[0], mb, mv, mb - mv, str(bs), str(vs)])


func _lod_test() -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 32
	sphere.rings = 16
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, sphere.get_mesh_arrays())
	var t0 := Time.get_ticks_usec()
	im.generate_lods(25.0, 60.0, [])
	_out("INFO|lod_test|surface_lods=%d|ms=%.1f" % [im.get_surface_lod_count(0), (Time.get_ticks_usec() - t0) / 1000.0])


func _merge_bench() -> void:
	var ch = _gs().characters[0]
	var model: Node3D = ch.model_scene.instantiate()
	var meshes: Array[MeshInstance3D] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n)
	var t0 := Time.get_ticks_usec()
	var n_arr := 0
	for mi in meshes:
		for si in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(si)
			n_arr += 1
	var t1 := Time.get_ticks_usec()
	var big := PackedInt32Array()
	big.resize(174000)
	for i in big.size():
		big[i] += 7
	var t2 := Time.get_ticks_usec()
	var e: Dictionary = CharacterMesh._build(meshes, ch.tint_materials)
	var t3 := Time.get_ticks_usec()
	_out("INFO|merge_bench|get_arrays x%d=%.1f ms|loop174k=%.1f ms|build_total=%.1f ms|ok=%s" % [n_arr, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, e.has("mesh")])
	model.free()


func _shot(name: String) -> void:
	_out("SHOT|" + name)
	await _wait(1.5)


## Telas para comparar o original (malhas do Celerino separadas, sombras de 4 divisões)
## com o otimizado, na mesma build.
func _shots() -> void:
	for variant in ["orig", "novo"]:
		CharacterMesh.enabled = variant == "novo"
		await _goto("res://scenes/character_select.tscn")
		await _wait(2.5)
		await _shot("character_select_" + variant)
	for ti in [0, 3]:
		var race := await _start_race(ti, 1)
		await _wait(5.0)
		get_tree().paused = true
		var sun: DirectionalLight3D = race.track.find_children("*", "DirectionalLight3D", true, false)[0]
		var mode := sun.directional_shadow_mode
		var dist := sun.directional_shadow_max_distance
		var split := sun.directional_shadow_split_1
		await _wait(0.6)
		await _shot("race_t%d_novo" % ti)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = 190.0
		sun.directional_shadow_split_1 = 0.1
		await _wait(1.5)
		await _shot("race_t%d_orig_sombra" % ti)
		sun.directional_shadow_mode = mode
		sun.directional_shadow_max_distance = dist
		sun.directional_shadow_split_1 = split
		await _wait(1.0)
		get_tree().paused = false
	CharacterMesh.enabled = true


## Isola o que pesa em telas de alta densidade: escala do 3D, 3D desligado, interface
## escondida (o que sobra é o custo fixo do navegador para um canvas grande).
func _dpr_test() -> void:
	var root := get_tree().root
	var rs = _gs().render_scale
	var layers: Array = []
	for n in root.find_children("*", "CanvasLayer", true, false):
		layers.append(n)
	var controls: Array = []
	for n in get_tree().current_scene.get_children():
		if n is Control:
			controls.append(n)
	if rs:
		rs.hold(true)
	var base_scale := root.scaling_3d_scale
	await _measure("dpr|scale_%.2f" % base_scale, 2.5)
	for sc in [1.0, 0.5, 0.35]:
		root.scaling_3d_scale = sc
		await _wait(0.8)
		await _measure("dpr|scale_%.2f" % sc, 2.5)
	root.scaling_3d_scale = base_scale
	root.disable_3d = true
	await _wait(0.8)
	await _measure("dpr|no_3d", 2.5)
	for c in controls:
		c.visible = false
	for l in layers:
		l.visible = false
	await _wait(0.8)
	await _measure("dpr|no_3d_no_ui", 2.5)
	root.disable_3d = false
	await _wait(0.8)
	await _measure("dpr|only_3d", 2.5)
	for c in controls:
		c.visible = true
	for l in layers:
		l.visible = true
	if rs:
		rs.hold(false)


## Qual conversão de cor o renderer espera: troca o shader do piloto junto por variantes
## (com e sem sRGB→linear) e fotografa cada uma ao lado do original.
func _color_test() -> void:
	CharacterMesh.enabled = false
	await _goto("res://scenes/character_select.tscn")
	await _wait(2.5)
	await _shot("cor_orig")
	CharacterMesh.enabled = true
	await _goto("res://scenes/character_select.tscn")
	await _wait(2.5)
	await _shot("cor_conv")
	var mats: Array = []
	for key in CharacterMesh._cache:
		var e: Dictionary = CharacterMesh._cache[key]
		if e.has("material"):
			mats.append(e.material)
	var base_code: String = (mats[0] as ShaderMaterial).shader.code
	var sh := Shader.new()
	sh.code = base_code.replace("albedo_linear = srgb_to_linear(c);", "albedo_linear = c;")
	_out("INFO|color_test|replaced=%s|renderer_define_test" % [sh.code != base_code])
	for m in mats:
		(m as ShaderMaterial).shader = sh
	for key in CharacterMesh._tinted:
		(CharacterMesh._tinted[key] as ShaderMaterial).shader = sh
	await _wait(2.0)
	await _shot("cor_sem_conv")


func _info() -> void:
	var vp := get_viewport()
	_out("INFO|window=%s|vp=%s|scale=%s|msaa=%d|renderer=%s|threads=%s|dpr=%s" % [
		DisplayServer.window_get_size(), vp.get_visible_rect().size, vp.scaling_3d_scale, vp.msaa_3d,
		RenderingServer.get_current_rendering_method(), OS.has_feature("threads"),
		JavaScriptBridge.eval("window.devicePixelRatio") if OS.has_feature("web") else 1])
	_out("INFO|gpu=%s|%s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])


func _run() -> void:
	var s := _arg("s", "full")
	_phase = "menu"
	await _wait(3.0)
	_info()
	_lod_test()
	if s == "color":
		await _color_test()
		_out("DONE")
		return
	if s == "dpr":
		await _dpr_test()
		_out("DONE")
		return
	if s == "shots":
		await _shots()
		_out("DONE")
		return
	if s == "info":
		_merge_bench()
		_out("DONE")
		return
	await _measure("menu", 3.0)
	if s == "full" or s == "quick":
		_phase = "track_select"
		await _goto(TRACK_SELECT)
		await _wait(2.0)
		await _measure("track_select", 3.0)
	var tracks := [0, 1, 2, 3] if s != "one" else [int(_arg("t", "0"))]
	for ti in tracks:
		var race := await _start_race(ti, 1)
		await _wait(3.0)
		await _measure("race_t%d_1p" % ti, 6.0)
		_wrap_ai(race)
		await _cpu_breakdown(race, "t%d_1p" % ti)
		if (s == "full" and (ti == 0 or ti == 3)) or s == "ab":
			await _ab(race, "ab_t%d" % ti)
		if s == "live" and (ti == 0 or ti == 3):
			await _live_ab(race, "t%d" % ti)
	if s == "full" or s == "quick":
		for p in [2, 4]:
			var race := await _start_race(0, p)
			await _wait(3.0)
			await _measure("race_t0_%dp" % p, 6.0)
			_wrap_ai(race)
			await _cpu_breakdown(race, "t0_%dp" % p)
	_phase = "done"
	_out("DONE")
