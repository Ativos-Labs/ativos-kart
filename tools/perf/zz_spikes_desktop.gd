extends SceneTree
## Sonda de picos no meio da corrida (com janela: precisa da GPU de verdade).
## J1 no piloto automático, rivais normais. Mede cada quadro depois da largada:
## intervalo real, tempo de process/physics, GPU (Vulkan), compilações de pipeline,
## memória de vídeo e eventos do jogo no quadro (turbo, drift, moedas, caixas...).
## Args (depois de --): tracks=0,1,2,3 secs=45 warm=1 players=1

var args := {"tracks": "0,1,2,3", "secs": "45", "warm": "1", "players": "1", "scaletest": "0"}
var scale_steps := [[8.0, 0.88], [16.0, 1.0], [24.0, 0.76], [32.0, 1.0], [40.0, 0.88]]
var scale_i := 0
var last_lap := 0
var gs: Node
var race: Node
var tracks: PackedInt32Array
var ti := -1
var phase := "boot"
var frame := 0
var t_start := 0
var last_us := 0
var rows: Array = []
var events: Array[String] = []
var last_counters := {}
var last_scale := 1.0
var vp_rid: RID
var results: Array[String] = []

const COUNTERS := {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"spec": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	for s in args.tracks.split(","):
		tracks.append(int(s))


func _counters() -> Dictionary:
	var out := {}
	for k in COUNTERS:
		out[k] = int(Performance.get_monitor(COUNTERS[k]))
	return out


func _next_track() -> void:
	ti += 1
	if ti >= tracks.size():
		print("\n".join(results))
		quit()
		return
	gs.selected_track_index = tracks[ti]
	gs.mode = 1
	gs.laps = 99
	gs.speed_class = 1
	gs.difficulty = 1
	var devs: Array[int] = []
	if int(args.players) > 1:
		for i in int(args.players):
			devs.append(i)
	gs.set_players(devs)
	if args.warm == "0":
		# Como era antes: sem warm_up (cena trocada direto).
		change_scene_to_file("res://scenes/race.tscn")
	else:
		gs.goto_scene("res://scenes/race.tscn")
	phase = "loading"
	rows.clear()


func _hook() -> void:
	race = current_scene
	var ai = load("res://scripts/kart_ai.gd").new()
	var line = load("res://scripts/racing_line.gd").build(race.track)
	ai.setup(race.kart, race.track, line, race._karts, 0.85)
	ai.pace = 1.0
	ai.rubber_band = 0.0
	race.kart.autopilot = ai.drive
	set_meta(&"ai", ai)
	for k in race._karts:
		var n: String = k.name
		k.boost_started.connect(func(p): events.append("boost%d:%s" % [p, n]))
		k.jumped.connect(func(): events.append("jump:" + n))
		k.landed.connect(func(_s): events.append("land:" + n))
		k.trick_performed.connect(func(): events.append("trick:" + n))
		k.item_box_collected.connect(func(_b): events.append("itembox:" + n))
		k.coin_collected.connect(func(): events.append("coin:" + n))
		k.obstacle_hit.connect(func(_l, _s): events.append("obstacle:" + n))
		k.kart_bumped.connect(func(_o, _s): events.append("kartbump:" + n))
		k.bumped.connect(func(_s): events.append("wall:" + n))
	race.kart.drift_level_changed.connect(func(l): events.append("drift%d:J1" % l))
	vp_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 1:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	if frame == 3:
		gs = root.get_node("GameState")
		_next_track()
		return false
	if phase == "loading":
		if not gs._changing_scene and current_scene and current_scene.has_method(&"warm_up") and current_scene.is_node_ready():
			_hook()
			phase = "countdown"
	elif phase == "countdown":
		if race.state == 1:
			phase = "racing"
			t_start = Time.get_ticks_msec()
			last_us = Time.get_ticks_usec()
			last_counters = _counters()
			last_scale = root.scaling_3d_scale
			scale_i = 0
			last_lap = 0
			events.clear()
	elif phase == "racing":
		var now := Time.get_ticks_usec()
		var c := _counters()
		var dc := {}
		var total := 0
		for k in c:
			dc[k] = c[k] - last_counters[k]
			total += dc[k]
		last_counters = c
		var tsec := (Time.get_ticks_msec() - t_start) / 1000.0
		if args.scaletest == "1" and scale_i < scale_steps.size() and tsec >= scale_steps[scale_i][0]:
			gs.render_scale.dynamic = scale_steps[scale_i][1]
			gs.render_scale.apply()
			scale_i += 1
		if race.player.laps_done != last_lap:
			last_lap = race.player.laps_done
			events.append("lap%d" % last_lap)
		var cam_env = race.get_node("Camera").environment
		if cam_env != (get_meta(&"last_env") if has_meta(&"last_env") else null):
			events.append("env:" + ("submerso" if cam_env else "normal"))
			set_meta(&"last_env", cam_env)
		if not is_equal_approx(root.scaling_3d_scale, last_scale):
			events.append("scale%.2f->%.2f" % [last_scale, root.scaling_3d_scale])
			last_scale = root.scaling_3d_scale
		rows.append({
			"ms": (now - last_us) / 1000.0,
			"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"gpu": RenderingServer.viewport_get_measured_render_time_gpu(vp_rid),
			"cpu_r": RenderingServer.viewport_get_measured_render_time_cpu(vp_rid),
			"comp": total, "dc": dc,
			"vmem": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"t": (Time.get_ticks_msec() - t_start) / 1000.0,
			"ev": events.duplicate(),
			"drawn": Engine.get_frames_drawn(),
			"scale": root.scaling_3d_scale,
		})
		events.clear()
		last_us = now
		if Time.get_ticks_msec() - t_start > int(args.secs) * 1000:
			_summarize()
			_next_track()
	return false


func _summarize() -> void:
	var ms := PackedFloat32Array()
	for r in rows:
		ms.append(r.ms)
	var sorted := ms.duplicate()
	sorted.sort()
	var n := sorted.size()
	var med := sorted[n / 2]
	var comp_total := {}
	for k in COUNTERS:
		comp_total[k] = 0
	var vmin := 1e9
	var vmax := 0.0
	for r in rows:
		for k in r.dc:
			comp_total[k] += r.dc[k]
		vmin = minf(vmin, r.vmem)
		vmax = maxf(vmax, r.vmem)
	var g := PackedFloat32Array()
	for r in rows:
		g.append(r.gpu)
	g.sort()
	var undrawn := 0
	for i in range(1, rows.size()):
		if rows[i].drawn == rows[i - 1].drawn:
			undrawn += 1
	var over25 := 0
	var over50 := 0
	for v in ms:
		if v > 25.0: over25 += 1
		if v > 50.0: over50 += 1
	results.append("SPIKES track=%d warm=%s frames=%d med=%.2f p95=%.2f p99=%.2f max=%.2f >25ms=%d >50ms=%d compiles=%s vmem=%.1f..%.1fMB scale_end=%.2f gpu med=%.2f p95=%.2f p99=%.2f max=%.2f undrawn=%d scale_start=%.2f" % [
		tracks[ti], args.warm, n, med, sorted[int(n * 0.95)], sorted[int(n * 0.99)], sorted[n - 1],
		over25, over50, comp_total, vmin, vmax, root.scaling_3d_scale, g[n / 2], g[int(n * 0.95)], g[int(n * 0.99)], g[n - 1], undrawn, rows[0].get("scale", 0.0)])
	# Piores quadros com o contexto (eventos deste e dos 2 anteriores).
	var idx := range(rows.size())
	idx.sort_custom(func(a, b): return rows[a].ms > rows[b].ms)
	for j in mini(12, idx.size()):
		var i: int = idx[j]
		var r = rows[i]
		if r.ms < med * 1.8:
			break
		var ev: Array = []
		for back in range(maxi(0, i - 2), i + 1):
			ev.append_array(rows[back].ev)
		results.append("  t=%6.2fs %6.2fms proc=%.2f phys=%.2f gpu=%.2f cpu_r=%.2f comp=%d %s vmem=%.1f draws=%d ev=%s" % [
			r.t, r.ms, r.proc, r.phys, r.gpu, r.cpu_r, r.comp, r.dc if r.comp > 0 else "", r.vmem, r.draws, ev])
	for i in rows.size():
		for e in rows[i].ev:
			if String(e).begins_with("scale") or String(e).begins_with("lap"):
				var around := PackedStringArray()
				for k in range(i, mini(rows.size(), i + 6)):
					around.append("%.1f" % rows[k].ms)
				results.append("  EVENT %s t=%.2f frames(ms)=%s comp=%d" % [e, rows[i].t, ",".join(around), rows[i].comp + (rows[i + 1].comp if i + 1 < rows.size() else 0)])
	# Compilações fora dos piores quadros também contam.
	var comp_frames: Array[String] = []
	for r in rows:
		if r.comp > 0:
			comp_frames.append("t=%.2f n=%d %.1fms ev=%s" % [r.t, r.comp, r.ms, r.ev])
	if not comp_frames.is_empty():
		results.append("  compile frames: " + "; ".join(comp_frames.slice(0, 25)))
