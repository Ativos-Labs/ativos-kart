class_name ResultRow
extends Control
## Linha inclinada da tela de resultado ("VOLTA 1   0:31.240").

var left_text := ""
var right_text := ""
var tag := ""
var highlight := false
var big := false
## Deslocamento horizontal do desenho (animação de entrada).
var slide := 0.0:
	set(value):
		slide = value
		queue_redraw()


func setup(p_left: String, p_right: String, p_highlight := false, p_big := false, p_tag := "") -> void:
	left_text = p_left
	right_text = p_right
	highlight = p_highlight
	big = p_big
	tag = p_tag
	custom_minimum_size = Vector2(520, 66 if big else 48)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(slide, 0.0))
	var rect := Rect2(Vector2.ZERO, size)
	var slant := size.y * 0.35
	var pts := UiKit.slant_points(rect, slant)
	draw_colored_polygon(UiKit.offset_points(pts, Vector2(0, 4)), Color(0, 0, 0, 0.3))
	var top := UiKit.YELLOW_LIGHT if highlight else Color.WHITE
	var bottom := UiKit.YELLOW_DARK if highlight else UiKit.WHITE_BOTTOM
	draw_colored_polygon(pts, Color.WHITE)
	UiKit.draw_gradient_poly(self, UiKit.slant_points(rect.grow(-3.0), slant - 1.0), top, bottom, 0.0, size.y)
	var font: Font = UiKit.FONT_ITALIC if big else UiKit.FONT_BODY
	var fs := 34 if big else 22
	var baseline := size.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(slant + 22.0, baseline), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK)
	var tf: Font = UiKit.FONT_ITALIC
	var tfs := 40 if big else 28
	var tb := size.y * 0.5 + (tf.get_ascent(tfs) - tf.get_descent(tfs)) * 0.5
	var tw := tf.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	draw_string(tf, Vector2(size.x - slant - 26.0 - tw, tb), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, UiKit.INK)
	if tag != "":
		var tag_font: Font = UiKit.FONT_BODY
		var tag_w := tag_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
		var tag_rect := Rect2(Vector2(size.x - slant - 40.0 - tw - tag_w, size.y * 0.5 - 12.0), Vector2(tag_w, 24))
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiKit.RED
		sb.set_corner_radius_all(12)
		sb.draw(get_canvas_item(), tag_rect)
		draw_string(tag_font, tag_rect.position + Vector2(9, 18), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
