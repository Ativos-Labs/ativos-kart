@tool
class_name TrackStadium
extends RefCounted
## Estádio (Track.stadium_track), sempre com a marca da Ativos:
## - anel de arquibancadas lotadas (retângulo arredondado em volta de
##   Track.stadium_center) com 12 filas de degraus, a torcida pintada nos degraus
##   (shaders/stadium_crowd.gdshader), mureta com placas de propaganda e cobertura azul
##   com a marca na beirada; onde a pista cruza o anel as filas de baixo somem e ela
##   passa num túnel por baixo das de cima, com o letreiro "ESTÁDIO CELERINO";
## - quatro torres de luz nos cantos, o telão de LED atrás da arquibancada lá no fim da
##   reta da largada e bandeiras na beirada da cobertura;
## - no miolo: o prédio dos boxes com a torre de controle ao lado da reta, o pódio depois
##   da chegada e o Celerino gigante num pedestal, com o gesto dele de tempos em tempos;
## - pórtico de largada de treliça com placar e luzes de largada.

const CROWD_SHADER := preload("res://shaders/stadium_crowd.gdshader")
const SCREEN_SHADER := preload("res://shaders/telao.gdshader")
const FONT := preload("res://assets/fonts/LilitaOne-Regular.woff2")
const CELERINO := "res://data/personagens/celerino.tres"

## Formato do anel (expoente do retângulo arredondado: 2 = elipse) e distância entre os
## pontos dele (m).
const RING_POWER := 4.0
const RING_SPACING := 2.0
## Perfil da arquibancada (m; u = para fora a partir da linha do anel, v = altura):
## mureta, filas (piso × espelho), parede de trás e fachada.
const FRONT_H := 2.4
const WALL_U := 0.4
const ROWS := 12
const TREAD := 1.6
const RISER := 0.9
const BACK_U := WALL_U + ROWS * TREAD
const TOP_H := FRONT_H + ROWS * RISER + 1.2
const OUT_U := BACK_U + 0.6
## Altura do teto do túnel (embaixo das filas de cima, em cima da pista).
const PORTAL_CEIL := 6.6
## Cobertura: de `ROOF_IN` até `ROOF_OUT` (u), caindo um pouco para trás.
const ROOF_IN := 5.5
const ROOF_OUT := OUT_U + 1.6
const ROOF_FRONT_Y := 21.0
const ROOF_BACK_Y := 19.6
const ROOF_THICK := 0.5
const COLUMN_SPACING := 18.0
## Comprimento das placas da mureta e das faixas da cobertura (m).
const PANEL_LEN := 8.0
const FASCIA_LEN := 16.0
const CHUNK := 120.0
## Celerino gigante (o modelo tem 2 m) e intervalo entre os gestos (s).
const MASCOT_SCALE := 6.5
const MASCOT_GESTURE_EVERY := 11.0

const CONCRETE := Color(0.74, 0.75, 0.78)
const CONCRETE_DARK := Color(0.3, 0.31, 0.38)
const FACADE := Color(0.88, 0.89, 0.91)
## Forro escuro e azulado: a luz que volta do gramado deixava o forro claro verde.
const ROOF_UNDER := Color(0.2, 0.23, 0.36)
## Telhado num azul mais fundo que o da marca (de cima, o azul da marca desbota).
const ROOF_TOP := Color(0.08, 0.15, 0.52)
const STEEL := Color(0.8, 0.82, 0.86)
const DOOR := Color(0.12, 0.14, 0.2)

var track: Track
var terrain: TrackTerrain
var root: Node3D
var rng := RandomNumberGenerator.new()
## Lugares ocupados (x, z, raio) do TrackScenery.
var reserved: Array[Vector3] = []

var _mats := {}
## Anel: pontos (x, z), normal para fora, altura do chão, metros desde o ponto 0 e
## pontos em cima da pista (túnel).
var _ring := PackedVector2Array()
var _normals := PackedVector2Array()
var _ground := PackedFloat32Array()
var _arc := PackedFloat32Array()
var _portal := PackedByteArray()
var _ring_length := 0.0
## Lado do miolo na largada (+1 = direita) e onde ficaram o telão e os boxes.
var _infield_side := 1.0
var _screen_at := Vector2.INF
var _pits_at := Vector2.INF
var _podium_at := Vector2.INF
## Paleta (de dia as constantes acima; na cidade neon, à noite, tudo mais escuro, com o
## acabamento de neon por cima) e a cor dos frisos das arquibancadas.
var _night := false
var _concrete := CONCRETE
var _concrete_dark := CONCRETE_DARK
var _facade := FACADE
var _roof_under := ROOF_UNDER
var _roof_top := ROOF_TOP
var _steel := STEEL
var _door := DOOR
var _trim := TrackScenery.BRAND_BLUE


func _init(p_track: Track, p_terrain: TrackTerrain, p_root: Node3D) -> void:
	track = p_track
	terrain = p_terrain
	root = p_root
	rng.seed = track.decoration_seed * 6151 + 29
	_night = track.city_track
	if _night:
		_concrete = Color(0.16, 0.17, 0.22)
		_concrete_dark = Color(0.09, 0.09, 0.13)
		_facade = Color(0.12, 0.12, 0.17)
		_roof_under = Color(0.07, 0.07, 0.12)
		_roof_top = Color(0.06, 0.06, 0.14)
		_steel = Color(0.22, 0.23, 0.28)
		_door = Color(0.05, 0.06, 0.1)
		_trim = Color(0.14, 0.1, 0.35)
	var p0 := track.get_point_at(0.0)
	var to_center := Vector3(track.stadium_center.x - p0.x, 0.0, track.stadium_center.y - p0.z)
	if not track.rights.is_empty():
		_infield_side = 1.0 if track.rights[0].dot(to_center) >= 0.0 else -1.0


# --- Anel ------------------------------------------------------------------------------

## Pontos do anel (x, z) a cada `spacing` m.
static func ring_points(p_track: Track, spacing := RING_SPACING) -> PackedVector2Array:
	var c := p_track.stadium_center
	var r := p_track.stadium_radii
	var n := 1440
	var e := 2.0 / RING_POWER
	var dense := PackedVector2Array()
	dense.resize(n)
	for k in n:
		var a := TAU * k / n
		var ca := cos(a)
		var sa := sin(a)
		dense[k] = c + Vector2(r.x * signf(ca) * pow(absf(ca), e), r.y * signf(sa) * pow(absf(sa), e))
	var cum := PackedFloat32Array()
	cum.resize(n + 1)
	for k in n:
		cum[k + 1] = cum[k] + dense[k].distance_to(dense[(k + 1) % n])
	var total := cum[n]
	var count := maxi(16, roundi(total / spacing))
	var out := PackedVector2Array()
	out.resize(count)
	var j := 0
	for m in count:
		var s := total * m / count
		while j < n - 1 and cum[j + 1] < s:
			j += 1
		var t := (s - cum[j]) / maxf(cum[j + 1] - cum[j], 0.0001)
		out[m] = dense[j].lerp(dense[(j + 1) % n], t)
	return out


## Ponto (x, z) dentro do anel do estádio, com o anel `margin` m maior (negativo = menor).
static func inside(p_track: Track, x: float, z: float, margin := 0.0) -> bool:
	var r := p_track.stadium_radii + Vector2(margin, margin)
	if r.x <= 0.0 or r.y <= 0.0:
		return false
	var dx := absf(x - p_track.stadium_center.x) / r.x
	var dz := absf(z - p_track.stadium_center.y) / r.y
	return pow(dx, RING_POWER) + pow(dz, RING_POWER) < 1.0


func _setup_ring() -> void:
	_ring = ring_points(track)
	var n := _ring.size()
	_normals.resize(n)
	_ground.resize(n)
	_arc.resize(n)
	_portal.resize(n)
	var c := track.stadium_center
	var acc := 0.0
	for i in n:
		var t := (_ring[(i + 1) % n] - _ring[(i - 1 + n) % n]).normalized()
		var nn := Vector2(t.y, -t.x)
		if nn.dot(_ring[i] - c) < 0.0:
			nn = -nn
		_normals[i] = nn
		_ground[i] = terrain.height_at(_ring[i].x, _ring[i].y) - 0.05
		_arc[i] = acc
		acc += _ring[i].distance_to(_ring[(i + 1) % n])
	_ring_length = acc
	# Túnel: onde alguma parte do perfil fica em cima da pista (com folga além da mureta).
	var clearance := track.road_width * 0.5 + track.shoulder_width + track.wall_thickness + 1.5
	var raw := PackedByteArray()
	raw.resize(n)
	for i in n:
		var u := 0.0
		while u <= OUT_U + 0.01:
			var q := _ring[i] + _normals[i] * u
			if terrain.distance_to_track(q.x, q.y) < clearance:
				raw[i] = 1
				break
			u += 2.0
	for i in n:
		_portal[i] = 1 if raw[i] == 1 or raw[(i + 1) % n] == 1 or raw[(i - 1 + n) % n] == 1 else 0


## Ponto do perfil (u para fora, v de altura) no ponto `i` do anel.
func _at(i: int, p: Vector2) -> Vector3:
	var r := _ring[i]
	var nn := _normals[i]
	return Vector3(r.x + nn.x * p.x, _ground[i] + p.y, r.y + nn.y * p.x)


func _n3(i: int) -> Vector3:
	return Vector3(_normals[i].x, 0.0, _normals[i].y)


func _tangent3(i: int) -> Vector3:
	var n := _ring.size()
	var t := _ring[(i + 1) % n] - _ring[(i - 1 + n) % n]
	return Vector3(t.x, 0.0, t.y).normalized()


func _ring_basis(i: int) -> Basis:
	return TrackScenery._panel_basis(-_n3(i))


static func _chunk_key(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))


static func _group(groups: Dictionary, key: Vector2i) -> Track.MeshData:
	if not groups.has(key):
		groups[key] = Track.MeshData.new()
	return groups[key]


# --- Materiais e malhas ------------------------------------------------------------------

func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"tint":
			var t := StandardMaterial3D.new()
			t.vertex_color_use_as_albedo = true
			t.vertex_color_is_srgb = true
			t.roughness = 0.85
			m = t
		"crowd":
			var s := ShaderMaterial.new()
			s.shader = CROWD_SHADER
			s.set_shader_parameter("night", 1.0 if _night else 0.0)
			m = s
		"lamp":
			var l := StandardMaterial3D.new()
			l.albedo_color = Color(1.0, 0.98, 0.9)
			l.emission_enabled = true
			l.emission = Color(1.0, 0.96, 0.84)
			l.emission_energy_multiplier = 5.0 if _night else 2.2
			m = l
		"red_lamp":
			var rl := StandardMaterial3D.new()
			rl.albedo_color = Color(0.9, 0.08, 0.06)
			rl.emission_enabled = true
			rl.emission = Color(1.0, 0.12, 0.08)
			rl.emission_energy_multiplier = 3.0
			m = rl
		"glass":
			var g := StandardMaterial3D.new()
			g.albedo_color = Color(0.1, 0.2, 0.36)
			if _night:
				# Vidro da torre aceso por dentro.
				g.emission_enabled = true
				g.emission = Color(0.2, 0.55, 1.0)
				g.emission_energy_multiplier = 0.8
			g.metallic = 0.6
			g.roughness = 0.12
			m = g
	_mats[key] = m
	return m


static func _mi(mesh: Mesh, xform := Transform3D.IDENTITY, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _node(name: String, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	(parent if parent else root).add_child(n)
	return n


## Quadrilátero a, b, c, d (em ordem) virado para `facing`, com cor (alfa 0 = sem cor).
static func _quad(md: Track.MeshData, p: Array, normals: Array, uvs: Array, facing: Vector3, col := Color(0, 0, 0, 0)) -> void:
	var ids := PackedInt32Array()
	for k in 4:
		ids.append(md.add_vertex(p[k], normals[k], uvs[k]))
		if col.a > 0.0:
			md.colors.append(col)
	md.add_tri(ids[0], ids[1], ids[2], facing)
	md.add_tri(ids[0], ids[2], ids[3], facing)


## Viga de seção retangular (largura `w`, altura `h`) de `a` até `b`, com as pontas.
static func _beam_md(md: Track.MeshData, a: Vector3, b: Vector3, w: float, h: float, col: Color) -> void:
	var d := (b - a).normalized()
	var ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var side := d.cross(ref).normalized() * w * 0.5
	var up := side.normalized().cross(d).normalized() * h * 0.5
	var corners := [-side - up, side - up, side + up, -side + up]
	for k in 4:
		var c0: Vector3 = corners[k]
		var c1: Vector3 = corners[(k + 1) % 4]
		var nrm := (c0 + c1).normalized()
		_quad(md, [a + c0, b + c0, b + c1, a + c1], [nrm, nrm, nrm, nrm], [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN], nrm, col)
	for end: Array in [[a, -d], [b, d]]:
		var o: Vector3 = end[0]
		var nrm: Vector3 = end[1]
		_quad(md, [o + corners[0], o + corners[1], o + corners[2], o + corners[3]], [nrm, nrm, nrm, nrm],
				[Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN], nrm, col)


## Tubo de `a` até `b` (peça para MeshMerge/TrackBeach.parts_mesh).
static func _tube(a: Vector3, b: Vector3, radius: float, color: Color, segments := 6) -> Array:
	var y := b - a
	var length := y.length()
	y /= maxf(length, 0.0001)
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return [TrackProps._cyl(radius, radius, length, segments), Transform3D(Basis(x, y, z), (a + b) * 0.5), color]


static func _label(text: String, size_m: float, color: Color, outline: Color, outline_px := 18) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 128
	l.pixel_size = size_m / 128.0
	l.modulate = color
	l.outline_modulate = outline
	l.outline_size = outline_px if outline.a > 0.0 else 0
	l.double_sided = false
	l.shaded = true
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


# --- Montagem ----------------------------------------------------------------------------

## Arquibancadas, cobertura, torres, telão, boxes, pódio, Celerino e bandeiras.
## `p_reserved` é a lista de lugares ocupados do TrackScenery.
func build_landmarks(p_reserved: Array[Vector3], preview: bool) -> void:
	reserved = p_reserved
	if track.stadium_radii.x <= 0.0 or track.stadium_radii.y <= 0.0:
		return
	_setup_ring()
	var node := _node("Estadio")
	_build_stands(node)
	_build_ad_boards(node)
	_build_fascia(node)
	_build_portals(node)
	_build_screen(node)
	_build_light_towers(node)
	_build_pits(node)
	_build_tents(node)
	_build_podium(node)
	_build_mascot(node, preview)
	_build_ring_flags(node)
	if _night:
		_build_neon_trims(node)
		# Letreiros acesos (sem sombra da cena por cima).
		for label in node.find_children("*", "Label3D", true, false):
			(label as Label3D).shaded = false


## Bordas do perfil: [a, b, normal (u, v), tipo, cor ou fila]. Tipo 0 = concreto/cor,
## 1 = espelho de degrau com torcida, 2 = piso de degrau com torcida. No túnel o perfil
## começa em PORTAL_CEIL (só as filas de cima, com o teto embaixo).
func _profile(portal: bool) -> Array:
	var e := []
	var k0 := 0
	if portal:
		while FRONT_H + k0 * RISER < PORTAL_CEIL + 0.25:
			k0 += 1
		var u0 := WALL_U + k0 * TREAD
		e.append([Vector2(u0, PORTAL_CEIL), Vector2(u0, FRONT_H + k0 * RISER), Vector2(-1, 0), 0, _trim])
		e.append([Vector2(u0, PORTAL_CEIL), Vector2(OUT_U, PORTAL_CEIL), Vector2(0, -1), 0, _concrete_dark])
	else:
		e.append([Vector2(0, 0), Vector2(0, FRONT_H), Vector2(-1, 0), 0, _concrete])
		e.append([Vector2(0, FRONT_H), Vector2(WALL_U, FRONT_H), Vector2(0, 1), 0, _trim])
	for k in range(k0, ROWS):
		var u0 := WALL_U + k * TREAD
		var v := FRONT_H + k * RISER
		e.append([Vector2(u0, v), Vector2(u0 + TREAD, v), Vector2(0, 1), 2, float(k)])
		e.append([Vector2(u0 + TREAD, v), Vector2(u0 + TREAD, v + RISER), Vector2(-1, 0), 1, float(k)])
	var top_row := FRONT_H + ROWS * RISER
	e.append([Vector2(BACK_U, top_row), Vector2(BACK_U, TOP_H), Vector2(-1, 0), 0, _concrete])
	e.append([Vector2(BACK_U, TOP_H), Vector2(OUT_U, TOP_H), Vector2(0, 1), 0, _trim])
	e.append([Vector2(OUT_U, TOP_H), Vector2(OUT_U, TOP_H - 1.4), Vector2(1, 0), 0, _trim])
	e.append([Vector2(OUT_U, TOP_H - 1.4), Vector2(OUT_U, PORTAL_CEIL if portal else 0.0), Vector2(1, 0), 0, _facade])
	return e


## Cobertura: telhado azul por cima, forro claro, viga da frente (com as faixas da marca)
## e a beirada de trás.
func _roof_profile() -> Array:
	var du := ROOF_OUT - ROOF_IN
	var dv := ROOF_BACK_Y - ROOF_FRONT_Y
	var up := Vector2(-dv, du).normalized()
	var beam_u := ROOF_IN + 0.8
	var beam_v := ROOF_FRONT_Y - 1.9
	return [
		[Vector2(ROOF_IN, ROOF_FRONT_Y + ROOF_THICK), Vector2(ROOF_OUT, ROOF_BACK_Y + ROOF_THICK), up, 0, _roof_top],
		[Vector2(beam_u, ROOF_FRONT_Y - 0.05), Vector2(ROOF_OUT, ROOF_BACK_Y), -up, 0, _roof_under],
		[Vector2(ROOF_IN, beam_v), Vector2(ROOF_IN, ROOF_FRONT_Y + ROOF_THICK), Vector2(-1, 0), 0, TrackScenery.NAVY],
		[Vector2(ROOF_IN, beam_v), Vector2(beam_u, beam_v), Vector2(0, -1), 0, TrackScenery.NAVY],
		[Vector2(beam_u, beam_v), Vector2(beam_u, ROOF_FRONT_Y), Vector2(1, 0), 0, TrackScenery.NAVY],
		[Vector2(ROOF_OUT, ROOF_BACK_Y), Vector2(ROOF_OUT, ROOF_BACK_Y + ROOF_THICK), Vector2(1, 0), 0, _roof_top],
	]


## Estica as bordas do `profile` entre os pontos `i` e `i + 1` do anel.
func _extrude(md_tint: Track.MeshData, md_crowd: Track.MeshData, i: int, profile: Array) -> void:
	var j := (i + 1) % _ring.size()
	var s0 := _arc[i]
	var s1 := s0 + _ring[i].distance_to(_ring[j])
	var ni := _n3(i)
	var nj := _n3(j)
	for edge: Array in profile:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var nrm: Vector2 = edge[2]
		var kind: int = edge[3]
		var n0 := (ni * nrm.x + Vector3.UP * nrm.y).normalized()
		var n1 := (nj * nrm.x + Vector3.UP * nrm.y).normalized()
		var pts := [_at(i, a), _at(j, a), _at(j, b), _at(i, b)]
		var normals := [n0, n1, n1, n0]
		if kind == 0:
			_quad(md_tint, pts, normals, [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN], (n0 + n1) * 0.5, edge[4])
		else:
			var row: float = edge[4]
			var y0 := row + 0.001
			var y1 := row + 0.999
			if kind == 2:
				y0 = -y0 - 1.0
				y1 = -y1 - 1.0
			_quad(md_crowd, pts, normals, [Vector2(s0, y0), Vector2(s1, y0), Vector2(s1, y1), Vector2(s0, y1)], (n0 + n1) * 0.5)


## Fecha o perfil inteiro da arquibancada no ponto `i` (beira do túnel), virado para `toward`.
func _cap(md: Track.MeshData, i: int, toward: Vector3) -> void:
	var strips := [[0.0, WALL_U, FRONT_H]]
	for k in ROWS:
		var u0 := WALL_U + k * TREAD
		strips.append([u0, u0 + TREAD, FRONT_H + k * RISER])
	strips.append([BACK_U, OUT_U, TOP_H])
	var nrm := [toward, toward, toward, toward]
	var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	for st: Array in strips:
		_quad(md, [_at(i, Vector2(st[0], 0.0)), _at(i, Vector2(st[1], 0.0)), _at(i, Vector2(st[1], st[2])), _at(i, Vector2(st[0], st[2]))],
				nrm, uvs, toward, _concrete)


func _build_stands(parent: Node3D) -> void:
	var tint_groups := {}
	var crowd_groups := {}
	var stand := _profile(false)
	var portal := _profile(true)
	var roof := _roof_profile()
	var n := _ring.size()
	var next_column := 0.0
	for i in n:
		var j := (i + 1) % n
		var key := _chunk_key(_at(i, Vector2.ZERO))
		var md_t := _group(tint_groups, key)
		var md_c := _group(crowd_groups, key)
		var over_track := _portal[i] == 1 or _portal[j] == 1
		_extrude(md_t, md_c, i, portal if over_track else stand)
		_extrude(md_t, md_c, i, roof)
		if over_track and _portal[i] == 0:
			_cap(md_t, i, _tangent3(i))
		if over_track and _portal[j] == 0:
			_cap(md_t, j, -_tangent3(j))
		# Colunas atrás da fachada, com o tirante até a frente da cobertura.
		if _arc[i] >= next_column and not over_track:
			next_column = _arc[i] + COLUMN_SPACING
			var cu := OUT_U + 0.9
			var roof_y := lerpf(ROOF_FRONT_Y, ROOF_BACK_Y, (cu - ROOF_IN) / (ROOF_OUT - ROOF_IN))
			_beam_md(md_t, _at(i, Vector2(cu, 0.0)), _at(i, Vector2(cu, roof_y)), 0.9, 0.9, _steel)
			_beam_md(md_t, _at(i, Vector2(cu, TOP_H + 1.2)), _at(i, Vector2(ROOF_IN + 3.0, ROOF_FRONT_Y - 0.15)), 0.35, 0.5, _steel)
	for key: Vector2i in tint_groups:
		var md: Track.MeshData = tint_groups[key]
		if not md.indices.is_empty():
			var mi := _mi(md.to_mesh(_mat("tint")))
			mi.name = "Arquibancada"
			parent.add_child(mi)
	for key: Vector2i in crowd_groups:
		var md: Track.MeshData = crowd_groups[key]
		if not md.indices.is_empty():
			var mi := _mi(md.to_mesh(_mat("crowd")))
			mi.name = "Torcida"
			parent.add_child(mi)


## Materiais das placas (`aspect` = largura/altura).
func _brand_variants(aspect: float) -> Array[ShaderMaterial]:
	var list := _brand_variants_day(aspect)
	if _night:
		for m in list:
			m.set_shader_parameter("emission", 0.85)
	return list


func _brand_variants_day(aspect: float) -> Array[ShaderMaterial]:
	return [
		TrackScenery.brand_material(TrackScenery.WORDMARK_DARK, TrackScenery.BRAND_BLUE, aspect,
				{"logo_fill": 0.62, "border_width": 0.06, "border_color": TrackScenery.YELLOW, "emission": 0.12}),
		TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.NAVY, aspect,
				{"recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW, "logo_fill": 0.74, "logo_count": 3, "emission": 0.1}),
		TrackScenery.brand_material(TrackScenery.WORDMARK, Color.WHITE, aspect,
				{"logo_fill": 0.6, "border_width": 0.06, "border_color": TrackScenery.BRAND_BLUE}),
		TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.YELLOW, aspect, {"logo_fill": 0.74, "logo_count": 3}),
	]


## Placas retas de `length` m de `u` (para fora) entre `y0` e `y1`, viradas para dentro do
## estádio, nos trechos sem túnel: uma malha por material (poucas chamadas de desenho).
func _ring_panels(parent: Node3D, name: String, length: float, u: float, y0: float, y1: float, materials: Array[ShaderMaterial]) -> void:
	var mds: Array[Track.MeshData] = []
	for m in materials:
		mds.append(Track.MeshData.new())
	var n := _ring.size()
	var per := maxi(1, roundi(length / RING_SPACING))
	var count := 0
	var i := 0
	while i + per <= n:
		var j := (i + per) % n
		var ok := true
		for k in range(i, i + per + 1):
			if _portal[k % n] == 1:
				ok = false
				break
		if ok:
			var nrm := (_normals[i] + _normals[j]).normalized()
			var inward := Vector3(-nrm.x, 0.0, -nrm.y)
			var pa := _at(i, Vector2(u, 0.0))
			var pb := _at(j, Vector2(u, 0.0))
			var g := minf(_ground[i], _ground[j])
			pa.y = g
			pb.y = g
			# Esquerda/direita de quem olha da pista para a placa.
			var right := (-inward).cross(Vector3.UP)
			if (pb - pa).dot(right) < 0.0:
				var tmp := pa
				pa = pb
				pb = tmp
			var up0 := Vector3.UP * y0
			var up1 := Vector3.UP * y1
			_quad(mds[count % mds.size()], [pa + up1, pb + up1, pb + up0, pa + up0], [inward, inward, inward, inward],
					[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], inward)
			count += 1
		i += per
	for k in mds.size():
		if not mds[k].indices.is_empty():
			var mi := _mi(mds[k].to_mesh(materials[k]), Transform3D.IDENTITY, false)
			mi.name = name
			parent.add_child(mi)


## Propaganda na mureta (na frente da torcida, de frente para a pista).
func _build_ad_boards(parent: Node3D) -> void:
	var h := FRONT_H - 0.65
	_ring_panels(parent, "Propaganda", PANEL_LEN, -0.04, 0.35, 0.35 + h, _brand_variants(PANEL_LEN / h))


## Faixas da marca na viga da frente da cobertura.
func _build_fascia(parent: Node3D) -> void:
	var y0 := ROOF_FRONT_Y - 1.75
	var y1 := ROOF_FRONT_Y + ROOF_THICK - 0.1
	var all := _brand_variants(FASCIA_LEN / (y1 - y0))
	var mats: Array[ShaderMaterial] = [all[0], all[1]]
	# A faixa fica no alto: o piso embaixo dela não conta (só a altura do anel).
	_ring_panels(parent, "FaixaCobertura", FASCIA_LEN, ROOF_IN - 0.04, y0, y1, mats)


## Trechos seguidos do anel em cima da pista: [[primeiro, último], ...].
func _portal_runs() -> Array:
	var n := _ring.size()
	var runs := []
	var start := -1
	# Começa num ponto fora de túnel (para não cortar um trecho na emenda do anel).
	var first := 0
	while first < n and _portal[first] == 1:
		first += 1
	if first >= n:
		return runs
	for k in range(1, n + 1):
		var i := (first + k) % n
		if _portal[i] == 1 and start < 0:
			start = i
		elif _portal[i] == 0 and start >= 0:
			runs.append([start, (i - 1 + n) % n])
			start = -1
	return runs


## Túneis: viga reta na frente das filas de cima com o letreiro, letreiro na fachada de
## fora e luzes no teto. A viga vai reta de uma ponta à outra do trecho (num anel curvo
## as pontas de uma viga curva escondiam o começo e o fim do letreiro).
func _build_portals(parent: Node3D) -> void:
	var k0 := 0
	while FRONT_H + k0 * RISER < PORTAL_CEIL + 0.25:
		k0 += 1
	var front_u := WALL_U + k0 * TREAD
	var beam_u := front_u - 0.5
	var beam_bottom := PORTAL_CEIL - 1.0
	var beam_top := FRONT_H + k0 * RISER + 0.55
	var beam_h := beam_top - beam_bottom
	var beam_depth := 0.8
	var lamps := []
	var lu := front_u + 1.6
	while lu < OUT_U - 0.8:
		lamps.append([Vector2(lu, PORTAL_CEIL - 0.06), Vector2(lu + 0.5, PORTAL_CEIL - 0.06), Vector2(0, -1), 0, Color.WHITE])
		lu += 3.0
	var n := _ring.size()
	for run: Array in _portal_runs():
		var a: int = (run[0] - 1 + n) % n
		var b: int = (run[1] + 1) % n
		var count := (b - a + n) % n
		var tunnel := _node("Tunel", parent)
		var lamp_md := Track.MeshData.new()
		var dummy := Track.MeshData.new()
		for k in count:
			_extrude(lamp_md, dummy, (a + k) % n, lamps)
		tunnel.add_child(_mi(lamp_md.to_mesh(_mat("lamp")), Transform3D.IDENTITY, false))
		var mid_y := (beam_bottom + beam_top) * 0.5
		var pa := _at(a, Vector2(beam_u, mid_y))
		var pb := _at(b, Vector2(beam_u, mid_y))
		var md := Track.MeshData.new()
		_beam_md(md, pa, pb, beam_depth, beam_h, TrackScenery.NAVY)
		_beam_md(md, pa + Vector3.UP * (beam_h * 0.5 + 0.1), pb + Vector3.UP * (beam_h * 0.5 + 0.1), beam_depth + 0.1, 0.2, TrackScenery.YELLOW)
		tunnel.add_child(_mi(md.to_mesh(_mat("tint"))))
		if _night:
			var nm := Track.MeshData.new()
			var half_h := beam_h * 0.5
			for y: float in [-half_h - 0.05, half_h + 0.25]:
				_beam_md(nm, pa + Vector3.UP * y, pb + Vector3.UP * y, beam_depth + 0.16, 0.12, TrackCity.MAGENTA if y < 0.0 else TrackCity.CYAN)
			tunnel.add_child(_mi(nm.to_mesh(TrackCity.neon_material()), Transform3D.IDENTITY, false))
		# Frente da viga, virada para dentro do estádio.
		var along := pb - pa
		var inward := along.cross(Vector3.UP).normalized()
		var to_center := Vector3(track.stadium_center.x, 0.0, track.stadium_center.y) - pa
		if inward.dot(Vector3(to_center.x, 0.0, to_center.z)) < 0.0:
			inward = -inward
		var size := clampf(along.length() * 0.065, 1.4, 2.2)
		var inner := _label("ESTÁDIO CELERINO", size, TrackScenery.YELLOW, Color(0, 0, 0, 0))
		inner.transform = Transform3D(TrackScenery._panel_basis(inward), (pa + pb) * 0.5 + inward * (beam_depth * 0.5 + 0.03))
		tunnel.add_child(inner)
		# Na fachada de fora, para quem chega do parque.
		var mid := (a + count / 2) % n
		var outer := _label("ESTÁDIO CELERINO", size * 1.15, TrackScenery.BRAND_BLUE, Color(0, 0, 0, 0))
		outer.transform = Transform3D(TrackScenery._panel_basis(_n3(mid)), _at(mid, Vector2(OUT_U + 0.04, (TOP_H - 1.4 + PORTAL_CEIL) * 0.5)))
		tunnel.add_child(outer)


## Telão de LED atrás da arquibancada que fica em frente à reta da largada.
func _build_screen(parent: Node3D) -> void:
	var start := track.get_point_at(0.0)
	var dir := track.get_direction_at(0.0)
	var s2 := Vector2(start.x, start.z)
	var d2 := Vector2(dir.x, dir.z).normalized()
	var best := -1
	var best_off := INF
	for i in _ring.size():
		var rel := _ring[i] - s2
		var ahead := rel.dot(d2)
		if ahead < 60.0 or _portal[i] == 1:
			continue
		var off := absf(rel.cross(d2))
		if off < best_off:
			best_off = off
			best = i
	if best < 0:
		return
	var w := 28.0
	var h := w * 9.0 / 16.0
	var bottom := 24.0
	var base := _at(best, Vector2(OUT_U + 7.0, 0.0))
	var face := s2 - Vector2(base.x, base.z)
	var b := TrackScenery._panel_basis(Vector3(face.x, 0.0, face.y))
	var screen := _node("Telao", parent)
	screen.transform = Transform3D(b, base)
	_screen_at = Vector2(base.x, base.z)
	var parts := []
	parts.append([TrackProps._box(Vector3(w + 1.4, h + 1.4, 1.2)), Transform3D(Basis(), Vector3(0, bottom + h * 0.5, -0.6)), TrackScenery.NAVY])
	parts.append([TrackProps._box(Vector3(w + 1.6, 0.35, 1.4)), Transform3D(Basis(), Vector3(0, bottom - 0.6, -0.6)), TrackScenery.YELLOW])
	parts.append([TrackProps._box(Vector3(w + 1.6, 0.35, 1.4)), Transform3D(Basis(), Vector3(0, bottom + h + 0.6, -0.6)), TrackScenery.YELLOW])
	for lx: float in [-w * 0.3, w * 0.3]:
		parts.append([TrackProps._box(Vector3(1.6, bottom + h * 0.5, 1.6)), Transform3D(Basis(), Vector3(lx, (bottom + h * 0.5) * 0.5, -1.6)), _steel])
		parts.append([TrackProps._box(Vector3(3.2, 0.6, 3.2)), Transform3D(Basis(), Vector3(lx, 0.3, -1.6)), _concrete_dark])
	screen.add_child(_mi(TrackBeach.parts_mesh(parts, _mat("tint"))))
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var mat := ShaderMaterial.new()
	mat.shader = SCREEN_SHADER
	mat.set_shader_parameter("logo_a", TrackScenery.WORDMARK_DARK)
	mat.set_shader_parameter("logo_a_aspect", float(TrackScenery.WORDMARK_DARK.get_width()) / TrackScenery.WORDMARK_DARK.get_height())
	mat.set_shader_parameter("logo_b", TrackScenery.LOGO_ICON)
	mat.set_shader_parameter("logo_b_aspect", float(TrackScenery.LOGO_ICON.get_width()) / TrackScenery.LOGO_ICON.get_height())
	mat.set_shader_parameter("panel_aspect", w / h)
	quad.material = mat
	screen.add_child(_mi(quad, Transform3D(Basis(), Vector3(0, bottom + h * 0.5, 0.02)), false))


## Quatro torres de luz atrás das arquibancadas, nos cantos (desviando do telão).
func _build_light_towers(parent: Node3D) -> void:
	var parts := []
	var lamp_parts := []
	var beams: Array[Vector3] = []
	var height := 46.0
	var c := track.stadium_center
	for k in 4:
		var ang := deg_to_rad(45.0 + 90.0 * k)
		var target := c + Vector2(cos(ang) * track.stadium_radii.x, sin(ang) * track.stadium_radii.y) * 1.2
		var i := _nearest_ring(target)
		var pos := _at(i, Vector2(OUT_U + 9.0, 0.0))
		if _screen_at != Vector2.INF and Vector2(pos.x, pos.z).distance_to(_screen_at) < 48.0:
			i = (i + roundi(28.0 / RING_SPACING) * (1 if k % 2 == 0 else -1) + _ring.size()) % _ring.size()
			pos = _at(i, Vector2(OUT_U + 9.0, 0.0))
		var face := c - Vector2(pos.x, pos.z)
		var fb := TrackScenery._panel_basis(Vector3(face.x, 0.0, face.y))
		# Treliça de quatro pernas afinando para cima, com anéis e diagonais.
		var levels := 9
		var corners_at := func(t: float) -> Array:
			var half := lerpf(1.7, 0.75, t)
			var y := t * height
			return [pos + fb * Vector3(-half, 0, -half) + Vector3.UP * y, pos + fb * Vector3(half, 0, -half) + Vector3.UP * y,
					pos + fb * Vector3(half, 0, half) + Vector3.UP * y, pos + fb * Vector3(-half, 0, half) + Vector3.UP * y]
		for lv in levels:
			var lo: Array = corners_at.call(float(lv) / levels)
			var hi: Array = corners_at.call(float(lv + 1) / levels)
			for q in 4:
				parts.append(_tube(lo[q], hi[q], 0.16, _steel))
				parts.append(_tube(hi[q], hi[(q + 1) % 4], 0.07, _steel))
				parts.append(_tube(lo[q], hi[(q + 1) % 4], 0.06, _steel))
		# Cabeça com os refletores, inclinada para o gramado.
		var head_b := fb * Basis(Vector3.RIGHT, deg_to_rad(18.0))
		var head_c := pos + Vector3.UP * (height + 3.0)
		beams.append(head_c + Vector3.UP * 4.0)
		parts.append([TrackProps._box(Vector3(10.0, 6.4, 0.7)), Transform3D(head_b, head_c), TrackScenery.NAVY])
		parts.append([TrackProps._box(Vector3(4.0, 0.3, 4.0)), Transform3D(fb, pos + Vector3.UP * height), _steel])
		for row in 3:
			for col in 5:
				var off := Vector3(-3.8 + col * 1.9, -2.0 + row * 2.0, 0.42)
				lamp_parts.append([TrackProps._box(Vector3(1.5, 1.5, 0.25)), Transform3D(head_b, head_c + head_b * off), Color.WHITE])
	var towers := _node("TorresDeLuz", parent)
	towers.add_child(_mi(TrackBeach.parts_mesh(parts, _mat("tint"))))
	towers.add_child(_mi(TrackBeach.parts_mesh(lamp_parts, _mat("lamp")), Transform3D.IDENTITY, false))
	if _night:
		var cols: Array[Color] = [Color(0.55, 0.85, 1.0), Color(1.0, 0.45, 0.85)]
		for k in beams.size():
			TrackCity.add_beam(towers, beams[k], cols[k % 2], float(k) * 1.6 + 0.5)


func _nearest_ring(p: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in _ring.size():
		var d := _ring[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


## Base de pé ao lado da reta da largada, no lado do miolo: +X ao longo da pista (no
## sentido que fica à esquerda de quem olha da pista), +Z virado para a pista.
func _infield_frame(along: float, lateral_extra: float) -> Transform3D:
	var outside := track.road_width * 0.5 + track.shoulder_width + track.wall_thickness
	var xf := track.get_transform_at(along, _infield_side * (outside + lateral_extra))
	var r := xf.basis.x
	var z := -_infield_side * r
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(xf.origin.x, terrain.height_at(xf.origin.x, xf.origin.z) - 0.05, xf.origin.z))


## Prédio dos boxes (garagens viradas para a reta) com a torre de controle no meio.
func _build_pits(parent: Node3D) -> void:
	var from := -78.0
	var to := 42.0
	var length := to - from
	var frame := _infield_frame((from + to) * 0.5, 7.0)
	var pits := _node("Boxes", parent)
	pits.transform = frame
	_pits_at = Vector2(frame.origin.x, frame.origin.z)
	var depth := 14.0
	var h := 6.5
	var parts := []
	parts.append([TrackProps._box(Vector3(length, h, depth)), Transform3D(Basis(), Vector3(0, h * 0.5, -depth * 0.5)), _facade])
	parts.append([TrackProps._box(Vector3(length + 1.0, 0.35, depth + 1.0)), Transform3D(Basis(), Vector3(0, h + 0.17, -depth * 0.5)), _concrete_dark])
	parts.append([TrackProps._box(Vector3(length + 1.0, 1.6, 0.3)), Transform3D(Basis(), Vector3(0, h + 1.1, 0.35)), TrackScenery.NAVY])
	var glow := []
	var doors := int(length / 8.0)
	var pitch := length / doors
	for k in doors:
		var x := -length * 0.5 + pitch * (k + 0.5)
		if _night:
			# Garagem acesa por dentro e a faixa de neon em cima.
			glow.append([TrackProps._box(Vector3(pitch - 1.6, 4.4, 0.2)), Transform3D(Basis(), Vector3(x, 2.2, 0.06)), Color(0.05, 0.12, 0.24)])
			glow.append([TrackProps._box(Vector3(pitch - 1.2, 0.25, 0.3)), Transform3D(Basis(), Vector3(x, 4.75, 0.1)), TrackCity.CYAN])
		else:
			parts.append([TrackProps._box(Vector3(pitch - 1.6, 4.4, 0.2)), Transform3D(Basis(), Vector3(x, 2.2, 0.06)), _door])
			parts.append([TrackProps._box(Vector3(pitch - 1.2, 0.4, 0.3)), Transform3D(Basis(), Vector3(x, 4.75, 0.1)), TrackScenery.YELLOW])
		parts.append([TrackProps._box(Vector3(0.9, h, 0.5)), Transform3D(Basis(), Vector3(x - pitch * 0.5, h * 0.5, 0.1)), TrackScenery.BRAND_BLUE])
	# Torre de controle: base, faixa de vidro, tampa azul e a placa da marca no alto.
	var tz := -depth * 0.5 - 1.0
	parts.append([TrackProps._box(Vector3(12.0, 16.0, 12.0)), Transform3D(Basis(), Vector3(0, 8.0, tz)), _facade])
	parts.append([TrackProps._box(Vector3(14.0, 1.2, 14.0)), Transform3D(Basis(), Vector3(0, 21.6, tz)), TrackScenery.BRAND_BLUE])
	parts.append([TrackProps._box(Vector3(10.4, 3.4, 0.5)), Transform3D(Basis(), Vector3(0, 24.0, tz + 4.0)), TrackScenery.NAVY])
	parts.append(_tube(Vector3(4.5, 22.2, tz - 4.0), Vector3(4.5, 30.0, tz - 4.0), 0.12, _steel))
	pits.add_child(_mi(TrackBeach.parts_mesh(parts, _mat("tint"))))
	if not glow.is_empty():
		pits.add_child(_mi(TrackBeach.parts_mesh(glow, TrackCity.neon_material()), Transform3D.IDENTITY, false))
	var glass := TrackProps._box(Vector3(13.0, 5.0, 13.0))
	pits.add_child(_mi(glass, Transform3D(Basis(), Vector3(0, 18.5, tz))))
	(pits.get_child(-1) as MeshInstance3D).material_override = _mat("glass")
	# Faixas da marca na platibanda e a placa da torre.
	var md := Track.MeshData.new()
	var md2 := Track.MeshData.new()
	var panel := 12.0
	var count := int(length / panel)
	var fw := Vector3.BACK
	for k in count:
		var x0 := -length * 0.5 + (length - count * panel) * 0.5 + k * panel
		var target := md if k % 2 == 0 else md2
		_quad(target, [Vector3(x0, h + 1.85, 0.52), Vector3(x0 + panel, h + 1.85, 0.52), Vector3(x0 + panel, h + 0.35, 0.52), Vector3(x0, h + 0.35, 0.52)],
				[fw, fw, fw, fw], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], fw)
	var mats := _brand_variants(panel / 1.5)
	pits.add_child(_mi(md.to_mesh(mats[0]), Transform3D.IDENTITY, false))
	pits.add_child(_mi(md2.to_mesh(mats[1]), Transform3D.IDENTITY, false))
	var sign := QuadMesh.new()
	sign.size = Vector2(10.0, 3.0)
	sign.material = TrackScenery.brand_material(TrackScenery.WORDMARK_DARK, TrackScenery.NAVY, 10.0 / 3.0,
			{"logo_fill": 0.62, "border_width": 0.06, "border_color": TrackScenery.YELLOW, "emission": 0.25})
	pits.add_child(_mi(sign, Transform3D(Basis(), Vector3(0, 24.0, tz + 4.27)), false))
	reserved.append(Vector3(frame.origin.x, frame.origin.z, length * 0.6))


## Tendas de convidados atrás dos boxes: paredes brancas, teto de pirâmide azul ou
## amarelo e uma bandeirinha no alto.
func _build_tents(parent: Node3D) -> void:
	var frame := _infield_frame(-18.0, 7.0 + 14.0 + 16.0)
	var row := _node("Tendas", parent)
	row.transform = frame
	var parts := []
	var size := 8.0
	var roof := TrackProps._cyl(0.05, size * 0.5 * sqrt(2.0) + 0.3, 2.8, 4)
	for k in 6:
		var x := (k - 2.5) * (size + 6.0)
		var col: Color = TrackScenery.BRAND_BLUE if k % 2 == 0 else TrackScenery.YELLOW
		if _night:
			col = Color(0.2, 0.08, 0.36) if k % 2 == 0 else Color(0.05, 0.18, 0.28)
		parts.append([TrackProps._box(Vector3(size, 2.6, size)), Transform3D(Basis(), Vector3(x, 1.3, 0)), _facade])
		parts.append([TrackProps._box(Vector3(size - 2.0, 2.2, 0.1)), Transform3D(Basis(), Vector3(x, 1.1, size * 0.5 + 0.02)), _door])
		parts.append([roof, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(x, 2.6 + 1.4, 0)), col])
		parts.append(_tube(Vector3(x, 5.3, 0), Vector3(x, 7.0, 0), 0.05, _steel))
		parts.append([TrackProps._box(Vector3(0.9, 0.55, 0.04)), Transform3D(Basis(), Vector3(x + 0.48, 6.7, 0)), TrackScenery.RED if k % 2 == 0 else TrackScenery.BRAND_BLUE])
	row.add_child(_mi(TrackBeach.parts_mesh(parts, _mat("tint"))))
	if _night:
		var glow := []
		for k in 6:
			var x := (k - 2.5) * (size + 6.0)
			var col: Color = TrackCity.MAGENTA if k % 2 == 0 else TrackCity.CYAN
			var h := size * 0.5 + 0.05
			var corners: Array[Vector3] = [Vector3(x - h, 2.62, -h), Vector3(x + h, 2.62, -h), Vector3(x + h, 2.62, h), Vector3(x - h, 2.62, h)]
			for q in 4:
				glow.append(_tube(corners[q], corners[(q + 1) % 4], 0.07, col))
		row.add_child(_mi(TrackBeach.parts_mesh(glow, TrackCity.neon_material()), Transform3D.IDENTITY, false))
	reserved.append(Vector3(frame.origin.x, frame.origin.z, 50.0))


## Pódio (1º, 2º e 3º) com o painel da marca, depois da linha de chegada.
func _build_podium(parent: Node3D) -> void:
	var frame := _infield_frame(64.0, 9.0)
	var podium := _node("Podio", parent)
	podium.transform = frame
	_podium_at = Vector2(frame.origin.x, frame.origin.z)
	var parts := []
	var places := [[0.0, 2.4, Color(1.0, 0.78, 0.2), "1"], [-3.5, 1.7, Color(0.8, 0.82, 0.86), "2"], [3.5, 1.2, Color(0.82, 0.5, 0.26), "3"]]
	for p: Array in places:
		var x: float = p[0]
		var h: float = p[1]
		parts.append([TrackProps._box(Vector3(3.4, h, 3.4)), Transform3D(Basis(), Vector3(x, h * 0.5, -2.0)), Color.WHITE])
		parts.append([TrackProps._box(Vector3(3.5, 0.14, 3.5)), Transform3D(Basis(), Vector3(x, h + 0.07, -2.0)), p[2]])
		parts.append([TrackProps._box(Vector3(3.45, 0.35, 3.45)), Transform3D(Basis(), Vector3(x, 0.4, -2.0)), TrackScenery.BRAND_BLUE])
		var num := _label(p[3], 1.3, TrackScenery.BRAND_BLUE, Color(0, 0, 0, 0))
		num.position = Vector3(x, h * 0.55 + 0.25, -0.28)
		podium.add_child(num)
	parts.append([TrackProps._box(Vector3(13.0, 6.0, 0.4)), Transform3D(Basis(), Vector3(0, 3.6, -4.4)), TrackScenery.NAVY])
	parts.append([TrackProps._box(Vector3(14.0, 1.0, 4.0)), Transform3D(Basis(), Vector3(0, 0.25, -2.4)), _concrete])
	podium.add_child(_mi(TrackBeach.parts_mesh(parts, _mat("tint"))))
	var back := QuadMesh.new()
	back.size = Vector2(12.4, 5.4)
	back.material = TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.BRAND_BLUE, 12.4 / 5.4,
			{"recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW, "logo_fill": 0.5, "logo_count": 4, "stripes": 0.5})
	podium.add_child(_mi(back, Transform3D(Basis(), Vector3(0, 3.6, -4.18)), false))
	reserved.append(Vector3(frame.origin.x, frame.origin.z, 14.0))


## O Celerino gigante (o modelo do jogo, em pé, ~13 m) num pedestal no meio do miolo,
## virado para a reta da largada; de tempos em tempos ele faz o gesto de escolha dele.
func _build_mascot(parent: Node3D, preview: bool) -> void:
	var c := track.stadium_center
	var r := track.stadium_radii
	var best := Vector2.INF
	var best_d := 0.0
	var x := c.x - r.x
	while x <= c.x + r.x:
		var z := c.y - r.y
		while z <= c.y + r.y:
			if inside(track, x, z, -30.0):
				var p := Vector2(x, z)
				var ok := (_pits_at == Vector2.INF or p.distance_to(_pits_at) > 50.0) \
						and (_podium_at == Vector2.INF or p.distance_to(_podium_at) > 30.0)
				var d := terrain.distance_to_track(x, z)
				if ok and d > best_d:
					best_d = d
					best = p
			z += 6.0
		x += 6.0
	if best == Vector2.INF or best_d < 22.0:
		return
	var ground := terrain.height_at(best.x, best.y) - 0.05
	var start := track.get_point_at(0.0)
	var face := Vector2(start.x, start.z) - best
	var b := TrackScenery._panel_basis(Vector3(face.x, 0.0, face.y))
	var statue := _node("CelerinoGigante", parent)
	statue.transform = Transform3D(b, Vector3(best.x, ground, best.y))
	var plinth_h := 2.6
	var parts := [
		[TrackProps._box(Vector3(11.0, plinth_h, 11.0)), Transform3D(Basis(), Vector3(0, plinth_h * 0.5, 0)), TrackScenery.BRAND_BLUE],
		[TrackProps._box(Vector3(11.6, 0.35, 11.6)), Transform3D(Basis(), Vector3(0, plinth_h + 0.17, 0)), TrackScenery.YELLOW],
		[TrackProps._box(Vector3(12.4, 0.5, 12.4)), Transform3D(Basis(), Vector3(0, 0.25, 0)), _concrete],
	]
	statue.add_child(_mi(TrackBeach.parts_mesh(parts, _mat("tint"))))
	var name_front := _label("CELERINO", 1.9, TrackScenery.YELLOW, Color(0, 0, 0, 0))
	name_front.position = Vector3(0, plinth_h * 0.5, 5.53)
	statue.add_child(name_front)
	var name_back := _label("CELERINO", 1.9, TrackScenery.YELLOW, Color(0, 0, 0, 0))
	name_back.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, plinth_h * 0.5, -5.53))
	statue.add_child(name_back)
	reserved.append(Vector3(best.x, best.y, 12.0))
	if _night:
		# Dois refletores coloridos na frente do pedestal, apontados para ele.
		for side: float in [-1.0, 1.0]:
			var spot := SpotLight3D.new()
			spot.name = "Refletor"
			var at := Vector3(side * 6.5, 0.6, 9.0)
			var target := Vector3(0.0, plinth_h + MASCOT_SCALE * 1.0, 0.0)
			spot.transform = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)
			spot.light_color = TrackCity.MAGENTA if side < 0.0 else TrackCity.CYAN
			spot.light_energy = 9.0
			spot.spot_range = 34.0
			spot.spot_angle = 26.0
			spot.shadow_enabled = false
			statue.add_child(spot)
	# No editor fica só o pedestal (o CharacterRig não roda no editor).
	if preview:
		return
	var data := load(CELERINO) as CharacterData
	if data == null:
		return
	var rig := data.instantiate_rig()
	rig.name = "Celerino"
	rig.setup_stand(MASCOT_SCALE)
	rig.update_every = 2
	rig.position = Vector3(0, plinth_h + 0.35, 0)
	statue.add_child(rig)
	var timer := Timer.new()
	timer.name = "Gesto"
	timer.wait_time = MASCOT_GESTURE_EVERY
	timer.autostart = true
	timer.timeout.connect(rig.play_pick_gesture.bind(1.6))
	statue.add_child(timer)


## Cidade neon: frisos de neon no anel — em cima da mureta (ciano, fora dos túneis), na
## viga da cobertura (magenta), na faixa da fachada de fora (roxo) e na beirada de trás do
## telhado (ciano).
func _build_neon_trims(parent: Node3D) -> void:
	var md := Track.MeshData.new()
	var dummy := Track.MeshData.new()
	var beam_v := ROOF_FRONT_Y - 1.9
	var front := [[Vector2(-0.06, FRONT_H - 0.05), Vector2(-0.06, FRONT_H + 0.16), Vector2(-1, 0), 0, TrackCity.CYAN]]
	var always := [
		[Vector2(ROOF_IN - 0.06, beam_v), Vector2(ROOF_IN - 0.06, beam_v + 0.24), Vector2(-1, 0), 0, TrackCity.MAGENTA],
		[Vector2(OUT_U + 0.06, TOP_H - 1.46), Vector2(OUT_U + 0.06, TOP_H - 1.2), Vector2(1, 0), 0, TrackCity.PURPLE],
		[Vector2(ROOF_OUT + 0.06, ROOF_BACK_Y), Vector2(ROOF_OUT + 0.06, ROOF_BACK_Y + 0.26), Vector2(1, 0), 0, TrackCity.CYAN],
	]
	var n := _ring.size()
	for i in n:
		var j := (i + 1) % n
		_extrude(md, dummy, i, always)
		if _portal[i] == 0 and _portal[j] == 0:
			_extrude(md, dummy, i, front)
	var mi := _mi(md.to_mesh(TrackCity.neon_material()), Transform3D.IDENTITY, false)
	mi.name = "NeonEstadio"
	parent.add_child(mi)


## Bandeiras da Ativos em mastros na beirada da cobertura.
func _build_ring_flags(parent: Node3D) -> void:
	var variants: Array[ShaderMaterial] = [
		TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.BRAND_BLUE, 1.6,
				{"recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW, "wave": 0.25, "logo_fill": 0.62}),
		TrackScenery.brand_material(TrackScenery.LOGO_ICON, Color.WHITE, 1.6, {"wave": 0.25, "logo_fill": 0.62}),
		TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.YELLOW, 1.6, {"wave": 0.25, "logo_fill": 0.62}),
	]
	var flag := QuadMesh.new()
	flag.size = Vector2(3.4, 2.1)
	flag.subdivide_width = 10
	flag.subdivide_depth = 2
	flag.center_offset = Vector3(1.7, 0.0, 0.0)
	var flags := _node("Bandeiras", parent)
	flags.add_to_group(TrackScenery.DETAIL_GROUP)
	var poles := []
	var count := 16
	var n := _ring.size()
	for k in count:
		var i := int(float(k) / count * n + n / (count * 2)) % n
		if _portal[i] == 1:
			continue
		var base := _at(i, Vector2(ROOF_IN + 0.5, ROOF_FRONT_Y + ROOF_THICK))
		poles.append(_tube(base, base + Vector3.UP * 6.0, 0.08, _steel))
		var z := -_n3(i)
		var x := Vector3.UP.cross(z).normalized()
		var mi := _mi(flag, Transform3D(Basis(x, Vector3.UP, z), base + Vector3.UP * 4.9), false)
		mi.material_override = variants[k % variants.size()]
		flags.add_child(mi)
	if not poles.is_empty():
		flags.add_child(_mi(TrackBeach.parts_mesh(poles, _mat("tint")), Transform3D.IDENTITY, false))


# --- Largada ---------------------------------------------------------------------------

## Pórtico de treliça: duas torres, viga de treliça, placar de LED com a marca (o ícone
## atrás), luzes de largada e faixa quadriculada.
func build_start_gate(gate: Node3D) -> void:
	var half := track.road_width * 0.5 + 2.0
	var height := 9.4
	var bay := 1.5
	var parts := []
	for side: float in [-1.0, 1.0]:
		var cx := side * half
		var corners: Array[Vector3] = [Vector3(cx - 0.6, 0, -0.6), Vector3(cx + 0.6, 0, -0.6), Vector3(cx + 0.6, 0, 0.6), Vector3(cx - 0.6, 0, 0.6)]
		for q in 4:
			parts.append(_tube(corners[q], corners[q] + Vector3.UP * height, 0.09, _steel, 8))
		var y := 0.0
		while y < height - 0.1:
			var y1 := minf(y + bay, height)
			for q in 4:
				var a := corners[q] + Vector3.UP * y1
				var b := corners[(q + 1) % 4] + Vector3.UP * y1
				parts.append(_tube(a, b, 0.05, _steel))
				parts.append(_tube(corners[q] + Vector3.UP * y, b, 0.045, _steel))
			y = y1
		parts.append([TrackProps._box(Vector3(2.0, 0.5, 2.0)), Transform3D(Basis(), Vector3(cx, 0.25, 0)), TrackScenery.BRAND_BLUE])
	# Viga de treliça em cima (1,2 × 1,2 m).
	var x0 := -half - 0.6
	var x1 := half + 0.6
	var rails: Array[Vector3] = [Vector3(0, height, -0.6), Vector3(0, height, 0.6), Vector3(0, height + 1.2, 0.6), Vector3(0, height + 1.2, -0.6)]
	for q in 4:
		parts.append(_tube(Vector3(x0, rails[q].y, rails[q].z), Vector3(x1, rails[q].y, rails[q].z), 0.08, _steel, 8))
	var x := x0
	while x < x1 - 0.1:
		var xn := minf(x + bay, x1)
		for q in 4:
			var a := Vector3(xn, rails[q].y, rails[q].z)
			var b := Vector3(xn, rails[(q + 1) % 4].y, rails[(q + 1) % 4].z)
			parts.append(_tube(a, b, 0.05, _steel))
			parts.append(_tube(Vector3(x, rails[q].y, rails[q].z), b, 0.045, _steel))
		x = xn
	# Placar pendurado na viga e a caixa das luzes de largada.
	var board_w := half * 2.0 - 2.4
	parts.append([TrackProps._box(Vector3(board_w + 0.4, 2.6, 0.5)), Transform3D(Basis(), Vector3(0, height - 1.5, 0)), TrackScenery.NAVY])
	parts.append([TrackProps._box(Vector3(board_w + 0.6, 0.2, 0.6)), Transform3D(Basis(), Vector3(0, height - 0.15, 0)), TrackScenery.YELLOW])
	parts.append([TrackProps._box(Vector3(4.6, 1.0, 0.6)), Transform3D(Basis(), Vector3(0, height - 3.45, 0)), Color(0.07, 0.07, 0.09)])
	gate.add_child(_mi(TrackBeach.parts_mesh(parts, _mat("tint"))))
	if _night:
		var glow := []
		for side: float in [-1.0, 1.0]:
			for oz: float in [-0.68, 0.68]:
				var a := Vector3(side * (half + 0.68), 0.5, oz)
				glow.append(_tube(a, a + Vector3.UP * (height - 0.5), 0.06, TrackCity.CYAN if oz > 0.0 else TrackCity.MAGENTA))
		for oz: float in [-0.68, 0.68]:
			glow.append(_tube(Vector3(x0, height - 0.08, oz), Vector3(x1, height - 0.08, oz), 0.06, TrackCity.MAGENTA))
			glow.append(_tube(Vector3(x0, height + 1.28, oz), Vector3(x1, height + 1.28, oz), 0.06, TrackCity.CYAN))
		gate.add_child(_mi(TrackBeach.parts_mesh(glow, TrackCity.neon_material()), Transform3D.IDENTITY, false))
	var lamps := []
	for k in 5:
		for z: float in [0.32, -0.32]:
			lamps.append([TrackProps._sphere(0.3, 10), Transform3D(Basis(), Vector3(-1.7 + k * 0.85, height - 3.45, z)), Color.WHITE])
	gate.add_child(_mi(TrackBeach.parts_mesh(lamps, _mat("red_lamp")), Transform3D.IDENTITY, false))
	var panel := QuadMesh.new()
	panel.size = Vector2(board_w, 2.2)
	var aspect := panel.size.x / panel.size.y
	var front := _mi(panel, Transform3D(Basis(), Vector3(0, height - 1.5, 0.26)), false)
	front.material_override = TrackScenery.brand_material(TrackScenery.WORDMARK_DARK, TrackScenery.NAVY, aspect,
			{"logo_fill": 0.66, "border_width": 0.05, "border_color": TrackScenery.YELLOW, "emission": 0.4})
	gate.add_child(front)
	var back := _mi(panel, Transform3D(Basis(Vector3.UP, PI), Vector3(0, height - 1.5, -0.26)), false)
	back.material_override = TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.BRAND_BLUE, aspect,
			{"logo_fill": 0.8, "logo_count": 3, "recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW, "emission": 0.3})
	gate.add_child(back)
	# Faixa quadriculada na frente da viga.
	var img := Image.create(32, 2, false, Image.FORMAT_RGB8)
	for px in 32:
		for py in 2:
			img.set_pixel(px, py, Color.WHITE if (px + py) % 2 == 0 else Color(0.05, 0.05, 0.07))
	var checker := StandardMaterial3D.new()
	checker.albedo_texture = ImageTexture.create_from_image(img)
	checker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	checker.cull_mode = BaseMaterial3D.CULL_DISABLED
	checker.roughness = 0.6
	var strip := QuadMesh.new()
	strip.size = Vector2(x1 - x0, 0.8)
	strip.material = checker
	for z: float in [0.66, -0.66]:
		gate.add_child(_mi(strip, Transform3D(Basis(), Vector3(0, height + 0.6, z)), false))
	if track.with_collision:
		track.physics_job(func() -> void:
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.6, height, 1.6)
			for side: float in [-1.0, 1.0]:
				var body := StaticBody3D.new()
				body.add_to_group("wall")
				body.transform = Transform3D(Basis(), Vector3(side * half, height * 0.5, 0.0))
				var col := CollisionShape3D.new()
				col.shape = shape
				body.add_child(col)
				gate.add_child(body))
