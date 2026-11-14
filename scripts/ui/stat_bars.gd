class_name StatBars
extends Control
## Barras de atributos (Velocidade, Aceleração, Controle, Peso) em amarelo,
## com animação ao trocar de personagem ou de kart.

const ROWS := [
	["speed", "Velocidade"],
	["acceleration", "Aceleração"],
	["handling", "Controle"],
	["weight", "Peso"],
]
const MAX_VALUE := 5.0

## Texto escuro (para painéis claros) ou claro (sobre fundo escuro).
@export var dark_text := true
@export var row_height := 36.0
@export var label_width := 150.0

var _values := {}
var _targets := {}


func _ready() -> void:
	for row in ROWS:
		_values[row[0]] = 0.0
		_targets[row[0]] = 0.0
	set_process(false)


func _get_minimum_size() -> Vector2:
	return Vector2(label_width + 220.0, row_height * ROWS.size())


func set_stats(stats: Dictionary, animate := true) -> void:
	for row in ROWS:
		var key: String = row[0]
		_targets[key] = float(stats.get(key, 0))
		if not animate:
			_values[key] = _targets[key]
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var moving := false
	for key in _targets:
		var v: float = _values[key]
		var t: float = _targets[key]
		v = move_toward(v, t, delta * 12.0)
		_values[key] = v
		moving = moving or not is_equal_approx(v, t)
	queue_redraw()
	if not moving:
		set_process(false)


func _draw() -> void:
	var font: Font = UiKit.FONT_BODY
	var fs := 19
	var text_color := UiKit.INK if dark_text else Color.WHITE
	var bar_x := label_width
	var bar_w := size.x - label_width - 6.0
	for i in ROWS.size():
		var key: String = ROWS[i][0]
		var y := i * row_height
		var baseline := y + row_height * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(0, baseline), ROWS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		var bar := Rect2(bar_x, y + row_height * 0.24, bar_w, row_height * 0.52)
		var slant := bar.size.y * 0.45
		var track := UiKit.slant_points(bar, slant)
		draw_colored_polygon(UiKit.offset_points(track, Vector2(0, 2)), Color(0, 0, 0, 0.2))
		draw_colored_polygon(track, Color(0.1, 0.13, 0.25, 0.85) if dark_text else Color(0, 0, 0, 0.45))
		var value: float = clampf(_values.get(key, 0.0) / MAX_VALUE, 0.0, 1.0)
		if value > 0.01:
			var fill_rect := Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4.0) * value, bar.size.y - 4.0))
			var fill := UiKit.slant_points(fill_rect, slant * 0.9)
			UiKit.draw_gradient_poly(self, fill, UiKit.YELLOW_LIGHT, UiKit.YELLOW_DARK, fill_rect.position.y, fill_rect.end.y)
		# Divisões a cada ponto.
		for s in range(1, int(MAX_VALUE)):
			var fx := bar.position.x + bar.size.x * s / MAX_VALUE
			draw_line(Vector2(fx + slant * 0.5, bar.position.y + 2), Vector2(fx - slant * 0.5, bar.end.y - 2),
					Color(0.1, 0.13, 0.25, 0.55), 2.0, true)
