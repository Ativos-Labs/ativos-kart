@tool
class_name TrackRampBuilder
extends RefCounted
## Monta as rampas de pulo da pista (veja track_ramp.gd): subida curva azul com o
## logo "at" pintado e setas amarelas (ou setas de turbo acesas; na rampa de
## asa-delta, painel azul aceso com setas brancas e moldura amarela), saias inclinadas
## nas laterais, zebrado na borda, a colisão (JumpRamp, que guarda a borda de onde o
## kart decola) e paredes invisíveis no trecho do pulo — no ar o kart passa da
## altura das muretas, e elas não deixam ele sair da pista.

const RAMP_SHADER := preload("res://shaders/ramp.gdshader")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")

## Inclinação das saias laterais (rad, ~38°): abaixo do limite de chão do kart
## (50°), então quem entra de lado sobe nelas em vez de bater numa parede.
const SKIRT_ANGLE := 0.66
## Comprimento de cada fatia da rampa (m).
const STEP := 0.5
## Paredes invisíveis do trecho do pulo: altura acima das muretas e quanto vão
## antes do começo da rampa e depois da borda (m).
const GUARD_HEIGHT := 7.0
const GUARD_BEFORE := 8.0
const GUARD_AFTER := 75.0
## Rampa de asa-delta: o kart voa bem mais alto (e mais longe, até
## TrackRamp.glide_distance), então as paredes do voo vão até esta altura.
const GLIDE_GUARD_HEIGHT := 32.0

var track: Track
var root: Node3D


func _init(p_track: Track, p_root: Node3D) -> void:
	track = p_track
	root = p_root


func build() -> void:
	for ramp in track.ramps:
		if ramp != null:
			_build_ramp(ramp)


func _build_ramp(ramp: TrackRamp) -> void:
	var lip_dist := wrapf(ramp.at, 0.0, 1.0) * track.length
	var start := lip_dist - ramp.length
	# O topo fica entre as zebras; com `width` < 1 ele estreita e `offset` o leva
	# para um dos lados.
	var inner_half := track.road_width * 0.5 - track.curb_min_width - 0.1
	var half := inner_half * ramp.width
	var center := ramp.offset * (inner_half - half)
	var run := 1.0 / tan(SKIRT_ANGLE)
	var steps := maxi(4, ceili(ramp.length / STEP))

	# Linha do meio do topo, direita e altura em cada fatia.
	var mid := PackedVector3Array()
	var rights := PackedVector3Array()
	var heights := PackedFloat32Array()
	for i in steps + 1:
		var t := float(i) / steps
		var d := start + ramp.length * t
		var r := track.get_direction_at(d).cross(Vector3.UP).normalized()
		var h := ramp.height * ramp.profile(t)
		mid.append(track.get_point_at(d) + r * center + Vector3.UP * h)
		rights.append(r)
		heights.append(h)

	var md := Track.MeshData.new()
	var top_color := Color(1.0, 0.0, 0.0)
	var skirt_color := Color(0.0, 1.0, 0.0)
	var lip_color := Color(0.0, 0.0, 1.0)

	# Topo.
	var base := md.verts.size()
	for i in steps + 1:
		var along := (mid[mini(i + 1, steps)] - mid[maxi(i - 1, 0)]).normalized()
		var n := rights[i].cross(along).normalized()
		var v := ramp.length * float(i) / steps
		md.add_vertex(mid[i] - rights[i] * half, n, Vector2(0.0, v))
		md.add_vertex(mid[i] + rights[i] * half, n, Vector2(1.0, v))
		md.colors.append_array([top_color, top_color])
	for i in steps:
		var a := base + i * 2
		md.add_tri(a, a + 1, a + 2, md.normals[a])
		md.add_tri(a + 1, a + 3, a + 2, md.normals[a])

	# Saias laterais inclinadas (do topo até o asfalto).
	for side: float in [-1.0, 1.0]:
		base = md.verts.size()
		for i in steps + 1:
			var out := rights[i] * side
			var n := (Vector3.UP * cos(SKIRT_ANGLE) + out * sin(SKIRT_ANGLE)).normalized()
			var top := mid[i] + out * half
			var h := heights[i]
			var v := ramp.length * float(i) / steps
			md.add_vertex(top, n, Vector2(0.0, v))
			md.add_vertex(top + out * (h * run) + Vector3.DOWN * (h + 0.03), n, Vector2(h / sin(SKIRT_ANGLE) + 0.03, v))
			md.colors.append_array([skirt_color, skirt_color])
		for i in steps:
			var a := base + i * 2
			md.add_tri(a, a + 1, a + 2, md.normals[a])
			md.add_tri(a + 1, a + 3, a + 2, md.normals[a])

	# Face da borda (vertical, virada para a frente).
	var lip_right := rights[steps]
	var lip_dir := track.get_direction_at(lip_dist)
	lip_dir.y = 0.0
	lip_dir = lip_dir.normalized()
	var lip_h := heights[steps]
	var top_l := mid[steps] - lip_right * half
	var top_r := mid[steps] + lip_right * half
	var drop := Vector3.DOWN * (lip_h + 0.03)
	var foot_l := top_l - lip_right * (lip_h * run) + drop
	var foot_r := top_r + lip_right * (lip_h * run) + drop
	base = md.verts.size()
	for p: Vector3 in [foot_l, top_l, top_r, foot_r]:
		md.add_vertex(p, lip_dir, Vector2((p - foot_l).dot(lip_right), p.y - foot_l.y))
		md.colors.append(lip_color)
	md.add_tri(base, base + 1, base + 2, lip_dir)
	md.add_tri(base, base + 2, base + 3, lip_dir)

	var mat := ShaderMaterial.new()
	mat.shader = RAMP_SHADER
	mat.set_shader_parameter("ramp_length", ramp.length)
	mat.set_shader_parameter("ramp_width", half * 2.0)
	mat.set_shader_parameter("turbo", ramp.turbo)
	mat.set_shader_parameter("glider", ramp.glider)
	mat.set_shader_parameter("logo", LOGO_ICON)
	mat.set_shader_parameter("logo_aspect", float(LOGO_ICON.get_width()) / LOGO_ICON.get_height())
	var mi := MeshInstance3D.new()
	mi.name = "Rampa"
	mi.mesh = md.to_mesh(mat)
	root.add_child(mi)

	if not track.with_collision:
		return
	var body := JumpRamp.new()
	body.name = "RampaColisao"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_solid_faces(md.collision_faces()))
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var lip_point := track.get_point_at(lip_dist) + lip_right * center
	body.lip = Transform3D(Basis.looking_at(lip_dir, Vector3.UP), lip_point)
	body.ramp_length = ramp.length
	body.half_width = half
	body.height = ramp.height
	body.launch_angle = ramp.lip_angle()
	body.glider = ramp.glider
	root.add_child(body)

	if ramp.turbo:
		# Igual às placas de turbo: o kart ganha o turbo ao entrar na rampa.
		var area := Area3D.new()
		area.name = "TurboRampa"
		var box := BoxShape3D.new()
		box.size = Vector3(half * 2.0, ramp.height + 2.0, ramp.length)
		var area_col := CollisionShape3D.new()
		area_col.shape = box
		area.add_child(area_col)
		area.transform = Transform3D(Basis.looking_at(lip_dir, Vector3.UP),
				lip_point - lip_dir * ramp.length * 0.5 + Vector3.UP * (ramp.height * 0.5 + 0.6))
		area.body_entered.connect(track._on_boost_pad_body_entered)
		root.add_child(area)

	if ramp.glider:
		_build_guard_walls(start - GUARD_BEFORE, lip_dist + ramp.glide_distance, GLIDE_GUARD_HEIGHT)
	else:
		_build_guard_walls(start - GUARD_BEFORE, lip_dist + GUARD_AFTER, GUARD_HEIGHT)


## Paredes invisíveis em cima das muretas no trecho do pulo (só colisão), com `height`
## m acima delas.
func _build_guard_walls(from: float, to: float, height: float) -> void:
	var offset := track.road_width * 0.5 + track.shoulder_width
	var count := ceili((to - from) / 2.0)
	var low := Vector3.UP * (track.wall_height - 0.2)
	var high := Vector3.UP * (track.wall_height + height)
	var faces := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for i in count + 1:
			var d := lerpf(from, to, float(i) / count)
			var r := track.get_direction_at(d).cross(Vector3.UP).normalized()
			var p := track.get_point_at(d) + r * side * offset
			if i > 0:
				faces.append_array([prev + low, prev + high, p + low, prev + high, p + high, p + low])
			prev = p
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "ParedeInvisivelPulo"
	body.add_to_group("wall")
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	root.add_child(body)


## Tira os triângulos sem área (o começo das saias, onde a altura é zero).
static func _solid_faces(faces: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		if (faces[i + 1] - a).cross(faces[i + 2] - a).length_squared() > 1e-8:
			out.append_array([a, faces[i + 1], faces[i + 2]])
	return out
