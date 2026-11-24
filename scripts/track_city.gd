@tool
class_name TrackCity
extends RefCounted
## Cidade neon à noite (Track.city_track), sempre com a marca da Ativos:
## - prédios em quadras (mais altos longe da pista) com janelas acesas
##   (shaders/city_building.gdshader), faixas de neon no alto, antenas com luz vermelha e
##   letreiros holográficos da Ativos e do Celerino nas fachadas viradas para a pista;
## - horizonte de arranha-céus em volta do mapa inteiro;
## - tubos de neon nas muretas (magenta à esquerda, ciano à direita), postes com luminária
##   de neon em cima das muretas e portais de neon por cima da pista;
## - fachos de holofote varrendo o céu (light_beam.gdshader);
## - neblina baixa nas ruas, no canal e no gramado do estádio (city_mist.gdshader), em
##   duas camadas, por cima da névoa do WorldEnvironment (mais densa perto do chão).
## O asfalto molhado, as zebras de neon e as muretas de LED ficam no track.gd; o estádio,
## quando tem, fica no track_stadium.gd (com os acabamentos de neon dele).

const BUILDING_SHADER := preload("res://shaders/city_building.gdshader")
const NEON_SHADER := preload("res://shaders/neon.gdshader")
const BEAM_SHADER := preload("res://shaders/light_beam.gdshader")
const MIST_SHADER := preload("res://shaders/city_mist.gdshader")
const CELERINO_ICON := preload("res://assets/ui/carregando_celerino.png")

const CYAN := Color(0.1, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.15, 0.75)
const PURPLE := Color(0.62, 0.28, 1.0)
const NEON_BLUE := Color(0.25, 0.45, 1.0)
const NEON_YELLOW := Color(1.0, 0.84, 0.15)
const NEONS: Array[Color] = [CYAN, MAGENTA, PURPLE, NEON_BLUE, NEON_YELLOW]
const STEEL_DARK := Color(0.16, 0.17, 0.21)

## Quadras (m) e distância mínima dos prédios até o meio da pista.
const LOT := 34.0
const CLEAR := 27.0
## Até onde vão os prédios além da área da pista, e a faixa do horizonte.
const CITY_MARGIN := 420.0
const SKYLINE_WIDTH := 520.0
## Blocos de malha (m): poucos e grandes, para não multiplicar as chamadas de desenho.
const CHUNK := 320.0
const LAMP_SPACING := 34.0
const ARCH_SPACING := 150.0
## Neblina: tamanho das placas (m) e as camadas [altura acima do chão, densidade, escala
## do ruído, vento, distância mínima até o meio da pista]. A rasante (0,45 m) cobre também
## a pista: o kart anda dentro dela (perto da câmera ela se abre); as de cima ficam fora
## das muretas.
const MIST_CELL := 24.0
const MIST_LAYERS := [[0.45, 0.42, 0.028, Vector2(0.02, 0.011), 0.0], [1.8, 0.6, 0.02, Vector2(0.012, 0.007), 15.5],
		[4.5, 0.36, 0.013, Vector2(-0.008, 0.01), 15.5]]

var track: Track
var terrain: TrackTerrain
var root: Node3D
var rng := RandomNumberGenerator.new()
## Lugares ocupados (x, z, raio) do TrackScenery.
var reserved: Array[Vector3] = []
var _outside := 0.0
var _mats := {}


func _init(p_track: Track, p_terrain: TrackTerrain, p_root: Node3D) -> void:
	track = p_track
	terrain = p_terrain
	root = p_root
	rng.seed = track.decoration_seed * 7307 + 3
	_outside = track.road_width * 0.5 + track.shoulder_width + track.wall_thickness


## Material dos tubos de neon (cor de vértice acesa).
static func neon_material(energy := 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = NEON_SHADER
	m.set_shader_parameter("energy", energy)
	return m


## Letreiro holográfico (painel com logo aceso): `kind` 0..4.
static func sign_material(kind: int, aspect: float) -> ShaderMaterial:
	match kind % 5:
		0:
			return TrackScenery.brand_material(TrackScenery.WORDMARK_DARK, Color(0.1, 0.02, 0.2), aspect,
					{"logo_fill": 0.6, "border_width": 0.05, "border_color": MAGENTA, "emission": 1.3})
		1:
			return TrackScenery.brand_material(TrackScenery.LOGO_ICON, Color(0.02, 0.02, 0.06), aspect,
					{"recolor": true, "recolor_main": CYAN, "recolor_accent": MAGENTA, "logo_fill": 0.78, "emission": 1.6})
		2:
			return TrackScenery.brand_material(TrackScenery.WORDMARK_DARK, Color(0.0, 0.2, 0.32), aspect,
					{"logo_fill": 0.6, "border_width": 0.05, "border_color": CYAN, "emission": 1.3})
		3:
			return TrackScenery.brand_material(TrackScenery.LOGO_ICON, Color(0.08, 0.12, 0.45), aspect,
					{"recolor": true, "recolor_main": Color.WHITE, "recolor_accent": NEON_YELLOW, "logo_fill": 0.78, "emission": 1.3})
	# O Celerino no kart (a silhueta do ícone de carregamento) em magenta.
	return TrackScenery.brand_material(CELERINO_ICON, Color(0.04, 0.0, 0.08), aspect,
			{"recolor": true, "recolor_main": MAGENTA, "recolor_accent": MAGENTA, "logo_fill": 0.82, "emission": 1.6,
			"border_width": 0.04, "border_color": CYAN})


## Facho de holofote com a ponta em `at` (veja light_beam.gdshader).
static func add_beam(parent: Node3D, at: Vector3, color: Color, phase: float, length := 240.0) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = length * 0.06
	cone.bottom_radius = 0.6
	cone.height = length
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("beam_length", length)
	mat.set_shader_parameter("phase", phase)
	var mi := MeshInstance3D.new()
	mi.name = "Holofote"
	mi.mesh = cone
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# O cone vem centrado na origem: o shader sobe metade dele para a ponta ficar em `at`
	# e gira em volta dela.
	mi.transform = Transform3D(Basis(), at)
	mi.custom_aabb = AABB(Vector3(-length, -length, -length), Vector3.ONE * length * 2.0)
	parent.add_child(mi)


func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"building":
			var b := ShaderMaterial.new()
			b.shader = BUILDING_SHADER
			m = b
		"neon":
			m = neon_material()
		"tint":
			var t := StandardMaterial3D.new()
			t.vertex_color_use_as_albedo = true
			t.vertex_color_is_srgb = true
			t.roughness = 0.6
			t.metallic = 0.3
			m = t
	_mats[key] = m
	return m


func _node(name: String, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	(parent if parent else root).add_child(n)
	return n


static func _chunk_key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CHUNK), floori(z / CHUNK))


func _commit(groups: Dictionary, material: Material, name: String, parent: Node3D, shadows := true) -> void:
	for key: Vector2i in groups:
		var md: Track.MeshData = groups[key]
		if md.indices.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.name = name
		mi.mesh = md.to_mesh(material)
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Fora do estádio (com folga), onde a cidade pode ter prédios, postes e portais.
func _outside_stadium(x: float, z: float, margin: float) -> bool:
	return not track.stadium_track or not TrackStadium.inside(track, x, z, margin)


# --- Montagem ----------------------------------------------------------------------------

func build_landmarks(p_reserved: Array[Vector3], preview: bool) -> void:
	reserved = p_reserved
	var node := _node("Cidade")
	_build_wall_neon(node)
	_build_lamps(node)
	_build_arches(node)
	_build_buildings(node, preview)
	_build_skyline(node)
	_build_beams(node)
	_build_mist(node, preview)


## Faixa de neon logo abaixo do alto das muretas, dos dois lados (fora dos vãos).
func _build_wall_neon(parent: Node3D) -> void:
	var md := Track.MeshData.new()
	var n := track.samples.size()
	var lat := track.road_width * 0.5 + track.shoulder_width - 0.03
	var y0 := track.wall_height - 0.26
	var y1 := track.wall_height - 0.11
	var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	for side: float in [-1.0, 1.0]:
		var col := MAGENTA if side < 0.0 else CYAN
		for i in n:
			var j := (i + 1) % n
			if track.is_gap(i) or track.is_gap(j):
				continue
			var a := track.samples[i] + track.rights[i] * side * lat
			var b := track.samples[j] + track.rights[j] * side * lat
			var nrm := -track.rights[i] * side
			TrackStadium._quad(md, [a + Vector3.UP * y0, b + Vector3.UP * y0, b + Vector3.UP * y1, a + Vector3.UP * y1],
					[nrm, nrm, nrm, nrm], uvs, nrm, col)
	var mi := MeshInstance3D.new()
	mi.name = "NeonMureta"
	mi.mesh = md.to_mesh(_mat("neon"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Postes em cima das muretas, alternando os lados, com o braço por cima do acostamento
## e a luminária de neon.
func _build_lamps(parent: Node3D) -> void:
	var poles := {}
	var heads := {}
	var n := track.samples.size()
	var step_len := track.length / n
	var lat := track.road_width * 0.5 + track.shoulder_width + track.wall_thickness * 0.5
	var next := 20.0
	var side := 1.0
	for i in n:
		if track.distances[i] < next:
			continue
		next = track.distances[i] + LAMP_SPACING * 0.5
		side = -side
		if track.is_gap(i) or absf(track.distances[i]) < 25.0 or track.distances[i] > track.length - 25.0:
			continue
		var base := track.samples[i] + track.rights[i] * side * lat + Vector3.UP * track.wall_height
		if not _outside_stadium(base.x, base.z, 0.0):
			continue
		var top := base + Vector3.UP * 7.5
		var reach := top - track.rights[i] * side * 3.2
		var key := _chunk_key(base.x, base.z)
		if not poles.has(key):
			poles[key] = Track.MeshData.new()
			heads[key] = Track.MeshData.new()
		TrackStadium._beam_md(poles[key], base, top + Vector3.UP * 0.2, 0.22, 0.22, STEEL_DARK)
		TrackStadium._beam_md(poles[key], top, reach, 0.16, 0.16, STEEL_DARK)
		var col := CYAN if side > 0.0 else MAGENTA
		TrackStadium._beam_md(heads[key], reach - track.rights[i] * side * 0.2 + Vector3.DOWN * 0.12,
				reach + track.rights[i] * side * 1.3 + Vector3.DOWN * 0.12, 0.32, 0.1, col)
	_commit(poles, _mat("tint"), "Postes", parent)
	_commit(heads, _mat("neon"), "Luminarias", parent, false)


## Portais de neon por cima da pista: dois pilares e a viga, contorno de neon por dentro
## e por fora e a placa acesa da marca no meio.
func _build_arches(parent: Node3D) -> void:
	var node := _node("Portais", parent)
	var frame := Track.MeshData.new()
	var neon := Track.MeshData.new()
	var signs: Array[Track.MeshData] = [Track.MeshData.new(), Track.MeshData.new()]
	var n := track.samples.size()
	var half := _outside + 0.6
	var height := 9.0
	var count := 0
	var d := 70.0
	while d < track.length - 60.0:
		var i := clampi(int(d / track.length * n), 0, n - 1)
		d += 12.0
		if not _arch_ok(i):
			continue
		d += ARCH_SPACING - 12.0
		var p := track.samples[i]
		var r := track.rights[i]
		var t := track.tangents[i]
		t.y = 0.0
		t = t.normalized()
		var col: Color = NEONS[count % NEONS.size()]
		var l0 := p - r * half
		var r0 := p + r * half
		var up := Vector3.UP * height
		TrackStadium._beam_md(frame, l0, l0 + up, 0.9, 0.9, STEEL_DARK)
		TrackStadium._beam_md(frame, r0, r0 + up, 0.9, 0.9, STEEL_DARK)
		TrackStadium._beam_md(frame, l0 + up + Vector3.UP * 0.55 - r * 0.45, r0 + up + Vector3.UP * 0.55 + r * 0.45, 1.1, 1.1, STEEL_DARK)
		# Contorno de neon nas duas faces (quem chega e quem olha para trás).
		for face: float in [-1.0, 1.0]:
			var o := t * face * 0.5
			var li := l0 + r * 0.5 + o
			var ri := r0 - r * 0.5 + o
			TrackStadium._beam_md(neon, li, li + up, 0.1, 0.1, col)
			TrackStadium._beam_md(neon, ri, ri + up, 0.1, 0.1, col)
			TrackStadium._beam_md(neon, li + up, ri + up, 0.1, 0.1, col)
		# Placa no alto, de frente para quem chega (+ o verso).
		var w := 9.0
		var h := 1.7
		var c := p + Vector3.UP * (height + 0.55)
		var toward := -t
		for face: float in [1.0, -1.0]:
			var nrm := toward * face
			var right := (-nrm).cross(Vector3.UP).normalized()
			var center := c + nrm * 0.6
			var md := signs[(count + (0 if face > 0.0 else 1)) % 2]
			TrackStadium._quad(md, [center - right * w * 0.5 + Vector3.UP * h * 0.5, center + right * w * 0.5 + Vector3.UP * h * 0.5,
					center + right * w * 0.5 - Vector3.UP * h * 0.5, center - right * w * 0.5 - Vector3.UP * h * 0.5],
					[nrm, nrm, nrm, nrm], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], nrm)
		count += 1
	if count == 0:
		return
	var fm := MeshInstance3D.new()
	fm.mesh = frame.to_mesh(_mat("tint"))
	node.add_child(fm)
	var nm := MeshInstance3D.new()
	nm.mesh = neon.to_mesh(_mat("neon"))
	nm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(nm)
	for k in 2:
		if signs[k].indices.is_empty():
			continue
		var sm := MeshInstance3D.new()
		sm.mesh = signs[k].to_mesh(sign_material(k * 2, 9.0 / 1.7))
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(sm)


## Portal só em trecho comum: longe da largada, fora do estádio, sem ponte, vão ou rampa
## por perto (o pulo passa por cima de onde o portal ficaria).
func _arch_ok(i: int) -> bool:
	var d := track.distances[i]
	if d < 70.0 or d > track.length - 60.0:
		return false
	var n := track.samples.size()
	for k in range(-12, 13, 3):
		var j := (i + k + n) % n
		if track.is_bridge(j) or track.is_gap(j) or not track.is_plain(j):
			return false
	for ramp in track.ramps:
		if ramp == null:
			continue
		var rd := ramp.at * track.length
		var ahead := wrapf(d - rd, -track.length * 0.5, track.length * 0.5)
		if ahead > -40.0 and ahead < (ramp.glide_distance if ramp.glider else 70.0):
			return false
	var p := track.samples[i]
	return _outside_stadium(p.x, p.z, TrackStadium.OUT_U + 20.0)


## Prédios nas quadras em volta da pista (fora do estádio e do canal).
func _build_buildings(parent: Node3D, preview: bool) -> void:
	var node := _node("Predios", parent)
	var groups := {}
	var neon := {}
	var signs: Array[Track.MeshData] = []
	for k in 5:
		signs.append(Track.MeshData.new())
	var area := terrain.half_extent + Vector2(CITY_MARGIN, CITY_MARGIN)
	var c := terrain.center
	var step := LOT * (2.0 if preview else 1.0)
	var x := c.x - area.x
	while x < c.x + area.x:
		var z := c.y - area.y
		while z < c.y + area.y:
			_try_building(groups, neon, signs, x + rng.randf_range(-4.0, 4.0), z + rng.randf_range(-4.0, 4.0))
			z += step
		x += step
	_commit(groups, _mat("building"), "Predios", node)
	_commit(neon, _mat("neon"), "NeonPredios", node, false)
	for k in signs.size():
		if signs[k].indices.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Letreiros"
		mi.mesh = signs[k].to_mesh(sign_material(k, 1.6))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)


func _try_building(groups: Dictionary, neon: Dictionary, signs: Array[Track.MeshData], px: float, pz: float) -> void:
	if rng.randf() < 0.1:
		return
	var w := rng.randf_range(14.0, 26.0)
	var d := rng.randf_range(14.0, 26.0)
	var corners: Array[Vector2] = [Vector2(px - w * 0.5, pz - d * 0.5), Vector2(px + w * 0.5, pz - d * 0.5),
			Vector2(px + w * 0.5, pz + d * 0.5), Vector2(px - w * 0.5, pz + d * 0.5)]
	var dmin := terrain.distance_to_track(px, pz)
	var gmin := INF
	var gmax := -INF
	for q in corners:
		dmin = minf(dmin, terrain.distance_to_track(q.x, q.y))
		var g := terrain.height_at(q.x, q.y)
		gmin = minf(gmin, g)
		gmax = maxf(gmax, g)
	if dmin < CLEAR or gmin < terrain.water_level + 0.6 or gmax - gmin > 3.0:
		return
	if not _outside_stadium(px, pz, TrackStadium.OUT_U + 34.0):
		return
	for r in reserved:
		if Vector2(px - r.x, pz - r.y).length() < r.z + 12.0:
			return
	var far := smoothstep(CLEAR, 260.0, dmin)
	var h := lerpf(12.0, 58.0, far) * rng.randf_range(0.6, 1.4)
	if rng.randf() < 0.08 + far * 0.1:
		h *= rng.randf_range(1.8, 2.8)
	var seed := rng.randf()
	var col: Color = NEONS[rng.randi() % NEONS.size()]
	var info := Color(col.r, col.g, col.b, seed)
	var key := _chunk_key(px, pz)
	if not groups.has(key):
		groups[key] = Track.MeshData.new()
		neon[key] = Track.MeshData.new()
	var md: Track.MeshData = groups[key]
	var nm: Track.MeshData = neon[key]
	var base := gmin - 0.6
	var top := gmax + h
	_box_building(md, Vector3(px, base, pz), w, d, top - base, info)
	# Recuo no alto dos prédios altos.
	var crown := top
	if h > 45.0 and rng.randf() < 0.6:
		var w2 := w * rng.randf_range(0.5, 0.75)
		var d2 := d * rng.randf_range(0.5, 0.75)
		var h2 := h * rng.randf_range(0.15, 0.35)
		_box_building(md, Vector3(px, top, pz), w2, d2, h2, info)
		_neon_ring(nm, Vector3(px, top + h2, pz), w2, d2, col)
		crown = top + h2
	if rng.randf() < 0.75:
		_neon_ring(nm, Vector3(px, top, pz), w, d, col)
	# Faixas de neon nas quinas de alguns.
	if rng.randf() < 0.25:
		for q in corners:
			var p := Vector3(q.x, base, q.y)
			TrackStadium._beam_md(nm, p + Vector3.UP * 2.0, p + Vector3.UP * (top - base - 1.0), 0.18, 0.18, col)
	# Antena com a luz vermelha nos mais altos.
	if h > 70.0:
		var a := Vector3(px, crown, pz)
		TrackStadium._beam_md(nm, a, a + Vector3.UP * 9.0, 0.12, 0.12, Color(0.35, 0.35, 0.4))
		TrackStadium._beam_md(nm, a + Vector3.UP * 9.0, a + Vector3.UP * 9.6, 0.5, 0.5, Color(1.0, 0.1, 0.1))
	# Letreiro holográfico na fachada virada para a pista (perto dela).
	if dmin < 110.0 and rng.randf() < 0.45:
		var idx := terrain.nearest_track_index(px, pz)
		if idx >= 0:
			var to := track.samples[idx] - Vector3(px, 0.0, pz)
			var nrm := Vector3(signf(to.x), 0.0, 0.0) if absf(to.x) > absf(to.z) else Vector3(0.0, 0.0, signf(to.z))
			var face_w := d if absf(nrm.x) > 0.5 else w
			var sw := face_w * rng.randf_range(0.6, 0.85)
			var sh := sw / 1.6
			var sy := base + clampf((top - base) * rng.randf_range(0.45, 0.75), sh * 0.5 + 6.0, top - base - sh * 0.5 - 1.0)
			var center := Vector3(px, sy, pz) + nrm * ((w if absf(nrm.x) > 0.5 else d) * 0.5 + 0.35)
			var right := (-nrm).cross(Vector3.UP).normalized()
			if sy + sh * 0.5 < top:
				TrackStadium._quad(signs[rng.randi() % signs.size()], [center - right * sw * 0.5 + Vector3.UP * sh * 0.5,
						center + right * sw * 0.5 + Vector3.UP * sh * 0.5, center + right * sw * 0.5 - Vector3.UP * sh * 0.5,
						center - right * sw * 0.5 - Vector3.UP * sh * 0.5], [nrm, nrm, nrm, nrm],
						[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], nrm)


## Caixa de prédio (4 fachadas e o telhado) com UV em metros e a cor/sorteio em COLOR.
static func _box_building(md: Track.MeshData, base: Vector3, w: float, d: float, h: float, info: Color) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var c: Array[Vector3] = [base + Vector3(-hw, 0, -hd), base + Vector3(hw, 0, -hd), base + Vector3(hw, 0, hd), base + Vector3(-hw, 0, hd)]
	var up := Vector3.UP * h
	var run := 0.0
	for k in 4:
		var a := c[k]
		var b := c[(k + 1) % 4]
		var nrm := (a + b - base * 2.0)
		nrm.y = 0.0
		nrm = nrm.normalized()
		var seg_len := a.distance_to(b)
		var ia := md.add_vertex(a, nrm, Vector2(run, 0.0))
		var ib := md.add_vertex(b, nrm, Vector2(run + seg_len, 0.0))
		var ic := md.add_vertex(b + up, nrm, Vector2(run + seg_len, h))
		var id := md.add_vertex(a + up, nrm, Vector2(run, h))
		md.colors.append_array([info, info, info, info])
		md.add_tri(ia, ib, ic, nrm)
		md.add_tri(ia, ic, id, nrm)
		run += seg_len
	var r := [md.add_vertex(c[0] + up, Vector3.UP, Vector2(0, -1)), md.add_vertex(c[1] + up, Vector3.UP, Vector2(1, -1)),
			md.add_vertex(c[2] + up, Vector3.UP, Vector2(1, -1)), md.add_vertex(c[3] + up, Vector3.UP, Vector2(0, -1))]
	md.colors.append_array([info, info, info, info])
	md.add_tri(r[0], r[1], r[2], Vector3.UP)
	md.add_tri(r[0], r[2], r[3], Vector3.UP)


## Faixa de neon em volta do alto de um bloco (um pouco para fora da fachada).
static func _neon_ring(md: Track.MeshData, top_center: Vector3, w: float, d: float, col: Color) -> void:
	var hw := w * 0.5 + 0.12
	var hd := d * 0.5 + 0.12
	var y := top_center + Vector3.DOWN * 0.9
	var c: Array[Vector3] = [y + Vector3(-hw, 0, -hd), y + Vector3(hw, 0, -hd), y + Vector3(hw, 0, hd), y + Vector3(-hw, 0, hd)]
	for k in 4:
		TrackStadium._beam_md(md, c[k], c[(k + 1) % 4], 0.12, 0.35, col)


## Arranha-céus no horizonte, em volta do mapa inteiro (sem sombra).
func _build_skyline(parent: Node3D) -> void:
	var node := _node("Horizonte", parent)
	var md := Track.MeshData.new()
	var nm := Track.MeshData.new()
	var c := terrain.center
	var inner := maxf(terrain.half_extent.x, terrain.half_extent.y) + CITY_MARGIN + 60.0
	var count := 170
	for k in count:
		var ang := TAU * (k + rng.randf_range(-0.3, 0.3)) / count
		var dist := inner + rng.randf_range(0.0, SKYLINE_WIDTH)
		var px := c.x + cos(ang) * dist
		var pz := c.y + sin(ang) * dist
		var w := rng.randf_range(26.0, 60.0)
		var d := rng.randf_range(26.0, 60.0)
		var h := rng.randf_range(60.0, 180.0) * (1.0 + rng.randf() * rng.randf() * 1.4)
		var col: Color = NEONS[rng.randi() % NEONS.size()]
		var ground := terrain.height_at(px, pz) - 1.0
		_box_building(md, Vector3(px, ground, pz), w, d, h, Color(col.r, col.g, col.b, rng.randf()))
		if rng.randf() < 0.5:
			_neon_ring(nm, Vector3(px, ground + h, pz), w, d, col)
		if h > 200.0:
			var a := Vector3(px, ground + h, pz)
			TrackStadium._beam_md(nm, a, a + Vector3.UP * 18.0, 0.4, 0.4, Color(0.35, 0.35, 0.4))
			TrackStadium._beam_md(nm, a + Vector3.UP * 18.0, a + Vector3.UP * 19.5, 1.4, 1.4, Color(1.0, 0.1, 0.1))
	var bm := MeshInstance3D.new()
	bm.mesh = md.to_mesh(_mat("building"))
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(bm)
	var neon_mi := MeshInstance3D.new()
	neon_mi.mesh = nm.to_mesh(_mat("neon"))
	neon_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(neon_mi)


## Fachos de holofote varrendo o céu: no alto de alguns prédios perto da pista (o
## estádio põe os dele nas torres de luz).
func _build_beams(parent: Node3D) -> void:
	var node := _node("Holofotes", parent)
	var n := track.samples.size()
	var cols: Array[Color] = [Color(0.55, 0.85, 1.0), Color(1.0, 0.45, 0.85), Color(0.7, 0.55, 1.0)]
	var made := 0
	for k in 6:
		var i := int(float(k) / 6.0 * n + n / 12) % n
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := track.samples[i] + track.rights[i] * side * 60.0
		if not _outside_stadium(p.x, p.z, TrackStadium.OUT_U + 30.0):
			continue
		var g := terrain.height_at(p.x, p.z)
		if g < terrain.water_level + 0.5:
			continue
		add_beam(node, Vector3(p.x, g + 1.0, p.z), cols[made % cols.size()], float(k) * 1.9)
		made += 1


## Neblina baixa: placas em três alturas nas quadras, no canal (logo acima da água), no
## gramado do estádio e (a rasante) em cima da pista, nunca em cima das arquibancadas. As
## placas seguem o chão pelos cantos (sem degrau entre vizinhas) e somem nas beiradas
## (COLOR.a nos cantos). Fica no DETAIL_GROUP (some no gráfico baixo).
func _build_mist(parent: Node3D, preview: bool) -> void:
	if preview:
		return
	var node := _node("Neblina", parent)
	node.add_to_group(TrackScenery.DETAIL_GROUP)
	var area := terrain.half_extent + Vector2(CITY_MARGIN, CITY_MARGIN)
	var origin := terrain.center - area
	var nx := int(area.x * 2.0 / MIST_CELL)
	var nz := int(area.y * 2.0 / MIST_CELL)
	var half := MIST_CELL * 0.5
	# Cada célula: a menor distância até a pista e se pode ter neblina (fora das arquibancadas).
	var near := PackedFloat32Array()
	var allowed := PackedByteArray()
	near.resize(nx * nz)
	allowed.resize(nx * nz)
	for i in nx:
		for j in nz:
			var x := origin.x + (i + 0.5) * MIST_CELL
			var z := origin.y + (j + 0.5) * MIST_CELL
			var d := INF
			for o: Vector2 in [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half), Vector2.ZERO]:
				d = minf(d, terrain.distance_to_track(x + o.x, z + o.y))
			near[i * nz + j] = d
			var on_stands := track.stadium_track and not TrackStadium.inside(track, x, z, -half - 4.0) \
					and TrackStadium.inside(track, x, z, TrackStadium.OUT_U + half + 6.0)
			allowed[i * nz + j] = 0 if on_stands else 1
	# Altura do chão em cada canto da grade (no canal, a água).
	var corner_y := PackedFloat32Array()
	corner_y.resize((nx + 1) * (nz + 1))
	for i in nx + 1:
		for j in nz + 1:
			var x := origin.x + i * MIST_CELL
			var z := origin.y + j * MIST_CELL
			corner_y[i * (nz + 1) + j] = maxf(terrain.height_at(x, z), terrain.water_level)
	for k in MIST_LAYERS.size():
		var lift: float = MIST_LAYERS[k][0]
		var clear: float = MIST_LAYERS[k][4]
		var on := PackedByteArray()
		on.resize(nx * nz)
		for c in nx * nz:
			on[c] = 1 if allowed[c] == 1 and near[c] >= clear else 0
		var groups := {}
		for i in nx:
			for j in nz:
				if on[i * nz + j] == 0:
					continue
				var x0 := origin.x + i * MIST_CELL
				var z0 := origin.y + j * MIST_CELL
				var key := _chunk_key(x0 + half, z0 + half)
				if not groups.has(key):
					groups[key] = Track.MeshData.new()
				var md: Track.MeshData = groups[key]
				var ids := PackedInt32Array()
				for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var ci := i + corner.x
					var cj := j + corner.y
					# O canto fica cheio só se as quatro células em volta têm neblina.
					var full := true
					for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
						var a := ci + o.x
						var b := cj + o.y
						if a < 0 or b < 0 or a >= nx or b >= nz or on[a * nz + b] == 0:
							full = false
							break
					var y := corner_y[ci * (nz + 1) + cj] + lift
					ids.append(md.add_vertex(Vector3(origin.x + ci * MIST_CELL, y, origin.y + cj * MIST_CELL), Vector3.UP, Vector2(corner)))
					md.colors.append(Color(1, 1, 1, 1.0 if full else 0.0))
				md.add_tri(ids[0], ids[1], ids[2], Vector3.UP)
				md.add_tri(ids[0], ids[2], ids[3], Vector3.UP)
		var mat := ShaderMaterial.new()
		mat.shader = MIST_SHADER
		mat.set_shader_parameter("density", MIST_LAYERS[k][1])
		mat.set_shader_parameter("scale", MIST_LAYERS[k][2])
		mat.set_shader_parameter("drift", MIST_LAYERS[k][3])
		if k == 2:
			mat.set_shader_parameter("mist_color", Color(0.3, 0.18, 0.55))
			mat.set_shader_parameter("glow_color", Color(0.2, 0.85, 1.0))
		_commit(groups, mat, "Neblina", node, false)
