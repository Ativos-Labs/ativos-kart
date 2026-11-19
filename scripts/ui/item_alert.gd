class_name ItemAlert
extends Control
## Aviso no alto do HUD de que um item vem atrás do jogador (PEC dos Precatórios,
## Intimação): o ícone do item num círculo escuro, um anel vermelho pulsando em volta e
## uma faixa vermelha com o texto embaixo. Aparece e some com um pulinho. Quando o perigo
## é resolvido (a Liminar suspende a PEC), o aviso fica verde um instante (show_resolved).

## Raio do círculo (px); o controle ocupa o círculo e a faixa embaixo.
var radius := 46.0:
	set(value):
		radius = value
		_resize()
var kind := RaceItem.NONE
## Mostrando o aviso verde de resolvido (até ele sumir sozinho).
var resolved := false
var _text := ""
var _t := 0.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_resize()


## Mostra o aviso do item `p_kind` (RaceItem.NONE esconde).
func show_alert(p_kind: int) -> void:
	if resolved:
		# O verde fica até o fim; um aviso novo (outro item vindo) passa na frente.
		if p_kind == RaceItem.NONE:
			return
		resolved = false
	elif p_kind == kind:
		return
	kind = p_kind
	if _tween:
		_tween.kill()
	pivot_offset = size * 0.5
	if kind == RaceItem.NONE:
		_tween = create_tween()
		_tween.tween_property(self, "scale", Vector2.ONE * 0.2, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_tween.tween_callback(hide)
		return
	_text = "PEC A CAMINHO!" if kind == RaceItem.Kind.PEC else "%s!" % RaceItem.short_name(kind)
	_t = 0.0
	visible = true
	scale = Vector2.ONE * 0.2
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


## O perigo de `p_kind` passou (`text`, ex.: "PEC SUSPENSA!"): o aviso fica verde, pula
## e some sozinho.
func show_resolved(p_kind: int, text: String) -> void:
	kind = p_kind
	resolved = true
	_text = text
	_t = 0.0
	visible = true
	pivot_offset = size * 0.5
	if _tween:
		_tween.kill()
	scale = Vector2.ONE * 1.3
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(1.1)
	_tween.tween_property(self, "scale", Vector2.ONE * 0.2, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		resolved = false
		kind = RaceItem.NONE
		hide())
	queue_redraw()


func _process(delta: float) -> void:
	if visible and kind != RaceItem.NONE:
		_t += delta
		queue_redraw()


func _resize() -> void:
	custom_minimum_size = Vector2(radius * 5.2, radius * 2.0 + radius * 0.9)
	size = custom_minimum_size


func _draw() -> void:
	if kind == RaceItem.NONE:
		return
	var c := Vector2(size.x * 0.5, radius)
	var pulse := 0.5 + 0.5 * sin(_t * TAU * 2.5)
	var tone: Color = UiKit.GREEN if resolved else UiKit.RED
	# Anel que cresce e some, por trás do círculo.
	var wave := fmod(_t * 1.6, 1.0)
	draw_arc(c, radius * (1.0 + wave * 0.45), 0.0, TAU, 40, Color(tone, 0.7 * (1.0 - wave)), radius * 0.12, true)
	draw_circle(c + Vector2(0.0, 4.0), radius, Color(0, 0, 0, 0.3))
	draw_circle(c, radius, tone.lerp(Color.WHITE, pulse * 0.35))
	draw_circle(c, radius * 0.86, UiKit.NAVY)
	RaceItem.draw_icon(self, kind, c, radius * 0.66)
	# Faixa com o texto.
	var font: Font = UiKit.FONT_TITLE
	var fs := int(radius * 0.42)
	var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var band := Rect2(Vector2(c.x - w * 0.5 - radius * 0.3, c.y + radius * 0.8), Vector2(w + radius * 0.6, radius * 0.62))
	UiKit.draw_ribbon(self, band, radius * 0.14, tone.lerp(Color("178a4a") if resolved else Color("c41c22"), pulse))
	var base := band.position.y + (band.size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	UiKit.draw_outlined(self, font, Vector2(c.x - w * 0.5, base), _text, fs, Color.WHITE, UiKit.NAVY, maxi(int(radius * 0.1), 3))
