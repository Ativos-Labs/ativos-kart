class_name ImpugnacaoCalculadora
extends Node3D
## Impugnação dos cálculos em 3D (ItemAttacks a joga e conta o tempo): uma calculadora
## grande deitada na pista, com a frente levantada para quem vem atrás. O visor mostra a
## contagem (3, 2, 1, "ERRO"), o LED vermelho pisca a cada apito e um anel vermelho no
## chão marca até onde a explosão pega. Ao estourar: clarão, onda no chão e uma chuva de
## números (algarismos, "%", "R$" e sinais) voando para todo lado.
## O nó fica no chão, com -z no sentido da corrida (o visor fica na frente).

const FACE_TEX := preload("res://assets/textures/itens/calculadora.png")
const NUMBERS_TEX := preload("res://assets/textures/itens/numeros.png")
## Tamanho (m, proporção da textura 384 x 544), inclinação da frente (rad).
const SIZE := Vector3(0.9, 0.16, 0.9 * 544.0 / 384.0)
const TILT := 0.35
## Chuva de números: quantos e por quanto tempo (s).
const NUMBERS := 44
const NUMBERS_TIME := 1.8

static var _parts: Array = []
static var _ring_mesh: ArrayMesh
static var _danger_mat: StandardMaterial3D
static var _wave_mat: StandardMaterial3D
static var _flash_mesh: SphereMesh
static var _numbers_process: ParticleProcessMaterial
static var _numbers_mesh: QuadMesh

var _model: Node3D
var _display: Label3D
var _led: MeshInstance3D
var _danger: MeshInstance3D
var _wave: MeshInstance3D
var _flash: MeshInstance3D
var _numbers: GPUParticles3D
var _hop: Tween
var _led_tween: Tween
var _boom: Tween
var _radius := 7.0


func build(blast_radius: float) -> void:
	name = "Calculadora"
	_radius = blast_radius
	_model = Node3D.new()
	_model.name = "Modelo"
	add_child(_model)
	for part: Array in _get_parts():
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		mi.transform = part[2]
		_model.add_child(mi)
		if part.size() > 3:
			_led = mi
	_display = Label3D.new()
	_display.name = "Visor"
	_display.font = UiKit.FONT_TITLE
	_display.font_size = 96
	_display.pixel_size = 0.0017
	_display.modulate = Color("26301f")
	_display.outline_size = 0
	_display.shaded = false
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Deitado na frente da calculadora, no visor (o topo do texto para a frente).
	_display.rotation.x = -PI * 0.5
	_display.position = Vector3(SIZE.x * 0.38, SIZE.y * 0.5 + 0.004, -SIZE.z * (0.5 - 0.165))
	_model.add_child(_display)
	_make_shared()
	_danger = _ring(_danger_mat, "AnelPerigo")
	_wave = _ring(_wave_mat, "Onda")
	_flash = MeshInstance3D.new()
	_flash.name = "Clarao"
	_flash.mesh = _flash_mesh
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	add_child(_flash)
	_numbers = GPUParticles3D.new()
	_numbers.name = "ChuvaDeNumeros"
	_numbers.amount = NUMBERS
	_numbers.lifetime = NUMBERS_TIME
	_numbers.one_shot = true
	_numbers.explosiveness = 0.9
	_numbers.emitting = false
	_numbers.process_material = _numbers_process
	_numbers.draw_pass_1 = _numbers_mesh
	_numbers.position = Vector3(0.0, 0.8, 0.0)
	_numbers.visibility_aabb = AABB(Vector3(-14.0, -4.0, -14.0), Vector3(28.0, 20.0, 28.0))
	_numbers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_numbers)
	visible = false


## Pronta para ser jogada: modelo inteiro, visor `text`, anel de perigo aceso.
func arm(text: String) -> void:
	_kill(_boom)
	_kill(_hop)
	visible = true
	_model.visible = true
	_model.position = Vector3(0.0, _rest_height(), 0.0)
	_model.rotation = Vector3(TILT, 0.0, 0.0)
	_display.text = text
	_led.visible = false
	_danger.visible = false
	_wave.visible = false
	_flash.visible = false


## No ar (jogada): gira um pouco; o anel só aparece no chão.
func tumble(delta: float) -> void:
	_model.rotation.x += delta * 9.0


## Pousou: deita com a frente levantada e acende o anel de perigo.
func land() -> void:
	_model.rotation = Vector3(TILT, 0.0, 0.0)
	_model.position = Vector3(0.0, _rest_height(), 0.0)
	_danger.visible = true
	_danger.scale = Vector3(_radius, 1.0, _radius)
	_danger.transparency = 0.55


## Um apito: o visor mostra `text`, o LED pisca, a calculadora pula e o anel brilha.
func beep(text: String) -> void:
	_display.text = text
	_kill(_led_tween)
	_led.visible = true
	_led_tween = _new_tween()
	_led_tween.tween_interval(0.12)
	_led_tween.tween_callback(_led.hide)
	if _danger.visible:
		_danger.transparency = 0.1
		_led_tween.parallel().tween_property(_danger, "transparency", 0.55, 0.3)
	_kill(_hop)
	_hop = _new_tween()
	var rest := _rest_height()
	_hop.tween_property(_model, "position:y", rest + 0.14, 0.07).set_ease(Tween.EASE_OUT)
	_hop.tween_property(_model, "position:y", rest, 0.1).set_ease(Tween.EASE_IN)


## Estoura: some a calculadora; clarão, onda no chão e a chuva de números. Termina em
## NUMBERS_TIME s (depois disso pode ser jogada de novo).
func explode() -> void:
	_kill(_hop)
	_kill(_led_tween)
	_model.visible = false
	_danger.visible = false
	_numbers.restart()
	_flash.visible = true
	_flash.scale = Vector3.ONE * 0.4
	_flash.transparency = 0.15
	_wave.visible = true
	_wave.scale = Vector3.ONE
	_wave.transparency = 0.0
	_kill(_boom)
	_boom = _new_tween().set_parallel()
	# Clarão curto e menor que o alcance (senão vira uma cúpula e esconde os números).
	_boom.tween_property(_flash, "scale", Vector3.ONE * _radius * 0.4, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_boom.tween_property(_flash, "transparency", 1.0, 0.18).set_delay(0.03)
	_boom.tween_property(_wave, "scale", Vector3(_radius * 1.15, 1.0, _radius * 1.15), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_boom.tween_property(_wave, "transparency", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_boom.chain().tween_callback(_flash.hide)
	_boom.chain().tween_callback(_wave.hide)


## Some de vez (volta para a reserva).
func park() -> void:
	_kill(_boom)
	_kill(_hop)
	_kill(_led_tween)
	_numbers.emitting = false
	visible = false


## Mostra tudo parado (compila os shaders atrás da tela de carregamento).
func prewarm(on: bool) -> void:
	if on:
		arm("3")
		land()
		_led.visible = true
		_flash.visible = true
		_flash.scale = Vector3.ONE * 0.5
		_flash.transparency = 0.6
		_wave.visible = true
		_wave.transparency = 0.5
		_numbers.restart()
	else:
		park()


func _rest_height() -> float:
	# Girada em volta do meio, a traseira desce: sobe o modelo até ela encostar no chão.
	return SIZE.z * 0.5 * sin(TILT) + SIZE.y * 0.5 * cos(TILT)


func _ring(mat: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _ring_mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.07
	mi.visible = false
	add_child(mi)
	return mi


func _new_tween() -> Tween:
	return create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)


static func _kill(tw: Tween) -> void:
	if tw:
		tw.kill()


## Anel deitado de raio 1 (de 0,86 a 1), para o perigo e a onda.
static func ring_mesh() -> ArrayMesh:
	if _ring_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments := 48
		for i in segments:
			var a0 := TAU * i / segments
			var a1 := TAU * (i + 1) / segments
			var o0 := Vector3(cos(a0), 0.0, sin(a0))
			var o1 := Vector3(cos(a1), 0.0, sin(a1))
			for v: Vector3 in [o0 * 0.86, o0, o1, o0 * 0.86, o1, o1 * 0.86]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		_ring_mesh = st.commit()
	return _ring_mesh


static func _make_shared() -> void:
	if _danger_mat:
		return
	ring_mesh()
	_danger_mat = _unshaded(Color(1.0, 0.18, 0.12, 0.9))
	_wave_mat = _unshaded(Color(1.0, 0.95, 0.8, 0.9))
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = 1.0
	_flash_mesh.height = 2.0
	_flash_mesh.radial_segments = 16
	_flash_mesh.rings = 8
	_flash_mesh.material = _unshaded(Color(1.0, 0.95, 0.7, 0.8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0.0, -16.0, 0.0)
	pm.damping_min = 1.0
	pm.damping_max = 2.5
	pm.scale_min = 0.6
	pm.scale_max = 1.25
	pm.angle_min = -35.0
	pm.angle_max = 35.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 0.999
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colors.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	colors.colors = PackedColorArray([Color("ffffff"), Color("ffd21a"), Color("5ce08a"), Color("6fd0ff"), Color("ff7a5c")])
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = colors
	pm.color_initial_ramp = color_tex
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	_numbers_process = pm
	_numbers_mesh = QuadMesh.new()
	_numbers_mesh.size = Vector2(0.85, 0.85)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = NUMBERS_TEX
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 4
	mat.particles_anim_loop = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_numbers_mesh.material = mat


static func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	return mat


## Peças: corpo, frente com as teclas e o LED (o 4º item marca o LED).
static func _get_parts() -> Array:
	if not _parts.is_empty():
		return _parts
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("343a48")
	body_mat.roughness = 0.5
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_texture = FACE_TEX
	face_mat.roughness = 0.45
	face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color = Color(1.0, 0.15, 0.1)
	led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := BoxMesh.new()
	body.size = SIZE
	var face := PlaneMesh.new()
	face.size = Vector2(SIZE.x, SIZE.z)
	var led := SphereMesh.new()
	led.radius = 0.05
	led.height = 0.1
	led.radial_segments = 8
	led.rings = 4
	_parts = [
		[body, body_mat, Transform3D.IDENTITY],
		[face, face_mat, Transform3D(Basis.IDENTITY, Vector3(0.0, SIZE.y * 0.5 + 0.002, 0.0))],
		[led, led_mat, Transform3D(Basis.IDENTITY, Vector3(SIZE.x * 0.4, SIZE.y * 0.5 + 0.03, -SIZE.z * 0.47)), true],
	]
	return _parts
