class_name CarimboIndeferido
extends Node3D
## Carimbo INDEFERIDO em 3D (ItemAttacks o move): um carimbo de borracha voando baixo e
## girando — bolota vermelha no cabo, base de madeira com a etiqueta "INDEFERIDO" em
## cima e a borracha vermelha embaixo. Também faz a marca vermelha que fica estampada
## na traseira do kart atingido (make_mark), desenhada por cima dela como um adesivo.
## Malhas e materiais são os mesmos para todos.

const LABEL_TEX := preload("res://assets/textures/itens/carimbo_etiqueta.png")
const MARK_TEX := preload("res://assets/textures/itens/indeferido.png")
## Altura do centro do carimbo acima do chão (m) e giro (rad/s).
const HOVER := 0.55 * KartScale.ITEMS
const SPIN := 9.0
## Proporção da marca (altura / largura).
const MARK_ASPECT := 208.0 / 512.0

static var _parts: Array = []
static var _mark_mesh: QuadMesh

var _model: Node3D
var _t := 0.0
var _tween: Tween


func build() -> void:
	name = "Carimbo"
	_model = Node3D.new()
	_model.name = "Modelo"
	add_child(_model)
	for part: Array in _get_parts():
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		mi.transform = part[2]
		_model.add_child(mi)
	visible = false


## Gira e balança (chamado a cada passo de física enquanto voa).
func fly(delta: float) -> void:
	_t += delta
	_model.rotation = Vector3(0.14 * sin(_t * 7.0), _t * SPIN, 0.1 * cos(_t * 5.0))
	_model.position.y = sin(_t * 11.0) * 0.05


## Bateu na mureta: achata e volta.
func bump() -> void:
	if _tween:
		_tween.kill()
	_model.scale = Vector3(1.3, 0.7, 1.3)
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Volta ao começo (antes de ser jogado de novo).
func reset() -> void:
	if _tween:
		_tween.kill()
	_t = randf() * 3.0
	_model.scale = Vector3.ONE
	fly(0.0)


## A marca "INDEFERIDO" (um quadro com a tinta vermelha), para pôr atrás de um kart.
static func make_mark() -> MeshInstance3D:
	if _mark_mesh == null:
		_mark_mesh = QuadMesh.new()
		_mark_mesh.size = Vector2(1.0, MARK_ASPECT)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = MARK_TEX
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.9
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# Por cima da traseira do kart (escapamento, placa e rodas não a cortam); só a
		# frente do quadro é desenhada, então ela não aparece olhando o kart de frente.
		mat.no_depth_test = true
		mat.render_priority = 1
		_mark_mesh.material = mat
	var mark := MeshInstance3D.new()
	mark.name = "MarcaIndeferido"
	mark.mesh = _mark_mesh
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mark


## Peças do carimbo: [malha, material, posição]. Medidas em m; o centro do modelo fica
## no meio da base.
static func _get_parts() -> Array:
	if not _parts.is_empty():
		return _parts
	var wood := _material(Color("b9773f"), 0.7)
	var wood_dark := _material(Color("7a4520"), 0.6)
	var rubber := _material(Color("d8262c"), 0.85)
	var lacquer := _material(Color("a3161e"), 0.25)
	var label := StandardMaterial3D.new()
	label.albedo_texture = LABEL_TEX
	label.roughness = 0.8
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var base := BoxMesh.new()
	base.size = Vector3(0.9, 0.22, 0.6)
	var pad := BoxMesh.new()
	pad.size = Vector3(0.84, 0.08, 0.54)
	var top := PlaneMesh.new()
	top.size = Vector2(0.6, 0.375)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.085
	neck.bottom_radius = 0.11
	neck.height = 0.3
	neck.radial_segments = 12
	neck.rings = 1
	var knob := SphereMesh.new()
	knob.radius = 0.2
	knob.height = 0.34
	knob.radial_segments = 16
	knob.rings = 8
	_parts = [
		[base, wood, Transform3D(Basis.IDENTITY, Vector3.ZERO)],
		[pad, rubber, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.15, 0.0))],
		[top, label, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.112, 0.0))],
		[neck, wood_dark, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.26, 0.0))],
		[knob, lacquer, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0))],
	]
	return _parts


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat
