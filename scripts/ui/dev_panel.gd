class_name DevPanel
extends CanvasLayer
## Modo dev (GameState.dev_mode): painel para testar os itens na corrida. F1 ou a tecla
## à esquerda do 1 (' ou `; no Mac o F1 pede o fn) abre e fecha — a etiqueta "DEV" no
## alto lembra que ele existe. Com ele aberto:
## - 1…9, 0, − e B, F, J, L (ou clique): o J1 ganha o item na hora, com uma roleta curta;
##   os de uso imediato (turbos, moedas) são usados assim que ela para. As letras são as
##   Armadilhas e Defesas: B = Pendência documental (a banana), F = Fila do tribunal,
##   J = Trânsito em julgado, L = Liminar;
## - Alt/Option + tecla (ou clique direito): um rival usa o item em cima do J1 — quem vem de
##   trás para Juridiquês, Intimação, PEC e Superpreferência, o mais perto para os outros;
##   as armadilhas caem na pista logo à frente do J1 (RaceItems.dev_rival_use);
## - I: item infinito (o item usado volta para o slot);
## - N: rivais sem itens (as caixas não dão nada para eles);
## - T: rivais parados, travados onde estão (alvos para os ataques).
## Usou qualquer uma dessas coisas, a corrida não vale recorde (RaceItems.dev_used).

## Teclas dos itens, na ordem de RaceItem.Kind (códigos físicos).
const ITEM_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS,
		KEY_B, KEY_F, KEY_J, KEY_L]
const ITEM_LABELS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "−", "B", "F", "J", "L"]
## Quanto tempo (s) a última frase fica embaixo do painel.
const MESSAGE_TIME := 5.0
## Abre/fecha o painel: F1 e a tecla à esquerda do 1 (US: `, ABNT: ', ISO do Mac: §).
const OPEN_KEYS: Array[Key] = [KEY_F1, KEY_QUOTELEFT, KEY_SECTION]

## Opções do painel (linhas embaixo dos itens).
enum Toggle { INFINITE, NO_AI_ITEMS, PARKED }
const TOGGLE_KEYS: Array[Key] = [KEY_I, KEY_N, KEY_T]
const TOGGLE_NAMES: Array[String] = ["Item infinito", "Rivais sem itens", "Rivais parados"]

## A corrida (race.gd).
var race: Node3D
## Tecla de abrir mostrada no painel e na etiqueta: o caractere da tecla à esquerda do 1
## neste teclado (no desktop) ou "F1" (na web o layout é desconhecido).
var open_label := "F1"
## Nome do modificador do "rival usa": Option no Mac, Alt no resto.
var alt_label := "Alt"
var _board: Board
var _tag: Label
var _parked := false
var _message := ""
var _message_time := 0.0


## O desenho do painel (fundo, itens, opções e a frase) e os cliques.
class Board extends Control:
	const WIDTH := 330.0
	const PAD := 12.0
	const ROW := 22.0
	const TOGGLE_ROW := 25.0
	const ROWS_TOP := 74.0
	const BACKGROUND := Color(0.03, 0.05, 0.12, 0.8)
	const HOVER := Color(1, 1, 1, 0.1)
	const SOFT := Color(0.78, 0.82, 0.92)

	var panel: DevPanel
	## Linha sob o mouse: 0…COUNT-1 = item, COUNT + i = opção i, -1 = nenhuma.
	var hover := -1
	var _bg := StyleBoxFlat.new()

	func _init(p_panel: DevPanel) -> void:
		panel = p_panel
		name = "Painel"
		mouse_filter = Control.MOUSE_FILTER_STOP
		size = Vector2(WIDTH, _toggles_top() + TOGGLE_ROW * Toggle.size() + 50.0)
		_bg.bg_color = BACKGROUND
		_bg.set_corner_radius_all(14)
		_bg.border_color = Color(1.0, 0.82, 0.1, 0.55)
		_bg.set_border_width_all(2)
		mouse_exited.connect(func():
			hover = -1
			queue_redraw())

	func _toggles_top() -> float:
		return ROWS_TOP + ROW * RaceItem.COUNT + 12.0

	## Linha em `y` (veja `hover`).
	func row_at(y: float) -> int:
		if y >= ROWS_TOP and y < ROWS_TOP + ROW * RaceItem.COUNT:
			return int((y - ROWS_TOP) / ROW)
		var t := _toggles_top()
		if y >= t and y < t + TOGGLE_ROW * Toggle.size():
			return RaceItem.COUNT + int((y - t) / TOGGLE_ROW)
		return -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var row := row_at(event.position.y)
			if row != hover:
				hover = row
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed:
			var row := row_at(event.position.y)
			if row < 0:
				return
			if row >= RaceItem.COUNT:
				if event.button_index == MOUSE_BUTTON_LEFT:
					panel.toggle(row - RaceItem.COUNT)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				panel.give(row)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				panel.rival_use(row)
			accept_event()

	func _text(x: float, center_y: float, text: String, font: Font, font_size: int, color: Color,
			width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		var baseline := center_y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2(x, baseline), text, align, width, font_size, color)

	func _draw() -> void:
		draw_style_box(_bg, Rect2(Vector2.ZERO, size))
		var on: bool = panel.items_on()
		_text(PAD, 20.0, "MODO DEV · ITENS", UiKit.FONT_TITLE, 21, UiKit.YELLOW)
		var w := UiKit.key_width(panel.open_label, 20.0, 12)
		UiKit.draw_key(self, Vector2(WIDTH - PAD - w, 10.0), 20.0, panel.open_label, 12)
		_text(PAD, 44.0, "Tecla ou clique: você ganha o item", UiKit.FONT_BODY, 12, SOFT)
		_text(PAD, 60.0, "%s + tecla ou clique direito: rival usa em você" % panel.alt_label, UiKit.FONT_BODY, 12, SOFT)
		for kind in RaceItem.COUNT:
			var y := ROWS_TOP + kind * ROW
			if hover == kind:
				draw_rect(Rect2(6.0, y, WIDTH - 12.0, ROW), HOVER)
			var alpha := 1.0 if on else 0.4
			UiKit.draw_key(self, Vector2(PAD, y + 2.0), 18.0, ITEM_LABELS[kind], 11,
					Color(1, 1, 1, alpha))
			RaceItem.draw_icon(self, kind, Vector2(PAD + 44.0, y + ROW * 0.5), 9.5)
			_text(PAD + 62.0, y + ROW * 0.5, RaceItem.item_name(kind), UiKit.FONT_BODY, 14,
					Color(1, 1, 1, alpha))
			if RaceItem.is_auto(kind):
				_text(PAD + 62.0, y + ROW * 0.5, "na hora", UiKit.FONT_BODY, 11,
						Color(RaceItem.color(kind), 0.85 * alpha), WIDTH - PAD * 2.0 - 62.0, HORIZONTAL_ALIGNMENT_RIGHT)
		var t := _toggles_top()
		draw_line(Vector2(PAD, t - 6.0), Vector2(WIDTH - PAD, t - 6.0), Color(1, 1, 1, 0.15), 1.0)
		for i in Toggle.size():
			var y := t + i * TOGGLE_ROW
			if hover == RaceItem.COUNT + i:
				draw_rect(Rect2(6.0, y, WIDTH - 12.0, TOGGLE_ROW), HOVER)
			UiKit.draw_key(self, Vector2(PAD, y + 3.0), 19.0, GameSettings.key_name(TOGGLE_KEYS[i]), 11)
			_text(PAD + 40.0, y + TOGGLE_ROW * 0.5, TOGGLE_NAMES[i], UiKit.FONT_BODY, 14, Color.WHITE)
			var lit: bool = panel.is_on(i)
			var pill := Rect2(WIDTH - PAD - 46.0, y + 4.0, 46.0, TOGGLE_ROW - 8.0)
			var box := StyleBoxFlat.new()
			box.bg_color = UiKit.GREEN if lit else Color(1, 1, 1, 0.14)
			box.set_corner_radius_all(int(pill.size.y * 0.5))
			draw_style_box(box, pill)
			_text(pill.position.x, pill.get_center().y, "SIM" if lit else "NÃO", UiKit.FONT_BODY, 11,
					UiKit.NAVY if lit else SOFT, pill.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var msg: String = panel.message()
		if msg != "":
			var y := t + TOGGLE_ROW * Toggle.size() + 8.0
			draw_multiline_string(UiKit.FONT_BODY, Vector2(PAD, y + 13.0), msg, HORIZONTAL_ALIGNMENT_LEFT,
					WIDTH - PAD * 2.0, 13, 2, UiKit.YELLOW_LIGHT)


func setup(p_race: Node3D) -> void:
	race = p_race


func _ready() -> void:
	name = "ModoDev"
	layer = 15
	if DisplayServer.get_name() in ["Windows", "macOS", "X11", "Wayland"]:
		var label := DisplayServer.keyboard_get_label_from_physical(KEY_QUOTELEFT)
		if label > KEY_SPACE and label < KEY_SPECIAL:
			open_label = char(label)
	if OS.get_name() == "macOS":
		alt_label = "Option"
	_tag = Label.new()
	_tag.name = "Etiqueta"
	_tag.text = "DEV · F1" if open_label == "F1" else "DEV · %s ou F1" % open_label
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.add_theme_font_override("font", UiKit.FONT_BODY)
	_tag.add_theme_font_size_override("font_size", 13)
	_tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2, 0.75))
	_tag.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.12, 0.8))
	_tag.add_theme_constant_override("outline_size", 5)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 4)
	_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_tag)
	_board = Board.new(self)
	# Embaixo do slot do item (canto superior esquerdo), acima das pílulas de moeda/volta.
	_board.position = Vector2(26.0, 164.0)
	_board.visible = false
	add_child(_board)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode in OPEN_KEYS:
		_board.visible = not _board.visible
		_tag.visible = not _board.visible
		_board.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if not _board.visible:
		return
	var toggle_index := TOGGLE_KEYS.find(key.physical_keycode)
	if toggle_index >= 0:
		toggle(toggle_index)
		get_viewport().set_input_as_handled()
		return
	var kind := ITEM_KEYS.find(key.physical_keycode)
	if kind >= 0:
		if key.alt_pressed:
			rival_use(kind)
		else:
			give(kind)
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _parked and race.is_racing():
		for r in race.racers:
			if r.ai and not r.finished:
				r.kart.controls_enabled = false


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message = ""
			_board.queue_redraw()


# --- Ações -------------------------------------------------------------------------

## O J1 ganha `kind`.
func give(kind: int) -> void:
	var h := _player_holder()
	if not _can_use(h):
		return
	race.items.dev_give(h, kind)
	_say("Você ganhou %s." % RaceItem.item_name(kind))


## Um rival usa `kind` em cima do J1.
func rival_use(kind: int) -> void:
	var h := _player_holder()
	if not _can_use(h):
		return
	_say(race.items.dev_rival_use(kind, h))


func toggle(which: int) -> void:
	var items: RaceItems = race.items
	match which:
		Toggle.INFINITE:
			items.dev_infinite = not items.dev_infinite
			if items.dev_infinite:
				items.dev_used = true
			_say("Item infinito: o item usado volta para o slot." if items.dev_infinite else "Item infinito desligado.")
		Toggle.NO_AI_ITEMS:
			items.dev_set_no_ai_items(not items.dev_no_ai_items)
			_say("Os rivais não pegam mais itens." if items.dev_no_ai_items else "Os rivais voltam a pegar itens.")
		Toggle.PARKED:
			_parked = not _parked
			items.dev_used = true
			if not _parked:
				for r in race.racers:
					if r.ai and (race.is_racing() or r.finished):
						r.kart.controls_enabled = true
			_say("Rivais parados: alvos para os ataques." if _parked else "Os rivais voltam a correr.")
	_board.queue_redraw()


func is_on(which: int) -> bool:
	var items: RaceItems = race.items
	match which:
		Toggle.INFINITE:
			return items.dev_infinite
		Toggle.NO_AI_ITEMS:
			return items.dev_no_ai_items
		Toggle.PARKED:
			return _parked
	return false


## Os itens estão ligados nesta corrida (não no contra-relógio nem sem rivais)?
func items_on() -> bool:
	return race.items.enabled


## A frase embaixo do painel ("" = nenhuma).
func message() -> String:
	return _message


func _say(text: String) -> void:
	_message = text
	_message_time = MESSAGE_TIME
	_board.queue_redraw()


func _player_holder() -> RaceItems.Holder:
	if race.humans.is_empty():
		return null
	for h in race.items.holders():
		if h.racer == race.humans[0]:
			return h
	return null


func _can_use(h: RaceItems.Holder) -> bool:
	if not race.items.enabled:
		_say("Itens desligados: contra-relógio ou corrida sem rivais.")
		return false
	if h == null or h.racer.finished:
		_say("Você já terminou a corrida.")
		return false
	if not race.is_racing():
		_say("Espere a largada.")
		return false
	return true
