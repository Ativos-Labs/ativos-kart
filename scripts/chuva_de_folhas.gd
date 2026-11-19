class_name ChuvaDeFolhas
extends Node3D
## Chuva de folhas (quem escorrega na Pendência documental; também quando a pilha é
## destruída): as folhas da pilha saltam e caem devagar, balançando e girando, em volta
## do kart. Anda em passos de física (interpolação ligada). ItemAttacks guarda algumas.

const SHEET_TEX := preload("res://assets/textures/itens/pendencia_folha.png")
const COUNT := 14
const LIFE := 1.7
## Tamanho de cada folha (m), gravidade (m/s²) e resistência do ar (1/s).
const SIZE := Vector2(0.42, 0.52)
const GRAVITY := 7.0
const DRAG := 2.2

static var _mesh: QuadMesh

var _sheets: Array[MeshInstance3D] = []
var _vel := PackedVector3Array()
var _spin := PackedVector3Array()
var _sway := PackedFloat32Array()
var _t := -1.0


func build() -> void:
	name = "ChuvaDeFolhas"
	top_level = true
	_vel.resize(COUNT)
	_spin.resize(COUNT)
	_sway.resize(COUNT)
	for i in COUNT:
		var mi := MeshInstance3D.new()
		mi.name = "Folha%d" % i
		mi.mesh = _get_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_sheets.append(mi)
	visible = false
	set_physics_process(false)


func is_busy() -> bool:
	return _t >= 0.0


## As folhas saltam de `pos`; `carry` = velocidade (m/s) que elas herdam (o embalo do
## kart, para a chuva cair em volta dele e não ficar para trás).
func play(pos: Vector3, carry := Vector3.ZERO) -> void:
	global_position = pos
	var flat := Vector3(carry.x, 0.0, carry.z)
	for i in COUNT:
		var a := TAU * i / COUNT + randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a))
		_vel[i] = out * randf_range(2.0, 5.5) + Vector3.UP * randf_range(5.0, 9.5) + flat * randf_range(0.55, 0.85)
		_spin[i] = Vector3(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0), randf_range(-9.0, 9.0))
		_sway[i] = randf() * TAU
		var sheet := _sheets[i]
		sheet.position = out * 0.3 + Vector3.UP * randf_range(0.1, 0.5)
		sheet.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		sheet.scale = Vector3.ONE
	_t = 0.0
	visible = true
	reset_physics_interpolation()
	for sheet in _sheets:
		sheet.reset_physics_interpolation()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		set_physics_process(false)
		return
	_t += delta
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var drag := exp(-DRAG * delta)
	for i in COUNT:
		var v := _vel[i]
		v.y -= GRAVITY * delta
		v *= drag
		# Papel cai planando: balança para os lados.
		var s := _sway[i] + _t * 5.0
		v.x += sin(s) * 3.0 * delta
		v.z += cos(s * 0.8) * 3.0 * delta
		_vel[i] = v
		var sheet := _sheets[i]
		sheet.position += v * delta
		sheet.rotation += _spin[i] * delta
		sheet.scale = Vector3.ONE * (1.0 - smoothstep(0.75, 1.0, k))
	if k >= 1.0:
		_t = -1.0
		visible = false
		set_physics_process(false)


## Mostra as folhas paradas em `pos` (compilar o shader atrás da tela de carregamento).
func prewarm(on: bool, pos := Vector3.ZERO) -> void:
	if on:
		global_position = pos
		for i in COUNT:
			_sheets[i].position = Vector3((i % 5) * 0.5 - 1.0, (i / 5) * 0.6, 0.0)
			_sheets[i].scale = Vector3.ONE
	visible = on
	_t = -1.0


static func _get_mesh() -> QuadMesh:
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = SIZE
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = SHEET_TEX
		mat.roughness = 0.9
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_mesh.material = mat
	return _mesh
