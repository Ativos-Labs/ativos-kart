class_name MenuInput
extends Node
## Controle nos menus (filho do GameState, vale em todas as telas e na pausa).
##
## O Godot 4 não liga o controle direito nas ações de interface: `ui_accept` e
## `ui_cancel` vêm só com teclas (o project.godot acrescenta A e B), e o analógico em
## `ui_left`/`ui_right`/`ui_up`/`ui_down` anda um item a cada tremidinha do eixo.
## Por isso o analógico saiu dessas ações (lá ficou só o direcional) e este nó lê o
## analógico esquerdo de cada controle e manda as ações `ui_*` como se fossem teclas:
## um passo ao inclinar e repetição enquanto segura. O direcional também repete
## (botão de controle não repete sozinho, como as setas do teclado).
##
## Também guarda se o último aparelho usado foi um controle, para as dicas de botões
## da tela (HintBar) mostrarem A/B em vez de Enter/Esc.

signal device_changed(using_pad: bool)

## Inclinação do analógico para contar como apertado e para soltar (a folga entre
## os dois evita passos repetidos com o analógico tremendo perto do limite).
const PRESS := 0.6
const RELEASE := 0.35
## Segurando: espera antes de repetir e intervalo entre as repetições. O intervalo
## fica acima da trava de 0,12 s das telas de escolha, senão metade dos passos se perde.
const REPEAT_DELAY := 0.4
const REPEAT_RATE := 0.13

const ACTIONS := {
	Vector2i.LEFT: &"ui_left",
	Vector2i.RIGHT: &"ui_right",
	Vector2i.UP: &"ui_up",
	Vector2i.DOWN: &"ui_down",
}

## O último aparelho usado foi um controle (e não teclado ou mouse).
var using_pad := false

## Direção segurada em cada controle (id do controle -> _Held).
var _held := {}


class _Held:
	var dir := Vector2i.ZERO
	var from_dpad := false
	## Já mandou alguma ação `ui_*` por esta direção (precisa mandar a soltura depois).
	var sent := false
	var timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# O sinal da janela chega antes das telas, que podem marcar o evento como tratado.
	get_tree().root.window_input.connect(_on_window_input)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(delta: float) -> void:
	for device in Input.get_connected_joypads():
		var held: _Held = _held.get(device)
		if held == null:
			held = _Held.new()
			_held[device] = held
		var dpad := _dpad_dir(device)
		var dir := dpad
		if dir == Vector2i.ZERO:
			dir = _stick_dir(device, Vector2i.ZERO if held.from_dpad else held.dir)
		if dir != held.dir:
			_end(device, held)
			held.dir = dir
			held.from_dpad = dpad != Vector2i.ZERO
			held.timer = REPEAT_DELAY
			# O direcional já mandou o primeiro passo (evento do próprio botão).
			if dir != Vector2i.ZERO and not held.from_dpad:
				_send(device, dir, true)
				held.sent = true
		elif dir != Vector2i.ZERO:
			held.timer -= delta
			if held.timer <= 0.0:
				held.timer += REPEAT_RATE
				_send(device, dir, true)
				held.sent = true


## Direção do analógico esquerdo. Continua em `current` até o analógico quase voltar
## ao centro; uma direção nova só conta passando de PRESS.
func _stick_dir(device: int, current: Vector2i) -> Vector2i:
	var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	if current != Vector2i.ZERO and stick.dot(Vector2(current)) > RELEASE:
		return current
	if absf(stick.x) >= absf(stick.y):
		return Vector2i(int(signf(stick.x)), 0) if absf(stick.x) > PRESS else Vector2i.ZERO
	return Vector2i(0, int(signf(stick.y))) if absf(stick.y) > PRESS else Vector2i.ZERO


func _dpad_dir(device: int) -> Vector2i:
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		return Vector2i.LEFT
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		return Vector2i.RIGHT
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
		return Vector2i.UP
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
		return Vector2i.DOWN
	return Vector2i.ZERO


## Solta a ação da direção que estava segurada (se este nó mandou alguma).
func _end(device: int, held: _Held) -> void:
	if held.sent and held.dir != Vector2i.ZERO:
		_send(device, held.dir, false)
	held.sent = false


func _send(device: int, dir: Vector2i, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = ACTIONS[dir]
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	ev.device = device
	Input.parse_input_event(ev)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or not _held.has(device):
		return
	_end(device, _held[device])
	_held.erase(device)


func _on_window_input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton:
		pad = pad or event.pressed
	elif event is InputEventJoypadMotion:
		pad = pad or absf(event.axis_value) > PRESS
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(using_pad)
