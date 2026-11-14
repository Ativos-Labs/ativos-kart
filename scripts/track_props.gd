@tool
class_name TrackProps
extends RefCounted
## Decorações típicas de cada cenário (veja TrackTheme), sempre com a marca da Ativos:
## - Praia: coqueiros, guarda-sóis azuis e amarelos, veleiros com o logo na vela e
##   um farol listrado com o logo "at".
## - Deserto: cactos, pedras, caixa-d'água com o logo, letreiro gigante "ativos" e
##   um arco de pedra por cima da pista.
## - Neve: pinheiros nevados, pedras, chalés com placa da Ativos, bonecos de neve de
##   cachecol azul e neve caindo.
## Usa um sorteio próprio (não muda a decoração que o TrackScenery já gerou).

const SNOWFALL := preload("res://scripts/snowfall.gd")

var s: TrackScenery
var track: Track
var terrain: TrackTerrain
var rng := RandomNumberGenerator.new()


func _init(p_scenery: TrackScenery) -> void:
	s = p_scenery
	track = s.track
	terrain = s.terrain
	rng.seed = track.decoration_seed * 7919 + 13


func build_landmarks() -> void:
	match track.scenery:
		TrackTheme.Scenery.PRAIA:
			_build_lighthouse()
		TrackTheme.Scenery.DESERTO:
			_build_water_tower()
			_build_giant_sign()
			_build_rock_arch()
		TrackTheme.Scenery.NEVE:
			_build_chalets()


func build_details(preview: bool) -> void:
	match track.scenery:
		TrackTheme.Scenery.PRAIA:
			_build_umbrellas()
			_build_boats()
		TrackTheme.Scenery.NEVE:
			_build_snowmen()
			if not preview:
				var snow := SNOWFALL.new()
				snow.name = "Neve"
				s.root.add_child(snow)


# --- Utilidades ------------------------------------------------------------------------

## Lugar livre e plano a uma distância da pista entre `min_d` e `max_d`.
## Devolve Vector3.INF se não achar.
func _find_spot(min_d: float, max_d: float, radius: float, tries := 400, near := Vector2.INF, near_max := INF) -> Vector3:
	var area := terrain.half_extent + Vector2(max_d, max_d)
	for t in tries:
		var x := terrain.center.x + rng.randf_range(-area.x, area.x)
		var z := terrain.center.y + rng.randf_range(-area.y, area.y)
		if near != Vector2.INF and Vector2(x, z).distance_to(near) > near_max:
			continue
		var d := terrain.distance_to_track(x, z)
		if d < min_d or d > max_d or s._is_reserved(x, z) or Vector2(x, z).distance_to(s._start) < 45.0:
			continue
		var y := terrain.height_at(x, z)
		if y < terrain.water_level + 0.6:
			continue
		var flat := true
		for o: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
			if absf(terrain.height_at(x + o.x, z + o.y) - y) > maxf(1.2, radius * 0.25):
				flat = false
				break
		if flat:
			return Vector3(x, y, z)
	return Vector3.INF


## Base em pé com a frente (+Z) virada para o ponto mais perto da pista.
func _face_track(p: Vector3) -> Basis:
	var idx := terrain.nearest_track_index(p.x, p.z)
	if idx < 0:
		return Basis()
	var to := track.samples[idx] - p
	to.y = 0.0
	if to.length_squared() < 0.01:
		return Basis()
	return TrackScenery._panel_basis(to)


func _vertex_color_material(roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	return m


static func _cyl(top: float, bottom: float, height: float, segments := 16) -> CylinderMesh:
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


static func _sphere(radius: float, segments := 16) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = segments / 2
	return m


## Monta uma malha com várias superfícies: [[malha, transform, material], ...]
## (peças com o mesmo material viram uma superfície só).
static func _compound(parts: Array) -> ArrayMesh:
	var tools := {}
	var order: Array[Material] = []
	for part in parts:
		var mat: Material = part[2]
		if not tools.has(mat):
			tools[mat] = MeshMerge.new()
			order.append(mat)
		(tools[mat] as MeshMerge).append_from(part[0], 0, part[1])
	var mesh := ArrayMesh.new()
	for mat in order:
		var st: MeshMerge = tools[mat]
		st.set_material(mat)
		st.commit(mesh)
	return mesh


# --- Árvores de cada cenário ------------------------------------------------------------

func build_trees() -> void:
	var forest := FastNoiseLite.new()
	forest.seed = track.decoration_seed + 5
	forest.frequency = 0.012
	var area := terrain.half_extent + Vector2(270.0, 270.0)
	var groups := {}
	var placed := 0
	var attempts := 0
	var target := track.tree_count
	while placed < target and attempts < target * 14:
		attempts += 1
		var x := terrain.center.x + rng.randf_range(-area.x, area.x)
		var z := terrain.center.y + rng.randf_range(-area.y, area.y)
		var d := terrain.distance_to_track(x, z)
		if d < s._outside + 3.5 or Vector2(x, z).distance_to(s._start) < 40.0 or s._is_reserved(x, z):
			continue
		var y := terrain.height_at(x, z)
		if y < terrain.water_level + 0.4 or y > 90.0:
			continue
		if absf(terrain.height_at(x + 2.5, z) - y) > 1.8 or absf(terrain.height_at(x, z + 2.5) - y) > 1.8:
			continue
		var keep := (0.25 + 0.75 * smoothstep(-0.2, 0.35, forest.get_noise_2d(x, z))) * lerpf(1.0, 0.35, smoothstep(40.0, 280.0, d))
		if rng.randf() > keep:
			continue
		var kind := _pick_kind()
		var sc := rng.randf_range(0.8, 1.4)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if kind == "rock":
			basis = basis.scaled(Vector3(sc, sc * rng.randf_range(0.5, 0.85), sc * rng.randf_range(0.8, 1.2)))
		else:
			basis = basis.scaled(Vector3.ONE * sc)
		if not groups.has(kind):
			groups[kind] = [[] as Array[Transform3D], [] as Array[Color]]
		(groups[kind][0] as Array[Transform3D]).append(Transform3D(basis, Vector3(x, y - (0.35 if kind == "rock" else 0.1), z)))
		(groups[kind][1] as Array[Color]).append(_kind_color(kind))
		placed += 1
	for kind: String in groups:
		var mesh: Mesh
		var label := ""
		match kind:
			"palm":
				mesh = _palm_mesh()
				label = "Coqueiros"
			"broadleaf":
				mesh = TrackScenery._broadleaf_mesh()
				label = "Arvores"
			"cactus":
				mesh = _cactus_mesh()
				label = "Cactos"
			"pine":
				mesh = TrackScenery._pine_mesh(1.0)
				label = "Pinheiros"
			_:
				mesh = _rock_mesh(_vertex_color_material(0.95))
				label = "Pedras"
		s._add_multimesh(mesh, groups[kind][0], groups[kind][1], label)


func _pick_kind() -> String:
	var r := rng.randf()
	match track.scenery:
		TrackTheme.Scenery.PRAIA:
			return "palm" if r < 0.8 else "broadleaf"
		TrackTheme.Scenery.DESERTO:
			return "cactus" if r < 0.55 else "rock"
		TrackTheme.Scenery.NEVE:
			return "pine" if r < 0.86 else "rock"
	return "broadleaf"


func _kind_color(kind: String) -> Color:
	match kind:
		"palm":
			return Color.from_hsv(rng.randf_range(0.26, 0.33), rng.randf_range(0.7, 0.85), rng.randf_range(0.55, 0.78))
		"broadleaf":
			if rng.randf() < 0.15:
				return Color.from_hsv(rng.randf_range(0.95, 1.0), rng.randf_range(0.45, 0.6), 1.0)
			return Color.from_hsv(rng.randf_range(0.25, 0.33), rng.randf_range(0.7, 0.9), rng.randf_range(0.55, 0.8))
		"cactus":
			return Color.from_hsv(rng.randf_range(0.27, 0.33), rng.randf_range(0.45, 0.6), rng.randf_range(0.42, 0.58))
		"pine":
			return Color.from_hsv(rng.randf_range(0.37, 0.43), rng.randf_range(0.55, 0.75), rng.randf_range(0.28, 0.42))
	return TrackTheme.rock_color(track.scenery, rng)


## Coqueiro: tronco curvado em gomos, folhas compridas caindo e cocos.
static func _palm_mesh() -> ArrayMesh:
	var trunk := MeshMerge.new()
	var pts: Array[Vector3] = []
	for k in 8:
		var t := k / 7.0
		pts.append(Vector3(1.5 * t * t, 7.4 * t, 0.0))
	for k in 7:
		var a := pts[k]
		var b := pts[k + 1]
		var d := b - a
		var y := d.normalized()
		var x := y.cross(Vector3.FORWARD).normalized()
		var seg := _cyl(0.3 - k * 0.012 - 0.012, 0.3 - k * 0.012 + 0.02, d.length() + 0.08, 8)
		trunk.append_from(seg, 0, Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5))
	trunk.set_material(TrackScenery.color_material(Color(0.62, 0.48, 0.33), 0.92))
	var mesh := trunk.commit()

	var top := pts[7] + Vector3(0.0, 0.15, 0.0)
	var fronds := SurfaceTool.new()
	fronds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 9:
		var ang := TAU * k / 9.0 + (0.18 if k % 2 == 0 else -0.1)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		_frond(fronds, top, dir, 3.6 + (k % 3) * 0.35, 0.62, 0.35 + (k % 2) * 0.25)
	var fm := TrackScenery._foliage_material(6.2, 8.6, top, 0.3)
	fm.set_shader_parameter("wind_strength", 0.03)
	fronds.set_material(fm)
	fronds.commit(mesh)

	var nuts := MeshMerge.new()
	for k in 3:
		var a := TAU * k / 3.0
		nuts.append_from(_sphere(0.22, 8), 0, Transform3D(Basis(), top + Vector3(cos(a) * 0.32, -0.42, sin(a) * 0.32)))
	nuts.set_material(TrackScenery.color_material(Color(0.4, 0.27, 0.14), 0.7))
	nuts.commit(mesh)
	return mesh


## Folha de coqueiro: fita em "V" que sai do topo e cai na ponta (duas faces).
static func _frond(st: SurfaceTool, top: Vector3, dir: Vector3, length: float, width: float, lift: float) -> void:
	var across := Vector3.UP.cross(dir).normalized()
	var rows := 7
	var left: Array[Vector3] = []
	var mid: Array[Vector3] = []
	var right: Array[Vector3] = []
	for r in rows + 1:
		var t := float(r) / rows
		var c := top + dir * (t * length) + Vector3.UP * (lift * t - 1.9 * t * t)
		var w := width * sin(PI * (0.12 + t * 0.85)) * (1.0 - t * 0.35)
		mid.append(c + Vector3.UP * 0.1 * (1.0 - t))
		left.append(c - across * w)
		right.append(c + across * w)
	for r in rows:
		for strip in [[left, mid], [mid, right]]:
			var a: Array[Vector3] = strip[0]
			var b: Array[Vector3] = strip[1]
			_quad(st, a[r], b[r], b[r + 1], a[r + 1])


## Quadrilátero com as duas faces (normal para cima de um lado, para baixo do outro).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# (a, c, b) e (a, d, c) viram para `n`; as cópias invertidas viram para -n.
	var n := (b - a).cross(d - a).normalized()
	for tri in [[a, b, c], [a, c, d]]:
		st.set_normal(n)
		st.add_vertex(tri[0])
		st.set_normal(n)
		st.add_vertex(tri[2])
		st.set_normal(n)
		st.add_vertex(tri[1])
		st.set_normal(-n)
		st.add_vertex(tri[0])
		st.set_normal(-n)
		st.add_vertex(tri[1])
		st.set_normal(-n)
		st.add_vertex(tri[2])


## Cacto: tronco e dois braços (cápsulas), sem balançar com o vento.
static func _cactus_mesh() -> ArrayMesh:
	var st := MeshMerge.new()
	var trunk := CapsuleMesh.new()
	trunk.radius = 0.42
	trunk.height = 4.8
	trunk.radial_segments = 10
	trunk.rings = 4
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0.0, 2.2, 0.0)))
	for arm: Vector4 in [Vector4(1.0, 1.7, 1.5, 0.3), Vector4(-1.0, 2.4, 1.1, 0.27)]:
		var side := arm.x
		var elbow := CapsuleMesh.new()
		elbow.radius = arm.w
		elbow.height = 1.05
		elbow.radial_segments = 8
		elbow.rings = 2
		st.append_from(elbow, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(side * 0.62, arm.y, 0.0)))
		var up := CapsuleMesh.new()
		up.radius = arm.w
		up.height = arm.z + arm.w * 2.0
		up.radial_segments = 8
		up.rings = 2
		st.append_from(up, 0, Transform3D(Basis(), Vector3(side * 1.02, arm.y + arm.z * 0.5, 0.0)))
	var m := TrackScenery._foliage_material(0.0, 4.6, Vector3(0.0, 2.2, 0.0), 0.15)
	m.set_shader_parameter("wind_strength", 0.0)
	st.set_material(m)
	return st.commit()


## Pedra: bolotas de poucas faces juntas.
static func _rock_mesh(material: Material) -> ArrayMesh:
	var st := MeshMerge.new()
	for b: Vector4 in [Vector4(0.0, 0.6, 0.0, 1.3), Vector4(0.9, 0.4, 0.3, 0.9), Vector4(-0.8, 0.35, -0.2, 1.0), Vector4(0.2, 0.9, -0.5, 0.8)]:
		var sp := SphereMesh.new()
		sp.radius = b.w
		sp.height = b.w * 2.0
		sp.radial_segments = 7
		sp.rings = 4
		st.append_from(sp, 0, Transform3D(Basis(), Vector3(b.x, b.y, b.z)))
	st.set_material(material)
	return st.commit()


# --- Praia: farol, guarda-sóis e veleiros -----------------------------------------------

func _build_lighthouse() -> void:
	var p := _find_spot(s._outside + 9.0, s._outside + 24.0, 4.0, 900)
	if p == Vector3.INF:
		return
	s._reserved.append(Vector3(p.x, p.z, 9.0))
	var node := Node3D.new()
	node.name = "Farol"
	node.position = p - Vector3.UP * 0.4
	s.root.add_child(node)
	var white := TrackScenery.color_material(Color(0.97, 0.97, 0.98), 0.5)
	var blue := TrackScenery.color_material(TrackScenery.BRAND_BLUE, 0.45)
	var navy := TrackScenery.color_material(TrackScenery.NAVY, 0.45)
	s._add_mesh(_cyl(3.4, 3.8, 1.6, 24), Transform3D(Basis(), Vector3(0, 0.8, 0)), node).material_override = white
	var y := 1.6
	var radius := 2.3
	for k in 6:
		var h := 3.2
		var r_top := radius - 0.12
		var band := _cyl(r_top, radius, h, 24)
		var mi := s._add_mesh(band, Transform3D(Basis(), Vector3(0, y + h * 0.5, 0)), node)
		if k == 3:
			# Faixa branca com o logo "at" em volta da torre.
			mi.material_override = TrackScenery.brand_material(TrackScenery.LOGO_ICON, Color.WHITE, TAU * radius / h, {"logo_fill": 0.62, "logo_count": 3})
		else:
			mi.material_override = blue if k % 2 == 0 else white
		y += h
		radius = r_top
	s._add_mesh(_cyl(2.6, 2.6, 0.35, 24), Transform3D(Basis(), Vector3(0, y + 0.17, 0)), node).material_override = navy
	var glass := TrackScenery.color_material(Color(1.0, 0.92, 0.55), 0.1)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.85, 0.4)
	glass.emission_energy_multiplier = 1.6
	s._add_mesh(_cyl(1.2, 1.2, 2.2, 16), Transform3D(Basis(), Vector3(0, y + 1.45, 0)), node).material_override = glass
	s._add_mesh(_cyl(0.0, 1.7, 1.8, 16), Transform3D(Basis(), Vector3(0, y + 3.45, 0)), node).material_override = navy
	s._add_mesh(_sphere(0.35, 10), Transform3D(Basis(), Vector3(0, y + 4.45, 0)), node).material_override = TrackScenery.color_material(TrackScenery.YELLOW, 0.4)


## Guarda-sol: mastro e copa em gomos de duas cores (duas variantes).
func _umbrella_mesh(a: Color, b: Color) -> ArrayMesh:
	var pole := TrackScenery.color_material(Color(0.95, 0.95, 0.97), 0.4)
	var parts: Array = [[_cyl(0.05, 0.05, 2.7, 6), Transform3D(Basis(), Vector3(0, 1.35, 0)), pole]]
	var mesh := _compound(parts)
	var sectors := 10
	var mats: Array[StandardMaterial3D] = [TrackScenery.color_material(a, 0.6), TrackScenery.color_material(b, 0.6)]
	for m in mats:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for which in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var apex := Vector3(0, 2.95, 0)
		for k in sectors:
			if k % 2 != which:
				continue
			var a0 := TAU * k / sectors
			var a1 := TAU * (k + 1) / sectors
			var r0 := Vector3(cos(a0) * 1.75, 2.35, sin(a0) * 1.75)
			var r1 := Vector3(cos(a1) * 1.75, 2.35, sin(a1) * 1.75)
			# Normal da face da frente desse triângulo (o material desenha os dois lados).
			var n := (r0 - apex).cross(r1 - apex).normalized()
			for v in [apex, r1, r0]:
				st.set_normal(n)
				st.add_vertex(v)
		st.set_material(mats[which])
		st.commit(mesh)
	return mesh


func _build_umbrellas() -> void:
	var variants: Array[ArrayMesh] = [_umbrella_mesh(TrackScenery.BRAND_BLUE, Color.WHITE), _umbrella_mesh(TrackScenery.YELLOW, TrackScenery.BRAND_BLUE)]
	var towel := _box(Vector3(1.0, 0.04, 2.0))
	var lists: Array = [[] as Array[Transform3D], [] as Array[Transform3D]]
	var towels: Array[Transform3D] = []
	var towel_cols: Array[Color] = []
	var palette := [TrackScenery.BRAND_BLUE, TrackScenery.YELLOW, TrackScenery.RED, Color.WHITE, TrackScenery.BRAND_LIGHT]
	var clusters := 0
	var attempts := 0
	while clusters < 9 and attempts < 600:
		attempts += 1
		var c := _find_spot(s._outside + 4.0, s._outside + 16.0, 2.0, 30)
		if c == Vector3.INF:
			continue
		clusters += 1
		for k in rng.randi_range(3, 6):
			var x := c.x + rng.randf_range(-7.0, 7.0)
			var z := c.z + rng.randf_range(-7.0, 7.0)
			if terrain.distance_to_track(x, z) < s._outside + 2.5 or s._is_reserved(x, z):
				continue
			var y := terrain.height_at(x, z)
			if y < terrain.water_level + 0.35:
				continue
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
			(lists[k % 2] as Array[Transform3D]).append(Transform3D(b * tilt, Vector3(x, y - 0.15, z)))
			towels.append(Transform3D(b, Vector3(x, y + 0.02, z) + b.x * 1.1))
			towel_cols.append(palette[rng.randi() % palette.size()])
	for v in 2:
		s._add_multimesh(variants[v], lists[v], [] as Array[Color], "GuardaSois")
	towel.material = _vertex_color_material(0.9)
	s._add_multimesh(towel, towels, towel_cols, "Toalhas", false)


func _build_boats() -> void:
	var hull_mat := TrackScenery.color_material(Color(0.97, 0.97, 0.98), 0.45)
	var stripe_mat := TrackScenery.color_material(TrackScenery.NAVY, 0.45)
	var mast_mat := TrackScenery.color_material(Color(0.85, 0.85, 0.88), 0.35, 0.4)
	var hull := _compound([
		[_box(Vector3(2.2, 1.0, 5.2)), Transform3D(Basis(), Vector3(0, 0.3, 0.4)), hull_mat],
		[_box(Vector3(2.26, 0.22, 5.26)), Transform3D(Basis(), Vector3(0, 0.62, 0.4)), stripe_mat],
		[_cyl(0.0, 1.1, 2.2, 4), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.UP, PI * 0.25), Vector3(0, 0.3, -3.3)), hull_mat],
		[_cyl(0.08, 0.1, 8.5, 6), Transform3D(Basis(), Vector3(0, 4.9, 0.2)), mast_mat],
		[_box(Vector3(0.1, 0.1, 3.6)), Transform3D(Basis(), Vector3(0, 1.7, 1.6)), mast_mat],
	])
	var sails: Array[ShaderMaterial] = [
		TrackScenery.brand_material(TrackScenery.LOGO_ICON, Color.WHITE, 3.4 / 5.6, {"logo_fill": 0.5}),
		TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.BRAND_BLUE, 3.4 / 5.6, {"logo_fill": 0.5, "recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW}),
		TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.YELLOW, 3.4 / 5.6, {"logo_fill": 0.5}),
	]
	var sail := QuadMesh.new()
	sail.size = Vector2(3.4, 5.6)
	sail.subdivide_width = 6
	sail.subdivide_depth = 2
	var area := terrain.half_extent + Vector2(160.0, 160.0)
	var placed := 0
	var attempts := 0
	while placed < 8 and attempts < 2000:
		attempts += 1
		var x := terrain.center.x + rng.randf_range(-area.x, area.x)
		var z := terrain.center.y + rng.randf_range(-area.y, area.y)
		if terrain.distance_to_track(x, z) < s._outside + 14.0:
			continue
		var deep := true
		for o: Vector2 in [Vector2.ZERO, Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
			if terrain.height_at(x + o.x, z + o.y) > terrain.water_level - 1.0:
				deep = false
				break
		if not deep:
			continue
		var node := s._drifting_node("Veleiro")
		node.position = Vector3(x, terrain.water_level - 0.2, z)
		node.rotation.y = rng.randf() * TAU
		if node is DriftingProp:
			node.bob_height = 0.12
			node.bob_speed = 0.9
			node.spin_speed = rng.randf_range(-0.012, 0.012)
		s.root.add_child(node)
		s._add_mesh(hull, Transform3D(), node)
		var mi := s._add_mesh(sail, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 4.6, 1.6)), node)
		mi.material_override = sails[placed % sails.size()]
		placed += 1


# --- Deserto: caixa-d'água, letreiro gigante e arco de pedra ------------------------------

func _build_water_tower() -> void:
	var p := _find_spot(s._outside + 10.0, s._outside + 34.0, 4.5, 900)
	if p == Vector3.INF:
		return
	s._reserved.append(Vector3(p.x, p.z, 8.0))
	var node := Node3D.new()
	node.name = "CaixaDagua"
	node.position = p
	node.basis = _face_track(p)
	s.root.add_child(node)
	var steel := TrackScenery.color_material(Color(0.78, 0.8, 0.85), 0.4, 0.5)
	var navy := TrackScenery.color_material(TrackScenery.NAVY, 0.45)
	var leg_h := 13.0
	for c: Vector2 in [Vector2(-2.2, -2.2), Vector2(2.2, -2.2), Vector2(-2.2, 2.2), Vector2(2.2, 2.2)]:
		s._add_mesh(_box(Vector3(0.4, leg_h + 1.5, 0.4)), Transform3D(Basis(), Vector3(c.x, leg_h * 0.5 - 0.75, c.y)), node).material_override = steel
	for y: float in [4.0, 8.5]:
		for side in 4:
			var b := Basis(Vector3.UP, PI * 0.5 * side)
			s._add_mesh(_box(Vector3(4.4, 0.18, 0.18)), Transform3D(b, b * Vector3(0, y, 2.2)), node).material_override = steel
	var radius := 3.5
	var h := 5.2
	var tank := s._add_mesh(_cyl(radius, radius, h, 32), Transform3D(Basis(), Vector3(0, leg_h + h * 0.5, 0)), node)
	tank.material_override = TrackScenery.brand_material(TrackScenery.LOGO_ICON, TrackScenery.BRAND_BLUE, TAU * radius / h,
			{"logo_fill": 0.62, "logo_count": 3, "recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW})
	s._add_mesh(_cyl(0.0, radius + 0.35, 2.2, 32), Transform3D(Basis(), Vector3(0, leg_h + h + 1.1, 0)), node).material_override = navy
	s._add_mesh(_cyl(radius + 0.1, radius + 0.1, 0.3, 32), Transform3D(Basis(), Vector3(0, leg_h + 0.15, 0)), node).material_override = navy


## Letreiro gigante com a marca, num morro de frente para a reta de largada.
func _build_giant_sign() -> void:
	var start := track.get_point_at(0.0)
	var fwd := track.get_direction_at(0.0)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best := Vector3.INF
	var best_score := -INF
	for t in 500:
		var x := start.x + rng.randf_range(-380.0, 380.0)
		var z := start.z + rng.randf_range(-380.0, 380.0)
		var to := Vector3(x - start.x, 0.0, z - start.z)
		var dist := to.length()
		if dist < 140.0 or dist > 360.0:
			continue
		var d := terrain.distance_to_track(x, z)
		if d < 55.0:
			continue
		var y := terrain.height_at(x, z)
		if y < terrain.water_level + 2.0:
			continue
		var score := to.normalized().dot(fwd) * 2.0 - absf(dist - 240.0) / 200.0 + clampf(y / 30.0, 0.0, 0.6)
		if score > best_score:
			best_score = score
			best = Vector3(x, y, z)
	if best == Vector3.INF:
		return
	var node := Node3D.new()
	node.name = "Letreiro"
	var facing := Vector3(start.x - best.x, 0.0, start.z - best.z)
	node.basis = TrackScenery._panel_basis(facing)
	node.position = best
	s.root.add_child(node)
	var size := Vector2(52.0, 13.0)
	var steel := TrackScenery.color_material(Color(0.7, 0.72, 0.78), 0.45, 0.5)
	var ground_max := -INF
	var legs: Array[Vector3] = []
	for k in 6:
		var lx := lerpf(-size.x * 0.42, size.x * 0.42, k / 5.0)
		var wp := node.transform * Vector3(lx, 0.0, -0.6)
		var gy := terrain.height_at(wp.x, wp.z)
		ground_max = maxf(ground_max, gy)
		legs.append(Vector3(lx, gy - best.y, -0.6))
	var center_y := ground_max - best.y + 6.0 + size.y * 0.5
	for leg in legs:
		var h := center_y - leg.y + 1.0
		s._add_mesh(_box(Vector3(0.7, h, 0.7)), Transform3D(Basis(), Vector3(leg.x, leg.y + h * 0.5 - 1.0, leg.z)), node).material_override = steel
	s._add_mesh(_box(Vector3(size.x + 1.0, size.y + 1.0, 0.6)), Transform3D(Basis(), Vector3(0, center_y, -0.32)), node).material_override = TrackScenery.color_material(TrackScenery.NAVY, 0.5)
	var board := QuadMesh.new()
	board.size = size
	var mi := s._add_mesh(board, Transform3D(Basis(), Vector3(0, center_y, 0.0)), node)
	mi.material_override = TrackScenery.brand_material(TrackScenery.WORDMARK, Color.WHITE, size.x / size.y, {"logo_fill": 0.72, "border_width": 0.05, "border_color": TrackScenery.YELLOW, "emission": 0.08})


## Arco de pedra natural por cima da pista, num trecho reto.
func _build_rock_arch() -> void:
	var count := track.samples.size()
	var best := -1
	var best_score := INF
	for i in range(int(count * 0.62), int(count * 0.96)):
		if track.is_bridge(i) or absf(track.curvature[i]) > 0.008:
			continue
		var ok := true
		for k in range(-6, 7):
			var j := (i + k + count) % count
			if track.is_bridge(j) or absf(track.curvature[j]) > 0.012:
				ok = false
				break
		if not ok:
			continue
		var score := absf(track.curvature[i]) + absf(float(i) / count - 0.8)
		if score < best_score:
			best_score = score
			best = i
	if best < 0:
		return
	var c := track.samples[best]
	var r := track.rights[best]
	var t := track.tangents[best]
	t.y = 0.0
	t = t.normalized()
	var radius := s._outside + 5.5
	# Pedra em camadas (o shader de blocos com blocos largos e juntas quase da
	# mesma cor vira faixas de arenito).
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/stone.gdshader")
	mat.set_shader_parameter("stone_a", Color(0.88, 0.52, 0.31))
	mat.set_shader_parameter("stone_b", Color(0.72, 0.36, 0.21))
	mat.set_shader_parameter("mortar", Color(0.62, 0.32, 0.19))
	mat.set_shader_parameter("block_w", 9.0)
	mat.set_shader_parameter("block_h", 1.3)
	var st := MeshMerge.new()
	var lumps := 34
	for k in lumps + 1:
		var a := lerpf(-0.1, PI + 0.1, float(k) / lumps)
		var edge := 1.0 - smoothstep(0.0, 0.25, minf(a, PI - a))
		# Mais grosso nos pés, mais fino e irregular no alto.
		var lump := rng.randf_range(2.4, 4.0) + edge * 1.6
		var p := c + r * cos(a) * radius + Vector3.UP * (sin(a) * radius * 0.92)
		p += t * rng.randf_range(-1.4, 1.4) + Vector3.UP * rng.randf_range(-0.6, 0.6)
		for extra in 2:
			var sp := SphereMesh.new()
			var rr := lump * (1.0 if extra == 0 else rng.randf_range(0.5, 0.75))
			sp.radius = rr
			sp.height = rr * 2.0 * rng.randf_range(0.8, 1.0)
			sp.radial_segments = 7
			sp.rings = 4
			var off := Vector3.ZERO if extra == 0 else Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * lump * 0.6
			st.append_from(sp, 0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + off))
	# Pés do arco descendo até o chão.
	for side: float in [-1.0, 1.0]:
		for k in 4:
			var p := c + r * side * (radius + rng.randf_range(-0.5, 2.0)) + Vector3.UP * (-2.0 + k * 1.5) + t * rng.randf_range(-2.0, 2.0)
			var sp := SphereMesh.new()
			sp.radius = 5.2 - k * 0.5
			sp.height = sp.radius * 1.8
			sp.radial_segments = 7
			sp.rings = 4
			st.append_from(sp, 0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.name = "ArcoDePedra"
	mi.mesh = st.commit()
	s.root.add_child(mi)
	for side: float in [-1.0, 1.0]:
		var p := c + r * side * radius
		s._reserved.append(Vector3(p.x, p.z, 9.0))


# --- Neve: chalés, bonecos de neve e neve caindo -------------------------------------------

func _build_chalets() -> void:
	var wood := TrackScenery.color_material(Color(0.55, 0.34, 0.2), 0.85)
	var dark_wood := TrackScenery.color_material(Color(0.32, 0.2, 0.12), 0.85)
	var snow := TrackScenery.color_material(Color(0.95, 0.97, 1.0), 0.7)
	var stone := ShaderMaterial.new()
	stone.shader = preload("res://shaders/stone.gdshader")
	stone.set_shader_parameter("stone_a", Color(0.66, 0.66, 0.68))
	stone.set_shader_parameter("stone_b", Color(0.48, 0.49, 0.52))
	stone.set_shader_parameter("block_w", 0.8)
	stone.set_shader_parameter("block_h", 0.4)
	var window := TrackScenery.color_material(Color(1.0, 0.85, 0.5), 0.3)
	window.emission_enabled = true
	window.emission = Color(1.0, 0.72, 0.35)
	window.emission_energy_multiplier = 1.2
	var roof := PrismMesh.new()
	roof.size = Vector3(7.0, 2.8, 6.0)
	var house := _compound([
		[_box(Vector3(6.6, 0.9, 5.6)), Transform3D(Basis(), Vector3(0, 0.15, 0)), stone],
		[_box(Vector3(6.0, 3.4, 5.0)), Transform3D(Basis(), Vector3(0, 2.3, 0)), wood],
		[roof, Transform3D(Basis(), Vector3(0, 5.4, 0)), snow],
		[_box(Vector3(0.8, 2.2, 0.8)), Transform3D(Basis(), Vector3(1.6, 6.0, 1.0)), stone],
		[_box(Vector3(1.3, 2.1, 0.12)), Transform3D(Basis(), Vector3(0, 1.65, 2.52)), dark_wood],
		[_box(Vector3(1.1, 0.9, 0.12)), Transform3D(Basis(), Vector3(-1.9, 2.6, 2.52)), window],
		[_box(Vector3(1.1, 0.9, 0.12)), Transform3D(Basis(), Vector3(1.9, 2.6, 2.52)), window],
		[_box(Vector3(0.12, 0.9, 1.1)), Transform3D(Basis(), Vector3(3.02, 2.6, 0.0)), window],
		[_box(Vector3(0.12, 0.9, 1.1)), Transform3D(Basis(), Vector3(-3.02, 2.6, 0.0)), window],
	])
	var sign := QuadMesh.new()
	sign.size = Vector2(2.6, 0.95)
	var sign_mat := TrackScenery.brand_material(TrackScenery.WORDMARK_DARK, TrackScenery.NAVY, 2.6 / 0.95, {"logo_fill": 0.62, "border_width": 0.08, "border_color": TrackScenery.YELLOW, "emission": 0.15})
	var start := track.get_point_at(0.0)
	var placed := 0
	var attempts := 0
	while placed < 6 and attempts < 40:
		attempts += 1
		var p := _find_spot(s._outside + 12.0, s._outside + 46.0, 4.5, 60, Vector2(start.x, start.z), 220.0)
		if p == Vector3.INF:
			continue
		s._reserved.append(Vector3(p.x, p.z, 8.0))
		var node := Node3D.new()
		node.name = "Chale"
		node.position = p - Vector3.UP * 0.25
		node.basis = _face_track(p)
		s.root.add_child(node)
		s._add_mesh(house, Transform3D(), node)
		s._add_mesh(sign, Transform3D(Basis(), Vector3(0, 3.35, 2.6)), node).material_override = sign_mat
		placed += 1


func _build_snowmen() -> void:
	var snow := TrackScenery.color_material(Color(0.96, 0.97, 1.0), 0.8)
	var coal := TrackScenery.color_material(Color(0.06, 0.06, 0.08), 0.5)
	var carrot := TrackScenery.color_material(Color(1.0, 0.5, 0.1), 0.6)
	var scarf := TrackScenery.color_material(TrackScenery.BRAND_BLUE, 0.7)
	var hat := TrackScenery.color_material(TrackScenery.NAVY, 0.5)
	var band := TrackScenery.color_material(TrackScenery.YELLOW, 0.5)
	var stick := TrackScenery.color_material(Color(0.36, 0.23, 0.13), 0.9)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.66
	ring.rings = 12
	ring.ring_segments = 8
	var parts: Array = [
		[_sphere(1.0, 14), Transform3D(Basis(), Vector3(0, 0.85, 0)), snow],
		[_sphere(0.72, 14), Transform3D(Basis(), Vector3(0, 2.15, 0)), snow],
		[_sphere(0.5, 12), Transform3D(Basis(), Vector3(0, 3.15, 0)), snow],
		[ring, Transform3D(Basis(), Vector3(0, 2.72, 0)), scarf],
		[_box(Vector3(0.28, 0.9, 0.08)), Transform3D(Basis(Vector3.BACK, 0.15), Vector3(0.28, 2.3, 0.62)), scarf],
		[_cyl(0.0, 0.09, 0.55, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 3.15, 0.72)), carrot],
		[_cyl(0.42, 0.42, 0.7, 14), Transform3D(Basis(), Vector3(0, 3.85, 0)), hat],
		[_cyl(0.68, 0.68, 0.08, 14), Transform3D(Basis(), Vector3(0, 3.52, 0)), hat],
		[_cyl(0.43, 0.43, 0.14, 14), Transform3D(Basis(), Vector3(0, 3.62, 0)), band],
		[_box(Vector3(0.08, 0.08, 1.5)), Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -0.5), Vector3(1.2, 2.5, 0)), stick],
		[_box(Vector3(0.08, 0.08, 1.5)), Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, -0.7), Vector3(-1.2, 2.55, 0)), stick],
	]
	for e: Vector3 in [Vector3(-0.17, 3.28, 0.44), Vector3(0.17, 3.28, 0.44), Vector3(0, 2.3, 0.7), Vector3(0, 1.95, 0.72), Vector3(0, 1.1, 0.98)]:
		parts.append([_sphere(0.075, 6), Transform3D(Basis(), e), coal])
	var mesh := _compound(parts)
	var xforms: Array[Transform3D] = []
	var count := track.samples.size()
	var attempts := 0
	while xforms.size() < 16 and attempts < 400:
		attempts += 1
		var i := rng.randi() % count
		if track.is_bridge(i):
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p := s._beside(i, side * (s._outside + rng.randf_range(2.5, 7.0)))
		if terrain.distance_to_track(p.x, p.z) < s._outside + 2.0 or s._is_reserved(p.x, p.z) or Vector2(p.x, p.z).distance_to(s._start) < 30.0:
			continue
		var y := terrain.height_at(p.x, p.z)
		if y < terrain.water_level + 0.4:
			continue
		var b := TrackScenery._panel_basis(-track.rights[i] * side - track.tangents[i] * 0.4).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15))
		xforms.append(Transform3D(b, Vector3(p.x, y - 0.1, p.z)))
		s._reserved.append(Vector3(p.x, p.z, 2.5))
	s._add_multimesh(mesh, xforms, [] as Array[Color], "BonecosDeNeve")
