class_name GameSettings
extends Node
## Opções do jogo (tela "Opções", filho do GameState): volume de cada canal de áudio,
## tela cheia, resolução da janela, qualidade gráfica (GraphicsQuality, em `graphics`)
## e as teclas do kart. Ficam em user://opcoes.cfg e valem desde a abertura do jogo.
##
## Os canais de áudio estão em res://default_bus_layout.tres: "Musica" (MusicPlayer) e
## "Efeitos" (Sfx e o motor dos karts), os dois passando pelo "Master".

## Teclas do kart mudaram (a tela de controles e as dicas mostram as novas).
signal keys_changed

const PATH := "user://opcoes.cfg"

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Musica"
const BUS_SFX := &"Efeitos"
## Volume inicial de cada canal (0 a 1).
const VOLUME_DEFAULTS := {&"Master": 1.0, &"Musica": 0.8, &"Efeitos": 1.0}

## Resoluções da janela (pixels de verdade). Só aparecem as que cabem na tela.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3200, 1800),
	Vector2i(3840, 2160),
]

## Ações do kart que dá para trocar de tecla (as mesmas que cada jogador tem
## separadas no multijogador). A pausa fica fixa em Esc / P / Start: o Esc também
## volta nos menus.
const KEY_ACTIONS: Array[StringName] = [&"acelerar", &"frear", &"esquerda", &"direita", &"drift", &"reposicionar"]
const KEY_ACTION_NAMES := {
	&"acelerar": "Acelerar",
	&"frear": "Frear / ré",
	&"esquerda": "Virar à esquerda",
	&"direita": "Virar à direita",
	&"drift": "Pulo / drift",
	&"reposicionar": "Reposicionar",
}
## Teclas por ação (a principal e a alternativa).
const KEY_SLOTS := 2
## Nomes das teclas em português (as outras usam o nome do sistema).
const KEY_NAMES := {
	KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
	KEY_SPACE: "Espaço", KEY_ESCAPE: "Esc", KEY_ENTER: "Enter", KEY_KP_ENTER: "Enter",
	KEY_BACKSPACE: "Apagar", KEY_CTRL: "Ctrl", KEY_CAPSLOCK: "Caps",
}

## Qualidade gráfica (sombras, efeitos, antisserrilhado, resolução do 3D, cenário).
var graphics: GraphicsQuality

var _cfg := ConfigFile.new()
## Teclas do project.godot (para "Restaurar padrão"): ação → PackedInt32Array de
## códigos físicos (0 = vaga vazia).
var _default_keys := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in KEY_ACTIONS:
		_default_keys[action] = _keys_in_map(action)
	_cfg.load(PATH)
	graphics = GraphicsQuality.new()
	graphics.name = "Graficos"
	graphics.setup(_cfg, save)
	add_child(graphics)
	for bus in VOLUME_DEFAULTS:
		_apply_volume(bus, get_volume(bus))
	for action in KEY_ACTIONS:
		if _cfg.has_section_key("teclas", action):
			_apply_keys(action, get_keys(action))
	if not OS.has_feature("web"):
		var size := _saved_resolution()
		if size != Vector2i.ZERO:
			_resize_window(size)
		if _cfg.get_value("tela", "tela_cheia", false):
			set_fullscreen(true, false)


func save() -> void:
	_cfg.save(PATH)


# --- Áudio ---------------------------------------------------------------------------

func get_volume(bus: StringName) -> float:
	return clampf(float(_cfg.get_value("audio", bus, VOLUME_DEFAULTS.get(bus, 1.0))), 0.0, 1.0)


func set_volume(bus: StringName, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	_cfg.set_value("audio", bus, value)
	_apply_volume(bus, value)
	save()


## Volume em curva (quadrado da posição): a metade do controle fica em -12 dB, que
## soa como "metade" do som, e o fim do controle não fica com tudo igual.
func _apply_volume(bus: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value * value, 0.0001)))


# --- Tela ----------------------------------------------------------------------------

func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool, remember := true) -> void:
	if on != is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		if not on:
			# Voltando para a janela: o tamanho escolhido nas opções.
			var size := _saved_resolution()
			if size != Vector2i.ZERO:
				_resize_window.call_deferred(size)
	if remember:
		_cfg.set_value("tela", "tela_cheia", on)
		save()


## Dá para trocar o tamanho da janela (no navegador quem manda é a página).
func can_resize() -> bool:
	return not OS.has_feature("web")


## Resoluções que cabem na tela, com o tamanho atual da janela (se for outro) no meio.
func available_resolutions() -> Array[Vector2i]:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= usable.x and r.y <= usable.y:
			out.append(r)
	var current := DisplayServer.window_get_size()
	if not is_fullscreen() and not out.has(current):
		out.append(current)
		out.sort_custom(func(a: Vector2i, b: Vector2i): return a.x * a.y < b.x * b.y)
	if out.is_empty():
		out.append(current)
	return out


func get_resolution() -> Vector2i:
	return DisplayServer.window_get_size()


func set_resolution(size: Vector2i) -> void:
	_cfg.set_value("tela", "resolucao", "%dx%d" % [size.x, size.y])
	save()
	if not is_fullscreen():
		_resize_window(size)


func _saved_resolution() -> Vector2i:
	var parts := str(_cfg.get_value("tela", "resolucao", "")).split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


## Muda o tamanho da janela e centraliza na tela.
func _resize_window(size: Vector2i) -> void:
	if is_fullscreen() or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	size = size.min(screen.size)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


static func format_resolution(size: Vector2i) -> String:
	return "%d × %d" % [size.x, size.y]


# --- Teclas --------------------------------------------------------------------------

## Teclas da ação (códigos físicos, KEY_SLOTS vagas; 0 = vaga vazia).
func get_keys(action: StringName) -> PackedInt32Array:
	var keys := PackedInt32Array(_cfg.get_value("teclas", action, _default_keys.get(action, PackedInt32Array())))
	keys.resize(KEY_SLOTS)
	return keys


## Põe `physical` (código físico da tecla) na vaga `slot` da ação. Se outra ação do
## kart já usava essa tecla, ela fica com a tecla antiga desta vaga (troca).
func set_key(action: StringName, slot: int, physical: int) -> void:
	var keys := get_keys(action)
	var old := keys[slot]
	if old == physical:
		return
	for other in KEY_ACTIONS:
		var other_keys := get_keys(other)
		for i in KEY_SLOTS:
			if other_keys[i] == physical and not (other == action and i == slot):
				other_keys[i] = old
				if other == action:
					keys[i] = old
				else:
					_store_keys(other, other_keys)
	keys[slot] = physical
	_store_keys(action, keys)
	_after_keys_changed()


func reset_keys() -> void:
	for action in KEY_ACTIONS:
		if _cfg.has_section_key("teclas", action):
			_cfg.erase_section_key("teclas", action)
		_apply_keys(action, get_keys(action))
	_after_keys_changed()


func keys_are_default() -> bool:
	for action in KEY_ACTIONS:
		if get_keys(action) != _default_keys[action]:
			return false
	return true


## Nome para mostrar das teclas da ação ("W", "↑"...), sem as vagas vazias.
func key_labels(action: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for k in get_keys(action):
		if k != 0:
			out.append(key_name(k))
	return out


static func key_name(physical: int) -> String:
	if physical == 0:
		return ""
	# A tecla que está nessa posição no teclado do jogador (AZERTY, Dvorak...). Só os
	# sistemas de desktop sabem o layout; na web e sem tela vale o nome no padrão US.
	var keycode := physical as Key
	if DisplayServer.get_name() in ["Windows", "macOS", "X11", "Wayland"]:
		var mapped := DisplayServer.keyboard_get_keycode_from_physical(physical) as Key
		if mapped != KEY_NONE:
			keycode = mapped
	if KEY_NAMES.has(keycode):
		return KEY_NAMES[keycode]
	var label := OS.get_keycode_string(keycode)
	return label if label != "" else "?"


func _store_keys(action: StringName, keys: PackedInt32Array) -> void:
	if keys == _default_keys[action]:
		if _cfg.has_section_key("teclas", action):
			_cfg.erase_section_key("teclas", action)
	else:
		_cfg.set_value("teclas", action, keys)
	_apply_keys(action, keys)


func _after_keys_changed() -> void:
	save()
	# Multijogador: as cópias das ações de cada jogador ("j2_acelerar"...) são refeitas.
	for slot in GameState.players:
		slot.apply_input_map()
	keys_changed.emit()


## Troca as teclas da ação no InputMap (os botões do controle ficam como estão).
func _apply_keys(action: StringName, keys: PackedInt32Array) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	for k in keys:
		if k != 0:
			var ev := InputEventKey.new()
			ev.physical_keycode = k as Key
			InputMap.action_add_event(action, ev)


func _keys_in_map(action: StringName) -> PackedInt32Array:
	var keys := PackedInt32Array()
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and keys.size() < KEY_SLOTS:
				var k: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
				keys.append(k)
	keys.resize(KEY_SLOTS)
	return keys
