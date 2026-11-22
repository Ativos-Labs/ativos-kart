extends Node3D
## Tela de seleção de kart: o kart com o piloto escolhido girando no palco,
## atributos (kart + piloto) e botões para voltar ou seguir para a escolha da asa-delta.
## No multijogador todos escolhem ao mesmo tempo, cada um no seu cartão (PickPanel, com
## o kart dele no palco): ←/→ troca, A confirma, B desfaz; quando todos confirmam a
## tela segue para as asas.

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

# Multijogador.
var _multi: MultiPick
var _panels: Array[PickPanel] = []
var _indices: Array[int] = []
var _visuals: Array[KartVisual] = []


func _ready() -> void:
	toast.modulate.a = 0.0
	if GameState.is_multiplayer():
		_setup_multi()
		return
	prev_button.pressed.connect(_change.bind(-1))
	next_button.pressed.connect(_change.bind(1))
	back_button.pressed.connect(_back)
	race_button.pressed.connect(_confirm)
	index = clampi(GameState.players[0].kart_index, 0, GameState.karts.size() - 1)
	var character := GameState.get_player_character(0)
	driver_label.text = character.display_name if character else "Sem piloto"
	if character:
		_portrait = CharacterPortrait.new()
		add_child(_portrait)
		_portrait.setup(character, 160)
		driver_portrait.texture = _portrait.get_texture()
	_show_kart(0)
	race_button.grab_focus()


func _exit_tree() -> void:
	# O multijogador desliga o 3D da janela (cada cartão tem o seu palco).
	if _multi:
		get_viewport().disable_3d = false


func _physics_process(delta: float) -> void:
	_nav_cooldown -= delta
	_time += delta
	if _multi:
		for p in _panels.size():
			_panels[p].stage.turntable.rotate_y(delta * 0.5)
			_idle_steer(_visuals[p], delta, p * 1.7)
		return
	if _spin_pause > 0.0:
		_spin_pause -= delta
	elif not _dragging:
		turntable.rotate_y(delta * 0.5)
	_idle_steer(_kart_visual, delta, 0.0)


## O piloto "brinca" com o volante enquanto espera.
func _idle_steer(visual: KartVisual, delta: float, phase: float) -> void:
	if is_instance_valid(visual):
		var t := _time + phase
		var steer := sin(t * 1.3) * 0.7 * clampf(sin(t * 0.45) * 2.0, 0.0, 1.0)
		visual.update_motion(delta, 0.0, steer, 0)


func _input(event: InputEvent) -> void:
	# O analógico chega como ui_left/ui_right (MenuInput), um passo por vez.
	if _multi or _confirming or event is InputEventJoypadMotion:
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
	if _multi:
		return
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
		_nudge(_kart_visual, dir)
		Sfx.play(self, &"ui_back", -12.0)
		return
	index = wrapi(index + dir, 0, GameState.karts.size())
	Sfx.play(self, &"ui_move", -10.0)
	_show_kart(dir)


func _confirm() -> void:
	if _confirming:
		return
	_confirming = true
	GameState.players[0].kart_index = index
	_thumbs_up(_kart_visual)
	Sfx.play(self, &"ui_accept", -8.0)
	await get_tree().create_timer(0.6).timeout
	GameState.goto_scene(GameState.SCENE_GLIDER_SELECT)


func _thumbs_up(visual: KartVisual) -> void:
	if is_instance_valid(visual) and visual.driver:
		visual.driver.set_face(&"face_happy")
		visual.driver.play_gesture(&"gesture_thumbs_up", 1.5, 2)
		visual.driver.bounce(1.2)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	GameState.goto_scene(GameState.SCENE_CHARACTER_SELECT)


func _show_kart(dir: int) -> void:
	var data: KartData = GameState.karts[index]
	var character := GameState.get_player_character(0)
	if is_instance_valid(_kart_visual):
		_kart_visual.queue_free()
	_kart_visual = _spawn_kart(data, character, turntable, dir)
	name_label.text = data.display_name
	counter_label.text = "%d de %d" % [index + 1, GameState.karts.size()]
	description_label.text = data.description
	credits_label.text = data.credits
	credits_label.visible = data.credits != ""
	stats.set_stats(data.combined_stats(character))


## Kart com o piloto no palco `parent`; trocando (dir ≠ 0) ele entra deslizando do lado.
func _spawn_kart(data: KartData, character: CharacterData, parent: Node3D, dir: int) -> KartVisual:
	var visual := KartVisual.new()
	parent.add_child(visual)
	visual.setup(data, character)
	if dir != 0:
		visual.position.x = dir * 4.0
		visual.scale = Vector3.ONE * 0.7
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(visual, "position:x", 0.0, 0.4)
		tw.tween_property(visual, "scale", Vector3.ONE, 0.4)
	return visual


## Chamado pelo GameState atrás do fade: mostra todos os karts juntos por um quadro
## para os shaders deles compilarem já (trocar para um kart novo travava a tela na
## primeira vez, na web e também no Forward+).
func warm_up() -> void:
	var stage := turntable if _panels.is_empty() else _panels[0].stage.turntable
	var shown := index if _panels.is_empty() else _indices[0]
	var extras: Array[KartVisual] = []
	for i in GameState.karts.size():
		if i == shown:
			continue
		var v := KartVisual.new()
		stage.add_child(v)
		v.setup(GameState.karts[i], null)
		extras.append(v)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for v in extras:
		v.queue_free()


func _nudge(visual: KartVisual, dir: int) -> void:
	if not is_instance_valid(visual):
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(visual, "position:x", dir * 0.25, 0.08)
	tw.tween_property(visual, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _show_toast(text: String) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.3)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)


# --- Multijogador: todos escolhem ao mesmo tempo ---------------------------------------

func _setup_multi() -> void:
	header.text = "ESCOLHAM SEUS KARTS"
	for node: CanvasItem in [$UI/Root/InfoPanel, $UI/Root/Buttons]:
		node.hide()
	$Palco.hide()
	get_viewport().disable_3d = true
	# O aviso fica na linha do título (embaixo dele estão os cartões).
	toast.anchor_left = 1.0
	toast.anchor_right = 1.0
	toast.anchor_top = 0.0
	toast.anchor_bottom = 0.0
	toast.offset_left = -620.0
	toast.offset_right = -40.0
	toast.offset_top = 26.0
	toast.offset_bottom = 80.0
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	($UI/Root/Hints as HintBar).hints = PackedStringArray(["←  →|Trocar", "Enter|Pronto", "Esc|Voltar"])

	_multi = MultiPick.new()
	_multi.name = "Escolha"
	add_child(_multi)
	_multi.moved.connect(_multi_move)
	_multi.confirm_requested.connect(_multi_confirm)
	_multi.unconfirmed.connect(_multi_unconfirm)
	_multi.back_requested.connect(_back)
	_multi.all_ready.connect(func(): GameState.goto_scene(GameState.SCENE_GLIDER_SELECT))

	for p in GameState.players.size():
		var slot := GameState.players[p]
		var panel := PickPanel.new()
		panel.name = "Cartao%s" % slot.tag
		$UI/Root.add_child(panel)
		panel.setup(slot, 1.9, true)
		panel.stage.frame(Vector3(0.0, 0.38, 0.0), Vector2(2.3, 1.1), 0.3, 7.0)
		panel.stage.turntable.rotation.y = 2.45 + p * 0.6
		panel.step_requested.connect(func(dir: int): _on_panel_step(p, dir))
		panel.stage_clicked.connect(_on_panel_clicked.bind(p))
		var bars := StatBars.new()
		bars.row_height = 26.0
		bars.label_width = 104.0
		bars.bar_min_width = 110.0
		bars.font_size = 15
		bars.name = "Atributos"
		panel.extra.add_child(bars)
		_panels.append(panel)
		_indices.append(clampi(slot.kart_index, 0, GameState.karts.size() - 1))
		_visuals.append(null)
		_show_player_kart(p, 0)
	get_viewport().size_changed.connect(_multi_layout)
	_multi_layout()


func _multi_layout() -> void:
	var rects := MultiPick.card_rects(_panels.size(), MultiPick.content_rect(get_viewport()))
	for p in _panels.size():
		_panels[p].position = rects[p].position
		_panels[p].size = rects[p].size


func _show_player_kart(p: int, dir: int) -> void:
	var data: KartData = GameState.karts[_indices[p]]
	var character := GameState.get_player_character(p)
	var panel := _panels[p]
	if is_instance_valid(_visuals[p]):
		_visuals[p].queue_free()
	_visuals[p] = _spawn_kart(data, character, panel.stage.turntable, dir)
	panel.title.text = data.display_name
	panel.detail.text = "%d de %d" % [_indices[p] + 1, GameState.karts.size()]
	(panel.extra.get_node("Atributos") as StatBars).set_stats(data.combined_stats(character), dir != 0)


func _multi_move(p: int, dir: Vector2i) -> void:
	if dir.x != 0:
		_multi_change(p, dir.x)


func _multi_change(p: int, dir: int) -> void:
	_panels[p].flash_arrow(dir)
	if GameState.karts.size() <= 1:
		_show_toast("Novos karts em breve!")
		_nudge(_visuals[p], dir)
		Sfx.play(self, &"ui_back", -12.0)
		return
	_indices[p] = wrapi(_indices[p] + dir, 0, GameState.karts.size())
	Sfx.play(self, &"ui_move", -10.0)
	_show_player_kart(p, dir)


func _multi_confirm(p: int) -> void:
	GameState.players[p].kart_index = _indices[p]
	_multi.set_ready(p, true)
	_panels[p].confirmed = true
	_thumbs_up(_visuals[p])
	Sfx.play(self, &"ui_accept", -8.0)
	if not _multi.confirmed.has(false):
		_show_toast("Todos prontos!")


func _multi_unconfirm(p: int) -> void:
	_panels[p].confirmed = false
	Sfx.play(self, &"ui_back", -10.0)


## Setas clicadas com o mouse: só no cartão do jogador do mouse, antes de confirmar.
func _on_panel_step(p: int, dir: int) -> void:
	if not _multi.locked and p == _multi.mouse_player() and not _multi.confirmed[p]:
		_multi_change(p, dir)


func _on_panel_clicked(p: int) -> void:
	if _multi.locked or p != _multi.mouse_player():
		return
	if _multi.confirmed[p]:
		_multi.set_ready(p, false)
		_multi_unconfirm(p)
	else:
		_multi_confirm(p)
