class_name TransitoJulgado
extends Node3D
## Trânsito em julgado em 3D: o kart e o piloto banhados de dourado (material_overlay
## nas malhas deles), aura dourada em volta, brilho no chão, um martelo de juiz gigante
## girando em volta dele (e batendo de vez em quando) e brilhos subindo. Fica no kart
## enquanto Kart.judged_time durar: pisca nos últimos FLICKER s e some. Um por kart,
## criado na primeira vez (ItemEffects). Anda em passos de física.

const SHADER := preload("res://shaders/julgado.gdshader")
## Martelo: raio da volta (m, além da metade do kart), altura, voltas por segundo e
## a cada quanto tempo (s) ele bate.
const ORBIT := 0.9 * KartScale.ITEMS
const ORBIT_HEIGHT := 1.05 * KartScale.ITEMS
const ORBIT_SPEED := 0.55
const KNOCK_EVERY := 0.9
const SPARKS := 12
## Últimos segundos piscando.
const FLICKER := 1.6

static var _aura_mat: ShaderMaterial
static var _spark_mat: ShaderMaterial
static var _floor_mat: ShaderMaterial
static var _overlay_mat: ShaderMaterial
static var _gavel_parts: Array = []

var kart: Kart
var _aura: MeshInstance3D
var _orbit: Node3D
var _gavel: Node3D
var _sparks: Array[MeshInstance3D] = []
var _floor: MeshInstance3D
var _spark_t := PackedFloat32Array()
var _t := 0.0
var _knock := 0.0
var _fade := 0.0
var _mat: ShaderMaterial
var _smat: ShaderMaterial
var _fmat: ShaderMaterial
var _omat: ShaderMaterial
## Malhas do kart e do piloto com o banho dourado (e o que elas tinham antes).
var _gilded: Array[GeometryInstance3D] = []
var _gilded_before: Array[Material] = []
var _radius := 1.6


func build(k: Kart) -> void:
	name = "TransitoEmJulgado"
	kart = k
	var size := k.hitbox_size if k.hitbox_size != Vector3.ZERO else Vector3(1.8, 1.2, 2.4) * KartScale.ITEMS
	_radius = maxf(size.x, size.z) * 0.5 + ORBIT
	_mat = _get_aura_material().duplicate() as ShaderMaterial
	_smat = _get_spark_material().duplicate() as ShaderMaterial
	_fmat = _get_floor_material().duplicate() as ShaderMaterial
	_omat = _get_overlay_material().duplicate() as ShaderMaterial
	# Brilho dourado no chão, embaixo do kart.
	_floor = MeshInstance3D.new()
	_floor.name = "BrilhoChao"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (_radius * 2.0 + 0.6 * KartScale.ITEMS)
	_floor.mesh = plane
	_floor.material_override = _fmat
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor.position.y = 0.06
	add_child(_floor)
	_aura = MeshInstance3D.new()
	_aura.name = "Aura"
	var sphere := SphereMesh.new()
	sphere.radial_segments = 24
	sphere.rings = 12
	_aura.mesh = sphere
	_aura.material_override = _mat
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Esfera achatada envolvendo o kart e o piloto.
	_aura.scale = Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5) + Vector3(0.65, 0.85, 0.6) * KartScale.ITEMS
	_aura.position = Vector3(0.0, size.y * 0.5 + 0.25 * KartScale.ITEMS, 0.0)
	add_child(_aura)
	_orbit = Node3D.new()
	_orbit.name = "Volta"
	add_child(_orbit)
	_gavel = Node3D.new()
	_gavel.name = "Martelo"
	_orbit.add_child(_gavel)
	for part: Array in _get_gavel_parts():
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		mi.transform = part[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gavel.add_child(mi)
	_gavel.position = Vector3(_radius, ORBIT_HEIGHT, 0.0)
	_gavel.scale = Vector3.ONE * KartScale.ITEMS
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.7 * KartScale.ITEMS
	_spark_t.resize(SPARKS)
	for i in SPARKS:
		var spark := MeshInstance3D.new()
		spark.name = "Brilho%d" % i
		spark.mesh = quad
		spark.material_override = _smat
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		_sparks.append(spark)
		_spark_t[i] = float(i) / SPARKS
	visible = false
	set_physics_process(false)


## Liga (o kart acabou de ficar invencível).
func play() -> void:
	_t = 0.0
	_knock = 0.0
	_fade = 0.0
	visible = true
	scale = Vector3.ONE * 0.3
	reset_physics_interpolation()
	_gild(true)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if kart == null or not is_instance_valid(kart):
		return
	_t += delta
	var left := kart.judged_time
	var target := 1.0
	if left <= 0.0:
		target = 0.0
	elif left < FLICKER:
		# Pisca cada vez mais rápido no fim.
		target = 1.0 if fmod(_t * lerpf(14.0, 6.0, left / FLICKER), 1.0) < 0.6 else 0.25
	_fade = move_toward(_fade, target, delta * (12.0 if left > 0.0 else 4.0))
	_mat.set_shader_parameter("fade", _fade)
	_smat.set_shader_parameter("fade", _fade)
	_fmat.set_shader_parameter("fade", _fade)
	_omat.set_shader_parameter("fade", _fade)
	# Martelo dando a volta, girando no próprio eixo e batendo (cai e volta) a cada tanto.
	_orbit.rotation.y = _t * TAU * ORBIT_SPEED
	_knock += delta
	var swing := 0.0
	if _knock > KNOCK_EVERY:
		_knock = 0.0
	if _knock < 0.22:
		swing = sin(_knock / 0.22 * PI) * 1.1
	_gavel.rotation = Vector3(0.0, _t * 5.0, -0.5 + swing)
	_gavel.scale = Vector3.ONE * _fade
	# Brilhos subindo em espiral.
	for i in SPARKS:
		var k := fmod(_spark_t[i] + _t * 0.7, 1.0)
		var a := TAU * i / SPARKS + _t * 1.3
		var r := _radius * lerpf(0.75, 0.45, k)
		_sparks[i].position = Vector3(cos(a) * r, (0.2 + k * 2.2) * KartScale.ITEMS, sin(a) * r)
		_sparks[i].scale = Vector3.ONE * sin(k * PI) * lerpf(0.6, 1.1, float(i % 3) / 2.0)
	if left <= 0.0 and _fade <= 0.0:
		visible = false
		_gild(false)
		set_physics_process(false)


## Põe (ou tira) o banho dourado nas malhas sólidas do kart e do piloto (o fogo do
## turbo e a senha da Fila ficam de fora: são quadrados transparentes).
func _gild(on: bool) -> void:
	if on and _gilded.is_empty() and kart.kart_visual:
		for node in kart.kart_visual.find_children("*", "MeshInstance3D", true, false):
			var g := node as MeshInstance3D
			if not g.visible or (kart.boost_fx and kart.boost_fx.is_ancestor_of(g)):
				continue
			if g.get_parent() is SenhaTribunal or g.get_parent().get_parent() is SenhaTribunal:
				continue
			_gilded.append(g)
			_gilded_before.append(g.material_overlay)
			g.material_overlay = _omat
	elif not on:
		for i in _gilded.size():
			if is_instance_valid(_gilded[i]):
				_gilded[i].material_overlay = _gilded_before[i]
		_gilded.clear()
		_gilded_before.clear()


## Mostra parado (compilar os shaders atrás da tela de carregamento).
func prewarm(on: bool) -> void:
	visible = on
	if on:
		scale = Vector3.ONE
		_fade = 1.0
		_mat.set_shader_parameter("fade", 1.0)
		_smat.set_shader_parameter("fade", 1.0)
		_fmat.set_shader_parameter("fade", 1.0)
		_omat.set_shader_parameter("fade", 1.0)
		for i in SPARKS:
			_sparks[i].position = Vector3(cos(i) * _radius, 1.0 * KartScale.ITEMS, sin(i) * _radius)
			_sparks[i].scale = Vector3.ONE
	_gild(on)


static func _get_aura_material() -> ShaderMaterial:
	if _aura_mat == null:
		_aura_mat = ShaderMaterial.new()
		_aura_mat.shader = SHADER
		_aura_mat.set_shader_parameter("part", 0)
	return _aura_mat


static func _get_floor_material() -> ShaderMaterial:
	if _floor_mat == null:
		_floor_mat = ShaderMaterial.new()
		_floor_mat.shader = SHADER
		_floor_mat.set_shader_parameter("part", 2)
		_floor_mat.render_priority = -1
	return _floor_mat


static func _get_overlay_material() -> ShaderMaterial:
	if _overlay_mat == null:
		_overlay_mat = ShaderMaterial.new()
		_overlay_mat.shader = SHADER
		_overlay_mat.set_shader_parameter("part", 3)
	return _overlay_mat


static func _get_spark_material() -> ShaderMaterial:
	if _spark_mat == null:
		_spark_mat = ShaderMaterial.new()
		_spark_mat.shader = SHADER
		_spark_mat.set_shader_parameter("part", 1)
		_spark_mat.render_priority = 1
	return _spark_mat


## Martelo de juiz (m): cabeça de madeira deitada com duas faixas douradas, cabo e a
## bolinha na ponta. O cabo aponta para baixo (-y) e a cabeça fica de lado (eixo x).
static func _get_gavel_parts() -> Array:
	if not _gavel_parts.is_empty():
		return _gavel_parts
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("8a4b22")
	wood.roughness = 0.35
	var wood_dark := StandardMaterial3D.new()
	wood_dark.albedo_color = Color("4f2810")
	wood_dark.roughness = 0.4
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffcf3a")
	gold.metallic = 0.8
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color("ffb800")
	gold.emission_energy_multiplier = 0.5
	var head := CylinderMesh.new()
	head.top_radius = 0.2
	head.bottom_radius = 0.2
	head.height = 0.78
	head.radial_segments = 16
	head.rings = 1
	var cap := CylinderMesh.new()
	cap.top_radius = 0.23
	cap.bottom_radius = 0.23
	cap.height = 0.1
	cap.radial_segments = 16
	cap.rings = 1
	var band := CylinderMesh.new()
	band.top_radius = 0.215
	band.bottom_radius = 0.215
	band.height = 0.06
	band.radial_segments = 16
	band.rings = 1
	var handle := CylinderMesh.new()
	handle.top_radius = 0.055
	handle.bottom_radius = 0.07
	handle.height = 0.95
	handle.radial_segments = 10
	handle.rings = 1
	var knob := SphereMesh.new()
	knob.radius = 0.1
	knob.height = 0.2
	knob.radial_segments = 10
	knob.rings = 5
	var side := Basis(Vector3.FORWARD, PI * 0.5)
	_gavel_parts = [
		[head, wood, Transform3D(side, Vector3.ZERO)],
		[cap, wood_dark, Transform3D(side, Vector3(0.39, 0.0, 0.0))],
		[cap, wood_dark, Transform3D(side, Vector3(-0.39, 0.0, 0.0))],
		[band, gold, Transform3D(side, Vector3(0.19, 0.0, 0.0))],
		[band, gold, Transform3D(side, Vector3(-0.19, 0.0, 0.0))],
		[handle, wood, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.62, 0.0))],
		[knob, wood_dark, Transform3D(Basis.IDENTITY, Vector3(0.0, -1.1, 0.0))],
	]
	return _gavel_parts
