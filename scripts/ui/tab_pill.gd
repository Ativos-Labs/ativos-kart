class_name TabPill
extends Button
## Aba da tela de opções ("Som", "Tela", "Gráficos", "Teclas"): amarela quando é a
## aba aberta.

## Esta é a aba aberta.
var active := false:
	set(value):
		active = value
		queue_redraw()
var icon_kind := ""


func _ready() -> void:
	custom_minimum_size = Vector2(150, 48)
	focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(color, Color(0, 0, 0, 0))
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func(): grab_focus())


func _on_focus_entered() -> void:
	queue_redraw()
	if is_visible_in_tree():
		Sfx.play(self, &"ui_move", -14.0)


func _draw() -> void:
	var focused := has_focus()
	var rect := Rect2(Vector2(0, 2), size - Vector2(0, 4))
	var box := StyleBoxFlat.new()
	box.bg_color = UiKit.YELLOW if active else UiKit.NAVY
	box.set_corner_radius_all(int(rect.size.y * 0.5))
	box.border_width_bottom = 4
	box.border_color = UiKit.YELLOW_DARK if active else Color(0, 0, 0, 0.35)
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 2)
	box.draw(get_canvas_item(), rect)
	if focused:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_corner_radius_all(int(rect.size.y * 0.5) + 3)
		ring.set_border_width_all(3)
		ring.border_color = UiKit.ORANGE if active else UiKit.YELLOW
		ring.draw(get_canvas_item(), rect.grow(3.0))
	var ink := UiKit.INK if active else Color.WHITE
	var font: Font = UiKit.FONT_ITALIC
	var fs := 24
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var icon_w := 30.0 if icon_kind != "" else 0.0
	var x := (size.x - tw - icon_w) * 0.5
	if icon_kind != "":
		UiKit.draw_icon(self, icon_kind, Vector2(x + 11.0, rect.get_center().y - 1.0), 12.0, ink)
	var baseline := rect.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - 1.0
	draw_string(font, Vector2(x + icon_w, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
