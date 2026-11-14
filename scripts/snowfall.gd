class_name Snowfall
extends GPUParticles3D
## Neve caindo em volta da câmera (cenário de neve). Os flocos ficam no mundo; só
## o lugar onde eles nascem acompanha a câmera.

const AREA := 46.0

## Câmera que a neve acompanha (vazio = a câmera da tela). Na tela dividida cada
## jogador ganha uma neve que segue a câmera dele.
var target_camera: Camera3D


func _ready() -> void:
	amount = 2600
	lifetime = 9.0
	preprocess = 9.0
	local_coords = false
	fixed_fps = 30
	visibility_aabb = AABB(Vector3(-80, -60, -80), Vector3(160, 90, 160))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(AREA, 2.0, AREA)
	pm.direction = Vector3(0.15, -1.0, 0.05)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0.0, -0.6, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	process_material = pm
	var flake := QuadMesh.new()
	flake.size = Vector2(0.11, 0.11)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	mat.albedo_texture = _flake_texture()
	flake.material = mat
	draw_pass_1 = flake
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var cam := target_camera if is_instance_valid(target_camera) else null
	if cam == null:
		cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		global_position = cam.global_position + Vector3.UP * 16.0 - cam.global_basis.z * 14.0


## Bolinha macia (círculo com borda suave).
static func _flake_texture() -> ImageTexture:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) * 1.4))
	return ImageTexture.create_from_image(img)
