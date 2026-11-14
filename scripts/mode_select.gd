extends Control
## Tela "Modo de jogo": Grand Prix, Corrida ou Contra-relógio, quantos jogadores (até
## 4, um por controle conectado mais o teclado), cilindrada (50/100/150cc),
## dificuldade e adversários. Com 2 ou mais jogadores o painel "Quem vai jogar?"
## pergunta qual controle é de quem; depois cada um escolhe piloto e kart.

const MODES := [
	{
		"title": "Grand Prix",
		"subtitle": "4 corridas  •  pontos  •  troféu",
		"description": "A Copa Ativos inteira: as 4 pistas em sequência contra o computador. Cada chegada vale pontos (15, 12, 10…) e quem somar mais leva a copa.",
		"icon": "trophy",
		"color": Color("e08a00"),
	},
	{
		"title": "Corrida",
		"subtitle": "uma pista à sua escolha",
		"description": "Uma corrida avulsa na pista que você escolher. Bom para treinar uma pista ou para um racha rápido com os amigos.",
		"icon": "flag",
		"color": Color("2b62ee"),
	},
	{
		"title": "Contra-relógio",
		"subtitle": "sem adversários  •  fantasma",
		"description": "Só você e o relógio. O seu melhor percurso em cada pista vira um kart fantasma, que corre junto na próxima vez para você bater.",
		"icon": "clock",
		"color": Color("7a3fe0"),
	},
]
const CLASS_HINTS := [
	"50cc: bem mais devagar, ótimo para quem está começando.",
	"100cc: a velocidade normal do jogo (os recordes de sempre).",
	"150cc: bem mais rápido. Drift nas curvas fechadas ou parede!",
]
const DIFFICULTY_HINTS := [
	"Fácil: os adversários erram mais e correm devagar.",
	"Normal: uma disputa equilibrada.",
	"Difícil: os adversários são rápidos e quase não erram.",
]

@onready var root: Control = $UI/Root
@onready var header: RibbonLabel = %Header

var _cards: Array[ModeCard] = []
var _players: OptionSelector
var _class: OptionSelector
var _difficulty: OptionSelector
var _rivals: OptionSelector
var _options_box: VBoxContainer
var _hint: Label
var _devices_label: Label
var _back_button: FancyButton
var _continue_button: FancyButton
var _join: JoinPanel
var _hints_bar: HintBar
var _mode := 0
var _leaving := false


func _ready() -> void:
	_mode = GameState.mode
	_build()
	Input.joy_connection_changed.connect(_on_joy_changed)
	_update_player_limit()
	_select_mode(_mode, true)
	_cards[_mode].grab_focus()
	_animate_intro()


func _build() -> void:
	var cards := HBoxContainer.new()
	cards.position = Vector2(54, 102)
	cards.add_theme_constant_override("separation", 26)
	root.add_child(cards)
	for i in MODES.size():
		var m: Dictionary = MODES[i]
		var card := ModeCard.new()
		card.setup(m.title, m.subtitle, m.description, m.icon, m.color)
		card.focus_entered.connect(_select_mode.bind(i, false))
		card.pressed.connect(_on_card_pressed.bind(i))
		cards.add_child(card)
		_cards.append(card)

	_options_box = VBoxContainer.new()
	_options_box.position = Vector2(64, 372)
	_options_box.add_theme_constant_override("separation", 8)
	root.add_child(_options_box)
	_players = _add_option("Jogadores", PackedStringArray(["1 jogador", "2 jogadores", "3 jogadores", "4 jogadores"]),
			GameState.players.size() - 1)
	_class = _add_option("Cilindrada", PackedStringArray(["50cc", "100cc", "150cc"]), GameState.speed_class)
	_difficulty = _add_option("Dificuldade", PackedStringArray(GameState.DIFFICULTY_NAMES), GameState.difficulty)
	_rivals = _add_option("Adversários", PackedStringArray(["Com o computador", "Sem adversários"]),
			0 if GameState.cpu_enabled else 1)

	var side := VBoxContainer.new()
	side.position = Vector2(700, 372)
	side.custom_minimum_size = Vector2(520, 0)
	side.add_theme_constant_override("separation", 14)
	root.add_child(side)
	var info := PanelContainer.new()
	info.custom_minimum_size = Vector2(520, 116)
	side.add_child(info)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)
	info.add_child(info_box)
	_hint = Label.new()
	_hint.theme_type_variation = &"PanelLabel"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 18)
	info_box.add_child(_hint)
	_devices_label = Label.new()
	_devices_label.theme_type_variation = &"PanelSoft"
	_devices_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_devices_label.add_theme_font_size_override("font_size", 15)
	info_box.add_child(_devices_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 26)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	side.add_child(buttons)
	_back_button = _make_button("Voltar", "back", false)
	_continue_button = _make_button("Continuar", "next", true)
	buttons.add_child(_back_button)
	buttons.add_child(_continue_button)
	_back_button.pressed.connect(_back)
	_continue_button.pressed.connect(_continue)

	_hints_bar = HintBar.new()
	_hints_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hints_bar.offset_top = -48.0
	_hints_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints_bar.hints = PackedStringArray(["↑  ↓|Navegar", "←  →|Trocar", "Enter|Confirmar", "Esc|Voltar"])
	root.add_child(_hints_bar)

	_join = JoinPanel.new()
	root.add_child(_join)
	_join.completed.connect(_on_join_completed)
	_join.cancelled.connect(func(): _continue_button.grab_focus())

	for o: OptionSelector in [_players, _class, _difficulty, _rivals]:
		o.changed.connect(func(_i): _update_hint(o))
		o.focus_entered.connect(_update_hint.bind(o))


func _add_option(caption: String, values: PackedStringArray, index: int) -> OptionSelector:
	var o := OptionSelector.new()
	o.setup(caption, values, index)
	_options_box.add_child(o)
	return o


func _make_button(text: String, icon: String, primary: bool) -> FancyButton:
	var b := FancyButton.new()
	b.text = text
	b.icon_kind = icon
	b.primary = primary
	b.custom_minimum_size = Vector2(230, 62)
	return b


# --- Modos e opções -------------------------------------------------------------------

func _select_mode(i: int, first: bool) -> void:
	_mode = i
	for k in _cards.size():
		_cards[k].selected = k == i
	# Contra-relógio não tem adversários (nem dificuldade); a Corrida pode ter ou não.
	_difficulty.visible = i != GameState.Mode.TIME_TRIAL
	_rivals.visible = i == GameState.Mode.VERSUS
	_update_focus_chain()
	_update_hint(_players if first else null)


func _on_card_pressed(i: int) -> void:
	_select_mode(i, false)
	_continue()


## Liga o foco: cartões ↔ opções (só as visíveis) ↔ botões.
func _update_focus_chain() -> void:
	var opts: Array[OptionSelector] = []
	for o: OptionSelector in [_players, _class, _difficulty, _rivals]:
		if o.visible:
			opts.append(o)
	for k in _cards.size():
		var card := _cards[k]
		card.focus_neighbor_bottom = card.get_path_to(opts[0])
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_left = card.get_path_to(_cards[k - 1]) if k > 0 else card.get_path()
		card.focus_neighbor_right = card.get_path_to(_cards[k + 1]) if k < _cards.size() - 1 else card.get_path()
	for k in opts.size():
		var o := opts[k]
		o.focus_neighbor_top = o.get_path_to(opts[k - 1]) if k > 0 else o.get_path_to(_cards[_mode])
		o.focus_neighbor_bottom = o.get_path_to(opts[k + 1]) if k < opts.size() - 1 else o.get_path_to(_continue_button)
		o.focus_neighbor_left = o.get_path()
		o.focus_neighbor_right = o.get_path()
	for b: Control in [_back_button, _continue_button]:
		b.focus_neighbor_top = b.get_path_to(opts[opts.size() - 1])
		b.focus_neighbor_bottom = b.get_path()
	_back_button.focus_neighbor_right = _back_button.get_path_to(_continue_button)
	_continue_button.focus_neighbor_left = _continue_button.get_path_to(_back_button)
	_back_button.focus_neighbor_left = _back_button.get_path()
	_continue_button.focus_neighbor_right = _continue_button.get_path()


func _update_hint(source: OptionSelector) -> void:
	var text := ""
	if source == _class:
		text = CLASS_HINTS[_class.index]
	elif source == _difficulty:
		text = DIFFICULTY_HINTS[_difficulty.index]
	elif source == _rivals:
		var n := GameState.RACE_SIZE - (_players.index + 1)
		text = "Corrida contra %d pilotos do computador." % n if _rivals.index == 0 else "Só os jogadores na pista."
	elif source == _players:
		text = "Sozinho, em tela cheia." if _players.index == 0 else \
				"Tela dividida para %d jogadores, um controle para cada (o teclado também vale)." % (_players.index + 1)
	else:
		text = MODES[_mode].description
	_hint.text = text


## Até 4 jogadores: um por controle conectado, mais o teclado.
func _update_player_limit() -> void:
	var pads := Input.get_connected_joypads().size()
	_players.limit = mini(GameState.MAX_PLAYERS, pads + 1)
	var text := ""
	match pads:
		0:
			text = "Nenhum controle conectado: só dá para jogar sozinho, no teclado."
		1:
			text = "1 controle conectado (+ teclado): até 2 jogadores."
		_:
			text = "%d controles conectados (+ teclado): até %d jogadores." % [pads, mini(pads + 1, GameState.MAX_PLAYERS)]
	if OS.has_feature("web"):
		text += " No navegador, aperte um botão no controle para ele aparecer."
	_devices_label.text = text


func _on_joy_changed(_device: int, _connected: bool) -> void:
	_update_player_limit()


# --- Seguir / voltar ----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _leaving or _join.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _continue() -> void:
	if _leaving or _join.visible:
		return
	GameState.mode = _mode
	GameState.speed_class = _class.index
	GameState.difficulty = _difficulty.index
	GameState.cpu_enabled = _rivals.index == 0
	GameState.grand_prix = null
	var count := _players.index + 1
	if count <= 1:
		var none: Array[int] = []
		_go(none)
	else:
		Sfx.play(self, &"ui_accept", -8.0)
		_join.open(count)


func _on_join_completed(devices: Array[int]) -> void:
	_go(devices)


func _go(devices: Array[int]) -> void:
	_leaving = true
	GameState.set_players(devices)
	GameState.goto_scene(GameState.SCENE_CHARACTER_SELECT)


func _back() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play(self, &"ui_back", -10.0)
	GameState.goto_scene(GameState.SCENE_MAIN_MENU)


func _animate_intro() -> void:
	await get_tree().process_frame
	var delay := 0.05
	for card in _cards:
		card.pivot_offset = card.size * 0.5
		var target := card.scale
		card.scale = target * 0.6
		card.modulate.a = 0.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", target, 0.35).set_delay(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		delay += 0.07
	var x := _options_box.position.x
	_options_box.position.x = x - 640.0
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_options_box, "position:x", x, 0.45).set_delay(0.12)
