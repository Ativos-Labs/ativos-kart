class_name PickStage
extends SubViewport
## Palco 3D de um jogador nas telas de escolha do multijogador (piloto, kart e asa-delta):
## um mundo 3D só dele, com as luzes de estúdio, o pedestal com o aro na cor do jogador
## e uma câmera que enquadra o que estiver em `turntable`, seja qual for o formato do
## cartão (o PickPanel mostra a textura desta SubViewport).

var turntable: Node3D
var camera: Camera3D

## O que tem de caber na imagem: centro e meia largura/altura (m), visto de cima com
## a inclinação `_pitch` (rad) a `_distance` m.
var _target := Vector3(0.0, 1.0, 0.0)
var _half := Vector2(1.2, 1.2)
var _pitch := 0.2
var _distance := 5.5


## `trim`: cor do aro do pedestal; `radius`: raio do pedestal (m). Chame depois de pôr
## na árvore (copia o antisserrilhado da janela).
func setup(trim: Color, radius: float) -> void:
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var main := get_tree().root
	msaa_3d = main.msaa_3d
	screen_space_aa = main.screen_space_aa
	use_debanding = main.use_debanding
	mesh_lod_threshold = main.mesh_lod_threshold

	var world := WorldEnvironment.new()
	world.environment = _studio_environment()
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0.0)
	key.light_energy = 1.15
	key.shadow_enabled = true
	# Palco pequeno: a sombra cobre só ele (mais nítida).
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 16.0
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.35, 2.7, 0.0)
	rim.light_color = Color(0.75, 0.88, 1.0)
	rim.light_energy = 0.9
	add_child(rim)

	var podium := CylinderMesh.new()
	podium.top_radius = radius
	podium.bottom_radius = radius * 0.88
	podium.height = 0.3
	podium.radial_segments = 48
	var podium_mat := StandardMaterial3D.new()
	podium_mat.albedo_color = Color(0.2, 0.27, 0.55)
	podium_mat.metallic = 0.2
	podium_mat.roughness = 0.3
	podium.material = podium_mat
	var base := MeshInstance3D.new()
	base.mesh = podium
	base.position.y = -0.15
	add_child(base)
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.04
	ring.outer_radius = radius + 0.07
	ring.rings = 48
	ring.ring_segments = 8
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = trim
	ring_mat.emission_enabled = true
	ring_mat.emission = trim
	ring_mat.emission_energy_multiplier = 0.3
	ring.material = ring_mat
	var trim_ring := MeshInstance3D.new()
	trim_ring.mesh = ring
	add_child(trim_ring)

	turntable = Node3D.new()
	turntable.name = "Giro"
	add_child(turntable)
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	size_changed.connect(_frame)
	_frame()


## Enquadra: `target` no meio da imagem, com `half_size` (meia largura e meia altura, m,
## na distância do alvo) sempre dentro dela, visto com a inclinação `pitch` (rad).
func frame(target: Vector3, half_size: Vector2, pitch: float, distance: float) -> void:
	_target = target
	_half = half_size
	_pitch = pitch
	_distance = distance
	_frame()


func _frame() -> void:
	if camera == null:
		return
	camera.rotation = Vector3(-_pitch, 0.0, 0.0)
	camera.position = _target + Vector3(0.0, sin(_pitch), cos(_pitch)) * _distance
	var aspect := float(size.x) / maxf(float(size.y), 1.0)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var t := maxf(_half.y, _half.x / aspect) / _distance
	camera.fov = rad_to_deg(2.0 * atan(t))


## O mesmo estúdio das telas de escolha de um jogador (céu só para a luz ambiente).
static func _studio_environment() -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.6, 0.72, 1.0)
	sky_mat.sky_horizon_color = Color(0.82, 0.86, 0.95)
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.5)
	sky_mat.ground_horizon_color = Color(0.55, 0.58, 0.72)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ssao_enabled = true
	env.ssao_radius = 0.5
	env.ssao_intensity = 1.4
	env.ssao_light_affect = 0.25
	return env
