class_name CoinCounter
extends Control
## Contador de moedas Ativos do HUD: a moeda dourada com o "at" e o número (amarelo
## quando chega no máximo). Só redesenha quando o número muda; ganhar uma moeda dá um
## pulinho e perder pisca em vermelho.

const LOGO := preload("res://assets/logos/ativos_icone.png")
const GOLD := Color("ffc928")
const GOLD_DARK := Color("c98a00")
const GOLD_LIGHT := Color("fff1a6")

var coins := 0
var max_coins := 10
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): pivot_offset = Vector2(size.y * 0.5, size.y * 0.5))


func set_coins(value: int, animate := true) -> void:
	if value == coins:
		return
	var gained := value > coins
	coins = value
	queue_redraw()
	if not animate:
		return
	if _tween:
		_tween.kill()
	if gained:
		scale = Vector2.ONE * 1.22
		modulate = Color.WHITE
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.28)
	else:
		scale = Vector2.ONE
		modulate = Color(1.0, 0.35, 0.35)
		_tween = create_tween()
		for i in 3:
			_tween.tween_property(self, "modulate", Color(1.0, 0.35, 0.35), 0.06)
			_tween.tween_property(self, "modulate", Color.WHITE, 0.1)


func _draw() -> void:
	var r := size.y * 0.42
	var c := Vector2(r + 4.0, size.y * 0.5)
	# Moeda: sombra, borda escura, corpo dourado com brilho e o "at" no meio.
	draw_circle(c + Vector2(2.0, 4.0), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, UiKit.NAVY)
	draw_circle(c, r - 3.0, GOLD_DARK)
	draw_circle(c, r - 7.0, GOLD)
	draw_circle(c + Vector2(-r * 0.22, -r * 0.24), r * 0.42, Color(GOLD_LIGHT, 0.45))
	var logo_w := (r - 9.0) * 1.7
	var logo_h := logo_w * LOGO.get_height() / LOGO.get_width()
	draw_texture_rect(LOGO, Rect2(c - Vector2(logo_w, logo_h) * 0.5, Vector2(logo_w, logo_h)), false, Color(0.55, 0.32, 0.0, 0.9))
	# Número.
	var font: Font = UiKit.FONT_ITALIC
	var big := int(size.y * 0.78)
	var full := coins >= max_coins
	var baseline := size.y * 0.5 + (font.get_ascent(big) - font.get_descent(big)) * 0.5
	var x := c.x + r + 10.0
	UiKit.draw_outlined(self, font, Vector2(x, baseline), "×", int(big * 0.6), Color(0.9, 0.93, 1.0), UiKit.NAVY, 12)
	x += font.get_string_size("×", HORIZONTAL_ALIGNMENT_LEFT, -1, int(big * 0.6)).x + 4.0
	UiKit.draw_outlined(self, font, Vector2(x, baseline), str(coins), big, UiKit.YELLOW if full else Color.WHITE, UiKit.NAVY, 16)
	if full:
		x += font.get_string_size(str(coins), HORIZONTAL_ALIGNMENT_LEFT, -1, big).x + 6.0
		UiKit.draw_outlined(self, UiKit.FONT_BODY, Vector2(x, baseline - big * 0.42), "MÁX", int(big * 0.34), UiKit.YELLOW, UiKit.NAVY, 8)
