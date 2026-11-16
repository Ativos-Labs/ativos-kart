extends Node3D
## Tela de seleção de personagem: grade de retratos, personagem 3D no palco
## (acena, sorri, comemora ao confirmar), nome, atributos e dicas de teclas.
## No multijogador cada jogador escolhe na vez dele (etiqueta "J2" no topo); quem
## repete um personagem já escolhido corre com ele recolorido na cor do jogador.

const COLUMNS := 4

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
var _tag: PlayerTag


func _ready() -> void:
	_build_grid()
	back_button.pressed.connect(_back)
	confirm_button.pressed.connect(_confirm)
	toast.modulate.a = 0.0
	if GameState.is_multiplayer():
		_tag = PlayerTag.new()
		$UI/Root.add_child(_tag)
		_tag.position = Vector2(header.position.x + header.size.x + 14.0, header.position.y + 3.0)
	GameState.picking_player = clampi(GameState.picking_player, 0, GameState.players.size() - 1)
	_start_turn(true)


## Começa a vez do jogador que está escolhendo (GameState.picking_player).
func _start_turn(first: bool) -> void:
	var slot := _slot()
	index = clampi(slot.character_index, 0, maxi(GameState.characters.size() - 1, 0))
	if _tag:
		_tag.setup_slot(slot, slot.device_name())
		header.accent = slot.color
		header.queue_redraw()
		_tag.pivot_offset = Vector2(43, 25)
		_tag.scale = Vector2.ONE * 1.3
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_tag, "scale", Vector2.ONE, 0.3)
	if is_instance_valid(_rig):
		_rig.queue_free()
		_rig = null
	_select(index, first)


func _slot() -> PlayerSlot:
	return GameState.players[GameState.picking_player]


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
	if _confirming or event is InputEventJoypadMotion:
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
	var count := _tiles.size()
	var next := index + step
	if absi(step) == 1:
		next = wrapi(next, 0, count)
	elif next < 0 or next >= count:
		return
	Sfx.play(self, &"ui_move", -12.0)
	_select(next, false)


func _on_tile_pressed(i: int) -> void:
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
	description_label.text = data.description if unlocked else "Novos pilotos chegam em breve. Por enquanto, o Celerino está pronto para correr!"
	stats.set_stats({"speed": data.speed, "acceleration": data.acceleration, "handling": data.handling, "weight": data.weight}
			if unlocked else {}, not first)
	confirm_button.disabled = not unlocked
	locked_mark.visible = not unlocked
	if unlocked:
		# A escolha já vale (para mostrar o personagem recolorido se for repetido).
		_slot().character_index = index
	_show_rig(GameState.get_player_character(GameState.picking_player) if unlocked else null, first)
	_tint_background(data.color if unlocked else Color(0.3, 0.36, 0.5), data.color_dark if unlocked else Color(0.08, 0.1, 0.18), first)

	# Pulinho do quadradinho escolhido.
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
	_rig = data.instantiate_rig()
	_rig.setup_stand(data.showcase_scale)
	turntable.add_child(_rig)
	_rig.scale = Vector3.ONE * 0.6
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rig, "scale", Vector3.ONE, 0.35)
	_rig.set_face(&"face_happy")
	_rig.play_gesture(&"gesture_wave", 1.6, 2)
	if not first:
		_rig.bounce(1.0)


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
		_show_toast("Esse piloto chega em breve!")
		Sfx.play(self, &"ui_back", -10.0)
		_shake(tile)
		return
	_confirming = true
	_slot().character_index = index
	Sfx.play(self, &"ui_accept", -8.0)
	if is_instance_valid(_rig):
		_rig.set_face(&"face_surprised", 0.35)
		_rig.play_gesture(&"gesture_cheer", 2.0)
		_rig.bounce(1.4)
	var who := "%s: " % _slot().tag if _tag else ""
	_show_toast("%s%s está pronto!" % [who, tile.data.display_name])
	await get_tree().create_timer(0.85).timeout
	if GameState.picking_player < GameState.players.size() - 1:
		# Vez do próximo jogador.
		GameState.picking_player += 1
		_confirming = false
		_start_turn(false)
		return
	GameState.picking_player = 0
	GameState.goto_scene(GameState.SCENE_KART_SELECT)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	if GameState.picking_player > 0:
		GameState.picking_player -= 1
		_start_turn(false)
		return
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
