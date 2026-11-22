class_name IntimacaoEnvelope
extends Node3D
## Intimação em 3D (ItemAttacks o move): um envelope oficial em pé, voando com duas
## asinhas de penas. O verso (aba, lacre vermelho e "INTIMAÇÃO") fica virado para trás,
## para a câmera de quem jogou; a frente (PODER JUDICIÁRIO, destinatário, URGENTE) vai
## na direção do alvo. O nó olha para onde o envelope voa (-z).

const FRONT_TEX := preload("res://assets/textures/itens/intimacao_frente.png")
const BACK_TEX := preload("res://assets/textures/itens/intimacao_verso.png")
## Tamanho do envelope (m, proporção das texturas 512 x 352) e altura do centro acima do
## chão (m).
const SIZE := Vector2(1.1, 1.1 * 352.0 / 512.0)
const HOVER := 1.0 * KartScale.ITEMS

static var _front: QuadMesh
static var _back: QuadMesh

var wings: ItemWings
var _model: Node3D
var _t := 0.0


func build() -> void:
	name = "Envelope"
	_model = Node3D.new()
	_model.name = "Modelo"
	add_child(_model)
	_make_meshes()
	var back := MeshInstance3D.new()
	back.name = "Verso"
	back.mesh = _back
	back.position = Vector3(0.0, 0.0, 0.006)
	_model.add_child(back)
	var front := MeshInstance3D.new()
	front.name = "Frente"
	front.mesh = _front
	front.position = Vector3(0.0, 0.0, -0.006)
	front.rotation.y = PI
	_model.add_child(front)
	wings = ItemWings.new()
	wings.rate = 4.5
	wings.swing = 0.6
	wings.rest = 0.25
	_model.add_child(wings)
	wings.build(0.75, SIZE.x * 0.5 - 0.04)
	wings.position = Vector3(0.0, SIZE.y * 0.18, 0.0)
	visible = false


## Bate as asas e balança (chamado a cada passo de física enquanto voa).
func fly(delta: float) -> void:
	_t += delta
	wings.flap(delta)
	_model.position.y = sin(_t * 9.0) * 0.07
	_model.rotation = Vector3(0.08 * sin(_t * 4.0), 0.0, 0.12 * sin(_t * 3.1))


func reset() -> void:
	_t = randf() * 3.0
	fly(0.0)


static func _make_meshes() -> void:
	if _front:
		return
	_front = _quad(FRONT_TEX)
	_back = _quad(BACK_TEX)


static func _quad(tex: Texture2D) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.material = mat
	return mesh
