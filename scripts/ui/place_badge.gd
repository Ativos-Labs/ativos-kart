class_name PlaceBadge
extends Control
## Posição do jogador na corrida ("1º", "2º"...): ouro, prata e bronze no pódio.
## Só redesenha quando a posição mostrada muda; a troca espera a posição ficar
## estável um instante (dois karts lado a lado não fazem o número piscar) e entra
## com um "pulo".

## Tempo (s) que uma posição nova precisa durar para aparecer.
const SETTLE_TIME := 0.2
const PODIUM_COLORS := [Color("ffd21a"), Color("dfe6f2"), Color("f0a061")]

var place := 0
var total := 0
var _pending := 0
var _pending_time := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): pivot_offset = Vector2(size.x * 0.3, size.y * 0.6))


## Posição atual (chame a cada quadro; a troca aparece quando estabiliza).
func set_place(p_place: int, p_total: int) -> void:
	total = p_total
	if place == 0:
		place = p_place
		_pending = p_place
		queue_redraw()
		return
	if p_place != _pending:
		_pending = p_place
		_pending_time = 0.0


func _process(delta: float) -> void:
	if _pending == place or _pending == 0:
		return
	_pending_time += delta
	if _pending_time < SETTLE_TIME:
		return
	var gained := _pending < place
	place = _pending
	queue_redraw()
	if _tween:
		_tween.kill()
	scale = Vector2.ONE * (1.35 if gained else 0.8)
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	if gained:
		Sfx.play(self, &"place_up", -16.0, 0.9 + 0.05 * (total - place))


func _draw() -> void:
	if place <= 0 or total <= 1:
		return
	var font: Font = UiKit.FONT_ITALIC
	var number := str(place)
	var big := int(size.y * 0.92)
	var small := int(big * 0.45)
	var color: Color = PODIUM_COLORS[place - 1] if place <= 3 else Color.WHITE
	var outline := UiKit.NAVY
	var baseline := size.y * 0.5 + (font.get_ascent(big) - font.get_descent(big)) * 0.5
	var x := 6.0
	var w := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	# Sombra, contorno e número; o "º" fica no alto, à direita.
	draw_string_outline(font, Vector2(x + 3.0, baseline + 6.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1, big, 22, Color(0, 0, 0, 0.35))
	UiKit.draw_outlined(self, font, Vector2(x, baseline), number, big, color, outline, 22)
	var sup := Vector2(x + w + 2.0, baseline - big * 0.42)
	UiKit.draw_outlined(self, font, sup, "º", small, color, outline, 14)
	# "de 8" embaixo do º.
	var of_text := "de %d" % total
	UiKit.draw_outlined(self, UiKit.FONT_BODY, Vector2(x + w + 4.0, baseline - 4.0), of_text, int(small * 0.55),
			Color(0.9, 0.93, 1.0), outline, 8)
