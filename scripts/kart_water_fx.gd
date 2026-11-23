class_name KartWaterFx
extends Node3D
## Efeitos de água de um kart: bolhas saindo de trás enquanto ele anda submerso e um
## respingo (gotas para cima e um anel) quando ele entra ou sai da água.

const BUBBLE_SHADER := preload("res://shaders/bubble.gdshader")

var bubbles: GPUParticles3D
var splash: GPUParticles3D

static var _bubble_mat: ShaderMaterial
static var _drop_mat: ShaderMaterial
static var _bubble_process: ParticleProcessMaterial
static var _splash_process: ParticleProcessMaterial


func _init() -> void:
	name = "Agua"
	_make_shared()
	bubbles = GPUParticles3D.new()
	bubbles.name = "Bolhas"
	bubbles.amount = 18
	bubbles.lifetime = 1.6
	bubbles.local_coords = false
	bubbles.emitting = false
	bubbles.process_material = _bubble_process
	bubbles.draw_pass_1 = _quad(_bubble_mat)
	bubbles.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 10, 8))
	bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bubbles)
	splash = GPUParticles3D.new()
	splash.name = "Respingo"
	splash.amount = 46
	splash.lifetime = 1.0
	splash.one_shot = true
	splash.explosiveness = 0.92
	splash.local_coords = false
	splash.emitting = false
	splash.process_material = _splash_process
	splash.draw_pass_1 = _quad(_drop_mat)
	splash.top_level = true
	splash.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 10, 12))
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(splash)


static func _make_shared() -> void:
	if _bubble_mat:
		return
	_bubble_mat = ShaderMaterial.new()
	_bubble_mat.shader = BUBBLE_SHADER
	_drop_mat = ShaderMaterial.new()
	_drop_mat.shader = BUBBLE_SHADER
	_drop_mat.set_shader_parameter("drop", true)
	_drop_mat.set_shader_parameter("tint", Color(0.86, 0.96, 1.0, 0.9))
	var b := ParticleProcessMaterial.new()
	b.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	b.emission_box_extents = Vector3(0.25, 0.08, 0.15)
	b.direction = Vector3(0.0, 1.0, 0.4)
	b.spread = 30.0
	b.initial_velocity_min = 0.6
	b.initial_velocity_max = 1.6
	b.gravity = Vector3(0.0, 2.6, 0.0)
	b.damping_min = 0.6
	b.damping_max = 1.2
	b.scale_min = 0.05
	b.scale_max = 0.16
	b.turbulence_enabled = false
	_bubble_process = b
	var s := ParticleProcessMaterial.new()
	s.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	s.emission_ring_axis = Vector3.UP
	s.emission_ring_radius = 0.7
	s.emission_ring_inner_radius = 0.3
	s.emission_ring_height = 0.05
	s.direction = Vector3(0.0, 1.0, 0.0)
	s.spread = 38.0
	s.initial_velocity_min = 3.0
	s.initial_velocity_max = 6.5
	s.gravity = Vector3(0.0, -14.0, 0.0)
	s.scale_min = 0.08
	s.scale_max = 0.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	s.color_ramp = ramp
	_splash_process = s


static func _quad(material: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = material
	return q


## Liga/desliga as bolhas (kart submerso).
func set_underwater(on: bool) -> void:
	if bubbles.emitting != on:
		bubbles.emitting = on


## Respingo em `at` (global), na superfície da água.
func burst(at: Vector3) -> void:
	splash.global_position = at
	splash.restart()
	splash.emitting = true


## Para os shaders compilarem atrás da tela de carregamento (Race.warm_up).
func prewarm(on: bool) -> void:
	for p: GPUParticles3D in [bubbles, splash]:
		if on:
			p.emitting = true
		else:
			p.restart()
			p.emitting = false
