extends Node
## Probe TEMPORÁRIO (só entra numa build web de teste, veja README.md): fotografa as
## pistas para a tela de seleção e mede essa tela. Nunca fica no projeto.
##
## Cenários pela URL:
##   ?s=shots   vista aérea de cada pista (fundo) + foto da largada (cartão)
##   ?s=explore vista aérea de cada pista nos 4 lados, para escolher o melhor (VIEWS)
##   ?s=select  mede a tela de pistas: entrada, parada e trocando de pista
##
## A foto é tirada na build web (renderizador Compatibility); o water.gdshader já
## converte a profundidade do Compatibility, então a água sai como no desktop.

const TRACK_SELECT := "res://scenes/track_select.tscn"
## Lado de onde a câmera aérea olha cada pista (graus em volta do eixo Y; 0 = olhando
## para -Z) e a inclinação (graus abaixo do horizonte). Escolhidos com ?s=explore.
const VIEWS := {
	"circuito_ativos": {"yaw": 90.0, "pitch": 55.0},
	"ilha_ativos": {"yaw": 0.0, "pitch": 55.0},
	"canion_ativos": {"yaw": 90.0, "pitch": 55.0},
	"pico_nevado": {"yaw": 90.0, "pitch": 55.0},
}
const FOV := 40.0
## Quanto da tela a pista ocupa (o resto é margem).
const FILL := 0.9
## Neblina na foto aérea (fração da neblina da corrida).
const FOG_SCALE := 0.12

var _query := ""
var _last_us := 0
var _rec := false
var _ft := PackedFloat32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	if OS.has_feature("web"):
		_query = str(JavaScriptBridge.eval("location.search"))
	_run.call_deferred()


func _out(s: String) -> void:
	print("PERF|", s)


func _gs() -> Node:
	return get_node("/root/GameState")


func _arg(key: String, def: String) -> String:
	for part in _query.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == key:
			return kv[1]
	return def


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if _rec and _last_us > 0:
		_ft.append((now - _last_us) / 1000.0)
	_last_us = now


func _run() -> void:
	await _wait(2.0)
	match _arg("s", "shots"):
		"shots":
			await _shots(false)
		"explore":
			await _shots(true)
		"select":
			await _select_test()
	_out("DONE")


# --- Fotos ---------------------------------------------------------------------------

func _shots(explore: bool) -> void:
	var gs := _gs()
	if gs.render_scale:
		gs.render_scale.reset()
		gs.render_scale.hold(true)
	get_tree().current_scene.queue_free()
	await _wait(0.5)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.mesh_lod_threshold = 0.0
	var root := get_tree().root
	for data: TrackData in gs.tracks:
		var track: Track = data.scene.instantiate()
		root.add_child(track)
		await get_tree().process_frame
		_full_detail(track)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.current = true
		var view: Dictionary = VIEWS.get(data.id, {"yaw": 0.0, "pitch": 55.0})
		var yaws: Array = [0.0, 90.0, 180.0, 270.0] if explore else [view.yaw]
		for yaw: float in yaws:
			_aerial(cam, track, yaw, view.pitch)
			await _settle()
			var shot := "%s_fundo" % data.id
			if explore:
				shot += "_y%d" % int(yaw)
			await _shot(shot)
		if not explore:
			_start_line(cam, track)
			await _settle()
			await _shot("%s_cartao" % data.id)
		cam.queue_free()
		track.queue_free()
		await _wait(0.5)


## Pede o print ao run_chrome.mjs e espera ele ficar pronto (o Chrome só tira o
## print no próximo quadro que a placa de vídeo entregar, às vezes segundos depois).
func _shot(shot: String) -> void:
	_out("SHOT|" + shot)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
		if str(JavaScriptBridge.eval("window.__shot_saved || ''")) == shot:
			return
	_out("INFO|print sem resposta: " + shot)


## Espera a imagem assentar: a câmera chegar e os shaders compilarem (na web cada
## shader novo trava o jogo um instante, e o print sairia atrasado).
func _settle() -> void:
	await _wait(0.6)
	var good := 0
	var last := Time.get_ticks_usec()
	while good < 45:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		good = good + 1 if now - last < 80000 else 0
		last = now




## Vista de longe: sem cortes por distância, sombra até onde a câmera vê, sem neve
## (os flocos acompanham a câmera e viram pontos soltos na foto) e com pouca neblina
## (a 400 m de altura a neblina da corrida deixa tudo branco).
func _full_detail(node: Node) -> void:
	for child in node.get_children(true):
		_full_detail(child)
	if node is WorldEnvironment and node.environment:
		var env: Environment = node.environment.duplicate()
		env.fog_density *= FOG_SCALE
		env.fog_aerial_perspective *= FOG_SCALE
		node.environment = env
	elif node is GPUParticles3D or node is CPUParticles3D:
		node.visible = false
	elif node is GeometryInstance3D:
		node.visibility_range_begin = 0.0
		node.visibility_range_end = 0.0
	elif node is DirectionalLight3D:
		node.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		node.directional_shadow_max_distance = 700.0
		node.directional_shadow_split_1 = 0.15
		node.directional_shadow_split_2 = 0.35
		node.directional_shadow_split_3 = 0.6


## Câmera inclinada que enquadra a pista inteira (amostras do traçado + muretas).
func _aerial(cam: Camera3D, track: Track, yaw_deg: float, pitch_deg: float) -> void:
	cam.fov = FOV
	# A espuma da água vem da profundidade da tela: de longe, com o near padrão
	# (0,05 m), o buffer perde a precisão e a água inteira vira espuma branca.
	cam.near = 40.0
	cam.far = 2000.0
	var pts := PackedVector3Array()
	var center := Vector3.ZERO
	for i in track.samples.size():
		var s := track.samples[i]
		var r := track.rights[i] * 9.0
		pts.append(s + r)
		pts.append(s - r)
		center += s
	center /= maxf(track.samples.size(), 1)
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	var target := Vector3((mn.x + mx.x) * 0.5, center.y, (mn.z + mx.z) * 0.5)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0.0))
	var size := get_viewport().get_visible_rect().size
	var tan_v := tan(deg_to_rad(FOV) * 0.5) * FILL
	var tan_h := tan_v * size.x / size.y
	var inv := basis.inverse()
	var d := 0.0
	for p in pts:
		var q := inv * (p - target)
		d = maxf(d, maxf(absf(q.x) / tan_h, absf(q.y) / tan_v) + q.z)
	cam.global_transform = Transform3D(basis, target + basis.z * d)
	cam.reset_physics_interpolation()


## A mesma foto que a tela tirava em tempo real: da largada, olhando a reta.
func _start_line(cam: Camera3D, track: Track) -> void:
	cam.fov = 52.0
	cam.near = 0.05
	cam.far = 1000.0
	cam.global_position = track.get_transform_at(-38.0, -4.5).origin + Vector3.UP * 3.4
	cam.look_at(track.get_point_at(6.0) + Vector3.UP * 3.6, Vector3.UP)
	cam.reset_physics_interpolation()


# --- Medição da tela de pistas -------------------------------------------------------

func _select_test() -> void:
	var gs := _gs()
	var old := get_tree().current_scene
	var t0 := Time.get_ticks_usec()
	_ft = PackedFloat32Array()
	_rec = true
	gs.goto_scene(TRACK_SELECT)
	while get_tree().current_scene == old or gs._changing_scene:
		await get_tree().process_frame
	_rec = false
	_report("entrada", (Time.get_ticks_usec() - t0) / 1000.0)
	await _wait(2.0)
	await _measure("parada", 5.0)
	for i in 4:
		var ev := InputEventAction.new()
		ev.action = &"ui_right"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		ev = ev.duplicate()
		ev.pressed = false
		Input.parse_input_event(ev)
		await _measure("troca%d" % i, 1.5)
	await _measure("parada2", 5.0)
	await _shot("tela_pistas")


func _measure(label: String, secs: float) -> void:
	_ft = PackedFloat32Array()
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_usec()
	var dc := 0.0
	var prim := 0.0
	var n := 0
	_rec = true
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		await get_tree().process_frame
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	_rec = false
	var el := (Time.get_ticks_usec() - t0) / 1e6
	_report(label, el * 1000.0, (Engine.get_frames_drawn() - f0) / el, dc / maxi(n, 1), prim / maxi(n, 1))


func _report(label: String, total_ms: float, fps := 0.0, dc := 0.0, prim := 0.0) -> void:
	var s := _ft.duplicate()
	s.sort()
	var pick := func(q: float) -> float: return s[clampi(int(q * (s.size() - 1)), 0, s.size() - 1)] if s.size() > 0 else 0.0
	var stalls := 0
	for f in s:
		if f > 50.0:
			stalls += 1
	_out("M|%s|ms=%.0f|fps=%.1f|p50=%.2f|p95=%.2f|max=%.1f|stalls50=%d|dc=%d|prim=%d" % [
		label, total_ms, fps, pick.call(0.5), pick.call(0.95), pick.call(1.0), stalls, dc, prim])

