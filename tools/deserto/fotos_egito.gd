extends Node
## Probe TEMPORÁRIO (build web de teste, veja tools/pistas/README.md): fotografa o Cânion
## do Egito com a corrida montada — largada, dunas, descida para o oásis, debaixo d'água,
## templo, esfinge, pirâmides, viaduto, vale e a vista de cima. ?v=nome1,nome2 escolhe as vistas.

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


var race: Node
var track: Track
var cam: Camera3D


func _run() -> void:
	await _wait(2.0)
	var gs := get_node("/root/GameState")
	if gs.render_scale:
		gs.render_scale.reset()
		gs.render_scale.hold(true)
	gs.selected_track_index = int(_arg("t", "2"))
	gs.mode = 1
	gs.laps = 99
	var devs: Array[int] = []
	gs.set_players(devs)
	var old := get_tree().current_scene
	var t0 := Time.get_ticks_msec()
	gs.goto_scene(gs.SCENE_RACE)
	while get_tree().current_scene == old or gs._changing_scene:
		await get_tree().process_frame
	_out("INFO|corrida pronta em %d ms" % (Time.get_ticks_msec() - t0))
	await _wait(1.0)
	race = get_tree().current_scene
	track = race.track
	cam = race.camera
	cam.set_physics_process(false)
	cam.set_process(false)
	race.hud.visible = false
	var only := _arg("v", "")
	var views := _views()
	for v: Array in views:
		if only != "" and not (v[0] in only.split(",")):
			continue
		await v[1].call()
		await _view(v[0])
	_out("DONE")


## Câmera na pista: `frac` da volta, `lateral` (m), `height` (m acima da pista),
## virada `yaw` (rad, + = esquerda) e inclinada `pitch` (rad, + = para cima).
func _on_track(frac: float, lateral: float, height: float, yaw := 0.0, pitch := -0.08) -> void:
	var xf := track.global_transform * track.get_transform_at(frac * track.length, lateral)
	var b := Basis(Vector3.UP, yaw) * Basis.looking_at(-xf.basis.z * Vector3(1, 0, 1), Vector3.UP)
	cam.global_transform = Transform3D(b * Basis(Vector3.RIGHT, pitch), xf.origin + Vector3.UP * height)


func _look(eye: Vector3, target: Vector3) -> void:
	cam.global_transform = Transform3D(Basis.looking_at((target - eye).normalized(), Vector3.UP), eye)


func _node_pos(name: String) -> Vector3:
	var n := track.find_child(name, true, false) as Node3D
	return n.global_position if n else Vector3.INF


func _karts(frac: float, gap: float) -> void:
	var karts: Array = race._karts
	for k in mini(3, karts.size()):
		var kart: Kart = karts[k]
		var lat: float = [0.0, -3.5, 3.5][k]
		var xf := track.global_transform * track.get_transform_at(frac * track.length + k * gap, lat)
		kart.teleport(Transform3D(xf.basis, xf.origin + Vector3.UP * 0.3))


func _views() -> Array:
	return [
		["largada", func() -> void:
			_karts(-0.004, -7.0)
			_on_track(-0.018, 0.0, 3.2, 0.0, -0.05)],
		["portal_frente", func() -> void:
			_on_track(0.012, 5.0, 4.0, PI + 0.25, 0.08)],
		["dunas", func() -> void:
			_karts(0.6, 8.0)
			_on_track(0.592, -1.0, 2.6, 0.0, -0.06)],
		["dunas_piramides", func() -> void:
			_karts(0.652, 8.0)
			_on_track(0.645, 0.0, 3.0, 0.0, 0.0)],
		["descida_oasis", func() -> void:
			_karts(0.712, 8.0)
			_on_track(0.704, 2.5, 3.0, 0.0, -0.06)],
		["oasis_lado", func() -> void:
			var mid := track.global_transform * track.get_point_at(0.775 * track.length)
			var i := track.get_closest_index(track.to_local(mid), -1, 2000)
			var side := track.global_basis * track.rights[i]
			_look(mid - side * 85.0 + Vector3.UP * 30.0, mid + Vector3.UP * -4.0)],
		["oasis_margem", func() -> void:
			var q := _node_pos("Cais")
			var mid := track.global_transform * track.get_point_at(0.775 * track.length)
			_look(q + (q - mid).normalized() * 30.0 + Vector3.UP * 6.0, mid + Vector3.UP * -8.0)],
		["submerso", func() -> void:
			_karts(0.768, 8.0)
			_on_track(0.758, 0.0, 2.2, 0.0, 0.02)],
		["submerso_ruinas", func() -> void:
			_on_track(0.78, 0.0, 2.6, 0.9, 0.05)],
		["templo", func() -> void:
			_karts(0.888, 8.0)
			_on_track(0.872, 0.0, 3.0, 0.0, 0.02)],
		["templo_cima", func() -> void:
			var g := _node_pos("PortalDoTemplo")
			var i := track.get_closest_index(track.to_local(g), -1, 2000)
			var side := track.global_basis * track.rights[i]
			_look(g + side * 70.0 + Vector3.UP * 40.0 - track.global_basis * track.tangents[i] * 40.0, g)],
		["esfinge", func() -> void:
			var s := _node_pos("Esfinge")
			var i := track.get_closest_index(track.to_local(s), -1, 2000)
			var p := track.global_transform * track.samples[i]
			_look(p + Vector3.UP * 3.0, s + Vector3.UP * 6.0)],
		["tambores", func() -> void:
			_on_track(0.947, 0.0, 2.4, 0.0, -0.04)],
		["piramide_meio", func() -> void:
			_on_track(0.96, 0.0, 3.0, -1.2, 0.08)],
		["viaduto", func() -> void:
			_on_track(0.15, 0.0, 3.0, 0.0, -0.05)],
		["vale", func() -> void:
			_on_track(0.318, 0.0, 6.0, 0.0, -0.2)],
		["de_cima", func() -> void:
			var box := track._bounds()
			var c := track.global_transform * box.get_center()
			_look(c + Vector3(0, 620, 330), c)],
	]


func _view(shot: String) -> void:
	cam.reset_physics_interpolation()
	var under: bool = race._underwater_env != null and cam.global_position.y < race._water_y
	cam.environment = race._underwater_env if under else null
	await _settle()
	await _shot(shot)
