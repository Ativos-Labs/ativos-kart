extends Node3D
## Tela de seleção de kart: o kart com o piloto escolhido girando no palco,
## atributos (kart + piloto) e botões para voltar ou seguir para a escolha da asa-delta.
## No multijogador cada jogador escolhe na vez dele (etiqueta "J2" no topo).

@onready var turntable: Node3D = $Palco/Giro
@onready var name_label: Label = %KartName
@onready var counter_label: Label = %KartCounter
@onready var description_label: Label = %KartDescription
@onready var credits_label: Label = %KartCredits
@onready var driver_label: Label = %DriverName
@onready var driver_portrait: TextureRect = %DriverPortrait
@onready var stats: StatBars = %Stats
@onready var prev_button: ArrowButton = %PrevButton
@onready var next_button: ArrowButton = %NextButton
@onready var back_button: FancyButton = %BackButton
@onready var race_button: FancyButton = %RaceButton
@onready var toast: Label = %Toast
@onready var header: RibbonLabel = $UI/Root/Header

var index := 0
var _kart_visual: KartVisual
var _spin_pause := 0.0
var _dragging := false
var _nav_cooldown := 0.0
var _toast_tween: Tween
var _time := 0.0
var _confirming := false
var _portrait: CharacterPortrait
var _tag: PlayerTag


func _ready() -> void:
	prev_button.pressed.connect(_change.bind(-1))
	next_button.pressed.connect(_change.bind(1))
	back_button.pressed.connect(_back)
	race_button.pressed.connect(_confirm)
	toast.modulate.a = 0.0
	if GameState.is_multiplayer():
		_tag = PlayerTag.new()
		$UI/Root.add_child(_tag)
		_tag.position = Vector2(header.position.x + header.size.x + 14.0, header.position.y + 3.0)
	GameState.picking_player = clampi(GameState.picking_player, 0, GameState.players.size() - 1)
	_start_turn()


## Começa a vez do jogador que está escolhendo (GameState.picking_player).
func _start_turn() -> void:
	var slot := _slot()
	index = clampi(slot.kart_index, 0, GameState.karts.size() - 1)
	if _tag:
		_tag.setup_slot(slot, slot.device_name())
		header.accent = slot.color
		header.queue_redraw()
		_tag.pivot_offset = Vector2(43, 25)
		_tag.scale = Vector2.ONE * 1.3
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_tag, "scale", Vector2.ONE, 0.3)
	var character := _character()
	driver_label.text = character.display_name if character else "Sem piloto"
	if is_instance_valid(_portrait):
		_portrait.queue_free()
		_portrait = null
	driver_portrait.texture = null
	if character:
		_portrait = CharacterPortrait.new()
		add_child(_portrait)
		_portrait.setup(character, 160)
		driver_portrait.texture = _portrait.get_texture()
	_show_kart(0)
	race_button.grab_focus()


func _slot() -> PlayerSlot:
	return GameState.players[GameState.picking_player]


func _character() -> CharacterData:
	return GameState.get_player_character(GameState.picking_player)


func _physics_process(delta: float) -> void:
	_nav_cooldown -= delta
	_time += delta
	if _spin_pause > 0.0:
		_spin_pause -= delta
	elif not _dragging:
		turntable.rotate_y(delta * 0.5)
	# O piloto "brinca" com o volante enquanto espera.
	if is_instance_valid(_kart_visual):
		var steer := sin(_time * 1.3) * 0.7 * clampf(sin(_time * 0.45) * 2.0, 0.0, 1.0)
		_kart_visual.update_motion(delta, 0.0, steer, 0)


func _input(event: InputEvent) -> void:
	# O analógico chega como ui_left/ui_right (MenuInput), um passo por vez.
	if _confirming or event is InputEventJoypadMotion:
		return
	if event.is_action_pressed("esquerda") or event.is_action_pressed("ui_left"):
		_change(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("direita") or event.is_action_pressed("ui_right"):
		_change(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Arraste com o mouse para girar o kart.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_spin_pause = 2.5
	elif event is InputEventMouseMotion and _dragging:
		turntable.rotate_y(event.relative.x * 0.012)
		_spin_pause = 2.5


func _change(dir: int) -> void:
	if _nav_cooldown > 0.0:
		return
	_nav_cooldown = 0.22
	(prev_button if dir < 0 else next_button).flash()
	if GameState.karts.size() <= 1:
		_show_toast("Novos karts em breve!")
		_nudge(dir)
		Sfx.play(self, &"ui_back", -12.0)
		return
	index = wrapi(index + dir, 0, GameState.karts.size())
	Sfx.play(self, &"ui_move", -10.0)
	_show_kart(dir)


func _confirm() -> void:
	if _confirming:
		return
	_confirming = true
	_slot().kart_index = index
	if is_instance_valid(_kart_visual) and _kart_visual.driver:
		_kart_visual.driver.set_face(&"face_happy")
		_kart_visual.driver.play_gesture(&"gesture_thumbs_up", 1.5, 2)
		_kart_visual.driver.bounce(1.2)
	Sfx.play(self, &"ui_accept", -8.0)
	await get_tree().create_timer(0.6).timeout
	if GameState.picking_player < GameState.players.size() - 1:
		GameState.picking_player += 1
		_confirming = false
		_start_turn()
		return
	GameState.picking_player = 0
	GameState.goto_scene(GameState.SCENE_GLIDER_SELECT)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	if GameState.picking_player > 0:
		GameState.picking_player -= 1
		_start_turn()
		return
	# Volta para a escolha de piloto do último jogador.
	GameState.picking_player = GameState.players.size() - 1
	GameState.goto_scene(GameState.SCENE_CHARACTER_SELECT)


func _show_kart(dir: int) -> void:
	var data: KartData = GameState.karts[index]
	var character := _character()
	if is_instance_valid(_kart_visual):
		_kart_visual.queue_free()
	_kart_visual = KartVisual.new()
	turntable.add_child(_kart_visual)
	_kart_visual.setup(data, character)
	if dir != 0:
		_kart_visual.position.x = dir * 4.0
		_kart_visual.scale = Vector3.ONE * 0.7
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_kart_visual, "position:x", 0.0, 0.4)
		tw.tween_property(_kart_visual, "scale", Vector3.ONE, 0.4)

	name_label.text = data.display_name
	counter_label.text = "%d de %d" % [index + 1, GameState.karts.size()]
	description_label.text = data.description
	credits_label.text = data.credits
	credits_label.visible = data.credits != ""
	stats.set_stats(data.combined_stats(character))


## Chamado pelo GameState atrás do fade: mostra todos os karts juntos por um quadro
## para os shaders deles compilarem já (trocar para um kart novo travava a tela na
## primeira vez, na web e também no Forward+).
func warm_up() -> void:
	var extras: Array[KartVisual] = []
	for i in GameState.karts.size():
		if i == index:
			continue
		var v := KartVisual.new()
		turntable.add_child(v)
		v.setup(GameState.karts[i], null)
		extras.append(v)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for v in extras:
		v.queue_free()


func _nudge(dir: int) -> void:
	if not is_instance_valid(_kart_visual):
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_kart_visual, "position:x", dir * 0.25, 0.08)
	tw.tween_property(_kart_visual, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _show_toast(text: String) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
