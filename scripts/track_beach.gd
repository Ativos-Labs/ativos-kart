@tool
class_name TrackBeach
extends RefCounted
## Praia de areia branca (Track.beach_track), sempre com a marca da Ativos:
## - cercas de corda com postes brancos no lugar das muretas (a colisão continua a das
##   muretas, invisíveis) e, no baixio (TrackSection RASO), linhas de boias coloridas;
##   placas de madeira com a marca da Ativos penduradas na cerca de tempos em tempos;
## - largada com um portal de bambu, telhado de sapê e a placa da Ativos;
## - vila de quiosques de sapê com vasos de flores perto da largada, palafitas (casinhas
##   em cima de estacas) ao lado das passarelas, guarda-sóis grandes listrados com
##   espreguiçadeiras e bandeirinhas coloridas penduradas na reta da largada;
## - um arco de pedra natural por cima da pista (com cipós pendurados e um coqueiro no
##   alto) e ilhotas de pedra com coqueiros no mar;
## - na trilha da mata (TrackSection SELVA): cerca de madeira escura de duas traves,
##   murinhos de pedra com grama e flores vermelhas em cima e a mata fechada dos dois
##   lados (árvores grandes, coqueiros, bananeiras, samambaias e moitas floridas).

const THATCH_SHADER := preload("res://shaders/thatch.gdshader")
const ROCK_SHADER := preload("res://shaders/beach_rock.gdshader")
const STONE_SHADER := preload("res://shaders/stone.gdshader")

## Distância entre os postes da cerca (m) e altura da corda.
const POST_SPACING := 4.0
const ROPE_HEIGHT := 0.86
const ROPE_SAG := 0.2
## Uma placa da Ativos na cerca a cada tantos metros (nos dois lados).
const SIGN_SPACING := 96.0
const WHITE := Color(0.88, 0.87, 0.83)
const PENNANTS: Array[Color] = [Color("263dbf"), Color("ffd21a"), Color("ef2b2d"), Color(0.97, 0.97, 0.97),
		Color(0.15, 0.75, 0.85), Color(1.0, 0.55, 0.15)]

var track: Track
var terrain: TrackTerrain
var root: Node3D
var rng := RandomNumberGenerator.new()
## Lugares ocupados (x, z, raio): o cenário não põe árvores em cima (TrackScenery._reserved).
var reserved: Array[Vector3] = []

var _outside := 0.0
var _mats := {}


func _init(p_track: Track, p_terrain: TrackTerrain, p_root: Node3D) -> void:
	track = p_track
	terrain = p_terrain
	root = p_root
	rng.seed = track.decoration_seed * 4241 + 17
	_outside = track.road_width * 0.5 + track.shoulder_width + track.wall_thickness


# --- Materiais e malhas ------------------------------------------------------------------

func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"post":
			m = TrackScenery.color_material(WHITE, 0.7)
		"rope":
			m = TrackScenery.color_material(Color(0.8, 0.67, 0.45), 0.95)
		"wood":
			m = TrackScenery.color_material(Color(0.56, 0.37, 0.22), 0.88)
		"wood_dark":
			m = TrackScenery.color_material(Color(0.34, 0.22, 0.13), 0.9)
		"bamboo":
			m = TrackScenery.color_material(Color(0.8, 0.68, 0.38), 0.6)
		"tint":
			var t := StandardMaterial3D.new()
			t.vertex_color_use_as_albedo = true
			t.vertex_color_is_srgb = true
			t.roughness = 0.85
			m = t
		"cloth":
			var c := StandardMaterial3D.new()
			c.vertex_color_use_as_albedo = true
			c.vertex_color_is_srgb = true
			c.roughness = 0.8
			c.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = c
		"leaf":
			var l := TrackScenery.color_material(Color(0.24, 0.52, 0.16), 0.8)
			l.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = l
		"sand":
			m = TrackScenery.color_material(Color(0.77, 0.68, 0.5), 0.95)
		"thatch":
			var s := ShaderMaterial.new()
			s.shader = THATCH_SHADER
			s.set_shader_parameter("noise_tex", Track.NOISE_TEXTURE)
			m = s
		"rock":
			var r := ShaderMaterial.new()
			r.shader = ROCK_SHADER
			r.set_shader_parameter("noise_tex", Track.NOISE_TEXTURE)
			r.set_shader_parameter("water_level", track.water_level)
			m = r
		"sign":
			m = TrackScenery.brand_material(TrackScenery.WORDMARK_DARK, TrackScenery.NAVY, 2.6 / 0.62,
					{"logo_fill": 0.68, "border_width": 0.1, "border_color": TrackScenery.YELLOW, "emission": 0.08})
	_mats[key] = m
	return m


## Acrescenta à `mesh` uma superfície com os dados de `md` (sem ler nada de volta da GPU).
static func add_surface(mesh: ArrayMesh, md: Track.MeshData, material: Material) -> void:
	if md.indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = md.verts
	arrays[Mesh.ARRAY_NORMAL] = md.normals
	arrays[Mesh.ARRAY_TEX_UV] = md.uvs
	if md.colors.size() == md.verts.size():
		arrays[Mesh.ARRAY_COLOR] = md.colors
	arrays[Mesh.ARRAY_INDEX] = md.indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


## Peças [malha primitiva, transform, cor] numa superfície só (cor em COLOR).
static func parts_mesh(parts: Array, material: Material, mesh: ArrayMesh = null) -> ArrayMesh:
	var st := MeshMerge.new()
	for part in parts:
		st.append_from(part[0], 0, part[1], part[2] if part.size() > 2 else Color.WHITE)
	st.set_material(material)
	return st.commit(mesh)


## Telhado de quatro águas (com cumeeira se `w` > `d`), base em `y0`. UV = metros ao
## longo da beirada × metros descendo do topo (thatch.gdshader).
static func hip_roof(md: Track.MeshData, w: float, d: float, h: float, y0: float, center := Vector3.ZERO) -> void:
	var ridge := maxf(w - d, 0.0) * 0.5
	var r0 := center + Vector3(-ridge, y0 + h, 0.0)
	var r1 := center + Vector3(ridge, y0 + h, 0.0)
	var c00 := center + Vector3(-w * 0.5, y0, -d * 0.5)
	var c10 := center + Vector3(w * 0.5, y0, -d * 0.5)
	var c11 := center + Vector3(w * 0.5, y0, d * 0.5)
	var c01 := center + Vector3(-w * 0.5, y0, d * 0.5)
	var slope_d := Vector2(d * 0.5, h).length()
	var slope_w := Vector2(w * 0.5 - ridge, h).length()
	# Frente e trás (trapézios).
	for face: Array in [[c01, c11, r1, r0, Vector3(0, 0, 1)], [c10, c00, r0, r1, Vector3(0, 0, -1)]]:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var rb: Vector3 = face[2]
		var ra: Vector3 = face[3]
		var n := (b - a).cross(ra - a).normalized()
		if n.dot(face[4]) < 0.0:
			n = -n
		var ia := md.add_vertex(a, n, Vector2(0.0, slope_d))
		var ib := md.add_vertex(b, n, Vector2(w, slope_d))
		var irb := md.add_vertex(rb, n, Vector2(w * 0.5 + ridge, 0.0))
		var ira := md.add_vertex(ra, n, Vector2(w * 0.5 - ridge, 0.0))
		md.add_tri(ia, ib, irb, n)
		md.add_tri(ia, irb, ira, n)
	# Lados (triângulos).
	for face: Array in [[c00, c01, r0, Vector3(-1, 0, 0)], [c11, c10, r1, Vector3(1, 0, 0)]]:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var r: Vector3 = face[2]
		var n := (b - a).cross(r - a).normalized()
		if n.dot(face[3]) < 0.0:
			n = -n
		var ia := md.add_vertex(a, n, Vector2(0.0, slope_w))
		var ib := md.add_vertex(b, n, Vector2(d, slope_w))
		var ir := md.add_vertex(r, n, Vector2(d * 0.5, 0.0))
		md.add_tri(ia, ib, ir, n)


## Corda (tubo de 4 lados) de `a` até `b`, caindo `sag` m no meio.
static func rope(md: Track.MeshData, a: Vector3, b: Vector3, sag: float, radius: float, segs := 4) -> void:
	var pts: Array[Vector3] = []
	for k in segs + 1:
		var t := float(k) / segs
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	var sides := 4
	var base := md.verts.size()
	for k in pts.size():
		var dir := (pts[mini(k + 1, segs)] - pts[maxi(k - 1, 0)]).normalized()
		var x := dir.cross(Vector3.UP)
		x = x.normalized() if x.length_squared() > 0.0001 else Vector3.RIGHT
		var y := x.cross(dir).normalized()
		for j in sides:
			var ang := TAU * (j + 0.5) / sides
			var n := x * cos(ang) + y * sin(ang)
			md.add_vertex(pts[k] + n * radius, n, Vector2(float(j) / sides, k))
	for k in segs:
		for j in sides:
			var a0 := base + k * sides + j
			var a1 := base + k * sides + (j + 1) % sides
			md.add_tri(a0, a1, a1 + sides, md.normals[a0])
			md.add_tri(a0, a1 + sides, a0 + sides, md.normals[a0])


## Muitas cópias de uma malha em blocos de `chunk` m (a câmera descarta o que não vê).
func _multimesh(mesh: Mesh, xforms: Array[Transform3D], colors: Array[Color], name: String,
		parent: Node3D, shadows := true, chunk := 120.0) -> void:
	if xforms.is_empty():
		return
	var groups := {}
	for i in xforms.size():
		var o := xforms[i].origin
		var key := Vector2i(floori(o.x / chunk), floori(o.z / chunk))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
	for key: Vector2i in groups:
		var ids: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = not colors.is_empty()
		mm.mesh = mesh
		mm.instance_count = ids.size()
		for k in ids.size():
			mm.set_instance_transform(k, xforms[ids[k]])
			if mm.use_colors:
				mm.set_instance_color(k, colors[ids[k]])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = name
		mmi.multimesh = mm
		if not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


static func _chunk_key(at: Vector3, chunk := 120.0) -> Vector2i:
	return Vector2i(floori(at.x / chunk), floori(at.z / chunk))


## Malhas por bloco de `chunk` m (para as cordas e bandeirinhas).
func _chunk_md(groups: Dictionary, at: Vector3, chunk := 120.0) -> Track.MeshData:
	var key := Vector2i(floori(at.x / chunk), floori(at.z / chunk))
	if not groups.has(key):
		groups[key] = Track.MeshData.new()
	return groups[key]


func _commit_chunks(groups: Dictionary, material: Material, name: String, parent: Node3D, shadows := true) -> void:
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


func _node(name: String, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	(parent if parent else root).add_child(n)
	return n


func _is_reserved(x: float, z: float, radius := 0.0) -> bool:
	for r in reserved:
		if Vector2(x - r.x, z - r.y).length() < r.z + radius:
			return true
	return false


## Base de pé com a frente (+Z) virada para `p` → pista.
func _face_track(p: Vector3) -> Basis:
	var idx := terrain.nearest_track_index(p.x, p.z)
	if idx < 0:
		return Basis()
	var to := track.samples[idx] - p
	to.y = 0.0
	return TrackScenery._panel_basis(to) if to.length_squared() > 0.01 else Basis()


func _is_water_sample(i: int) -> bool:
	return track.section_kind_at(i) == TrackSection.Kind.RASO


func _is_jungle_sample(i: int) -> bool:
	return track.section_kind_at(i) == TrackSection.Kind.SELVA


func _near_gap(i: int) -> bool:
	var n := track.samples.size()
	for k in range(-1, 2):
		if track.is_gap((i + k + n) % n):
			return true
	return false


# --- Cercas de corda e boias -------------------------------------------------------------

## Postes brancos com uma corda grossa caindo entre eles, na linha das muretas (que
## continuam só como colisão). No baixio a cerca vira uma linha de boias na superfície,
## com um poste mais alto de vez em quando.
func build_fences() -> void:
	var node := _node("Cercas")
	var count := track.samples.size()
	var step_len := track.length / count
	var offset := track.road_width * 0.5 + track.shoulder_width + track.wall_thickness * 0.5
	var wl := track.water_level
	var posts: Array[Transform3D] = []
	var tall: Array[Transform3D] = []
	var floats: Array[Transform3D] = []
	var float_cols: Array[Color] = []
	var signs: Array[Transform3D] = []
	var ropes := {}
	var rail_posts: Array[Transform3D] = []
	var rails := {}
	var n_posts := int(track.length / POST_SPACING)
	var spacing := track.length / n_posts
	var buoy_colors: Array[Color] = [Color(0.95, 0.18, 0.15), Color(0.97, 0.97, 0.97), Color(1.0, 0.8, 0.1)]
	var next_sign := SIGN_SPACING * 0.5
	for side: float in [-1.0, 1.0]:
		var prev := Vector3.INF
		var prev_water := false
		var prev_post := Vector3.INF
		var prev_jungle := false
		next_sign = SIGN_SPACING * (0.5 if side > 0.0 else 1.0)
		for k in n_posts + 1:
			var d := k * spacing
			var i := int(d / step_len) % count
			if _near_gap(i):
				prev = Vector3.INF
				continue
			var p := track.get_transform_at(d, side * offset).origin
			var water := _is_water_sample(i) or p.y < wl + 0.05
			if _is_jungle_sample(i) and not water:
				# Trilha da mata: cerca de madeira escura de duas traves.
				if k < n_posts:
					rail_posts.append(Transform3D(TrackScenery._panel_basis(track.tangents[i]), p))
				if prev_post != Vector3.INF and prev_jungle:
					var rmm: MeshMerge = rails.get(_chunk_key(p), null)
					if rmm == null:
						rmm = MeshMerge.new()
						rails[_chunk_key(p)] = rmm
					for h: float in [0.42, 0.9]:
						var a := prev_post + Vector3.UP * h
						var b := p + Vector3.UP * h
						var dir := b - a
						var bar := TrackProps._box(Vector3(0.1, 0.16, dir.length() + 0.12))
						rmm.append_from(bar, 0, Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b) * 0.5))
				prev_post = p
				prev_jungle = true
				prev = Vector3.INF
				continue
			var anchor: Vector3
			if water:
				anchor = Vector3(p.x, wl + 0.05, p.z)
				if k % 4 == 0 and k < n_posts:
					tall.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, minf(p.y, wl - 0.3), p.z)))
			else:
				anchor = p + Vector3.UP * ROPE_HEIGHT
				if k < n_posts:
					posts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.FORWARD, rng.randf_range(-0.03, 0.03)), p))
			if prev != Vector3.INF:
				var md := _chunk_md(ropes, anchor)
				if water and prev_water:
					# Boias numa corda esticada na superfície.
					rope(md, prev, anchor, 0.0, 0.03, 1)
					for m in 3:
						var fp := prev.lerp(anchor, (m + 0.5) / 3.0)
						floats.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), fp))
						float_cols.append(buoy_colors[(k * 3 + m) % buoy_colors.size()])
				elif not water and not prev_water:
					rope(md, prev, anchor, ROPE_SAG, 0.05)
					if d > next_sign and d < track.length - 30.0:
						next_sign = d + SIGN_SPACING
						# Placa de madeira pendurada entre dois postes, virada para a pista.
						var mid := prev.lerp(anchor, 0.5) + Vector3.DOWN * 0.3
						var along := anchor - prev
						along.y = 0.0
						var facing := -track.rights[i] * side
						var b := TrackScenery._panel_basis(facing)
						if along.length_squared() > 0.01:
							var x := along.normalized() * (1.0 if b.x.dot(along) > 0.0 else -1.0)
							b = Basis(x, Vector3.UP, x.cross(Vector3.UP).normalized() * (1.0 if x.cross(Vector3.UP).dot(facing) > 0.0 else -1.0))
						signs.append(Transform3D(b, mid + facing * 0.12))
				else:
					# Da areia para a água (ou o contrário): a corda desce até a boia.
					rope(md, prev, anchor, 0.08, 0.04)
			prev = anchor
			prev_water = water
			prev_post = p
			prev_jungle = false
	# Poste: estaca pintada de branco com a ponta arredondada.
	var post_mesh := parts_mesh([
		[TrackProps._cyl(0.1, 0.12, 1.12, 8), Transform3D(Basis(), Vector3(0, 0.56, 0)), WHITE],
		[TrackProps._sphere(0.1, 8), Transform3D(Basis(), Vector3(0, 1.12, 0)), WHITE],
		[TrackProps._cyl(0.13, 0.13, 0.14, 8), Transform3D(Basis(), Vector3(0, ROPE_HEIGHT, 0)), Color(0.8, 0.67, 0.45)],
	], _mat("tint"))
	_multimesh(post_mesh, posts, [] as Array[Color], "Postes", node)
	var tall_mesh := parts_mesh([
		[TrackProps._cyl(0.09, 0.11, 2.6, 8), Transform3D(Basis(), Vector3(0, 1.3, 0)), Color(0.55, 0.37, 0.22)],
		[TrackProps._cyl(0.13, 0.13, 0.3, 8), Transform3D(Basis(), Vector3(0, 2.45, 0)), Color(0.95, 0.18, 0.15)],
	], _mat("tint"))
	_multimesh(tall_mesh, tall, [] as Array[Color], "PostesDasBoias", node)
	var float_mesh := TrackProps._sphere(0.26, 10)
	float_mesh.height = 0.36
	float_mesh.material = _mat("tint")
	_multimesh(float_mesh, floats, float_cols, "Boias", node, false)
	_commit_chunks(ropes, _mat("rope"), "Cordas", node, false)
	if not rail_posts.is_empty():
		var rail_post := parts_mesh([
			[TrackProps._box(Vector3(0.18, 1.18, 0.18)), Transform3D(Basis(), Vector3(0, 0.55, 0)), Color(0.2, 0.16, 0.13)],
			[TrackProps._box(Vector3(0.22, 0.06, 0.22)), Transform3D(Basis(), Vector3(0, 1.15, 0)), Color(0.15, 0.12, 0.1)],
		], _mat("tint"))
		_multimesh(rail_post, rail_posts, [] as Array[Color], "PostesDaMata", node)
		var rail_mat := TrackScenery.color_material(Color(0.2, 0.16, 0.13), 0.85)
		for key: Vector2i in rails:
			var rmm: MeshMerge = rails[key]
			rmm.set_material(rail_mat)
			var mi := MeshInstance3D.new()
			mi.name = "Traves"
			mi.mesh = rmm.commit()
			node.add_child(mi)
	if not signs.is_empty():
		var board := QuadMesh.new()
		board.size = Vector2(2.6, 0.62)
		board.material = _mat("sign")
		_multimesh(board, signs, [] as Array[Color], "PlacasAtivos", node, false)


# --- Portal da largada -----------------------------------------------------------------

## Portal de bambu: três varas grossas de cada lado, duas travessas, a placa da Ativos
## (marca na frente, ícone "at" atrás), faixa quadriculada embaixo, telhado de sapê em
## cima e bandeirinhas penduradas.
func build_start_gate(gate: Node3D) -> void:
	var half := track.road_width * 0.5 + 1.6
	var span := half * 2.0
	var parts := []
	var bamboo := Color(0.82, 0.7, 0.4)
	var joint := Color(0.6, 0.48, 0.25)
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var off := Vector3(side * (half + (k - 1) * 0.12), 0.0, (k - 1) * 0.36)
			var r := 0.2 - absf(k - 1) * 0.04
			var h := 8.0 - absf(k - 1) * 0.6
			parts.append([TrackProps._cyl(r, r * 1.05, h, 10), Transform3D(Basis(), off + Vector3.UP * h * 0.5), bamboo])
			var y := 0.7
			while y < h - 0.2:
				parts.append([TrackProps._cyl(r * 1.15, r * 1.15, 0.1, 10), Transform3D(Basis(), off + Vector3.UP * y), joint])
				y += 0.95
	for y: float in [4.55, 6.75]:
		var bar := TrackProps._cyl(0.17, 0.17, span + 2.0, 10)
		parts.append([bar, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, y, 0)), bamboo])
	# Amarras de corda nos cruzamentos.
	for side: float in [-1.0, 1.0]:
		for y: float in [4.55, 6.75]:
			parts.append([TrackProps._cyl(0.24, 0.24, 0.3, 8), Transform3D(Basis(), Vector3(side * half, y, 0)), Color(0.72, 0.58, 0.36)])
	gate.add_child(_mi(parts_mesh(parts, _mat("tint"))))
	# Telhado de sapê comprido por cima.
	var roof := ArrayMesh.new()
	var md := Track.MeshData.new()
	hip_roof(md, span + 3.4, 3.4, 1.7, 7.6)
	add_surface(roof, md, _mat("thatch"))
	gate.add_child(_mi(roof))
	# Placa: marca na frente (quem chega para largar) e o ícone atrás.
	var panel := QuadMesh.new()
	panel.size = Vector2(span - 1.2, 1.7)
	var aspect := panel.size.x / panel.size.y
	var front := _mi(panel)
	front.transform = Transform3D(Basis(), Vector3(0, 5.65, 0.2))
	front.material_override = TrackScenery.brand_material(TrackScenery.WORDMARK_DARK, TrackScenery.NAVY, aspect,
			{"logo_fill": 0.66, "border_width": 0.06, "border_color": TrackScenery.YELLOW, "emission": 0.15})
	gate.add_child(front)
	var back := _mi(panel)
	back.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 5.65, -0.2))
	back.material_override = TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.BRAND_BLUE, aspect,
			{"logo_fill": 0.8, "logo_count": 3, "recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW, "emission": 0.1})
	gate.add_child(back)
	var board := TrackProps._box(Vector3(span - 1.0, 1.9, 0.3))
	board.material = _mat("wood_dark")
	var bm := _mi(board)
	bm.position = Vector3(0, 5.65, 0)
	gate.add_child(bm)
	# Faixa quadriculada embaixo da placa.
	var img := Image.create(24, 2, false, Image.FORMAT_RGB8)
	for x in 24:
		for y in 2:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.07))
	var checker := StandardMaterial3D.new()
	checker.albedo_texture = ImageTexture.create_from_image(img)
	checker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	checker.cull_mode = BaseMaterial3D.CULL_DISABLED
	checker.roughness = 0.6
	var strip := QuadMesh.new()
	strip.size = Vector2(span - 1.4, 0.5)
	strip.material = checker
	var sm := _mi(strip)
	sm.position = Vector3(0, 4.15, 0)
	gate.add_child(sm)
	# Bandeirinhas penduradas na travessa de cima, dos dois lados.
	var flags := Track.MeshData.new()
	for z: float in [0.3, -0.3]:
		bunting(flags, Vector3(-half, 7.3, z), Vector3(half, 7.3, z), 0.7, 3)
	var fm := MeshInstance3D.new()
	fm.mesh = flags.to_mesh(_mat("cloth"))
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(fm)
	if track.with_collision:
		track.physics_job(func() -> void:
			var shape := CylinderShape3D.new()
			shape.radius = 0.5
			shape.height = 8.0
			for side: float in [-1.0, 1.0]:
				var body := StaticBody3D.new()
				body.add_to_group("wall")
				body.transform = Transform3D(Basis(), Vector3(side * half, 4.0, 0.0))
				var col := CollisionShape3D.new()
				col.shape = shape
				body.add_child(col)
				gate.add_child(body))


func _mi(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


## Bandeirinhas triangulares coloridas numa cordinha de `a` até `b` (caindo `sag` m),
## com as cores em COLOR (material "cloth", dos dois lados).
func bunting(md: Track.MeshData, a: Vector3, b: Vector3, sag: float, color_offset := 0) -> void:
	var length := a.distance_to(b)
	var n := maxi(2, int(length / 0.6))
	var dir := b - a
	dir.y = 0.0
	var facing := dir.normalized().cross(Vector3.UP).normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var line := func(t: float) -> Vector3:
		return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
	var cord := Color(0.92, 0.9, 0.85)
	for k in n:
		var t0 := (k + 0.12) / n
		var t1 := (k + 0.88) / n
		var tm := (k + 0.5) / n
		var p0: Vector3 = line.call(t0)
		var p1: Vector3 = line.call(t1)
		var tip: Vector3 = line.call(tm) + Vector3.DOWN * 0.46
		var col: Color = PENNANTS[(k + color_offset) % PENNANTS.size()]
		var i0 := md.add_vertex(p0, facing, Vector2(0, 0))
		var i1 := md.add_vertex(p1, facing, Vector2(1, 0))
		var i2 := md.add_vertex(tip, facing, Vector2(0.5, 1))
		md.colors.append_array([col, col, col])
		md.add_tri(i0, i1, i2, facing)
		# Cordinha entre as bandeiras (fita fina).
		var c0: Vector3 = line.call(float(k) / n)
		var c1: Vector3 = line.call(float(k + 1) / n)
		var j0 := md.add_vertex(c0, facing, Vector2(0, 0))
		var j1 := md.add_vertex(c1, facing, Vector2(1, 0))
		var j2 := md.add_vertex(c1 + Vector3.DOWN * 0.03, facing, Vector2(1, 1))
		var j3 := md.add_vertex(c0 + Vector3.DOWN * 0.03, facing, Vector2(0, 1))
		md.colors.append_array([cord, cord, cord, cord])
		md.add_tri(j0, j1, j2, facing)
		md.add_tri(j0, j2, j3, facing)


# --- Cenário ---------------------------------------------------------------------------

## Vila, palafitas, guarda-sóis, bandeirinhas, arco de pedra e ilhotas. `p_reserved` é
## a lista de lugares ocupados do TrackScenery (as árvores vêm depois e desviam).
func build_landmarks(p_reserved: Array[Vector3], preview: bool) -> void:
	reserved = p_reserved
	_build_rock_arch()
	_build_stilt_huts()
	_build_village()
	_build_bunting_lines()
	_build_islets(preview)
	_build_far_islands()


## Malha do quiosque de praia (frente = +Z): assoalho em estacas baixas, balcão com a
## placa da Ativos, meia parede, quatro esteios e telhado de sapê; vasos de flores na
## frente. Superfícies: madeira e flores (cor de vértice) e o sapê.
func _kiosk_mesh() -> ArrayMesh:
	var wood := Color(0.56, 0.37, 0.22)
	var dark := Color(0.36, 0.23, 0.14)
	var light := Color(0.76, 0.58, 0.38)
	var parts := []
	parts.append([TrackProps._box(Vector3(5.2, 0.25, 5.2)), Transform3D(Basis(), Vector3(0, 0.55, 0)), light])
	for x: float in [-2.3, 2.3]:
		for z: float in [-2.3, 2.3]:
			parts.append([TrackProps._cyl(0.14, 0.16, 0.8, 6), Transform3D(Basis(), Vector3(x, 0.3, z)), dark])
			parts.append([TrackProps._cyl(0.12, 0.14, 2.7, 8), Transform3D(Basis(), Vector3(x, 2.0, z)), wood])
	# Balcão na frente, meia parede atrás e nos lados.
	parts.append([TrackProps._box(Vector3(4.4, 1.05, 0.5)), Transform3D(Basis(), Vector3(0, 1.2, 2.2)), wood])
	parts.append([TrackProps._box(Vector3(4.7, 0.1, 0.8)), Transform3D(Basis(), Vector3(0, 1.78, 2.25)), light])
	parts.append([TrackProps._box(Vector3(4.6, 1.3, 0.12)), Transform3D(Basis(), Vector3(0, 1.3, -2.3)), wood])
	for x: float in [-2.3, 2.3]:
		parts.append([TrackProps._box(Vector3(0.12, 1.0, 4.6)), Transform3D(Basis(), Vector3(x, 1.15, 0)), wood])
	# Banquinhos na frente do balcão.
	for x: float in [-1.4, 0.0, 1.4]:
		parts.append([TrackProps._cyl(0.25, 0.25, 0.08, 10), Transform3D(Basis(), Vector3(x, 0.78, 3.15)), light])
		parts.append([TrackProps._cyl(0.05, 0.05, 0.75, 6), Transform3D(Basis(), Vector3(x, 0.38, 3.15)), dark])
	# Vasos de flores (arbusto verde e flores) dos dois lados da frente.
	for x: float in [-3.3, 3.3]:
		parts.append([TrackProps._box(Vector3(1.0, 0.5, 1.0)), Transform3D(Basis(), Vector3(x, 0.25, 2.4)), dark])
		parts.append([TrackProps._sphere(0.7, 8), Transform3D(Basis().scaled(Vector3(1, 0.8, 1)), Vector3(x, 0.95, 2.4)), Color(0.22, 0.52, 0.16)])
		for f in 6:
			var a := TAU * f / 6.0 + x
			var fc: Color = [Color(0.95, 0.2, 0.3), Color(1.0, 0.45, 0.7), Color(1.0, 0.8, 0.15)][f % 3]
			parts.append([TrackProps._sphere(0.16, 6), Transform3D(Basis(), Vector3(x + cos(a) * 0.55, 1.2 + (f % 2) * 0.15, 2.4 + sin(a) * 0.55)), fc])
	var mesh := parts_mesh(parts, _mat("tint"))
	var roof := Track.MeshData.new()
	hip_roof(roof, 7.2, 7.2, 2.8, 3.25)
	# Segunda camada mais alta (telhado em dois níveis, como os quiosques de verdade).
	hip_roof(roof, 2.6, 2.6, 1.3, 5.4)
	add_surface(mesh, roof, _mat("thatch"))
	return mesh


## Quiosques de sapê na areia perto da largada e na reta da praia, virados para a pista.
func _build_village() -> void:
	var node := _node("Vila")
	var xforms: Array[Transform3D] = []
	var signs: Array[Transform3D] = []
	var umbrellas: Array[Array] = [[] as Array[Transform3D], [] as Array[Transform3D]]
	var loungers: Array[Transform3D] = []
	var lounger_cols: Array[Color] = []
	var boards: Array[Transform3D] = []
	var board_cols: Array[Color] = []
	var count := track.samples.size()
	var wl := track.water_level
	var start := track.get_point_at(0.0)
	var placed := 0
	for attempt in 500:
		if placed >= 11:
			break
		# Perto da largada: do fim da volta até a reta da praia.
		var frac := wrapf(rng.randf_range(-0.12, 0.15), 0.0, 1.0)
		var i := int(frac * count) % count
		if not track.is_plain(i):
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lateral := side * (_outside + rng.randf_range(6.5, 16.0))
		var p := track.samples[i] + track.rights[i] * lateral
		if terrain.distance_to_track(p.x, p.z) < _outside + 5.0 or _is_reserved(p.x, p.z, 5.0):
			continue
		if Vector2(p.x - start.x, p.z - start.z).length() < 26.0:
			continue
		var y := terrain.height_at(p.x, p.z)
		if y < wl + 0.7 or absf(terrain.height_at(p.x + 4.0, p.z) - y) > 1.0 or absf(terrain.height_at(p.x, p.z + 4.0) - y) > 1.0:
			continue
		var basis := _face_track(Vector3(p.x, y, p.z))
		xforms.append(Transform3D(basis, Vector3(p.x, y - 0.1, p.z)))
		signs.append(Transform3D(basis, Vector3(p.x, y - 0.1, p.z) + basis * Vector3(0.0, 1.22, 2.47)))
		reserved.append(Vector3(p.x, p.z, 7.5))
		placed += 1
		# Pranchas de surfe fincadas na areia do lado do quiosque.
		for b in rng.randi_range(1, 3):
			var bp := Vector3(p.x, y, p.z) + basis * Vector3(3.6 + b * 0.75, -0.35, rng.randf_range(-1.6, 1.0))
			var bb := basis.rotated(Vector3.UP, rng.randf_range(-0.4, 0.4)) * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
			boards.append(Transform3D(bb, bp))
			board_cols.append([TrackScenery.YELLOW, Color(0.15, 0.75, 0.85), TrackScenery.RED, TrackScenery.BRAND_BLUE, Color(1.0, 0.55, 0.15), WHITE][rng.randi() % 6])
		# Guarda-sóis com espreguiçadeiras ao lado.
		for u in rng.randi_range(1, 2):
			var off := basis * Vector3(rng.randf_range(5.5, 8.0) * (-1.0 if u == 0 else 1.0), 0.0, rng.randf_range(-1.0, 3.0))
			var up := Vector3(p.x, 0.0, p.z) + off
			if terrain.distance_to_track(up.x, up.z) < _outside + 2.5:
				continue
			var uy := terrain.height_at(up.x, up.z)
			if uy < wl + 0.4:
				continue
			var ub := Basis(Vector3.UP, rng.randf() * TAU)
			(umbrellas[rng.randi() % 2] as Array[Transform3D]).append(Transform3D(ub, Vector3(up.x, uy - 0.1, up.z)))
			reserved.append(Vector3(up.x, up.z, 3.5))
			for l in 2:
				var lb := basis.rotated(Vector3.UP, rng.randf_range(-0.3, 0.3))
				loungers.append(Transform3D(lb, Vector3(up.x, uy, up.z) + lb * Vector3((l - 0.5) * 1.5, 0.0, 0.6)))
				lounger_cols.append([TrackScenery.BRAND_BLUE, WHITE, TrackScenery.YELLOW, Color(0.15, 0.75, 0.85)][rng.randi() % 4])
	_multimesh(_kiosk_mesh(), xforms, [] as Array[Color], "Quiosques", node)
	if not signs.is_empty():
		var board := QuadMesh.new()
		board.size = Vector2(2.6, 0.62)
		board.material = _mat("sign")
		_multimesh(board, signs, [] as Array[Color], "PlacasDosQuiosques", node, false)
	var variants: Array[ArrayMesh] = [_big_umbrella_mesh(Color(0.93, 0.15, 0.16), WHITE), _big_umbrella_mesh(TrackScenery.BRAND_BLUE, WHITE)]
	for v in 2:
		_multimesh(variants[v], umbrellas[v], [] as Array[Color], "GuardaSoisGrandes", node)
	_multimesh(_lounger_mesh(), loungers, lounger_cols, "Espreguicadeiras", node)
	# Prancha: oval achatada com uma faixa branca no meio (cor da instância).
	var board := parts_mesh([
		[TrackProps._sphere(1.0, 12), Transform3D(Basis().scaled(Vector3(0.3, 1.15, 0.05)), Vector3(0, 1.15, 0)), Color.WHITE],
		[TrackProps._box(Vector3(0.05, 2.1, 0.11)), Transform3D(Basis(), Vector3(0, 1.15, 0)), Color(0.98, 0.98, 0.98)],
	], _mat("tint"))
	_multimesh(board, boards, board_cols, "Pranchas", node)


## Guarda-sol grande de praia: mastro de madeira e copa em gomos listrados de duas cores,
## com franja (frente: as duas cores; sombra larga).
func _big_umbrella_mesh(a: Color, b: Color) -> ArrayMesh:
	var mesh := parts_mesh([
		[TrackProps._cyl(0.07, 0.09, 3.4, 8), Transform3D(Basis(), Vector3(0, 1.7, 0)), Color(0.55, 0.37, 0.22)],
		[TrackProps._sphere(0.12, 8), Transform3D(Basis(), Vector3(0, 3.75, 0)), Color(0.97, 0.97, 0.97)],
	], _mat("tint"))
	var md := Track.MeshData.new()
	var sectors := 12
	var apex := Vector3(0, 3.7, 0)
	var rim_r := 2.8
	var rim_y := 2.75
	for k in sectors:
		var a0 := TAU * k / sectors
		var a1 := TAU * (k + 1) / sectors
		var r0 := Vector3(cos(a0) * rim_r, rim_y, sin(a0) * rim_r)
		var r1 := Vector3(cos(a1) * rim_r, rim_y, sin(a1) * rim_r)
		var mid := (r0 + r1) * 0.5 + Vector3.DOWN * 0.12
		var col := a if k % 2 == 0 else b
		var n := (r0 - apex).cross(r1 - apex).normalized()
		if n.y < 0.0:
			n = -n
		var i0 := md.add_vertex(apex, n, Vector2.ZERO)
		var i1 := md.add_vertex(r0, n, Vector2.ZERO)
		var i2 := md.add_vertex(mid, n, Vector2.ZERO)
		var i3 := md.add_vertex(r1, n, Vector2.ZERO)
		md.colors.append_array([col, col, col, col])
		md.add_tri(i0, i1, i2, n)
		md.add_tri(i0, i2, i3, n)
		# Franja caindo da borda.
		var out := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		var j0 := md.add_vertex(r0, out, Vector2.ZERO)
		var j1 := md.add_vertex(r1, out, Vector2.ZERO)
		var j2 := md.add_vertex(r1 + Vector3.DOWN * 0.28, out, Vector2.ZERO)
		var j3 := md.add_vertex(r0 + Vector3.DOWN * 0.28, out, Vector2.ZERO)
		var fc := b if k % 2 == 0 else a
		md.colors.append_array([fc, fc, fc, fc])
		md.add_tri(j0, j1, j2, out)
		md.add_tri(j0, j2, j3, out)
	add_surface(mesh, md, _mat("cloth"))
	return mesh


## Espreguiçadeira de madeira com almofada (cor da instância).
func _lounger_mesh() -> ArrayMesh:
	var wood := TrackScenery.color_material(Color(0.62, 0.42, 0.25), 0.8)
	var cushion := StandardMaterial3D.new()
	cushion.vertex_color_use_as_albedo = true
	cushion.vertex_color_is_srgb = true
	cushion.roughness = 0.85
	var mesh := TrackProps._compound([
		[TrackProps._box(Vector3(0.7, 0.08, 1.5)), Transform3D(Basis(), Vector3(0, 0.36, 0.15)), wood],
		[TrackProps._box(Vector3(0.7, 0.08, 0.8)), Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, 0.62, -0.78)), wood],
		[TrackProps._box(Vector3(0.06, 0.34, 0.06)), Transform3D(Basis(), Vector3(-0.3, 0.17, 0.75)), wood],
		[TrackProps._box(Vector3(0.06, 0.34, 0.06)), Transform3D(Basis(), Vector3(0.3, 0.17, 0.75)), wood],
		[TrackProps._box(Vector3(0.06, 0.34, 0.06)), Transform3D(Basis(), Vector3(-0.3, 0.17, -0.45)), wood],
		[TrackProps._box(Vector3(0.06, 0.34, 0.06)), Transform3D(Basis(), Vector3(0.3, 0.17, -0.45)), wood],
	])
	parts_mesh([
		[TrackProps._box(Vector3(0.62, 0.07, 1.4)), Transform3D(Basis(), Vector3(0, 0.43, 0.15)), Color.WHITE],
		[TrackProps._box(Vector3(0.62, 0.07, 0.72)), Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, 0.68, -0.74)), Color.WHITE],
	], cushion, mesh)
	return mesh


## Casinha de palafita (frente = +Z): plataforma em estacas, paredes de madeira com porta
## e janelas, telhado de sapê e uma passarelinha até o píer. `top` = altura da plataforma
## acima da base da malha (que fica no fundo); `bridge` = comprimento da passarelinha.
func _stilt_hut_mesh(top: float, bridge: float) -> ArrayMesh:
	var wood := Color(0.56, 0.37, 0.22)
	var dark := Color(0.34, 0.22, 0.13)
	var light := Color(0.74, 0.56, 0.36)
	var parts := []
	for x: float in [-2.6, 0.0, 2.6]:
		for z: float in [-2.6, 0.0, 2.6]:
			parts.append([TrackProps._cyl(0.17, 0.2, top + 0.2, 8), Transform3D(Basis(), Vector3(x, (top + 0.2) * 0.5 - 0.2, z)), dark])
	parts.append([TrackProps._box(Vector3(6.2, 0.24, 6.2)), Transform3D(Basis(), Vector3(0, top, 0)), light])
	# Paredes.
	parts.append([TrackProps._box(Vector3(4.2, 2.3, 3.6)), Transform3D(Basis(), Vector3(0, top + 1.27, -0.6)), wood])
	parts.append([TrackProps._box(Vector3(0.9, 1.7, 0.08)), Transform3D(Basis(), Vector3(0, top + 0.97, 1.22)), dark])
	for x: float in [-1.4, 1.4]:
		parts.append([TrackProps._box(Vector3(0.8, 0.6, 0.08)), Transform3D(Basis(), Vector3(x, top + 1.5, 1.22)), Color(0.12, 0.2, 0.28)])
	for x: float in [-2.12, 2.12]:
		parts.append([TrackProps._box(Vector3(0.08, 0.6, 0.8)), Transform3D(Basis(), Vector3(x, top + 1.5, -0.6)), Color(0.12, 0.2, 0.28)])
	# Guarda-corpo da varanda.
	for x: float in [-3.0, 3.0]:
		parts.append([TrackProps._box(Vector3(0.08, 0.08, 6.0)), Transform3D(Basis(), Vector3(x, top + 0.9, 0)), dark])
	parts.append([TrackProps._box(Vector3(6.0, 0.08, 0.08)), Transform3D(Basis(), Vector3(0, top + 0.9, -3.0)), dark])
	for x: float in [-3.0, -1.5, 1.5, 3.0]:
		parts.append([TrackProps._box(Vector3(0.08, 0.9, 0.08)), Transform3D(Basis(), Vector3(x, top + 0.45, 3.0)), dark])
	# Flores na varanda.
	for x: float in [-2.4, 2.4]:
		parts.append([TrackProps._sphere(0.45, 8), Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), Vector3(x, top + 0.45, 2.3)), Color(0.22, 0.52, 0.16)])
		parts.append([TrackProps._sphere(0.15, 6), Transform3D(Basis(), Vector3(x + 0.2, top + 0.75, 2.4)), Color(0.95, 0.2, 0.3)])
		parts.append([TrackProps._sphere(0.15, 6), Transform3D(Basis(), Vector3(x - 0.2, top + 0.7, 2.2)), Color(1.0, 0.45, 0.7)])
	# Passarelinha até o píer (sai pela frente).
	if bridge > 0.5:
		parts.append([TrackProps._box(Vector3(1.4, 0.14, bridge)), Transform3D(Basis(), Vector3(0, top + 0.02, 3.1 + bridge * 0.5)), light])
		for z in int(bridge / 2.2):
			parts.append([TrackProps._cyl(0.1, 0.12, top + 0.2, 6), Transform3D(Basis(), Vector3(0.65, (top + 0.2) * 0.5 - 0.2, 4.2 + z * 2.2)), dark])
			parts.append([TrackProps._cyl(0.1, 0.12, top + 0.2, 6), Transform3D(Basis(), Vector3(-0.65, (top + 0.2) * 0.5 - 0.2, 4.2 + z * 2.2)), dark])
	var mesh := parts_mesh(parts, _mat("tint"))
	var roof := Track.MeshData.new()
	hip_roof(roof, 6.0, 5.4, 2.6, top + 2.35, Vector3(0, 0, -0.5))
	add_surface(mesh, roof, _mat("thatch"))
	return mesh


## Palafitas dos dois lados das passarelas (só onde há água embaixo), viradas para o
## píer; onde ele ainda é baixo, com uma passarelinha até a beira dele.
func _build_stilt_huts() -> void:
	var node := _node("Palafitas")
	var wl := track.water_level
	var lip := _outside + TrackBridgeBuilder.LIP
	var gap := 9.0
	var floor_y := wl - 3.0
	var top := wl + 1.9 - floor_y
	var meshes: Array[ArrayMesh] = [_stilt_hut_mesh(top, gap - 3.1 + 0.4), _stilt_hut_mesh(top, 0.0)]
	var lists: Array[Array] = [[] as Array[Transform3D], [] as Array[Transform3D]]
	for span in track.bridge_spans:
		var b: TrackBridge = span.bridge
		if b.style != TrackBridge.Style.PASSARELA:
			continue
		var from: int = span.from
		var to: int = span.to
		var step := track.length / track.samples.size()
		var k := 0
		var d := track.distances[from] + 14.0
		while d < track.distances[to] - 30.0:
			var i := int(d / step) % track.samples.size()
			# Píer alto (subindo para a rampa de asa-delta): a casinha fica sem passarelinha
			# e um pouco mais longe.
			var high := track.samples[i].y > wl + 4.5
			var sides: Array[float] = [1.0 if k % 2 == 0 else -1.0]
			if rng.randf() < 0.35:
				sides.append(-sides[0])
			k += 1
			for side in sides:
				var center := track.samples[i] + track.rights[i] * side * (lip + gap + (6.0 if high else 0.0))
				center.y = 0.0
				var ok := terrain.height_at(center.x, center.z) < wl - 0.8 and terrain.distance_to_track(center.x, center.z) > lip + 3.0
				if ok:
					var basis := TrackScenery._panel_basis(-track.rights[i] * side)
					(lists[1 if high else 0] as Array[Transform3D]).append(Transform3D(basis, Vector3(center.x, floor_y, center.z)))
					reserved.append(Vector3(center.x, center.z, 8.0))
			d += rng.randf_range(24.0, 32.0)
	for v in 2:
		_multimesh(meshes[v], lists[v], [] as Array[Color], "Palafitas", node)


## Bandeirinhas penduradas entre varas de bambu dos dois lados da reta da largada.
func _build_bunting_lines() -> void:
	var node := _node("Bandeirinhas")
	var offset := _outside + 1.4
	var poles: Array[Transform3D] = []
	var groups := {}
	for side: float in [-1.0, 1.0]:
		var prev := Vector3.INF
		var d := -64.0
		var k := 0
		while d < 120.0:
			var i := int(fposmod(d, track.length) / (track.length / track.samples.size())) % track.samples.size()
			var p := track.get_transform_at(fposmod(d, track.length), side * offset).origin
			var ground := terrain.height_at(p.x, p.z)
			if absf(d) < 8.0 or not track.is_plain(i) or ground < track.water_level + 0.3:
				prev = Vector3.INF
				d += 17.0
				continue
			p.y = minf(p.y, ground)
			poles.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
			var top := p + Vector3.UP * 4.6
			if prev != Vector3.INF:
				bunting(_chunk_md(groups, top), prev, top, 0.9, k * 2)
			prev = top
			k += 1
			d += 17.0
	var pole := parts_mesh([
		[TrackProps._cyl(0.08, 0.1, 4.9, 8), Transform3D(Basis(), Vector3(0, 2.45, 0)), Color(0.82, 0.7, 0.4)],
		[TrackProps._sphere(0.12, 6), Transform3D(Basis(), Vector3(0, 4.95, 0)), TrackScenery.YELLOW],
	], _mat("tint"))
	_multimesh(pole, poles, [] as Array[Color], "VarasDasBandeirinhas", node)
	_commit_chunks(groups, _mat("cloth"), "Bandeirinhas", node, false)


# --- Arco de pedra ---------------------------------------------------------------------

## Pedra (bolotas de poucas faces amassadas) com o material de rocha da praia.
static func rock_blob(radius: float, segments := 9) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = maxi(4, segments / 2)
	return s


## Amostra do meio do arco de pedra: a reta mais reta da ilha (40 m entre 40% e 52%
## da volta, na areia ou na trilha da mata), ou -1.
func _arch_index() -> int:
	return arch_index(track)


static func arch_index(p_track: Track) -> int:
	var count := p_track.samples.size()
	var half := int(20.0 / (p_track.length / count))
	var best := -1
	var best_k := INF
	for i in range(int(0.4 * count), int(0.52 * count)):
		var worst := 0.0
		var ok := true
		for k in range(-half, half + 1):
			var j := (i + k + count) % count
			var kind := p_track.section_kind_at(j)
			if p_track.is_bridge(j) or (kind != -1 and kind != TrackSection.Kind.SELVA):
				ok = false
				break
			worst = maxf(worst, absf(p_track.curvature[j]))
		if ok and worst < best_k:
			best_k = worst
			best = i
	return best


## Onde ficam os dois pés do arco de pedra (vazio se não tiver arco).
func arch_feet() -> Array[Vector3]:
	var feet: Array[Vector3] = []
	var i := _arch_index()
	if i >= 0:
		for side: float in [-1.0, 1.0]:
			feet.append(track.samples[i] + track.rights[i] * side * (_outside + 8.5))
	return feet


## Arco de pedra natural por cima da pista: um "tubo" de pedra irregular (ruído 3D) de um
## pé ao outro, mais grosso embaixo, com pedras grandes em volta dos pés, cipós
## pendurados por baixo e um coqueiro em cima.
func _build_rock_arch() -> void:
	var i := _arch_index()
	if i < 0:
		return
	var node := _node("ArcoDePedra")
	var c := track.samples[i]
	var r := track.rights[i]
	var t := track.tangents[i]
	t.y = 0.0
	t = t.normalized()
	var span := _outside + 7.5
	var apex := 11.0
	var noise := FastNoiseLite.new()
	noise.seed = track.decoration_seed + 91
	noise.frequency = 0.14
	noise.fractal_octaves = 3
	var rows := 46
	var ring := 16
	var md := Track.MeshData.new()
	var row_low: Array[int] = []
	var row_high: Array[int] = []
	for k in rows + 1:
		var a := lerpf(-0.14, PI + 0.14, float(k) / rows)
		var center := c + r * (-cos(a) * span) + Vector3.UP * (sin(a) * apex)
		var tang := (r * sin(a) * span + Vector3.UP * cos(a) * apex).normalized()
		var nrm := tang.cross(t).normalized()
		var h := clampf(sin(a), 0.0, 1.0)
		var rt := lerpf(6.0, 3.6, h)
		var rn := lerpf(5.0, 2.7, h)
		var low := -1
		var high := -1
		for j in ring:
			var phi := TAU * j / ring
			var dir := t * cos(phi) * rt + nrm * sin(phi) * rn
			var pos := center + dir
			var bump := noise.get_noise_3dv(pos) * 1.8 + noise.get_noise_3dv(pos * 2.4 + Vector3(9.0, 3.0, 1.0)) * 0.55
			pos += dir.normalized() * bump
			var vi := md.add_vertex(pos, dir.normalized(), Vector2.ZERO)
			if low < 0 or pos.y < md.verts[low].y:
				low = vi
			if high < 0 or pos.y > md.verts[high].y:
				high = vi
		row_low.append(low)
		row_high.append(high)
	# Normais pela malha (com os calombos).
	var fresh := PackedVector3Array()
	fresh.resize(md.verts.size())
	for k in rows + 1:
		for j in ring:
			var along := md.verts[mini(k + 1, rows) * ring + j] - md.verts[maxi(k - 1, 0) * ring + j]
			var around := md.verts[k * ring + (j + 1) % ring] - md.verts[k * ring + (j - 1 + ring) % ring]
			var n := along.cross(around).normalized()
			if n.dot(md.normals[k * ring + j]) < 0.0:
				n = -n
			fresh[k * ring + j] = n
	md.normals = fresh
	for k in rows:
		for j in ring:
			var a0 := k * ring + j
			var a1 := k * ring + (j + 1) % ring
			md.add_tri(a0, a1, a1 + ring, md.normals[a0])
			md.add_tri(a0, a1 + ring, a0 + ring, md.normals[a0])
	var arch := MeshInstance3D.new()
	arch.name = "Arco"
	arch.mesh = md.to_mesh(_mat("rock"))
	node.add_child(arch)
	# Pedras grandes em volta dos pés (giradas em eixos quaisquer: nada de bolas certinhas).
	var feet := MeshMerge.new()
	for side: float in [-1.0, 1.0]:
		var base := c + r * side * (span + 1.0)
		base.y = terrain.height_at(base.x, base.z)
		for k in 6:
			var rad := rng.randf_range(2.2, 4.6)
			var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if axis.length_squared() < 0.01:
				axis = Vector3.UP
			var p := base + r * side * rng.randf_range(-2.0, 5.0) + t * rng.randf_range(-6.0, 6.0) + Vector3.UP * rng.randf_range(-1.0, 1.5)
			feet.append_from(rock_blob(1.0, 7), 0, Transform3D(Basis(axis.normalized(), rng.randf() * TAU).scaled(Vector3(rad * 1.2, rad * 0.75, rad)), p))
		reserved.append(Vector3(base.x, base.z, 12.0))
	feet.set_material(_mat("rock"))
	var fm := MeshInstance3D.new()
	fm.name = "PedrasDosPes"
	fm.mesh = feet.commit()
	node.add_child(fm)
	# Cipós pendurados por baixo da parte que passa por cima da pista.
	var vines := Track.MeshData.new()
	var leaves := Track.MeshData.new()
	for k in rows + 1:
		var low := md.verts[row_low[k]]
		var lat := (low - c).dot(r)
		if absf(lat) > track.road_width * 0.5 + 4.0 or low.y - c.y < 6.5:
			continue
		for v in 2:
			var top := low + t * rng.randf_range(-2.5, 2.5) + Vector3.UP * 0.4
			_vine(vines, leaves, top, rng.randf_range(1.4, minf(4.2, low.y - c.y - 3.6)))
	var vm := MeshInstance3D.new()
	vm.mesh = vines.to_mesh(_mat("rope"))
	vm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(vm)
	var lm := MeshInstance3D.new()
	lm.mesh = leaves.to_mesh(_mat("leaf"))
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(lm)
	# Coqueiro e tufos de mato em cima.
	var palm_spots: Array[Transform3D] = []
	var palm_cols: Array[Color] = []
	for k: int in [rows / 2 + 6, rows / 2 - 9]:
		palm_spots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 0.85)), md.verts[row_high[k]] + Vector3.DOWN * 0.3))
		palm_cols.append(Color(0.3, 0.62, 0.2))
	_multimesh(TrackProps._palm_mesh(), palm_spots, palm_cols, "CoqueirosDoArco", node)
	var tufts := MeshMerge.new()
	for k in range(2, rows - 1, 3):
		var top := md.verts[row_high[k]]
		tufts.append_from(TrackProps._sphere(1.0, 8), 0, Transform3D(Basis().scaled(Vector3(rng.randf_range(1.2, 2.2), 0.6, rng.randf_range(1.2, 2.2))), top))
	tufts.set_material(TrackScenery.color_material(Color(0.24, 0.48, 0.15), 0.9))
	var tm := MeshInstance3D.new()
	tm.name = "MatoDoArco"
	tm.mesh = tufts.commit()
	node.add_child(tm)


## Cipó: cordinha caindo de `top` com folhas em pares ao longo dela.
func _vine(stem: Track.MeshData, leaves: Track.MeshData, top: Vector3, length: float) -> void:
	var bottom := top + Vector3.DOWN * length + Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
	rope(stem, top, bottom, 0.0, 0.03, 2)
	var n := int(length / 0.32)
	for k in n:
		var p := top.lerp(bottom, (k + 0.5) / n)
		var ang := rng.randf() * TAU
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := dir.cross(Vector3.UP)
		var s := rng.randf_range(0.18, 0.3) * (1.0 - 0.4 * float(k) / n)
		var tip := p + dir * s * 1.6 + Vector3.DOWN * s * 0.6
		var normal := side.cross(tip - p).normalized()
		var a := leaves.add_vertex(p, normal, Vector2.ZERO)
		var b := leaves.add_vertex(p + dir * s * 0.8 + side * s * 0.45, normal, Vector2.ZERO)
		var c := leaves.add_vertex(tip, normal, Vector2.ZERO)
		var d := leaves.add_vertex(p + dir * s * 0.8 - side * s * 0.45, normal, Vector2.ZERO)
		leaves.add_tri(a, b, c, normal)
		leaves.add_tri(a, c, d, normal)


# --- Ilhotas ---------------------------------------------------------------------------

## Ilhotas de pedra no mar (na baía e em volta), com o alto verde e coqueiros.
func _build_islets(preview: bool) -> void:
	var node := _node("Ilhotas")
	var wl := track.water_level
	var md := MeshMerge.new()
	var green := MeshMerge.new()
	var palms: Array[Transform3D] = []
	var palm_cols: Array[Color] = []
	var area := terrain.half_extent + Vector2(240.0, 240.0)
	var placed := 0
	var spots: Array[Vector2] = []
	for attempt in 3000:
		if placed >= (5 if preview else 11):
			break
		var x := terrain.center.x + rng.randf_range(-area.x, area.x)
		var z := terrain.center.y + rng.randf_range(-area.y, area.y)
		var d := terrain.distance_to_track(x, z)
		if d < _outside + 40.0 or d > 300.0:
			continue
		if terrain.height_at(x, z) > wl - 2.5:
			continue
		var close := false
		for sp in spots:
			if sp.distance_to(Vector2(x, z)) < 70.0:
				close = true
				break
		if close:
			continue
		spots.append(Vector2(x, z))
		placed += 1
		var floor_y := terrain.height_at(x, z)
		var size := rng.randf_range(5.0, 11.0)
		var height := rng.randf_range(3.5, 11.0)
		var top_y := wl + height
		for k in rng.randi_range(3, 6):
			var off := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * size * 0.8
			var rad := size * rng.randf_range(0.55, 0.9)
			var hy := (top_y - floor_y) * rng.randf_range(0.6, 1.0)
			var center := Vector3(x, floor_y + hy * 0.5, z) + off
			md.append_from(rock_blob(1.0, 8), 0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rad, hy * 0.62, rad * rng.randf_range(0.7, 1.1))), center))
		# Alto verde (mato) e coqueiros.
		green.append_from(TrackProps._sphere(1.0, 10), 0, Transform3D(Basis().scaled(Vector3(size * 0.75, 1.2, size * 0.7)), Vector3(x, top_y - 0.4, z)))
		for k in rng.randi_range(1, 3):
			var pp := Vector3(x + rng.randf_range(-size, size) * 0.35, top_y - 0.2, z + rng.randf_range(-size, size) * 0.35)
			palms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), pp))
			palm_cols.append(Color.from_hsv(rng.randf_range(0.24, 0.32), rng.randf_range(0.7, 0.85), rng.randf_range(0.55, 0.75)))
	if placed == 0:
		return
	md.set_material(_mat("rock"))
	var rocks := MeshInstance3D.new()
	rocks.name = "Pedras"
	rocks.mesh = md.commit()
	node.add_child(rocks)
	green.set_material(TrackScenery.color_material(Color(0.25, 0.55, 0.18), 0.9))
	var gm := MeshInstance3D.new()
	gm.name = "Mato"
	gm.mesh = green.commit()
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(gm)
	_multimesh(TrackProps._palm_mesh(), palms, palm_cols, "Coqueiros", node)


# --- Trilha da mata ----------------------------------------------------------------------

## Bananeira: tronco verde e folhas largas e compridas caindo (cor da instância).
static func banana_mesh() -> ArrayMesh:
	var trunk := MeshMerge.new()
	trunk.append_from(TrackProps._cyl(0.13, 0.2, 2.2, 8), 0, Transform3D(Basis(), Vector3(0, 1.1, 0)))
	trunk.set_material(TrackScenery.color_material(Color(0.42, 0.5, 0.22), 0.85))
	var mesh := trunk.commit()
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, 2.15, 0)
	for k in 7:
		var ang := TAU * k / 7.0 + (0.25 if k % 2 == 0 else -0.15)
		TrackProps._frond(leaves, top + Vector3.UP * (k % 3) * 0.15, Vector3(cos(ang), 0.0, sin(ang)), 2.2 + (k % 3) * 0.3, 0.62, 1.1 + (k % 2) * 0.4)
	var fm := TrackScenery._foliage_material(1.4, 3.6, top, 0.35)
	fm.set_shader_parameter("wind_strength", 0.04)
	leaves.set_material(fm)
	leaves.commit(mesh)
	return mesh


## Samambaia: folhas baixas e finas saindo do chão em roda (cor da instância).
static func fern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 9:
		var ang := TAU * k / 9.0 + (0.2 if k % 2 == 0 else 0.0)
		TrackProps._frond(st, Vector3(0, 0.15, 0), Vector3(cos(ang), 0.0, sin(ang)), 1.25 + (k % 3) * 0.2, 0.26, 1.2)
	var fm := TrackScenery._foliage_material(0.0, 1.2, Vector3(0, 0.4, 0), 0.4)
	fm.set_shader_parameter("wind_strength", 0.02)
	st.set_material(fm)
	return st.commit()


## Moita florida: arbusto verde com flores vermelhas (e algumas rosas) por cima.
func _flower_bush_mesh() -> ArrayMesh:
	var parts := []
	var green := Color(0.2, 0.46, 0.14)
	parts.append([TrackProps._sphere(0.75, 8), Transform3D(Basis().scaled(Vector3(1.2, 0.8, 1.0)), Vector3(0, 0.5, 0)), green])
	parts.append([TrackProps._sphere(0.55, 8), Transform3D(Basis(), Vector3(0.6, 0.45, 0.3)), green.lightened(0.1)])
	parts.append([TrackProps._sphere(0.5, 8), Transform3D(Basis(), Vector3(-0.6, 0.4, -0.2)), green.darkened(0.1)])
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for f in 11:
		var a := r.randf() * TAU
		var rad := r.randf_range(0.3, 0.85)
		var fc := Color(0.92, 0.1, 0.12) if f % 4 != 0 else Color(1.0, 0.35, 0.55)
		parts.append([TrackProps._sphere(0.13, 6), Transform3D(Basis(), Vector3(cos(a) * rad, 0.75 + r.randf_range(0.0, 0.3), sin(a) * rad * 0.8)), fc])
	return parts_mesh(parts, _mat("tint"))


## Trilha da mata (SELVA, amostras `ids`): murinhos de pedra cobertos de grama e flores
## atrás da cerca, e a mata fechada dos dois lados.
func build_jungle(ids: PackedInt32Array, preview: bool) -> void:
	if ids.is_empty():
		return
	var node := _node("Mata")
	var wl := track.water_level
	# Os pés do arco de pedra (se ele cair na mata) ficam livres.
	for foot in arch_feet():
		reserved.append(Vector3(foot.x, foot.z, 12.0))
	# Murinhos de pedra: trechos de 12 a 28 m, encostados por fora da cerca.
	var stone := ShaderMaterial.new()
	stone.shader = STONE_SHADER
	stone.set_shader_parameter("stone_a", Color(0.62, 0.62, 0.56))
	stone.set_shader_parameter("stone_b", Color(0.44, 0.46, 0.4))
	stone.set_shader_parameter("mortar", Color(0.28, 0.3, 0.24))
	stone.set_shader_parameter("block_w", 0.62)
	stone.set_shader_parameter("block_h", 0.34)
	var walls := MeshMerge.new()
	var caps := MeshMerge.new()
	var bushes: Array[Transform3D] = []
	var lateral := _outside + 1.3
	var first := ids[0]
	var last := ids[ids.size() - 1]
	for side: float in [-1.0, 1.0]:
		var i := first + rng.randi_range(2, 8)
		while i < last - 4:
			var run := rng.randi_range(6, 14)
			var h := rng.randf_range(0.9, 1.5)
			for k in range(i, mini(i + run, last - 2)):
				var a := track.samples[k] + track.rights[k] * side * lateral
				var b := track.samples[k + 1] + track.rights[k + 1] * side * lateral
				var ga := terrain.height_at(a.x, a.z)
				var gb := terrain.height_at(b.x, b.z)
				if minf(ga, gb) < wl + 0.3:
					continue
				var mid := (a + b) * 0.5
				var g := minf(ga, gb)
				var dir := b - a
				dir.y = 0.0
				var basis := Basis.looking_at(dir, Vector3.UP)
				walls.append_from(TrackProps._box(Vector3(1.1, h + 0.5, dir.length() + 0.05)), 0, Transform3D(basis, Vector3(mid.x, g + h * 0.5 - 0.25, mid.z)))
				caps.append_from(TrackProps._box(Vector3(1.3, 0.22, dir.length() + 0.05)), 0, Transform3D(basis, Vector3(mid.x, g + h + 0.08, mid.z)))
				if (k - i) % 2 == 0 and rng.randf() < 0.75:
					var bp := Vector3(mid.x, g + h, mid.z) + track.rights[k] * side * rng.randf_range(-0.2, 0.3)
					bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 0.95)), bp))
			i += run + rng.randi_range(4, 12)
	walls.set_material(stone)
	var wm := MeshInstance3D.new()
	wm.name = "Murinhos"
	wm.mesh = walls.commit()
	node.add_child(wm)
	caps.set_material(TrackScenery.color_material(Color(0.24, 0.5, 0.15), 0.9))
	var cm := MeshInstance3D.new()
	cm.name = "GramaDosMurinhos"
	cm.mesh = caps.commit()
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(cm)
	# Mata dos dois lados.
	var trees: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	var palms: Array[Transform3D] = []
	var palm_cols: Array[Color] = []
	var bananas: Array[Transform3D] = []
	var banana_cols: Array[Color] = []
	var ferns: Array[Transform3D] = []
	var fern_cols: Array[Color] = []
	var scale := 0.35 if preview else 1.0
	var targets := {"tree": int(110 * scale), "palm": int(65 * scale), "banana": int(130 * scale), "fern": int(300 * scale), "bush": int(110 * scale)}
	var placed := {"tree": 0, "palm": 0, "banana": 0, "fern": 0, "bush": 0}
	for attempt in 4000:
		var kind := ""
		for key: String in targets:
			if placed[key] < targets[key]:
				kind = key
				break
		if kind == "":
			break
		var k := ids[rng.randi() % ids.size()]
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var near := 2.4 if kind == "fern" or kind == "bush" else (3.5 if kind == "banana" else 6.0)
		# Mais denso perto da cerca (a mata "fecha" a trilha).
		var reach := 34.0 if kind == "tree" or kind == "palm" else 14.0
		var lat := _outside + near + reach * pow(rng.randf(), 1.6)
		var p := track.samples[k] + track.rights[k] * side * lat + track.tangents[k] * rng.randf_range(-2.0, 2.0)
		if terrain.distance_to_track(p.x, p.z) < _outside + near * 0.8 or _is_reserved(p.x, p.z, 1.5):
			continue
		var y := terrain.height_at(p.x, p.z)
		if y < wl + 0.5 or terrain.jungle_at(p.x, p.z) < 0.4:
			continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y - 0.1, p.z))
		match kind:
			"tree":
				trees.append(xf.scaled_local(Vector3.ONE * rng.randf_range(1.4, 2.3)))
				tree_cols.append(Color.from_hsv(rng.randf_range(0.26, 0.36), rng.randf_range(0.7, 0.9), rng.randf_range(0.4, 0.62)))
			"palm":
				palms.append(xf.scaled_local(Vector3.ONE * rng.randf_range(1.0, 1.45)))
				palm_cols.append(Color.from_hsv(rng.randf_range(0.25, 0.33), rng.randf_range(0.7, 0.85), rng.randf_range(0.5, 0.72)))
			"banana":
				bananas.append(xf.scaled_local(Vector3.ONE * rng.randf_range(0.8, 1.3)))
				banana_cols.append(Color.from_hsv(rng.randf_range(0.24, 0.3), rng.randf_range(0.65, 0.85), rng.randf_range(0.6, 0.85)))
			"fern":
				ferns.append(xf.scaled_local(Vector3.ONE * rng.randf_range(0.7, 1.3)))
				fern_cols.append(Color.from_hsv(rng.randf_range(0.27, 0.35), rng.randf_range(0.7, 0.9), rng.randf_range(0.45, 0.7)))
			"bush":
				bushes.append(xf.scaled_local(Vector3.ONE * rng.randf_range(0.8, 1.3)))
		placed[kind] += 1
	_multimesh(TrackScenery._broadleaf_mesh(), trees, tree_cols, "ArvoresDaMata", node)
	_multimesh(TrackProps._palm_mesh(), palms, palm_cols, "CoqueirosDaMata", node)
	_multimesh(banana_mesh(), bananas, banana_cols, "Bananeiras", node)
	_multimesh(fern_mesh(), ferns, fern_cols, "Samambaias", node, false)
	_multimesh(_flower_bush_mesh(), bushes, [] as Array[Color], "MoitasFloridas", node)


## Ilhas grandes no horizonte (mar aberto em volta da pista): morro verde de mata com
## uma faixa de areia na beira e pedras, longe o bastante para a névoa clarear.
func _build_far_islands() -> void:
	var node := _node("IlhasDistantes")
	var wl := track.water_level
	var green := MeshMerge.new()
	var sand := MeshMerge.new()
	var rocks := MeshMerge.new()
	var count := 7
	var phase := rng.randf() * TAU
	for k in count:
		var ang := phase + TAU * k / count + rng.randf_range(-0.25, 0.25)
		var dist := rng.randf_range(560.0, 980.0)
		var c := Vector3(terrain.center.x + cos(ang) * dist, wl, terrain.center.y + sin(ang) * dist)
		var rad := rng.randf_range(70.0, 170.0)
		var h := rad * rng.randf_range(0.22, 0.45)
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		# Dois ou três morros juntos.
		for m in rng.randi_range(2, 3):
			var off := yaw * Vector3(rng.randf_range(-0.45, 0.45) * rad, 0.0, rng.randf_range(-0.3, 0.3) * rad)
			var rr := rad * rng.randf_range(0.5, 0.85)
			green.append_from(TrackProps._sphere(1.0, 16), 0, Transform3D(yaw.scaled(Vector3(rr, h * rng.randf_range(0.7, 1.0), rr * 0.75)), c + off))
		sand.append_from(TrackProps._sphere(1.0, 20), 0, Transform3D(yaw.scaled(Vector3(rad * 1.12, 2.4, rad * 0.9)), c + Vector3.DOWN * 1.6))
		for m in 4:
			var off := yaw * Vector3(rng.randf_range(-0.9, 0.9) * rad, 0.0, rng.randf_range(-0.7, 0.7) * rad)
			var rr := rng.randf_range(8.0, 20.0)
			rocks.append_from(rock_blob(1.0, 7), 0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rr, rr * 0.8, rr)), c + off))
	green.set_material(TrackScenery.color_material(Color(0.22, 0.46, 0.17), 0.95))
	sand.set_material(TrackScenery.color_material(Color(0.77, 0.68, 0.5), 0.95))
	rocks.set_material(_mat("rock"))
	for pair: Array in [[green, "Morros"], [sand, "Praias"], [rocks, "Pedras"]]:
		var mi := MeshInstance3D.new()
		mi.name = pair[1]
		mi.mesh = (pair[0] as MeshMerge).commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
