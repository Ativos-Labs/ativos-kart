class_name HudPill
extends Control
## Pílula escura do canto da tela da corrida: um ícone desenhado (moeda Ativos ou
## bandeira quadriculada) e um número em itálico. A largura acompanha o texto. Só
## redesenha quando o texto muda; `bump()` dá um pulinho e `flash()` pisca em vermelho.

enum Icon { COIN, FLAG }

const LOGO := preload("res://assets/logos/ativos_icone.png")
const GOLD := Color("ffc928")
const GOLD_DARK := Color("c98a00")
const GOLD_LIGHT := Color("fff1a6")
const BACKGROUND := Color(0.03, 0.05, 0.12, 0.62)
const FLAG_DARK := Color(0.07, 0.08, 0.11)

var icon := Icon.COIN
var text := ""
var text_color := Color.WHITE
var outline_color := Color(0.0, 0.0, 0.0, 0.55)
## Altura da pílula (unidades de interface).
var height := 58.0:
	set(value):
		height = value
		_resize()
var _style := StyleBoxFlat.new()
var _tween: Tween


func _init(p_icon := Icon.COIN, p_height := 58.0) -> void:
	icon = p_icon
	height = p_height
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): pivot_offset = size * 0.5)


## Troca o texto (e a cor). Retorna false se nada mudou.
func set_text(value: String, color := Color.WHITE, outline := Color(0.0, 0.0, 0.0, 0.55)) -> bool:
	if value == text and color == text_color and outline == outline_color:
		return false
	text = value
	text_color = color
	outline_color = outline
	_resize()
	queue_redraw()
	return true


func bump(amount := 1.2) -> void:
	if _tween:
		_tween.kill()
	modulate = Color.WHITE
	scale = Vector2.ONE * amount
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.3)


func flash() -> void:
	if _tween:
		_tween.kill()
	scale = Vector2.ONE
	_tween = create_tween()
	for i in 3:
		_tween.tween_property(self, "modulate", Color(1.0, 0.35, 0.35), 0.06)
		_tween.tween_property(self, "modulate", Color.WHITE, 0.1)


func _font_size() -> int:
	return int(height * 0.66)


func _pad() -> float:
	return height * 0.2


func _icon_width() -> float:
	return height * 0.66 if icon == Icon.COIN else height * 0.62


func _resize() -> void:
	var w := UiKit.FONT_ITALIC.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x
	custom_minimum_size = Vector2(ceilf(_pad() * 2.3 + _icon_width() + height * 0.14 + w), height)


func _draw() -> void:
	var h := size.y
	_style.bg_color = BACKGROUND
	_style.set_corner_radius_all(int(h * 0.3))
	_style.set_border_width_all(2)
	_style.border_color = Color(1.0, 1.0, 1.0, 0.1)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var x := _pad()
	if icon == Icon.COIN:
		_draw_coin(Vector2(x + _icon_width() * 0.5, h * 0.5), _icon_width() * 0.5)
	else:
		_draw_flag(Rect2(x, h * 0.18, _icon_width(), h * 0.64))
	x += _icon_width() + h * 0.14
	var font: Font = UiKit.FONT_ITALIC
	var fs := _font_size()
	var baseline := h * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(x + 2.0, baseline + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35))
	UiKit.draw_outlined(self, font, Vector2(x, baseline), text, fs, text_color, outline_color, 6)


## Moeda Ativos (a mesma das pistas): borda escura, corpo dourado com brilho e o "at".
func _draw_coin(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(1.5, 3.0), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, UiKit.NAVY)
	draw_circle(c, r - 2.0, GOLD_DARK)
	draw_circle(c, r * 0.8, GOLD)
	draw_circle(c + Vector2(-r * 0.22, -r * 0.24), r * 0.4, Color(GOLD_LIGHT, 0.45))
	var logo_w := r * 1.15
	var logo_h := logo_w * LOGO.get_height() / LOGO.get_width()
	draw_texture_rect(LOGO, Rect2(c - Vector2(logo_w, logo_h) * 0.5, Vector2(logo_w, logo_h)), false,
			Color(0.55, 0.32, 0.0, 0.9))


## Bandeira quadriculada tremulando, presa num mastro (4 × 3 casas, com borda branca).
func _draw_flag(rect: Rect2) -> void:
	var pole_x := rect.position.x + rect.size.x * 0.08
	draw_line(Vector2(pole_x, rect.position.y), Vector2(pole_x, rect.end.y), Color(0.85, 0.88, 0.95), 3.0, true)
	var left := pole_x + 1.5
	var w := rect.end.x - left
	var top := rect.position.y + 1.0
	var fh := rect.size.y * 0.62
	var cols := 4
	var rows := 3
	# Ponto da bandeira: u (0..1 ao longo) e v (0..1 de cima para baixo), com uma onda.
	var at := func(u: float, v: float) -> Vector2:
		return Vector2(left + u * w, top + v * fh + sin(u * PI * 1.6) * fh * 0.12)
	var border := 2.0
	var outline := PackedVector2Array()
	for k in 9:
		outline.append(at.call(k / 8.0, 0.0) + Vector2(0.0, -border))
	for k in 9:
		outline.append(at.call(1.0 - k / 8.0, 1.0) + Vector2(0.0, border))
	outline[8] += Vector2(border, 0.0)
	outline[9] += Vector2(border, 0.0)
	draw_colored_polygon(outline, Color.WHITE)
	for i in cols:
		for j in rows:
			if (i + j) % 2 == 0:
				continue
			var u0 := float(i) / cols
			var u1 := float(i + 1) / cols
			var v0 := float(j) / rows
			var v1 := float(j + 1) / rows
			draw_colored_polygon(PackedVector2Array([at.call(u0, v0), at.call(u1, v0), at.call(u1, v1), at.call(u0, v1)]),
					FLAG_DARK)
