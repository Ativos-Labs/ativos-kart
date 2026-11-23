extends Node
## Probe TEMPORÁRIO (build web de teste): fotografa os trechos especiais de cada pista
## (vale da asa-delta, mergulho, dunas, gelo) com a corrida montada (karts no lugar).
## ?t=0,1,2,3 escolhe as pistas.

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
	for t in _arg("t", "0,1,2,3").split(","):
		await _track(int(t))
	_out("DONE")


func _track(ti: int) -> void:
	var gs := get_node("/root/GameState")
	gs.selected_track_index = ti
	gs.mode = 1
	gs.laps = 99
	var devs: Array[int] = []
	gs.set_players(devs)
	var old := get_tree().current_scene
	gs.goto_scene(gs.SCENE_RACE)
	while get_tree().current_scene == old or gs._changing_scene:
		await get_tree().process_frame
	await _wait(1.0)
	var race := get_tree().current_scene
	var track: Track = race.track
	var cam: Camera3D = race.camera
	cam.set_physics_process(false)
	cam.set_process(false)
	race.hud.visible = false
	var id := track.track_id
	_out("INFO|%s comprimento %.0f" % [id, track.length])
	var vales := track._valley_paths()
	for gi in track.gap_spans.size():
		var span: Dictionary = track.gap_spans[gi]
		var from: int = span.from
		var to: int = span.to
		# 1. Da borda da rampa, como quem vai decolar.
		var lip := track.distances[from] - 2.0
		var xf := track.global_transform * track.get_transform_at(lip - 14.0)
		cam.global_transform = Transform3D(xf.basis * Basis(Vector3.RIGHT, -0.22), xf.origin + Vector3.UP * 7.5)
		_put_karts(race, track, lip + 30.0, 9.0)
		await _view(cam, "%s_vale_voo" % id)
		# 2. Do vale, olhando a cabeceira (cachoeira) com a pista cruzando.
		if gi < vales.size():
			var path := vales[gi]
			var head: Vector3 = track.global_transform * (path.transform * path.curve.sample_baked(0.0))
			var mid := track.global_transform * track.samples[(from + to) / 2]
			var away := Vector3(mid.x - head.x, 0.0, mid.z - head.z).normalized()
			var eye := mid + away * 95.0 + Vector3.UP * 6.0
			cam.global_transform = Transform3D(Basis.looking_at((head + Vector3.UP * 2.0 - eye).normalized(), Vector3.UP), eye)
			await _view(cam, "%s_vale_cachoeira" % id)
			# 3. De lado, alto: o vão inteiro.
			var side := track.global_basis * track.rights[(from + to) / 2]
			eye = mid + side * 120.0 + Vector3.UP * 45.0
			cam.global_transform = Transform3D(Basis.looking_at((mid - eye).normalized(), Vector3.UP), eye)
			await _view(cam, "%s_vale_lado" % id)
			# 4. No meio do voo, olhando para a frente e um pouco para baixo.
			var fly := track.global_transform * track.get_transform_at(track.distances[(from + to) / 2] - 25.0)
			cam.global_transform = Transform3D(fly.basis * Basis(Vector3.RIGHT, -0.35), fly.origin + Vector3.UP * 6.0)
			await _view(cam, "%s_vale_meio_voo" % id)
			# 5. A cachoeira de perto.
			for n in track.find_children("Cachoeira", "MeshInstance3D", true, false):
				var box: AABB = (n as MeshInstance3D).get_aabb()
				var c: Vector3 = (n as MeshInstance3D).global_transform * box.get_center()
				var toward := Vector3(mid.x - c.x, 0.0, mid.z - c.z).normalized()
				var at := c + toward * maxf(box.size.y * 1.6, 30.0) + Vector3.UP * 4.0
				cam.global_transform = Transform3D(Basis.looking_at((c - at).normalized(), Vector3.UP), at)
				await _view(cam, "%s_cachoeira_perto" % id)
				break
	for s in track.sections:
		if s == null or s.kind == TrackSection.Kind.VALE:
			continue
		var a := s.start * track.length
		var e := s.end * track.length
		var at := a + (e - a) * 0.35
		var name: String = ["mergulho", "dunas", "gelo"][s.kind]
		var xf := track.global_transform * track.get_transform_at(at - 12.0)
		cam.global_transform = Transform3D(xf.basis * Basis(Vector3.RIGHT, -0.1), xf.origin + Vector3.UP * 2.6)
		_put_karts(race, track, at, 7.0)
		await _view(cam, "%s_%s" % [id, name])
		# De cima, mais longe.
		var mid := track.global_transform * track.get_point_at((a + e) * 0.5)
		var side := track.global_basis * track.rights[track.get_closest_index(track.to_local(mid))]
		var eye := mid + side * 70.0 + Vector3.UP * 38.0
		cam.global_transform = Transform3D(Basis.looking_at((mid - eye).normalized(), Vector3.UP), eye)
		await _view(cam, "%s_%s_cima" % [id, name])


## Põe o jogador e dois adversários na pista a `along` m (para aparecerem no print).
func _put_karts(race: Node, track: Track, along: float, gap: float) -> void:
	var karts: Array = race._karts
	for k in mini(3, karts.size()):
		var kart: Kart = karts[k]
		var lat: float = [0.0, -3.5, 3.5][k]
		var xf := track.global_transform * track.get_transform_at(along + k * gap, lat)
		kart.teleport(Transform3D(xf.basis, xf.origin + Vector3.UP * 0.3))


func _view(cam: Camera3D, shot: String) -> void:
	cam.reset_physics_interpolation()
	var race := get_tree().current_scene
	var under: bool = race._underwater_env != null and cam.global_position.y < race._water_y
	cam.environment = race._underwater_env if under else null
	await _settle()
	await _shot(shot)
