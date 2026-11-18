extends SceneTree
## Sonda headless dos voos de asa-delta (veja tools/asas/README.md). Corre a pista com o
## J1 no piloto automático e os 7 adversários e mede cada voo: tempo no ar, quando a asa
## abriu, distância, onde aterrissa (fração da volta e lateral), altura máxima acima da
## pista, batidas na parede, moedas pegas no ar e quedas.
## Args (depois de --): track=0..3 cls=0..2 secs=110 pull=0
##   pull=1 o J1 segura o freio o voo inteiro (voo mais longo possível)
##   pull=2/3 o J1 vira tudo para a esquerda/direita no ar (testa as paredes do voo)
var frame := 0
var race: Node
var args := {"track": "0", "cls": "1", "secs": "110", "pull": "0"}
var st := {}   # kart -> estado do voo atual
var glides: Array = []
var respawns := 0
var t0 := 0.0
var ref_ai

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		Engine.time_scale = 2.5
		Engine.physics_ticks_per_second = 150
		var gs = root.get_node("GameState")
		gs.selected_track_index = int(args.track)
		gs.mode = 1
		gs.laps = 99
		gs.speed_class = int(args.cls)
		gs.difficulty = 1
		var devs: Array[int] = []
		gs.set_players(devs)
		race = load("res://scenes/race.tscn").instantiate()
		root.add_child(race)
		current_scene = race
	elif frame == 4:
		var ai = load("res://scripts/kart_ai.gd").new()
		var line = load("res://scripts/racing_line.gd").build(race.track)
		ai.setup(race.kart, race.track, line, race._karts, 0.8)
		ai.pace = 1.0
		ai.rubber_band = 0.0
		ref_ai = ai
		var mode := int(args.pull)
		race.kart.autopilot = func(k):
			var o: Dictionary = ai.drive(k)
			if k.gliding and mode == 1:
				o.brake = 1.0
			elif k.gliding and mode == 2:
				o.steer = 1.0
			elif k.gliding and mode == 3:
				o.steer = -1.0
			return o
		for k in race._karts:
			st[k] = {"air": false}
			k.glider_opened.connect(_on_open.bind(k))
			k.bumped.connect(func(_s): if k.gliding or st[k].air: st[k].walls += 1)
			k.coin_collected.connect(func(): if k.gliding: st[k].coins += 1)
		t0 = Time.get_ticks_msec()
	elif frame > 4:
		for k in race._karts:
			_track_kart(k)
		var sim: float = race.race_time
		if sim > float(args.secs):
			_report()
			return true
	return false

func _info(k) -> Dictionary:
	var tr = race.track
	var local: Vector3 = tr.to_local(k.global_position)
	var i: int = tr.get_closest_index(local)
	return {"along": tr.get_along(local, i), "lat": tr.get_lateral(local, i), "h": local.y - tr.samples[i].y}

func _on_open(k) -> void:
	st[k].opened_at = race.race_time

func _track_kart(k) -> void:
	var s: Dictionary = st[k]
	var flying: bool = k.ramp_jump and (k._glide_pending or k.gliding)
	if flying and not s.air:
		var inf := _info(k)
		s.merge({"air": true, "t": race.race_time, "from": inf.along, "peak": 0.0, "walls": 0, "coins": 0, "opened_at": -1.0, "v0": k.speed}, true)
	if s.air:
		var inf := _info(k)
		s.peak = maxf(s.peak, inf.h)
		if k.is_on_floor() and race.race_time - s.t > 0.3:
			s.air = false
			var d: float = inf.along - s.from
			if d < 0.0:
				d += race.track.length
			glides.append({"kart": k.name, "player": k == race.kart, "air": race.race_time - s.t, "open": s.opened_at - s.t,
				"dist": d, "land": fposmod(inf.along, race.track.length) / race.track.length, "lat": inf.lat, "peak": s.peak,
				"walls": s.walls, "coins": s.coins, "v0": s.v0, "v1": k.speed})
	if k.global_position.y < -15.0:
		respawns += 1

func _report() -> void:
	var tr = race.track
	print("PISTA %s classe %s: %d voos, %.0f s simulados em %.0f s" % [tr.track_id, args.cls, glides.size(), race.race_time, (Time.get_ticks_msec() - t0) / 1000.0])
	var air := []
	for g in glides:
		print("  %-10s ar %.2fs (abriu %.2fs) dist %5.1fm aterrissa %.3f lat %+5.1f pico %4.1fm v %4.1f->%4.1f paredes %d moedas %d" % [
			("*" if g.player else "") + str(g.kart).substr(0, 9), g.air, g.open, g.dist, g.land, g.lat, g.peak, g.v0, g.v1, g.walls, g.coins])
		air.append(g.air)
	print("  quedas abaixo de -15 m: %d" % respawns)
	if glides.is_empty():
		return
	var mn := {"air": 99.0, "dist": 9999.0, "land": 9.0}
	var mx := {"air": 0.0, "dist": 0.0, "land": -9.0, "lat": 0.0, "walls": 0, "peak": 0.0}
	for g in glides:
		for key in mn: mn[key] = minf(mn[key], g[key])
		for key in ["air", "dist", "land", "peak"]: mx[key] = maxf(mx[key], g[key])
		mx.lat = maxf(mx.lat, absf(g.lat))
		mx.walls += g.walls
	print("RESUMO %s cls=%s voos=%d ar %.2f-%.2fs dist %.0f-%.0fm aterrissa %.3f-%.3f |lat|max %.1f pico %.1f paredes %d quedas %d" % [
		race.track.track_id, args.cls, glides.size(), mn.air, mx.air, mn.dist, mx.dist, mn.land, mx.land, mx.lat, mx.peak, mx.walls, respawns])
	for r in race.racers:
		print("  %s progresso %.0f m" % [r.kart.name, r.progress])
