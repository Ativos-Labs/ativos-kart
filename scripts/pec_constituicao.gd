class_name PecConstituicao
extends Node3D
## PEC dos Precatórios em 3D (ItemAttacks a move): uma Constituição gigante (livro de
## 4 x 5,4 m, capa azul com letras douradas e um post-it "PEC DOS PRECATÓRIOS") voando
## alto com asas de penas. Em cima do líder ela para, as asas recolhem e ela cai de
## chapa. O topo da capa fica na frente (-z): da câmera de trás o título aparece em pé.

const COVER_TEX := preload("res://assets/textures/itens/constituicao_capa.png")
const PAGES_TEX := preload("res://assets/textures/itens/paginas.png")
## Tamanho do livro (m): largura, grossura e comprimento.
const SIZE := Vector3(4.0, 0.9, 5.4)
const COVER := 0.12

static var _parts: Array = []

var wings: ItemWings
var _model: Node3D
var _t := 0.0


func build() -> void:
	name = "Constituicao"
	_model = Node3D.new()
	_model.name = "Modelo"
	add_child(_model)
	for part: Array in _get_parts():
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		mi.transform = part[2]
		_model.add_child(mi)
	wings = ItemWings.new()
	wings.rate = 1.6
	wings.swing = 0.5
	wings.rest = 0.3
	_model.add_child(wings)
	wings.build(3.4, SIZE.x * 0.5)
	visible = false


## Bate as asas e balança. `tilt` (rad) inclina o bico (para baixo na queda).
func fly(delta: float, tilt := 0.0) -> void:
	_t += delta
	wings.flap(delta)
	_model.rotation = Vector3(tilt + 0.06 * sin(_t * 2.2), 0.0, 0.08 * sin(_t * 1.7))


## 1 = asas abertas, 0 = recolhidas (na queda).
func set_open(value: float) -> void:
	wings.open = value


func reset() -> void:
	_t = 0.0
	wings.open = 1.0
	_model.scale = Vector3.ONE
	fly(0.0)


## Achata um pouco ao bater no chão e volta.
func slam() -> void:
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_model.scale = Vector3(1.08, 0.6, 1.08)
	tw.tween_property(_model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Peças do livro: capas, páginas, lombada (à esquerda) e a arte da capa.
static func _get_parts() -> Array:
	if not _parts.is_empty():
		return _parts
	# Um pouco de brilho próprio: voando alto, ela é vista por baixo, na sombra.
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color("1d3a8a")
	blue.roughness = 0.55
	blue.emission_enabled = true
	blue.emission = Color("1d3a8a")
	blue.emission_energy_multiplier = 0.6
	var pages := StandardMaterial3D.new()
	pages.albedo_texture = PAGES_TEX
	pages.uv1_triplanar = true
	pages.uv1_scale = Vector3(0.5, 1.4, 0.5)
	pages.roughness = 0.9
	var art := StandardMaterial3D.new()
	art.albedo_texture = COVER_TEX
	art.roughness = 0.6
	art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	art.emission_enabled = true
	art.emission_texture = COVER_TEX
	art.emission_energy_multiplier = 0.25
	var cover := BoxMesh.new()
	cover.size = Vector3(SIZE.x + 0.1, COVER, SIZE.z + 0.1)
	var block := BoxMesh.new()
	block.size = Vector3(SIZE.x - 0.1, SIZE.y - COVER * 2.0, SIZE.z - 0.1)
	var spine := BoxMesh.new()
	spine.size = Vector3(0.16, SIZE.y, SIZE.z + 0.1)
	var face := PlaneMesh.new()
	face.size = Vector2(SIZE.x, SIZE.z)
	var half := (SIZE.y - COVER) * 0.5
	_parts = [
		[cover, blue, Transform3D(Basis.IDENTITY, Vector3(0.0, half, 0.0))],
		[cover, blue, Transform3D(Basis.IDENTITY, Vector3(0.0, -half, 0.0))],
		[block, pages, Transform3D(Basis.IDENTITY, Vector3(0.06, 0.0, 0.0))],
		[spine, blue, Transform3D(Basis.IDENTITY, Vector3(-SIZE.x * 0.5 - 0.02, 0.0, 0.0))],
		[face, art, Transform3D(Basis.IDENTITY, Vector3(0.0, SIZE.y * 0.5 + 0.005, 0.0))],
		# Contracapa (vista de baixo, voando): a mesma arte virada para baixo (girada no
		# eixo do comprimento, para ler sem espelhar de baixo).
		[face, art, Transform3D(Basis(Vector3.BACK, PI), Vector3(0.0, -SIZE.y * 0.5 - 0.005, 0.0))],
	]
	return _parts
