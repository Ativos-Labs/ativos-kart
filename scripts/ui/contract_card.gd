class_name ContractCard
extends Control
## Cessão de crédito no HUD de quem usou: um contrato aparece ao lado do slot do item
## ("CESSÃO DE CRÉDITO", cedente, cessionário e o item cedido), o Celerino assina (a
## assinatura vai surgindo da esquerda para a direita), o carimbo "CEDIDO" bate e o
## papel voa para dentro do slot, onde o item cai (ItemSlot.receive).
## Desenhado uma vez por contrato; a animação mexe em posição, escala e no recorte da
## assinatura.

const CARD_SIZE := Vector2(268, 164)
const SIGN_RECT := Rect2(18, 106, 150, 36)

var _paper: Paper
var _sign_clip: Control
var _stamp: Stamp
var _icon: ItemIcon
var _tween: Tween
var _home := Vector2.ZERO
## Tamanho do contrato (HUD compacto da tela dividida: menor).
var card_scale := 1.0


## O papel com o texto.
class Paper:
	extends Control

	var from_name := ""
	var to_name := ""
	var _style := StyleBoxFlat.new()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		_style.set_corner_radius_all(10)
		_style.bg_color = Color(0, 0, 0, 0.3)
		draw_style_box(_style, Rect2(r.position + Vector2(3, 6), r.size))
		_style.bg_color = RaceItem.PAPER
		_style.border_color = Color(RaceItem.INK, 0.35)
		_style.set_border_width_all(2)
		draw_style_box(_style, r)
		_style.set_border_width_all(0)
		var head := StyleBoxFlat.new()
		head.bg_color = UiKit.NAVY
		head.corner_radius_top_left = 10
		head.corner_radius_top_right = 10
		draw_style_box(head, Rect2(0, 0, size.x, 32))
		_text(UiKit.FONT_TITLE, "CESSÃO DE CRÉDITO", Vector2(14, 24), 19, UiKit.YELLOW)
		_text(UiKit.FONT_BODY, "CEDENTE", Vector2(14, 55), 11, UiKit.INK_SOFT)
		_text(UiKit.FONT_TITLE, from_name.to_upper(), Vector2(104, 57), 17, UiKit.NAVY)
		_text(UiKit.FONT_BODY, "CESSIONÁRIO", Vector2(14, 79), 11, UiKit.INK_SOFT)
		_text(UiKit.FONT_TITLE, to_name.to_upper(), Vector2(104, 81), 17, UiKit.NAVY)
		var gray := Color(0.62, 0.65, 0.74)
		draw_line(Vector2(14, 95), Vector2(size.x - 74, 95), gray, 3.0)
		draw_line(Vector2(14, 103), Vector2(size.x - 120, 103), gray, 3.0)
		# Linha da assinatura e o nome embaixo dela.
		draw_line(Vector2(14, 144), Vector2(170, 144), Color(RaceItem.INK, 0.6), 1.5, true)
		_text(UiKit.FONT_BODY, "Celerino, tabelião fantasma", Vector2(16, 157), 10, UiKit.INK_SOFT)

	func _text(font: Font, text: String, pos: Vector2, fs: int, color: Color) -> void:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - pos.x - 8.0, fs, color)


## A assinatura do Celerino (rabisco cursivo com laçadas e um traço embaixo).
class Signature:
	extends Control

	func _draw() -> void:
		var pts := PackedVector2Array()
		var w := size.x
		var h := size.y
		for i in 110:
			var t := float(i) / 109.0
			var loop := t * TAU * 6.5
			var x := 8.0 + t * (w - 26.0) + 7.0 * cos(loop) * (0.6 + 0.4 * sin(t * 7.0))
			var y := h * 0.55 - 11.0 * sin(loop) * (0.55 + 0.45 * sin(t * 4.3 + 1.0)) + 5.0 * t
			pts.append(Vector2(x, y))
		draw_polyline(pts, RaceItem.INK, 2.2, true)
		draw_line(Vector2(6.0, h - 4.0), Vector2(w - 8.0, h - 9.0), RaceItem.INK, 1.8, true)


## Carimbo vermelho "CEDIDO".
class Stamp:
	extends Control

	func _draw() -> void:
		var red := Color(RaceItem.BADGE, 0.9)
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = red
		box.set_border_width_all(3)
		box.set_corner_radius_all(6)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var font: Font = UiKit.FONT_TITLE
		var fs := 20
		var text := "CEDIDO"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := size.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2((size.x - w) * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = CARD_SIZE
	pivot_offset = size * 0.5
	_paper = Paper.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.size = CARD_SIZE
	add_child(_paper)
	_icon = ItemIcon.new()
	_icon.size = Vector2(50, 50)
	_icon.position = Vector2(CARD_SIZE.x - 60, 38)
	add_child(_icon)
	_sign_clip = Control.new()
	_sign_clip.clip_contents = true
	_sign_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign_clip.position = SIGN_RECT.position
	_sign_clip.size = Vector2(0.0, SIGN_RECT.size.y)
	add_child(_sign_clip)
	var signature := Signature.new()
	signature.mouse_filter = Control.MOUSE_FILTER_IGNORE
	signature.size = SIGN_RECT.size
	_sign_clip.add_child(signature)
	_stamp = Stamp.new()
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.size = Vector2(100, 36)
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.position = Vector2(CARD_SIZE.x - 112, 112)
	_stamp.rotation = -0.22
	add_child(_stamp)
	visible = false


## Lugar do contrato (canto superior esquerdo do cartão, coordenadas do pai).
func set_home(pos: Vector2) -> void:
	_home = pos
	position = pos


## Roda a animação inteira em `duration` segundos e termina dentro do slot (`target`,
## centro em coordenadas do pai).
func play(kind: int, from_name: String, to_name: String, duration: float, target: Vector2) -> void:
	_paper.from_name = from_name
	_paper.to_name = to_name
	_paper.queue_redraw()
	_icon.kind = kind
	if _tween:
		_tween.kill()
	var k := clampf(duration / 2.0, 0.5, 2.0)
	visible = true
	position = _home + Vector2(-40.0, 0.0)
	scale = Vector2.ONE * 0.8 * card_scale
	rotation = -0.06
	modulate.a = 0.0
	_sign_clip.size.x = 0.0
	_stamp.modulate.a = 0.0
	_stamp.scale = Vector2.ONE * 2.2
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(self, "position", _home, 0.25 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * card_scale, 0.25 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", 0.02, 0.25 * k)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12 * k)
	_tween.chain().tween_property(_sign_clip, "size:x", SIGN_RECT.size.x, 0.75 * k) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_callback(Sfx.play.bind(self, &"bump", -10.0, 1.6))
	_tween.tween_property(_stamp, "scale", Vector2.ONE, 0.12 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_stamp, "modulate:a", 1.0, 0.08 * k)
	_tween.chain().tween_interval(0.22 * k)
	_tween.chain().tween_property(self, "position", target - size * 0.5, 0.36 * k) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", Vector2.ONE * 0.15 * card_scale, 0.36 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.36 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)


func clear() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	hide()
