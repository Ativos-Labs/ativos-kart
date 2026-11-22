extends Node3D
## Tela de seleção de asa-delta: o kart e o piloto escolhidos girando no palco com a
## asa aberta em cima, o nome e a descrição da asa e botões para voltar ou seguir para
## a escolha da pista. A asa abre nas rampas de asa-delta das pistas; todas planam
## igual (a escolha é só de estilo). No multijogador todos escolhem ao mesmo tempo, cada
## um no seu cartão (PickPanel): ←/→ troca, A confirma, B desfaz; quando todos
## confirmam a tela segue para as pistas.

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

# Multijogador.
var _multi: MultiPick
var _panels: Array[PickPanel] = []
var _indices: Array[int] = []
var _karts: Array[KartVisual] = []
var _gliders: Array[GliderVisual] = []


func _ready() -> void:
	toast.modulate.a = 0.0
	if GameState.is_multiplayer():
		_setup_multi()
		return
	prev_button.pressed.connect(_change.bind(-1))
	next_button.pressed.connect(_change.bind(1))
	back_button.pressed.connect(_back)
	race_button.pressed.connect(_confirm)
	_build_dots(dots, _on_dot_input)
	index = clampi(GameState.players[0].glider_index, 0, maxi(GameState.gliders.size() - 1, 0))
	var character := GameState.get_player_character(0)
	var kart := GameState.get_player_kart(0)
	driver_label.text = character.display_name if character else "Sem piloto"
	kart_label.text = kart.display_name if kart else "-"
	if character:
		_portrait = CharacterPortrait.new()
		add_child(_portrait)
		_portrait.setup(character, 160)
		driver_portrait.texture = _portrait.get_texture()
	# O kart e o piloto escolhidos, no palco.
	_kart_visual = KartVisual.new()
	turntable.add_child(_kart_visual)
	_kart_visual.setup(kart, character)
	_kart_visual.scale = Vector3.ONE * _kart_visual.showcase_scale()
	_show_glider(0)
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
			_panels[p].stage.turntable.rotate_y(delta * 0.45)
			_glide(_karts[p], delta, p * 1.3)
		return
	if _spin_pause > 0.0:
		_spin_pause -= delta
	elif not _dragging:
		turntable.rotate_y(delta * 0.45)
	_glide(_kart_visual, delta, 0.0)


## O piloto "pilota" a asa enquanto espera: vira de leve para os lados e inclina o
## kart para o lado da curva, como planando.
func _glide(visual: KartVisual, delta: float, phase: float) -> void:
	if is_instance_valid(visual):
		var steer := sin((_time + phase) * 0.9) * 0.6
		visual.update_motion(delta, 0.0, steer, 0)
		visual.rotation.z = lerpf(visual.rotation.z, steer * 0.12, 1.0 - exp(-3.0 * delta))


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
	GameState.players[0].glider_index = index
	_celebrate(_kart_visual, _glider)
	await get_tree().create_timer(0.6).timeout
	GameState.goto_scene(GameState.SCENE_TRACK_SELECT)


## Piloto comemora e a asa dá um "estalo" de novo.
func _celebrate(visual: KartVisual, glider: GliderVisual) -> void:
	if is_instance_valid(visual) and visual.driver:
		visual.driver.set_face(&"face_happy")
		visual.driver.play_gesture(&"gesture_cheer", 1.4)
		visual.driver.bounce(1.2)
	if is_instance_valid(glider):
		glider.set_open(false, true)
		glider.set_open(true)
	Sfx.play(self, &"ui_accept", -8.0)
	Sfx.play(self, &"glider_open", -12.0)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	GameState.goto_scene(GameState.SCENE_KART_SELECT)


## Mostra a asa `index` aberta em cima do kart (desdobrando, ao trocar).
func _show_glider(dir: int) -> void:
	if GameState.gliders.is_empty():
		return
	var data: GliderData = GameState.gliders[index]
	if is_instance_valid(_glider):
		_glider.queue_free()
	_glider = _spawn_glider(data, _kart_visual, dir)
	name_label.text = data.display_name
	counter_label.text = "%d de %d" % [index + 1, GameState.gliders.size()]
	description_label.text = data.description
	credits_label.text = data.credits
	credits_label.visible = data.credits != ""
	_update_dots(dots, index)


## Asa `data` aberta em cima do kart `visual` (desdobrando, se dir ≠ 0).
func _spawn_glider(data: GliderData, visual: KartVisual, dir: int) -> GliderVisual:
	var glider := GliderVisual.new()
	glider.name = "Asa"
	glider.sway = 0.6
	# Filha do modelo do kart: inclina junto com ele.
	visual.add_child(glider)
	glider.setup(data)
	glider.position = glider.fit_to(visual)
	if dir == 0:
		glider.set_open(true, true)
	else:
		glider.set_open(true)
		Sfx.play(self, &"glider_open", -16.0)
	return glider


## Uma bolinha com a cor de cada asa (a escolhida, maior e com aro). `on_input`
## recebe os cliques (evento, índice da asa); vazio = só mostra.
func _build_dots(row: HBoxContainer, on_input := Callable()) -> void:
	for child in row.get_children():
		child.queue_free()
	for i in GameState.gliders.size():
		var dot := Panel.new()
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_STOP if on_input.is_valid() else Control.MOUSE_FILTER_IGNORE
		if on_input.is_valid():
			dot.gui_input.connect(on_input.bind(i))
		row.add_child(dot)


func _update_dots(row: HBoxContainer, chosen_index: int) -> void:
	for i in row.get_child_count():
		var dot := row.get_child(i) as Panel
		var chosen := i == chosen_index
		var box := StyleBoxFlat.new()
		box.bg_color = GameState.gliders[i].accent
		box.set_corner_radius_all(13)
		box.set_border_width_all(4 if chosen else 2)
		box.border_color = UiKit.YELLOW if chosen else Color(1, 1, 1, 0.85)
		if row != dots:
			# Nos cartões (fundo claro) o aro das outras asas fica escuro.
			box.border_color = UiKit.YELLOW_DARK if chosen else Color(UiKit.INK, 0.25)
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
	var stage := turntable if _panels.is_empty() else _panels[0].stage.turntable
	var shown := index if _panels.is_empty() else _indices[0]
	var extras: Array[GliderVisual] = []
	for i in GameState.gliders.size():
		if i == shown:
			continue
		var g := GliderVisual.new()
		stage.add_child(g)
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


# --- Multijogador: todos escolhem ao mesmo tempo ---------------------------------------

func _setup_multi() -> void:
	header.text = "ESCOLHAM SUAS ASAS"
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
	_multi.all_ready.connect(func(): GameState.goto_scene(GameState.SCENE_TRACK_SELECT))

	for p in GameState.players.size():
		var slot := GameState.players[p]
		var panel := PickPanel.new()
		panel.name = "Cartao%s" % slot.tag
		$UI/Root.add_child(panel)
		panel.setup(slot, 1.9, true)
		panel.stage.frame(Vector3(0.0, 1.5, 0.0), Vector2(2.25, 2.3), 0.25, 10.0)
		panel.stage.turntable.rotation.y = 2.2 + p * 0.6
		panel.step_requested.connect(func(dir: int): _on_panel_step(p, dir))
		panel.stage_clicked.connect(_on_panel_clicked.bind(p))
		var row := HBoxContainer.new()
		row.name = "Cores"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 34.0
		panel.extra.add_child(row)
		_build_dots(row)
		var visual := KartVisual.new()
		panel.stage.turntable.add_child(visual)
		visual.setup(GameState.get_player_kart(p), GameState.get_player_character(p))
		visual.scale = Vector3.ONE * visual.showcase_scale()
		_panels.append(panel)
		_karts.append(visual)
		_gliders.append(null)
		_indices.append(clampi(slot.glider_index, 0, maxi(GameState.gliders.size() - 1, 0)))
		_show_player_glider(p, 0)
	get_viewport().size_changed.connect(_multi_layout)
	_multi_layout()


func _multi_layout() -> void:
	var rects := MultiPick.card_rects(_panels.size(), MultiPick.content_rect(get_viewport()))
	for p in _panels.size():
		_panels[p].position = rects[p].position
		_panels[p].size = rects[p].size


func _show_player_glider(p: int, dir: int) -> void:
	if GameState.gliders.is_empty():
		return
	var data: GliderData = GameState.gliders[_indices[p]]
	var panel := _panels[p]
	if is_instance_valid(_gliders[p]):
		_gliders[p].queue_free()
	_gliders[p] = _spawn_glider(data, _karts[p], dir)
	panel.title.text = data.display_name
	panel.detail.text = "%d de %d" % [_indices[p] + 1, GameState.gliders.size()]
	_update_dots(panel.extra.get_node("Cores") as HBoxContainer, _indices[p])


func _multi_move(p: int, dir: Vector2i) -> void:
	if dir.x != 0:
		_multi_change(p, dir.x)


func _multi_change(p: int, dir: int) -> void:
	_panels[p].flash_arrow(dir)
	if GameState.gliders.size() <= 1:
		_show_toast("Novas asas em breve!")
		Sfx.play(self, &"ui_back", -12.0)
		return
	_indices[p] = wrapi(_indices[p] + dir, 0, GameState.gliders.size())
	Sfx.play(self, &"ui_move", -10.0)
	_show_player_glider(p, dir)


func _multi_confirm(p: int) -> void:
	GameState.players[p].glider_index = _indices[p]
	_multi.set_ready(p, true)
	_panels[p].confirmed = true
	_celebrate(_karts[p], _gliders[p])
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
