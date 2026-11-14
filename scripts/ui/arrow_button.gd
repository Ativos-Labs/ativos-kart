class_name ArrowButton
extends Button
## Botão redondo com seta (trocar kart/personagem). Desenhado por código.

## -1 = seta para a esquerda, 1 = seta para a direita.
@export_enum("Esquerda:-1", "Direita:1") var direction := 1

var _time := 0.0


func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)


## Faz a seta dar um "empurrãozinho" (feedback de navegação pelo teclado).
func flash() -> void:
	_time = 0.25
	set_process(true)


func _process(delta: float) -> void:
	_time -= delta
	queue_redraw()
	if _time <= 0.0:
		set_process(false)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	var hot := (is_hovered() or _time > 0.0) and not disabled
	var push := (_time / 0.25) * 4.0 * direction if _time > 0.0 else 0.0
	c.x += push
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color.WHITE)
	draw_circle(c, r - 3.0, UiKit.YELLOW if hot else Color(0.9, 0.92, 0.96))
	draw_circle(c - Vector2(0, r * 0.35), r * 0.55, Color(1, 1, 1, 0.35))
	var color := UiKit.INK if not disabled else Color(UiKit.INK, 0.3)
	var s := r * 0.48
	var d := float(direction)
	var points := PackedVector2Array([
		c + Vector2(d * s, 0.0),
		c + Vector2(-d * s * 0.7, -s),
		c + Vector2(-d * s * 0.7, s),
	])
	draw_colored_polygon(points, color)
