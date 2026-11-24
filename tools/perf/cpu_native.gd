extends SceneTree
## Probe de CPU NATIVO (headless, sem janela): carga da corrida, custo de cada script com
## a corrida andando e de cada parte do passo de física do kart. Complementa o probe web
## (zz_perf_probe.gd): aqui não há navegador, então os números são estáveis o bastante
## para comparar funções, mas não incluem GPU nem o custo do áudio do navegador.
##
## Uso (copie para _probe/, que o Godot enxerga; tools/ tem .gdignore):
##   cp tools/perf/cpu_native.gd _probe/
##   Godot --headless --audio-driver Dummy --path . -s res://_probe/cpu_native.gd -- track=0 patch=1
## Args: track=0..3  players=1..4  secs=4 (tempo medido)  patch=1 (cronometra o kart)
##
## Cuidados: compare sempre dentro da MESMA rodada (o Mac varia até 2x entre rodadas);
## os microbenchmarks rodam com dados quentes no cache (o custo real, com 8 karts e o
## Jolt alternando, é 1,5 a 3x maior, veja KARTPROF); `patch=1` troca o código do
## kart.gd só na memória e falha (assert) se os trechos procurados mudarem.

var frame := 0
var race: Node
var args := {"track": "0", "players": "1", "secs": "4", "patch": "0"}
var _keep: Array = []
var _phase := 0
var _t := 0.0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]


func _us() -> int:
	return Time.get_ticks_usec()


func _bench(label: String, n: int, f: Callable) -> float:
	var t0 := _us()
	for i in n:
		f.call()
	var us := float(_us() - t0) / n
	print("BENCH|%s|%.1f us/call" % [label, us])
	return us


func _process(d: float) -> bool:
	frame += 1
	if frame == 2:
		var gs = root.get_node("GameState")
		gs.selected_track_index = int(args.track)
		gs.mode = 1
		gs.laps = 99  # a corrida nunca termina: não grava recordes
		gs.speed_class = 1
		gs.difficulty = 1
		gs.cpu_enabled = true
		var devs: Array[int] = []
		if int(args.players) > 1:
			for i in int(args.players):
				devs.append(i)
		gs.set_players(devs)
		if args.patch == "1":
			_patch_kart()
		var t0 := _us()
		race = load("res://scenes/race.tscn").instantiate()
		root.add_child(race)
		current_scene = race
		print("LOAD|corrida (instanciar + _ready, pista inclusa)=%.1f ms" % ((_us() - t0) / 1000.0))
	elif frame == 3:
		# A corrida monta o grid aos poucos: espera o kart do J1 existir.
		if race.kart == null:
			frame = 2
			return false
		# O J1 também pilota sozinho (IA de referência).
		var ai = load("res://scripts/kart_ai.gd").new()
		var line = load("res://scripts/racing_line.gd").build(race.track)
		ai.setup(race.kart, race.track, line, race._karts, 0.85)
		race.kart.autopilot = ai.drive
		_keep.append(ai)
	elif frame > 3:
		_t += d
		if _phase == 0 and race.state == 1 and _t > 7.0:
			_phase = 1
			_micro()
			_live_split()
		elif _phase == 2 and _t > 7.0 + float(args.secs) + 0.5:
			_report_live()
			_report_patch()
			return true
	return false


## Troca o código do kart.gd (só na memória) por uma cópia com cronômetros em volta de
## cada parte do _physics_process.
func _patch_kart() -> void:
	var sc: GDScript = load("res://scripts/kart.gd")
	var src := sc.source_code
	var pairs := [
		["	var input := _gather_input()\n", "	var __t0 := Time.get_ticks_usec()\n	var input := _gather_input()\n	var __t1 := Time.get_ticks_usec()\n	PROF[0] += __t1 - __t0\n"],
		["	move_and_slide()\n	var now_on_floor", "	var __t2 := Time.get_ticks_usec()\n	move_and_slide()\n	var __t3 := Time.get_ticks_usec()\n	PROF[1] += __t3 - __t2\n	var now_on_floor"],
		["	_handle_walls(fwd, delta)\n	_update_skid_marks(now_on_floor)\n\n	_update_visuals(delta, steer)\n	_prev_speed = speed\n",
		 "	var __t4 := Time.get_ticks_usec()\n	_handle_walls(fwd, delta)\n	_update_skid_marks(now_on_floor)\n	var __t5 := Time.get_ticks_usec()\n	PROF[2] += __t5 - __t4\n	_update_visuals(delta, steer)\n	_prev_speed = speed\n	var __t6 := Time.get_ticks_usec()\n	PROF[3] += __t6 - __t5\n	PROF[4] += __t6 - __t0\n	PROF[5] += 1\n"],
		["var _dust_ratio := -1.0\n", "var _dust_ratio := -1.0\nstatic var PROF := [0, 0, 0, 0, 0, 0]\n"],
	]
	for pr in pairs:
		assert(src.count(pr[0]) == 1, "patch falhou (o kart.gd mudou?): " + pr[0].left(40))
		src = src.replace(pr[0], pr[1])
	sc.source_code = src
	print("PATCH|kart.gd err=%d" % sc.reload(true))


func _report_patch() -> void:
	var playing := 0
	var total3d := 0
	for k in race._karts:
		if k._engine_3d:
			total3d += 1
			if k._engine_3d.playing:
				playing += 1
	print("VOICES|motores 3D tocando=%d de %d" % [playing, total3d])
	if args.patch != "1":
		return
	var prof: Array = race.kart.PROF
	if prof[5] == 0:
		return
	var n: float = prof[5]
	print("KARTPROF|por kart por passo (us)|entrada/IA=%.1f|move_and_slide=%.1f|muros+marcas=%.1f|visual=%.1f|resto=%.1f|total=%.1f" % [
		prof[0] / n, prof[1] / n, prof[2] / n, prof[3] / n, (prof[4] - prof[0] - prof[1] - prof[2] - prof[3]) / n, prof[4] / n])


# --- Microbenchmarks com o jogo andando (chamadas extras, mesmo estado) -------------

func _micro() -> void:
	var dt := 1.0 / 60.0
	var player = race.kart
	var ai_kart = null
	var ai = null
	for r in race.racers:
		if r.ai and r.kart != player:
			ai_kart = r.kart
			ai = r.ai
			break
	_bench("ai.drive (1 kart)", 400, func(): ai_kart._gather_input())
	var tr = race.track
	var along: float = tr.get_along(tr.to_local(ai_kart.global_position), ai._index)
	_bench("ai._target_lateral", 400, func(): ai._target_lateral(ai_kart, along, along + 15.0, 0.0, dt))
	_bench("ai._avoid_offset", 400, func(): ai._avoid_offset(ai_kart, 0.0, 0.0))
	_bench("ai._update_drift", 400, func(): ai._update_drift(ai_kart, along, 20.0, 0.1, 1.0, 0.1, false, dt))
	_bench("line.max_curvature(30 m)", 400, func(): ai.line.max_curvature(100.0, 30.0))
	_bench("line.turn_between(40 m)", 400, func(): ai.line.turn_between(100.0, 40.0))
	_bench("track.get_closest_index(dica)", 400, func(): tr.get_closest_index(tr.to_local(ai_kart.global_position), ai._index, 10))
	_bench("kart._update_visuals", 400, func(): ai_kart._update_visuals(dt, 0.2))
	_bench("kart_visual.update_motion", 400, func(): ai_kart.kart_visual.update_motion(dt, 20.0, 0.2, 0))
	var rig = ai_kart.driver
	var old_every: int = rig.update_every
	rig.update_every = 1
	_bench("rig._process (pose completa)", 200, func(): rig._process(dt))
	rig.update_every = old_every
	# move_and_slide: salva e devolve a posição (o custo de devolver é medido à parte).
	var xf: Transform3D = ai_kart.global_transform
	var vel: Vector3 = ai_kart.velocity
	var restore := _bench("devolver posição", 200, func():
		ai_kart.global_transform = xf
		ai_kart.velocity = vel)
	var mas := _bench("move_and_slide + devolver", 200, func():
		ai_kart.move_and_slide()
		ai_kart.global_transform = xf
		ai_kart.velocity = vel)
	print("BENCH|move_and_slide (estimado)|%.1f us/call" % (mas - restore))
	if race.track.coins:
		_bench("coins._physics_process", 200, func(): race.track.coins._physics_process(0.0))
	if player._engine:
		# Motor sintetizado do J1 (corrida com um jogador só).
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		var p := AudioStreamPlayer.new()
		p.stream = gen
		root.add_child(p)
		p.play()
		var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
		var t0 := _us()
		var frames := 0
		for rep in 20:
			pb.clear_buffer()
			var old = player._engine
			player._engine = pb
			frames += pb.get_frames_available()
			player._fill_engine_audio()
			player._engine = old
		var us := float(_us() - t0)
		print("BENCH|motor sintetizado|%.2f us/amostra|%.0f us por quadro a 60 fps" % [us / frames, us / frames * 22050.0 / 60.0])
		p.queue_free()


# --- Custo por script com o jogo andando (como o probe web) ------------------------

var _ins := {}
var _ticks := 0
var _frames := 0
var _step_ms := PackedFloat32Array()
var _pf_t := 0
var _pf_n := 0


func _live_split() -> void:
	for n in race.find_children("*", "", true, false):
		var sc: Script = n.get_script()
		if sc == null:
			continue
		var key: String = sc.resource_path.get_file()
		var g: Dictionary = _ins.get(key, {"p": [], "pp": [], "us_p": 0, "us_pp": 0})
		if n.is_processing() and n.has_method("_process"):
			n.set_process(false)
			g.p.append(n)
		if n.is_physics_processing() and n.has_method("_physics_process"):
			n.set_physics_process(false)
			g.pp.append(n)
		if not g.p.is_empty() or not g.pp.is_empty():
			_ins[key] = g
	if race.is_physics_processing():
		race.set_physics_process(false)
		_ins["race.gd"] = {"p": [], "pp": [race], "us_p": 0, "us_pp": 0}
	var hook := Node.new()
	var s := GDScript.new()
	s.source_code = "extends Node\nfunc _process(d):\n\tget_meta(\"probe\")._run(\"p\", d)\nfunc _physics_process(d):\n\tget_meta(\"probe\")._run(\"pp\", d)\n"
	s.reload()
	hook.set_script(s)
	hook.set_meta("probe", self)
	root.add_child(hook)
	# Passo inteiro (scripts + Jolt + interpolação): do sinal physics_frame (começo do
	# passo) ao process_frame seguinte. O monitor TIME_PHYSICS_PROCESS não serve: o Godot
	# só o atualiza uma vez por segundo, com o MAIOR passo daquele segundo.
	physics_frame.connect(func():
		if _pf_n == 0:
			_pf_t = _us()
		_pf_n += 1)
	process_frame.connect(func():
		if _pf_n > 0:
			var ms := (_us() - _pf_t) / 1000.0 / _pf_n
			for i in _pf_n:
				_step_ms.append(ms)
			_pf_n = 0)
	_phase = 2


func _run(kind: String, d: float) -> void:
	if kind == "pp":
		_ticks += 1
	else:
		_frames += 1
	for key in _ins:
		var g: Dictionary = _ins[key]
		var t0 := _us()
		for n in g[kind]:
			if is_instance_valid(n) and n.is_inside_tree():
				if kind == "p":
					n._process(d)
				else:
					n._physics_process(d)
		g["us_" + kind] += _us() - t0


func _report_live() -> void:
	var rows := []
	var total := 0.0
	for key in _ins:
		var g: Dictionary = _ins[key]
		var pp: float = g.us_pp / 1000.0 / maxi(_ticks, 1)
		var p: float = g.us_p / 1000.0 / maxi(_frames, 1)
		rows.append([pp + p, key, pp, p])
		total += pp
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows:
		if r[0] > 0.005:
			print("LIVE|%s|física=%.3f ms/passo|_process=%.3f ms/quadro" % [r[1], r[2], r[3]])
	var steps := _step_ms.duplicate()
	steps.sort()
	var med: float = steps[steps.size() / 2] if steps.size() > 0 else 0.0
	var p95: float = steps[int(steps.size() * 0.95)] if steps.size() > 0 else 0.0
	print("LIVE|scripts na física=%.3f ms/passo|passo inteiro mediana=%.3f p95=%.3f ms|passos=%d quadros=%d" % [
		total, med, p95, _ticks, _frames])
