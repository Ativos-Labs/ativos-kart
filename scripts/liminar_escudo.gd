class_name LiminarEscudo
extends Node3D
## Liminar em 3D: o escudo-documento LIMINAR DEFERIDA aparece em cima do kart (sempre de
## frente para a câmera) enquanto uma onda verde sai dele e se espalha até `radius`. Tudo
## acompanha o kart (ele não para). ItemAttacks guarda um ou dois e cuida do efeito (o que
## a onda destrói).

const TEX := preload("res://assets/textures/itens/liminar.png")
## Tamanho do escudo (m), altura do meio dele acima do kart e quanto à frente (m): baixo e
## um pouco adiante, para caber na câmera de quem usou (ela vem atrás e mais baixa).
const SIZE := Vector2(1.0, 1.25)
const HEIGHT := 1.45
const AHEAD := 1.6
## Duração (s) da onda e do escudo na tela.
const WAVE_TIME := 0.5
const SHOW_TIME := 1.15

static var _shield_mesh: QuadMesh
static var _wave_mesh: CylinderMesh

var kart: Kart
## O escudo fica num pivô que acompanha a frente do kart (o resto só a posição dele).
var _pivot: Node3D
var _shield: MeshInstance3D
var _wave: MeshInstance3D
var _ring: MeshInstance3D
var _t := -1.0
var _radius := 10.0
var _tween: Tween


func build() -> void:
	name = "Liminar"
	top_level = true
	_pivot = Node3D.new()
	_pivot.name = "Frente"
	add_child(_pivot)
	_shield = MeshInstance3D.new()
	_shield.name = "Escudo"
	_shield.mesh = _get_shield_mesh()
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_shield)
	_wave = MeshInstance3D.new()
	_wave.name = "Onda"
	_wave.mesh = _get_wave_mesh()
	_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A faixa (2,4 m de altura, achatada pela escala) começa no chão.
	_wave.position.y = 0.66
	add_child(_wave)
	_ring = MeshInstance3D.new()
	_ring.name = "Anel"
	_ring.mesh = ImpugnacaoCalculadora.ring_mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.55, 1.0, 0.7, 0.7)
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	visible = false
	set_physics_process(false)


func is_busy() -> bool:
	return _t >= 0.0


## A liminar de `k`: a onda chega a `radius` m.
func play(k: Kart, radius: float) -> void:
	kart = k
	_radius = radius
	_t = 0.0
	_follow()
	visible = true
	_shield.visible = true
	_shield.position = Vector3(0.0, HEIGHT - 0.5, 0.0)
	_shield.scale = Vector3.ONE * 0.15
	_shield.transparency = 0.0
	_wave.visible = true
	_wave.scale = Vector3(1.0, 0.55, 1.0)
	_wave.transparency = 0.0
	_ring.visible = true
	_ring.scale = Vector3.ONE
	_ring.transparency = 0.0
	reset_physics_interpolation()
	for child: Node3D in [_pivot, _shield, _wave, _ring]:
		child.reset_physics_interpolation()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	# Escudo: pula, fica um pouco subindo e some encolhendo.
	_tween.tween_property(_shield, "scale", Vector3.ONE * 1.15, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_shield, "position:y", HEIGHT, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_shield, "scale", Vector3.ONE, 0.12).set_delay(0.2)
	_tween.tween_property(_shield, "position:y", HEIGHT + 0.2, SHOW_TIME - 0.3).set_delay(0.3)
	_tween.tween_property(_shield, "scale", Vector3.ONE * 0.2, 0.25).set_delay(SHOW_TIME - 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_shield, "transparency", 1.0, 0.25).set_delay(SHOW_TIME - 0.25)
	# Onda: um anel de luz em pé e outro no chão se abrindo.
	var wide := Vector3(radius, 1.0, radius)
	_tween.tween_property(_wave, "scale", Vector3(radius, 0.55, radius), WAVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_wave, "transparency", 1.0, WAVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_ring, "scale", wide * 1.15, WAVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_ring, "transparency", 1.0, WAVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		set_physics_process(false)
		return
	_t += delta
	_follow()
	if _t > WAVE_TIME:
		_wave.visible = false
		_ring.visible = false
	if _t >= SHOW_TIME:
		_t = -1.0
		visible = false
		set_physics_process(false)


func _follow() -> void:
	if kart and is_instance_valid(kart):
		global_position = kart.global_position + Vector3.UP * 0.1
		var f := kart.get_forward()
		_pivot.position = Vector3(f.x, 0.0, f.z) * AHEAD


## Mostra parado em `xf` (compilar os shaders atrás da tela de carregamento).
func prewarm(on: bool, xf := Transform3D.IDENTITY) -> void:
	visible = on
	if on:
		global_transform = xf
		_shield.visible = true
		_shield.scale = Vector3.ONE
		_shield.position = Vector3(0.0, HEIGHT, 0.0)
		_wave.visible = true
		_wave.scale = Vector3(3.0, 0.55, 3.0)
		_ring.visible = true
		_ring.scale = Vector3(3.0, 1.0, 3.0)
		for child: GeometryInstance3D in [_shield, _wave, _ring]:
			child.transparency = 0.0


static func _get_shield_mesh() -> QuadMesh:
	if _shield_mesh == null:
		_shield_mesh = QuadMesh.new()
		_shield_mesh.size = SIZE
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = TEX
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.billboard_keep_scale = true
		mat.no_depth_test = true
		mat.render_priority = 2
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_shield_mesh.material = mat
	return _shield_mesh


## Faixa de luz em pé (cilindro sem tampas, raio 1): verde clara embaixo, sumindo em
## cima.
static func _get_wave_mesh() -> CylinderMesh:
	if _wave_mesh == null:
		_wave_mesh = CylinderMesh.new()
		_wave_mesh.top_radius = 1.0
		_wave_mesh.bottom_radius = 1.0
		_wave_mesh.height = 2.4
		_wave_mesh.radial_segments = 40
		_wave_mesh.rings = 1
		_wave_mesh.cap_top = false
		_wave_mesh.cap_bottom = false
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.85, 1.0, 0.9, 0.0))
		gradient.set_color(1, Color(0.3, 0.95, 0.55, 0.6))
		gradient.add_point(0.75, Color(0.6, 1.0, 0.75, 0.4))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill_from = Vector2(0.0, 0.0)
		tex.fill_to = Vector2(0.0, 1.0)
		tex.width = 4
		tex.height = 64
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = tex
		_wave_mesh.material = mat
	return _wave_mesh
