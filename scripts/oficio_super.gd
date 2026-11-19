class_name OficioSuper
extends Node3D
## Superpreferência em 3D: o kart vira um ofício gigante (folha A4 de 3 m) voando baixo
## como um tapete, ondulando (shaders/oficio.gdshader). Ele nasce do tamanho do kart,
## cresce, e o carimbo PRIORIDADE bate em cima. No fim a folha sobe girando e some, e o
## kart reaparece. Inclina com a subida/descida e com as curvas.
## Montado uma vez (ItemEffects): só uma Superpreferência por vez na pista.

const SHADER := preload("res://shaders/oficio.gdshader")
const PAPER_TEX := preload("res://assets/textures/itens/oficio.png")
const STAMP_TEX := preload("res://assets/textures/itens/oficio_carimbo.png")
## Tamanho da folha (m, proporção A4) e a altura em que ela voa.
const SIZE := Vector2(3.0, 4.24)
const HOVER := 0.7
## Quando o carimbo bate (s depois de virar ofício) e quanto demora.
const STAMP_AT := 0.32
const STAMP_TIME := 0.16

var sheet: MeshInstance3D
var _mat: ShaderMaterial
var _kart: Kart
var _home: Node3D
var _t := -1.0
var _leaving := false
var _pitch := 0.0
var _roll := 0.0
var _tween: Tween


func build(home: Node3D) -> void:
	name = "Oficio"
	_home = home
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("paper_tex", PAPER_TEX)
	_mat.set_shader_parameter("stamp_tex", STAMP_TEX)
	_mat.set_shader_parameter("sheet_size", SIZE)
	sheet = MeshInstance3D.new()
	sheet.name = "Folha"
	sheet.mesh = _sheet_mesh()
	sheet.material_override = _mat
	add_child(sheet)
	_park()


func is_busy() -> bool:
	return _t >= 0.0


## `k` vira o ofício (o kart já sumiu: Kart.start_super).
func start(k: Kart) -> void:
	_kart = k
	_t = 0.0
	_leaving = false
	_pitch = 0.0
	_roll = 0.0
	if get_parent() != k:
		get_parent().remove_child(self)
		k.add_child(self)
	position = Vector3(0.0, HOVER, 0.0)
	rotation = Vector3.ZERO
	scale = Vector3(0.45, 1.0, 0.45)
	visible = true
	reset_physics_interpolation()
	_mat.set_shader_parameter("stamp", 0.0)
	_kill_tween()
	_tween = _new_tween()
	_tween.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(maxf(STAMP_AT - 0.3, 0.0))
	_tween.tween_method(_set_stamp, 0.0, 1.0, STAMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	set_physics_process(true)


## O ofício acabou: a folha sobe girando e some (o kart reaparece embaixo).
func finish() -> void:
	if not is_busy() or _leaving:
		return
	_leaving = true
	var keep := global_transform
	if get_parent() != _home:
		get_parent().remove_child(self)
		_home.add_child(self)
	global_transform = keep
	reset_physics_interpolation()
	var fwd := -keep.basis.z
	fwd.y = 0.0
	_kill_tween()
	_tween = _new_tween().set_parallel()
	_tween.tween_property(self, "position", position + Vector3.UP * 6.0 + fwd.normalized() * 10.0, 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", rotation + Vector3(-0.9, 2.4, 0.5), 0.8)
	_tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_park)


## Mostra a folha parada em `xf` (compila o shader atrás da tela de carregamento).
func prewarm(on: bool, xf := Transform3D.IDENTITY) -> void:
	if is_busy():
		return
	if on:
		visible = true
		global_transform = xf
		_mat.set_shader_parameter("stamp", 1.0)
		reset_physics_interpolation()
	else:
		_park()


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		set_physics_process(false)
		return
	_t += delta
	if _leaving:
		return
	if not is_instance_valid(_kart):
		_park()
		return
	# Bico acompanha a subida/descida; inclina para dentro das curvas.
	var v := _kart.velocity
	var flat := Vector2(v.x, v.z).length()
	var pitch := clampf(atan2(v.y, maxf(flat, 4.0)), -0.35, 0.35)
	var roll := clampf(_kart.get_yaw_rate() * 0.12, -0.3, 0.3)
	var k := 1.0 - exp(-8.0 * delta)
	_pitch = lerpf(_pitch, pitch, k)
	_roll = lerpf(_roll, roll, k)
	rotation = Vector3(_pitch + 0.04, 0.0, _roll)
	position.y = HOVER + sin(_t * 3.1) * 0.08


func _set_stamp(value: float) -> void:
	_mat.set_shader_parameter("stamp", value)


func _park() -> void:
	_kill_tween()
	_t = -1.0
	_leaving = false
	_kart = null
	visible = false
	if get_parent() and get_parent() != _home:
		get_parent().remove_child(self)
		_home.add_child(self)
	set_physics_process(false)


func _new_tween() -> Tween:
	return create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null


## Folha plana (x = largura, z = comprimento, frente em -z) com bastante divisão para a
## onda; lado impresso para cima (+y). O shader levanta os vértices.
func _sheet_mesh() -> ArrayMesh:
	var cols := 10
	var rows := 16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows + 1:
		for i in cols + 1:
			var u := float(i) / cols
			var v := float(j) / rows
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3((u - 0.5) * SIZE.x, 0.0, (v - 0.5) * SIZE.y))
	for j in rows:
		for i in cols:
			var a := j * (cols + 1) + i
			var b := a + 1
			var c := a + cols + 1
			var d := c + 1
			for idx: int in [a, b, d, a, d, c]:
				st.add_index(idx)
	var mesh := st.commit()
	mesh.custom_aabb = AABB(Vector3(-SIZE.x * 0.5, -0.5, -SIZE.y * 0.5), Vector3(SIZE.x, 1.4, SIZE.y))
	return mesh
