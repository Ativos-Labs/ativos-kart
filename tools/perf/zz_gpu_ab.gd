extends SceneTree
## A/B de GPU no Forward+ (com janela, mas não precisa dela visível). Corrida real, J1 na
## IA; em `views` momentos da corrida (segundos de corrida: first, first+gap, ...) o jogo
## pausa e, com a câmera parada, alterna base / variante numa SubViewport grande (4K: a
## GPU do M4 fica no limite, como uma placa fraca em 1080p). Cada variante é medida entre
## duas bases (pareado); a amostra é um quadro forçado (force_draw + force_sync), então
## vale mesmo com a janela coberta (o macOS para de desenhar janelas cobertas).
## Imprime GPUAB|... por vista (GPU e CPU da renderização) e um resumo SUMMARY|.
## Args: tracks=0,1,2,3 views=4 first=8 gap=12 res=3840x2160 settle=10 frames=24
##       only=a,b (variantes) lod=1.0 players=1
##       shots=1 shotdir=/abs/dir: salva um PNG da SubViewport por variante (use res=1920x1080)
## Rode com tools/perf/run_desktop.sh (guarda e devolve as opções/recordes do jogo).
##
## Cuidados (medidos em 2026-11-24):
## - Variantes que mudam constantes de especialização (sombra, PCSS, divisões, filtro,
##   MSAA) recompilam pipelines e o Godot usa o ubershader até terminar: com settle
##   curto (6 quadros) o "PCSS desligado" parecia economizar 4,6 ms e era 0. Use
##   settle=40 para essas.
## - "uniform_set is null" no log vem das partículas na SubViewport extra (some com
##   particulas_ocultas; não acontece no jogo, nem com a tela dividida). Custa ~0,3 ms.

var args := {"tracks": "0,1,2,3", "views": "4", "first": "8", "gap": "12", "res": "3840x2160",
	"settle": "10", "frames": "24", "only": "", "lod": "1.0", "players": "1", "shots": "", "shotdir": ""}
var gs: Node
var race: Node
var tracks: PackedInt32Array
var ti := -1
var phase := "boot"
var frame := 0
var view_i := 0
var sub: SubViewport
var sub_cam: Camera3D
var last_us := 0
var steps: Array = []  # [name, apply, revert]
var step_i := 0
var step_frame := 0
var samples := PackedFloat32Array()
var gpu_samples := PackedFloat32Array()
var compiles_at := 0
var view_rows := {}  # variant -> Array of [base_ms, var_ms]
var all_rows := {}   # variant -> Array of delta
var per_track := {}  # track -> variant -> Array of delta
var cur_base := []
var warmed := false

const SPEC := Performance.PIPELINE_COMPILATIONS_SPECIALIZATION


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	for s in args.tracks.split(","):
		tracks.append(int(s))


func _process(_d: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	var dt := (now - last_us) / 1000.0
	last_us = now
	if frame == 1:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(320, 180))
	if frame == 3:
		gs = root.get_node("GameState")
		var gq = gs.settings.graphics
		gq._values = gq.preset_values(2)  # Alta, sem gravar
		gq._apply_globals()
		gs.render_scale.fixed = 1.0
		print("INFO|adapter=%s driver=%s method=%s" % [RenderingServer.get_video_adapter_name(),
			RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method()])
		_next_track()
		return false
	match phase:
		"loading":
			if not gs._changing_scene and current_scene and current_scene.has_method(&"warm_up") and current_scene.is_node_ready():
				_hook()
				if phase == "loading":
					phase = "countdown"
		"countdown":
			_sync_cam()
			if race.state == 1:
				phase = "racing"
				_race_t = 0.0
		"racing":
			_sync_cam()
			_race_t += _d
			if _race_t >= float(args.first) + float(args.gap) * view_i:
				paused = true
				_start_view()
				phase = "ab"
		"ab":
			_sync_cam()
			_ab_frame(dt)
	return false


func _next_track() -> void:
	ti += 1
	if ti >= tracks.size():
		_summary()
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
	gs.goto_scene("res://scenes/race.tscn")
	phase = "loading"
	view_i = 0
	warmed = false


func _hook() -> void:
	race = current_scene
	var ai = load("res://scripts/kart_ai.gd").new()
	var line = load("res://scripts/racing_line.gd").build(race.track)
	ai.setup(race.kart, race.track, line, race._karts, 0.85)
	ai.pace = 1.0
	ai.rubber_band = 0.0
	race.kart.autopilot = ai.drive
	set_meta(&"ai", ai)
	var r: PackedStringArray = args.res.split("x")
	sub = SubViewport.new()
	sub.size = Vector2i(int(r[0]), int(r[1]))
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.use_taa = root.use_taa
	sub.use_debanding = root.use_debanding
	sub.scaling_3d_mode = root.scaling_3d_mode
	sub.scaling_3d_scale = 1.0
	sub.anisotropic_filtering_level = root.anisotropic_filtering_level
	sub.msaa_3d = root.msaa_3d
	sub.screen_space_aa = root.screen_space_aa
	sub.mesh_lod_threshold = float(args.lod)
	sub.positional_shadow_atlas_size = root.positional_shadow_atlas_size
	sub_cam = Camera3D.new()
	sub.add_child(sub_cam)
	root.add_child(sub)
	sub_cam.current = true
	root.disable_3d = true
	RenderingServer.viewport_set_measure_render_time(sub.get_viewport_rid(), true)
	_build_steps()
	print("INFO|track=%d msaa=%d lod=%.1f steps=%d" % [tracks[ti], sub.msaa_3d, sub.mesh_lod_threshold, steps.size()])


func _sync_cam() -> void:
	var c: Camera3D = race.get_node("Camera")
	sub_cam.global_transform = c.global_transform
	sub_cam.fov = c.fov
	sub_cam.near = c.near
	sub_cam.far = c.far
	sub_cam.keep_aspect = c.keep_aspect
	sub_cam.environment = c.environment
	sub_cam.attributes = c.attributes
	sub_cam.cull_mask = c.cull_mask


func _light() -> DirectionalLight3D:
	for n in race.find_children("*", "DirectionalLight3D", true, false):
		return n
	return null


func _env() -> Environment:
	for n in race.find_children("*", "WorldEnvironment", true, false):
		return n.environment
	return null


func _geo(under: Node, cls: String) -> Array:
	return under.find_children("*", cls, true, false)


func _set_shadow(nodes: Array, on: bool, store: Dictionary) -> void:
	for n in nodes:
		var gi := n as GeometryInstance3D
		if on:
			if store.has(gi):
				gi.cast_shadow = store[gi]
		else:
			store[gi] = gi.cast_shadow
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _set_visible(nodes: Array, on: bool, store: Dictionary) -> void:
	for n in nodes:
		if on:
			if store.has(n):
				n.visible = store[n]
		else:
			store[n] = n.visible
			n.visible = false


func _build_steps() -> void:
	steps.clear()
	var L := _light()
	var E := _env()
	var tr: Node = race.track
	var karts: Node = race.get_node("Karts")
	var vars: Array = []
	var st := {}
	vars.append(["sombra_off", func(): L.shadow_enabled = false, func(): L.shadow_enabled = true])
	vars.append(["pcss_off", func(): st.ang = L.light_angular_distance; L.light_angular_distance = 0.0, func(): L.light_angular_distance = st.ang])
	vars.append(["2_divisoes", func(): st.m = L.directional_shadow_mode; st.s1 = L.directional_shadow_split_1; L.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; L.directional_shadow_split_1 = 0.18,
		func(): L.directional_shadow_mode = st.m; L.directional_shadow_split_1 = st.s1])
	vars.append(["sem_blend", func(): L.directional_shadow_blend_splits = false, func(): L.directional_shadow_blend_splits = true])
	vars.append(["sombra_120m", func(): st.md = L.directional_shadow_max_distance; L.directional_shadow_max_distance = 120.0, func(): L.directional_shadow_max_distance = st.md])
	var mm := _geo(tr, "MultiMeshInstance3D")
	var st_mm := {}
	vars.append(["multimesh_sem_sombra", func(): _set_shadow(mm, false, st_mm), func(): _set_shadow(mm, true, st_mm)])
	var props := _geo(tr, "MeshInstance3D")
	var st_pr := {}
	vars.append(["malhas_pista_sem_sombra", func(): _set_shadow(props, false, st_pr), func(): _set_shadow(props, true, st_pr)])
	var kg := _geo(karts, "GeometryInstance3D")
	var st_kg := {}
	vars.append(["karts_sem_sombra", func(): _set_shadow(kg, false, st_kg), func(): _set_shadow(kg, true, st_kg)])
	var kn := karts.get_children()
	var st_kn := {}
	vars.append(["karts_ocultos", func(): _set_visible(kn, false, st_kn), func(): _set_visible(kn, true, st_kn)])
	vars.append(["ssao_off", func(): E.ssao_enabled = false, func(): E.ssao_enabled = true])
	vars.append(["glow_off", func(): E.glow_enabled = false, func(): E.glow_enabled = true])
	vars.append(["fog_off", func(): st.fog = E.fog_enabled; E.fog_enabled = false, func(): E.fog_enabled = st.fog])
	vars.append(["msaa_off", func(): sub.msaa_3d = Viewport.MSAA_DISABLED, func(): sub.msaa_3d = root.msaa_3d])
	vars.append(["msaa_2x", func(): sub.msaa_3d = Viewport.MSAA_2X, func(): sub.msaa_3d = root.msaa_3d])
	var terr := tr.find_children("Terreno*", "GeometryInstance3D", true, false)
	var st_te := {}
	vars.append(["terreno_oculto", func(): _set_visible(terr, false, st_te), func(): _set_visible(terr, true, st_te)])
	var coins := tr.find_children("Moedas*", "", true, false)
	var st_co := {}
	vars.append(["moedas_ocultas", func(): _set_visible(coins, false, st_co), func(): _set_visible(coins, true, st_co)])
	var mm_vis := mm.filter(func(n): return not coins.has(n) and not coins.has(n.get_parent()))
	var st_mv := {}
	vars.append(["multimesh_ocultos", func(): _set_visible(mm_vis, false, st_mv), func(): _set_visible(mm_vis, true, st_mv)])
	var parts := race.find_children("*", "GPUParticles3D", true, false)
	var st_pa := {}
	vars.append(["particulas_ocultas", func(): _set_visible(parts, false, st_pa), func(): _set_visible(parts, true, st_pa)])
	var gq = gs.settings.graphics
	var apply_preset := func(p: int):
		var vals: Dictionary = gq.preset_values(p)
		vals[&"resolucao_3d"] = 1.0
		gq._values = vals
		gq._apply_globals()
		gq._apply_tree()
		gs.render_scale.fixed = 1.0
		sub.msaa_3d = root.msaa_3d
		sub.screen_space_aa = root.screen_space_aa
		sub.mesh_lod_threshold = root.mesh_lod_threshold
	vars.append(["preset_media", func(): apply_preset.call(1), func(): apply_preset.call(2)])
	vars.append(["preset_baixa", func(): apply_preset.call(0), func(): apply_preset.call(2)])
	var ssao_set := func(q: int, half: bool):
		RenderingServer.environment_set_ssao_quality(q as RenderingServer.EnvironmentSSAOQuality, half,
			ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target"),
			ProjectSettings.get_setting("rendering/environment/ssao/blur_passes"),
			ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from"),
			ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to"))
	var q0: int = ProjectSettings.get_setting("rendering/environment/ssao/quality")
	var h0: bool = ProjectSettings.get_setting("rendering/environment/ssao/half_size")
	vars.append(["ssao_low", func(): ssao_set.call(RenderingServer.ENV_SSAO_QUALITY_LOW, h0), func(): ssao_set.call(q0, h0)])
	var bic0: bool = int(ProjectSettings.get_setting("rendering/environment/glow/upscale_mode")) == 1
	vars.append(["glow_linear", func(): RenderingServer.environment_glow_set_use_bicubic_upscale(false), func(): RenderingServer.environment_glow_set_use_bicubic_upscale(bic0)])
	var f0: int = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")
	vars.append(["filtro_sombra_vlow", func(): RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW),
		func(): RenderingServer.directional_soft_shadow_filter_set_quality(f0 as RenderingServer.ShadowQuality)])
	var a0: int = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")
	var b16: bool = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits")
	vars.append(["atlas_2048", func(): RenderingServer.directional_shadow_atlas_set_size(2048, b16), func(): RenderingServer.directional_shadow_atlas_set_size(a0, b16)])
	vars.append(["pcss_3", func(): st.ang3 = L.light_angular_distance; L.light_angular_distance = 3.0, func(): L.light_angular_distance = st.ang3])
	vars.append(["pcss_off_sem_blend_base", func(): st.ang4 = L.light_angular_distance; L.light_angular_distance = 0.0, func(): L.light_angular_distance = st.ang4])
	vars.append(["blend_e_pcss_off", func(): st.ang2 = L.light_angular_distance; L.light_angular_distance = 0.0; L.directional_shadow_blend_splits = false,
		func(): L.light_angular_distance = st.ang2; L.directional_shadow_blend_splits = true])
	# Como era antes: um MultiMesh só com todas as moedas (os blocos ficam escondidos).
	var tc = race.track.coins
	if tc:
		var old_mmi := MultiMeshInstance3D.new()
		var omm := MultiMesh.new()
		omm.transform_format = MultiMesh.TRANSFORM_3D
		omm.use_custom_data = true
		omm.mesh = tc.coin_mesh()
		omm.instance_count = tc.positions.size()
		for i in tc.positions.size():
			omm.set_instance_transform(i, Transform3D(tc._bases[i], tc.positions[i]))
			omm.set_instance_custom_data(i, Color(float(i), 0, 0, 0))
		old_mmi.multimesh = omm
		old_mmi.material_override = tc.coin_material()
		old_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		old_mmi.extra_cull_margin = 0.5
		old_mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		old_mmi.visible = false
		tc.add_child(old_mmi)
		var chunks: Array = tc.find_children("Moedas*", "MultiMeshInstance3D", false, false)
		vars.append(["moedas_antigas", func():
			for c in chunks: c.visible = false
			old_mmi.visible = true,
			func():
				for c in chunks: c.visible = true
				old_mmi.visible = false])
		# O Alta de antes de 2026-11-24: MSAA 4x, glow bicúbico e as moedas num MultiMesh só.
		vars.append(["alta_antiga", func():
			sub.msaa_3d = Viewport.MSAA_4X
			RenderingServer.environment_glow_set_use_bicubic_upscale(true)
			for c in chunks: c.visible = false
			old_mmi.visible = true,
			func():
				sub.msaa_3d = root.msaa_3d
				RenderingServer.environment_glow_set_use_bicubic_upscale(bic0)
				for c in chunks: c.visible = true
				old_mmi.visible = false])
	vars.append(["msaa_4x", func(): sub.msaa_3d = Viewport.MSAA_4X, func(): sub.msaa_3d = root.msaa_3d])
	vars.append(["glow_bicubico", func(): RenderingServer.environment_glow_set_use_bicubic_upscale(true), func(): RenderingServer.environment_glow_set_use_bicubic_upscale(bic0)])
	vars.append(["lod_4px", func(): sub.mesh_lod_threshold = 4.0, func(): sub.mesh_lod_threshold = float(args.lod)])
	vars.append(["base_aa", func(): pass, func(): pass])  # A/A: ruído
	var only: PackedStringArray = args.only.split(",", false)
	for v in vars:
		if only.is_empty() or only.has(v[0]):
			steps.append(v)


var _race_t := 0.0
var cpu_samples := PackedFloat32Array()
var view_cpu := {}
var all_cpu := {}
var cur_base_cpu := []
var _drawn0 := 0
var _frame0 := 0


func _start_view() -> void:
	if args.shots != "":
		Engine.time_scale = 0.0  # TIME dos shaders parado: os prints só diferem pela variante
	_drawn0 = Engine.get_frames_drawn()
	_frame0 = frame
	step_i = -1
	view_rows = {}
	cur_base = []
	cur_base_cpu = []
	view_cpu = {}
	compiles_at = int(Performance.get_monitor(SPEC))
	if not warmed:
		# Liga cada variante uns quadros antes (compila o que precisar).
		warmed = true
		for v in steps:
			v[1].call()
		step_frame = -20
		step_i = -2  # quadros de aquecimento, depois volta tudo
		return
	_next_step()


func _next_step() -> void:
	step_i += 1
	step_frame = 0
	samples = PackedFloat32Array()
	cpu_samples = PackedFloat32Array()
	gpu_samples = PackedFloat32Array()


## Sequência: base, var0, base, var1, base, ... (cada variante entre duas bases).
func _ab_frame(dt: float) -> void:
	if step_i == -2:
		step_frame += 1
		if step_frame == 0:
			for v in steps:
				v[2].call()
		if step_frame >= 15:
			step_i = -1
			_next_step()
		return
	var n_steps := steps.size() * 2 + 1
	if step_i >= n_steps:
		_end_view()
		return
	var is_base := step_i % 2 == 0
	var v = null if is_base else steps[step_i / 2]
	if step_frame == 0 and v != null:
		v[1].call()
	if step_frame == int(args.settle) + 2:
		print("STEP|%s" % ("base" if v == null else v[0]))
	if args.shots != "" and step_frame == int(args.settle) + 1 and (v != null or step_i == 0):
		RenderingServer.force_draw(false, 0.0)
		RenderingServer.force_sync()
		var img := sub.get_texture().get_image()
		var nm: String = "base" if v == null else v[0]
		img.save_png("%s/t%d_v%d_%s.png" % [args.shotdir, tracks[ti], view_i, nm])
	step_frame += 1
	var settle := int(args.settle)
	if step_frame > settle + 1:
		# Quadro forçado (não depende da janela estar visível): o 1º absorve o que
		# estava pendente, o 2º é o medido (draw + espera a GPU terminar).
		RenderingServer.force_sync()
		var f0 := Time.get_ticks_usec()
		RenderingServer.force_draw(false, 0.0)
		RenderingServer.force_sync()
		samples.append((Time.get_ticks_usec() - f0) / 1000.0)
		cpu_samples.append(RenderingServer.get_frame_setup_time_cpu()
			+ RenderingServer.viewport_get_measured_render_time_cpu(sub.get_viewport_rid())
			+ RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(sub.get_viewport_rid()))
	if step_frame >= settle + 1 + int(args.frames):
		var med := _median(samples)
		var gmed := _median(gpu_samples)
		var cmed := _median(cpu_samples)
		if is_base:
			cur_base.append(med)
			cur_base_cpu.append(cmed)
			if step_i > 0:
				var pv = steps[step_i / 2 - 1]
				var b0: float = cur_base[cur_base.size() - 2]
				var b1: float = cur_base[cur_base.size() - 1]
				var vm: float = view_rows[pv[0]]
				var delta := vm - (b0 + b1) * 0.5
				_record(pv[0], delta)
				var cb: float = (cur_base_cpu[cur_base_cpu.size() - 2] + cur_base_cpu[cur_base_cpu.size() - 1]) * 0.5
				var cdelta: float = view_cpu[pv[0]] - cb
				if not all_cpu.has(pv[0]):
					all_cpu[pv[0]] = []
				all_cpu[pv[0]].append(cdelta)
				print("GPUAB|t%d v%d|%-24s base=%.2f var=%.2f delta=%+.2f ms | cpu_render base=%.2f delta=%+.2f" % [tracks[ti], view_i, pv[0], (b0 + b1) * 0.5, vm, delta, cb, cdelta])
		else:
			view_rows[v[0]] = med
			view_cpu[v[0]] = cmed
			v[2].call()
		_next_step()


func _record(name: String, delta: float) -> void:
	if not all_rows.has(name):
		all_rows[name] = []
	all_rows[name].append(delta)
	var t: int = tracks[ti]
	if not per_track.has(t):
		per_track[t] = {}
	if not per_track[t].has(name):
		per_track[t][name] = []
	per_track[t][name].append(delta)


func _end_view() -> void:
	var comp := int(Performance.get_monitor(SPEC)) - compiles_at
	print("VIEW|t%d v%d along=%.0f base_med=%.2f spec_compiles=%d drawn=%d/%d" % [tracks[ti], view_i,
		race.racers[0].along if race.racers.size() > 0 else -1.0, _median(PackedFloat32Array(cur_base)), comp,
		Engine.get_frames_drawn() - _drawn0, frame - _frame0])
	paused = false
	Engine.time_scale = 1.0
	view_i += 1
	if view_i >= int(args.views):
		sub.queue_free()
		root.disable_3d = false
		_next_track()
	else:
		phase = "racing"


func _median(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _summary() -> void:
	print("SUMMARY|variante|mediana delta (ms) todas as vistas|por pista")
	var names := all_rows.keys()
	names.sort_custom(func(a, b): return _median(PackedFloat32Array(all_rows[a])) < _median(PackedFloat32Array(all_rows[b])))
	for nm in names:
		var pt: PackedStringArray = []
		for t in per_track:
			if per_track[t].has(nm):
				pt.append("t%d=%+.2f" % [t, _median(PackedFloat32Array(per_track[t][nm]))])
		print("SUMMARY|%-24s %+.2f|cpu_render %+.2f|%s" % [nm, _median(PackedFloat32Array(all_rows[nm])), _median(PackedFloat32Array(all_cpu.get(nm, []))), " ".join(pt)])
