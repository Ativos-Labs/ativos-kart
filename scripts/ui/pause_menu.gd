class_name PauseMenu
extends CanvasLayer
## Menu de pausa (Esc / P / Start). A música fica baixinha enquanto ele está aberto.

signal resume_requested
signal restart_requested
signal menu_requested

## A corrida liga/desliga a possibilidade de pausar.
var can_pause := true

@onready var checker: ColorRect = %Checker
@onready var buttons: VBoxContainer = %Buttons
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton
@onready var controls_button: Button = %ControlsButton
@onready var options_button: Button = %OptionsButton
@onready var menu_button: Button = %MenuButton
@onready var controls_panel: ControlsPanel = %ControlsPanel
@onready var options_panel: OptionsPanel = %OptionsPanel
@onready var info_label: Label = %InfoLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	continue_button.pressed.connect(close)
	restart_button.pressed.connect(func(): restart_requested.emit())
	controls_button.pressed.connect(controls_panel.open)
	controls_panel.closed.connect(controls_button.grab_focus)
	options_button.pressed.connect(options_panel.open)
	options_panel.closed.connect(options_button.grab_focus)
	menu_button.pressed.connect(func(): menu_requested.emit())
	var character := GameState.get_selected_character()
	info_label.text = "%s  •  %s  •  %d voltas" % [
		character.display_name if character else "-",
		GameState.get_selected_kart().display_name,
		GameState.laps,
	]


## Linha de informação embaixo dos botões (modo, piloto, voltas...).
func set_info(text: String) -> void:
	info_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa"):
		if visible:
			close()
		elif can_pause:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Na web, trocar de aba ou clicar fora do jogo pausa a corrida: o navegador
	# congela a aba escondida e, na volta, o kart seguiria andando sem controle.
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT] \
			and OS.has_feature("web") and can_pause and not visible and is_node_ready():
		open()


func open() -> void:
	visible = true
	get_tree().paused = true
	GameState.music.set_ducked(true)
	Sfx.play(self, &"ui_accept", -12.0)
	var mat := checker.material as ShaderMaterial
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if mat:
		tw.tween_method(func(v: float): mat.set_shader_parameter("reveal", v), 0.0, 1.0, 0.3)
	var delay := 0.05
	for b in buttons.get_children():
		b.modulate.a = 0.0
		var bt := create_tween()
		bt.tween_interval(delay)
		bt.tween_property(b, "modulate:a", 1.0, 0.15)
		delay += 0.05
	continue_button.grab_focus()


func close() -> void:
	controls_panel.hide()
	if options_panel.visible:
		options_panel.close()
	visible = false
	get_tree().paused = false
	GameState.music.set_ducked(false)
	resume_requested.emit()
