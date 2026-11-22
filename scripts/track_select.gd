extends Node
## Tela de seleção de pista: ao fundo, a vista aérea da pista escolhida (uma imagem
## pronta), com as copas (a Copa Ativos traz o logo "at"), os cartões das pistas,
## o mapa do traçado, os recordes e o botão para correr. Vagas sem pista ainda
## aparecem como "?" (em breve).
## No Grand Prix a escolha é da copa: dá para olhar cada pista, e "Começar copa"
## corre todas em sequência, a partir da primeira.
##
## Nada aqui é 3D: o fundo e as fotos dos cartões são imagens geradas antes por
## tools/track_shots/gerar.sh, e o mapa e os números só precisam do traçado (~1 ms
## por pista). Gerar a pista de verdade travava a tela a cada troca.

const COLUMNS := 2
const CAPTIONS := {
	"length": "EXTENSÃO",
	"laps": "VOLTAS",
	"turns": "CURVAS",
	"difficulty": "DIFICULDADE",
	"record": "RECORDE",
	"lap": "MELHOR VOLTA",
}

## Duração da troca de uma imagem de fundo para a outra.
const FADE := 0.25

@onready var background: TextureRect = %Background
## Imagem nova aparecendo por cima da atual.
@onready var background_next: TextureRect = %BackgroundNext
@onready var cups_row: HBoxContainer = %Cups
@onready var cup_ribbon: RibbonLabel = %CupRibbon
@onready var grid: GridContainer = %Grid
@onready var info_panel: Control = %InfoPanel
@onready var track_name_label: Label = %TrackName
@onready var subtitle_label: Label = %TrackSubtitle
@onready var preview: TrackPreview = %Preview
@onready var stats_grid: GridContainer = %Stats
@onready var description_label: Label = %Description
@onready var back_button: FancyButton = %BackButton
@onready var race_button: FancyButton = %RaceButton
@onready var toast: Label = %Toast

var index := 0
var _slots: Array[TrackData] = []
var _cards: Array[TrackCard] = []
var _cups: Array[CupBadge] = []
## TrackData → Track fora da árvore, só com o traçado (`prepare_layout`).
var _layouts := {}
## Caminho → imagem de fundo já carregada; e os caminhos pedidos à thread de carga.
var _backgrounds := {}
var _loading := {}
var _bg_tween: Tween
var _stat_values := {}
var _stars: StarRating
var _nav_cooldown := 0.0
var _confirming := false
var _toast_tween: Tween


func _ready() -> void:
	_build_slots()
	_build_cups()
	_build_cards()
	_build_stats()
	back_button.pressed.connect(_back)
	race_button.pressed.connect(_confirm)
	toast.modulate.a = 0.0
	if _is_cup_mode():
		($UI/Root/Header as RibbonLabel).text = "ESCOLHA A COPA"
		race_button.text = "Começar copa"
	index = clampi(GameState.selected_track_index, 0, _slots.size() - 1)
	_select(index, true)
	# A imagem da pista escolhida já carregou (atrás do fade); as outras vêm numa
	# thread, para trocar de pista sem travar.
	for data in _slots:
		if data.is_unlocked() and data.background != "" and not _backgrounds.has(data.background):
			if ResourceLoader.load_threaded_request(data.background) == OK:
				_loading[data.background] = true
	race_button.grab_focus()
	_animate_intro()


func _is_cup_mode() -> bool:
	return GameState.mode == GameState.Mode.GRAND_PRIX


func _exit_tree() -> void:
	# Os traçados ficam fora da árvore: não são liberados junto com a tela.
	for track: Track in _layouts.values():
		track.free()
	_layouts.clear()
	# Carga pedida e não recolhida fica presa no ResourceLoader.
	for path: String in _loading:
		ResourceLoader.load_threaded_get(path)
	_loading.clear()


# --- Montagem ---------------------------------------------------------------------

func _build_slots() -> void:
	_slots.assign(GameState.tracks)
	while _slots.size() < GameState.track_slots:
		var placeholder := TrackData.new()
		placeholder.display_name = "???"
		placeholder.cup_name = _slots[0].cup_name if not _slots.is_empty() else "Copa Ativos"
		placeholder.locked = true
		_slots.append(placeholder)


func _build_cups() -> void:
	var names: Array[String] = []
	for t in GameState.tracks:
		if not names.has(t.cup_name):
			names.append(t.cup_name)
	for i in maxi(GameState.cup_slots, names.size()):
		var badge := CupBadge.new()
		var unlocked := i < names.size()
		badge.setup(names[i] if unlocked else "???", unlocked)
		badge.selected = i == 0
		badge.pressed.connect(_on_cup_pressed.bind(i))
		cups_row.add_child(badge)
		_cups.append(badge)
	cup_ribbon.text = (names[0] if not names.is_empty() else "Copa").to_upper()


func _build_cards() -> void:
	grid.columns = COLUMNS
	for i in _slots.size():
		var card := TrackCard.new()
		card.setup(_slots[i])
		# Foto pronta da largada (448×300, carrega em poucos ms).
		if _slots[i].is_unlocked() and _slots[i].thumbnail != "":
			card.thumbnail = load(_slots[i].thumbnail)
		card.pressed.connect(_on_card_pressed.bind(i))
		grid.add_child(card)
		_cards.append(card)


func _build_stats() -> void:
	for key: String in CAPTIONS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", -2)
		var caption := Label.new()
		caption.theme_type_variation = &"PanelSoft"
		caption.add_theme_font_size_override("font_size", 13)
		caption.text = CAPTIONS[key]
		cell.add_child(caption)
		if key == "difficulty":
			_stars = StarRating.new()
			_stars.custom_minimum_size = Vector2(124, 30)
			cell.add_child(_stars)
		else:
			var value := Label.new()
			value.theme_type_variation = &"PanelLabel"
			value.add_theme_font_override("font", UiKit.FONT_TITLE)
			value.add_theme_font_size_override("font_size", 25)
			cell.add_child(value)
			_stat_values[key] = value
		stats_grid.add_child(cell)


# --- Fundo e traçado ---------------------------------------------------------------

func _process(delta: float) -> void:
	_nav_cooldown -= delta
	# Recolhe as imagens de fundo que a thread terminou de carregar.
	for path: String in _loading.keys():
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_backgrounds[path] = ResourceLoader.load_threaded_get(path)
			_loading.erase(path)


## Vista aérea da pista (null se ela não tiver imagem). Se a thread ainda não
## terminou de carregar, espera por ela.
func _background(data: TrackData) -> Texture2D:
	var path := data.background
	if path == "":
		return null
	if not _backgrounds.has(path):
		if _loading.has(path):
			_loading.erase(path)
			_backgrounds[path] = ResourceLoader.load_threaded_get(path)
		else:
			_backgrounds[path] = load(path)
	return _backgrounds[path]


## Troca o fundo: a imagem nova aparece por cima da atual (na primeira, na hora).
func _show_background(texture: Texture2D, instant: bool) -> void:
	if _bg_tween and _bg_tween.is_valid():
		# Trocou de novo no meio da transição: a anterior termina na hora.
		_bg_tween.kill()
		background.texture = background_next.texture
	background_next.modulate.a = 0.0
	if instant or texture == background.texture:
		background.texture = texture
		return
	background_next.texture = texture
	_bg_tween = create_tween()
	_bg_tween.tween_property(background_next, "modulate:a", 1.0, FADE)
	_bg_tween.tween_callback(func() -> void:
		background.texture = texture
		background_next.modulate.a = 0.0)


## Só o traçado da pista (amostras, comprimento, curvas, turbos), para o mapa e os
## números. A pista em si (terreno, cenário...) nunca é gerada nesta tela.
func _layout(data: TrackData) -> Track:
	var track: Track = _layouts.get(data)
	if track == null:
		track = data.scene.instantiate()
		track.with_collision = false
		track.prepare_layout()
		_layouts[data] = track
	return track


# --- Navegação --------------------------------------------------------------------

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


func _move(step: int) -> void:
	if _nav_cooldown > 0.0:
		return
	_nav_cooldown = 0.12
	var next := index + step
	if absi(step) == 1:
		next = wrapi(next, 0, _cards.size())
	elif next < 0 or next >= _cards.size():
		return
	Sfx.play(self, &"ui_move", -12.0)
	_select(next, false)


func _on_card_pressed(i: int) -> void:
	if i == index:
		_confirm()
	else:
		Sfx.play(self, &"ui_move", -12.0)
		_select(i, false)


func _on_cup_pressed(i: int) -> void:
	if _cups[i].unlocked:
		return
	_show_toast("Novas copas em breve!")
	Sfx.play(self, &"ui_back", -10.0)
	_shake(_cups[i])


func _select(i: int, first: bool) -> void:
	index = i
	for k in _cards.size():
		_cards[k].selected = k == index
	var data := _slots[index]
	var unlocked := data.is_unlocked()
	# Vaga "em breve" deixa ao fundo a última pista mostrada.
	if unlocked:
		_show_background(_background(data), first)
	_update_info(data, unlocked, first)
	race_button.disabled = not unlocked
	var card := _cards[index]
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 1.08
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(card, "scale", Vector2.ONE, 0.25)


func _update_info(data: TrackData, unlocked: bool, first: bool) -> void:
	track_name_label.text = data.display_name if unlocked else "???"
	var where := "Corrida %d de %d da copa" if _is_cup_mode() else "Pista %d de %d"
	subtitle_label.text = ("%s  •  %s  •  %s" % [data.cup_name, where % [index + 1, _slots.size()],
			GameState.get_speed_class_name()]) if unlocked else "Em breve"
	var layout := _layout(data) if unlocked else null
	preview.show_track(layout, UiKit.YELLOW)
	if unlocked:
		_stat_values["length"].text = _format_meters(layout.length)
		_stat_values["laps"].text = str(data.laps)
		_stat_values["turns"].text = str(_count_turns(layout))
		_stat_values["record"].text = GameState.format_time(GameState.get_record(data.id, GameState.record_key("total")))
		_stat_values["lap"].text = GameState.format_time(GameState.get_record(data.id, GameState.record_key("lap")))
		_stars.value = data.difficulty
		description_label.text = data.description
	else:
		for key: String in _stat_values:
			_stat_values[key].text = "–"
		_stars.value = 0
		description_label.text = "Novas pistas chegam em breve. Por enquanto, o %s está pronto para correr!" % GameState.tracks[0].display_name
	if not first:
		info_panel.pivot_offset = info_panel.size * 0.5
		info_panel.scale = Vector2.ONE * 0.97
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(info_panel, "scale", Vector2.ONE, 0.22)


func _confirm() -> void:
	if _confirming:
		return
	var data := _slots[index]
	if not data.is_unlocked():
		_show_toast("Essa pista chega em breve!")
		Sfx.play(self, &"ui_back", -10.0)
		_shake(_cards[index])
		return
	_confirming = true
	GameState.selected_track_index = GameState.tracks.find(data)
	GameState.laps = data.laps
	Sfx.play(self, &"go", -10.0)
	if _is_cup_mode():
		GameState.start_grand_prix(data.cup_name)
		_show_toast("%s: %d corridas!" % [data.cup_name, GameState.grand_prix.race_count()])
	else:
		_show_toast("Rumo ao %s!" % data.display_name)
	var card := _cards[index]
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card.scale = Vector2.ONE * 1.15
	tw.tween_property(card, "scale", Vector2.ONE, 0.35)
	await get_tree().create_timer(0.7).timeout
	GameState.goto_scene(GameState.SCENE_RACE)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	GameState.goto_scene(GameState.SCENE_GLIDER_SELECT)


# --- Utilidades ---------------------------------------------------------------------

## Quantas curvas a pista tem (trechos com raio menor que ~80 m). Num "S",
## cada lado conta como uma curva.
static func _count_turns(track: Track) -> int:
	var count := track.curvature.size()
	var step := track.length / maxi(count, 1)
	# Começa num trecho reto para não contar a mesma curva duas vezes na emenda.
	var offset := 0
	for i in count:
		if absf(track.curvature[i]) < 0.008:
			offset = i
			break
	var turns := 0
	var side := 0.0
	var run := 0.0
	for k in count:
		var c := track.curvature[(k + offset) % count]
		var s := signf(c) if absf(c) > 0.012 else (side if absf(c) > 0.008 else 0.0)
		if s != side:
			if side != 0.0 and run > 6.0:
				turns += 1
			side = s
			run = 0.0
		run += step
	if side != 0.0 and run > 6.0:
		turns += 1
	return turns


static func _format_meters(meters: float) -> String:
	var digits := str(int(round(meters)))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return out + " m"


func _animate_intro() -> void:
	await get_tree().process_frame
	var delay := 0.05
	for card in _cards:
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * 0.5
		card.modulate.a = 0.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_delay(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		delay += 0.06
	for badge in _cups:
		badge.pivot_offset = badge.size * 0.5
		badge.scale = Vector2.ZERO
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(badge, "scale", Vector2.ONE, 0.3).set_delay(delay * 0.5)
		delay += 0.04
	var x := info_panel.position.x
	info_panel.position.x = x + 560.0
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(info_panel, "position:x", x, 0.45)


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
