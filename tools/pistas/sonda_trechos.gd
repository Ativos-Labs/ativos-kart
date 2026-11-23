extends SceneTree
## Sonda headless dos trechos especiais: corrida com o J1 no piloto automático e os 7
## adversários. Mede voos sobre o vale (quem atravessou, quem caiu, onde pousou, folga
## de altura na beira do pouso), tempo debaixo d'água, respingos, superfícies pisadas,
## tempo no ar nas dunas, resgates e voltas.
## Args: track=0..3 cls=0..2 secs=150 pull=0 (pull=1: J1 freia no voo inteiro)
var frame := 0
var race: Node
var args := {"track": "0", "cls": "1", "secs": "150", "pull": "0", "skill": "0.8"}
var ref_ai
var st := {}
var flights: Array = []
var respawns := {}
var falls := 0
var t0 := 0
var surf := {}
var under_t := 0.0
var splashes := 0
var dune_air := 0.0
var dune_air_max := 0.0
var lap_t: Array = []
var last_lap := 0
var min_margin := 999.0


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
		ai.setup(race.kart, race.track, line, race._karts, float(args.skill))
		ai.pace = 1.0
		ai.rubber_band = 0.0
		ref_ai = ai
		var pull := int(args.pull)
		race.kart.autopilot = func(k):
			var o: Dictionary = ai.drive(k)
			if k.gliding and pull == 1:
				o.brake = 1.0
			return o
		for k in race._karts:
			st[k] = {"air": false, "pos": k.global_position}
			respawns[k.name] = 0
			k.obstacle_hit.connect(func(_l, _s):
				var tr = race.track
				var i: int = tr.get_closest_index(tr.to_local(k.global_position))
				if k.gliding or k._glide_pending or tr.is_gap(i):
					print("  GOLPE no voo: %s em %.3f gliding=%s" % [k.name, tr.distances[i] / tr.length, k.gliding]))
			k.glider_closed.connect(func():
				var tr = race.track
				var i: int = tr.get_closest_index(tr.to_local(k.global_position))
				if tr.is_gap(i):
					print("  ASA FECHOU no vao: %s em %.3f h %.1f" % [k.name, tr.distances[i] / tr.length, tr.to_local(k.global_position).y - tr.samples[i].y]))
		race.kart.splashed.connect(func(_e): splashes += 1)
		t0 = Time.get_ticks_msec()
	elif frame > 4:
		var dt := 1.0 / 150.0 * 2.5
		for k in race._karts:
			_track_kart(k)
		var k1 = race.kart
		if race.state == 1:
			var key: int = k1.surface
			surf[key] = surf.get(key, 0.0) + _dt()
			if k1.underwater:
				under_t += _dt()
			var tr = race.track
			var r = race.player
			var kind: int = tr.section_kind_at(r.index)
			if kind == 1 and not k1.is_on_floor() and not k1.ramp_jump:
				dune_air += _dt()
		var p = race.player
		if p and p.laps_done > last_lap:
			lap_t.append(race.race_time)
			last_lap = p.laps_done
		if race.race_time > float(args.secs):
			_report()
			return true
	return false


func _dt() -> float:
	return 1.0 / 60.0


func _track_kart(k) -> void:
	var s: Dictionary = st[k]
	var tr = race.track
	# Teleporte = resgate.
	if k.global_position.distance_to(s.pos) > 12.0:
		respawns[k.name] += 1
		var local: Vector3 = tr.to_local(s.pos)
		var i: int = tr.get_closest_index(local)
		if tr.is_gap(i) or tr.is_gap((i + 1) % tr.samples.size()):
			falls += 1
			print("  QUEDA no vale: %s em %.3f (h %.1f acima da linha) t=%.1f" % [k.name, tr.distances[i] / tr.length, local.y - tr.samples[i].y, race.race_time])
	s.pos = k.global_position
	var g: bool = k.gliding
	if g != s.get("g", false):
		s.g = g
		var ii: int = tr.get_closest_index(tr.to_local(k.global_position))
		if k == race.kart:
			print("  J1 asa %s em %.3f t=%.1f h %.1f v %.1f landing=%s" % ["abriu" if g else "fechou", tr.distances[ii] / tr.length, race.race_time,
					tr.to_local(k.global_position).y - tr.samples[ii].y, k.speed, k._glide_landing])
	var flying: bool = k.ramp_jump and (k._glide_pending or k.gliding)
	var local: Vector3 = tr.to_local(k.global_position)
	var idx: int = tr.get_closest_index(local)
	if flying and not s.air:
		s.merge({"air": true, "t": race.race_time, "from": tr.get_along(local, idx), "v0": k.speed, "margin": 999.0, "crossed": false}, true)
	if s.air:
		# Folga de altura sobre a beira do pouso (a primeira amostra com chão).
		for span in tr.gap_spans:
			var e: int = (span.to + 1) % tr.samples.size()
			var d: float = (local - tr.samples[e]).dot(tr.tangents[e])
			var flat := Vector2(local.x - tr.samples[e].x, local.z - tr.samples[e].z).length()
			if absf(d) < 2.5 and flat < 16.0:
				s.margin = minf(s.margin, local.y - tr.samples[e].y)
		if k.is_on_floor() and race.race_time - s.t > 0.3:
			s.air = false
			var along: float = tr.get_along(local, idx)
			var dist: float = fposmod(along - s.from, tr.length)
			flights.append({"kart": k.name, "player": k == race.kart, "air": race.race_time - s.t, "dist": dist,
				"land": fposmod(along, tr.length) / tr.length, "v0": s.v0, "margin": s.margin, "after": tr.past_gap(idx)})
			if s.margin < 900.0:
				min_margin = minf(min_margin, s.margin)


func _report() -> void:
	var tr = race.track
	print("PISTA %s classe %s: %.0f s simulados em %.0f s, comprimento %.0f m" % [tr.track_id, args.cls, race.race_time,
			(Time.get_ticks_msec() - t0) / 1000.0, tr.length])
	var mn_air := 99.0
	var mx_air := 0.0
	var mn_d := 9999.0
	var mx_d := 0.0
	for f in flights:
		mn_air = minf(mn_air, f.air)
		mx_air = maxf(mx_air, f.air)
		mn_d = minf(mn_d, f.dist)
		mx_d = maxf(mx_d, f.dist)
		if f.after < 0.0 or f.air < 2.5:
			print("  ESTRANHO %s voo %.2fs %.0fm pousa %.3f depois=%.0f v0 %.1f" % [f.kart, f.air, f.dist, f.land, f.after, f.v0])
		if f.player:
			print("  *J1 voo %.2fs %.0fm pousa %.3f (%.0fm depois da beira) v0 %.1f folga na beira %.1fm" % [f.air, f.dist, f.land, f.after, f.v0, f.margin])
	var mn_a := 9999.0
	var mx_a := -9999.0
	for f in flights:
		if f.after >= 0.0:
			mn_a = minf(mn_a, f.after)
			mx_a = maxf(mx_a, f.after)
	print("VOOS %d ar %.2f-%.2fs dist %.0f-%.0fm pouso %.0f-%.0fm depois da beira, folga minima na beira do pouso %.1fm QUEDAS NO VALE %d" % [
			flights.size(), mn_air, mx_air, mn_d, mx_d, mn_a, mx_a, min_margin, falls])
	var names := ["asfalto", "areia", "areia_fofa", "movedica", "gelo"]
	var s := []
	for key in surf:
		s.append("%s %.1fs" % [names[key], surf[key]])
	print("J1 superficies: ", ", ".join(s), " | debaixo d'agua %.1fs, respingos %d, no ar nas dunas %.2fs" % [under_t, splashes, dune_air])
	var laps := []
	var prev := 0.0
	for t in lap_t:
		laps.append("%.1f" % (t - prev))
		prev = t
	print("J1 voltas: ", ", ".join(laps))
	var rs := []
	for n in respawns:
		if respawns[n] > 0:
			rs.append("%s %d" % [n, respawns[n]])
	print("resgates: ", ", ".join(rs) if not rs.is_empty() else "nenhum")
	for r in race.racers:
		print("  %s progresso %.0f m (%.2f voltas)" % [r.kart.name, r.progress, r.progress / tr.length])
