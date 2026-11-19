class_name ItemWings
extends Node3D
## Par de asinhas de penas (assets/textures/itens/asa.png) batendo: o envelope da
## Intimação e a Constituição da PEC dos Precatórios voam com elas. Cada asa é uma folha
## deitada (x = para fora, z = para trás) presa pelo ombro, que gira em volta do eixo do
## comprimento do item para bater. Malha e material são os mesmos para todas (um shader).

const TEX := preload("res://assets/textures/itens/asa.png")
## Proporção da textura (altura / largura) e onde fica o ombro nela (v, de cima).
const ASPECT := 0.75
const SHOULDER_V := 0.4

static var _material: StandardMaterial3D

## Batidas por segundo, amplitude (rad) e ângulo de repouso (rad, para cima).
var rate := 3.2
var swing := 0.55
var rest := 0.35
## 0 = recolhidas (dobradas junto ao corpo), 1 = abertas.
var open := 1.0
var _right: Node3D
var _left: Node3D
var _t := 0.0


## Monta as duas asas com `span` m de comprimento cada, presas a `half_width` m do meio.
func build(span: float, half_width: float) -> void:
	name = "Asas"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(span, span * ASPECT)
	# O ombro (borda de dentro, a SHOULDER_V da frente) fica no pivô.
	mesh.center_offset = Vector3(span * 0.5, 0.0, span * ASPECT * (0.5 - SHOULDER_V))
	mesh.material = _get_material()
	for side: float in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.name = "AsaDireita" if side > 0.0 else "AsaEsquerda"
		pivot.position = Vector3(half_width * side, 0.0, 0.0)
		# A esquerda é a direita espelhada.
		pivot.scale = Vector3(side, 1.0, 1.0)
		var wing := MeshInstance3D.new()
		wing.mesh = mesh
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(wing)
		add_child(pivot)
		if side > 0.0:
			_right = pivot
		else:
			_left = pivot
	flap(0.0)


## Avança a batida (chamado a cada passo de física).
func flap(delta: float) -> void:
	_t += delta
	var a := (rest + sin(_t * rate * TAU) * swing) * open + (1.0 - open) * 1.35
	# Recolhidas, as asas ficam em pé junto ao corpo. A esquerda é espelhada (escala x
	# negativa): o mesmo giro a levaria para baixo.
	_right.rotation.z = a
	_left.rotation.z = -a


static func _get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_texture = TEX
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_material.alpha_scissor_threshold = 0.5
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _material
