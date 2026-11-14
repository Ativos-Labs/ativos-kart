class_name StarRating
extends Control
## Estrelas de dificuldade (1 a 5).

@export var value := 2:
	set(v):
		value = v
		queue_redraw()
@export var max_value := 5


func _get_minimum_size() -> Vector2:
	return Vector2(max_value * 26.0, 26.0)


func _draw() -> void:
	var r := minf(size.y * 0.5, size.x / max_value * 0.5) - 1.0
	for i in max_value:
		var c := Vector2(r + 1.0 + i * (r * 2.0 + 2.0), size.y * 0.5)
		var pts := PackedVector2Array()
		for k in 10:
			var rad := r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2.from_angle(-PI * 0.5 + k * PI / 5.0) * rad)
		var filled := i < value
		draw_colored_polygon(UiKit.offset_points(pts, Vector2(0, 2)), Color(0, 0, 0, 0.18))
		draw_colored_polygon(pts, UiKit.YELLOW if filled else Color(0.82, 0.85, 0.9))
		draw_polyline(UiKit.closed(pts), UiKit.YELLOW_DARK if filled else Color(0.68, 0.72, 0.8), 2.0, true)
