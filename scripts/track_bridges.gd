@tool
class_name TrackBridgeBuilder
extends RefCounted
## Monta as pontes da pista (veja track_bridge.gd): tabuleiro com faixa azul e
## amarela, cabeceiras, pilares e a estrutura de cada estilo — torre estaiada com o
## logo "at" e cabos, arco de aço azul com a marca no alto, viaduto de arcos de
## pedra ou passarela de tábuas em cima de estacas (praia) — e as faixas com a marca da
## Ativos nas laterais.

const STONE_SHADER := preload("res://shaders/stone.gdshader")
const BEACH_ROAD_SHADER := preload("res://shaders/beach_road.gdshader")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")
const WORDMARK := preload("res://assets/logos/ativos_marca.png")
const WORDMARK_DARK := preload("res://assets/logos/ativos_marca_branca.png")

## Espessura do tabuleiro embaixo do asfalto.
const DECK_THICKNESS := 1.5
## Quanto o tabuleiro passa para fora da mureta.
const LIP := 0.35

var track: Track
var terrain: TrackTerrain
var root: Node3D

var _outer := 0.0
var _step := 2.0
var _mats := {}


## Junta várias peças com o mesmo material numa malha só (menos draw calls).
class Batch:
	var tools := {}

	func add(mesh: PrimitiveMesh, xform: Transform3D, material: Material) -> void:
		if not tools.has(material):
			tools[material] = MeshMerge.new()
		(tools[material] as MeshMerge).append_from(mesh, 0, xform)

	func commit(parent: Node3D, name: String, shadows := true) -> void:
		for material: Material in tools:
			var st: MeshMerge = tools[material]
			st.set_material(material)
			var mi := MeshInstance3D.new()
			mi.name = name
			mi.mesh = st.commit()
			if not shadows:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
		tools.clear()


func _init(p_track: Track, p_terrain: TrackTerrain, p_root: Node3D) -> void:
	track = p_track
	terrain = p_terrain
	root = p_root


func build(_preview: bool) -> void:
	_outer = track.road_width * 0.5 + track.shoulder_width + track.wall_thickness
	_step = track.length / maxf(track.samples.size(), 1)
	var count := track.samples.size()
	for span in track.bridge_spans:
		var b: TrackBridge = span.bridge
		var from: int = span.from
		var to: int = span.to
		var node := Node3D.new()
		node.name = "Ponte"
		root.add_child(node)
		if b.style == TrackBridge.Style.PASSARELA:
			_build_boardwalk(node, from, to)
			continue
		var viaduct := b.style == TrackBridge.Style.VIADUTO
		var solid := Batch.new()
		var thin := Batch.new()
		_build_deck(node, maxi(from - 2, 0), mini(to + 2, count - 1), viaduct)
		var pier_mat: Material = _mat("stone") if viaduct else _mat("pier")
		_build_abutment(solid, from, 1.0, pier_mat)
		_build_abutment(solid, to, -1.0, pier_mat)
		match b.style:
			TrackBridge.Style.ESTAIADA:
				_build_piers(solid, from, to, 22.0)
				_build_cable_stayed(node, solid, thin, from, to)
			TrackBridge.Style.ARCO:
				_build_piers(solid, from, to, 26.0)
				_build_arch(node, solid, thin, from, to)
			TrackBridge.Style.VIADUTO:
				_build_viaduct(node, solid, from, to)
			_:
				_build_piers(solid, from, to, 16.0)
		if not viaduct:
			_build_banners(node, from, to)
		solid.commit(node, "Estrutura")
		thin.commit(node, "Cabos", false)


# --- Materiais ---------------------------------------------------------------------------

func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if track.city_track and key in ["concrete", "pier", "fascia", "trim"]:
		# Elevado da cidade neon: concreto escuro, faixa roxa e o friso aceso em ciano.
		match key:
			"concrete":
				m = TrackScenery.color_material(Color(0.2, 0.2, 0.25), 0.85)
			"pier":
				m = TrackScenery.color_material(Color(0.17, 0.17, 0.22), 0.85)
			"fascia":
				m = TrackScenery.color_material(Color(0.16, 0.06, 0.3), 0.5)
			"trim":
				m = TrackCity.neon_material(2.4)
		_mats[key] = m
		return m
	match key:
		"concrete":
			m = TrackScenery.color_material(Color(0.8, 0.8, 0.82), 0.85)
		"pier":
			m = TrackScenery.color_material(Color(0.74, 0.75, 0.78), 0.85)
		"fascia":
			m = TrackScenery.color_material(TrackScenery.BRAND_BLUE, 0.45)
		"trim":
			m = TrackScenery.color_material(TrackScenery.YELLOW, 0.45)
		"tower":
			m = TrackScenery.color_material(Color(0.95, 0.95, 0.97), 0.4)
		"steel":
			m = TrackScenery.color_material(TrackScenery.BRAND_BLUE, 0.35, 0.35)
		"cable":
			m = TrackScenery.color_material(Color(0.93, 0.93, 0.96), 0.3, 0.5)
		"wood":
			m = TrackScenery.color_material(Color(0.55, 0.36, 0.21), 0.88)
		"wood_dark":
			m = TrackScenery.color_material(Color(0.33, 0.22, 0.14), 0.9)
		"lantern":
			var l := TrackScenery.color_material(Color(1.0, 0.86, 0.5), 0.3)
			l.emission_enabled = true
			l.emission = Color(1.0, 0.78, 0.4)
			l.emission_energy_multiplier = 1.4
			m = l
		"stone":
			var s := ShaderMaterial.new()
			s.shader = STONE_SHADER
			match track.scenery:
				TrackTheme.Scenery.NEVE:
					s.set_shader_parameter("stone_a", Color(0.7, 0.7, 0.72))
					s.set_shader_parameter("stone_b", Color(0.5, 0.51, 0.55))
					s.set_shader_parameter("snow_cover", 1.0)
				TrackTheme.Scenery.DESERTO:
					s.set_shader_parameter("stone_a", Color(0.86, 0.6, 0.42))
					s.set_shader_parameter("stone_b", Color(0.68, 0.42, 0.28))
			m = s
	_mats[key] = m
	return m


# --- Posições ao longo da pista ----------------------------------------------------------

## Ponto na pista no índice fracionário `fi`, deslocado para o lado e para cima.
func _pos(fi: float, lateral: float, height: float) -> Vector3:
	var n := track.samples.size()
	var i := clampi(int(floor(fi)), 0, n - 1)
	var j := mini(i + 1, n - 1)
	var t := clampf(fi - i, 0.0, 1.0)
	var s := track.samples[i].lerp(track.samples[j], t)
	var r := track.rights[i].lerp(track.rights[j], t).normalized()
	return s + r * lateral + Vector3.UP * height


func _tangent(fi: float) -> Vector3:
	var n := track.samples.size()
	var i := clampi(int(round(fi)), 0, n - 1)
	var t := track.tangents[i]
	t.y = 0.0
	return t.normalized()


## Base virada para o sentido da pista (+Z = para trás, como um painel olhando quem chega).
func _track_basis(fi: float) -> Basis:
	var t := _tangent(fi)
	return Basis(t.cross(Vector3.UP).normalized(), Vector3.UP, -t)


## Altura mais baixa do chão embaixo da largura do tabuleiro.
func _ground_under(fi: float) -> float:
	var lip := _outer + LIP
	var low := INF
	for lat: float in [-lip, 0.0, lip]:
		var p := _pos(fi, lat, 0.0)
		low = minf(low, terrain.height_at(p.x, p.z))
	return low


## Viga (caixa) ligando dois pontos.
func _beam(batch: Batch, a: Vector3, b: Vector3, w: float, h: float, material: Material) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.01:
		return
	var box := BoxMesh.new()
	box.size = Vector3(w, h, len)
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	batch.add(box, Transform3D(Basis.looking_at(d, up), (a + b) * 0.5), material)


## Cabo (cilindro fino) ligando dois pontos.
func _cable(batch: Batch, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var d := b - a
	var len := d.length()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = len
	cyl.radial_segments = 6
	cyl.rings = 1
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	batch.add(cyl, Transform3D(Basis(x, y, z), (a + b) * 0.5), material)


# --- Tabuleiro, cabeceiras e pilares -------------------------------------------------------

## Faixa entre dois trilhos de (lateral, altura) do índice i0 ao i1.
func _strip(md: Track.MeshData, i0: int, i1: int, a: Vector2, b: Vector2, n: Vector2) -> void:
	var base := md.verts.size()
	for i in range(i0, i1 + 1):
		var s := track.samples[i]
		var r := track.rights[i]
		var nn := (r * n.x + Vector3.UP * n.y).normalized()
		md.add_vertex(s + r * a.x + Vector3.UP * a.y, nn, Vector2(0.0, track.distances[i]))
		md.add_vertex(s + r * b.x + Vector3.UP * b.y, nn, Vector2(1.0, track.distances[i]))
	for k in i1 - i0:
		var v := base + k * 2
		md.add_tri(v, v + 1, v + 2, md.normals[v])
		md.add_tri(v + 1, v + 3, v + 2, md.normals[v])


func _cap(md: Track.MeshData, i: int, facing: Vector3, lip: float) -> void:
	var s := track.samples[i]
	var r := track.rights[i]
	var top := -0.05
	var bottom := -DECK_THICKNESS
	var a := md.add_vertex(s - r * lip + Vector3.UP * top, facing, Vector2(0, 0))
	var b := md.add_vertex(s + r * lip + Vector3.UP * top, facing, Vector2(1, 0))
	var c := md.add_vertex(s - r * lip + Vector3.UP * bottom, facing, Vector2(0, 1))
	var d := md.add_vertex(s + r * lip + Vector3.UP * bottom, facing, Vector2(1, 1))
	md.add_tri(a, b, c, facing)
	md.add_tri(b, d, c, facing)


func _build_deck(node: Node3D, i0: int, i1: int, viaduct: bool) -> void:
	var lip := _outer + LIP
	var body := Track.MeshData.new()
	_strip(body, i0, i1, Vector2(-lip, -0.05), Vector2(lip, -0.05), Vector2(0, 1))
	_strip(body, i0, i1, Vector2(-lip, -DECK_THICKNESS), Vector2(lip, -DECK_THICKNESS), Vector2(0, -1))
	_cap(body, i0, -track.tangents[i0], lip)
	_cap(body, i1, track.tangents[i1], lip)
	var trim := Track.MeshData.new()
	var fascia := Track.MeshData.new()
	for side: float in [-1.0, 1.0]:
		_strip(trim, i0, i1, Vector2(side * lip, -0.05), Vector2(side * lip, -0.42), Vector2(side, 0))
		_strip(fascia, i0, i1, Vector2(side * lip, -0.42), Vector2(side * lip, -DECK_THICKNESS), Vector2(side, 0))
	var deck := MeshInstance3D.new()
	deck.name = "Tabuleiro"
	deck.mesh = body.to_mesh(_mat("stone") if viaduct else _mat("concrete"))
	node.add_child(deck)
	for part in [[trim, _mat("stone") if viaduct else _mat("trim")], [fascia, _mat("stone") if viaduct else _mat("fascia")]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (part[0] as Track.MeshData).to_mesh(part[1])
		node.add_child(mi)


## Bloco embaixo da ponta da ponte, descendo até o chão.
func _build_abutment(batch: Batch, i: int, inward: float, material: Material) -> void:
	var fi := float(i) + inward * 1.2 / _step
	var road_y := _pos(fi, 0.0, 0.0).y
	var top := road_y - DECK_THICKNESS + 0.05
	var bottom := _ground_under(fi) - 2.5
	if top - bottom < 0.4:
		return
	var box := BoxMesh.new()
	box.size = Vector3((_outer + LIP) * 2.0, top - bottom, 3.0)
	var c := _pos(fi, 0.0, 0.0)
	batch.add(box, Transform3D(_track_basis(fi), Vector3(c.x, (top + bottom) * 0.5, c.z)), material)


## O pilar cairia em cima de outro trecho da pista (viaduto sobre a pista)?
func _blocks_road(p: Vector3, fi: float) -> bool:
	var idx := terrain.nearest_track_index(p.x, p.z)
	if idx < 0:
		return false
	var d := terrain.nearest_info(p.x, p.z).x
	if d > _outer + 1.5:
		return false
	var gap := absf(track.distances[idx] - track.distances[clampi(int(fi), 0, track.samples.size() - 1)])
	return minf(gap, track.length - gap) > 45.0


## Pilares: duas colunas e uma viga embaixo do tabuleiro, a cada ~`spacing` metros.
func _build_piers(batch: Batch, from: int, to: int, spacing: float) -> void:
	var total := (to - from) * _step
	var parts := maxi(2, int(round(total / spacing)))
	var col_lat := _outer - 2.2
	for k in range(1, parts):
		var fi := lerpf(from, to, float(k) / parts)
		var road_y := _pos(fi, 0.0, 0.0).y
		var top := road_y - DECK_THICKNESS
		var cols: Array[Vector3] = []
		var blocked := false
		var low := INF
		for side: float in [-1.0, 1.0]:
			var p := _pos(fi, side * col_lat, 0.0)
			if _blocks_road(p, fi):
				blocked = true
			low = minf(low, terrain.height_at(p.x, p.z))
			cols.append(p)
		if blocked or top - low < 0.8:
			continue
		var bottom := low - 2.0
		var h := top - 0.5 - bottom
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.75
		cyl.bottom_radius = 0.9
		cyl.height = h
		cyl.radial_segments = 14
		cyl.rings = 1
		for p in cols:
			batch.add(cyl, Transform3D(Basis(), Vector3(p.x, bottom + h * 0.5, p.z)), _mat("pier"))
		var cap := BoxMesh.new()
		cap.size = Vector3(col_lat * 2.0 + 2.6, 1.0, 2.4)
		var c := _pos(fi, 0.0, 0.0)
		batch.add(cap, Transform3D(_track_basis(fi), Vector3(c.x, top - 0.5, c.z)), _mat("pier"))


# --- Faixas com a marca nas laterais ----------------------------------------------------

func _build_banners(node: Node3D, from: int, to: int) -> void:
	var total := (to - from) * _step
	if total < 24.0:
		return
	var width := minf(16.0, total * 0.45)
	var aspect := width / 0.98
	var mid := (from + to) * 0.5
	var lip := _outer + LIP
	var panel := QuadMesh.new()
	panel.size = Vector2(width, 0.98)
	var mat := TrackScenery.brand_material(WORDMARK_DARK, TrackScenery.BRAND_BLUE, aspect,
			{"logo_fill": 0.78, "logo_count": maxi(1, int(width / 6.0)), "emission": 0.05})
	for side: float in [-1.0, 1.0]:
		var p := _pos(mid, side * (lip + 0.04), -0.96)
		var facing := track.rights[int(mid)] * side
		var mi := MeshInstance3D.new()
		mi.mesh = panel
		mi.material_override = mat
		mi.transform = Transform3D(TrackScenery._panel_basis(facing), p)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)


## Painel com logo nas duas faces (frente vira para quem chega pela pista).
func _sign(node: Node3D, center: Vector3, basis: Basis, size: Vector2, front: Material, back: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var f := MeshInstance3D.new()
	f.mesh = quad
	f.material_override = front
	f.transform = Transform3D(basis, center + basis.z * 0.42)
	node.add_child(f)
	var b := MeshInstance3D.new()
	b.mesh = quad
	b.material_override = back
	b.transform = Transform3D(basis.rotated(Vector3.UP, PI), center - basis.z * 0.42)
	node.add_child(b)


# --- Ponte estaiada: torre com o logo e leque de cabos ---------------------------------------

func _build_cable_stayed(node: Node3D, solid: Batch, thin: Batch, from: int, to: int) -> void:
	var mid := (from + to) * 0.5
	var road_y := _pos(mid, 0.0, 0.0).y
	var leg_lat := _outer + 1.8
	var top_h := 31.0
	var basis := _track_basis(mid)
	var low := INF
	for side: float in [-1.0, 1.0]:
		var p := _pos(mid, side * leg_lat, 0.0)
		low = minf(low, terrain.height_at(p.x, p.z))
	var bottom := low - 2.0
	var tops: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var p := _pos(mid, side * leg_lat, 0.0)
		var leg := BoxMesh.new()
		var h := road_y + top_h - bottom
		leg.size = Vector3(1.9, h, 2.6)
		solid.add(leg, Transform3D(basis, Vector3(p.x, bottom + h * 0.5, p.z)), _mat("tower"))
		var cap := BoxMesh.new()
		cap.size = Vector3(2.3, 2.2, 3.0)
		solid.add(cap, Transform3D(basis, Vector3(p.x, road_y + top_h + 0.6, p.z)), _mat("steel"))
		var band := BoxMesh.new()
		band.size = Vector3(2.0, 0.5, 2.7)
		solid.add(band, Transform3D(basis, Vector3(p.x, road_y + top_h - 1.0, p.z)), _mat("trim"))
		tops.append(Vector3(p.x, road_y + top_h - 2.5, p.z))
	# Vigas entre as pernas (a de baixo fica bem acima dos karts).
	var c := _pos(mid, 0.0, 0.0)
	for y: float in [12.0, top_h - 3.5]:
		var beam := BoxMesh.new()
		beam.size = Vector3(leg_lat * 2.0, 1.3, 1.8)
		solid.add(beam, Transform3D(basis, Vector3(c.x, road_y + y, c.z)), _mat("tower"))
	# Placa com o logo entre as vigas.
	var sign_size := Vector2(leg_lat * 2.0 - 2.4, 9.0)
	var sign_center := Vector3(c.x, road_y + 20.6, c.z)
	var board := BoxMesh.new()
	board.size = Vector3(sign_size.x + 0.4, sign_size.y + 0.4, 0.7)
	solid.add(board, Transform3D(basis, sign_center), _mat("steel"))
	var aspect := sign_size.x / sign_size.y
	_sign(node, sign_center, basis, sign_size,
			TrackScenery.brand_material(LOGO_ICON, TrackScenery.BRAND_BLUE, aspect,
				{"recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW, "logo_fill": 0.78, "emission": 0.12}),
			TrackScenery.brand_material(WORDMARK_DARK, TrackScenery.NAVY, aspect, {"logo_fill": 0.5, "border_width": 0.06, "border_color": TrackScenery.YELLOW, "emission": 0.1}))
	# Cabos em leque para os dois lados.
	var spacing := 9.0 / _step
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		for dir: float in [-1.0, 1.0]:
			for k in range(1, 9):
				var fi := mid + dir * (k * spacing + 3.0 / _step)
				if fi < from + 1 or fi > to - 1:
					break
				var anchor := _pos(fi, side * (_outer - 0.15), track.wall_height + 0.1)
				var top := tops[s] + Vector3.UP * (-k * 1.1)
				_cable(thin, top, anchor, 0.09, _mat("cable"))


# --- Ponte em arco de aço ----------------------------------------------------------------

func _build_arch(node: Node3D, solid: Batch, thin: Batch, from: int, to: int) -> void:
	var total := (to - from) * _step
	var rise := clampf(total * 0.17, 11.0, 19.0)
	var lat := _outer + 0.8
	var segments := 30
	for side: float in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for k in segments + 1:
			var u := float(k) / segments
			var fi := lerpf(from + 1, to - 1, u)
			var h := 0.4 + rise * 4.0 * u * (1.0 - u)
			var p := _pos(fi, side * lat, h)
			if k > 0:
				_beam(solid, prev, p, 1.25, 1.5, _mat("steel"))
				if k < segments and k % 2 == 0:
					_beam(thin, p, _pos(fi, side * lat, 0.0), 0.16, 0.16, _mat("cable"))
			prev = p
	# Base do arco (pé de concreto em cada canto).
	for fi: float in [float(from + 1), float(to - 1)]:
		for side: float in [-1.0, 1.0]:
			var box := BoxMesh.new()
			box.size = Vector3(2.0, 2.2, 3.0)
			var p := _pos(fi, side * lat, 0.4)
			solid.add(box, Transform3D(_track_basis(fi), p), _mat("pier"))
	# Travessas entre os dois arcos (bem acima da pista).
	for u: float in [0.3, 0.4, 0.5, 0.6, 0.7]:
		var fi := lerpf(from + 1, to - 1, u)
		var h := 0.4 + rise * 4.0 * u * (1.0 - u)
		if h < 9.0:
			continue
		_beam(solid, _pos(fi, -lat, h + 0.3), _pos(fi, lat, h + 0.3), 0.8, 0.9, _mat("steel"))
	# Placa com a marca pendurada no alto, no meio do arco.
	var mid := lerpf(from + 1, to - 1, 0.5)
	var size := Vector2(lat * 2.0 - 4.5, 3.3)
	var center := _pos(mid, 0.0, rise + 0.4 - 2.6)
	var basis := _track_basis(mid)
	var board := BoxMesh.new()
	board.size = Vector3(size.x + 0.35, size.y + 0.35, 0.7)
	solid.add(board, Transform3D(basis, center), _mat("steel"))
	var aspect := size.x / size.y
	_sign(node, center, basis, size,
			TrackScenery.brand_material(WORDMARK_DARK, TrackScenery.NAVY, aspect, {"logo_fill": 0.62, "border_width": 0.07, "border_color": TrackScenery.YELLOW, "emission": 0.1}),
			TrackScenery.brand_material(LOGO_ICON, TrackScenery.YELLOW, aspect, {"logo_fill": 0.8, "logo_count": 3, "emission": 0.08}))


# --- Viaduto de arcos de pedra ---------------------------------------------------------

func _build_viaduct(node: Node3D, solid: Batch, from: int, to: int) -> void:
	var stone := _mat("stone")
	var lip := _outer + LIP
	var total := (to - from) * _step
	var bays := maxi(2, int(round(total / 17.0)))
	var pier_half := 1.7 / _step
	var piers: Array[float] = []
	for k in bays + 1:
		piers.append(lerpf(from, to, float(k) / bays))
	# Pilares de pedra (os das pontas ficam nas cabeceiras).
	for k in range(1, bays):
		var fi := piers[k]
		var road_y := _pos(fi, 0.0, 0.0).y
		var top := road_y - DECK_THICKNESS
		var bottom := _ground_under(fi) - 2.0
		if top - bottom < 0.5:
			continue
		var box := BoxMesh.new()
		box.size = Vector3(lip * 2.0 + 0.6, top - bottom, 3.4)
		var c := _pos(fi, 0.0, 0.0)
		solid.add(box, Transform3D(_track_basis(fi), Vector3(c.x, (top + bottom) * 0.5, c.z)), stone)
		# Medalhão com o logo "at" nos dois lados do pilar.
		for side: float in [-1.0, 1.0]:
			var quad := QuadMesh.new()
			quad.size = Vector2(2.6, 2.6)
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = TrackScenery.brand_material(LOGO_ICON, TrackScenery.BRAND_BLUE, 1.0,
					{"recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW, "logo_fill": 0.55, "border_width": 0.06, "border_color": Color.WHITE})
			var p := _pos(fi, side * (lip + 0.32), -DECK_THICKNESS - 1.7)
			mi.transform = Transform3D(TrackScenery._panel_basis(track.rights[int(fi)] * side), p)
			node.add_child(mi)
	# Arcos entre os pilares: parede lateral acima do arco e o teto curvo do arco.
	var md := Track.MeshData.new()
	for k in bays:
		var fa := piers[k] + (pier_half if k > 0 else 1.5 / _step)
		var fb := piers[k + 1] - (pier_half if k < bays - 1 else 1.5 / _step)
		var radius := (fb - fa) * _step * 0.5
		if radius < 1.5:
			continue
		var crown := -DECK_THICKNESS - 0.9
		var spring := crown - radius
		var steps := 16
		for side: float in [-1.0, 1.0]:
			var base := md.verts.size()
			for s in steps + 1:
				var u := float(s) / steps
				var fi := lerpf(fa, fb, u)
				var x := (u - 0.5) * 2.0
				var y := spring + radius * sqrt(maxf(0.0, 1.0 - x * x))
				var n := track.rights[int(fi)] * side
				md.add_vertex(_pos(fi, side * lip, y), n, Vector2(u, 0))
				md.add_vertex(_pos(fi, side * lip, -DECK_THICKNESS), n, Vector2(u, 1))
			for s in steps:
				var v := base + s * 2
				md.add_tri(v, v + 1, v + 2, md.normals[v])
				md.add_tri(v + 1, v + 3, v + 2, md.normals[v])
		# Teto do arco (de um lado ao outro), virado para dentro do arco.
		var base2 := md.verts.size()
		for s in steps + 1:
			var u := float(s) / steps
			var fi := lerpf(fa, fb, u)
			var x := (u - 0.5) * 2.0
			var y := spring + radius * sqrt(maxf(0.0, 1.0 - x * x))
			var t := _tangent(fi)
			var n := (-t * x - Vector3.UP * sqrt(maxf(0.0, 1.0 - x * x))).normalized()
			md.add_vertex(_pos(fi, -lip, y), n, Vector2(u, 0))
			md.add_vertex(_pos(fi, lip, y), n, Vector2(u, 1))
		for s in steps:
			var v := base2 + s * 2
			md.add_tri(v, v + 1, v + 2, md.normals[v])
			md.add_tri(v + 1, v + 3, v + 2, md.normals[v])
	var arches := MeshInstance3D.new()
	arches.name = "Arcos"
	arches.mesh = md.to_mesh(stone)
	node.add_child(arches)


# --- Passarela de madeira (praia) --------------------------------------------------------

## Píer de tábuas: tabuleiro de tábuas (o mesmo desenho do piso da pista, que continua
## por cima), testeira de madeira, vigas atravessadas, fileiras de estacas descendo até o
## fundo com mãos-francesas em "X" e lampiões nos dois lados.
func _build_boardwalk(node: Node3D, from: int, to: int) -> void:
	var count := track.samples.size()
	var i0 := maxi(from - 1, 0)
	var i1 := mini(to, count - 1)
	var lip := _outer + LIP
	var deck_top := -0.05
	var deck_bottom := -0.42
	var body := Track.MeshData.new()
	_strip(body, i0, i1, Vector2(-lip, deck_top), Vector2(lip, deck_top), Vector2(0, 1))
	var under := Track.MeshData.new()
	_strip(under, i0, i1, Vector2(-lip, deck_bottom), Vector2(lip, deck_bottom), Vector2(0, -1))
	for side: float in [-1.0, 1.0]:
		_strip(under, i0, i1, Vector2(side * lip, deck_top), Vector2(side * lip, deck_bottom), Vector2(side, 0))
	var planks := ShaderMaterial.new()
	planks.shader = BEACH_ROAD_SHADER
	planks.set_shader_parameter("noise_tex", Track.NOISE_TEXTURE)
	planks.set_shader_parameter("all_planks", true)
	planks.set_shader_parameter("road_width", lip * 2.0)
	planks.set_shader_parameter("track_length", track.length)
	var deck := MeshInstance3D.new()
	deck.name = "Tabuas"
	deck.mesh = body.to_mesh(planks)
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(deck)
	var side_mi := MeshInstance3D.new()
	side_mi.name = "Testeira"
	side_mi.mesh = under.to_mesh(_mat("wood_dark"))
	node.add_child(side_mi)

	var solid := Batch.new()
	var thin := Batch.new()
	# Vigas atravessadas embaixo do tabuleiro e fileiras de estacas.
	var total := (i1 - i0) * _step
	var rows := maxi(2, int(round(total / 5.6)))
	var lats: Array[float] = [-lip + 0.5, -lip * 0.45, lip * 0.45, lip - 0.5]
	var prev: Array[Vector3] = []
	for k in rows + 1:
		var fi := lerpf(i0, i1, float(k) / rows)
		var c := _pos(fi, 0.0, 0.0)
		var basis := _track_basis(fi)
		var beam := BoxMesh.new()
		beam.size = Vector3(lip * 2.0 - 0.2, 0.32, 0.36)
		solid.add(beam, Transform3D(basis, c + Vector3.UP * (deck_bottom - 0.16)), _mat("wood_dark"))
		var tops: Array[Vector3] = []
		for lat in lats:
			var top := _pos(fi, lat, deck_bottom - 0.3)
			var floor_y := terrain.height_at(top.x, top.z)
			var bottom := minf(floor_y - 0.8, track.water_level - 1.0)
			var h := top.y - bottom
			if h < 0.3:
				tops.append(Vector3.INF)
				continue
			var pile := CylinderMesh.new()
			pile.top_radius = 0.2
			pile.bottom_radius = 0.24
			pile.height = h
			pile.radial_segments = 8
			pile.rings = 1
			solid.add(pile, Transform3D(Basis(Vector3.UP, fi), Vector3(top.x, bottom + h * 0.5, top.z)), _mat("wood"))
			tops.append(top)
		# Mão-francesa em "X" entre as estacas de fora e as do meio, nas fileiras pares.
		if k % 2 == 0:
			for pair: Vector2i in [Vector2i(0, 1), Vector2i(2, 3)]:
				var a := tops[pair.x]
				var b := tops[pair.y]
				if a == Vector3.INF or b == Vector3.INF:
					continue
				var low := maxf(track.water_level + 0.3, maxf(a.y, b.y) - 3.2)
				if a.y - low < 1.0:
					continue
				_beam(thin, a, Vector3(b.x, low, b.z), 0.12, 0.16, _mat("wood_dark"))
				_beam(thin, b, Vector3(a.x, low, a.z), 0.12, 0.16, _mat("wood_dark"))
		# Longarinas ligando a fileira anterior a esta (embaixo das tábuas).
		if not prev.is_empty():
			for li in lats.size():
				var a := prev[li]
				var b := _pos(fi, lats[li], deck_bottom - 0.12)
				_beam(solid, a, b, 0.22, 0.24, _mat("wood_dark"))
		prev.clear()
		for lat in lats:
			prev.append(_pos(fi, lat, deck_bottom - 0.12))
	# Lampiões dos dois lados, alternados, a cada ~26 m (pouco para fora da cerca).
	var lamps := maxi(1, int(total / 26.0))
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.11
	post.height = 3.4
	post.radial_segments = 8
	var arm := BoxMesh.new()
	arm.size = Vector3(0.08, 0.08, 0.7)
	var lantern := CylinderMesh.new()
	lantern.top_radius = 0.16
	lantern.bottom_radius = 0.2
	lantern.height = 0.42
	lantern.radial_segments = 6
	var cap := CylinderMesh.new()
	cap.top_radius = 0.02
	cap.bottom_radius = 0.26
	cap.height = 0.2
	cap.radial_segments = 6
	for k in lamps:
		var fi := lerpf(i0, i1, (k + 0.5) / lamps)
		var side := 1.0 if k % 2 == 0 else -1.0
		var base := _pos(fi, side * (lip - 0.25), deck_top)
		var inward := -track.rights[clampi(int(fi), 0, count - 1)] * side
		solid.add(post, Transform3D(Basis(), base + Vector3.UP * 1.7), _mat("wood_dark"))
		var arm_end := base + Vector3.UP * 3.25 + inward * 0.55
		_beam(solid, base + Vector3.UP * 3.25, arm_end, 0.08, 0.08, _mat("wood_dark"))
		solid.add(lantern, Transform3D(Basis(), arm_end + Vector3.DOWN * 0.3), _mat("lantern"))
		solid.add(cap, Transform3D(Basis(), arm_end + Vector3.DOWN * 0.02), _mat("wood_dark"))
	solid.commit(node, "Estrutura")
	thin.commit(node, "Escoras", false)
