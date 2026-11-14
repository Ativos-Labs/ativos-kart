class_name RibbonLabel
extends Control
## Faixa inclinada com texto em itálico (títulos de tela e de janelas).

@export var text := "TÍTULO":
	set(value):
		text = value
		update_minimum_size()
		queue_redraw()
@export var font_size := 42:
	set(value):
		font_size = value
		update_minimum_size()
		queue_redraw()
## Cor da faixa.
@export var color := UiKit.NAVY:
	set(value):
		color = value
		queue_redraw()
@export var text_color := Color.WHITE
## Listra de destaque na ponta esquerda.
@export var accent := UiKit.YELLOW
@export var slant := 24.0


func _get_minimum_size() -> Vector2:
	var font: Font = UiKit.FONT_ITALIC
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2(w + slant * 2.0 + 64.0, font_size * 1.35)


func _draw() -> void:
	var h := size.y
	var stripe := 16.0
	UiKit.draw_ribbon(self, Rect2(stripe + 6.0, 0.0, size.x - stripe - 6.0, h), slant, color)
	var accent_pts := UiKit.slant_points(Rect2(0.0, 0.0, stripe + slant, h), slant)
	draw_colored_polygon(accent_pts, accent)
	var font: Font = UiKit.FONT_ITALIC
	var baseline := h * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	UiKit.draw_outlined(self, font, Vector2(stripe + slant + 26.0, baseline), text, font_size,
			text_color, Color(0.02, 0.04, 0.12, 0.85), maxi(4, font_size / 6))
