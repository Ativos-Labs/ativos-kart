class_name PlayerTag
extends Control
## Etiqueta de um jogador ("J2") na cor dele, com uma linha opcional ao lado (o nome
## do controle ou "Aperte A"). Usada nas telas de escolha e no painel de entrada.

var tag := "J1":
	set(value):
		tag = value
		queue_redraw()
var color: Color = PlayerSlot.COLORS[0]:
	set(value):
		color = value
		queue_redraw()
var note := "":
	set(value):
		note = value
		update_minimum_size()
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup_slot(slot: PlayerSlot, p_note := "") -> void:
	tag = slot.tag
	color = slot.color
	note = p_note


func _get_minimum_size() -> Vector2:
	var w := 86.0
	if note != "":
		w += UiKit.FONT_BODY.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 30.0
	return Vector2(w, 50.0)


func _draw() -> void:
	var h := size.y
	var pill := Rect2(Vector2(0, 0), Vector2(86.0, h))
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.3)
	shadow.set_corner_radius_all(int(h * 0.5))
	if note != "":
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.02, 0.04, 0.12, 0.55)
		back.set_corner_radius_all(int(h * 0.5))
		back.draw(get_canvas_item(), Rect2(Vector2(40.0, 4.0), Vector2(size.x - 40.0, h - 8.0)))
		draw_string(UiKit.FONT_BODY, Vector2(100.0, h * 0.5 + 7.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	shadow.draw(get_canvas_item(), Rect2(pill.position + Vector2(0, 4), pill.size))
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(h * 0.5))
	box.border_color = Color.WHITE
	box.set_border_width_all(4)
	box.draw(get_canvas_item(), pill)
	var font: Font = UiKit.FONT_ITALIC
	var fs := int(h * 0.62)
	var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := h * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	UiKit.draw_outlined(self, font, Vector2(pill.get_center().x - tw * 0.5, baseline), tag, fs, Color.WHITE, UiKit.NAVY, 8)
