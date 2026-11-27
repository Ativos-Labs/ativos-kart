extends Node
## Tela de copas, antes da de pistas: um cartão por copa (CupCard: emblema, nome e as
## fotos das pistas dela numa grade 2×2), com as vistas aéreas das pistas da copa
## escolhida lado a lado no fundo, em colunas com linhas pretas inclinadas entre elas
## (SlantedBackdrop). ←/→ (ou clicar) escolhe, Enter/A (ou clicar de novo) confirma e
## segue para as pistas da copa (GameState.selected_cup), Esc/B volta para as asas.
## Copas que ainda não existem (até GameState.cup_slots) aparecem como "?" (em breve).
## Depois de confirmar o cartão fica marcado, o resto escurece e nenhuma entrada vale até
## a tela trocar.

## Duração da troca de uma imagem de fundo para a outra.
const FADE := 0.25

## Fundo: um painel por copa (as vistas aéreas das pistas dela), trocando com fade.
@onready var backdrop: Control = %Backdrop
@onready var cups_row: HBoxContainer = %Cups
@onready var header: RibbonLabel = %Header
@onready var subtitle: Label = %Subtitle
@onready var back_button: FancyButton = %BackButton
@onready var next_button: FancyButton = %NextButton
@onready var toast: Label = %Toast

var index := 0
var _cards: Array[CupCard] = []
## Copas com pista, na ordem da lista de pistas.
var _cup_names: Array[String] = []
var _nav_cooldown := 0.0
var _confirming := false
var _toast_tween: Tween
## Copa → painel do fundo (montado na primeira vez que ela aparece) e o que está na tela.
var _panels := {}
var _shown: Control
## Caminho → [painel, faixa] do fundo esperando a thread carregar aquela vista aérea.
var _waiting := {}
## Caminho → imagem de fundo já carregada; e os caminhos pedidos à thread de carga.
var _backgrounds := {}
var _loading := {}


func _ready() -> void:
	for t in GameState.tracks:
		if not _cup_names.has(t.cup_name):
			_cup_names.append(t.cup_name)
	_build_cards()
	back_button.pressed.connect(_back)
	next_button.pressed.connect(_confirm)
	toast.modulate.a = 0.0
	if GameState.mode == GameState.Mode.GRAND_PRIX:
		subtitle.text = "Grand Prix: as pistas da copa em sequência, valendo pontos"
	else:
		subtitle.text = "Escolha a copa e depois a pista"
	var current := GameState.selected_cup
	if current == "":
		var track := GameState.get_selected_track()
		current = track.cup_name if track else ""
	_select(maxi(_cup_names.find(current), 0), true)
	_request_backgrounds()
	next_button.grab_focus()
	_animate_intro()


func _exit_tree() -> void:
	# Carga pedida e não recolhida fica presa no ResourceLoader.
	for path: String in _loading:
		ResourceLoader.load_threaded_get(path)
	_loading.clear()


func _build_cards() -> void:
	for i in maxi(GameState.cup_slots, _cup_names.size()):
		var unlocked := i < _cup_names.size()
		var tracks: Array[TrackData] = []
		if unlocked:
			for t in GameState.tracks:
				if t.cup_name == _cup_names[i]:
					tracks.append(t)
		while tracks.size() < GameState.track_slots:
			var placeholder := TrackData.new()
			placeholder.display_name = "???"
			placeholder.locked = true
			tracks.append(placeholder)
		var card := CupCard.new()
		card.setup(_cup_names[i] if unlocked else "???", unlocked, tracks)
		card.pressed.connect(_on_card_pressed.bind(i))
		cups_row.add_child(card)
		_cards.append(card)


# --- Fundo -------------------------------------------------------------------------

## Vistas aéreas das pistas da copa `i` (as que têm imagem).
func _background_paths(i: int) -> Array[String]:
	var paths: Array[String] = []
	if i < _cup_names.size():
		for t in _cards[i].tracks:
			if t.is_unlocked() and t.background != "":
				paths.append(t.background)
	return paths


## Pede à thread as vistas aéreas das outras copas.
func _request_backgrounds() -> void:
	for i in _cards.size():
		for path in _background_paths(i):
			if not _backgrounds.has(path) and not _loading.has(path):
				if ResourceLoader.load_threaded_request(path) == OK:
					_loading[path] = true


func _process(delta: float) -> void:
	_nav_cooldown -= delta
	for path: String in _loading.keys():
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_loaded(path, ResourceLoader.load_threaded_get(path))


func _loaded(path: String, texture: Texture2D) -> void:
	_loading.erase(path)
	_backgrounds[path] = texture
	for slot: Array in _waiting.get(path, []):
		if is_instance_valid(slot[0]):
			(slot[0] as SlantedBackdrop).set_texture(slot[1], texture)
	_waiting.erase(path)


## Painel do fundo da copa `i` (SlantedBackdrop: as vistas aéreas lado a lado, em colunas
## com linhas pretas inclinadas entre elas). `now`: carrega já as que faltam (a
## primeira copa da tela, atrás do fade); senão elas entram quando a thread terminar.
func _panel(i: int, now: bool) -> Control:
	if _panels.has(i):
		return _panels[i]
	var panel := SlantedBackdrop.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var paths := _background_paths(i)
	panel.set_count(paths.size())
	for k in paths.size():
		var path := paths[k]
		if not _backgrounds.has(path) and now:
			if _loading.has(path):
				_loaded(path, ResourceLoader.load_threaded_get(path))
			else:
				_backgrounds[path] = load(path)
		if _backgrounds.has(path):
			panel.set_texture(k, _backgrounds[path])
		else:
			if not _waiting.has(path):
				_waiting[path] = []
			_waiting[path].append([panel, k])
	_panels[i] = panel
	backdrop.add_child(panel)
	panel.visible = false
	return panel


## Troca o fundo para o da copa `i`: o painel novo aparece por cima do atual (na
## primeira, na hora). Copa sem nenhuma vista aérea deixa o fundo como está.
func _show_backdrop(i: int, instant: bool) -> void:
	if _background_paths(i).is_empty():
		return
	var panel := _panel(i, instant)
	if panel == _shown:
		return
	var old := _shown
	_shown = panel
	backdrop.move_child(panel, -1)
	panel.visible = true
	panel.modulate.a = 0.0 if not instant else 1.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.0 if instant else FADE)
	tw.tween_callback(func() -> void:
		if is_instance_valid(old) and old != _shown:
			old.visible = false)


# --- Navegação ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# O analógico chega como ui_left/ui_right (MenuInput), um passo por vez.
	if event is InputEventJoypadMotion:
		return
	if _confirming:
		# Copa escolhida, esperando a tela de pistas: nenhuma entrada chega à tela.
		get_viewport().set_input_as_handled()
		return
	var move := 0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("esquerda"):
		move = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("direita"):
		move = 1
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
	Sfx.play(self, &"ui_move", -12.0)
	_select(wrapi(index + step, 0, _cards.size()), false)


func _on_card_pressed(i: int) -> void:
	if _confirming:
		return
	if i == index:
		_confirm()
	else:
		Sfx.play(self, &"ui_move", -12.0)
		_select(i, false)


func _select(i: int, first: bool) -> void:
	index = i
	for k in _cards.size():
		_cards[k].selected = k == index
	var card := _cards[index]
	next_button.disabled = not card.unlocked
	_show_backdrop(index, first)
	if not first:
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * 1.06
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(card, "scale", Vector2.ONE, 0.25)


func _confirm() -> void:
	if _confirming:
		return
	var card := _cards[index]
	if not card.unlocked:
		_show_toast("Novas copas em breve!")
		Sfx.play(self, &"ui_back", -10.0)
		_shake(card)
		return
	_confirming = true
	GameState.selected_cup = card.cup_name
	Sfx.play(self, &"ui_accept", -8.0)
	_show_toast("%s!" % card.cup_name)
	card.picked = true
	next_button.picked = true
	var others: Array = [back_button]
	for k in _cards.size():
		if k != index:
			others.append(_cards[k])
	UiKit.dim(self, others, true)
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 1.1
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(card, "scale", Vector2.ONE * 1.03, 0.3)
	await get_tree().create_timer(0.5).timeout
	GameState.goto_scene(GameState.SCENE_TRACK_SELECT)


func _back() -> void:
	if _confirming:
		return
	Sfx.play(self, &"ui_back", -10.0)
	GameState.goto_scene(GameState.SCENE_GLIDER_SELECT)


# --- Animações ---------------------------------------------------------------------

func _animate_intro() -> void:
	await get_tree().process_frame
	var delay := 0.05
	for card in _cards:
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * 0.6
		card.modulate.a = 0.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_delay(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		delay += 0.07


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
