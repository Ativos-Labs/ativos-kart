class_name CharacterPortrait
extends SubViewport
## Renderiza o rosto do personagem (animado: pisca e muda de expressão) numa
## textura, para a grade de seleção e o retrato do HUD.

var rig: CharacterRig
## Quadros por segundo do retrato (0 = todo quadro). O do HUD não precisa de 60: cada
## quadro dele desenha mais um personagem inteiro (e deforma a malha dele).
var update_fps := 0.0
var _since_update := 0.0


func setup(data: CharacterData, pixels := 192, fps := 0.0) -> void:
	size = Vector2i(pixels, pixels)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	update_fps = fps
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if fps <= 0.0 else SubViewport.UPDATE_ONCE
	set_process(fps > 0.0)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.5, 0.45, 0.0)
	key.light_energy = 1.1
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI - 0.6, 0.0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.75, 0.85, 1.0)
	add_child(rim)

	var camera := Camera3D.new()
	camera.fov = 30.0
	add_child(camera)
	camera.position = Vector3(0.0, 1.42, 2.75)
	camera.rotation = Vector3(-0.03, 0.0, 0.0)
	camera.current = true

	rig = data.instantiate_rig()
	rig.setup_stand(1.0)
	add_child(rig)


func _process(delta: float) -> void:
	_since_update += delta
	if _since_update >= 1.0 / update_fps:
		_since_update = fmod(_since_update, 1.0 / update_fps)
		render_target_update_mode = SubViewport.UPDATE_ONCE
