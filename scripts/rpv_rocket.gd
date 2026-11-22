class_name RpvRocket
extends Node3D
## RPV em 3D: a guia de pagamento verde aparece esticada embaixo do kart, enrola num
## tubo (shaders/rpv_rocket.gdshader), ganha bico e aletas e vira um foguete com fogo
## saindo de trás. O kart sobe em cima dele (`Kart.visual_lift`) enquanto o turbo dura;
## no fim o foguete solta, desenrola e fica para trás.
## Um por kart, filho do kart (acompanha a posição com a interpolação da física) e
## criado na primeira RPV dele (ItemEffects.rpv). Malhas e materiais são os mesmos para
## todos (um shader só para compilar).

const SHADER := preload("res://shaders/rpv_rocket.gdshader")
const GUIA_TEX := preload("res://assets/textures/itens/rpv_guia.png")
## Raio e comprimento do tubo (m).
const RADIUS := 0.22
const LENGTH := 2.8
## O foguete fica um pouco para trás (m): a cauda, com as aletas e o "RPV", sai de
## trás do kart, onde a câmera vê.
const BACK := 0.45 * KartScale.ITEMS
## Quanto o modelo do kart sobe (m) para ficar em cima do foguete.
const LIFT := 0.36 * KartScale.ITEMS
## Tempos (s): enrolar, o fogo acender e soltar no fim.
const ROLL_TIME := 0.22
const IGNITE_AT := 0.16
const DROP_TIME := 0.45

static var _sheet_mesh: ArrayMesh
static var _nose_mesh: ArrayMesh
static var _fins_mesh: ArrayMesh
static var _solid_material: ShaderMaterial

var kart: Kart
var _sheet: MeshInstance3D
var _parts: Node3D
var _mat: ShaderMaterial
var _flame: BoostExhaustFx
var _t := -1.0
var _len := 1.5
## Soltou (fim): fica parado no mundo, desenrolando.
var _dropped := false
var _drop_xf := Transform3D.IDENTITY
var _lift_vel := 0.0


## Monta o foguete embaixo de `k` (escondido).
func build(k: Kart) -> void:
	name = "FogueteRPV"
	kart = k
	_build_meshes()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("guia_tex", GUIA_TEX)
	_mat.set_shader_parameter("radius", RADIUS)
	_sheet = MeshInstance3D.new()
	_sheet.name = "Guia"
	_sheet.mesh = _sheet_mesh
	_sheet.material_override = _mat
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheet)
	# Bico e aletas: aparecem quando o tubo fecha.
	_parts = Node3D.new()
	_parts.name = "BicoAletas"
	add_child(_parts)
	for m: ArrayMesh in [_nose_mesh, _fins_mesh]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = _solid_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_parts.add_child(mi)
	# Fogo da traseira: o mesmo fogo do turbo dos karts, numa "saída" só.
	var ex := KartExhaust.new()
	ex.position = Vector3(0.0, RADIUS, LENGTH * 0.5 + 0.02)
	ex.direction = Vector3.BACK
	ex.radius = RADIUS * 0.8
	ex.length = 1.1
	var data := KartData.new()
	data.exhausts.append(ex)
	_flame = BoostExhaustFx.new()
	_flame.name = "Fogo"
	add_child(_flame)
	_flame.setup(data, false)
	visible = false
	set_physics_process(false)


func is_busy() -> bool:
	return _t >= 0.0


## Começa: o turbo dura `duration` s (quem chama dá o turbo no kart).
func play(duration: float) -> void:
	if _dropped:
		_detach_back()
	_len = maxf(duration, 0.3)
	_t = 0.0
	_dropped = false
	_lift_vel = 0.0
	visible = true
	_parts.scale = Vector3.ONE * 0.01
	_mat.set_shader_parameter("roll", 0.0)
	# O modelo foi feito para os karts de antes do encaixe piloto × kart: encolhe com eles.
	scale = Vector3.ONE * (kart.data.race_scale if kart.data else 1.0) * KartScale.ITEMS
	_follow()
	reset_physics_interpolation()
	_flame.ignite(3)
	set_physics_process(true)


## Mostra o foguete pronto (compila os shaders atrás da tela de carregamento).
func prewarm(on: bool) -> void:
	if is_busy():
		return
	visible = on
	if on:
		_mat.set_shader_parameter("roll", 1.0)
		_parts.scale = Vector3.ONE
		_follow()
	_flame.prewarm(on)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		set_physics_process(false)
		return
	_t += delta
	if not is_instance_valid(kart):
		_park()
		return
	if not _dropped:
		var k := clampf(_t / ROLL_TIME, 0.0, 1.0)
		_mat.set_shader_parameter("roll", k * k * (3.0 - 2.0 * k))
		var p := clampf((_t - ROLL_TIME * 0.7) / 0.14, 0.0, 1.0)
		_parts.scale = Vector3.ONE * maxf(1.0 + 2.70158 * pow(p - 1.0, 3.0) + 1.70158 * pow(p - 1.0, 2.0), 0.01)
		_follow()
		_flame.update(delta, _t >= IGNITE_AT)
		_spring_lift(LIFT, delta)
		# Acaba no tempo, ou antes se o turbo foi cortado (raio, obstáculo, atropelado).
		var cut := _t > IGNITE_AT + 0.1 and kart.boost_time <= 0.0
		if _t >= _len or cut or kart.is_super():
			_drop()
	else:
		# Solto: fica no chão onde estava, desenrola, gira um pouco e some.
		var d := clampf((_t - _len) / DROP_TIME, 0.0, 1.0)
		_mat.set_shader_parameter("roll", 1.0 - d)
		_parts.scale = Vector3.ONE * maxf(1.0 - d * 3.0, 0.01)
		var spin := Basis(Vector3.UP, d * 0.8)
		var s := (kart.data.race_scale if kart.data else 1.0) * KartScale.ITEMS * (1.0 - d * d)
		global_transform = Transform3D(_drop_xf.basis * spin * Basis.from_scale(Vector3.ONE * maxf(s, 0.01)),
				_drop_xf.origin + Vector3.UP * d * 0.6 * KartScale.ITEMS)
		_flame.update(delta, false)
		_spring_lift(0.0, delta)
		if d >= 1.0:
			_park()


## Em baixo do kart, com a inclinação do modelo (rampas, curvas), mas sem a subida.
func _follow() -> void:
	var b := kart.visual.transform.basis.orthonormalized()
	transform = Transform3D(b * Basis.from_scale(scale), b * Vector3(0.0, 0.0, BACK) + Vector3(0.0, 0.03, 0.0))


func _spring_lift(goal: float, delta: float) -> void:
	if not is_instance_valid(kart):
		return
	_lift_vel += ((goal - kart.visual_lift) * 260.0 - _lift_vel * 20.0) * delta
	kart.visual_lift = clampf(kart.visual_lift + _lift_vel * delta, 0.0, LIFT * 1.3)


## O turbo acabou: o foguete solta do kart e fica para trás.
func _drop() -> void:
	_dropped = true
	_drop_xf = global_transform.orthonormalized()
	_len = _t
	top_level = true
	global_transform = _drop_xf
	reset_physics_interpolation()


func _detach_back() -> void:
	top_level = false
	_dropped = false


## Esconde e para; o kart volta para o chão.
func _park() -> void:
	_t = -1.0
	_detach_back()
	visible = false
	set_physics_process(false)
	if is_instance_valid(kart):
		kart.visual_lift = 0.0


# --- Malhas -----------------------------------------------------------------------------

static func _build_meshes() -> void:
	if _sheet_mesh:
		return
	# Folha: x dá a volta (largura = circunferência), z ao longo (bico em -z). Lado
	# impresso para cima (+y) — vira o lado de fora do tubo. UV.x vai do bico para trás.
	var width := TAU * RADIUS
	var cols := 24
	var rows := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows + 1:
		for i in cols + 1:
			var u := float(i) / cols
			var v := float(j) / rows
			st.set_uv(Vector2(v, 1.0 - u))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3((u - 0.5) * width, 2.0 * RADIUS, (v - 0.5) * LENGTH))
	for j in rows:
		for i in cols:
			var a := j * (cols + 1) + i
			var b := a + 1
			var c := a + cols + 1
			var d := c + 1
			# Horário visto de cima (a frente do triângulo fica para +y).
			for idx: int in [a, b, d, a, d, c]:
				st.add_index(idx)
	_sheet_mesh = st.commit()
	_sheet_mesh.custom_aabb = AABB(Vector3(-width * 0.5, -0.05, -LENGTH * 0.5 - 0.1), Vector3(width, 2.0 * RADIUS + 0.1, LENGTH + 0.2))

	# Bico: cone na frente do tubo.
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = RADIUS * 1.02
	nose.height = 0.5
	nose.radial_segments = 16
	nose.rings = 1
	nose.cap_bottom = false
	var nose_arrays := nose.get_mesh_arrays()
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, RADIUS, -LENGTH * 0.5 - 0.25))
	_nose_mesh = _transformed(nose_arrays, xf)

	# Aletas: três triângulos (dois dos lados e um em cima) na traseira.
	var fins := SurfaceTool.new()
	fins.begin(Mesh.PRIMITIVE_TRIANGLES)
	var back := LENGTH * 0.5
	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP]:
		var root := Vector3(0.0, RADIUS, 0.0) + dir * RADIUS * 0.9
		var tip := Vector3(0.0, RADIUS, 0.0) + dir * RADIUS * 2.3
		var p0 := root + Vector3(0.0, 0.0, back - 0.55)
		var p1 := root + Vector3(0.0, 0.0, back + 0.02)
		var p2 := tip + Vector3(0.0, 0.0, back + 0.1)
		var n := (p1 - p0).cross(p2 - p0).normalized()
		for p: Vector3 in [p0, p1, p2]:
			fins.set_normal(n)
			fins.add_vertex(p)
		for p: Vector3 in [p0, p2, p1]:
			fins.set_normal(-n)
			fins.add_vertex(p)
	_fins_mesh = fins.commit()

	_solid_material = ShaderMaterial.new()
	_solid_material.shader = SHADER
	_solid_material.set_shader_parameter("solid", 1.0)


static func _transformed(arrays: Array, xf: Transform3D) -> ArrayMesh:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = xf * verts[i]
		normals[i] = (xf.basis * normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
