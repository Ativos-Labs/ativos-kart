@tool
class_name TrackCoins
extends Node3D
## Moedas Ativos espalhadas pela pista (montadas por Track a partir de `coin_lines` e
## das rampas). Cada moeda pega soma um pouco na velocidade máxima do kart (até
## Kart.MAX_COINS) e volta a aparecer depois de RESPAWN_TIME. As moedas são MultiMeshes
## por bloco de CHUNK metros (veja `_build_chunks`); o giro fica no shader
## (shaders/coin.gdshader).
## A coleta é uma conta de distância por kart (grade de células), sem física.

const COIN_SCENE := preload("res://assets/models/moeda/moeda.glb")
const SHADER := preload("res://shaders/coin.gdshader")
## Tamanho da moeda em relação ao modelo (feito para os karts de antes do encaixe piloto
## × kart, que encolheram).
const COIN_SCALE := KartScale.ITEMS
## Altura do centro da moeda acima do asfalto (m).
const HEIGHT := 0.95 * KartScale.ITEMS
## Área de coleta, medida do meio do kart: no plano, meia largura da caixa de batida do
## kart (Kart.hitbox_size) mais este alcance (o raio da moeda e uma folga); na altura,
## esta meia altura.
const PICK_REACH := 0.78 * KartScale.ITEMS
const PICK_HEIGHT := 1.3 * KartScale.ITEMS
## Altura do meio do kart acima do chão (m).
const KART_CENTER := 0.55 * KartScale.ITEMS
const RESPAWN_TIME := 12.0
## Lado das células da grade de busca (m).
const CELL := 8.0
## Lado dos blocos de desenho (m): cada bloco é um MultiMesh (veja `_build_chunks`).
const CHUNK := 48.0
## Moeda que voa ao ser pega: duração (s), subida (m) e quantas podem voar juntas.
const POP_TIME := 0.42
const POP_RISE := 1.6 * KartScale.ITEMS
const POP_POOL := 10
## Sombra no chão (mancha redonda, como a das caixas de item): diâmetro em relação ao da
## moeda e altura máxima da moeda acima do chão para ter sombra (as do voo de asa-delta,
## lá no alto, ficam sem).
const SHADOW_SIZE := 1.7
const SHADOW_OPACITY := 0.65
const SHADOW_MAX_HEIGHT := 4.0
const GROW_TIME := 0.35

## Posições das moedas (espaço deste nó = espaço da pista).
var positions := PackedVector3Array()

## Um MultiMesh por bloco; a moeda i está no bloco `_chunk_of[i]`, instância `_slot_of[i]`.
var _mms: Array[MultiMesh] = []
var _chunk_of := PackedInt32Array()
var _slot_of := PackedInt32Array()
var _bases: Array[Basis] = []
## Sombras: uma MultiMesh à parte; `_shadow_of[i]` = instância da sombra da moeda i (-1 = sem).
var _shadow_mm: MultiMesh
var _shadow_of := PackedInt32Array()
var _shadow_xf: Array[Transform3D] = []
var _active := PackedByteArray()
var _respawn_at := PackedFloat32Array()
var _waiting := 0
var _growing := {}
var _grid := {}
var _time := 0.0
var _karts: Array[Node] = []
var _karts_frame := -1
var _pops: Array[MeshInstance3D] = []
var _pop_t := PackedFloat32Array()
var _pop_from := PackedVector3Array()
var _pop_dir := PackedVector3Array()

static var _mesh: Mesh
static var _material: ShaderMaterial
static var _pop_material: ShaderMaterial
static var _lock := Mutex.new()


## Malha da moeda (do moeda.glb), compartilhada por todas as pistas.
static func coin_mesh() -> Mesh:
	_lock.lock()
	if _mesh == null:
		var scene := COIN_SCENE.instantiate()
		var found := scene.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			_mesh = (found[0] as MeshInstance3D).mesh
		scene.free()
	_lock.unlock()
	return _mesh


## Material dourado que gira (o da moeda que voa gira mais rápido).
static func coin_material(pop := false) -> ShaderMaterial:
	var mesh := coin_mesh()
	_lock.lock()
	if _material == null:
		var tex: Texture2D = null
		if mesh and mesh.get_surface_count() > 0:
			var base := mesh.surface_get_material(0) as BaseMaterial3D
			if base:
				tex = base.albedo_texture
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("albedo_tex", tex)
		_pop_material = _material.duplicate() as ShaderMaterial
		_pop_material.set_shader_parameter("spin_speed", 16.0)
		_pop_material.set_shader_parameter("bob_height", 0.0)
		_pop_material.set_shader_parameter("glow", 0.65)
	_lock.unlock()
	return _pop_material if pop else _material


## Solta a malha e os materiais guardados (fim do jogo).
static func clear_cache() -> void:
	_lock.lock()
	_mesh = null
	_material = null
	_pop_material = null
	_lock.unlock()


## Monta as moedas. `with_collision` = false: só o visual (prévia da tela de pistas).
## `grounds` = ponto do chão embaixo de cada moeda (onde fica a sombra; vazio = sem sombra).
func setup(p_positions: PackedVector3Array, directions: PackedVector3Array, with_collision: bool,
		grounds := PackedVector3Array()) -> void:
	positions = p_positions
	var count := positions.size()
	_active.resize(count)
	_active.fill(1)
	_respawn_at.resize(count)
	_bases.clear()
	for i in count:
		var dir := directions[i] if i < directions.size() else Vector3.FORWARD
		dir.y = 0.0
		_bases.append(Basis.looking_at(dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD, Vector3.UP)
				.scaled(Vector3.ONE * COIN_SCALE))
		var cell := _cell_of(positions[i])
		if not _grid.has(cell):
			_grid[cell] = PackedInt32Array()
		var list: PackedInt32Array = _grid[cell]
		list.append(i)
		_grid[cell] = list
	_build_chunks()
	_build_shadows(directions, grounds)
	var live := with_collision and not Engine.is_editor_hint()
	set_physics_process(live)
	set_process(live)
	if live:
		for i in POP_POOL:
			var pop := MeshInstance3D.new()
			pop.name = "MoedaPega"
			pop.mesh = coin_mesh()
			pop.material_override = coin_material(true)
			pop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Anda no _process (quadro a quadro), fora da interpolação da física.
			pop.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			pop.visible = false
			add_child(pop)
			_pops.append(pop)
		_pop_t.resize(POP_POOL)
		_pop_t.fill(-1.0)
		_pop_from.resize(POP_POOL)
		_pop_dir.resize(POP_POOL)


## As moedas em blocos de CHUNK metros, um MultiMesh por bloco. Com um MultiMesh só para
## a pista toda o Godot desenhava todas as moedas em todo quadro (inclusive as de trás da
## câmera) e sempre no LOD mais detalhado, porque o LOD e o descarte usam a caixa do
## MultiMesh inteiro, que cobre a pista. A fase do giro vem do índice global da moeda
## (INSTANCE_CUSTOM.r no shader), igual ao INSTANCE_ID de quando era um MultiMesh só.
func _build_chunks() -> void:
	var count := positions.size()
	var groups := {}
	var order: Array[Vector2i] = []
	for i in count:
		var p := positions[i]
		var key := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
		if not groups.has(key):
			groups[key] = PackedInt32Array()
			order.append(key)
		var ids: PackedInt32Array = groups[key]
		ids.append(i)
		groups[key] = ids
	_chunk_of.resize(count)
	_slot_of.resize(count)
	_mms.clear()
	for key in order:
		var ids: PackedInt32Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = coin_mesh()
		mm.instance_count = ids.size()
		for k in ids.size():
			var i := ids[k]
			_chunk_of[i] = _mms.size()
			_slot_of[i] = k
			mm.set_instance_transform(k, Transform3D(_bases[i], positions[i]))
			mm.set_instance_custom_data(k, Color(float(i), 0.0, 0.0, 0.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Moedas"
		mmi.multimesh = mm
		mmi.material_override = coin_material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# O balanço do shader passa um pouco da caixa das moedas.
		mmi.extra_cull_margin = 0.5
		# As moedas que voltam crescem no _process: sem interpolação da física (senão o
		# Godot avisa e mantém um buffer de interpolação da MultiMesh à toa).
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(mmi, true)
		_mms.append(mm)


## Transformação da moeda i (no bloco dela).
func _set_coin(i: int, xf: Transform3D) -> void:
	_mms[_chunk_of[i]].set_instance_transform(_slot_of[i], xf)


## Mancha de sombra no chão embaixo de cada moeda baixa (uma chamada de desenho para
## todas). Não usa a sombra de verdade do sol: cada bloco de moedas sombreado seria
## desenhado de novo em cada divisão (cascata) da sombra, a cada quadro.
func _build_shadows(directions: PackedVector3Array, grounds: PackedVector3Array) -> void:
	_shadow_of.resize(positions.size())
	_shadow_of.fill(-1)
	_shadow_xf.clear()
	var mesh := coin_mesh()
	if grounds.size() != positions.size() or mesh == null:
		return
	var diameter := maxf(mesh.get_aabb().size.x, mesh.get_aabb().size.y) * COIN_SCALE * SHADOW_SIZE
	for i in positions.size():
		var ground := grounds[i]
		if positions[i].y - ground.y > SHADOW_MAX_HEIGHT:
			continue
		var dir := directions[i] if i < directions.size() else Vector3.FORWARD
		if dir.length_squared() < 0.001:
			dir = Vector3.FORWARD
		# Deitada no asfalto (com a subida da pista), um pouco acima para não piscar.
		var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
		_shadow_of[i] = _shadow_xf.size()
		_shadow_xf.append(Transform3D(basis, ground + basis.y * 0.05))
	if _shadow_xf.is_empty():
		return
	_shadow_mm = MultiMesh.new()
	_shadow_mm.transform_format = MultiMesh.TRANSFORM_3D
	_shadow_mm.mesh = ItemBox.make_shadow_mesh(diameter, SHADOW_OPACITY)
	_shadow_mm.instance_count = _shadow_xf.size()
	for k in _shadow_xf.size():
		_shadow_mm.set_instance_transform(k, _shadow_xf[k])
	var smi := MultiMeshInstance3D.new()
	smi.name = "SombrasMoedas"
	smi.multimesh = _shadow_mm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(smi)


## Tamanho da sombra da moeda i (0 = escondida, junto com a moeda pega).
func _scale_shadow(i: int, s: float) -> void:
	var k := _shadow_of[i] if i < _shadow_of.size() else -1
	if k < 0:
		return
	var xf := _shadow_xf[k]
	_shadow_mm.set_instance_transform(k, Transform3D(xf.basis.scaled(Vector3.ONE * s), xf.origin))


func _ready() -> void:
	if _mms.is_empty():
		set_physics_process(false)
		set_process(false)


static func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


## Mostra as moedas que voam (para o shader delas compilar atrás da tela de
## carregamento, veja Race.warm_up).
func prewarm(on: bool, near: Vector3 = Vector3.ZERO) -> void:
	for i in _pops.size():
		var pop := _pops[i]
		pop.visible = on
		if on:
			pop.global_position = near + Vector3(0.0, 1.2, 0.0) + Vector3.RIGHT * (i - _pops.size() * 0.5)
			pop.scale = Vector3.ONE


func _physics_process(delta: float) -> void:
	_time += delta
	if _waiting > 0:
		_respawn_due()
	var frame := Engine.get_physics_frames()
	if _karts_frame < 0 or frame - _karts_frame >= 60:
		_karts = get_tree().get_nodes_in_group(&"kart")
		_karts_frame = frame
	if _karts.is_empty():
		return
	var inv := global_transform.affine_inverse()
	for node in _karts:
		if not is_instance_valid(node):
			continue
		var kart := node as Kart
		if kart == null:
			continue
		# Veículo mais estreito (moto) precisa passar mais perto da moeda.
		var r := kart.hitbox_size.x * 0.5 + PICK_REACH
		var r2 := r * r
		var p := inv * kart.global_position + Vector3(0.0, KART_CENTER, 0.0)
		var cell := _cell_of(p)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var list: Variant = _grid.get(cell + Vector2i(dx, dz))
				if list == null:
					continue
				for i: int in list:
					if _active[i] == 0:
						continue
					var c := positions[i]
					var flat := Vector2(p.x - c.x, p.z - c.z)
					if flat.length_squared() < r2 and absf(p.y - c.y) < PICK_HEIGHT:
						_collect(i, kart)


func _collect(i: int, kart: Kart) -> void:
	_active[i] = 0
	_respawn_at[i] = _time + RESPAWN_TIME
	_waiting += 1
	_growing.erase(i)
	_set_coin(i, Transform3D(Basis().scaled(Vector3.ZERO), positions[i]))
	_scale_shadow(i, 0.0)
	_spawn_pop(positions[i])
	kart.add_coin()


func _respawn_due() -> void:
	for i in _active.size():
		if _active[i] == 0 and _time >= _respawn_at[i]:
			_active[i] = 1
			_waiting -= 1
			_growing[i] = 0.0


## Moedas perdidas saltando de um kart (em `at`, espaço global) para os lados.
func burst(at: Vector3, count: int) -> void:
	if _pops.is_empty():
		return
	var local := global_transform.affine_inverse() * at + Vector3.UP * 0.8 * KartScale.ITEMS
	for i in count:
		var a := TAU * (float(i) / count) + randf() * 0.8
		_spawn_pop(local, Vector3(cos(a), 0.0, sin(a)) * 2.2 * KartScale.ITEMS)


func _spawn_pop(at: Vector3, drift := Vector3.ZERO) -> void:
	var best := 0
	for k in _pop_t.size():
		if _pop_t[k] < 0.0:
			best = k
			break
		if _pop_t[k] > _pop_t[best]:
			best = k
	_pop_t[best] = 0.0
	_pop_from[best] = at
	_pop_dir[best] = drift
	var pop := _pops[best]
	pop.position = at
	pop.scale = Vector3.ONE * COIN_SCALE
	pop.visible = true


func _process(delta: float) -> void:
	# Moedas que voltam: crescem do nada.
	if not _growing.is_empty():
		for i: int in _growing.keys():
			var t: float = _growing[i] + delta
			var k := clampf(t / GROW_TIME, 0.0, 1.0)
			var s := 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
			_set_coin(i, Transform3D(_bases[i].scaled(Vector3.ONE * maxf(s, 0.001)), positions[i]))
			_scale_shadow(i, clampf(k, 0.001, 1.0))
			if k >= 1.0:
				_growing.erase(i)
			else:
				_growing[i] = t
	# Moedas pegas: sobem girando e encolhem.
	for k in _pop_t.size():
		if _pop_t[k] < 0.0:
			continue
		_pop_t[k] += delta
		var u := clampf(_pop_t[k] / POP_TIME, 0.0, 1.0)
		var pop := _pops[k]
		pop.position = _pop_from[k] + _pop_dir[k] * u + Vector3.UP * POP_RISE * (1.0 - (1.0 - u) * (1.0 - u))
		pop.scale = Vector3.ONE * lerpf(1.0, 0.25, u * u) * COIN_SCALE
		if u >= 1.0:
			_pop_t[k] = -1.0
			pop.visible = false
