class_name GliderVisual
extends Node3D
## A asa-delta montada no kart. Abre com um estalo quando o kart decola de uma rampa
## de asa-delta (desdobra de trás para a frente e cresce com uma sobrinha), balança de
## leve no ar e fecha rápido ao aterrissar. A vela fica centralizada em cima do kart e
## as quatro cordas descem até a carroceria (duas na frente e duas atrás, uma de cada
## lado), sem passar pelo piloto: `fit_to` mede o kart e devolve onde pôr este nó.
## Usada no kart da corrida, no fantasma do contra-relógio e na tela de seleção.

const MODEL := preload("res://assets/models/asas/asa_delta.glb")
## Bico para cima (rad) além da inclinação do modelo: de trás, a câmera da corrida vê
## a vela por baixo em vez de quase de perfil. Mais que isso a asa deita para trás e,
## de lado, parece uma pipa rebocada.
const PITCH := 0.12
## Duração da abertura e do fechamento (s).
const OPEN_TIME := 0.4
const CLOSE_TIME := 0.2
## Fechada, a asa fica dobrada para trás deste ângulo (rad) e bem estreita.
const FOLDED_PITCH := 1.25
## Altura da base da asa acima do banco (m): a vela fica bem acima da cabeça do piloto.
const MOUNT_HEIGHT := 0.6
## Centro da vela em relação à base do modelo, já com a inclinação PITCH: a base vai
## este tanto para a frente para a vela ficar no meio do kart (m).
const SAIL_BACK := 0.37
## Onde as cordas prendem na carroceria: fração da largura do kart para cada lado, e
## fração do comprimento a partir da frente (cordas da frente) e de trás (de trás).
const ANCHOR_SIDE := 0.36
const ANCHOR_SIDE_BIKE := 0.14
const ANCHOR_FRONT := 0.3
const ANCHOR_REAR := 0.15

## Um material por textura, dividido entre todos os karts (um shader só).
static var _materials := {}

var data: GliderData
## 0 = fechada (escondida), 1 = aberta.
var openness := 0.0
## Bico para cima extra (rad), pedido pelo kart ao frear no ar.
var lift := 0.0
## Balanço no ar (0 = parada, como na tela de seleção; 1 = voando).
var sway := 1.0

var _opening := false
var _model: Node3D
var _time := 0.0
## Cordas: o nó, a ponta de cima (espaço do modelo), a ponta de baixo como veio no
## modelo (relativa à de cima) e onde ela prende no kart (espaço deste nó; sem kart,
## onde o modelo a deixava).
var _cords: Array[MeshInstance3D] = []
var _cord_tops: Array[Vector3] = []
var _cord_bottoms: Array[Vector3] = []
var _anchors: Array[Vector3] = []


func setup(d: GliderData) -> void:
	data = d
	for child in get_children():
		child.queue_free()
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	var mat := material_for(d)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = mat
	# As cordas saem do modelo (que gira e encolhe na abertura) e ficam neste nó: cada
	# uma é esticada da vela até o ponto dela no kart a cada quadro (veja _aim_cords).
	_cords.clear()
	_cord_tops.clear()
	_cord_bottoms.clear()
	_anchors.clear()
	for node in _model.find_children("Corda*", "MeshInstance3D", true, false):
		var cord := node as MeshInstance3D
		var top := cord.position
		var bottom := Vector3.ZERO
		var faces := cord.mesh.get_faces()
		for p in faces:
			if p.y < bottom.y:
				bottom = p
		cord.get_parent().remove_child(cord)
		add_child(cord)
		_cords.append(cord)
		_cord_tops.append(top)
		_cord_bottoms.append(bottom)
		_anchors.append(top + bottom)
	_time = randf() * 10.0
	_apply()


## O material da asa `d` (o mesmo objeto para todos que usam a mesma textura).
static func material_for(d: GliderData) -> StandardMaterial3D:
	var tex: Texture2D = d.texture if d else null
	var key := tex.resource_path if tex else ""
	var cached: StandardMaterial3D = _materials.get(key)
	if cached:
		return cached
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.85
	m.metallic_specular = 0.3
	# A vela tem duas camadas e as peças da moldura são finas: as duas faces aparecem.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = m
	return m


static func clear_cache() -> void:
	_materials.clear()


## Mede o kart de `kv` (só a carroceria, sem o piloto) e prende as cordas nele.
## Devolve onde pôr este nó no espaço do KartVisual (frente = -Z): a vela fica no meio
## do kart, acima da cabeça do piloto. Chame depois de `setup`.
func fit_to(kv: KartVisual) -> Vector3:
	var b := kart_bounds(kv)
	var seat := kv.kart_data.seat_position if kv.kart_data else Vector3(0.0, 0.33, 0.3)
	var mount := Vector3(0.0, seat.y + MOUNT_HEIGHT, b.get_center().z - SAIL_BACK)
	# Pontos da carroceria: em cima das laterais, na frente e atrás do piloto. Numa moto
	# a caixa inclui o guidão: as cordas prendem rente ao corpo dela.
	var bike := kv.kart_data != null and kv.kart_data.turn_lean_degrees > 0.0
	var side := b.size.x * (ANCHOR_SIDE_BIKE if bike else ANCHOR_SIDE)
	var y := clampf(seat.y + 0.12, b.position.y + b.size.y * 0.25, b.end.y)
	var front := b.position.z + b.size.z * ANCHOR_FRONT
	var rear := b.end.z - b.size.z * ANCHOR_REAR
	for i in _cords.size():
		var top := _cord_tops[i]
		var anchor := Vector3(side * signf(top.x), y, front if top.z < 0.0 else rear)
		_anchors[i] = anchor - mount
	_apply()
	return mount


## Caixa do kart (só a carroceria) no espaço do KartVisual.
static func kart_bounds(kv: KartVisual) -> AABB:
	var out := AABB()
	var first := true
	if kv.model:
		for node in kv.model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != null and n != kv:
				if n is Node3D:
					xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var box := xf * mi.get_aabb()
			out = box if first else out.merge(box)
			first = false
	if first:
		# Sem modelo: um kart padrão (2,4 m de comprimento).
		out = AABB(Vector3(-0.75, 0.0, -1.2), Vector3(1.5, 0.9, 2.4))
	return out


## Abre (true) ou fecha a asa. Com `instant`, sem animação.
func set_open(open: bool, instant := false) -> void:
	_opening = open
	if instant:
		openness = 1.0 if open else 0.0
	set_process(true)
	_apply()


func is_open() -> bool:
	return _opening


## Abertura fixa, sem animação própria (o fantasma refaz a abertura gravada).
func set_openness(k: float) -> void:
	_opening = true
	openness = clampf(k, 0.0, 1.0)
	set_process(false)
	_apply()


func _process(delta: float) -> void:
	_time += delta
	var target := 1.0 if _opening else 0.0
	if openness != target:
		openness = move_toward(openness, target, delta / (OPEN_TIME if _opening else CLOSE_TIME))
	elif not _opening:
		set_process(false)
	_apply()


func _apply() -> void:
	visible = openness > 0.001
	if _model == null or not visible:
		return
	var k := openness
	# Abrindo: passa um pouco do tamanho e volta (estalo do tecido). Fechando: encolhe.
	var e := _ease_out_back(k) if _opening else k * k * (3.0 - 2.0 * k)
	var s := Vector3(lerpf(0.12, 1.0, e), lerpf(0.35, 1.0, e), lerpf(0.5, 1.0, e))
	var wobble := sway * clampf(k, 0.0, 1.0)
	var pitch := lerpf(FOLDED_PITCH, PITCH, clampf(e, 0.0, 1.15)) + lift \
			+ sin(_time * 1.7) * 0.03 * wobble
	var roll := sin(_time * 2.3 + 0.7) * 0.035 * wobble
	_model.transform = Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)) * Basis.from_scale(s), Vector3.ZERO)
	_aim_cords()


## Estica cada corda da ponta dela na vela (que se mexe com o modelo) até o ponto dela
## no kart: gira a corda para apontar para lá e alonga só no comprimento (a espessura
## fica a mesma).
func _aim_cords() -> void:
	var m := _model.transform
	for i in _cords.size():
		var top := m * _cord_tops[i]
		var along := m.basis * _cord_bottoms[i]
		var target := _anchors[i] - top
		var length := along.length()
		if length < 0.001 or target.length() < 0.001:
			continue
		var a := along / length
		var f := target.length() / length
		# Alonga ao longo de `a` (x + (f-1)(a·x)a) e gira `a` até a direção do alvo.
		var stretch := Basis(Vector3.RIGHT + (f - 1.0) * a.x * a, Vector3.UP + (f - 1.0) * a.y * a,
				Vector3.BACK + (f - 1.0) * a.z * a)
		var turn := Basis(Quaternion(a, target / target.length()))
		_cords[i].transform = Transform3D(turn * stretch * m.basis, top)

static func _ease_out_back(t: float) -> float:
	var c1 := 1.9
	var c3 := c1 + 1.0
	var u := t - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u
