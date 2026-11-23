@tool
class_name TrackEgypt
extends RefCounted
## Monumentos do Egito no deserto (cenário DESERTO), com as cores da Ativos (lápis-lazúli
## e ouro, como as pinturas dos templos):
## - pirâmides: a maior no meio do laço de baixo e um grupo de três no horizonte, à frente
##   de quem desce as dunas; as maiores têm a ponta de ouro com o logo "at";
## - templo numa reta: portal (dois pilonos e uma viga por cima da pista, com o disco
##   alado e a marca), avenida de esfinges antes dele, colunata depois, obeliscos e a
##   esfinge gigante olhando a pista;
## - obeliscos com hieróglifos, ruínas (colunas caídas e blocos), camelos e uma caravana
##   andando em volta da pirâmide do meio;
## - o portal de largada (pilonos com bandeiras, viga com a marca e a faixa quadriculada).
## Os hieróglifos vêm de assets/textures/hieroglifos.png (shaders/egypt_stone.gdshader).

const STONE_SHADER := preload("res://shaders/egypt_stone.gdshader")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")
const WORDMARK_DARK := preload("res://assets/logos/ativos_marca_branca.png")
const CARAVAN := preload("res://scripts/caravan.gd")

const LAPIS := Color(0.11, 0.22, 0.62)
const GOLD := Color(1.0, 0.78, 0.25)
const SANDSTONE := Color(0.88, 0.7, 0.47)
const CAMEL := Color(0.78, 0.6, 0.38)

var track: Track
var terrain: TrackTerrain
var root: Node3D
var rng := RandomNumberGenerator.new()
## Áreas ocupadas (x, z, raio), compartilhadas com o TrackScenery (as árvores desviam).
var reserved: Array[Vector3] = []

var _outside := 0.0
var _mats := {}
var _tint: StandardMaterial3D


func _init(p_track: Track, p_terrain: TrackTerrain, p_root: Node3D) -> void:
	track = p_track
	terrain = p_terrain
	root = p_root
	rng.seed = track.decoration_seed * 4637 + 29
	_outside = track.road_width * 0.5 + track.shoulder_width + track.wall_thickness
	_tint = StandardMaterial3D.new()
	_tint.vertex_color_use_as_albedo = true
	_tint.vertex_color_is_srgb = true
	_tint.roughness = 0.85


func build_landmarks(p_reserved: Array[Vector3], preview: bool) -> void:
	reserved = p_reserved
	var center := _build_pyramids()
	_build_temple()
	_build_obelisk_pairs()
	_build_ruins()
	if center != Vector4.INF and not preview:
		_build_caravan(center)


# --- Materiais -----------------------------------------------------------------------

## Arenito do shaders/egypt_stone.gdshader com os parâmetros de `opts` (um por combinação).
func stone(opts := {}) -> ShaderMaterial:
	var key := var_to_str(opts)
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = STONE_SHADER
	m.set_shader_parameter("noise_tex", Track.NOISE_TEXTURE)
	m.set_shader_parameter("glyph_tex", Track.GLYPHS)
	for k: String in opts:
		m.set_shader_parameter(k, opts[k])
	_mats[key] = m
	return m


func gold() -> StandardMaterial3D:
	if not _mats.has("gold"):
		var m := StandardMaterial3D.new()
		m.albedo_color = GOLD
		m.metallic = 0.9
		m.roughness = 0.28
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.2)
		m.emission_energy_multiplier = 0.35
		_mats["gold"] = m
	return _mats["gold"]


func tint() -> StandardMaterial3D:
	return _tint


# --- Malhas ---------------------------------------------------------------------------

## Tronco de pirâmide de 4 lados (base w0 × d0, topo w1 × d1, de y0 a y0 + h), com
## normais por face. UV.x = 0..1 de um lado ao outro de cada face, UV.y = altura (m).
static func frustum(md: Track.MeshData, w0: float, d0: float, w1: float, d1: float, h: float,
		y0 := 0.0, offset := Vector3.ZERO, cap := true) -> void:
	var b := [Vector3(-w0, 0, d0) * 0.5, Vector3(w0, 0, d0) * 0.5, Vector3(w0, 0, -d0) * 0.5, Vector3(-w0, 0, -d0) * 0.5]
	var t := [Vector3(-w1, 0, d1) * 0.5, Vector3(w1, 0, d1) * 0.5, Vector3(w1, 0, -d1) * 0.5, Vector3(-w1, 0, -d1) * 0.5]
	for k in 4:
		var a0: Vector3 = b[k] + Vector3(0, y0, 0) + offset
		var a1: Vector3 = b[(k + 1) % 4] + Vector3(0, y0, 0) + offset
		var c1: Vector3 = t[(k + 1) % 4] + Vector3(0, y0 + h, 0) + offset
		var c0: Vector3 = t[k] + Vector3(0, y0 + h, 0) + offset
		var n := (a1 - a0).cross(c0 - a0).normalized()
		var mid := (a0 + a1 + c0 + c1) * 0.25 - offset
		if n.dot(Vector3(mid.x, 0.0, mid.z)) < 0.0:
			n = -n
		var i := md.add_vertex(a0, n, Vector2(0.0, y0))
		md.add_vertex(a1, n, Vector2(1.0, y0))
		md.add_vertex(c1, n, Vector2(1.0, y0 + h))
		md.add_vertex(c0, n, Vector2(0.0, y0 + h))
		md.add_tri(i, i + 1, i + 2, n)
		md.add_tri(i, i + 2, i + 3, n)
	if cap:
		var i := md.verts.size()
		for k in 4:
			var c: Vector3 = t[k] + Vector3(0, y0 + h, 0) + offset
			md.add_vertex(c, Vector3.UP, Vector2(c.x, c.z))
		md.add_tri(i, i + 1, i + 2, Vector3.UP)
		md.add_tri(i, i + 2, i + 3, Vector3.UP)


## Fuste redondo (de y0 a y0 + h, raio r0 embaixo e r1 em cima), normais suaves.
## UV.x = volta (0..1), UV.y = altura (m).
static func shaft(md: Track.MeshData, r0: float, r1: float, h: float, y0 := 0.0, segs := 14, cap := true) -> void:
	var first := md.verts.size()
	var slope := (r0 - r1) / maxf(h, 0.001)
	for k in segs + 1:
		var a := TAU * k / segs
		var dir := Vector3(cos(a), 0.0, sin(a))
		var n := (dir + Vector3.UP * slope).normalized()
		md.add_vertex(dir * r0 + Vector3.UP * y0, n, Vector2(float(k) / segs, y0))
		md.add_vertex(dir * r1 + Vector3.UP * (y0 + h), n, Vector2(float(k) / segs, y0 + h))
	for k in segs:
		var a := first + k * 2
		md.add_tri(a, a + 1, a + 2, md.normals[a])
		md.add_tri(a + 1, a + 3, a + 2, md.normals[a])
	if cap:
		var c := md.add_vertex(Vector3.UP * (y0 + h), Vector3.UP, Vector2(0.5, 0.5))
		for k in segs:
			var a := TAU * k / segs
			var b := TAU * (k + 1) / segs
			var p := md.add_vertex(Vector3(cos(a), 0.0, sin(a)) * r1 + Vector3.UP * (y0 + h), Vector3.UP, Vector2.ZERO)
			var q := md.add_vertex(Vector3(cos(b), 0.0, sin(b)) * r1 + Vector3.UP * (y0 + h), Vector3.UP, Vector2.ZERO)
			md.add_tri(c, p, q, Vector3.UP)


## Pirâmide de base quadrada (lado `base`, altura `height`) com a base em y = 0.
static func pyramid(md: Track.MeshData, base: float, height: float) -> void:
	frustum(md, base, base, 0.001, 0.001, height, 0.0, Vector3.ZERO, false)


## Coluna de templo: base, fuste com hieróglifos e capitel de papiro aberto com faixas.
func column_mesh(height := 9.0, radius := 0.85) -> ArrayMesh:
	var md := Track.MeshData.new()
	frustum(md, radius * 2.6, radius * 2.6, radius * 2.4, radius * 2.4, 0.5)
	shaft(md, radius, radius * 0.86, height - 2.0, 0.5)
	# Capitel: abre como uma flor de papiro.
	shaft(md, radius * 0.86, radius * 1.45, 1.1, height - 1.5, 14, false)
	frustum(md, radius * 2.3, radius * 2.3, radius * 2.3, radius * 2.3, 0.4, height - 0.4)
	return md.to_mesh(stone({"glyph_cols": 5.0, "glyph_u": Vector2(0.0, 1.0), "glyph_v": Vector2(1.4, height - 2.4),
			"glyph_size": 0.62, "band_v": Vector4(height - 2.2, height, 2.2, 0.75), "block_h": 1.2, "block_w": 9.0, "joints": 0.5}))


## Obelisco de uma pedra só: hieróglifos numa coluna no meio de cada face e a ponta
## (piramídio) de ouro.
func obelisk_mesh(height := 14.0, base := 1.6) -> ArrayMesh:
	var md := Track.MeshData.new()
	frustum(md, base, base, base * 0.62, base * 0.62, height, 0.0, Vector3.ZERO, false)
	var mesh := md.to_mesh(stone({"glyph_cols": 1.0, "glyph_u": Vector2(0.3, 0.7), "glyph_v": Vector2(1.6, height - 1.2),
			"glyph_size": 0.62, "joints": 0.0, "sand_cover": 0.0}))
	var tip := Track.MeshData.new()
	frustum(tip, base * 0.62, base * 0.62, 0.001, 0.001, base * 0.75, height, Vector3.ZERO, false)
	var arrays := tip.to_mesh(gold())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays.surface_get_arrays(0))
	mesh.surface_set_material(1, gold())
	# Pedestal.
	var ped := Track.MeshData.new()
	frustum(ped, base * 1.7, base * 1.7, base * 1.5, base * 1.5, 0.9, -0.6)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ped.to_mesh(_tint).surface_get_arrays(0))
	mesh.surface_set_material(2, stone({"block_w": 1.2, "block_h": 0.45}))
	return mesh


## Esfinge deitada olhando para +Z (uns 11 m de comprimento com a base; `s` = escala):
## arenito, o lenço listrado de ouro e lápis-lazúli e a barba azul.
func sphinx_mesh(s := 1.0) -> ArrayMesh:
	var sand := SANDSTONE
	var dark := SANDSTONE.darkened(0.18)
	var parts := [
		[_box(Vector3(5.4, 1.0, 11.6)), Vector3(0, 0.5, 0), dark, Vector3.ONE],
		[_sphere(1.0), Vector3(0, 2.4, -1.3), sand, Vector3(2.0, 1.5, 4.0)],
		[_sphere(1.0), Vector3(1.15, 2.1, -3.5), sand, Vector3(1.3, 1.25, 1.7)],
		[_sphere(1.0), Vector3(-1.15, 2.1, -3.5), sand, Vector3(1.3, 1.25, 1.7)],
		[_sphere(1.0), Vector3(0, 3.0, 1.2), sand, Vector3(1.75, 2.0, 1.6)],
		[_box(Vector3(0.95, 0.85, 3.8)), Vector3(1.15, 1.42, 2.7), sand, Vector3.ONE],
		[_box(Vector3(0.95, 0.85, 3.8)), Vector3(-1.15, 1.42, 2.7), sand, Vector3.ONE],
		[_sphere(1.0), Vector3(1.15, 1.45, 4.6), sand, Vector3(0.55, 0.45, 0.45)],
		[_sphere(1.0), Vector3(-1.15, 1.45, 4.6), sand, Vector3(0.55, 0.45, 0.45)],
		# Cabeça, rosto e o lenço (nemes).
		[_sphere(1.0), Vector3(0, 5.0, 1.7), sand, Vector3(0.88, 1.05, 0.92)],
		[_sphere(1.0), Vector3(0, 5.45, 1.5), GOLD, Vector3(1.12, 0.85, 1.05)],
		[_box(Vector3(0.6, 1.9, 0.4)), Vector3(0.9, 4.15, 1.85), GOLD, Vector3.ONE],
		[_box(Vector3(0.6, 1.9, 0.4)), Vector3(-0.9, 4.15, 1.85), GOLD, Vector3.ONE],
		[_box(Vector3(0.22, 0.38, 0.28)), Vector3(0, 4.95, 2.6), dark, Vector3.ONE],
		[_box(Vector3(0.28, 0.85, 0.3)), Vector3(0, 3.85, 2.45), LAPIS, Vector3.ONE],
		[_box(Vector3(1.0, 0.1, 0.06)), Vector3(0, 4.45, 2.58), dark, Vector3.ONE],
		# Cauda enrolada do lado.
		[_box(Vector3(0.25, 0.25, 2.6)), Vector3(1.9, 1.3, -3.0), sand, Vector3.ONE],
	]
	# Listras do lenço.
	for k in 4:
		for side: float in [-1.0, 1.0]:
			parts.append([_box(Vector3(0.63, 0.14, 0.43)), Vector3(side * 0.9, 3.5 + k * 0.42, 1.85), LAPIS, Vector3.ONE])
		parts.append([_box(Vector3(2.3, 0.12, 1.6)), Vector3(0, 5.2 + k * 0.17, 1.42 - k * 0.05), LAPIS, Vector3(1.0 - k * 0.08, 1.0, 1.0)])
	var st := MeshMerge.new()
	for part in parts:
		var sc: Vector3 = part[3] * s
		st.append_from(part[0], 0, Transform3D(Basis.from_scale(sc), part[1] * s), part[2])
	st.set_material(_tint)
	return st.commit()


## Camelo em pé olhando para +Z (2,2 m na corcova), com a manta da Ativos.
func camel_mesh() -> ArrayMesh:
	var c := CAMEL
	var d := CAMEL.darkened(0.25)
	var parts := [
		[_sphere(1.0), Transform3D(Basis.from_scale(Vector3(0.55, 0.5, 1.0)), Vector3(0, 1.75, 0)), c],
		[_sphere(1.0), Transform3D(Basis.from_scale(Vector3(0.42, 0.45, 0.5)), Vector3(0, 2.2, -0.05)), c],
		[_cyl(0.16, 0.24, 1.2, 8), Transform3D(Basis(Vector3.RIGHT, 0.75), Vector3(0, 2.05, 1.15)), c],
		[_sphere(1.0), Transform3D(Basis.from_scale(Vector3(0.18, 0.2, 0.38)), Vector3(0, 2.55, 1.6)), c],
		[_sphere(1.0), Transform3D(Basis.from_scale(Vector3(0.06, 0.1, 0.06)), Vector3(0.12, 2.75, 1.42)), d],
		[_sphere(1.0), Transform3D(Basis.from_scale(Vector3(0.06, 0.1, 0.06)), Vector3(-0.12, 2.75, 1.42)), d],
		[_box(Vector3(1.0, 0.08, 1.2)), Transform3D(Basis(), Vector3(0, 2.38, 0.0)), LAPIS],
		[_box(Vector3(1.02, 0.1, 0.12)), Transform3D(Basis(), Vector3(0, 2.42, 0.55)), GOLD],
		[_box(Vector3(1.02, 0.1, 0.12)), Transform3D(Basis(), Vector3(0, 2.42, -0.55)), GOLD],
		[_cyl(0.03, 0.05, 0.7, 5), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 1.6, -1.0)), d],
	]
	for leg: Vector2 in [Vector2(0.3, 0.6), Vector2(-0.3, 0.6), Vector2(0.3, -0.62), Vector2(-0.3, -0.62)]:
		parts.append([_cyl(0.08, 0.11, 1.45, 6), Transform3D(Basis(), Vector3(leg.x, 0.72, leg.y)), c])
		parts.append([_sphere(1.0), Transform3D(Basis.from_scale(Vector3(0.11, 0.06, 0.14)), Vector3(leg.x, 0.04, leg.y + 0.04)), d])
	var st := MeshMerge.new()
	for part in parts:
		st.append_from(part[0], 0, part[1], part[2])
	st.set_material(_tint)
	return st.commit()


## Cabeça gigante de faraó caída (para o fundo do oásis): rosto, lenço listrado e
## a barba, olhando para +Z, uns 5 m de altura.
func pharaoh_head_mesh() -> ArrayMesh:
	var sand := SANDSTONE.darkened(0.05)
	var parts := [
		[_sphere(1.0), Vector3(0, 2.4, 0), sand, Vector3(1.6, 2.0, 1.7)],
		[_sphere(1.0), Vector3(0, 3.2, -0.3), GOLD, Vector3(2.15, 1.7, 2.0)],
		[_box(Vector3(1.1, 3.0, 0.7)), Vector3(1.75, 1.4, 0.4), GOLD, Vector3.ONE],
		[_box(Vector3(1.1, 3.0, 0.7)), Vector3(-1.75, 1.4, 0.4), GOLD, Vector3.ONE],
		[_box(Vector3(0.38, 0.6, 0.45)), Vector3(0, 2.3, 1.7), sand.darkened(0.1), Vector3.ONE],
		[_box(Vector3(0.5, 1.4, 0.5)), Vector3(0, 0.4, 1.3), LAPIS, Vector3.ONE],
		[_box(Vector3(0.5, 0.16, 0.1)), Vector3(0.55, 2.9, 1.55), Color(0.1, 0.1, 0.12), Vector3.ONE],
		[_box(Vector3(0.5, 0.16, 0.1)), Vector3(-0.55, 2.9, 1.55), Color(0.1, 0.1, 0.12), Vector3.ONE],
		[_box(Vector3(0.3, 0.8, 0.3)), Vector3(0, 4.8, 0.9), LAPIS, Vector3.ONE],
	]
	for k in 5:
		for side: float in [-1.0, 1.0]:
			parts.append([_box(Vector3(1.14, 0.22, 0.74)), Vector3(side * 1.75, 0.2 + k * 0.6, 0.4), LAPIS, Vector3.ONE])
	var st := MeshMerge.new()
	for part in parts:
		st.append_from(part[0], 0, Transform3D(Basis.from_scale(part[3]), part[1]), part[2])
	st.set_material(_tint)
	return st.commit()


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _sphere(radius: float, segments := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 3)
	return m


static func _cyl(top: float, bottom: float, height: float, segments := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


func _add(mesh: Mesh, xform: Transform3D, parent: Node3D, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], name: String, parent: Node3D, shadows := true) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


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


## Base em pé virada para `dir` (+Z do objeto olhando na direção, no plano).
static func _facing(dir: Vector3) -> Basis:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.0001:
		return Basis()
	return TrackScenery._panel_basis(d)


## Altura mais baixa do chão no quadrado de lado `size` em volta de (x, z).
func _ground_min(x: float, z: float, size: float) -> float:
	var y := terrain.height_at(x, z)
	for o: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		y = minf(y, terrain.height_at(x + o.x * size * 0.5, z + o.y * size * 0.5))
	return y


# --- Portal de largada ------------------------------------------------------------------

## Pilonos dos dois lados da largada (no acostamento), viga com a marca por cima da pista,
## o disco alado com o logo, a faixa quadriculada e bandeiras nos mastros dos pilonos.
## `gate` = nó na largada (frente +Z virada para quem chega).
func build_start_gate(gate: Node3D) -> void:
	var half := track.road_width * 0.5
	var tw0 := 4.2
	var tw1 := 3.3
	var td0 := 3.3
	var td1 := 2.5
	var th := 10.5
	var cx := half + 0.6 + tw0 * 0.5
	var tower := Track.MeshData.new()
	var cornice := Track.MeshData.new()
	for side: float in [-1.0, 1.0]:
		frustum(tower, tw0, td0, tw1, td1, th, 0.0, Vector3(side * cx, 0, 0))
		frustum(cornice, tw1, td1, tw1 + 0.8, td1 + 0.8, 1.0, th, Vector3(side * cx, 0, 0))
	_add(tower.to_mesh(stone({"glyph_cols": 2.0, "glyph_u": Vector2(0.12, 0.88), "glyph_v": Vector2(1.2, 8.8), "glyph_size": 0.72})), Transform3D(), gate)
	_add(cornice.to_mesh(stone({"band_v": Vector4(th, th + 1.0, 3.0, 0.8)})), Transform3D(), gate)
	# Viga por cima da pista (entra um pouco nos pilonos).
	var inner := cx - tw1 * 0.5 + 0.3
	var beam := Track.MeshData.new()
	frustum(beam, inner * 2.0, 2.2, inner * 2.0, 2.2, 2.3, 7.4)
	_add(beam.to_mesh(stone({"block_w": 2.6, "block_h": 0.75})), Transform3D(), gate)
	var panel := QuadMesh.new()
	panel.size = Vector2(inner * 2.0 - 1.0, 1.8)
	var aspect := panel.size.x / panel.size.y
	_add(panel, Transform3D(Basis(), Vector3(0, 8.55, 1.11)), gate, false).material_override = TrackScenery.brand_material(
			WORDMARK_DARK, TrackScenery.NAVY, aspect, {"logo_fill": 0.66, "border_width": 0.07, "border_color": GOLD, "emission": 0.12})
	_add(panel, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 8.55, -1.11)), gate, false).material_override = TrackScenery.brand_material(
			LOGO_ICON, LAPIS, aspect, {"logo_fill": 0.78, "logo_count": 3, "recolor": true, "recolor_main": Color.WHITE,
			"recolor_accent": GOLD, "border_width": 0.07, "border_color": GOLD, "emission": 0.1})
	_build_winged_disk(gate, Vector3(0, 10.75, 0.2), 1.0)
	# Faixa quadriculada embaixo da viga.
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
	strip.size = Vector2(inner * 2.0 - 0.8, 0.55)
	strip.material = checker
	_add(strip, Transform3D(Basis(), Vector3(0, 7.1, 0)), gate, false)
	# Mastros com bandeiras compridas na frente dos pilonos (como nos templos).
	var pole := _cyl(0.1, 0.14, 15.0, 8)
	pole.material = gold()
	var banners: Array[ShaderMaterial] = [
		TrackScenery.brand_material(LOGO_ICON, TrackScenery.BRAND_BLUE, 1.3 / 4.6, {"recolor": true, "recolor_main": Color.WHITE,
				"recolor_accent": TrackScenery.YELLOW, "wave": 0.18, "logo_fill": 0.8}),
		TrackScenery.brand_material(LOGO_ICON, TrackScenery.YELLOW, 1.3 / 4.6, {"wave": 0.18, "logo_fill": 0.8}),
	]
	var flag := QuadMesh.new()
	flag.size = Vector2(1.3, 4.6)
	flag.subdivide_depth = 8
	var n := 0
	for side: float in [-1.0, 1.0]:
		for off: float in [-1.05, 1.05]:
			var x := side * cx + off
			_add(pole, Transform3D(Basis(), Vector3(x, 7.5, td0 * 0.5 + 0.35)), gate)
			var mi := _add(flag, Transform3D(Basis(), Vector3(x + 0.72, 12.0, td0 * 0.5 + 0.35)), gate, false)
			mi.material_override = banners[n % 2]
			n += 1
	if track.with_collision:
		var size := Vector3(tw0, th, td0)
		track.physics_job(func() -> void:
			var shape := BoxShape3D.new()
			shape.size = size
			for side: float in [-1.0, 1.0]:
				var body := StaticBody3D.new()
				body.add_to_group("wall")
				body.position = Vector3(side * cx, th * 0.5, 0.0)
				var col := CollisionShape3D.new()
				col.shape = shape
				body.add_child(col)
				gate.add_child(body))


## Disco solar de ouro com o logo "at" e as asas abertas de lápis-lazúli e ouro.
func _build_winged_disk(parent: Node3D, at: Vector3, s: float) -> void:
	var disk := _cyl(1.05 * s, 1.05 * s, 0.3 * s, 24)
	disk.material = gold()
	_add(disk, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at), parent)
	var logo := QuadMesh.new()
	logo.size = Vector2(1.7, 1.7) * s
	_add(logo, Transform3D(Basis(), at + Vector3(0, 0, 0.16 * s)), parent, false).material_override = TrackScenery.brand_material(
			LOGO_ICON, GOLD, 1.0, {"logo_fill": 0.62, "recolor": true, "recolor_main": LAPIS, "recolor_accent": Color.WHITE})
	var wing := Track.MeshData.new()
	var cols := PackedColorArray()
	for side: float in [-1.0, 1.0]:
		# Três fileiras de penas, a de baixo mais curta.
		for row in 3:
			var length := (3.6 - row * 0.7) * s
			var y := (0.35 - row * 0.32) * s
			var x0 := side * 1.1 * s
			var x1 := side * (1.1 * s + length)
			var top := y + 0.16 * s
			var bot := y - 0.16 * s
			var i := wing.add_vertex(Vector3(x0, top, 0), Vector3.BACK, Vector2.ZERO)
			wing.add_vertex(Vector3(x1, top + 0.25 * s, 0), Vector3.BACK, Vector2.ZERO)
			wing.add_vertex(Vector3(x1, bot + 0.1 * s, 0), Vector3.BACK, Vector2.ZERO)
			wing.add_vertex(Vector3(x0, bot, 0), Vector3.BACK, Vector2.ZERO)
			wing.add_tri(i, i + 1, i + 2, Vector3.BACK)
			wing.add_tri(i, i + 2, i + 3, Vector3.BACK)
			var c := LAPIS if row != 1 else GOLD
			cols.append_array([c, c, c, c])
	wing.colors = cols
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.5
	_add(wing.to_mesh(mat), Transform3D(Basis(), at + Vector3(0, 0, 0.05)), parent, false)


# --- Pirâmides -----------------------------------------------------------------------------

## A maior pirâmide no maior vazio dentro do traçado e um grupo de três longe, onde quem
## corre olha de frente. Devolve (x, y, z, meia diagonal) da do meio (para a caravana)
## ou Vector4.INF.
func _build_pyramids() -> Vector4:
	var node := _node("Piramides")
	var box := track._bounds()
	var best := Vector3.INF
	var best_d := 0.0
	var x := box.position.x + 40.0
	while x < box.end.x - 40.0:
		var z := box.position.z + 40.0
		while z < box.end.z - 40.0:
			var d := terrain.distance_to_track(x, z)
			if d > best_d and terrain.height_at(x, z) > terrain.water_level + 2.0:
				best_d = d
				best = Vector3(x, 0.0, z)
			z += 8.0
		x += 8.0
	var center := Vector4.INF
	if best != Vector3.INF and best_d > 60.0:
		var base := clampf((best_d - 30.0) / 0.74, 50.0, 118.0)
		_place_pyramid(node, best, base, true)
		center = Vector4(best.x, terrain.height_at(best.x, best.z), best.z, base * 0.72)
	# Grupo no horizonte: onde a pista mais aponta (quem corre vê de frente).
	var count := track.samples.size()
	var grow := 430.0
	var main := Vector3.INF
	var main_score := 0.0
	x = box.position.x - grow
	while x < box.end.x + grow:
		var z := box.position.z - grow
		while z < box.end.z + grow:
			var d := terrain.distance_to_track(x, z)
			if d > 210.0 and d < 400.0 and Vector2(x, z).distance_to(terrain.center) < track.mountain_start - 40.0 \
					and terrain.height_at(x, z) > terrain.water_level + 3.0:
				var score := 0.0
				for i in range(0, count, 8):
					var to := Vector2(x - track.samples[i].x, z - track.samples[i].z)
					var dist := to.length()
					var t := Vector2(track.tangents[i].x, track.tangents[i].z).normalized()
					var ahead := t.dot(to / dist)
					if ahead > 0.82 and dist < 700.0:
						score += (ahead - 0.82) * (1.0 - dist / 700.0)
				if score > main_score:
					main_score = score
					main = Vector3(x, 0.0, z)
			z += 40.0
		x += 40.0
	if main == Vector3.INF:
		return center
	_place_pyramid(node, main, 132.0, true)
	# As outras duas, de lado em relação à pista e um pouco mais longe.
	var near_i := terrain.nearest_track_index(main.x, main.z)
	var away := (main - track.samples[maxi(near_i, 0)])
	away.y = 0.0
	away = away.normalized()
	var across := Vector3(-away.z, 0.0, away.x)
	for k: Array in [[1.0, 165.0, 60.0, 104.0], [-1.0, 150.0, 130.0, 70.0]]:
		var p: Vector3 = main + across * float(k[0]) * float(k[1]) + away * float(k[2])
		if terrain.distance_to_track(p.x, p.z) > 190.0:
			_place_pyramid(node, p, k[3], false)
	return center


func _place_pyramid(node: Node3D, at: Vector3, base: float, capstone: bool) -> void:
	var height := base * 0.63
	var y := _ground_min(at.x, at.z, base * 0.8) - base * 0.04
	var md := Track.MeshData.new()
	var cap_h := height * 0.07 if capstone else 0.0
	var cut := 1.0 - cap_h / height
	if capstone:
		# Tronco com o topo reto; a ponta de ouro vai em cima.
		frustum(md, base, base, base * (1.0 - cut), base * (1.0 - cut), height * cut)
	else:
		pyramid(md, base, height)
	var basis := Basis(Vector3.UP, rng.randf_range(-0.3, 0.3))
	var mi := _add(md.to_mesh(stone({"block_w": 3.2, "block_h": 1.6, "sand_cover": 0.35, "joints": 0.8})), Transform3D(basis, Vector3(at.x, y, at.z)), node)
	mi.name = "Piramide"
	reserved.append(Vector3(at.x, at.z, base * 0.75))
	if not capstone:
		return
	# Ponta de ouro com o logo "at" nas quatro faces.
	var top := base * (1.0 - cut)
	var cap := Track.MeshData.new()
	pyramid(cap, top, cap_h)
	var cap_xf := Transform3D(basis, Vector3(at.x, y + height * cut, at.z))
	_add(cap.to_mesh(gold()), cap_xf, node).name = "PontaDeOuro"
	var slope := atan2(cap_h, top * 0.5)
	var logo_mat := TrackScenery.brand_material(LOGO_ICON, GOLD, 1.0, {"logo_fill": 0.7, "recolor": true,
			"recolor_main": LAPIS, "recolor_accent": Color.WHITE, "emission": 0.3})
	var quad := QuadMesh.new()
	quad.size = Vector2(top * 0.5, top * 0.5)
	for k in 4:
		var face := Basis(Vector3.UP, k * PI * 0.5) * Basis(Vector3.RIGHT, -(PI * 0.5 - slope))
		var p := face * Vector3(0, 0, 0.02) + Basis(Vector3.UP, k * PI * 0.5) * Vector3(0, cap_h * 0.33, top * 0.5 * 0.67)
		_add(quad, cap_xf * Transform3D(face, p), node, false).material_override = logo_mat


# --- Templo ------------------------------------------------------------------------------

## Reta mais reta (sem ponte nem trecho especial) entre as frações `a` e `b`, com
## `span` m livres: índice do meio ou -1.
static func _find_straight(p_track: Track, a: float, b: float, span: float) -> int:
	var count := p_track.samples.size()
	var step := p_track.length / count
	var half := int(span * 0.5 / step)
	var best := -1
	var best_k := INF
	for i in range(int(a * count), int(b * count)):
		var worst := 0.0
		var ok := true
		for k in range(-half, half + 1):
			var j := (i + k + count) % count
			if not p_track.is_plain(j):
				ok = false
				break
			worst = maxf(worst, absf(p_track.curvature[j]))
		if ok and worst < best_k:
			best_k = worst
			best = i
	return best


## Ponto ao lado da pista na amostra `i` (lateral em m, + = direita), na altura do chão.
func _beside(i: int, lateral: float, along := 0.0) -> Vector3:
	var p := track.samples[i] + track.rights[i] * lateral + track.tangents[i] * along
	return Vector3(p.x, terrain.height_at(p.x, p.z), p.z)


## O ponto está livre de outros trechos da pista (a esta distância só a pista da amostra)?
func _clear(p: Vector3, lateral: float) -> bool:
	return terrain.distance_to_track(p.x, p.z) > absf(lateral) - 2.0


## Amostra do meio da reta do templo (o portal), ou -1.
static func temple_center(p_track: Track) -> int:
	return _find_straight(p_track, 0.82, 0.98, 70.0)


func _build_temple() -> void:
	var c := temple_center(track)
	if c < 0:
		return
	var node := _node("Templo")
	var count := track.samples.size()
	var step := track.length / count
	var at := func(m: float) -> int: return (c + int(round(m / step)) + count) % count
	var fwd := track.tangents[c]
	fwd.y = 0.0
	fwd = fwd.normalized()
	# Portal: dois pilonos por fora dos montes de areia e a viga por cima da pista.
	var gate := _node("PortalDoTemplo", node)
	var g := track.samples[c]
	gate.transform = Transform3D(_facing(-fwd), Vector3(g.x, 0.0, g.z))
	var lane := _outside + 3.2
	var tw0 := 9.0
	var th := 16.0
	var towers := Track.MeshData.new()
	var cornices := Track.MeshData.new()
	var ground := g.y
	for side: float in [-1.0, 1.0]:
		var tx := side * (lane + tw0 * 0.5)
		var wp := gate.transform * Vector3(tx, 0, 0)
		var y0 := minf(terrain.height_at(wp.x, wp.z), ground) - 1.0
		frustum(towers, tw0, 4.2, tw0 * 0.78, 3.2, th - y0 + ground, y0, Vector3(tx, 0, 0))
		frustum(cornices, tw0 * 0.78, 3.2, tw0 * 0.78 + 1.0, 4.2, 1.3, ground + th, Vector3(tx, 0, 0))
		reserved.append(Vector3(wp.x, wp.z, 9.0))
	_add(towers.to_mesh(stone({"glyph_cols": 4.0, "glyph_u": Vector2(0.1, 0.9), "glyph_v": Vector2(ground + 1.5, ground + 13.5), "glyph_size": 0.95})), Transform3D(), gate)
	_add(cornices.to_mesh(stone({"band_v": Vector4(ground + th, ground + th + 1.3, 2.4, 0.8)})), Transform3D(), gate)
	var beam := Track.MeshData.new()
	var span := lane + tw0 * 0.2
	frustum(beam, span * 2.0, 3.0, span * 2.0, 3.0, 2.6, ground + 10.4)
	_add(beam.to_mesh(stone({"block_w": 3.0, "block_h": 0.85})), Transform3D(), gate)
	var panel := QuadMesh.new()
	panel.size = Vector2(lane * 2.0 - 2.0, 2.0)
	for back in 2:
		var b := Basis(Vector3.UP, PI * back)
		_add(panel, Transform3D(b, b * Vector3(0, ground + 11.7, 1.52)), gate, false).material_override = TrackScenery.brand_material(
				WORDMARK_DARK, TrackScenery.NAVY, panel.size.x / panel.size.y, {"logo_fill": 0.62, "border_width": 0.07, "border_color": GOLD, "emission": 0.3})
		var disk := _node("DiscoAlado", gate)
		disk.transform = Transform3D(b, b * Vector3(0, ground + 14.6, 1.0))
		_build_winged_disk(disk, Vector3.ZERO, 1.25)
	# Avenida de esfinges antes do portal (viradas para a pista) e obeliscos na frente dele.
	var small := sphinx_mesh(0.32)
	var plinth := Track.MeshData.new()
	frustum(plinth, 2.4, 4.4, 2.2, 4.2, 1.2, -0.6)
	var plinth_mesh := plinth.to_mesh(stone({"block_w": 1.4, "block_h": 0.6}))
	var sx: Array[Transform3D] = []
	var px: Array[Transform3D] = []
	var lat := _outside + 5.0
	for k in 7:
		var i: int = at.call(-16.0 - k * 9.0)
		for side: float in [-1.0, 1.0]:
			var p := _beside(i, side * lat)
			if not _clear(p, lat):
				continue
			var face := _facing(-track.rights[i] * side)
			px.append(Transform3D(face, p))
			sx.append(Transform3D(face, p + Vector3.UP * 0.55))
			reserved.append(Vector3(p.x, p.z, 3.5))
	_multimesh(small, sx, "AvenidaDeEsfinges", node)
	_multimesh(plinth_mesh, px, "Pedestais", node)
	var obelisk := obelisk_mesh(15.0, 1.7)
	for side: float in [-1.0, 1.0]:
		var p := _beside(at.call(-9.0), side * (_outside + 4.5))
		if _clear(p, _outside + 4.5):
			_add(obelisk, Transform3D(Basis(), p), node)
			reserved.append(Vector3(p.x, p.z, 3.0))
	# Colunata depois do portal: colunas com vigas ligando uma na outra (ao longo da pista).
	var col_mesh := column_mesh(10.0, 0.9)
	var cx: Array[Transform3D] = []
	var beams := MeshMerge.new()
	var beam_count := 0
	for side: float in [-1.0, 1.0]:
		var prev := Vector3.INF
		for k in 7:
			var i: int = at.call(12.0 + k * 7.5)
			var p := _beside(i, side * (_outside + 4.6))
			if not _clear(p, _outside + 4.6):
				prev = Vector3.INF
				continue
			# A base afunda na areia; o alto fica no nível da pista + 10 m.
			var top := track.samples[i].y + 10.0
			var y0 := minf(p.y, track.samples[i].y) - 0.5
			cx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, (top - y0) / 10.0, 1.0)), Vector3(p.x, y0, p.z)))
			var cap_top := Vector3(p.x, top + 0.45, p.z)
			if prev != Vector3.INF and rng.randf() < 0.8:
				var d := cap_top - prev
				var mid := (cap_top + prev) * 0.5
				var bb := Basis.looking_at(d.normalized(), Vector3.UP)
				beams.append_from(_box(Vector3(1.6, 1.0, d.length() + 1.4)), 0, Transform3D(bb, mid))
				beam_count += 1
			prev = cap_top
			reserved.append(Vector3(p.x, p.z, 3.0))
	_multimesh(col_mesh, cx, "Colunata", node)
	if beam_count > 0:
		beams.set_material(stone({"block_w": 4.0, "block_h": 1.0}))
		_add(beams.commit(), Transform3D(), node).name = "Vigas"
	# Esfinge gigante do lado de fora, olhando a pista.
	var i_s: int = at.call(-38.0)
	var side_s := track.outer_side_at(i_s)
	for tries in 3:
		var lat_s := 44.0 + tries * 10.0
		var p := _beside(i_s, side_s * lat_s)
		if terrain.distance_to_track(p.x, p.z) < lat_s - 6.0 or _is_reserved(p.x, p.z, 10.0):
			continue
		var y := _ground_min(p.x, p.z, 10.0) - 0.4
		_add(sphinx_mesh(2.1), Transform3D(_facing(-track.rights[i_s] * side_s), Vector3(p.x, y, p.z)), node).name = "Esfinge"
		reserved.append(Vector3(p.x, p.z, 16.0))
		break


# --- Obeliscos, ruínas e camelos -------------------------------------------------------

## Pares de obeliscos nas retas comuns (fora do templo e da largada).
func _build_obelisk_pairs() -> void:
	var node := _node("Obeliscos")
	var mesh := obelisk_mesh(12.0, 1.4)
	var count := track.samples.size()
	var placed := 0
	var last := -INF
	for i in range(0, count, 3):
		var d := track.distances[i]
		if d < 120.0 or d > track.length - 90.0 or d - last < 260.0 or not track.is_plain(i) or absf(track.curvature[i]) > 0.006:
			continue
		var ok := true
		for side: float in [-1.0, 1.0]:
			var p := _beside(i, side * (_outside + 4.0))
			if not _clear(p, _outside + 4.0) or _is_reserved(p.x, p.z, 3.0):
				ok = false
		if not ok:
			continue
		for side: float in [-1.0, 1.0]:
			var p := _beside(i, side * (_outside + 4.0))
			_add(mesh, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)), p - Vector3.UP * 0.3), node)
			reserved.append(Vector3(p.x, p.z, 3.0))
		last = d
		placed += 1
		if placed >= 4:
			break


## Ruínas espalhadas perto da pista: pedaços de coluna em pé, tambores de coluna caídos
## e blocos de pedra meio enterrados.
func _build_ruins() -> void:
	var node := _node("Ruinas")
	var drum := Track.MeshData.new()
	shaft(drum, 0.85, 0.85, 1.6, 0.0, 12)
	var drum_mesh := drum.to_mesh(stone({"glyph_cols": 5.0, "glyph_u": Vector2(0.0, 1.0), "glyph_v": Vector2(0.2, 1.4), "glyph_size": 0.6, "joints": 0.0}))
	var block := Track.MeshData.new()
	frustum(block, 2.4, 1.6, 2.4, 1.6, 1.2)
	var block_mesh := block.to_mesh(stone({"block_w": 9.0, "block_h": 9.0, "joints": 0.0}))
	var dx: Array[Transform3D] = []
	var bx: Array[Transform3D] = []
	var tries := 0
	while dx.size() + bx.size() < 70 and tries < 900:
		tries += 1
		var i := rng.randi() % track.samples.size()
		if not track.is_plain(i):
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lat := side * rng.randf_range(_outside + 5.0, _outside + 45.0)
		var p := _beside(i, lat)
		if not _clear(p, absf(lat)) or _is_reserved(p.x, p.z, 2.0) or p.y < terrain.water_level + 0.5:
			continue
		var r := rng.randf()
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		if r < 0.35:
			# Coluna quebrada em pé (um a três tambores).
			for k in rng.randi_range(1, 3):
				dx.append(Transform3D(yaw * Basis(Vector3.UP, k * 0.4), p + Vector3.UP * (k * 1.6 - 0.4)))
		elif r < 0.7:
			# Tambores caídos rolados na areia.
			var lie := yaw * Basis(Vector3.FORWARD, PI * 0.5)
			for k in rng.randi_range(1, 3):
				dx.append(Transform3D(lie, p + yaw * Vector3(0.0, 0.55, k * 2.0) + yaw * Vector3(-0.8, 0, 0)))
		else:
			bx.append(Transform3D(yaw * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)), p - Vector3.UP * rng.randf_range(0.2, 0.6)))
	_multimesh(drum_mesh, dx, "Colunas", node)
	_multimesh(block_mesh, bx, "Blocos", node)


## Caravana de camelos dando a volta na pirâmide do meio, pelas dunas.
func _build_caravan(center: Vector4) -> void:
	var radius := center.w + 16.0
	var path := PackedVector3Array()
	var steps := int(TAU * radius / 5.0)
	for k in steps:
		var a := TAU * k / steps
		var x := center.x + cos(a) * radius
		var z := center.z + sin(a) * radius
		if terrain.distance_to_track(x, z) < _outside + 6.0:
			return
		path.append(Vector3(x, terrain.height_at(x, z) - 0.05, z))
	var node := _node("Caravana")
	var mesh := camel_mesh()
	for k in 5:
		var camel := CARAVAN.new() as Caravan
		camel.name = "Camelo"
		camel.path = path
		camel.speed = 1.5
		camel.offset = -k * 4.6
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		camel.add_child(mi)
		node.add_child(camel)
