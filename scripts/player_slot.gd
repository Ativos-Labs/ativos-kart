class_name PlayerSlot
extends RefCounted
## Um jogador humano (até 4 na mesma tela): o controle que ele usa, o piloto, o kart e
## a asa-delta escolhidos e a cor dele na interface (J1 azul, J2 vermelho, J3 verde, J4 amarelo).
##
## Jogando sozinho o jogador usa o teclado e todos os controles juntos (as ações de
## sempre: "acelerar", "frear"...). No multijogador cada um ganha cópias das ações só
## com os botões do controle dele ("j2_acelerar"...), criadas em `apply_input_map()`.

## Teclado e todos os controles juntos (um jogador só).
const DEVICE_ALL := -2
## Só o teclado.
const DEVICE_KEYBOARD := -1

const COLORS := [
	Color(0.17, 0.38, 0.93),
	Color(0.9, 0.16, 0.18),
	Color(0.16, 0.72, 0.32),
	Color(1.0, 0.78, 0.08),
]
## Ações do kart que cada jogador tem separadas. A pausa e os menus continuam valendo
## para todos os controles.
const ACTIONS: Array[StringName] = [&"acelerar", &"frear", &"esquerda", &"direita", &"drift", &"usar_item", &"reposicionar"]

## 0 = J1 ... 3 = J4.
var index := 0
## Controle do jogador: DEVICE_ALL, DEVICE_KEYBOARD ou o id do controle (0, 1, 2...).
var device := DEVICE_ALL
var character_index := 0
var kart_index := 0
var glider_index := 0


func _init(p_index := 0, p_device := DEVICE_ALL) -> void:
	index = p_index
	device = p_device


## "J1", "J2"...
var tag: String:
	get:
		return "J%d" % (index + 1)

var color: Color:
	get:
		return COLORS[clampi(index, 0, COLORS.size() - 1)]


## Prefixo das ações deste jogador ("" = as ações de sempre).
func input_prefix() -> String:
	return "" if device == DEVICE_ALL else "j%d_" % (index + 1)


## Nome da ação `base` para este jogador.
func action(base: StringName) -> StringName:
	return StringName(input_prefix() + base)


## Nome do controle para mostrar na tela.
func device_name() -> String:
	return device_label(device)


static func device_label(id: int) -> String:
	if id == DEVICE_ALL:
		return "Teclado e controles"
	if id == DEVICE_KEYBOARD:
		return "Teclado"
	var joy_name := Input.get_joy_name(id)
	return "Controle %d" % (id + 1) if joy_name.is_empty() else joy_name


## Cria (ou refaz) as ações deste jogador com os eventos das ações de sempre,
## filtrados pelo controle dele.
func apply_input_map() -> void:
	if device == DEVICE_ALL:
		return
	for base in ACTIONS:
		var name := action(base)
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		InputMap.add_action(name, InputMap.action_get_deadzone(base))
		for ev in InputMap.action_get_events(base):
			var copy: InputEvent = null
			if device == DEVICE_KEYBOARD:
				if ev is InputEventKey:
					copy = ev.duplicate()
			elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				copy = ev.duplicate()
				copy.device = device
			if copy:
				InputMap.action_add_event(name, copy)
