@tool
class_name TrackScenery
extends RefCounted
## Decoração em volta da pista: arquibancada, bandeiras, outdoors e placas de curva
## com a marca da Ativos, árvores, arbustos, grama, flores, dirigível e balões.

const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")
const TUFT_SHADER := preload("res://shaders/grass_tuft.gdshader")
const BRAND_SHADER := preload("res://shaders/brand_panel.gdshader")
const SIGN_SHADER := preload("res://shaders/chevron_sign.gdshader")
const PROP_SHADER := preload("res://shaders/prop_body.gdshader")
const CROWD_SHADER := preload("res://shaders/crowd.gdshader")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")
const WORDMARK := preload("res://assets/logos/ativos_marca.png")
const WORDMARK_DARK := preload("res://assets/logos/ativos_marca_branca.png")

## Grupo dos detalhes pequenos (grama, flores): somem com o cenário "Reduzido" das
## opções de gráficos (GraphicsQuality).
const DETAIL_GROUP := &"detalhe_cenario"

const BRAND_BLUE := Color("263dbf")
const BRAND_LIGHT := Color("5f72d9")
const NAVY := Color("0f1838")
const YELLOW := Color("ffd21a")
const RED := Color("ef2b2d")

var track: Track
var terrain: TrackTerrain
var root: Node3D
var rng := RandomNumberGenerator.new()

## Distância do centro da pista a partir da qual fica o lado de fora da mureta.
var _outside := 0.0
var _start := Vector2.ZERO
## Áreas sem árvores (arquibancada, outdoors): Vector3(x, z, raio).
var _reserved: Array[Vector3] = []


func _init(p_track: Track, p_terrain: TrackTerrain, p_root: Node3D) -> void:
	track = p_track
	terrain = p_terrain
	root = p_root


func build(preview: bool) -> void:
	rng.seed = track.decoration_seed
	_outside = track.road_width * 0.5 + track.shoulder_width + track.wall_thickness
	var start := track.get_point_at(0.0)
	_start = Vector2(start.x, start.z)
	_build_grandstand()
	_build_flags()
	_build_billboards()
	_build_turn_signs()
	# Decorações de cada cenário (farol, caixa-d'água, chalés...). Usam um sorteio
	# próprio para não mudar a decoração das pistas que já existem.
	var props := TrackProps.new(self)
	props.build_landmarks(preview)
	if track.scenery == TrackTheme.Scenery.CAMPO:
		_build_trees()
	else:
		props.build_trees()
	_build_bushes()
	_build_grass(preview)
	props.build_details(preview)
	if track.show_blimp:
		_build_blimp()
	_build_balloons()


# --- Materiais compartilhados ---------------------------------------------------------

## Material de painel com logo (veja shaders/brand_panel.gdshader).
static func brand_material(logo: Texture2D, bg: Color, panel_aspect: float, options := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BRAND_SHADER
	m.set_shader_parameter("logo", logo)
	m.set_shader_parameter("bg_color", bg)
	m.set_shader_parameter("panel_aspect", panel_aspect)
	m.set_shader_parameter("logo_aspect", float(logo.get_width()) / logo.get_height())
	for key: String in options:
		m.set_shader_parameter(key, options[key])
	return m


static func color_material(color: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _add_mesh(mesh: Mesh, xform: Transform3D, parent: Node3D = null, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else root).add_child(mi)
	return mi


## Desenha muitas cópias de uma malha. As cópias são divididas em blocos de
## `chunk` metros para a câmera descartar o que não vê; `max_distance` > 0 some com
## o bloco inteiro de longe (grama, flores). `detail`: entra no DETAIL_GROUP.
func _add_multimesh(mesh: Mesh, xforms: Array[Transform3D], colors: Array[Color], name: String,
		shadows := true, chunk := 140.0, max_distance := 0.0, detail := false) -> void:
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
		if max_distance > 0.0:
			mmi.visibility_range_end = max_distance + chunk * 0.7
		if detail:
			mmi.add_to_group(DETAIL_GROUP)
		root.add_child(mmi)


func _is_reserved(x: float, z: float) -> bool:
	for r in _reserved:
		if Vector2(x - r.x, z - r.y).length() < r.z:
			return true
	return false


## Base (x, z) de um ponto ao lado da pista: índice da amostra + deslocamento lateral.
func _beside(index: int, lateral: float, along := 0.0) -> Vector3:
	return track.samples[index] + track.rights[index] * lateral + track.tangents[index] * along


## Orientação de um painel (frente = +Z) virado para `facing`, em pé.
static func _panel_basis(facing: Vector3) -> Basis:
	var z := Vector3(facing.x, 0.0, facing.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


# --- Arquibancada ------------------------------------------------------------------

func _build_grandstand() -> void:
	var side := track.outer_side_at(0)
	var lateral := side * (_outside + 3.0)
	var stand := Node3D.new()
	stand.name = "Arquibancada"
	stand.transform = track.get_transform_at(0.0) * Transform3D(Basis(Vector3.UP, PI if side < 0.0 else 0.0), Vector3(lateral, 0.0, -6.0))
	root.add_child(stand)
	var center := stand.transform * Vector3(4.5, 0.0, 0.0)
	_reserved.append(Vector3(center.x, center.z, 34.0))

	var steps := 6
	var stand_length := 48.0
	var step_mat := color_material(Color(0.82, 0.84, 0.88), 0.85)
	var seat_mats: Array[StandardMaterial3D] = [color_material(BRAND_BLUE, 0.5), color_material(YELLOW, 0.5)]
	var crowd_colors := [RED, BRAND_BLUE, YELLOW, Color(0.3, 0.8, 0.45), Color(0.97, 0.97, 0.97),
			Color(0.85, 0.4, 0.9), BRAND_LIGHT, Color(1.0, 0.55, 0.15)]
	var crowd: Array[Transform3D] = []
	var crowd_cols: Array[Color] = []
	var per_row := 44
	for s in steps:
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 0.8 * (s + 1), stand_length)
		box.material = step_mat
		var x := 1.6 * s + 0.8
		_add_mesh(box, Transform3D(Basis(), Vector3(x, 0.4 * (s + 1), 0.0)), stand)
		var seat := BoxMesh.new()
		seat.size = Vector3(0.5, 0.18, stand_length)
		seat.material = seat_mats[s % 2]
		_add_mesh(seat, Transform3D(Basis(), Vector3(x - 0.5, 0.8 * (s + 1) + 0.09, 0.0)), stand)
		for k in per_row:
			if rng.randf() < 0.12:
				continue
			var z := -stand_length * 0.5 + 0.8 + k * (stand_length - 1.6) / (per_row - 1) + rng.randf_range(-0.15, 0.15)
			crowd.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3) - PI * 0.5),
					Vector3(x + rng.randf_range(-0.25, 0.15), 0.8 * (s + 1), z)))
			crowd_cols.append(crowd_colors[rng.randi() % crowd_colors.size()])
	var crowd_mesh := _person_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = crowd_mesh
	mm.instance_count = crowd.size()
	for i in crowd.size():
		mm.set_instance_transform(i, crowd[i])
		mm.set_instance_color(i, crowd_cols[i])
	var crowd_mi := MultiMeshInstance3D.new()
	crowd_mi.multimesh = mm
	crowd_mi.name = "Torcida"
	stand.add_child(crowd_mi)

	# Cobertura azul com a marca na frente.
	var roof_w := 10.5
	var roof := BoxMesh.new()
	roof.size = Vector3(roof_w, 0.35, stand_length + 1.5)
	roof.material = color_material(BRAND_BLUE, 0.45)
	var roof_xf := Transform3D(Basis(Vector3.FORWARD, -0.1), Vector3(4.6, 8.4, 0.0))
	_add_mesh(roof, roof_xf, stand)
	var fascia := QuadMesh.new()
	fascia.size = Vector2(stand_length + 1.5, 1.6)
	fascia.material = brand_material(WORDMARK_DARK, NAVY, (stand_length + 1.5) / 1.6,
			{"logo_count": 4, "logo_fill": 0.62, "border_width": 0.07, "border_color": YELLOW})
	_add_mesh(fascia, Transform3D(Basis(Vector3.UP, -PI * 0.5), roof_xf * Vector3(-roof_w * 0.5 - 0.05, -0.55, 0.0)), stand)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.16
	pole.bottom_radius = 0.2
	pole.height = 9.0
	pole.radial_segments = 8
	pole.material = color_material(Color(0.95, 0.95, 0.97), 0.4, 0.3)
	for z in [-stand_length * 0.5 + 0.6, -stand_length * 0.17, stand_length * 0.17, stand_length * 0.5 - 0.6]:
		_add_mesh(pole, Transform3D(Basis(), Vector3(8.9, 4.5, z)), stand)


static func _person_mesh() -> ArrayMesh:
	var st := MeshMerge.new()
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 0.78
	body.radial_segments = 8
	body.rings = 2
	st.append_from(body, 0, Transform3D(Basis(), Vector3(0.0, 0.39, 0.0)))
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	head.radial_segments = 8
	head.rings = 4
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0.0, 0.93, 0.0)))
	var m := ShaderMaterial.new()
	m.shader = CROWD_SHADER
	m.set_shader_parameter("head_start", 0.77)
	st.set_material(m)
	return st.commit()


# --- Bandeiras na reta de largada ------------------------------------------------------

func _build_flags() -> void:
	var variants: Array[ShaderMaterial] = [
		brand_material(LOGO_ICON, BRAND_BLUE, 1.6, {"recolor": true, "recolor_main": Color.WHITE, "recolor_accent": YELLOW, "wave": 0.22, "logo_fill": 0.62}),
		brand_material(LOGO_ICON, Color.WHITE, 1.6, {"wave": 0.22, "logo_fill": 0.62}),
		brand_material(LOGO_ICON, YELLOW, 1.6, {"wave": 0.22, "logo_fill": 0.62}),
	]
	var flag := QuadMesh.new()
	flag.size = Vector2(2.4, 1.5)
	flag.subdivide_width = 10
	flag.subdivide_depth = 2
	flag.center_offset = Vector3(1.2, 0.0, 0.0)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 6.6
	pole.radial_segments = 6
	pole.material = color_material(Color(0.95, 0.95, 0.97), 0.35, 0.4)
	var n := 0
	for along in range(-56, 64, 9):
		if absi(along) < 6:
			continue
		for side: float in [-1.0, 1.0]:
			var lateral := side * (_outside + 1.0)
			var xf := track.get_transform_at(float(along), lateral)
			var p := xf.origin
			if terrain.distance_to_track(p.x, p.z) < absf(lateral) - 1.0:
				continue
			var t := -xf.basis.z
			var right := t.cross(Vector3.UP).normalized()
			_add_mesh(pole, Transform3D(Basis(), p + Vector3.UP * 3.3), null)
			var flag_basis := Basis(-side * t, Vector3.UP, -side * right)
			var mi := _add_mesh(flag, Transform3D(flag_basis, p + Vector3.UP * 5.7), null, false)
			mi.material_override = variants[n % variants.size()]
			n += 1


# --- Outdoors --------------------------------------------------------------------------

func _build_billboards() -> void:
	var variants: Array[ShaderMaterial] = [
		brand_material(WORDMARK, Color.WHITE, 13.0 / 4.5, {"logo_fill": 0.5, "border_width": 0.12, "border_color": YELLOW}),
		brand_material(LOGO_ICON, BRAND_BLUE, 13.0 / 4.5, {"recolor": true, "recolor_main": Color.WHITE, "recolor_accent": YELLOW,
				"logo_fill": 0.72, "logo_count": 2, "stripes": 0.6, "border_width": 0.12, "border_color": Color.WHITE}),
		brand_material(WORDMARK_DARK, NAVY, 13.0 / 4.5, {"logo_fill": 0.5, "border_width": 0.12, "border_color": BRAND_LIGHT}),
		brand_material(LOGO_ICON, YELLOW, 13.0 / 4.5, {"logo_fill": 0.74, "logo_count": 2, "border_width": 0.12, "border_color": BRAND_BLUE}),
	]
	var board := QuadMesh.new()
	board.size = Vector2(13.0, 4.5)
	var frame := BoxMesh.new()
	frame.size = Vector3(13.6, 5.1, 0.35)
	frame.material = color_material(NAVY, 0.5)
	var leg := BoxMesh.new()
	leg.size = Vector3(0.4, 1.0, 0.4)
	leg.material = color_material(Color(0.75, 0.77, 0.82), 0.4, 0.5)
	var count := track.samples.size()
	var step_len := track.length / count
	var last := -INF
	var n := 0
	var i := int(60.0 / step_len)
	# No deserto, a reta do templo (portal, colunata e esfinges) fica sem outdoor.
	var temple := TrackEgypt.temple_center(track) if track.scenery == TrackTheme.Scenery.DESERTO else -1
	while i < count and track.distances[i] < track.length - 50.0:
		var ok := track.distances[i] - last > 105.0 and absf(track.curvature[i]) < 0.012 and not track.is_bridge(i)
		if temple >= 0 and absf(wrapf(track.distances[i] - track.distances[temple], -track.length * 0.5, track.length * 0.5)) < 110.0:
			ok = false
		if ok:
			var side := track.outer_side_at(i)
			var dist_out := _outside + 8.0
			var pos := _beside(i, side * dist_out)
			var ground := terrain.height_at(pos.x, pos.z)
			var rel := ground - track.samples[i].y
			if terrain.distance_to_track(pos.x, pos.z) > dist_out - 1.5 and ground > terrain.water_level + 0.3 and rel < 6.0 and rel > -4.0:
				var facing := (-track.tangents[i] * 0.55 - track.rights[i] * side).normalized()
				var b := _panel_basis(facing)
				var center := Vector3(pos.x, ground + 4.6, pos.z)
				_add_mesh(frame, Transform3D(b, center - b.z * 0.2))
				var mi := _add_mesh(board, Transform3D(b, center))
				mi.material_override = variants[n % variants.size()]
				var leg_h := center.y - (ground - 1.5)
				for lx: float in [-4.5, 4.5]:
					var base := center + b.x * lx - b.z * 0.25
					_add_mesh(leg, Transform3D(Basis().scaled(Vector3(1.0, leg_h, 1.0)), Vector3(base.x, ground - 1.5 + leg_h * 0.5, base.z)))
				_reserved.append(Vector3(pos.x, pos.z, 10.0))
				last = track.distances[i]
				n += 1
		i += maxi(1, int(6.0 / step_len))


# --- Placas de curva ------------------------------------------------------------------

func _build_turn_signs() -> void:
	var count := track.samples.size()
	var step_len := track.length / count
	var board := QuadMesh.new()
	board.size = Vector2(5.2, 1.6)
	var back := BoxMesh.new()
	back.size = Vector3(5.5, 1.9, 0.2)
	back.material = color_material(NAVY, 0.5)
	var leg := BoxMesh.new()
	leg.size = Vector3(0.22, 3.2, 0.22)
	leg.material = color_material(Color(0.75, 0.77, 0.82), 0.4, 0.5)
	var mats := {}
	var last := -INF
	for i in count:
		var k := track.curvature[i]
		if absf(k) < 0.019 or track.distances[i] - last < 30.0:
			continue
		var j := (i + int(8.0 / step_len)) % count
		var turn := signf(track.curvature[j])
		if turn == 0.0 or track.is_bridge(j):
			continue
		var side := -turn
		var lateral := side * (_outside + 1.3)
		var pos := _beside(j, lateral)
		if terrain.distance_to_track(pos.x, pos.z) < absf(lateral) - 1.0:
			continue
		var facing := (-track.tangents[j] * 0.9 - track.rights[j] * side * 0.45).normalized()
		var b := _panel_basis(facing)
		var center := pos + Vector3.UP * 2.6
		if not mats.has(turn):
			var m := ShaderMaterial.new()
			m.shader = SIGN_SHADER
			m.set_shader_parameter("direction", turn)
			m.set_shader_parameter("panel_aspect", 5.2 / 1.6)
			mats[turn] = m
		var mi := _add_mesh(board, Transform3D(b, center))
		mi.material_override = mats[turn]
		_add_mesh(back, Transform3D(b, center - b.z * 0.13))
		for lx: float in [-2.0, 2.0]:
			_add_mesh(leg, Transform3D(b, pos + b.x * lx - b.z * 0.2 + Vector3.UP * 1.0))
		last = track.distances[i]


# --- Árvores e arbustos --------------------------------------------------------------

## `center` = centro da copa (a normal é puxada para a de uma esfera em volta dele,
## dando volume à copa inteira); `normal_blend` = quanto puxar (0 = normal da malha).
static func _foliage_material(base_h: float, top_h: float, center: Vector3, normal_blend := 0.55) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	m.set_shader_parameter("base_height", base_h)
	m.set_shader_parameter("top_height", top_h)
	m.set_shader_parameter("canopy_center", center)
	m.set_shader_parameter("canopy_normal_blend", normal_blend)
	return m


static func _blob_mesh(blobs: Array[Vector4], material: Material, segments := 12) -> ArrayMesh:
	var st := MeshMerge.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = segments
	sphere.rings = segments / 2
	for b in blobs:
		st.append_from(sphere, 0, Transform3D(Basis().scaled(Vector3.ONE * b.w), Vector3(b.x, b.y, b.z)))
	st.set_material(material)
	# Copas e arbustos se repetem centenas de vezes: de longe usam versões simplificadas.
	return st.commit(null, true)


static func _trunk_surface(mesh: ArrayMesh, height: float, radius: float) -> void:
	var st := MeshMerge.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = radius * 0.65
	trunk.bottom_radius = radius
	trunk.height = height
	trunk.radial_segments = 7
	trunk.rings = 1
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0.0, height * 0.5 - 0.3, 0.0)))
	st.set_material(color_material(Color(0.45, 0.29, 0.17), 0.9))
	st.commit(mesh)


static func _broadleaf_mesh() -> ArrayMesh:
	var blobs: Array[Vector4] = [Vector4(0.0, 4.4, 0.0, 2.2), Vector4(1.3, 3.7, 0.4, 1.6), Vector4(-1.2, 3.8, -0.3, 1.7),
			Vector4(0.2, 3.5, -1.3, 1.5), Vector4(-0.2, 3.6, 1.3, 1.5), Vector4(-0.3, 5.6, 0.2, 1.4)]
	var mesh := _blob_mesh(blobs, _foliage_material(2.2, 6.6, Vector3(0.0, 4.3, 0.0)), 10)
	_trunk_surface(mesh, 3.4, 0.38)
	return mesh


## `snow` = neve no alto dos galhos (cenário de neve).
static func _pine_mesh(snow := 0.0) -> ArrayMesh:
	var st := MeshMerge.new()
	for tier: Vector3 in [Vector3(2.4, 3.2, 2.7), Vector3(1.85, 2.8, 4.5), Vector3(1.25, 2.4, 6.1)]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier.x
		cone.height = tier.y
		cone.radial_segments = 10
		cone.rings = 1
		st.append_from(cone, 0, Transform3D(Basis(), Vector3(0.0, tier.z, 0.0)))
	var mat := _foliage_material(1.0, 7.4, Vector3(0.0, 4.4, 0.0), 0.35)
	mat.set_shader_parameter("snow_cover", snow)
	st.set_material(mat)
	var mesh := st.commit(null, true)
	_trunk_surface(mesh, 1.9, 0.3)
	return mesh


func _build_trees() -> void:
	var forest := FastNoiseLite.new()
	forest.seed = track.decoration_seed + 5
	forest.frequency = 0.012
	var area := terrain.half_extent + Vector2(270.0, 270.0)
	var rounds: Array[Transform3D] = []
	var round_colors: Array[Color] = []
	var pines: Array[Transform3D] = []
	var pine_colors: Array[Color] = []
	var attempts := 0
	while rounds.size() + pines.size() < track.tree_count and attempts < track.tree_count * 14:
		attempts += 1
		var x := terrain.center.x + rng.randf_range(-area.x, area.x)
		var z := terrain.center.y + rng.randf_range(-area.y, area.y)
		var d := terrain.distance_to_track(x, z)
		if d < _outside + 3.5 or Vector2(x, z).distance_to(_start) < 40.0 or _is_reserved(x, z):
			continue
		var y := terrain.height_at(x, z)
		if y < terrain.water_level + 0.4 or y > 70.0:
			continue
		if absf(terrain.height_at(x + 2.5, z) - y) > 1.8 or absf(terrain.height_at(x, z + 2.5) - y) > 1.8:
			continue
		var keep := (0.25 + 0.75 * smoothstep(-0.2, 0.35, forest.get_noise_2d(x, z))) * lerpf(1.0, 0.35, smoothstep(40.0, 280.0, d))
		if rng.randf() > keep:
			continue
		var s := rng.randf_range(0.8, 1.45)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y - 0.1, z))
		if y > 14.0 or rng.randf() < 0.28:
			pines.append(xf)
			pine_colors.append(Color.from_hsv(rng.randf_range(0.36, 0.42), rng.randf_range(0.6, 0.8), rng.randf_range(0.4, 0.56)))
		else:
			rounds.append(xf)
			var roll := rng.randf()
			if roll < 0.09:
				round_colors.append(Color.from_hsv(rng.randf_range(0.9, 0.96), rng.randf_range(0.3, 0.42), 1.0))
			elif roll < 0.16:
				round_colors.append(Color.from_hsv(rng.randf_range(0.1, 0.14), rng.randf_range(0.65, 0.8), 1.0))
			else:
				round_colors.append(Color.from_hsv(rng.randf_range(0.23, 0.32), rng.randf_range(0.62, 0.85), rng.randf_range(0.62, 0.88)))
	_add_multimesh(_broadleaf_mesh(), rounds, round_colors, "Arvores")
	_add_multimesh(_pine_mesh(), pines, pine_colors, "Pinheiros")


func _build_bushes() -> void:
	var blobs: Array[Vector4] = [Vector4(0.0, 0.55, 0.0, 0.95), Vector4(0.8, 0.4, 0.25, 0.7), Vector4(-0.75, 0.45, -0.2, 0.75), Vector4(0.1, 0.4, -0.75, 0.6)]
	var bush_mat := _foliage_material(0.0, 1.5, Vector3(0.0, 0.25, 0.0))
	bush_mat.set_shader_parameter("snow_cover", TrackTheme.snow_cover(track.scenery))
	var mesh := _blob_mesh(blobs, bush_mat, 8)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var count := track.samples.size()
	var target := track.tree_count / 2
	var attempts := 0
	while xforms.size() < target and attempts < target * 8:
		attempts += 1
		var i := rng.randi() % count
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p := _beside(i, side * (_outside + rng.randf_range(1.2, 9.0)), rng.randf_range(-2.0, 2.0))
		if terrain.distance_to_track(p.x, p.z) < _outside + 1.0 or _is_reserved(p.x, p.z) or Vector2(p.x, p.z).distance_to(_start) < 30.0:
			continue
		var y := terrain.height_at(p.x, p.z)
		if y < terrain.water_level + 0.3:
			continue
		var s := rng.randf_range(0.7, 1.5)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.1), s)), Vector3(p.x, y - 0.15, p.z)))
		if track.beach_track:
			# Praia de areia branca: arbustos verdes (a cor vem das flores e das moitas floridas).
			colors.append(Color.from_hsv(rng.randf_range(0.25, 0.36), rng.randf_range(0.7, 0.9), rng.randf_range(0.45, 0.7)))
		else:
			colors.append(TrackTheme.bush_color(track.scenery, rng))
	_add_multimesh(mesh, xforms, colors, "Arbustos", true, 100.0, 380.0)


# --- Grama e flores ----------------------------------------------------------------------

## Planos cruzados (UV.y = 0 em cima, 1 na base).
static func _cross_quads(width: float, height: float, planes: int, material: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for k in planes:
		var b := Basis(Vector3.UP, PI * k / planes)
		var base := verts.size()
		for c: Vector3 in [Vector3(-width * 0.5, 0, 0), Vector3(width * 0.5, 0, 0), Vector3(width * 0.5, height, 0), Vector3(-width * 0.5, height, 0)]:
			verts.append(b * c)
			normals.append(Vector3.UP)
		uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


## Ponto aleatório para grama/flor: no acostamento (entre o asfalto e a mureta) ou
## do lado de fora da mureta. Devolve Vector3.INF se não servir.
func _random_ground_point(shoulder_chance: float) -> Vector3:
	var count := track.samples.size()
	var i := rng.randi() % count
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var half := track.road_width * 0.5
	if track.is_bridge(i):
		return Vector3.INF
	var lateral: float
	if rng.randf() < shoulder_chance:
		lateral = rng.randf_range(half + 0.5, half + track.shoulder_width - 0.35)
	else:
		lateral = _outside + 0.6 + pow(rng.randf(), 1.8) * 40.0
	var p := _beside(i, side * lateral, rng.randf_range(-1.5, 1.5))
	var d := terrain.distance_to_track(p.x, p.z)
	if d < half + 0.4 or (d > half + track.shoulder_width - 0.3 and d < _outside + 0.5):
		return Vector3.INF
	if _is_reserved(p.x, p.z) and d > _outside:
		return Vector3.INF
	var y := terrain.height_at(p.x, p.z)
	if y < terrain.water_level + 0.3:
		return Vector3.INF
	return Vector3(p.x, y, p.z)


func _build_grass(preview: bool) -> void:
	var divisor := 5 if preview else 1
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = TUFT_SHADER
	var grass_cols := TrackTheme.grass_colors(track.scenery)
	grass_mat.set_shader_parameter("base_color", grass_cols[0])
	grass_mat.set_shader_parameter("tip_color", grass_cols[1])
	var tuft := _cross_quads(0.9, 0.5, 3, grass_mat)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var target := track.grass_count / divisor
	var attempts := 0
	while xforms.size() < target and attempts < target * 3:
		attempts += 1
		var p := _random_ground_point(0.4)
		if p == Vector3.INF:
			continue
		var s := rng.randf_range(0.7, 1.35)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), p - Vector3.UP * 0.02))
		var v := rng.randf_range(0.88, 1.12)
		colors.append(Color(v, v * rng.randf_range(0.97, 1.03), v * 0.95))
	_add_multimesh(tuft, xforms, colors, "Grama", false, 50.0, 80.0, true)

	var flower_mat := ShaderMaterial.new()
	flower_mat.shader = TUFT_SHADER
	flower_mat.set_shader_parameter("flower", true)
	flower_mat.set_shader_parameter("fade_start", 40.0)
	flower_mat.set_shader_parameter("fade_end", 65.0)
	var flower := _cross_quads(0.42, 0.55, 2, flower_mat)
	var palette := TrackTheme.flower_palette(track.scenery)
	var fx: Array[Transform3D] = []
	var fc: Array[Color] = []
	var flowers := track.flower_count / divisor if not palette.is_empty() else 0
	attempts = 0
	while fx.size() < flowers and attempts < flowers:
		attempts += 1
		var c := _random_ground_point(0.25)
		if c == Vector3.INF:
			continue
		var color: Color = palette[rng.randi() % palette.size()]
		for k in 22:
			var offset := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 2.8
			var x := c.x + offset.x
			var z := c.z + offset.y
			var d := terrain.distance_to_track(x, z)
			if d < track.road_width * 0.5 + 0.4 or (d > track.road_width * 0.5 + track.shoulder_width - 0.3 and d < _outside + 0.5):
				continue
			var y := terrain.height_at(x, z)
			if y < terrain.water_level + 0.3:
				continue
			var s := rng.randf_range(0.75, 1.25)
			fx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y - 0.02, z)))
			fc.append(color if rng.randf() < 0.8 else palette[rng.randi() % palette.size()])
	_add_multimesh(flower, fx, fc, "Flores", false, 50.0, 70.0, true)


# --- Dirigível e balões ----------------------------------------------------------------

## Cria o nó (ainda fora da árvore: configure a posição antes de adicioná-lo).
## No editor fica parado (o script de movimento só roda no jogo).
func _drifting_node(name: String) -> Node3D:
	var node: Node3D = Node3D.new() if Engine.is_editor_hint() else DriftingProp.new()
	node.name = name
	return node


func _build_blimp() -> void:
	var blimp := _drifting_node("Dirigivel")
	var radius := maxf(terrain.half_extent.x, terrain.half_extent.y) + 35.0
	var angle := 0.9
	blimp.position = Vector3(terrain.center.x + cos(angle) * radius, 64.0, terrain.center.y + sin(angle) * radius)
	if blimp is DriftingProp:
		blimp.orbit_center = Vector3(terrain.center.x, 0.0, terrain.center.y)
		blimp.orbit_radius = radius
		blimp.orbit_speed = -0.032
		blimp.bob_height = 1.5
	else:
		blimp.basis = Basis.looking_at(Vector3(sin(angle), 0.0, -cos(angle)), Vector3.UP)
	root.add_child(blimp)
	var scale := Vector3(5.2, 5.2, 17.0)
	var body := SphereMesh.new()
	body.radius = 1.0
	body.height = 2.0
	body.radial_segments = 32
	body.rings = 16
	var m := ShaderMaterial.new()
	m.shader = PROP_SHADER
	m.set_shader_parameter("mode", 1)
	m.set_shader_parameter("logo", WORDMARK)
	m.set_shader_parameter("logo_aspect", float(WORDMARK.get_width()) / WORDMARK.get_height())
	m.set_shader_parameter("logo_width", 0.95)
	m.set_shader_parameter("logo_center_y", 0.1)
	m.set_shader_parameter("body_scale", scale)
	m.set_shader_parameter("color_a", BRAND_BLUE)
	m.set_shader_parameter("color_b", Color(0.97, 0.97, 0.99))
	m.set_shader_parameter("color_c", YELLOW)
	body.material = m
	_add_mesh(body, Transform3D(Basis().scaled(scale), Vector3.ZERO), blimp)
	var fin_mat := color_material(BRAND_BLUE, 0.4)
	var fin_v := BoxMesh.new()
	fin_v.size = Vector3(0.35, 4.2, 5.0)
	fin_v.material = fin_mat
	var fin_h := BoxMesh.new()
	fin_h.size = Vector3(4.2, 0.35, 5.0)
	fin_h.material = fin_mat
	for sy: float in [-1.0, 1.0]:
		_add_mesh(fin_v, Transform3D(Basis(), Vector3(0.0, sy * 4.4, 14.2)), blimp)
		_add_mesh(fin_h, Transform3D(Basis(), Vector3(sy * 4.4, 0.0, 14.2)), blimp)
	var gondola := BoxMesh.new()
	gondola.size = Vector3(2.4, 1.7, 6.5)
	gondola.material = color_material(NAVY, 0.4)
	_add_mesh(gondola, Transform3D(Basis(), Vector3(0.0, -5.6, -1.5)), blimp)
	var window := BoxMesh.new()
	window.size = Vector3(2.5, 0.55, 5.6)
	var glass := color_material(Color(0.55, 0.85, 1.0), 0.1, 0.2)
	glass.emission_enabled = true
	glass.emission = Color(0.4, 0.7, 1.0)
	glass.emission_energy_multiplier = 0.4
	window.material = glass
	_add_mesh(window, Transform3D(Basis(), Vector3(0.0, -5.4, -1.5)), blimp)


func _build_balloons() -> void:
	var palettes := [
		[BRAND_BLUE, Color.WHITE, YELLOW],
		[RED, Color.WHITE, YELLOW],
		[BRAND_LIGHT, Color.WHITE, BRAND_BLUE],
		[YELLOW, BRAND_BLUE, Color.WHITE],
		[Color(0.2, 0.75, 0.45), Color.WHITE, YELLOW],
		[Color(1.0, 0.55, 0.15), Color.WHITE, BRAND_BLUE],
	]
	var envelope := SphereMesh.new()
	envelope.radius = 1.0
	envelope.height = 2.0
	envelope.radial_segments = 24
	envelope.rings = 14
	var basket := BoxMesh.new()
	basket.size = Vector3(1.6, 1.2, 1.6)
	basket.material = color_material(Color(0.55, 0.36, 0.2), 0.9)
	var rope := BoxMesh.new()
	rope.size = Vector3(0.06, 2.0, 0.06)
	rope.material = color_material(Color(0.3, 0.25, 0.2), 0.9)
	var reach := maxf(terrain.half_extent.x, terrain.half_extent.y)
	for b in track.balloon_count:
		var angle := TAU * b / maxf(track.balloon_count, 1) + rng.randf_range(-0.3, 0.3)
		var dist := reach + rng.randf_range(50.0, 240.0)
		var x := terrain.center.x + cos(angle) * dist
		var z := terrain.center.y + sin(angle) * dist
		var ground := maxf(terrain.height_at(x, z), terrain.water_level)
		var node := _drifting_node("Balao")
		node.position = Vector3(x, ground + rng.randf_range(30.0, 85.0), z)
		node.rotation.y = rng.randf() * TAU
		root.add_child(node)
		var size := rng.randf_range(6.0, 8.5)
		var pal: Array = palettes[b % palettes.size()]
		var m := ShaderMaterial.new()
		m.shader = PROP_SHADER
		m.set_shader_parameter("mode", 0)
		m.set_shader_parameter("color_a", pal[0])
		m.set_shader_parameter("color_b", pal[1])
		m.set_shader_parameter("color_c", pal[2])
		m.set_shader_parameter("logo", LOGO_ICON)
		m.set_shader_parameter("logo_aspect", float(LOGO_ICON.get_width()) / LOGO_ICON.get_height())
		m.set_shader_parameter("logo_width", 1.05)
		m.set_shader_parameter("logo_center_y", 0.15)
		var mi := _add_mesh(envelope, Transform3D(Basis().scaled(Vector3.ONE * size), Vector3.ZERO), node)
		mi.material_override = m
		var bottom := -1.12 * size
		_add_mesh(basket, Transform3D(Basis(), Vector3(0.0, bottom - 2.4, 0.0)), node)
		for c: Vector2 in [Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.7, 0.7), Vector2(0.7, 0.7)]:
			_add_mesh(rope, Transform3D(Basis(), Vector3(c.x, bottom - 0.9, c.y)), node)
