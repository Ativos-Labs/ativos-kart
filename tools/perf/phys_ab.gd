extends SceneTree
## A/B do passo de física (headless): quanto do TIME_PHYSICS_PROCESS é do motor
## (interpolação, áreas, Jolt) e quanto é dos scripts. Alterna configurações em blocos
## de `block` passos (base, A, base, B, ...), `rounds` vezes; mediana por configuração.
## Uso (copie para _probe/): Godot --headless --audio-driver Dummy --path . \
##     -s res://_probe/phys_ab.gd -- track=0 [block=90] [rounds=4] [only=a,b]
## O passo é medido do sinal physics_frame ao process_frame seguinte (scripts + Jolt +
## interpolação); o monitor TIME_PHYSICS_PROCESS é o MAIOR passo de cada segundo.

var frame := 0
var race: Node
var args := {"track": "0", "block": "90", "rounds": "4", "skip": "12", "only": ""}
var _t := 0.0
var _started := false
var configs: Array = []  # [name, apply, revert]
var seq: Array = []
var seq_i := 0
var tick_in_block := 0
var cur: Array = []
var res := {}  # name -> Array of block medians
var hook: Node


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]


func _process(d: float) -> bool:
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
	elif frame == 3:
		if race.kart == null:
			frame = 2
			return false
		var ai = load("res://scripts/kart_ai.gd").new()
		var line = load("res://scripts/racing_line.gd").build(race.track)
		ai.setup(race.kart, race.track, line, race._karts, 0.85)
		race.kart.autopilot = ai.drive
		set_meta(&"ai", ai)
	elif frame > 3:
		_t += d
		if not _started and race.state == 1 and _t > 7.0:
			_started = true
			_build()
	return false


func _build() -> void:
	var areas := race.find_children("*", "Area3D", true, false)
	var st := {}
	configs.append(["interp_off", func(): physics_interpolation = false, func(): physics_interpolation = true])
	configs.append(["areas_off", func():
		for a in areas:
			st[a] = [a.monitoring, a.monitorable]
			a.set_deferred("monitoring", false)
			a.set_deferred("monitorable", false),
		func():
			for a in areas:
				if st.has(a) and is_instance_valid(a):
					a.set_deferred("monitoring", st[a][0])
					a.set_deferred("monitorable", st[a][1])])
	var karts: Array = race._karts
	var ai_karts := karts.filter(func(k): return k != race.kart)
	configs.append(["ia_karts_parados", func():
		for k in ai_karts:
			k.set_physics_process(false),
		func():
			for k in ai_karts:
				k.set_physics_process(true)])
	var rigs := race.find_children("*", "", true, false).filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("character_rig.gd"))
	configs.append(["todos_karts_parados", func():
		for k in karts:
			k.set_physics_process(false),
		func():
			for k in karts:
				k.set_physics_process(true)])
	var scripted: Array = []
	for n in race.find_children("*", "", true, false) + [race]:
		if n.get_script() and n.is_physics_processing():
			scripted.append(n)
	configs.append(["scripts_fisica_parados", func():
		for n in scripted:
			if is_instance_valid(n): n.set_physics_process(false),
		func():
			for n in scripted:
				if is_instance_valid(n): n.set_physics_process(true)])
	var by_script := {}
	for n in scripted:
		var k: String = n.get_script().resource_path.get_file()
		by_script[k] = by_script.get(k, 0) + 1
	print("INFO|scripts com _physics_process: %s" % by_script)
	configs.append(["base_aa", func(): pass, func(): pass])
	var only: PackedStringArray = args.only.split(",", false)
	if not only.is_empty():
		configs = configs.filter(func(c): return only.has(c[0]))
	for r in int(args.rounds):
		for c in configs:
			seq.append(null)
			seq.append(c)
	seq.append(null)
	print("INFO|areas=%d karts=%d rigs=%d seq=%d" % [areas.size(), karts.size(), rigs.size(), seq.size()])
	physics_frame.connect(_on_pf)
	process_frame.connect(_on_proc)
	_begin()


func _begin() -> void:
	tick_in_block = 0
	cur = []
	var c = seq[seq_i]
	if c != null:
		c[1].call()


var _pf_t := 0
var _pf_n := 0


## Início de cada passo (antes dos _physics_process).
func _on_pf() -> void:
	if _pf_n == 0:
		_pf_t = Time.get_ticks_usec()
	_pf_n += 1


## Começo do _process do quadro: os passos desse quadro (scripts + Jolt + interpolação)
## já terminaram.
func _on_proc() -> void:
	if _pf_n == 0:
		return
	var m := (Time.get_ticks_usec() - _pf_t) / 1000.0 / _pf_n
	var n := _pf_n
	_pf_n = 0
	for i in n:
		_tick(m)


func _tick(m: float) -> void:
	if seq_i >= seq.size():
		return
	tick_in_block += 1
	if tick_in_block > int(args.skip):
		cur.append(m)
	if tick_in_block >= int(args.block):
		var c = seq[seq_i]
		var nm: String = "base" if c == null else c[0]
		cur.sort()
		var med: float = cur[cur.size() / 2]
		if not res.has(nm):
			res[nm] = []
		res[nm].append(med)
		if c != null:
			c[2].call()
		seq_i += 1
		if seq_i >= seq.size():
			_report()
			quit()
			return
		_begin()


func _report() -> void:
	var b: Array = res.base.duplicate()
	b.sort()
	var base: float = b[b.size() / 2]
	print("PHYSAB|track=%s base passo inteiro (mediana) = %.3f ms" % [args.track, base])
	for nm in res:
		if nm == "base":
			continue
		var a: Array = res[nm].duplicate()
		a.sort()
		print("PHYSAB|%-18s %.3f ms  delta=%+.3f  blocos=%s" % [nm, a[a.size() / 2], a[a.size() / 2] - base, res[nm].map(func(x): return snappedf(x, 0.01))])
	print("PHYSAB|base blocos=%s" % [res.base.map(func(x): return snappedf(x, 0.01))])
