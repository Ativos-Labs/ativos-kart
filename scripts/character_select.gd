extends Node3D
## Tela de seleção de personagem: grade de retratos, personagem 3D no palco
## (acena, sorri, comemora ao confirmar), nome, atributos e dicas de teclas.
##
## No multijogador todos escolhem ao mesmo tempo na mesma grade: cada jogador tem um
## cursor na cor dele (etiqueta J1, J2... no quadradinho) e um cartão com o piloto
## dele no palco (PickPanel, nos cantos da tela). A confirma, B desfaz; quando todos
## confirmam a tela segue para os karts. Quem repete um personagem já escolhido por um
## jogador anterior corre com ele recolorido na cor do jogador.

const COLUMNS := 4
## Multijogador: a grade fica no meio, em 2 colunas (os cartões dos jogadores nos lados).
const MULTI_COLUMNS := 2
const MULTI_TILE_GAP := 24.0

@onready var turntable: Node3D = $Palco/Giro
@onready var background: ColorRect = %Background
@onready var grid: GridContainer = %Grid
@onready var name_ribbon: RibbonLabel = %NameRibbon
@onready var tagline_label: Label = %Tagline
@onready var description_label: Label = %Description
@onready var stats: StatBars = %Stats
@onready var toast: Label = %Toast
@onready var back_button: FancyButton = %BackButton
@onready var confirm_button: FancyButton = %ConfirmButton
@onready var locked_mark: Label = %LockedMark
@onready var header: RibbonLabel = $UI/Root/Header

var index := 0
var _tiles: Array[CharacterTile] = []
var _rig: CharacterRig
var _nav_cooldown := 0.0
var _confirming := false
var _dragging := false
var _spin_pause := 0.0
var _toast_tween: Tween
var _bg_tween: Tween

# Multijogador.
var _multi: MultiPick
var _panels: Array[PickPanel] = []
var _cursors: Array[int] = []
var _rigs: Array[CharacterRig] = []
var _columns := COLUMNS


func _ready() -> void:
	_build_grid()
	toast.modulate.a = 0.0
	if GameState.is_multiplayer():
		_setup_multi()
		return
	back_button.pressed.connect(_back)
	confirm_button.pressed.connect(_confirm)
	index = clampi(GameState.players[0].character_index, 0, maxi(GameState.characters.size() - 1, 0))
	_select(index, true)


func _exit_tree() -> void:
	# O multijogador desliga o 3D da janela (cada cartão tem o seu palco).
	if _multi:
		get_viewport().disable_3d = false


func _build_grid() -> void:
	grid.columns = COLUMNS
	var count := maxi(GameState.character_slots, GameState.characters.size())
	for i in count:
		var data: CharacterData
		if i < GameState.characters.size():
			data = GameState.characters[i]
		else:
			data = CharacterData.new()
			data.display_name = "???"
			data.tagline = "Em breve"
			data.locked = true
		var tile := CharacterTile.new()
		tile.setup(data)
		tile.pressed.connect(_on_tile_pressed.bind(i))
		grid.add_child(tile)
		_tiles.append(tile)


func _physics_process(delta: float) -> void:
	_nav_cooldown -= delta
	if _spin_pause > 0.0:
		_spin_pause -= delta
		if _spin_pause <= 0.0:
			var tw := create_tween().set_trans(Tween.TRANS_SINE)
			tw.tween_property(turntable, "rotation:y", 0.0, 0.6)


func _input(event: InputEvent) -> void:
	# O analógico chega como ui_left/ui_right... (MenuInput), um passo por vez.
	if _multi or _confirming or event is InputEventJoypadMotion:
		return
	var move := 0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("esquerda"):
		move = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("direita"):
		move = 1
	elif event.is_action_pressed("ui_up"):
		move = -COLUMNS
	elif event.is_action_pressed("ui_down"):
		move = COLUMNS
	if move != 0:
		_move(move)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not back_button.has_focus():
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _multi:
		return
	# Arraste com o mouse para girar o personagem.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_spin_pause = 2.0
	elif event is InputEventMouseMotion and _dragging:
		turntable.rotate_y(event.relative.x * 0.012)
		_spin_pause = 2.0


func _move(step: int) -> void:
	if _nav_cooldown > 0.0:
		return
	_nav_cooldown = 0.12
	var next := _step_index(index, step)
	if next < 0:
		return
	Sfx.play(self, &"ui_move", -12.0)
	_select(next, false)


## Quadradinho depois de andar `step` a partir de `from` (-1 = fora da grade).
## Para os lados dá a volta; para cima e para baixo para na borda.
func _step_index(from: int, step: int) -> int:
	var count := _tiles.size()
	var next := from + step
	if absi(step) == 1:
		return wrapi(next, 0, count)
	return next if next >= 0 and next < count else -1


func _on_tile_pressed(i: int) -> void:
	if _multi:
		var p := _multi.mouse_player()
		if _multi.locked or _multi.confirmed[p]:
			return
		if _cursors[p] == i:
			_multi_confirm(p)
		else:
			Sfx.play(self, &"ui_move", -12.0)
			_set_cursor(p, i)
		return
	if i == index:
		_confirm()
	else:
		Sfx.play(self, &"ui_move", -12.0)
		_select(i, false)


func _select(i: int, first: bool) -> void:
	index = i
	for t in _tiles.size():
		_tiles[t].selected = t == index
	var tile := _tiles[index]
	var data := tile.data
	var unlocked := tile.is_unlocked()

	name_ribbon.text = data.display_name.to_upper()
	name_ribbon.color = data.color if unlocked else Color(0.3, 0.34, 0.45)
	tagline_label.text = data.tagline
	description_label.text = data.description if unlocked else "Novos pilotos chegam em breve. Por enquanto, escolha um dos pilotos liberados!"
	stats.set_stats(_stats_of(data) if unlocked else {}, not first)
	confirm_button.disabled = not unlocked
	locked_mark.visible = not unlocked
	if unlocked:
		GameState.players[0].character_index = index
	_show_rig(GameState.get_player_character(0) if unlocked else null, first)
	_tint_background(data.color if unlocked else Color(0.3, 0.36, 0.5), data.color_dark if unlocked else Color(0.08, 0.1, 0.18), first)
	_bump(tile)


static func _stats_of(data: CharacterData) -> Dictionary:
	return {"speed": data.speed, "acceleration": data.acceleration, "handling": data.handling, "weight": data.weight}


## Pulinho do quadradinho escolhido.
func _bump(tile: Control) -> void:
	tile.pivot_offset = tile.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tile.scale = Vector2.ONE * 1.12
	tw.tween_property(tile, "scale", Vector2.ONE, 0.25)


func _show_rig(data: CharacterData, first: bool) -> void:
	if is_instance_valid(_rig) and _rig.data == data:
		return
	if is_instance_valid(_rig):
		_rig.queue_free()
		_rig = null
	if data == null:
		return
	_rig = _spawn_rig(data, turntable, first)


## Personagem em pé no palco `parent`, aparecendo com um pulinho e acenando.
func _spawn_rig(data: CharacterData, parent: Node3D, first: bool) -> CharacterRig:
	var rig := data.instantiate_rig()
	rig.setup_stand(data.showcase_scale)
	parent.add_child(rig)
	rig.scale = Vector3.ONE * 0.6
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rig, "scale", Vector3.ONE, 0.35)
	rig.set_face(&"face_happy")
	rig.play_gesture(&"gesture_wave", 1.6, 2)
	if not first:
		rig.bounce(1.0)
	return rig


func _tint_background(top: Color, bottom: Color, instant: bool) -> void:
	var mat := background.material as ShaderMaterial
	if mat == null:
		return
	var top_color := top.lightened(0.15)
	if _bg_tween:
		_bg_tween.kill()
	if instant:
		mat.set_shader_parameter("color_top", top_color)
		mat.set_shader_parameter("color_bottom", bottom)
		return
	_bg_tween = create_tween().set_parallel()
	_bg_tween.tween_method(func(c: Color): mat.set_shader_parameter("color_top", c),
			mat.get_shader_parameter("color_top"), top_color, 0.35)
	_bg_tween.tween_method(func(c: Color): mat.set_shader_parameter("color_bottom", c),
			mat.get_shader_parameter("color_bottom"), bottom, 0.35)


func _confirm() -> void:
	if _confirming:
		return
	var tile := _tiles[index]
	if not tile.is_unlocked():
		_reject_locked(tile)
		return
	_confirming = true
	GameState.players[0].character_index = index
	Sfx.play(self, &"ui_accept", -8.0)
	_cheer(_rig)
	_show_toast("%s está pronto!" % tile.data.display_name)
	await get_tree().create_timer(0.85).timeout
	GameState.goto_scene(GameState.SCENE_KART_SELECT)


func _reject_locked(tile: CharacterTile) -> void:
	_show_toast("Esse piloto chega em breve!")
	Sfx.play(self, &"ui_back", -10.0)
	_shake(tile)


func _cheer(rig: CharacterRig) -> void:
	if is_instance_valid(rig):
		rig.set_face(&"face_surprised", 0.35)
		rig.play_gesture(&"gesture_cheer", 2.0)
		rig.bounce(1.4)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	GameState.goto_scene(GameState.SCENE_MODE_SELECT)


func _shake(control: Control) -> void:
	var x := control.position.x
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	for i in 3:
		tw.tween_property(control, "position:x", x + 7.0, 0.04)
		tw.tween_property(control, "position:x", x - 7.0, 0.04)
	tw.tween_property(control, "position:x", x, 0.04)


func _show_toast(text: String) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast.pivot_offset = toast.size * 0.5
	toast.scale = Vector2.ONE * 1.25
	_toast_tween = create_tween()
	_toast_tween.set_parallel()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_property(toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(1.3)
	_toast_tween.chain().tween_property(toast, "modulate:a", 0.0, 0.4)


# --- Multijogador: todos escolhem ao mesmo tempo ---------------------------------------

func _setup_multi() -> void:
	header.text = "ESCOLHAM SEUS PILOTOS"
	for node: CanvasItem in [$UI/Root/InfoPanel, $UI/Root/NamePlate, $UI/Root/Buttons, locked_mark]:
		node.hide()
	$Palco.hide()
	get_viewport().disable_3d = true
	# O aviso fica na linha do título (embaixo dele estão os cartões).
	toast.anchor_top = 0.0
	toast.anchor_bottom = 0.0
	toast.offset_top = 26.0
	toast.offset_bottom = 80.0
	($UI/Root/Hints as HintBar).hints = PackedStringArray(["←  →  ↑  ↓|Escolher", "Enter|Pronto", "Esc|Voltar"])
	_columns = MULTI_COLUMNS
	grid.columns = MULTI_COLUMNS
	grid.add_theme_constant_override("h_separation", int(MULTI_TILE_GAP))
	grid.add_theme_constant_override("v_separation", int(MULTI_TILE_GAP))

	_multi = MultiPick.new()
	_multi.name = "Escolha"
	add_child(_multi)
	_multi.moved.connect(_multi_move)
	_multi.confirm_requested.connect(_multi_confirm)
	_multi.unconfirmed.connect(_multi_unconfirm)
	_multi.back_requested.connect(_multi_back)
	_multi.all_ready.connect(_multi_done)

	for p in GameState.players.size():
		var slot := GameState.players[p]
		var panel := PickPanel.new()
		panel.name = "Cartao%s" % slot.tag
		$UI/Root.add_child(panel)
		panel.setup(slot, 1.05, false)
		panel.stage_ratio = 0.46
		panel.stage.frame(Vector3(0.0, 1.0, 0.0), Vector2(1.15, 1.3), 0.12, 6.0)
		panel.stage_clicked.connect(_on_panel_clicked.bind(p))
		var bars := StatBars.new()
		bars.row_height = 26.0
		bars.label_width = 104.0
		bars.bar_min_width = 96.0
		bars.font_size = 15
		bars.name = "Atributos"
		panel.extra.add_child(bars)
		_panels.append(panel)
		_rigs.append(null)
		_cursors.append(clampi(slot.character_index, 0, maxi(GameState.characters.size() - 1, 0)))
	get_viewport().size_changed.connect(_multi_layout)
	_multi_layout()
	_refresh_multi(true)


## Grade no meio (do tamanho que couber na altura) e os cartões nos cantos.
func _multi_layout() -> void:
	var area := MultiPick.content_rect(get_viewport())
	var rows := ceili(_tiles.size() / float(MULTI_COLUMNS))
	var tile := clampf(floorf((area.size.y - MULTI_TILE_GAP * (rows - 1)) / rows), 80.0, 140.0)
	for t in _tiles:
		t.custom_minimum_size = Vector2(tile, tile)
	var grid_size := Vector2(tile * MULTI_COLUMNS + MULTI_TILE_GAP * (MULTI_COLUMNS - 1),
			tile * rows + MULTI_TILE_GAP * (rows - 1))
	grid.position = area.position + (area.size - grid_size) * 0.5
	grid.size = grid_size
	var rects := MultiPick.card_rects(_panels.size(), area, grid_size.x + 2.0 * (MULTI_TILE_GAP + 16.0))
	for p in _panels.size():
		_panels[p].position = rects[p].position
		_panels[p].size = rects[p].size


func _multi_move(p: int, dir: Vector2i) -> void:
	var next := _step_index(_cursors[p], dir.x + dir.y * _columns)
	if next < 0:
		return
	Sfx.play(self, &"ui_move", -12.0)
	_set_cursor(p, next)


func _set_cursor(p: int, i: int) -> void:
	_cursors[p] = i
	_bump(_tiles[i])
	_panels[p].bump()
	_refresh_multi(false)


## Atualiza cursores na grade e todos os cartões (escolher um piloto pode recolorir o
## de outro jogador que pegou o mesmo).
func _refresh_multi(first: bool) -> void:
	for p in _panels.size():
		var tile := _tiles[_cursors[p]]
		if tile.is_unlocked():
			GameState.players[p].character_index = _cursors[p]
	for t in _tiles.size():
		var here: Array[int] = []
		var ready: Array[bool] = []
		for p in _cursors.size():
			if _cursors[p] == t:
				here.append(p)
				ready.append(_multi.confirmed[p])
		_tiles[t].set_cursors(here, ready)
	for p in _panels.size():
		var panel := _panels[p]
		var tile := _tiles[_cursors[p]]
		var unlocked := tile.is_unlocked()
		panel.title.text = tile.data.display_name
		panel.detail.text = tile.data.tagline
		(panel.extra.get_node("Atributos") as StatBars).set_stats(_stats_of(tile.data) if unlocked else {}, not first)
		panel.set_placeholder("" if unlocked else "?")
		var data := GameState.get_player_character(p) if unlocked else null
		var rig := _rigs[p]
		if is_instance_valid(rig) and rig.data == data:
			continue
		if is_instance_valid(rig):
			rig.queue_free()
		_rigs[p] = _spawn_rig(data, panel.stage.turntable, first) if data else null


func _multi_confirm(p: int) -> void:
	var tile := _tiles[_cursors[p]]
	if not tile.is_unlocked():
		_reject_locked(tile)
		return
	GameState.players[p].character_index = _cursors[p]
	_multi.set_ready(p, true)
	_panels[p].confirmed = true
	Sfx.play(self, &"ui_accept", -8.0)
	_cheer(_rigs[p])
	_refresh_multi(false)
	if not _multi.confirmed.has(false):
		_show_toast("Todos prontos!")


func _multi_unconfirm(p: int) -> void:
	_panels[p].confirmed = false
	Sfx.play(self, &"ui_back", -10.0)
	if is_instance_valid(_rigs[p]):
		_rigs[p].set_face(&"face_happy")
	_refresh_multi(false)


func _on_panel_clicked(p: int) -> void:
	if _multi.locked or p != _multi.mouse_player():
		return
	if _multi.confirmed[p]:
		_multi.set_ready(p, false)
		_multi_unconfirm(p)
	else:
		_multi_confirm(p)


func _multi_back() -> void:
	Sfx.play(self, &"ui_back", -10.0)
	GameState.goto_scene(GameState.SCENE_MODE_SELECT)


func _multi_done() -> void:
	GameState.goto_scene(GameState.SCENE_KART_SELECT)
