class_name StartLights
extends Control
## Semáforo de largada: 3 luzes vermelhas que acendem na contagem e ficam verdes no "VAI!".

var step := 0:
	set(value):
		step = value
		queue_redraw()


func _draw() -> void:
	var count := 3
	var lamp := size.y * 0.32
	var housing := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.15, 0.92)
	sb.set_corner_radius_all(int(size.y * 0.5))
	sb.border_color = Color(1, 1, 1, 0.85)
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 5)
	sb.draw(get_canvas_item(), housing)
	var spacing := size.x / count
	for i in count:
		var c := Vector2(spacing * (i + 0.5), size.y * 0.5)
		var on := step >= 4 or i < step
		var col := Color(0.2, 0.22, 0.3)
		if step >= 4:
			col = UiKit.GREEN
		elif on:
			col = UiKit.RED
		if on:
			draw_circle(c, lamp * 1.45, Color(col, 0.25))
		draw_circle(c, lamp, col)
		draw_circle(c - Vector2(lamp * 0.3, lamp * 0.35), lamp * 0.35, Color(1, 1, 1, 0.35 if on else 0.12))
