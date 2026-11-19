@tool
class_name ItemBox
extends Node3D
## Caixa de item: cubo de vidro furta-cor com o logo "at" da Ativos em cada face,
## girando e flutuando sobre a pista (o giro fica no shader, veja
## shaders/item_box.gdshaderinc). Quando um kart passa por ela, ela estoura em
## pedaços, avisa o kart (`Kart.collect_item_box` → sinal `item_box_collected`) e
## volta a aparecer depois de `RESPAWN_TIME`. A lógica dos itens entra no kart/corrida.
## As caixas são criadas pela pista (Track.item_rows).

## Um kart pegou esta caixa.
signal collected(kart: Node3D)

const SHADER := preload("res://shaders/item_box.gdshader")
const INNER_SHADER := preload("res://shaders/item_box_inner.gdshader")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")
## Aresta do cubo e chanfro das quinas (m).
const SIZE := 1.4
const BEVEL := 0.12
## Altura do centro da caixa acima do asfalto (m).
const FLOAT_HEIGHT := 1.3
## Tempo até a caixa voltar depois de pega (s).
const RESPAWN_TIME := 2.5
## Pedaços do estouro: quantidade, duração (s) e gravidade.
const SHARD_COUNT := 9
const SHARD_LIFE := 0.6
const SHARD_GRAVITY := 16.0

## false enquanto a caixa está estourada (esperando para voltar).
var active := true
## false = depois de estourar não volta sozinha (a caixa falsa da Fila do tribunal;
## restore() a mostra de novo).
var respawns := true

var _box: MeshInstance3D
var _shadow: MeshInstance3D
var _area: Area3D
var _shards: Array[MeshInstance3D] = []
var _shard_vel := PackedVector3Array()
var _shard_size := PackedFloat32Array()
var _burst := -1.0


## Monta a caixa com a malha e a sombra compartilhadas pela pista (`make_mesh`,
## `make_shadow_mesh`). Sem colisão ela é só visual (prévia da tela de pistas).
## `ground_tilt` = inclinação da pista (rad, subida > 0) para a sombra deitar no chão.
func setup(mesh: Mesh, shadow_mesh: Mesh, with_collision: bool, ground_tilt := 0.0) -> void:
	_box = MeshInstance3D.new()
	_box.name = "Caixa"
	_box.mesh = mesh
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_box)
	_shadow = MeshInstance3D.new()
	_shadow.name = "Sombra"
	_shadow.mesh = shadow_mesh
	_shadow.position.y = -FLOAT_HEIGHT + 0.05
	_shadow.rotation.x = ground_tilt
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	if with_collision:
		_area = Area3D.new()
		_area.name = "Toque"
		# Área do chão até acima da caixa (o kart é baixo: uma esfera na altura da
		# caixa quase não o alcançaria). 1,9 m de largura: com as caixas a 3,6 m uma
		# da outra, a fileira toda pega o kart (1,8 m de largura) em qualquer ponto.
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.9, FLOAT_HEIGHT + 1.2, 1.9)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position.y = (1.2 - FLOAT_HEIGHT) * 0.5
		_area.add_child(col)
		_area.body_entered.connect(_on_body_entered)
		add_child(_area)


func _ready() -> void:
	set_physics_process(false)


func _on_body_entered(body: Node3D) -> void:
	if not active or not body.has_method("collect_item_box"):
		return
	var push := (body as CharacterBody3D).velocity if body is CharacterBody3D else Vector3.ZERO
	shatter(push)
	body.collect_item_box(self)
	collected.emit(body)


## Estoura a caixa em pedaços (empurrados por `push`, a velocidade de quem bateu)
## e agenda a volta dela.
func shatter(push := Vector3.ZERO) -> void:
	if not active:
		return
	active = false
	_box.visible = false
	_shadow.visible = false
	if _area:
		_area.set_deferred("monitoring", false)
	_spawn_shards(push)
	if respawns:
		get_tree().create_timer(RESPAWN_TIME, false, true).timeout.connect(_respawn)


## Mostra a caixa inteira de novo, na hora (caixa falsa reaproveitada).
func restore() -> void:
	active = true
	_box.visible = true
	_shadow.visible = true
	_box.scale = Vector3.ONE
	_shadow.scale = Vector3.ONE
	_burst = -1.0
	for shard in _shards:
		shard.visible = false


func _respawn() -> void:
	if not is_inside_tree():
		return
	active = true
	_box.visible = true
	_shadow.visible = true
	_box.scale = Vector3.ONE * 0.01
	_shadow.scale = Vector3.ONE * 0.01
	var tween := create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_box, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shadow, "scale", Vector3.ONE, 0.3)
	if _area:
		_area.set_deferred("monitoring", true)


func _spawn_shards(push: Vector3) -> void:
	if _shards.is_empty():
		_shard_vel.resize(SHARD_COUNT)
		_shard_size.resize(SHARD_COUNT)
		for i in SHARD_COUNT:
			var shard := MeshInstance3D.new()
			shard.name = "Pedaco"
			shard.mesh = _box.mesh
			shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(shard)
			_shards.append(shard)
	# Os pedaços seguem quase no embalo do kart: o estouro acontece na frente do
	# jogador em vez de passar colado na câmera.
	# (Os pedaços andam no espaço da caixa, que está virada no sentido da pista.)
	var carry := global_basis.inverse() * Vector3(push.x, 0.0, push.z) * 0.7
	for i in SHARD_COUNT:
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.25, 1.0), randf_range(-1.0, 1.0)).normalized()
		_shard_vel[i] = dir * randf_range(4.5, 8.0) + carry
		_shard_size[i] = randf_range(0.16, 0.28)
		var shard := _shards[i]
		shard.position = dir * SIZE * 0.25
		shard.scale = Vector3.ONE * _shard_size[i]
		shard.visible = true
		shard.reset_physics_interpolation()
	_burst = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _burst < 0.0:
		set_physics_process(false)
		return
	_burst += delta
	var k := clampf(_burst / SHARD_LIFE, 0.0, 1.0)
	for i in _shards.size():
		_shard_vel[i].y -= SHARD_GRAVITY * delta
		var shard := _shards[i]
		shard.position += _shard_vel[i] * delta
		shard.scale = Vector3.ONE * maxf(_shard_size[i] * (1.0 - k * k), 0.001)
	if k >= 1.0:
		for shard in _shards:
			shard.visible = false
		_burst = -1.0
		set_physics_process(false)


# --- Malha e materiais (compartilhados pelas caixas de uma pista) ------------------------

## Cubo com as quinas chanfradas. Cada face tem UV 0..1 (logo em pé olhando de
## fora); os chanfros têm COLOR.r = 1 (viram a moldura branca no shader).
static func make_mesh() -> ArrayMesh:
	var s := SIZE * 0.5
	var inner := s - BEVEL
	var md := Track.MeshData.new()
	var face := Color(0.0, 0.0, 0.0)
	var frame := Color(1.0, 0.0, 0.0)
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	# Faces.
	for n in axes:
		var up := Vector3.UP if absf(n.y) < 0.5 else (Vector3.FORWARD if n.y > 0.0 else Vector3.BACK)
		var right := up.cross(n)
		var base := md.verts.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			md.add_vertex(n * s + right * corner.x * inner + up * corner.y * inner, n,
					Vector2(0.5 + corner.x * 0.5, 0.5 - corner.y * 0.5))
			md.colors.append(face)
		md.add_tri(base, base + 1, base + 2, n)
		md.add_tri(base, base + 2, base + 3, n)
	# Chanfros das arestas (normais das duas faces: sombreado arredondado).
	for i in axes.size():
		for j in range(i + 1, axes.size()):
			var n1 := axes[i]
			var n2 := axes[j]
			if absf(n1.dot(n2)) > 0.5:
				continue
			var e := n1.cross(n2)
			var base := md.verts.size()
			md.add_vertex(n1 * s + n2 * inner + e * inner, n1, Vector2.ZERO)
			md.add_vertex(n1 * s + n2 * inner - e * inner, n1, Vector2.ZERO)
			md.add_vertex(n2 * s + n1 * inner + e * inner, n2, Vector2.ZERO)
			md.add_vertex(n2 * s + n1 * inner - e * inner, n2, Vector2.ZERO)
			md.colors.append_array([frame, frame, frame, frame])
			var facing := (n1 + n2).normalized()
			md.add_tri(base, base + 1, base + 3, facing)
			md.add_tri(base, base + 3, base + 2, facing)
	# Cantos.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var base := md.verts.size()
				md.add_vertex(Vector3(sx * s, sy * inner, sz * inner), Vector3(sx, 0, 0), Vector2.ZERO)
				md.add_vertex(Vector3(sx * inner, sy * s, sz * inner), Vector3(0, sy, 0), Vector2.ZERO)
				md.add_vertex(Vector3(sx * inner, sy * inner, sz * s), Vector3(0, 0, sz), Vector2.ZERO)
				md.colors.append_array([frame, frame, frame])
				md.add_tri(base, base + 1, base + 2, Vector3(sx, sy, sz))
	var mesh := md.to_mesh(make_material())
	# O shader gira e balança a caixa: a caixa de corte cobre qualquer giro.
	mesh.custom_aabb = AABB(Vector3(-1.0, -1.1, -1.0), Vector3(2.0, 2.2, 2.0))
	return mesh


## A malha da caixa falsa (Fila do tribunal): a mesma, com o logo de cabeça para baixo.
static func make_fake_mesh() -> ArrayMesh:
	var mesh := make_mesh()
	mesh.surface_set_material(0, make_material(true))
	return mesh


## Vidro de fora (desenhado por último) com o de dentro como segunda passada. Com
## `upside_down` o logo fica de cabeça para baixo (a caixa falsa da Fila do tribunal).
static func make_material(upside_down := false) -> ShaderMaterial:
	var back := ShaderMaterial.new()
	back.shader = INNER_SHADER
	back.render_priority = 0
	var front := ShaderMaterial.new()
	front.shader = SHADER
	front.render_priority = 1
	front.next_pass = back
	var aspect := float(LOGO_ICON.get_width()) / LOGO_ICON.get_height()
	for m: ShaderMaterial in [front, back]:
		m.set_shader_parameter("logo", LOGO_ICON)
		m.set_shader_parameter("logo_aspect", aspect)
		m.set_shader_parameter("upside_down", upside_down)
	return front


## Sombra redonda e suave no asfalto, embaixo da caixa.
static func make_shadow_mesh() -> PlaneMesh:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.02, 0.03, 0.08, 0.4)
	mat.albedo_texture = tex
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.9, 1.9)
	plane.material = mat
	return plane
