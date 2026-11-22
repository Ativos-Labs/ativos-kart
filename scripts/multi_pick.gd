class_name MultiPick
extends Node
## Escolha simultânea do multijogador nas telas de piloto, kart e asa-delta: todos
## escolhem ao mesmo tempo, cada um no seu controle (ou no teclado).
##
## Descobre de qual jogador é cada botão, guarda quem já confirmou e avisa a tela:
## direcional/analógico → `moved`; A (Enter, Start) → `confirm_requested` (a tela
## confere e chama `set_ready`); B (Esc) de quem confirmou desfaz (`unconfirmed`) e
## de quem ainda não confirmou volta para a tela anterior (`back_requested`). Com todos
## prontos, `all_ready` sai depois de um instante (dá tempo de alguém desfazer).
##
## O mouse e o teclado valem pelo jogador do teclado (ou pelo J1, se ninguém usa o
## teclado).

signal moved(player: int, dir: Vector2i)
signal confirm_requested(player: int)
signal unconfirmed(player: int)
signal back_requested
signal all_ready

## Intervalo mínimo entre dois passos do mesmo jogador (s).
const NAV_COOLDOWN := 0.12
## Todos prontos: espera antes de seguir (s).
const ALL_READY_DELAY := 0.8
## Margens da área dos cartões (unidades de interface): título em cima, dicas embaixo.
const MARGIN_SIDE := 30.0
const MARGIN_TOP := 98.0
const MARGIN_BOTTOM := 64.0
const GAP := 18.0

## Quem já confirmou (um por jogador).
var confirmed: Array[bool] = []
## Saindo da tela: ignora tudo.
var locked := false
## Espera depois de todos confirmarem (s). A tela pode aumentar (a seleção de personagem
## espera o último a confirmar terminar a comemoração).
var ready_delay := ALL_READY_DELAY

var _cooldown := PackedFloat32Array()
var _timer: SceneTreeTimer


func _ready() -> void:
	confirmed.resize(GameState.players.size())
	confirmed.fill(false)
	_cooldown.resize(GameState.players.size())


func _process(delta: float) -> void:
	for i in _cooldown.size():
		_cooldown[i] -= delta


func _input(event: InputEvent) -> void:
	# O analógico chega como ui_left/ui_right... (MenuInput), um passo por vez.
	if locked or event is InputEventJoypadMotion:
		return
	var dir := Vector2i.ZERO
	if event.is_action_pressed("ui_left") or event.is_action_pressed("esquerda"):
		dir = Vector2i.LEFT
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("direita"):
		dir = Vector2i.RIGHT
	elif event.is_action_pressed("ui_up"):
		dir = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		dir = Vector2i.DOWN
	var accept: bool = event.is_action_pressed("ui_accept") \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	var cancel: bool = event.is_action_pressed("ui_cancel")
	if dir == Vector2i.ZERO and not accept and not cancel:
		return
	get_viewport().set_input_as_handled()
	var p := player_for(event)
	if p < 0:
		return
	if dir != Vector2i.ZERO:
		if not confirmed[p] and _cooldown[p] <= 0.0:
			_cooldown[p] = NAV_COOLDOWN
			moved.emit(p, dir)
	elif accept:
		if not confirmed[p]:
			confirm_requested.emit(p)
	elif confirmed[p]:
		set_ready(p, false)
		unconfirmed.emit(p)
	else:
		locked = true
		back_requested.emit()


## Jogador dono do evento (-1 = um controle que não é de ninguém).
func player_for(event: InputEvent) -> int:
	var device := -99
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		device = event.device
	elif event is InputEventAction:
		# Analógico e direcional segurado (MenuInput manda o id do controle).
		device = event.device
	elif event is InputEventKey or event is InputEventMouse:
		return mouse_player()
	for i in GameState.players.size():
		if GameState.players[i].device == device:
			return i
	return -1


## Jogador do teclado e do mouse: quem joga no teclado, ou o J1.
func mouse_player() -> int:
	for i in GameState.players.size():
		if GameState.players[i].device == PlayerSlot.DEVICE_KEYBOARD:
			return i
	return 0


func set_ready(p: int, on: bool) -> void:
	confirmed[p] = on
	if not on or confirmed.has(false):
		_timer = null
		return
	var timer := get_tree().create_timer(ready_delay)
	_timer = timer
	await timer.timeout
	if _timer == timer and not locked and not confirmed.has(false):
		locked = true
		all_ready.emit()


## Área dos cartões dos jogadores (entre o título e a barra de dicas).
static func content_rect(vp: Viewport) -> Rect2:
	var full := vp.get_visible_rect()
	return Rect2(full.position + Vector2(MARGIN_SIDE, MARGIN_TOP),
			full.size - Vector2(MARGIN_SIDE * 2.0, MARGIN_TOP + MARGIN_BOTTOM))


## Cartões dos jogadores em `area`: 2 lado a lado (altos); 3 ou 4 em quadrantes
## (J1 J2 em cima, J3 J4 embaixo). `center_gap`: largura livre entre as duas colunas
## (a grade de pilotos fica nela).
static func card_rects(count: int, area: Rect2, center_gap := 0.0) -> Array[Rect2]:
	var rows := 1 if count <= 2 else 2
	var gap_x := maxf(center_gap, GAP)
	var cell := Vector2((area.size.x - gap_x) * 0.5, (area.size.y - GAP * (rows - 1)) / rows)
	var out: Array[Rect2] = []
	for i in count:
		var col := i % 2
		var row := i / 2
		out.append(Rect2(area.position + Vector2(col * (cell.x + gap_x), row * (cell.y + GAP)), cell))
	return out
