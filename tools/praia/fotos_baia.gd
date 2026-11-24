extends Node
## Probe TEMPORÁRIO (build web de teste, veja tools/praia/README.md): fotografa a Baía
## Ativos com a corrida montada — largada, vila, passarela, decolagem, voo, trilha da
## mata, arco de pedra, baixio, grampo e uma vista aérea. ?t=<índice da pista>.
## Com ?only=nome1,nome2 tira só essas fotos.

var _query := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_query = str(JavaScriptBridge.eval("location.search"))
	_run.call_deferred()


func _out(s: String) -> void:
	print("PERF|", s)


func _arg(key: String, def: String) -> String:
	for part in _query.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == key:
			return kv[1]
	return def


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _shot(shot: String) -> void:
	_out("SHOT|" + shot)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
		if str(JavaScriptBridge.eval("window.__shot_saved || ''")) == shot:
			return
	_out("INFO|print sem resposta: " + shot)


func _settle() -> void:
	await _wait(0.8)
	var good := 0
	var last := Time.get_ticks_usec()
	while good < 40:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		good = good + 1 if now - last < 80000 else 0
		last = now


func _run() -> void:
	await _wait(2.0)
	var gs := get_node("/root/GameState")
	if gs.render_scale:
		gs.render_scale.reset()
		gs.render_scale.hold(true)
	gs.selected_track_index = int(_arg("t", "4"))
	gs.mode = 1
	gs.laps = 99
	var devs: Array[int] = []
	gs.set_players(devs)
	var old := get_tree().current_scene
	gs.goto_scene(gs.SCENE_RACE)
	while get_tree().current_scene == old or gs._changing_scene:
		await get_tree().process_frame
	await _wait(1.5)
	var race := get_tree().current_scene
	var track: Track = race.track
	var cam: Camera3D = race.camera
	cam.set_physics_process(false)
	cam.set_process(false)
	race.hud.visible = false
	_out("INFO|%s comprimento %.0f" % [track.track_id, track.length])
	var only := _arg("only", "")
	var L := track.length
	var views := [
		["largada", _kart_eye(track, -46.0, 3.4, -0.06), -26.0],
		["vila", _kart_eye(track, 0.03 * L, 2.4, -0.05), 0.03 * L + 16.0],
		["praia_leste", _kart_eye(track, 0.125 * L, 2.6, -0.06), 0.125 * L + 16.0],
		["passarela", _kart_eye(track, 0.195 * L, 2.6, -0.06), 0.195 * L + 16.0],
		["passarela_lado", _side_eye(track, 0.215 * L, 60.0, 16.0), -1.0],
		["decolagem", _kart_eye(track, track.distances[track.gap_spans[0].from] - 16.0, 7.5, -0.22), -1.0],
		["voo", _kart_eye(track, track.distances[(track.gap_spans[0].from + track.gap_spans[0].to) / 2] - 25.0, 6.0, -0.3), -1.0],
		["mata_entrada", _kart_eye(track, 0.38 * L, 2.6, -0.04), 0.38 * L + 16.0],
		["mata", _kart_eye(track, 0.505 * L, 2.6, -0.04), 0.505 * L + 16.0],
		["mata_cima", _side_eye(track, 0.53 * L, 45.0, 28.0), -1.0],
		["baixio", _kart_eye(track, 0.615 * L, 2.6, -0.06), 0.615 * L + 16.0],
		["baixio_pulo", _kart_eye(track, 0.66 * L, 3.0, -0.08), -1.0],
		["baixio_cima", _side_eye(track, 0.65 * L, 70.0, 30.0), -1.0],
		["grampo", _kart_eye(track, 0.79 * L, 3.0, -0.08), 0.79 * L + 16.0],
		["dunas", _kart_eye(track, 0.9 * L, 2.6, -0.05), 0.9 * L + 16.0],
	]
	# Arco de pedra (o mesmo lugar que TrackBeach._arch_index): de frente, chegando nele.
	var ai := TrackBeach.arch_index(track)
	if ai >= 0:
		views.append(["arco", _kart_eye(track, track.distances[ai] - 45.0, 2.8, 0.02), track.distances[ai] - 25.0])
	# Vista aérea.
	var box := AABB(track.samples[0], Vector3.ZERO)
	for p in track.samples:
		box = box.expand(p)
	var center := track.global_transform * box.get_center()
	var eye := center + Vector3(0.0, 620.0, 380.0)
	views.append(["aerea", Transform3D(Basis.looking_at((center - eye).normalized(), Vector3.UP), eye), -1.0])
	for v in views:
		if only != "" and not only.split(",").has(v[0]):
			continue
		if v[2] >= 0.0:
			_put_karts(race, track, v[2], 8.0)
		cam.global_transform = v[1]
		cam.reset_physics_interpolation()
		await _settle()
		await _shot("baia_" + v[0])
	_out("DONE")


## Câmera na pista a `along` m, `h` m acima, inclinada `pitch` rad, olhando para a frente.
func _kart_eye(track: Track, along: float, h: float, pitch: float) -> Transform3D:
	var xf := track.global_transform * track.get_transform_at(fposmod(along, track.length))
	return Transform3D(xf.basis * Basis(Vector3.RIGHT, pitch), xf.origin + Vector3.UP * h)


## Câmera de lado e no alto, olhando para o ponto da pista a `along` m.
func _side_eye(track: Track, along: float, dist: float, h: float) -> Transform3D:
	var i := track.get_closest_index(track.get_point_at(along))
	var p := track.global_transform * track.samples[i]
	var side := track.global_basis * (track.rights[i] * track.outer_side_at(i))
	var eye := p + side * dist + Vector3.UP * h
	return Transform3D(Basis.looking_at((p - eye).normalized(), Vector3.UP), eye)


## Põe o jogador e dois adversários na pista a `along` m (para aparecerem no print).
func _put_karts(race: Node, track: Track, along: float, gap: float) -> void:
	var karts: Array = race._karts
	for k in mini(3, karts.size()):
		var kart: Kart = karts[k]
		var lat: float = [0.0, -3.5, 3.5][k]
		var xf := track.global_transform * track.get_transform_at(fposmod(along + k * gap, track.length), lat)
		kart.teleport(Transform3D(xf.basis, xf.origin + Vector3.UP * 0.3))
