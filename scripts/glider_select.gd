extends Node3D
## Tela de seleção de asa-delta: o kart e o piloto escolhidos girando no palco com a
## asa aberta em cima, o nome e a descrição da asa e botões para voltar ou seguir para
## a escolha da pista. A asa abre nas rampas de asa-delta das pistas; todas planam
## igual (a escolha é só de estilo). No multijogador cada jogador escolhe na vez dele.

@onready var turntable: Node3D = $Palco/Giro
@onready var name_label: Label = %GliderName
@onready var counter_label: Label = %GliderCounter
@onready var description_label: Label = %GliderDescription
@onready var credits_label: Label = %GliderCredits
@onready var driver_label: Label = %DriverName
@onready var kart_label: Label = %KartName
@onready var driver_portrait: TextureRect = %DriverPortrait
@onready var dots: HBoxContainer = %Dots
@onready var prev_button: ArrowButton = %PrevButton
@onready var next_button: ArrowButton = %NextButton
@onready var back_button: FancyButton = %BackButton
@onready var race_button: FancyButton = %RaceButton
@onready var toast: Label = %Toast
@onready var header: RibbonLabel = $UI/Root/Header

var index := 0
var _kart_visual: KartVisual
var _glider: GliderVisual
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
	_build_dots()
	_start_turn()


## Começa a vez do jogador que está escolhendo (GameState.picking_player).
func _start_turn() -> void:
	var slot := _slot()
	index = clampi(slot.glider_index, 0, maxi(GameState.gliders.size() - 1, 0))
	if _tag:
		_tag.setup_slot(slot, slot.device_name())
		header.accent = slot.color
		header.queue_redraw()
		_tag.pivot_offset = Vector2(43, 25)
		_tag.scale = Vector2.ONE * 1.3
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_tag, "scale", Vector2.ONE, 0.3)
	var character := GameState.get_player_character(GameState.picking_player)
	var kart := GameState.get_player_kart(GameState.picking_player)
	driver_label.text = character.display_name if character else "Sem piloto"
	kart_label.text = kart.display_name if kart else "-"
	if is_instance_valid(_portrait):
		_portrait.queue_free()
		_portrait = null
	driver_portrait.texture = null
	if character:
		_portrait = CharacterPortrait.new()
		add_child(_portrait)
		_portrait.setup(character, 160)
		driver_portrait.texture = _portrait.get_texture()
	# O kart e o piloto escolhidos, no palco.
	if is_instance_valid(_kart_visual):
		_kart_visual.queue_free()
	_kart_visual = KartVisual.new()
	turntable.add_child(_kart_visual)
	_kart_visual.setup(kart, character)
	_glider = null
	_show_glider(0)
	race_button.grab_focus()


func _slot() -> PlayerSlot:
	return GameState.players[GameState.picking_player]


func _physics_process(delta: float) -> void:
	_nav_cooldown -= delta
	_time += delta
	if _spin_pause > 0.0:
		_spin_pause -= delta
	elif not _dragging:
		turntable.rotate_y(delta * 0.45)
	# O piloto "pilota" a asa enquanto espera: vira de leve para os lados.
	if is_instance_valid(_kart_visual):
		var steer := sin(_time * 0.9) * 0.6
		_kart_visual.update_motion(delta, 0.0, steer, 0)
		# Inclina um pouco para o lado da curva, como planando.
		_kart_visual.rotation.z = lerpf(_kart_visual.rotation.z, steer * 0.12, 1.0 - exp(-3.0 * delta))


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
	# Arraste com o mouse para girar.
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
	if GameState.gliders.size() <= 1:
		_show_toast("Novas asas em breve!")
		Sfx.play(self, &"ui_back", -12.0)
		return
	index = wrapi(index + dir, 0, GameState.gliders.size())
	Sfx.play(self, &"ui_move", -10.0)
	_show_glider(dir)


func _confirm() -> void:
	if _confirming:
		return
	_confirming = true
	_slot().glider_index = index
	if is_instance_valid(_kart_visual) and _kart_visual.driver:
		_kart_visual.driver.set_face(&"face_happy")
		_kart_visual.driver.play_gesture(&"gesture_cheer", 1.4)
		_kart_visual.driver.bounce(1.2)
	if is_instance_valid(_glider):
		# A asa dá um "estalo" de novo.
		_glider.set_open(false, true)
		_glider.set_open(true)
	Sfx.play(self, &"ui_accept", -8.0)
	Sfx.play(self, &"glider_open", -12.0)
	await get_tree().create_timer(0.6).timeout
	if GameState.picking_player < GameState.players.size() - 1:
		GameState.picking_player += 1
		_confirming = false
		_start_turn()
		return
	GameState.picking_player = 0
	GameState.goto_scene(GameState.SCENE_TRACK_SELECT)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	if GameState.picking_player > 0:
		GameState.picking_player -= 1
		_start_turn()
		return
	# Volta para a escolha de kart do último jogador.
	GameState.picking_player = GameState.players.size() - 1
	GameState.goto_scene(GameState.SCENE_KART_SELECT)


## Mostra a asa `index` aberta em cima do kart (desdobrando, ao trocar).
func _show_glider(dir: int) -> void:
	if GameState.gliders.is_empty():
		return
	var data: GliderData = GameState.gliders[index]
	if is_instance_valid(_glider):
		_glider.queue_free()
	_glider = GliderVisual.new()
	_glider.name = "Asa"
	_glider.sway = 0.6
	# Filha do modelo do kart: inclina junto com ele.
	_kart_visual.add_child(_glider)
	_glider.setup(data)
	_glider.position = _glider.fit_to(_kart_visual)
	if dir == 0:
		_glider.set_open(true, true)
	else:
		_glider.set_open(true)
		Sfx.play(self, &"glider_open", -16.0)

	name_label.text = data.display_name
	counter_label.text = "%d de %d" % [index + 1, GameState.gliders.size()]
	description_label.text = data.description
	credits_label.text = data.credits
	credits_label.visible = data.credits != ""
	_update_dots()


## Uma bolinha com a cor de cada asa (a escolhida, maior e com aro).
func _build_dots() -> void:
	for child in dots.get_children():
		child.queue_free()
	for i in GameState.gliders.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(26, 26)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_STOP
		dot.gui_input.connect(_on_dot_input.bind(i))
		dots.add_child(dot)


func _update_dots() -> void:
	for i in dots.get_child_count():
		var dot := dots.get_child(i) as Panel
		var chosen := i == index
		var box := StyleBoxFlat.new()
		box.bg_color = GameState.gliders[i].accent
		box.set_corner_radius_all(13)
		box.set_border_width_all(4 if chosen else 2)
		box.border_color = UiKit.YELLOW if chosen else Color(1, 1, 1, 0.85)
		dot.add_theme_stylebox_override("panel", box)
		dot.custom_minimum_size = Vector2(30, 30) if chosen else Vector2(22, 22)


func _on_dot_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and i != index:
		var dir := 1 if i > index else -1
		index = i
		Sfx.play(self, &"ui_move", -10.0)
		_show_glider(dir)


## Chamado pelo GameState atrás do fade: mostra todas as asas por um quadro para as
## texturas subirem para a GPU já (trocar de asa não trava na primeira vez).
func warm_up() -> void:
	var extras: Array[GliderVisual] = []
	for i in GameState.gliders.size():
		if i == index:
			continue
		var g := GliderVisual.new()
		turntable.add_child(g)
		g.setup(GameState.gliders[i])
		g.position = Vector3(0.0, 1.0, 0.0)
		g.set_open(true, true)
		extras.append(g)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for g in extras:
		g.queue_free()


func _show_toast(text: String) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
