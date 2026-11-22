extends Node3D
## Tela inicial: o piloto escolhido no kart parado no grid de largada, câmera girando
## em volta, painel quadriculado com logo e botões, e a janela de controles.

@onready var track: Track = $Pista
@onready var camera: Camera3D = $Camera
@onready var showcase: Node3D = $Vitrine
@onready var checker: ColorRect = %Checker
@onready var title_box: Control = %TitleBox
@onready var kart_banner: Control = %KartBanner
@onready var menu_box: Control = %MenuBox
@onready var play_button: Button = %PlayButton
@onready var controls_button: Button = %ControlsButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var controls_panel: ControlsPanel = %ControlsPanel
@onready var options_panel: OptionsPanel = %OptionsPanel
@onready var record_label: Label = %RecordLabel
@onready var driver_label: Label = %DriverLabel

## Quanto a câmera do menu chega mais perto do kart parado no grid (o enquadramento era
## dos karts de antes do encaixe piloto × kart).
const MENU_ZOOM := 0.6
var _kart: KartVisual
var _time := 0.0
var _wave_timer := 2.5


func _ready() -> void:
	play_button.pressed.connect(func(): GameState.goto_scene(GameState.SCENE_MODE_SELECT))
	controls_button.pressed.connect(controls_panel.open)
	controls_panel.closed.connect(controls_button.grab_focus)
	options_button.pressed.connect(options_panel.open)
	options_panel.closed.connect(options_button.grab_focus)
	quit_button.pressed.connect(GameState.quit)
	if OS.has_feature("web"):
		quit_button.hide()
	GameState.music.play(&"menu")

	# Kart com o piloto parado no grid de largada.
	var character := GameState.get_selected_character()
	_kart = KartVisual.new()
	showcase.add_child(_kart)
	_kart.setup(GameState.get_selected_kart(), character)
	showcase.global_transform = track.global_transform * track.get_transform_at(-12.0, -3.0)

	record_label.text = GameState.format_time(GameState.get_record(track.track_id, "total"))
	driver_label.text = character.display_name if character else "-"

	camera.h_offset *= MENU_ZOOM
	_update_camera()
	camera.reset_physics_interpolation()
	play_button.grab_focus()
	_animate_intro()


func _process(delta: float) -> void:
	_time += delta
	_update_camera()
	if not is_instance_valid(_kart):
		return
	# O piloto mexe no volante, olha em volta e acena de vez em quando.
	var steer := sin(_time * 1.1) * 0.5 * clampf(sin(_time * 0.37) * 2.0, 0.0, 1.0)
	_kart.update_motion(delta, 0.0, steer, 0)
	_wave_timer -= delta
	if _wave_timer <= 0.0 and _kart.driver:
		_wave_timer = randf_range(5.0, 8.0)
		_kart.driver.play_gesture(&"gesture_wave", 1.4, 2)
		_kart.driver.set_face(&"face_happy", 1.5)


func _update_camera() -> void:
	# Perto do kart (do tamanho do encaixe piloto × kart, menor que os de antes).
	var center := showcase.global_position + Vector3.UP * 0.75 * MENU_ZOOM
	var forward := -showcase.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var angle := 0.55 + sin(_time * 0.13) * 0.75
	var offset := ((forward * cos(angle) + right * sin(angle)) * 5.4 + Vector3.UP * 1.25) * MENU_ZOOM
	camera.global_position = center + offset
	camera.look_at(center, Vector3.UP)


func _animate_intro() -> void:
	var mat := checker.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("reveal", 0.0)
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float): mat.set_shader_parameter("reveal", v), 0.0, 1.0, 0.55)
	await get_tree().process_frame
	# Botões entram deslizando da esquerda, um depois do outro.
	var delay := 0.15
	for button in menu_box.get_children():
		if not (button is Control) or not button.visible:
			continue
		var target_x: float = button.position.x
		button.position.x = target_x - 520.0
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(delay)
		tw.tween_property(button, "position:x", target_x, 0.4)
		delay += 0.08
	title_box.pivot_offset = title_box.size * 0.5
	title_box.scale = Vector2.ONE * 0.6
	title_box.modulate.a = 0.0
	var pop := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(title_box, "scale", Vector2.ONE, 0.5)
	pop.tween_property(title_box, "modulate:a", 1.0, 0.25)
	await pop.finished
	var bob := create_tween().set_loops()
	bob.tween_property(title_box, "position:y", title_box.position.y - 6.0, 1.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(title_box, "position:y", title_box.position.y, 1.4).set_trans(Tween.TRANS_SINE)
	kart_banner.pivot_offset = kart_banner.size * 0.5
	var wiggle := create_tween().set_loops()
	wiggle.tween_property(kart_banner, "rotation", deg_to_rad(-3.0), 0.9).set_trans(Tween.TRANS_SINE)
	wiggle.tween_property(kart_banner, "rotation", deg_to_rad(1.0), 0.9).set_trans(Tween.TRANS_SINE)
