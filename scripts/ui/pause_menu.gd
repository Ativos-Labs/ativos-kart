class_name PauseMenu
extends CanvasLayer
## Menu de pausa (Esc / P / Start). A música fica baixinha enquanto ele está aberto.
##
## No multijogador só quem abriu a pausa mexe nela (e nos painéis de Controles e
## Opções): os eventos dos outros aparelhos param no `_InputGate` antes da interface,
## e uma etiqueta ao lado do título mostra quem pausou ("J2 pausou").

signal resume_requested
signal restart_requested
signal menu_requested

## A corrida liga/desliga a possibilidade de pausar.
var can_pause := true
## Jogadores da corrida (a corrida preenche). Com mais de um, a pausa fica com quem
## a abriu.
var players: Array[PlayerSlot] = []

## Aparelho de quem abriu a pausa (PlayerSlot: id do controle ou DEVICE_KEYBOARD);
## DEVICE_ALL = qualquer um (jogando sozinho ou pausa automática).
var _owner := PlayerSlot.DEVICE_ALL
var _owner_tag: PlayerTag

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
@onready var title: Control = $Root/Title


## Barra os eventos de quem não abriu a pausa. É o último filho do menu: o `_input`
## anda do fim da árvore para o começo, então ele roda antes do `_input` dos painéis
## (o de Opções escuta a tecla nova por ali) e antes da interface (foco e botões).
class _InputGate:
	extends Node

	func _input(event: InputEvent) -> void:
		var menu_input := GameState.menu_input
		if (get_parent() as CanvasLayer).visible and menu_input and not menu_input.accepts(event):
			get_viewport().set_input_as_handled()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(_InputGate.new())
	# Logo depois do título (por baixo dos painéis de Controles e Opções).
	_owner_tag = PlayerTag.new()
	_owner_tag.position = Vector2(title.position.x + title.size.x + 20.0, title.position.y + (title.size.y - 50.0) * 0.5)
	_owner_tag.hide()
	title.add_sibling(_owner_tag)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
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
			open(PlayerSlot.event_device(event))
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


## Abre a pausa. `device` é o aparelho de quem pausou: no multijogador só ele mexe
## nela até fechar. Sem aparelho (pausa automática), qualquer um mexe.
func open(device := PlayerSlot.DEVICE_ALL) -> void:
	_set_owner(device if players.size() > 1 else PlayerSlot.DEVICE_ALL)
	visible = true
	get_tree().paused = true
	GameState.music.set_ducked(true)
	Sfx.play(self, &"ui_accept", -12.0)
	var mat := checker.material as ShaderMaterial
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if mat:
		tw.tween_method(func(v: float): mat.set_shader_parameter("reveal", v), 0.0, 1.0, 0.3)
	var delay := 0.05
	_owner_tag.modulate.a = 0.0
	create_tween().tween_property(_owner_tag, "modulate:a", 1.0, 0.2)
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
	_set_owner(PlayerSlot.DEVICE_ALL)
	get_tree().paused = false
	GameState.music.set_ducked(false)
	resume_requested.emit()


func _exit_tree() -> void:
	# Saiu da corrida com a pausa aberta (Reiniciar, Menu principal): solta os menus.
	if _owner != PlayerSlot.DEVICE_ALL and GameState.menu_input:
		GameState.menu_input.exclusive_device = PlayerSlot.DEVICE_ALL


func _set_owner(device: int) -> void:
	_owner = device
	if GameState.menu_input:
		GameState.menu_input.exclusive_device = device
	var slot: PlayerSlot = null
	for p in players:
		if device != PlayerSlot.DEVICE_ALL and p.device == device:
			slot = p
	_owner_tag.visible = slot != null
	if slot:
		_owner_tag.setup_slot(slot, "pausou")


## Desconectou o controle de quem pausou: qualquer um volta a mexer (senão ninguém
## conseguiria sair da pausa).
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and visible and device == _owner:
		_set_owner(PlayerSlot.DEVICE_ALL)
