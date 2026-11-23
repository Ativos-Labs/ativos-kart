extends SceneTree
## Analisa o traçado das pistas (sem renderizar): comprimento, raio mínimo, trechos
## que passam perto um do outro e um PNG de cima com pontes, rampas e rios.
## Args: out=<pasta> tracks=0,1,2,3

const SCENES := [
	"res://scenes/tracks/circuito_ativos.tscn",
	"res://scenes/tracks/ilha_ativos.tscn",
	"res://scenes/tracks/canion_ativos.tscn",
	"res://scenes/tracks/pico_nevado.tscn",
]

var args := {"out": "/tmp", "tracks": "0,1,2,3"}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]


var frame := 0


func _process(_d: float) -> bool:
	frame += 1
	if frame < 2:
		return false
	for t in args.tracks.split(","):
		_analyze(int(t))
	return true


func _analyze(ti: int) -> void:
	var track: Track = load(SCENES[ti]).instantiate()
	track.prepare_layout()
	var n := track.samples.size()
	var step := track.length / n
	print("== %s  length=%.1f m  samples=%d" % [track.track_id, track.length, n])
	# Raio mínimo.
	var min_r := INF
	var min_i := 0
	for i in n:
		var k := absf(track.curvature[i])
		if k > 0.0001 and 1.0 / k < min_r:
			min_r = 1.0 / k
			min_i = i
	print("  min radius %.1f m at frac %.3f" % [min_r, track.distances[min_i] / track.length])
	var ymin := INF
	var ymax := -INF
	for p in track.samples:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	print("  y range %.1f .. %.1f" % [ymin, ymax])
	# Retas (|curvatura| < 1/150 por pelo menos 40 m).
	var runs := []
	var start := -1
	for i in n + 1:
		var straight := i < n and absf(track.curvature[i]) < 1.0 / 150.0
		if straight and start < 0:
			start = i
		elif not straight and start >= 0:
			if (i - start) * step >= 40.0:
				runs.append("%.3f-%.3f(%dm)" % [track.distances[start] / track.length, track.distances[i - 1] / track.length, int((i - start) * step)])
			start = -1
	print("  straights: ", " ".join(runs))
	for sp in track.gap_spans:
		print("  gap %d..%d  %.1f m  y %.1f -> %.1f" % [sp.from, sp.to, (sp.to - sp.from + 2) * step,
				track.samples[sp.from - 1].y, track.samples[sp.to + 1].y])
	# Aproximações.
	var reported := {}
	for i in range(0, n, 2):
		for j in range(i + 2, n, 2):
			var along := absf(track.distances[j] - track.distances[i])
			along = minf(along, track.length - along)
			if along < 90.0:
				continue
			var a := Vector2(track.samples[i].x, track.samples[i].z)
			var b := Vector2(track.samples[j].x, track.samples[j].z)
			var d := a.distance_to(b)
			if d < 46.0:
				var key := "%d_%d" % [int(track.distances[i] / 40.0), int(track.distances[j] / 40.0)]
				if reported.has(key):
					continue
				reported[key] = true
				var dy := absf(track.samples[i].y - track.samples[j].y)
				print("  close: %.3f <-> %.3f  d=%.1f dy=%.1f %s" % [track.distances[i] / track.length,
						track.distances[j] / track.length, d, dy, "(bridge)" if track.is_bridge(i) or track.is_bridge(j) else ""])
	_draw(track, ti)
	track.free()


func _draw(track: Track, ti: int) -> void:
	var box := AABB(track.samples[0], Vector3.ZERO)
	for p in track.samples:
		box = box.expand(p)
	var margin := 60.0
	var size := 1100
	var span := maxf(box.size.x, box.size.z) + margin * 2.0
	var scale := size / span
	var origin := Vector2(box.position.x - margin, box.position.z - margin)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.14, 0.12))
	var to_px := func(p: Vector3) -> Vector2i:
		return Vector2i(int((p.x - origin.x) * scale), int((p.z - origin.y) * scale))
	# Grade de 50 m.
	for gx in range(int(origin.x / 50.0) * 50, int(origin.x + span), 50):
		var x := int((gx - origin.x) * scale)
		if x >= 0 and x < size:
			for y in size:
				img.set_pixel(x, y, Color(0.2, 0.22, 0.2) if gx % 250 != 0 else Color(0.35, 0.35, 0.35))
	for gz in range(int(origin.y / 50.0) * 50, int(origin.y + span), 50):
		var y := int((gz - origin.y) * scale)
		if y >= 0 and y < size:
			for x in size:
				img.set_pixel(x, y, Color(0.2, 0.22, 0.2) if gz % 250 != 0 else Color(0.35, 0.35, 0.35))
	# Rios.
	for child in track.get_children():
		if child is Path3D and (String(child.name).begins_with("Rio") or String(child.name).begins_with("Vale")):
			var vale := String(child.name).begins_with("Vale")
			var c: Curve3D = child.curve
			var tot := c.get_baked_length()
			for s in int(tot):
				var p: Vector3 = child.transform * c.sample_baked(s)
				_dot(img, to_px.call(p), 6 if vale else 3, Color(0.9, 0.3, 0.6) if vale else Color(0.2, 0.5, 0.9))
	# Pista: largura do asfalto em escala.
	var half_px := maxi(1, int(track.road_width * 0.5 * scale))
	for i in track.samples.size():
		var col := Color(0.55, 0.55, 0.58)
		var sec := track.section_at(i)
		if sec and track.section_blend[i] > 0.5:
			col = [Color(0.1, 0.4, 1.0), Color(1.0, 0.6, 0.2), Color(0.6, 1.0, 1.0), Color(1.0, 0.1, 0.1)][sec.kind]
		elif track.is_bridge(i):
			col = Color(0.3, 0.6, 1.0) if track.bridge_mask[i] == 2 else Color(0.6, 0.4, 1.0)
		var h := clampf(track.samples[i].y / 20.0, -1.0, 1.0)
		if h > 0.05:
			col = col.lerp(Color(1, 1, 1), h * 0.5)
		_dot(img, to_px.call(track.samples[i]), half_px, col)
	# Marcas de fração a cada 0.05.
	for k in 20:
		var p := track.get_point_at(track.length * k / 20.0)
		_dot(img, to_px.call(p), 3, Color(1, 1, 1) if k % 2 == 0 else Color(0.7, 0.7, 0.7))
	# Largada.
	_dot(img, to_px.call(track.get_point_at(0.0)), 7, Color(1, 1, 1))
	# Rampas.
	for r in track.ramps:
		var p := track.get_point_at(r.at * track.length)
		_dot(img, to_px.call(p), 6, Color(1, 0.9, 0.1) if r.glider else Color(1, 0.2, 0.2))
	for f in track.item_rows:
		_dot(img, to_px.call(track.get_point_at(f * track.length)), 4, Color(0.2, 1, 0.3))
	for f in track.obstacle_zones:
		_dot(img, to_px.call(track.get_point_at(f * track.length)), 5, Color(1, 0.5, 0.1))
	for f in track.boost_pads:
		_dot(img, to_px.call(track.get_point_at(f * track.length)), 3, Color(0.1, 0.9, 1))
	var path := "%s/layout_%s.png" % [args.out, track.track_id]
	img.save_png(path)
	print("  png ", path)


func _dot(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var x := c.x + dx
				var y := c.y + dy
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, col)
