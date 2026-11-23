@tool
class_name TrackSectionBuilder
extends RefCounted
## Monta o visual dos trechos especiais da pista (veja track_section.gd):
## - Submerso: a superfície da água vista de baixo, raios de sol, algas balançando,
##   corais, estrelas-do-mar, cardumes, colunas de bolhas e um naufrágio (no mar, com o
##   baú e o submarino amarelo da Ativos; no lago, um barco a remo e nenúfares).
## - Dunas: os redemoinhos de areia movediça, bandeirinhas de rali nas muretas,
##   esqueletos de fóssil meio enterrados e areia voando com o vento.
## - Gelo: blocos de gelo, cabanas de pesca no gelo (só no lago), montes de neve e
##   pinguins patinando em roda. No riacho congelado (sem lago) tudo fica no chão de neve
##   das margens. Na pista de neve e gelo: cristais de gelo gigantes nas margens e, sobre
##   cada riacho, um arco de gelo glacial por onde a pista passa.
## - Vale: paredão de pedra onde a pista acaba, cachoeira na cabeceira (congelada na
##   neve) com névoa e arco-íris, pedras no rio, árvores, bichos voando (golfinhos no
##   mar) e um destaque de cada cenário: ponte pênsil (campo), rochas no mar e um barco
##   encalhado (praia), arco de pedra e torres de rocha (deserto) e teleférico (neve).

const WATERFALL_SHADER := preload("res://shaders/waterfall.gdshader")
const UNDER_SHADER := preload("res://shaders/water_under.gdshader")
const SHAFT_SHADER := preload("res://shaders/light_shaft.gdshader")
const KELP_SHADER := preload("res://shaders/kelp.gdshader")
const CREATURE_SHADER := preload("res://shaders/creature.gdshader")
const QUICKSAND_SHADER := preload("res://shaders/quicksand.gdshader")
const RAINBOW_SHADER := preload("res://shaders/rainbow.gdshader")
const BUBBLE_SHADER := preload("res://shaders/bubble.gdshader")
const STONE_SHADER := preload("res://shaders/stone.gdshader")
const ICE_CRYSTAL_SHADER := preload("res://shaders/ice_crystal.gdshader")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")
const WORDMARK_DARK := preload("res://assets/logos/ativos_marca_branca.png")
const CABLE_CAR := preload("res://scripts/cable_car.gd")

enum Creature { PEIXE, PASSARO, GOLFINHO, PINGUIM }

var track: Track
var terrain: TrackTerrain
var root: Node3D
var rng := RandomNumberGenerator.new()

## Distância do centro da pista até o lado de fora da mureta.
var _outside := 0.0
## Material com a cor de vértice × cor da instância (sRGB, como os outros enfeites).
var _tint: StandardMaterial3D
var _creature_mats := {}


func _init(p_track: Track, p_terrain: TrackTerrain, p_root: Node3D) -> void:
	track = p_track
	terrain = p_terrain
	root = p_root


func build(preview: bool) -> void:
	rng.seed = track.decoration_seed * 7121 + 3
	_outside = track.road_width * 0.5 + track.shoulder_width + track.wall_thickness
	_tint = StandardMaterial3D.new()
	_tint.vertex_color_use_as_albedo = true
	_tint.vertex_color_is_srgb = true
	_tint.roughness = 0.8
	for s in track.sections:
		if s == null:
			continue
		match s.kind:
			TrackSection.Kind.SUBMERSO:
				_build_underwater(s, preview)
			TrackSection.Kind.AREIA:
				_build_dunes(s, preview)
			TrackSection.Kind.GELO:
				_build_ice(s)
	var paths := track._valley_paths()
	for gi in track.gap_spans.size():
		_build_gap_edges(track.gap_spans[gi])
		if gi < paths.size():
			_build_valley(track.gap_spans[gi], paths[gi], preview)


# --- Utilidades --------------------------------------------------------------------

## Amostras do trecho (com `full`, só as de dentro; senão as rampas também).
func _indices(s: TrackSection, full := true) -> PackedInt32Array:
	var out := PackedInt32Array()
	var si := track.sections.find(s)
	for i in track.samples.size():
		if track.section_of[i] == si and (not full or track.section_blend[i] >= 0.999):
			out.append(i)
	return out


## Ponto do chão ao lado de uma das amostras `ids`, a uma lateral entre `lat_min` e
## `lat_max` (m do centro da pista), fora das muretas. Vector3.INF se não deu.
func _spot_beside(ids: PackedInt32Array, lat_min: float, lat_max: float, clear := 1.0) -> Vector3:
	if ids.is_empty():
		return Vector3.INF
	var i := ids[rng.randi() % ids.size()]
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var p := track.samples[i] + track.rights[i] * side * rng.randf_range(lat_min, lat_max) \
			+ track.tangents[i] * rng.randf_range(-2.0, 2.0)
	if terrain.distance_to_track(p.x, p.z) < _outside + clear:
		return Vector3.INF
	return Vector3(p.x, terrain.height_at(p.x, p.z), p.z)


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], colors: Array[Color], name: String,
		parent: Node3D, shadows := false, custom: Array[Color] = []) -> MultiMeshInstance3D:
	if xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.use_custom_data = not custom.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if mm.use_colors:
			mm.set_instance_color(k, colors[k])
		if mm.use_custom_data:
			mm.set_instance_custom_data(k, custom[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


func _add(mesh: Mesh, xform: Transform3D, parent: Node3D, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _node(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	root.add_child(n)
	return n


static func _sphere(radius: float, segments := 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 3)
	return m


static func _cyl(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Peças [malha primitiva, transform, cor] numa malha só, com a cor em COLOR.
func _parts(parts: Array, material: Material, with_lods := false) -> ArrayMesh:
	var st := MeshMerge.new()
	for part in parts:
		st.append_from(part[0], 0, part[1], part[2] if part.size() > 2 else Color.WHITE)
	st.set_material(material)
	return st.commit(null, with_lods)


## Base olhando na direção `dir` (no plano), de pé.
static func _facing(dir: Vector3) -> Basis:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.0001:
		return Basis()
	return Basis.looking_at(d.normalized(), Vector3.UP)


func _stone_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = STONE_SHADER
	match track.scenery:
		TrackTheme.Scenery.DESERTO:
			m.set_shader_parameter("stone_a", Color(0.86, 0.5, 0.3))
			m.set_shader_parameter("stone_b", Color(0.66, 0.34, 0.2))
			m.set_shader_parameter("mortar", Color(0.45, 0.22, 0.14))
		TrackTheme.Scenery.PRAIA:
			m.set_shader_parameter("stone_a", Color(0.8, 0.72, 0.58))
			m.set_shader_parameter("stone_b", Color(0.62, 0.55, 0.45))
		TrackTheme.Scenery.NEVE:
			m.set_shader_parameter("snow_cover", 1.0)
	m.set_shader_parameter("block_w", 2.4)
	m.set_shader_parameter("block_h", 1.1)
	return m


# --- Bichos (creature.gdshader) -------------------------------------------------------

func _creature_material(kind: int) -> ShaderMaterial:
	if not _creature_mats.has(kind):
		var m := ShaderMaterial.new()
		m.shader = CREATURE_SHADER
		m.set_shader_parameter("mode", kind)
		_creature_mats[kind] = m
	return _creature_mats[kind]


## Malha de cada bicho, olhando para +Z, com as cores nos vértices.
func _creature_mesh(kind: int) -> ArrayMesh:
	var m := _creature_material(kind)
	match kind:
		Creature.PEIXE:
			return _parts([
				[_sphere(0.5, 8), Transform3D(Basis().scaled(Vector3(0.22, 0.36, 0.62)), Vector3.ZERO)],
				[_box(Vector3(0.02, 0.34, 0.26)), Transform3D(Basis(Vector3.RIGHT, 0.0), Vector3(0.0, 0.0, -0.4)), Color(0.9, 0.9, 0.9)],
				[_sphere(0.05, 6), Transform3D(Basis(), Vector3(0.09, 0.05, 0.2)), Color(0.05, 0.05, 0.05)],
				[_sphere(0.05, 6), Transform3D(Basis(), Vector3(-0.09, 0.05, 0.2)), Color(0.05, 0.05, 0.05)],
			], m)
		Creature.PASSARO:
			return _parts([
				[_sphere(0.5, 8), Transform3D(Basis().scaled(Vector3(0.3, 0.26, 0.9)), Vector3.ZERO)],
				[_box(Vector3(2.4, 0.05, 0.55)), Transform3D(Basis(), Vector3(0.0, 0.05, 0.05))],
				[_box(Vector3(0.5, 0.04, 0.3)), Transform3D(Basis(), Vector3(0.0, 0.0, -0.55))],
				[_cyl(0.0, 0.06, 0.25, 6), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, 0.55)), Color(1.0, 0.75, 0.2)],
			], m)
		Creature.GOLFINHO:
			var grey := Color(0.55, 0.62, 0.7)
			return _parts([
				[_sphere(0.5, 12), Transform3D(Basis().scaled(Vector3(0.7, 0.75, 2.6)), Vector3.ZERO), grey],
				[_sphere(0.5, 8), Transform3D(Basis().scaled(Vector3(0.5, 0.35, 1.6)), Vector3(0.0, -0.15, 0.2)), Color(0.88, 0.9, 0.92)],
				[_cyl(0.06, 0.18, 0.7, 6), Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.RIGHT, 0.3), Vector3(0.0, -0.05, 1.45)), grey],
				[_box(Vector3(0.06, 0.55, 0.5)), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.0, 0.45, -0.1)), grey],
				[_box(Vector3(1.1, 0.05, 0.35)), Transform3D(Basis(), Vector3(0.0, 0.0, -1.3)), grey],
			], m)
		_:
			var black := Color(0.08, 0.09, 0.12)
			return _parts([
				[_sphere(0.5, 10), Transform3D(Basis().scaled(Vector3(0.62, 1.0, 0.58)), Vector3(0.0, 0.52, 0.0)), black],
				[_sphere(0.5, 10), Transform3D(Basis().scaled(Vector3(0.48, 0.8, 0.3)), Vector3(0.0, 0.48, 0.16)), Color(0.96, 0.96, 0.96)],
				[_sphere(0.24, 8), Transform3D(Basis(), Vector3(0.0, 1.06, 0.02)), black],
				[_cyl(0.0, 0.07, 0.2, 6), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 1.03, 0.28)), Color(1.0, 0.6, 0.1)],
				[_box(Vector3(0.14, 0.04, 0.2)), Transform3D(Basis(), Vector3(0.12, 0.02, 0.08)), Color(1.0, 0.6, 0.1)],
				[_box(Vector3(0.14, 0.04, 0.2)), Transform3D(Basis(), Vector3(-0.12, 0.02, 0.08)), Color(1.0, 0.6, 0.1)],
			], m)


## Um grupo de bichos dando voltas em torno de `center` (cada um com seu raio, altura e
## fase). `size` = escala da malha.
func _flock(xforms: Array[Transform3D], colors: Array[Color], custom: Array[Color], center: Vector3, count: int,
		radius: Vector2, speed: float, size: float, spread_y: float, bob: float, palette: Array[Color]) -> void:
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	var phase0 := rng.randf() * TAU
	for k in count:
		var y := rng.randf_range(-spread_y, spread_y)
		var s := size * rng.randf_range(0.8, 1.2)
		xforms.append(Transform3D(Basis().scaled(Vector3.ONE * s), center + Vector3(0.0, y, 0.0)))
		colors.append(palette[rng.randi() % palette.size()])
		var r := rng.randf_range(radius.x, radius.y)
		# Velocidade angular para andar ~`speed` m/s no raio sorteado.
		custom.append(Color(r / s, dir * speed / maxf(r, 0.5), phase0 + k * 0.35 + rng.randf() * 0.2, bob / s))


# --- Submerso ------------------------------------------------------------------------

func _build_underwater(s: TrackSection, preview: bool) -> void:
	var wl := track.water_level
	var ids := PackedInt32Array()
	for i in _indices(s, false):
		if track.samples[i].y < wl - 1.5:
			ids.append(i)
	if ids.is_empty():
		return
	var node := _node("Submerso")
	var sea := track.scenery == TrackTheme.Scenery.PRAIA
	var box := AABB(track.samples[ids[0]], Vector3.ZERO)
	for i in ids:
		box = box.expand(track.samples[i])
	var reach := s.basin * 0.85
	# Superfície vista de baixo.
	var plane := PlaneMesh.new()
	plane.size = Vector2(box.size.x + reach * 2.0, box.size.z + reach * 2.0)
	var under := ShaderMaterial.new()
	under.shader = UNDER_SHADER
	var fog := TrackTheme.underwater_fog(track.scenery)
	under.set_shader_parameter("deep_color", fog)
	under.set_shader_parameter("bright_color", fog.lerp(Color(0.85, 1.0, 1.0), 0.75))
	plane.material = under
	_add(plane, Transform3D(Basis(), Vector3(box.get_center().x, wl - 0.04, box.get_center().z)), node, false)

	# Raios de sol inclinados, do alto até o fundo.
	var shaft_mat := ShaderMaterial.new()
	shaft_mat.shader = SHAFT_SHADER
	shaft_mat.set_shader_parameter("water_level", wl)
	var shafts: Array[Transform3D] = []
	var shaft := _shaft_mesh(shaft_mat)
	var count := clampi(ids.size() / 8, 6, 22)
	for k in count:
		var p := _spot_beside(ids, 0.0, 26.0, -_outside)
		if p == Vector3.INF:
			continue
		var depth := wl - p.y
		if depth < 2.5:
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, 0.25)
		shafts.append(Transform3D(b.scaled(Vector3(rng.randf_range(2.0, 4.5), depth + 1.0, 1.0)), Vector3(p.x, wl, p.z)))
	_multimesh(shaft, shafts, [], "RaiosDeSol", node)

	# Algas.
	var kelp_mat := ShaderMaterial.new()
	kelp_mat.shader = KELP_SHADER
	if not sea:
		kelp_mat.set_shader_parameter("base_color", Color(0.12, 0.3, 0.1))
		kelp_mat.set_shader_parameter("tip_color", Color(0.45, 0.65, 0.18))
	var kelp := _kelp_mesh(kelp_mat)
	var kx: Array[Transform3D] = []
	var kc: Array[Color] = []
	var target := (200 if sea else 260) / (4 if preview else 1)
	var tries := 0
	while kx.size() < target and tries < target * 4:
		tries += 1
		var p := _spot_beside(ids, _outside + 0.5, reach, 0.6)
		if p == Vector3.INF or p.y > wl - 1.5:
			continue
		var tall := minf(wl - p.y - 0.6, rng.randf_range(1.6, 6.5) if sea else rng.randf_range(0.8, 3.2))
		var w := rng.randf_range(0.6, 1.1)
		kx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, tall, w)), p - Vector3.UP * 0.1))
		kc.append(Color.from_hsv(rng.randf_range(0.2, 0.32), rng.randf_range(0.5, 0.9), rng.randf_range(0.75, 1.0)))
	_multimesh(kelp, kx, kc, "Algas", node)

	# Pedras.
	var rocks: Array[Transform3D] = []
	var rock_colors: Array[Color] = []
	for k in 50:
		var p := _spot_beside(ids, _outside + 1.0, reach, 1.0)
		if p == Vector3.INF or p.y > wl - 1.0:
			continue
		var sc := rng.randf_range(0.6, 2.4)
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.5, 0.9), sc)), p - Vector3.UP * 0.3 * sc))
		var v := rng.randf_range(0.35, 0.55)
		rock_colors.append(Color(v, v * 0.98, v * 0.92))
	_multimesh(TrackProps._rock_mesh(_tint), rocks, rock_colors, "Pedras", node)

	if sea:
		_build_corals(ids, node, reach)
	else:
		_build_lily_pads(ids, node, s)

	# Cardumes.
	var fx: Array[Transform3D] = []
	var fc: Array[Color] = []
	var fcu: Array[Color] = []
	var palette: Array[Color] = [Color(0.72, 0.76, 0.8), Color(0.55, 0.65, 0.45), Color(0.95, 0.55, 0.25)]
	if sea:
		palette = [Color(1.0, 0.82, 0.1), Color(0.2, 0.55, 1.0), Color(1.0, 0.45, 0.1), Color(0.95, 0.95, 1.0), Color(0.9, 0.3, 0.6)]
	for k in (9 if sea else 6):
		var p := _spot_beside(ids, 0.0, reach * 0.7, -_outside)
		if p == Vector3.INF:
			continue
		var floor_y := p.y
		var depth := wl - floor_y
		if depth < 3.0:
			continue
		var center := Vector3(p.x, floor_y + rng.randf_range(1.8, depth - 1.0), p.z)
		var one: Array[Color] = [palette[rng.randi() % palette.size()]]
		_flock(fx, fc, fcu, center, rng.randi_range(10, 18), Vector2(3.0, 9.0), rng.randf_range(2.0, 4.0),
				rng.randf_range(0.7, 1.2) if sea else rng.randf_range(0.6, 0.9), 0.9, 0.3, one)
	_multimesh(_creature_mesh(Creature.PEIXE), fx, fc, "Cardumes", node, false, fcu)

	# Colunas de bolhas saindo do fundo.
	if not preview:
		var bubble_mat := ShaderMaterial.new()
		bubble_mat.shader = BUBBLE_SHADER
		for k in 5:
			var p := _spot_beside(ids, _outside + 2.0, 30.0, 1.0)
			if p == Vector3.INF or p.y > wl - 2.0:
				continue
			_add_bubble_column(node, p, wl - p.y, bubble_mat)

	_build_wreck(ids, node, reach, sea)


func _shaft_mesh(material: Material) -> ArrayMesh:
	# Dois quads cruzados de 1 m de largura e 1 m de altura (do 0 para baixo).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a: float in [0.0, PI * 0.5]:
		var r := Vector3(cos(a), 0.0, sin(a)) * 0.5
		var top_l := -r
		var top_r := r
		var bot_l := -r + Vector3.DOWN
		var bot_r := r + Vector3.DOWN
		st.set_uv(Vector2(0, 0))
		st.add_vertex(top_l)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(top_r)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(bot_r)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(top_l)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(bot_r)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(bot_l)
	st.set_material(material)
	return st.commit()


func _kelp_mesh(material: Material) -> ArrayMesh:
	# Duas fitas cruzadas, 1 m de largura e 1 m de altura, com 10 gomos (o shader dobra).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a: float in [0.0, PI * 0.5]:
		var r := Vector3(cos(a), 0.0, sin(a)) * 0.5
		var n := Vector3(-sin(a), 0.0, cos(a))
		for k in 10:
			var y0 := k / 10.0
			var y1 := (k + 1) / 10.0
			var quad := [[-r + Vector3.UP * y0, Vector2(0, y0)], [r + Vector3.UP * y0, Vector2(1, y0)],
					[r + Vector3.UP * y1, Vector2(1, y1)], [-r + Vector3.UP * y1, Vector2(0, y1)]]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(n)
				st.set_uv(quad[idx][1])
				st.add_vertex(quad[idx][0])
	st.set_material(material)
	return st.commit()


func _build_corals(ids: PackedInt32Array, node: Node3D, reach: float) -> void:
	var wl := track.water_level
	var branch_parts := [[_cyl(0.12, 0.2, 1.2), Transform3D(Basis(), Vector3(0.0, 0.6, 0.0))]]
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var tilt := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.6)
		branch_parts.append([_cyl(0.06, 0.11, 1.1), Transform3D(tilt, Vector3(0.0, 1.0, 0.0) + tilt * Vector3(0.0, 0.5, 0.0))])
		branch_parts.append([_sphere(0.1, 6), Transform3D(Basis(), Vector3(0.0, 1.0, 0.0) + tilt * Vector3(0.0, 1.05, 0.0))])
	var meshes := [
		_parts(branch_parts, _tint),
		_parts([[_sphere(0.9, 12), Transform3D(Basis().scaled(Vector3(1.0, 0.6, 1.0)), Vector3(0.0, 0.3, 0.0))]], _tint),
		_parts([[_cyl(0.9, 0.9, 0.06, 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.95, 0.0))],
				[_cyl(0.05, 0.08, 0.5), Transform3D(Basis(), Vector3(0.0, 0.25, 0.0))]], _tint),
		_parts([[_cyl(0.16, 0.16, 1.4), Transform3D(Basis(), Vector3(0.0, 0.7, 0.0))],
				[_cyl(0.14, 0.14, 1.0), Transform3D(Basis(), Vector3(0.35, 0.5, 0.1))],
				[_cyl(0.13, 0.13, 1.8), Transform3D(Basis(), Vector3(-0.3, 0.9, 0.2))],
				[_cyl(0.12, 0.12, 0.8), Transform3D(Basis(), Vector3(0.1, 0.4, -0.35))]], _tint),
	]
	var names := ["CoraisGalho", "CoraisCerebro", "CoraisLeque", "CoraisTubo"]
	var palette: Array[Color] = [Color(1.0, 0.45, 0.55), Color(1.0, 0.6, 0.2), Color(0.7, 0.35, 0.95), Color(1.0, 0.85, 0.25),
			Color(0.95, 0.25, 0.3), Color(0.2, 0.85, 0.8), Color(1.0, 0.7, 0.75)]
	for mi in meshes.size():
		var xs: Array[Transform3D] = []
		var cs: Array[Color] = []
		var tries := 0
		while xs.size() < 45 and tries < 200:
			tries += 1
			var p := _spot_beside(ids, _outside + 0.4, reach * 0.8, 0.4)
			if p == Vector3.INF or p.y > wl - 1.6:
				continue
			var sc := rng.randf_range(0.8, 2.0)
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p - Vector3.UP * 0.05))
			cs.append(palette[rng.randi() % palette.size()])
		_multimesh(meshes[mi], xs, cs, names[mi], node)
	# Estrelas-do-mar e conchas no fundo.
	var star_parts := []
	for k in 5:
		var a := k * TAU / 5.0
		star_parts.append([_box(Vector3(0.16, 0.06, 0.55)), Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0.0, cos(a)) * 0.26)])
	star_parts.append([_cyl(0.14, 0.14, 0.07, 8), Transform3D()])
	var star := _parts(star_parts, _tint)
	var sx: Array[Transform3D] = []
	var sc_: Array[Color] = []
	for k in 60:
		var p := _spot_beside(ids, _outside + 0.3, reach * 0.6, 0.3)
		if p == Vector3.INF or p.y > wl - 1.2:
			continue
		sx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), p + Vector3.UP * 0.03))
		sc_.append([Color(1.0, 0.45, 0.2), Color(0.95, 0.25, 0.35), Color(1.0, 0.8, 0.3), Color(0.6, 0.35, 0.95)][rng.randi() % 4])
	_multimesh(star, sx, sc_, "EstrelasDoMar", node)


## Nenúfares na superfície do lago (alguns com flor) e juncos na beira.
func _build_lily_pads(ids: PackedInt32Array, node: Node3D, s: TrackSection) -> void:
	var wl := track.water_level
	var pad := _parts([[_cyl(0.7, 0.7, 0.04, 12), Transform3D()]], _tint)
	var flower := _parts([[_sphere(0.22, 8), Transform3D(Basis().scaled(Vector3(1.0, 0.6, 1.0)), Vector3(0.0, 0.1, 0.0))],
			[_cyl(0.06, 0.0, 0.25, 6), Transform3D(Basis(), Vector3(0.0, 0.25, 0.0)), Color(1.0, 0.85, 0.3)]], _tint)
	var px: Array[Transform3D] = []
	var pc: Array[Color] = []
	var fx: Array[Transform3D] = []
	var fc: Array[Color] = []
	var tries := 0
	while px.size() < 160 and tries < 900:
		tries += 1
		var p := _spot_beside(ids, _outside + 2.0, s.basin, 1.5)
		if p == Vector3.INF or p.y > wl - 0.4:
			continue
		var cluster := Vector3(p.x, wl + 0.02, p.z)
		for k in rng.randi_range(2, 6):
			var o := Vector3(rng.randf_range(-2.5, 2.5), 0.0, rng.randf_range(-2.5, 2.5))
			var sc := rng.randf_range(0.6, 1.4)
			px.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, 1.0, sc)), cluster + o))
			pc.append(Color.from_hsv(rng.randf_range(0.24, 0.32), 0.75, rng.randf_range(0.45, 0.7)))
			if rng.randf() < 0.18:
				fx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), cluster + o + Vector3.UP * 0.03))
				fc.append(Color(1.0, 0.55, 0.75) if rng.randf() < 0.7 else Color(1, 1, 1))
	_multimesh(pad, px, pc, "Nenufares", node)
	_multimesh(flower, fx, fc, "FloresDeLotus", node)


func _add_bubble_column(parent: Node3D, at: Vector3, height: float, material: Material) -> void:
	var p := GPUParticles3D.new()
	p.name = "ColunaDeBolhas"
	p.amount = 24
	p.lifetime = maxf(height / 2.2, 1.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0.0, 0.3, 0.0)
	pm.scale_min = 0.08
	pm.scale_max = 0.26
	p.process_material = pm
	var q := QuadMesh.new()
	q.material = material
	p.draw_pass_1 = q
	p.position = at
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, height + 2.0, 4))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


## Naufrágio ao lado da pista: no mar, um navio pirata meio enterrado com o baú do
## tesouro da Ativos e o submarino amarelo passando; no lago, um barco a remo.
func _build_wreck(ids: PackedInt32Array, node: Node3D, reach: float, sea: bool) -> void:
	var wl := track.water_level
	var spot := Vector3.INF
	for k in 60:
		var p := _spot_beside(ids, _outside + 9.0, minf(reach * 0.6, 34.0), 7.0)
		if p != Vector3.INF and p.y < wl - (4.0 if sea else 2.2):
			spot = p
			break
	if spot == Vector3.INF:
		return
	var face := _facing(track.samples[terrain.nearest_track_index(spot.x, spot.z)] - spot) if terrain.nearest_track_index(spot.x, spot.z) >= 0 else Basis()
	var wood := Color(0.42, 0.27, 0.15)
	var dark := Color(0.25, 0.16, 0.09)
	if sea:
		var hull := []
		var tilt := Basis(Vector3.FORWARD, 0.32) * Basis(Vector3.RIGHT, -0.08)
		hull.append([_box(Vector3(3.4, 2.2, 11.0)), Transform3D(tilt, Vector3(0.0, 0.7, 0.0)), wood])
		hull.append([_box(Vector3(3.0, 0.3, 10.4)), Transform3D(tilt, tilt * Vector3(0.0, 1.85, 0.0) + Vector3(0.0, 0.7, 0.0)), dark])
		hull.append([_box(Vector3(2.6, 1.6, 3.0)), Transform3D(tilt, tilt * Vector3(0.0, 2.4, -3.6) + Vector3(0.0, 0.7, 0.0)), wood])
		hull.append([_cyl(0.18, 0.22, 7.0), Transform3D(tilt * Basis(Vector3.RIGHT, 0.4), tilt * Vector3(0.0, 4.5, 1.0) + Vector3(0.0, 0.7, 0.0)), dark])
		hull.append([_box(Vector3(4.0, 0.15, 0.15)), Transform3D(tilt, tilt * Vector3(0.0, 6.0, 1.6) + Vector3(0.0, 0.7, 0.0)), dark])
		_add(_parts(hull, _tint), Transform3D(face * Basis(Vector3.UP, 1.2), spot - Vector3.UP * 0.6), node)
		# Baú do tesouro aberto, com moedas brilhando e a plaquinha da Ativos.
		var chest_at := spot + face * Vector3(4.5, 0.0, 4.0)
		chest_at.y = terrain.height_at(chest_at.x, chest_at.z)
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(1.0, 0.8, 0.2)
		gold.metallic = 0.9
		gold.roughness = 0.25
		gold.emission_enabled = true
		gold.emission = Color(1.0, 0.7, 0.15)
		gold.emission_energy_multiplier = 0.6
		var chest := _parts([
			[_box(Vector3(1.6, 0.9, 1.0)), Transform3D(Basis(), Vector3(0.0, 0.45, 0.0)), wood],
			[_box(Vector3(1.6, 0.12, 1.0)), Transform3D(Basis(Vector3.RIGHT, -1.1), Vector3(0.0, 1.15, -0.6)), wood],
			[_box(Vector3(1.66, 0.1, 0.1)), Transform3D(Basis(), Vector3(0.0, 0.85, 0.5)), Color(0.85, 0.7, 0.25)],
		], _tint)
		var chest_node := _add(chest, Transform3D(face * Basis(Vector3.UP, 0.4), chest_at), node)
		var coins_mesh := MeshMerge.new()
		for k in 14:
			coins_mesh.append_from(_cyl(0.13, 0.13, 0.04, 10), 0, Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6)),
					Vector3(rng.randf_range(-0.6, 0.6), 0.92 + rng.randf_range(0.0, 0.1), rng.randf_range(-0.35, 0.35))))
		coins_mesh.set_material(gold)
		_add(coins_mesh.commit(), Transform3D(), chest_node, false)
		var plate := QuadMesh.new()
		plate.size = Vector2(1.1, 0.45)
		var plate_mi := _add(plate, Transform3D(Basis(), Vector3(0.0, 0.45, 0.51)), chest_node, false)
		plate_mi.material_override = TrackScenery.brand_material(WORDMARK_DARK, TrackScenery.NAVY, 1.1 / 0.45, {"logo_fill": 0.8})
		_build_submarine(node, spot, ids)
	else:
		var boat := _parts([
			[_box(Vector3(1.5, 0.6, 4.2)), Transform3D(Basis(Vector3.FORWARD, 0.5), Vector3(0.0, 0.35, 0.0)), wood],
			[_box(Vector3(1.3, 0.08, 0.35)), Transform3D(Basis(Vector3.FORWARD, 0.5), Vector3(0.1, 0.62, 0.6)), dark],
			[_box(Vector3(0.12, 0.06, 2.6)), Transform3D(Basis(Vector3.UP, 0.5), Vector3(1.3, 0.1, 0.6)), dark],
		], _tint)
		_add(boat, Transform3D(face * Basis(Vector3.UP, 0.9), spot - Vector3.UP * 0.2), node)
		# Píer de madeira na beira do lago, com o logo na ponta.
		_build_pier(ids, node)


func _build_submarine(node: Node3D, near: Vector3, ids: PackedInt32Array) -> void:
	var wl := track.water_level
	var yellow := TrackScenery.color_material(TrackScenery.YELLOW, 0.35, 0.2)
	var navy := TrackScenery.color_material(TrackScenery.NAVY, 0.4)
	var sub := Node3D.new() if Engine.is_editor_hint() else DriftingProp.new()
	sub.name = "SubmarinoAtivos"
	var body := MeshMerge.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.3
	capsule.height = 7.5
	capsule.radial_segments = 16
	capsule.rings = 6
	body.append_from(capsule, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
	body.append_from(_cyl(0.7, 0.8, 1.4, 12), 0, Transform3D(Basis(), Vector3(0.0, 1.6, 0.6)))
	body.append_from(_cyl(0.08, 0.08, 1.2, 6), 0, Transform3D(Basis(), Vector3(0.0, 2.7, 0.9)))
	body.set_material(yellow)
	var mesh := body.commit()
	var trim := MeshMerge.new()
	for side: float in [-1.0, 1.0]:
		trim.append_from(_cyl(0.32, 0.32, 0.12, 12), 0, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * 1.25, 0.2, 1.8)))
		trim.append_from(_cyl(0.32, 0.32, 0.12, 12), 0, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * 1.25, 0.2, -0.4)))
	trim.append_from(_box(Vector3(2.6, 0.12, 0.6)), 0, Transform3D(Basis(), Vector3(0.0, 0.0, -3.4)))
	trim.append_from(_box(Vector3(0.12, 1.6, 0.6)), 0, Transform3D(Basis(), Vector3(0.0, 0.0, -3.4)))
	trim.set_material(navy)
	trim.commit(mesh)
	var hull := MeshInstance3D.new()
	hull.mesh = mesh
	sub.add_child(hull)
	# A marca da Ativos dos dois lados.
	for side: float in [-1.0, 1.0]:
		var q := QuadMesh.new()
		q.size = Vector2(3.4, 1.1)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.transform = Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * 1.31, 0.1, 0.4))
		mi.material_override = TrackScenery.brand_material(WORDMARK_DARK, TrackScenery.NAVY, 3.4 / 1.1, {"logo_fill": 0.78})
		sub.add_child(mi)
	var floor_y := terrain.height_at(near.x, near.z)
	var center := Vector3(near.x, lerpf(floor_y, wl, 0.55), near.z)
	if sub is DriftingProp:
		var dp := sub as DriftingProp
		dp.orbit_center = center
		dp.orbit_radius = 16.0
		dp.orbit_speed = 0.09
		dp.bob_height = 0.5
		dp.bob_speed = 0.5
	sub.position = center + Vector3(16.0, 0.0, 0.0)
	node.add_child(sub)


## Píer de madeira entrando no lago, com a bandeira da Ativos na ponta.
func _build_pier(ids: PackedInt32Array, node: Node3D) -> void:
	var wl := track.water_level
	for k in 80:
		var i := ids[rng.randi() % ids.size()]
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var out := track.rights[i] * side
		# Procura a margem: da água para fora até o chão passar da água.
		var shore := Vector3.INF
		for d in range(int(_outside) + 20, 110, 3):
			var p := track.samples[i] + out * d
			if terrain.distance_to_track(p.x, p.z) < d - 4.0:
				break
			if terrain.height_at(p.x, p.z) > wl + 0.3:
				shore = Vector3(p.x, wl, p.z)
				break
		if shore == Vector3.INF:
			continue
		var dir := -out
		var basis := _facing(dir)
		var plank := _box(Vector3(2.4, 0.12, 0.5))
		var parts := []
		for n in 26:
			parts.append([plank, Transform3D(Basis(), Vector3(0.0, 0.9, -n * 0.55)), Color(0.55, 0.38, 0.22)])
		for n in range(0, 26, 4):
			for sx: float in [-1.1, 1.1]:
				parts.append([_cyl(0.12, 0.12, 3.0, 6), Transform3D(Basis(), Vector3(sx, -0.5, -n * 0.55)), Color(0.36, 0.24, 0.13)])
		parts.append([_cyl(0.06, 0.06, 4.0, 6), Transform3D(Basis(), Vector3(0.9, 2.9, -14.0)), Color(0.9, 0.9, 0.9)])
		parts.append([_box(Vector3(0.05, 0.9, 1.4)), Transform3D(Basis(), Vector3(0.9, 4.4, -13.3)), TrackScenery.BRAND_BLUE])
		_add(_parts(parts, _tint), Transform3D(basis, shore + dir * -1.0), node)
		return


# --- Dunas ---------------------------------------------------------------------------

func _build_dunes(s: TrackSection, preview: bool) -> void:
	var ids := _indices(s)
	if ids.is_empty():
		return
	var node := _node("Dunas")
	# Redemoinhos de areia movediça: discos que acompanham a pista (sobe e desce).
	var qs := ShaderMaterial.new()
	qs.shader = QUICKSAND_SHADER
	for pit in s.pits:
		_add(_pit_mesh(pit, qs), Transform3D(), node, false).name = "AreiaMovedica"
	# Bandeirinhas de rali em cima das muretas.
	var pole := _parts([[_cyl(0.05, 0.06, 2.6, 6), Transform3D(Basis(), Vector3(0.0, 1.3, 0.0)), Color(0.95, 0.95, 0.95)],
			[_box(Vector3(0.04, 0.6, 0.9)), Transform3D(Basis(), Vector3(0.0, 2.25, 0.45))]], _tint)
	var fx: Array[Transform3D] = []
	var fc: Array[Color] = []
	var flag_colors: Array[Color] = [TrackScenery.BRAND_BLUE, TrackScenery.YELLOW, Color(1.0, 0.45, 0.1)]
	var step := track.length / track.samples.size()
	var every := maxi(1, int(16.0 / step))
	var wall := track.road_width * 0.5 + track.shoulder_width + track.wall_thickness * 0.5
	for n in range(0, ids.size(), every):
		var i := ids[n]
		for side: float in [-1.0, 1.0]:
			var p := track.samples[i] + track.rights[i] * side * wall + Vector3.UP * track.wall_height
			fx.append(Transform3D(_facing(-track.tangents[i]), p))
			fc.append(flag_colors[(n / every + (1 if side > 0.0 else 0)) % flag_colors.size()])
	_multimesh(pole, fx, fc, "Bandeirinhas", node)
	# Esqueletos de fóssil meio enterrados.
	for k in 2:
		var p := _spot_beside(ids, _outside + 10.0, 45.0, 8.0)
		if p != Vector3.INF:
			_build_fossil(node, p)
	# Areia voando com o vento por cima das dunas.
	if not preview:
		var sand_mat := ShaderMaterial.new()
		sand_mat.shader = BUBBLE_SHADER
		sand_mat.set_shader_parameter("drop", true)
		sand_mat.set_shader_parameter("tint", Color(0.95, 0.8, 0.58, 0.32))
		for n in range(0, ids.size(), maxi(1, ids.size() / 4)):
			var i := ids[n]
			var p := GPUParticles3D.new()
			p.name = "AreiaAoVento"
			p.amount = 90
			p.lifetime = 2.6
			var pm := ParticleProcessMaterial.new()
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(34.0, 1.2, 34.0)
			pm.direction = Vector3(0.8, 0.05, 0.6)
			pm.spread = 12.0
			pm.initial_velocity_min = 7.0
			pm.initial_velocity_max = 13.0
			pm.gravity = Vector3(0.0, -0.4, 0.0)
			pm.scale_min = 0.12
			pm.scale_max = 0.45
			var fade := Gradient.new()
			fade.set_color(0, Color(1, 1, 1, 0))
			fade.add_point(0.25, Color(1, 1, 1, 1))
			fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
			var ramp := GradientTexture1D.new()
			ramp.gradient = fade
			pm.color_ramp = ramp
			p.process_material = pm
			var q := QuadMesh.new()
			q.material = sand_mat
			p.draw_pass_1 = q
			p.position = track.samples[i] + Vector3.UP * 1.2
			p.visibility_aabb = AABB(Vector3(-50, -4, -50), Vector3(100, 10, 100))
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(p)


## Disco do redemoinho em cima da pista: anéis que seguem a altura do asfalto.
func _pit_mesh(pit: Vector3, material: Material) -> ArrayMesh:
	var center_d := pit.x * track.length
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var segs := 28
	var pts := []
	for ri in rings + 1:
		var row := []
		var rr := pit.z * ri / rings
		for si in segs:
			var a := si * TAU / segs
			var along := sin(a) * rr
			var lat := pit.y + cos(a) * rr
			var p := track.get_transform_at(center_d + along, lat).origin + Vector3.UP * 0.05
			row.append([p, Vector2(0.5 + cos(a) * 0.5 * ri / rings, 0.5 + sin(a) * 0.5 * ri / rings)])
		pts.append(row)
	for ri in rings:
		for si in segs:
			var a: Array = pts[ri][si]
			var b: Array = pts[ri][(si + 1) % segs]
			var c: Array = pts[ri + 1][(si + 1) % segs]
			var d: Array = pts[ri + 1][si]
			for v: Array in [a, c, b, a, d, c]:
				st.set_normal(Vector3.UP)
				st.set_uv(v[1])
				st.add_vertex(v[0])
	st.set_material(material)
	var mesh := st.commit()
	return mesh


## Costelas e coluna de um bicho enorme, meio enterradas na areia.
func _build_fossil(node: Node3D, at: Vector3) -> void:
	var bone := Color(0.93, 0.88, 0.76)
	var parts := []
	var length := rng.randf_range(12.0, 18.0)
	var ribs := 8
	for k in ribs + 1:
		var z := -length * 0.5 + length * k / ribs
		parts.append([_sphere(0.45, 8), Transform3D(Basis(), Vector3(0.0, 2.6 - absf(z) * 0.08, z)), bone])
	for k in ribs:
		var z := -length * 0.45 + length * 0.9 * k / maxf(ribs - 1, 1)
		var h := 3.2 - absf(z) * 0.12
		for side: float in [-1.0, 1.0]:
			# Costela em 4 pedaços fazendo um arco para baixo.
			var prev := Vector3(0.0, h, z)
			for seg in 4:
				var a := (seg + 1) / 4.0 * PI * 0.55
				var p := Vector3(side * sin(a) * 2.6, h - (1.0 - cos(a)) * 3.4, z)
				var mid := (prev + p) * 0.5
				var dir := (p - prev)
				var basis := Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD)
				parts.append([_cyl(0.16, 0.2, dir.length() + 0.15, 6), Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5), mid), bone])
				prev = p
	parts.append([_sphere(1.3, 10), Transform3D(Basis().scaled(Vector3(1.0, 0.8, 1.4)), Vector3(0.0, 1.6, length * 0.5 + 1.2)), bone])
	_add(_parts(parts, _tint), Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, rng.randf_range(-0.2, 0.2)), at - Vector3.UP * 1.2), node)


# --- Gelo ----------------------------------------------------------------------------

func _build_ice(s: TrackSection) -> void:
	var ids := _indices(s)
	if ids.is_empty():
		return
	var lake := s.is_basin()
	var node := _node("LagoCongelado" if lake else "RiachoCongelado")
	var wl := track.water_level
	# Blocos de gelo empilhados.
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.7, 0.88, 1.0, 0.82)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.roughness = 0.08
	ice.metallic_specular = 0.8
	ice.rim_enabled = true
	ice.rim = 0.5
	var block := _box(Vector3(1.0, 1.0, 1.0))
	# Na pista de neve e gelo, o mesmo gelo maciço dos cristais (opaco, sem ordenar).
	block.material = _ice_material(0.5) if track.snow_track else ice
	var bx: Array[Transform3D] = []
	for k in 70:
		var p := _spot_beside(ids, _outside + 1.0, 55.0, 0.8)
		if p == Vector3.INF:
			continue
		var sc := Vector3(rng.randf_range(0.8, 2.6), rng.randf_range(0.5, 1.6), rng.randf_range(0.8, 2.2))
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		bx.append(Transform3D(b.scaled(sc), Vector3(p.x, (wl if lake else p.y) + sc.y * 0.3, p.z)))
	_multimesh(block, bx, [], "BlocosDeGelo", node, true)
	# Montes de neve na base das muretas (do lado de fora).
	var snow := _parts([[_sphere(1.0, 10), Transform3D(Basis().scaled(Vector3(1.0, 0.45, 2.2)), Vector3.ZERO)]], _tint)
	var sx: Array[Transform3D] = []
	var sc_: Array[Color] = []
	for n in range(0, ids.size(), 3):
		var i := ids[n]
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.35:
				continue
			var p := track.samples[i] + track.rights[i] * side * (_outside + rng.randf_range(0.6, 2.0))
			var y := wl if lake else terrain.height_at(p.x, p.z)
			sx.append(Transform3D(_facing(track.tangents[i]).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(p.x, y, p.z)))
			sc_.append(Color(0.95, 0.97, 1.0))
	_multimesh(snow, sx, sc_, "MontesDeNeve", node)
	# Cabanas de pesca no gelo, com o buraco e a vara.
	for k in (4 if lake else 0):
		var p := _spot_beside(ids, _outside + 8.0, 40.0, 6.0)
		if p == Vector3.INF:
			continue
		var c: Color = [Color(0.85, 0.2, 0.2), TrackScenery.BRAND_BLUE, Color(0.95, 0.7, 0.15)][k % 3]
		var hut := _parts([
			[_box(Vector3(2.4, 2.0, 2.0)), Transform3D(Basis(), Vector3(0.0, 1.0, 0.0)), c],
			[_box(Vector3(2.7, 0.15, 1.5)), Transform3D(Basis(Vector3.FORWARD, 0.0) * Basis(Vector3.RIGHT, 0.5), Vector3(0.0, 2.25, 0.55)), Color(0.95, 0.97, 1.0)],
			[_box(Vector3(2.7, 0.15, 1.5)), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.0, 2.25, -0.55)), Color(0.95, 0.97, 1.0)],
			[_box(Vector3(0.8, 1.4, 0.05)), Transform3D(Basis(), Vector3(0.4, 0.7, 1.01)), Color(0.3, 0.2, 0.12)],
			[_cyl(0.45, 0.45, 0.03, 12), Transform3D(Basis(), Vector3(-0.4, 0.01, 2.0)), Color(0.05, 0.12, 0.2)],
			[_cyl(0.02, 0.03, 2.2, 5), Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(-0.4, 0.8, 1.4)), Color(0.3, 0.2, 0.12)],
		], _tint)
		_add(hut, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, wl, p.z)), node)
	# Pinguins patinando em roda.
	var px: Array[Transform3D] = []
	var pc: Array[Color] = []
	var pcu: Array[Color] = []
	for k in 4:
		var p := _spot_beside(ids, _outside + 10.0, 42.0, 8.0)
		if p == Vector3.INF:
			continue
		var white: Array[Color] = [Color.WHITE]
		_flock(px, pc, pcu, Vector3(p.x, wl if lake else p.y, p.z), rng.randi_range(3, 6), Vector2(2.5, 5.0), 1.6, 0.8, 0.0, 0.06, white)
	_multimesh(_creature_mesh(Creature.PINGUIM), px, pc, "Pinguins", node, true, pcu)
	if track.snow_track:
		_build_ice_crystals(ids, node, lake)
		if not lake:
			_build_ice_arch(ids, node)


func _ice_material(top: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ICE_CRYSTAL_SHADER
	m.set_shader_parameter("top", top)
	return m


## Cristal de gelo facetado: prisma de seis lados (raio 1, um pouco mais fino no alto)
## de y = -0,3 a 1 e ponta em pirâmide comprida até 2,1.
static func _crystal_mesh(material: Material) -> ArrayMesh:
	var md := Track.MeshData.new()
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for k in 6:
		var a := TAU * k / 6.0
		low.append(Vector3(cos(a), -0.3, sin(a)))
		high.append(Vector3(cos(a) * 0.8, 1.0, sin(a) * 0.8))
	var tip := Vector3(0.1, 2.1, -0.06)
	for k in 6:
		var n := (k + 1) % 6
		_flat_quad(md, low[k], low[n], high[n], high[k])
		_flat_tri(md, high[k], high[n], tip)
	return md.to_mesh(material)


## Triângulo com normal própria (facetado), virado para fora do eixo Y.
static func _flat_tri(md: Track.MeshData, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	var mid := (a + b + c) / 3.0
	if n.dot(Vector3(mid.x, 0.0, mid.z)) < 0.0:
		n = -n
	var i := md.add_vertex(a, n, Vector2.ZERO)
	md.add_vertex(b, n, Vector2.ZERO)
	md.add_vertex(c, n, Vector2.ZERO)
	md.add_tri(i, i + 1, i + 2, n)


static func _flat_quad(md: Track.MeshData, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(d - a).normalized()
	var mid := (a + b + c + d) * 0.25
	if n.dot(Vector3(mid.x, 0.0, mid.z)) < 0.0:
		n = -n
	var i := md.add_vertex(a, n, Vector2.ZERO)
	md.add_vertex(b, n, Vector2.ZERO)
	md.add_vertex(c, n, Vector2.ZERO)
	md.add_vertex(d, n, Vector2.ZERO)
	md.add_tri(i, i + 1, i + 2, n)
	md.add_tri(i, i + 2, i + 3, n)


## Tufos de cristais de gelo gigantes (1,5 a 6 m) nas margens do rio congelado.
func _build_ice_crystals(ids: PackedInt32Array, node: Node3D, lake: bool) -> void:
	var mesh := _crystal_mesh(_ice_material(2.1))
	var xs: Array[Transform3D] = []
	var clusters := int(ids.size() * (0.22 if lake else 0.3))
	for k in clusters:
		var p := _spot_beside(ids, _outside + 2.5, 30.0 if lake else 24.0, 2.0)
		if p == Vector3.INF:
			continue
		var y := track.water_level if lake and p.y < track.water_level else p.y
		var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		for c in rng.randi_range(3, 6):
			var h := rng.randf_range(1.6, 5.2) * (1.0 if c == 0 else rng.randf_range(0.35, 0.75))
			var r := h * rng.randf_range(0.07, 0.11)
			# Em leque: os menores saem tortos do pé do maior.
			var out := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
			var axis := (lean if c == 0 else out).cross(Vector3.UP).normalized()
			var tilt := Basis(axis, -rng.randf_range(0.05, 0.2) if c == 0 else -rng.randf_range(0.3, 0.75))
			var b := tilt * Basis(Vector3.UP, rng.randf() * TAU)
			var at := Vector3(p.x, y, p.z) + out * rng.randf_range(0.2, 0.9) * (0.0 if c == 0 else 1.0)
			xs.append(Transform3D(b.scaled(Vector3(r, h, r)), at))
	_multimesh(mesh, xs, [], "CristaisDeGelo", node, true)


## Arco de gelo glacial sobre o meio do riacho: um tubo irregular de margem a margem,
## alto o bastante para a câmera passar por baixo (sem colisão: os pés ficam fora dos
## montes de neve).
func _build_ice_arch(ids: PackedInt32Array, node: Node3D) -> void:
	var i := ids[ids.size() / 2]
	var center := track.samples[i]
	var right := track.rights[i]
	var fwd := track.tangents[i]
	var span := _outside + 3.5
	var feet: Array[float] = []
	for side: float in [-1.0, 1.0]:
		var f := center + right * side * span
		feet.append(terrain.height_at(f.x, f.z) - 0.6)
	var rise := 10.5
	var md := Track.MeshData.new()
	var rings := 28
	var sides := 9
	for r in rings + 1:
		var t := float(r) / rings
		var th := PI * t
		var base_y := lerpf(feet[0], feet[1], t)
		var c := center + right * (-cos(th) * span) + Vector3.UP * (base_y - center.y + sin(th) * rise)
		# Direção do arco e os dois eixos da seção (um deles ao longo da pista).
		var along_arc := (right * (sin(th) * span) + Vector3.UP * (cos(th) * rise + (feet[1] - feet[0]) / PI)).normalized()
		var ax := fwd
		var ay := along_arc.cross(ax).normalized()
		# Mais grosso nos pés, largo ao longo da pista (uma laje de geleira) e irregular
		# (gelo derretido e recongelado).
		var thick := lerpf(1.1, 2.4, pow(absf(cos(th)), 3.0)) * (1.0 + 0.22 * sin(t * 17.0) + 0.12 * sin(t * 41.0))
		var sway := ax * (0.6 * sin(t * 7.0)) + ay * (0.25 * sin(t * 13.0))
		for k in sides + 1:
			var a := TAU * k / sides
			var bumpy := 1.0 + 0.28 * sin(a * 3.0 + t * 11.0) + 0.16 * sin(a * 5.0 - t * 23.0) + 0.08 * sin(a * 7.0 + t * 37.0)
			var dir := (ax * cos(a) * 1.7 + ay * sin(a)).normalized()
			md.add_vertex(c + sway + dir * thick * bumpy, dir, Vector2(t, float(k) / sides))
	for r in rings:
		for k in sides:
			var a := r * (sides + 1) + k
			var b := a + sides + 1
			md.add_tri(a, a + 1, b, md.normals[a])
			md.add_tri(a + 1, b + 1, b, md.normals[a])
	# Pingentes de gelo pendurados na parte de baixo do arco.
	var cone := _crystal_mesh(_ice_material(2.1))
	var xs: Array[Transform3D] = []
	for k in 26:
		var t := rng.randf_range(0.2, 0.8)
		var th := PI * t
		var p := center + right * (-cos(th) * span) + Vector3.UP * (lerpf(feet[0], feet[1], t) - center.y + sin(th) * rise - 1.1)
		p += fwd * rng.randf_range(-0.9, 0.9)
		var h := rng.randf_range(0.4, 1.1) * (0.6 + 0.4 * sin(th))
		var b := Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, rng.randf() * TAU)
		xs.append(Transform3D(b.scaled(Vector3(h * 0.14, h, h * 0.14)), p))
	_add(md.to_mesh(_ice_material(center.y + rise + 2.0)), Transform3D.IDENTITY, node).name = "ArcoDeGelo"
	_multimesh(cone, xs, [], "Pingentes", node, true)


# --- Vale ----------------------------------------------------------------------------

## Paredão de pedra embaixo do fim do asfalto (nas duas beiras do vão) e tampas nas
## pontas das muretas.
func _build_gap_edges(span: Dictionary) -> void:
	var count := track.samples.size()
	var node := _node("BeiraDoVale")
	var stone := _stone_material()
	var cap := TrackScenery.color_material(Color(0.9, 0.9, 0.92), 0.6)
	var width := (_outside + 0.6) * 2.0
	for edge: Array in [[(int(span.from) - 1 + count) % count, 1.0], [(int(span.to) + 1) % count, -1.0]]:
		var i: int = edge[0]
		var gap_dir: float = edge[1]
		var t := track.tangents[i]
		t.y = 0.0
		t = t.normalized()
		var p := track.samples[i]
		var basis := _facing(t)
		var wall := _box(Vector3(width, 16.0, 3.0))
		wall.material = stone
		var xf := Transform3D(basis, p - t * gap_dir * 1.5 + Vector3.DOWN * 8.05)
		_add(wall, xf, node)
		if track.with_collision:
			# Quem chega baixo demais bate no paredão (e cai no vale). Gerando numa thread,
			# o corpo só é criado depois, na thread principal (Track.physics_job).
			track.physics_job(func() -> void:
				var body := StaticBody3D.new()
				body.name = "Paredao"
				body.add_to_group("wall")
				body.transform = xf
				var col := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3(width, 16.0, 3.0)
				col.shape = shape
				body.add_child(col)
				node.add_child(body))
		for side: float in [-1.0, 1.0]:
			var c := _box(Vector3(track.wall_thickness + 0.1, track.wall_height + 0.1, 0.25))
			c.material = cap
			var at := p + track.rights[i] * side * (track.road_width * 0.5 + track.shoulder_width + track.wall_thickness * 0.5)
			_add(c, Transform3D(basis, at + Vector3.UP * (track.wall_height * 0.5 - 0.05) - t * gap_dir * 0.1), node, false)


func _build_valley(span: Dictionary, path: Path3D, preview: bool) -> void:
	var sec: TrackSection = span.section
	var node := _node("Vale")
	# Linha do vale a cada 4 m (no espaço da pista).
	var line := PackedVector3Array()
	var total := path.curve.get_baked_length()
	var steps := maxi(2, int(total / 4.0))
	for k in steps + 1:
		line.append(path.transform * path.curve.sample_baked(total * k / steps))
	var wl := track.water_level
	var floor_y := sec.valley_floor
	var water_y := maxf(floor_y, wl) if floor_y < wl else floor_y
	# Onde a pista cruza o vale (na linha) e para que lado ele desce.
	var mid_i := (int(span.from) + int(span.to)) / 2
	var cross := track.samples[mid_i]
	var cross_k := 0
	var best := INF
	for k in line.size():
		var d := Vector2(line[k].x - cross.x, line[k].z - cross.z).length()
		if d < best:
			best = d
			cross_k = k
	var half_top := sec.valley_width * 0.5
	var snow := track.scenery == TrackTheme.Scenery.NEVE
	# Cachoeira na cabeceira.
	var head := line[0]
	var head_dir := (line[mini(3, line.size() - 1)] - line[0])
	head_dir.y = 0.0
	head_dir = head_dir.normalized()
	if not _build_waterfall(node, head - head_dir * (half_top + 10.0), head_dir, half_top + 10.0, water_y, snow, preview):
		# Cabeceira sem paredão (na ilha o vale abre para o mar): a cachoeira cai do
		# penhasco ao lado da ponta da pista mais alta.
		_cliff_waterfall(node, span, water_y, snow, preview)
	# Pedras no rio e nas margens.
	var rx: Array[Transform3D] = []
	var rc: Array[Color] = []
	var rock_tone := Color(0.62, 0.36, 0.24) if track.scenery == TrackTheme.Scenery.DESERTO else Color(0.5, 0.49, 0.47)
	for k in 90:
		var li := rng.randi_range(0, line.size() - 1)
		var l := line[li]
		var side_dir := Vector3(-head_dir.z, 0.0, head_dir.x) if li == 0 else _side_of(line, li)
		var off := rng.randf_range(-sec.valley_bed * 0.7, sec.valley_bed * 0.7)
		var p := l + side_dir * off
		var y := terrain.height_at(p.x, p.z)
		if terrain.distance_to_track(p.x, p.z) < _outside + 2.0:
			continue
		var sc := rng.randf_range(0.8, 3.2)
		rx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.5, 0.9), sc)), Vector3(p.x, y - 0.3 * sc, p.z)))
		var v := rng.randf_range(0.85, 1.15)
		rc.append(Color(rock_tone.r * v, rock_tone.g * v, rock_tone.b * v))
	_multimesh(TrackProps._rock_mesh(_tint), rx, rc, "PedrasDoRio", node, true)
	# Árvores no fundo e nas encostas mais suaves.
	_build_valley_trees(node, line, half_top, water_y)
	# Bichos.
	var bx: Array[Transform3D] = []
	var bc: Array[Color] = []
	var bcu: Array[Color] = []
	var bird_colors: Array[Color]
	match track.scenery:
		TrackTheme.Scenery.PRAIA:
			bird_colors = [Color(0.97, 0.97, 0.97)]
		TrackTheme.Scenery.DESERTO:
			bird_colors = [Color(0.15, 0.12, 0.1)]
		TrackTheme.Scenery.NEVE:
			bird_colors = [Color(0.35, 0.25, 0.18)]
		_:
			bird_colors = [Color(0.96, 0.96, 0.98), Color(0.2, 0.2, 0.25)]
	var rim_y := cross.y
	for k in 3:
		var li := clampi(cross_k + rng.randi_range(-30, 40), 0, line.size() - 1)
		var c := line[li]
		c.y = lerpf(water_y, rim_y, rng.randf_range(0.35, 0.8))
		_flock(bx, bc, bcu, c, rng.randi_range(3, 6), Vector2(10.0, 22.0), rng.randf_range(6.0, 9.0),
				2.2 if track.scenery == TrackTheme.Scenery.DESERTO else 1.4, 3.0, 1.5, bird_colors)
	_multimesh(_creature_mesh(Creature.PASSARO), bx, bc, "Passaros", node, false, bcu)
	match track.scenery:
		TrackTheme.Scenery.PRAIA:
			_build_sea_stacks(node, line, cross_k, half_top, water_y)
			var dx: Array[Transform3D] = []
			var dc: Array[Color] = []
			var dcu: Array[Color] = []
			var white: Array[Color] = [Color.WHITE]
			for k in 2:
				var li := clampi(cross_k + rng.randi_range(12, 40) * (1 if k == 0 else -1), 0, line.size() - 1)
				var c := line[li]
				c.y = wl
				_flock(dx, dc, dcu, c, 3, Vector2(9.0, 13.0), 7.0, 1.0, 0.3, 2.2, white)
			_multimesh(_creature_mesh(Creature.GOLFINHO), dx, dc, "Golfinhos", node, false, dcu)
		TrackTheme.Scenery.DESERTO:
			_build_hoodoos(node, line, cross_k, half_top, water_y)
			_build_stone_arch(node, line, mini(cross_k + 22, line.size() - 1), sec, water_y)
		TrackTheme.Scenery.NEVE:
			_build_cable_car(node, line, mini(cross_k + 24, line.size() - 1), half_top)
		_:
			_build_rope_bridge(node, line, mini(cross_k + 20, line.size() - 1), half_top, water_y)


## Direção de lado (no plano) da linha do vale no ponto `k`.
static func _side_of(line: PackedVector3Array, k: int) -> Vector3:
	var a := line[maxi(k - 1, 0)]
	var b := line[mini(k + 1, line.size() - 1)]
	var d := b - a
	d.y = 0.0
	d = d.normalized()
	return Vector3(-d.z, 0.0, d.x)


## Cachoeira do penhasco ao lado de uma das pontas da pista (a mais alta), caindo
## para dentro do vão.
func _cliff_waterfall(node: Node3D, span: Dictionary, water_y: float, frozen: bool, preview: bool) -> void:
	var count := track.samples.size()
	var best := Vector3.INF
	var best_into := Vector3.ZERO
	var best_drop := 6.0
	# A beira do pouso primeiro: quem plana vê a cachoeira de frente, chegando.
	for edge: Array in [[(int(span.to) + 1) % count, -1.0], [(int(span.from) - 1 + count) % count, 1.0]]:
		var i: int = edge[0]
		var t := track.tangents[i]
		t.y = 0.0
		t = t.normalized() * float(edge[1])
		for side: float in [-1.0, 1.0]:
			var spot := track.samples[i] + track.rights[i] * side * (_outside + 9.0) - t * 4.0
			var drop := terrain.height_at(spot.x, spot.z) - water_y
			if drop > best_drop:
				best_drop = drop
				best = spot
				best_into = t
		if best != Vector3.INF:
			break
	if best != Vector3.INF:
		_build_waterfall(node, best, best_into, 45.0, water_y, frozen, preview)


## Cachoeira descendo do alto do paredão até a água (ou cascata congelada), com névoa
## embaixo e, no campo e na praia, um arco-íris. A encosta é seguida a partir de
## `origin` andando `reach` m na direção `into`. Devolve false se ali não há queda.
func _build_waterfall(node: Node3D, origin: Vector3, into: Vector3, reach: float, water_y: float, frozen: bool, preview: bool) -> bool:
	# Do alto do paredão descendo até a água, rente à pedra.
	var profile := PackedVector3Array()
	var rim := -INF
	for k in 60:
		var p := origin + into * (reach * k / 59.0)
		var y := terrain.height_at(p.x, p.z)
		rim = maxf(rim, y)
		profile.append(Vector3(p.x, y, p.z))
	# Começa onde a encosta já é paredão e termina na água.
	var top_k := 0
	for k in profile.size():
		if profile[k].y < rim - 1.0:
			top_k = maxi(k - 1, 0)
			break
	var pts := PackedVector3Array()
	for k in range(top_k, profile.size()):
		var p := profile[k] + into * 0.9 + Vector3.UP * 0.4
		pts.append(p)
		if profile[k].y <= water_y + 0.2:
			break
	if pts.size() < 3:
		return false
	var height := pts[0].y - water_y
	if height < 4.0:
		return false
	var side := Vector3(-into.z, 0.0, into.x)
	var width := clampf(height * 0.55, 8.0, 18.0) * (1.4 if frozen else 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := 0.0
	var rows := []
	for k in pts.size():
		if k > 0:
			v += pts[k].distance_to(pts[k - 1])
		var p := pts[k]
		if k == pts.size() - 1:
			p.y = water_y
		rows.append([p - side * width * 0.5, p + side * width * 0.5, v])
	for k in rows.size() - 1:
		var a: Array = rows[k]
		var b: Array = rows[k + 1]
		var n := into
		for q: Array in [[a[0], 0.0, a[2]], [a[1], 1.0, a[2]], [b[1], 1.0, b[2]], [a[0], 0.0, a[2]], [b[1], 1.0, b[2]], [b[0], 0.0, b[2]]]:
			st.set_normal(n)
			st.set_uv(Vector2(q[1], q[2]))
			st.add_vertex(q[0])
	var mat := ShaderMaterial.new()
	mat.shader = WATERFALL_SHADER
	mat.set_shader_parameter("frozen", frozen)
	mat.set_shader_parameter("height", v)
	st.set_material(mat)
	var fall := _add(st.commit(), Transform3D(), node, false)
	fall.name = "Cachoeira"
	if frozen or preview:
		return true
	var bottom := Vector3(pts[pts.size() - 1].x, water_y, pts[pts.size() - 1].z) + into * 2.0
	# Névoa na base.
	var mist_mat := ShaderMaterial.new()
	mist_mat.shader = BUBBLE_SHADER
	mist_mat.set_shader_parameter("drop", true)
	mist_mat.set_shader_parameter("tint", Color(1.0, 1.0, 1.0, 0.22))
	var mist := GPUParticles3D.new()
	mist.name = "NevoaDaCachoeira"
	mist.amount = 34
	mist.lifetime = 3.2
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.45, 0.5, 3.0)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0.0, 0.25, 0.0)
	pm.scale_min = 2.5
	pm.scale_max = 5.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	mist.process_material = pm
	var q := QuadMesh.new()
	q.material = mist_mat
	mist.draw_pass_1 = q
	mist.transform = Transform3D(_facing(into), bottom)
	mist.visibility_aabb = AABB(Vector3(-20, -4, -20), Vector3(40, 24, 40))
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mist)
	if track.scenery == TrackTheme.Scenery.CAMPO or track.scenery == TrackTheme.Scenery.PRAIA:
		_build_rainbow(node, bottom + into * 6.0, into, height)
	return true


func _build_rainbow(node: Node3D, at: Vector3, facing: Vector3, height: float) -> void:
	var radius := clampf(height * 0.75, 10.0, 26.0)
	var band := radius * 0.16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 40
	for k in segs:
		var a0 := PI * k / segs
		var a1 := PI * (k + 1) / segs
		var quad := []
		for a: float in [a0, a1]:
			var dir := Vector3(cos(a), sin(a), 0.0)
			quad.append([dir * radius, Vector2(a / PI, 0.0)])
			quad.append([dir * (radius - band), Vector2(a / PI, 1.0)])
		for idx: int in [0, 2, 3, 0, 3, 1]:
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	var mat := ShaderMaterial.new()
	mat.shader = RAINBOW_SHADER
	st.set_material(mat)
	var mi := _add(st.commit(), Transform3D(_facing(facing), at + Vector3.DOWN * radius * 0.2), node, false)
	mi.name = "ArcoIris"


func _build_valley_trees(node: Node3D, line: PackedVector3Array, half_top: float, water_y: float) -> void:
	var mesh: Mesh
	match track.scenery:
		TrackTheme.Scenery.PRAIA:
			mesh = TrackProps._palm_mesh()
		TrackTheme.Scenery.DESERTO:
			mesh = TrackProps._cactus_mesh()
		TrackTheme.Scenery.NEVE:
			mesh = TrackScenery._pine_mesh(1.0)
		_:
			mesh = TrackScenery._broadleaf_mesh()
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	var tries := 0
	var target := 90 if track.scenery == TrackTheme.Scenery.NEVE else 60
	while xs.size() < target and tries < 900:
		tries += 1
		var li := rng.randi_range(0, line.size() - 1)
		var p := line[li] + _side_of(line, li) * rng.randf_range(-half_top - 25.0, half_top + 25.0)
		if terrain.distance_to_track(p.x, p.z) < _outside + 4.0:
			continue
		var y := terrain.height_at(p.x, p.z)
		if y < water_y + 0.5 or absf(terrain.height_at(p.x + 2.0, p.z) - y) > 1.6 or absf(terrain.height_at(p.x, p.z + 2.0) - y) > 1.6:
			continue
		var sc := rng.randf_range(0.8, 1.35)
		xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, y - 0.1, p.z)))
		match track.scenery:
			TrackTheme.Scenery.NEVE:
				cs.append(Color.from_hsv(rng.randf_range(0.36, 0.42), rng.randf_range(0.55, 0.75), rng.randf_range(0.32, 0.46)))
			TrackTheme.Scenery.DESERTO:
				cs.append(Color.from_hsv(rng.randf_range(0.28, 0.36), rng.randf_range(0.45, 0.6), rng.randf_range(0.45, 0.6)))
			_:
				cs.append(Color.from_hsv(rng.randf_range(0.22, 0.33), rng.randf_range(0.6, 0.85), rng.randf_range(0.5, 0.75)))
	_multimesh(mesh, xs, cs, "ArvoresDoVale", node, true)


## Rochas altas saindo do mar na enseada, com um tufo verde no alto.
func _build_sea_stacks(node: Node3D, line: PackedVector3Array, cross_k: int, half_top: float, water_y: float) -> void:
	var rock := Color(0.66, 0.58, 0.48)
	for k in 6:
		var li := clampi(cross_k + rng.randi_range(8, 70) * (1 if rng.randf() < 0.7 else -1), 0, line.size() - 1)
		var p := line[li] + _side_of(line, li) * rng.randf_range(-half_top * 0.5, half_top * 0.5)
		if terrain.distance_to_track(p.x, p.z) < _outside + 10.0:
			continue
		var floor := terrain.height_at(p.x, p.z)
		var h := rng.randf_range(10.0, 22.0)
		var r := rng.randf_range(2.5, 5.0)
		var parts := []
		var y := floor
		var segs := 4
		for s in segs:
			var seg_h := (h + water_y - floor) / segs
			var rr := r * (1.0 - s * 0.12) * rng.randf_range(0.85, 1.1)
			parts.append([_cyl(rr * 0.9, rr, seg_h, 9), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.4, 0.4), y + seg_h * 0.5, rng.randf_range(-0.4, 0.4))), rock])
			y += seg_h
		parts.append([_sphere(r * 0.85, 9), Transform3D(Basis().scaled(Vector3(1.0, 0.35, 1.0)), Vector3(0.0, y, 0.0)), Color(0.3, 0.6, 0.2)])
		_add(_parts(parts, _tint), Transform3D(Basis(), Vector3(p.x, 0.0, p.z)), node)
	# Barco encalhado na areia da enseada.
	for k in 40:
		var li := clampi(cross_k + rng.randi_range(-25, 25), 0, line.size() - 1)
		var p := line[li] + _side_of(line, li) * rng.randf_range(-half_top, half_top)
		var y := terrain.height_at(p.x, p.z)
		if y < water_y + 0.2 or y > water_y + 2.5 or terrain.distance_to_track(p.x, p.z) < _outside + 8.0:
			continue
		var wood := Color(0.5, 0.33, 0.2)
		var boat := _parts([
			[_box(Vector3(2.4, 1.2, 7.0)), Transform3D(Basis(Vector3.FORWARD, 0.35), Vector3(0.0, 0.5, 0.0)), wood],
			[_box(Vector3(2.0, 0.1, 6.4)), Transform3D(Basis(Vector3.FORWARD, 0.35), Vector3(0.2, 1.1, 0.0)), Color(0.85, 0.85, 0.82)],
			[_cyl(0.1, 0.12, 5.0, 6), Transform3D(Basis(Vector3.FORWARD, 0.35), Vector3(-0.8, 3.2, 0.5)), Color(0.35, 0.22, 0.12)],
			[_box(Vector3(0.05, 2.6, 2.4)), Transform3D(Basis(Vector3.FORWARD, 0.35), Vector3(-0.9, 3.6, 0.0)), TrackScenery.BRAND_BLUE],
		], _tint)
		_add(boat, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y - 0.3, p.z)), node)
		break


## Torres de rocha (pedras empilhadas) no fundo e nas encostas do cânion.
func _build_hoodoos(node: Node3D, line: PackedVector3Array, cross_k: int, half_top: float, water_y: float) -> void:
	var tones: Array[Color] = [Color(0.85, 0.48, 0.28), Color(0.72, 0.38, 0.22), Color(0.92, 0.66, 0.45)]
	var placed := 0
	for k in 80:
		if placed >= 9:
			break
		var li := clampi(cross_k + rng.randi_range(-60, 60), 0, line.size() - 1)
		var p := line[li] + _side_of(line, li) * rng.randf_range(-half_top * 0.9, half_top * 0.9)
		if terrain.distance_to_track(p.x, p.z) < _outside + 14.0:
			continue
		var y := terrain.height_at(p.x, p.z)
		if y < water_y + 0.4:
			continue
		var parts := []
		var h := 0.0
		var r := rng.randf_range(1.4, 2.6)
		for s in rng.randi_range(3, 5):
			var seg := rng.randf_range(2.0, 3.6)
			var rr := r * rng.randf_range(0.6, 1.0)
			parts.append([_sphere(1.0, 9), Transform3D(Basis().scaled(Vector3(rr, seg * 0.6, rr)), Vector3(0.0, h + seg * 0.5, 0.0)), tones[s % tones.size()]])
			h += seg * 0.9
		parts.append([_cyl(r * 1.1, r * 0.9, 0.9, 9), Transform3D(Basis(), Vector3(0.0, h + 0.3, 0.0)), Color(0.55, 0.3, 0.18)])
		_add(_parts(parts, _tint), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y - 0.5, p.z)), node)
		placed += 1


## Arco de pedra natural por cima do rio, um pouco depois de onde a pista cruza.
func _build_stone_arch(node: Node3D, line: PackedVector3Array, k: int, sec: TrackSection, water_y: float) -> void:
	var c := line[k]
	var side := _side_of(line, k)
	var span := sec.valley_bed * 0.5 + 8.0
	var a := c - side * span
	var b := c + side * span
	var ya := terrain.height_at(a.x, a.z)
	var yb := terrain.height_at(b.x, b.z)
	var base_y := maxf(water_y, minf(ya, yb))
	var rise := span * 1.1
	var parts := []
	var tone := Color(0.82, 0.45, 0.26)
	var segs := 16
	for s in segs + 1:
		var t := float(s) / segs
		var ang := PI * t
		var p := c + side * (-cos(ang) * span) + Vector3.UP * (base_y + sin(ang) * rise - c.y)
		var thick := lerpf(3.6, 2.4, sin(ang))
		parts.append([_sphere(1.0, 8), Transform3D(Basis(Vector3.UP, s * 0.7).scaled(Vector3(thick, thick * 0.8, thick * 1.2)), p - c), tone.darkened(0.1 * (s % 3))])
	_add(_parts(parts, _tint), Transform3D(Basis(), c), node).name = "ArcoDePedra"


## Ponte pênsil de madeira atravessando o vale (de uma beira à outra), mais à frente.
func _build_rope_bridge(node: Node3D, line: PackedVector3Array, k: int, half_top: float, water_y: float) -> void:
	var c := line[k]
	var side := _side_of(line, k)
	var a := c - side * (half_top + 6.0)
	var b := c + side * (half_top + 6.0)
	a.y = terrain.height_at(a.x, a.z)
	b.y = terrain.height_at(b.x, b.z)
	if a.y < water_y + 4.0 or b.y < water_y + 4.0:
		return
	var sag := minf(a.y, b.y) - water_y
	sag = clampf(sag * 0.3, 2.0, 9.0)
	var basis := _facing(side)
	var wood := Color(0.55, 0.37, 0.2)
	var rope := Color(0.75, 0.62, 0.42)
	var parts := []
	var length := a.distance_to(b)
	var planks := int(length / 0.9)
	var deck := func(t: float) -> Vector3:
		return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
	for n in planks:
		var t := (n + 0.5) / planks
		parts.append([_box(Vector3(2.2, 0.1, 0.6)), Transform3D(basis, deck.call(t) - c), wood])
	for n in 24:
		var t0 := n / 24.0
		var t1 := (n + 1) / 24.0
		for sx: float in [-1.1, 1.1]:
			var p0: Vector3 = deck.call(t0) + basis.x * sx + Vector3.UP * 1.0
			var p1: Vector3 = deck.call(t1) + basis.x * sx + Vector3.UP * 1.0
			var dir := p1 - p0
			parts.append([_cyl(0.04, 0.04, dir.length(), 5), Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), (p0 + p1) * 0.5 - c), rope])
	for end: Vector3 in [a, b]:
		for sx: float in [-1.1, 1.1]:
			parts.append([_cyl(0.15, 0.18, 2.4, 6), Transform3D(Basis(), end + basis.x * sx + Vector3.UP * 0.9 - c), wood])
	_add(_parts(parts, _tint), Transform3D(Basis(), c), node).name = "PontePensil"


## Teleférico atravessando o vale: uma torre em cada beira, os cabos e duas cabines
## (azul e amarela, com o logo) indo e vindo.
func _build_cable_car(node: Node3D, line: PackedVector3Array, k: int, half_top: float) -> void:
	var c := line[k]
	var side := _side_of(line, k)
	var a := c - side * (half_top + 14.0)
	var b := c + side * (half_top + 14.0)
	a.y = terrain.height_at(a.x, a.z)
	b.y = terrain.height_at(b.x, b.z)
	var tower_h := 16.0
	var steel := TrackScenery.color_material(Color(0.32, 0.34, 0.4), 0.5, 0.5)
	var tower := MeshMerge.new()
	tower.append_from(_box(Vector3(1.2, tower_h, 1.2)), 0, Transform3D(Basis(), Vector3(0.0, tower_h * 0.5, 0.0)))
	tower.append_from(_box(Vector3(5.0, 0.6, 1.0)), 0, Transform3D(Basis(), Vector3(0.0, tower_h, 0.0)))
	tower.set_material(steel)
	var tower_mesh := tower.commit()
	var basis := _facing(side)
	for end: Vector3 in [a, b]:
		_add(tower_mesh, Transform3D(basis.rotated(Vector3.UP, PI * 0.5), end), node)
	var top_a := a + Vector3.UP * tower_h
	var top_b := b + Vector3.UP * tower_h
	var cable_mat := TrackScenery.color_material(Color(0.15, 0.15, 0.17), 0.5)
	var cables := MeshMerge.new()
	for off: float in [-2.0, 2.0]:
		var o := basis.x * off
		var dir := top_b - top_a
		cables.append_from(_cyl(0.06, 0.06, dir.length(), 5), 0,
				Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), (top_a + top_b) * 0.5 + o))
	cables.set_material(cable_mat)
	_add(cables.commit(), Transform3D(), node, false)
	var colors: Array[Color] = [TrackScenery.BRAND_BLUE, TrackScenery.YELLOW]
	for n in 2:
		var cabin := Node3D.new() if Engine.is_editor_hint() else CABLE_CAR.new()
		cabin.name = "Cabine%d" % (n + 1)
		var body := _parts([
			[_box(Vector3(2.2, 2.0, 2.6)), Transform3D(Basis(), Vector3(0.0, -2.6, 0.0)), colors[n]],
			[_box(Vector3(2.3, 0.7, 2.7)), Transform3D(Basis(), Vector3(0.0, -2.2, 0.0)), Color(0.75, 0.88, 1.0)],
			[_cyl(0.05, 0.05, 1.6, 5), Transform3D(Basis(), Vector3(0.0, -0.8, 0.0)), Color(0.2, 0.2, 0.22)],
			[_box(Vector3(0.6, 0.3, 0.6)), Transform3D(Basis(), Vector3.ZERO), Color(0.2, 0.2, 0.22)],
		], _tint)
		var mi := MeshInstance3D.new()
		mi.mesh = body
		cabin.add_child(mi)
		var o := basis.x * (2.0 if n == 0 else -2.0)
		if cabin is CableCar:
			var cc := cabin as CableCar
			cc.from = top_a + o
			cc.to = top_b + o
			cc.phase = 0.0 if n == 0 else 0.5
		cabin.position = (top_a + top_b) * 0.5 + o
		node.add_child(cabin)
