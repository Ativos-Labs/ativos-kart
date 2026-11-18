class_name ItemSlot
extends Control
## Slot do item no canto superior esquerdo do HUD (como no Mario Kart). Vazio, some.
## Ao pegar uma caixa ele aparece e gira uma roleta vertical: uma fita de ícones desce
## pela janela, rápida no começo, e freia até parar no item sorteado (um clique a cada
## ícone que passa). O item fica guardado até o jogador usar (a tecla aparece no canto).
##
## Só a fita se mexe (posição): nada é redesenhado a cada quadro.

const BACKGROUND := Color(0.03, 0.05, 0.12, 0.62)
## Ícones na fita da roleta (o último é o sorteado).
const REEL_COUNT := 14
## Intervalo mínimo (s) entre os cliques da roleta.
const TICK_GAP := 0.05

## Item mostrado (RaceItem.NONE = vazio).
var kind := RaceItem.NONE
## Tecla (ou botão) de usar o item, mostrada no canto do slot quando tem item.
var key_text := "":
	set(value):
		key_text = value
		if _frame:
			_frame.key_text = value

var box_size := 100.0
var _frame: Frame
var _clip: Control
var _reel: Control
var _icons: Array[ItemIcon] = []
var _caption: Label
var _cell := 0.0
var _roll_t := -1.0
var _roll_len := 1.8
var _last_cell := 0
var _tick_wait := 0.0
var _box_tween: Tween
var _reel_tween: Tween
var _caption_tween: Tween


## Moldura de vidro escuro com borda branca e a tecla de usar no canto.
class Frame:
	extends Control

	var show_key := false:
		set(value):
			if value != show_key:
				show_key = value
				queue_redraw()
	var key_text := "":
		set(value):
			if value != key_text:
				key_text = value
				queue_redraw()
	var _style := StyleBoxFlat.new()
	var _shine := StyleBoxFlat.new()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var radius := int(size.x * 0.24)
		_style.set_corner_radius_all(radius)
		_style.bg_color = Color(0, 0, 0, 0.28)
		_style.set_border_width_all(0)
		draw_style_box(_style, Rect2(r.position + Vector2(0, 4), r.size))
		_style.bg_color = ItemSlot.BACKGROUND
		_style.border_color = Color(1, 1, 1, 0.92)
		_style.set_border_width_all(maxi(int(size.x * 0.035), 3))
		draw_style_box(_style, r)
		# Brilho de vidro na metade de cima.
		_shine.bg_color = Color(1, 1, 1, 0.07)
		_shine.corner_radius_top_left = radius - 4
		_shine.corner_radius_top_right = radius - 4
		var inset := size.x * 0.06
		draw_style_box(_shine, Rect2(Vector2(inset, inset), Vector2(size.x - inset * 2.0, size.y * 0.42 - inset)))
		if show_key and key_text != "":
			var h := roundf(size.x * 0.28)
			var fs := int(h * 0.56)
			var w := UiKit.key_width(key_text, h, fs)
			UiKit.draw_key(self, Vector2(size.x - w + h * 0.3, size.y - h * 0.62), h, key_text, fs)


func _init(p_box_size := 100.0) -> void:
	box_size = p_box_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(box_size, box_size)
	size = custom_minimum_size
	_frame = Frame.new()
	_frame.name = "Moldura"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.size = Vector2(box_size, box_size)
	_frame.pivot_offset = _frame.size * 0.5
	add_child(_frame)
	var pad := roundf(box_size * 0.1)
	_cell = box_size - pad * 2.0
	_clip = Control.new()
	_clip.name = "Janela"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.position = Vector2(pad, pad)
	_clip.size = Vector2(_cell, _cell)
	_frame.add_child(_clip)
	_reel = Control.new()
	_reel.name = "Fita"
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_reel)
	for i in REEL_COUNT:
		var icon := ItemIcon.new()
		icon.size = Vector2(_cell, _cell)
		icon.position = Vector2(0.0, -i * _cell)
		_reel.add_child(icon)
		_icons.append(icon)
	_caption = Label.new()
	_caption.name = "Legenda"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_override("font", UiKit.FONT_ITALIC)
	_caption.add_theme_font_size_override("font_size", int(box_size * 0.22))
	_caption.add_theme_constant_override("outline_size", int(box_size * 0.1))
	_caption.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.12, 0.9))
	_caption.position = Vector2(2.0, box_size + 2.0)
	_caption.size = Vector2(box_size * 4.0, box_size * 0.3)
	_caption.visible = false
	add_child(_caption)
	_frame.visible = false


func _ready() -> void:
	set_process(false)


## Gira a roleta e para em `result` depois de `duration` segundos.
func roll(result: int, duration: float) -> void:
	kind = result
	_frame.show_key = false
	_kill_reel_tween()
	var prev := result
	# A fita (de baixo para cima): sorteada no fim, sem dois iguais seguidos.
	for i in range(REEL_COUNT - 1, -1, -1):
		var k := result
		if i < REEL_COUNT - 1:
			k = randi() % RaceItem.COUNT
			if k == prev:
				k = (k + 1 + randi() % (RaceItem.COUNT - 1)) % RaceItem.COUNT
		_icons[i].kind = k
		prev = k
	_set_reel(0.0)
	_roll_t = 0.0
	_roll_len = maxf(duration, 0.3)
	_last_cell = 0
	_tick_wait = 0.0
	_appear()
	set_process(true)


## Mostra o item parado (sem roleta). NONE esconde o slot.
func show_item(value: int) -> void:
	_roll_t = -1.0
	set_process(false)
	_kill_reel_tween()
	kind = value
	if value == RaceItem.NONE:
		_disappear()
		return
	_icons[REEL_COUNT - 1].kind = value
	_set_reel(REEL_COUNT - 1)
	_frame.show_key = true
	_appear()


## Usou o item: o slot dá um estouro (cresce e some).
func use() -> void:
	kind = RaceItem.NONE
	_roll_t = -1.0
	set_process(false)
	_frame.show_key = false
	if _caption_tween:
		_caption_tween.kill()
	_caption.hide()
	_kill_box_tween()
	_box_tween = create_tween().set_parallel()
	_box_tween.tween_property(_frame, "scale", Vector2.ONE * 1.35, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_box_tween.tween_property(_frame, "modulate:a", 0.0, 0.22)
	_box_tween.chain().tween_callback(_frame.hide)


## O item foi roubado (Cessão de crédito de um rival): o ícone treme, sobe pela janela
## e o slot some.
func stolen() -> void:
	kind = RaceItem.NONE
	_roll_t = -1.0
	set_process(false)
	_frame.show_key = false
	_kill_reel_tween()
	_kill_box_tween()
	var x := _frame.position.x
	_box_tween = create_tween()
	for i in 4:
		_box_tween.tween_property(_frame, "position:x", x + (5.0 if i % 2 == 0 else -5.0), 0.045)
	_box_tween.tween_property(_frame, "position:x", x, 0.045)
	_box_tween.tween_method(_set_reel, float(REEL_COUNT - 1), float(REEL_COUNT - 2), 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_box_tween.tween_property(_frame, "modulate:a", 0.0, 0.25)
	_box_tween.tween_callback(_frame.hide)
	_icons[REEL_COUNT - 2].kind = RaceItem.NONE
	show_caption("CRÉDITO CEDIDO!", Color("9fe8ff"), 1.6)


## Item chegando por um contrato (Cessão de crédito): o slot aparece vazio e o item cai
## nele depois de `duration` segundos.
func receive(value: int, duration: float) -> void:
	kind = value
	_roll_t = -1.0
	set_process(false)
	_frame.show_key = false
	_kill_reel_tween()
	_icons[REEL_COUNT - 2].kind = RaceItem.NONE
	_icons[REEL_COUNT - 1].kind = value
	_set_reel(REEL_COUNT - 2)
	_appear()
	_reel_tween = create_tween()
	_reel_tween.tween_interval(maxf(duration - 0.3, 0.0))
	_reel_tween.tween_method(_set_reel, float(REEL_COUNT - 2), float(REEL_COUNT - 1), 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reel_tween.tween_callback(_land)


## Legenda embaixo do slot (nome do item, "CRÉDITO CEDIDO!"), some sozinha.
func show_caption(text: String, color: Color, hold := 1.2) -> void:
	_caption.text = text
	_caption.add_theme_color_override("font_color", color)
	_caption.visible = true
	_caption.modulate.a = 0.0
	var x := 2.0
	_caption.position.x = x - 16.0
	if _caption_tween:
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.set_parallel()
	_caption_tween.tween_property(_caption, "position:x", x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.15)
	_caption_tween.chain().tween_interval(hold)
	_caption_tween.chain().tween_property(_caption, "modulate:a", 0.0, 0.3)
	_caption_tween.chain().tween_callback(_caption.hide)


## Some na hora (fim da corrida).
func clear() -> void:
	kind = RaceItem.NONE
	_roll_t = -1.0
	set_process(false)
	_kill_reel_tween()
	_kill_box_tween()
	_frame.hide()
	_caption.hide()


## Centro do slot na tela do HUD (para o contrato voar até ele).
func get_box_center() -> Vector2:
	return get_global_rect().get_center()


func _process(delta: float) -> void:
	if _roll_t < 0.0:
		set_process(false)
		return
	_roll_t += delta
	_tick_wait -= delta
	var t := clampf(_roll_t / _roll_len, 0.0, 1.0)
	# Rápida no começo e freando até parar.
	var e := 1.0 - pow(1.0 - t, 3.2)
	var s := (REEL_COUNT - 1) * e
	_set_reel(s)
	var cell := int(s + 0.5)
	if cell != _last_cell:
		_last_cell = cell
		if _tick_wait <= 0.0:
			_tick_wait = TICK_GAP
			Sfx.play(self, &"item_tick", -17.0, 0.9 + 0.25 * t)
	if t >= 1.0:
		_roll_t = -1.0
		set_process(false)
		_land()


## A fita parada em `s` (0 = primeiro ícone na janela; os ícones descem).
func _set_reel(s: float) -> void:
	_reel.position.y = s * _cell


## Parou no item: pulinho, som e o nome embaixo.
func _land() -> void:
	_set_reel(REEL_COUNT - 1)
	_frame.show_key = true
	Sfx.play(self, &"item_get", -9.0)
	_kill_box_tween()
	_frame.modulate.a = 1.0
	_frame.scale = Vector2.ONE * 1.22
	_box_tween = create_tween()
	_box_tween.tween_property(_frame, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show_caption(RaceItem.short_name(kind), RaceItem.color(kind), 1.1)


func _appear() -> void:
	if _frame.visible and _frame.modulate.a >= 0.99 and not (_box_tween and _box_tween.is_running()):
		return
	_kill_box_tween()
	_frame.visible = true
	_frame.position = Vector2.ZERO
	_frame.scale = Vector2.ONE * 0.4
	_frame.modulate.a = 0.0
	_box_tween = create_tween().set_parallel()
	_box_tween.tween_property(_frame, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_box_tween.tween_property(_frame, "modulate:a", 1.0, 0.12)


func _disappear() -> void:
	if not _frame.visible:
		return
	_kill_box_tween()
	_box_tween = create_tween().set_parallel()
	_box_tween.tween_property(_frame, "scale", Vector2.ONE * 0.6, 0.2)
	_box_tween.tween_property(_frame, "modulate:a", 0.0, 0.2)
	_box_tween.chain().tween_callback(_frame.hide)


func _kill_box_tween() -> void:
	if _box_tween:
		_box_tween.kill()
		_box_tween = null
	_frame.position = Vector2.ZERO


func _kill_reel_tween() -> void:
	if _reel_tween:
		_reel_tween.kill()
		_reel_tween = null
