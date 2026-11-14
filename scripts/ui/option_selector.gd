class_name OptionSelector
extends Control
## Linha de opção "Nome   ◀ valor ▶" (jogadores, cilindrada, dificuldade...). Com o
## foco, ← e → trocam o valor; o mouse troca clicando nas setas (ou no meio, que
## avança). Valores a partir de `limit` aparecem apagados e não podem ser escolhidos.

signal changed(index: int)

var caption := ""
var options := PackedStringArray()
var index := 0
## Primeiro valor que não pode ser escolhido (-1 = todos podem).
var limit := -1:
	set(value):
		limit = value
		if limit >= 0 and index >= limit:
			set_index(maxi(limit - 1, 0))
		queue_redraw()

var _flash := 0.0
var _flash_dir := 0
var _last_step_ms := 0


func setup(p_caption: String, p_options: PackedStringArray, p_index := 0) -> void:
	caption = p_caption
	options = p_options
	index = clampi(p_index, 0, options.size() - 1)
	custom_minimum_size = Vector2(600, 48)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func(): grab_focus())
	set_process(false)
	queue_redraw()


func set_index(i: int, emit := true) -> void:
	i = clampi(i, 0, options.size() - 1)
	if i == index:
		return
	index = i
	queue_redraw()
	if emit:
		changed.emit(index)


func get_value() -> String:
	return options[index] if index < options.size() else ""


func _allowed() -> int:
	return options.size() if limit < 0 else mini(limit, options.size())


func step(dir: int) -> void:
	_last_step_ms = Time.get_ticks_msec()
	var next := index + dir
	_flash = 0.2
	_flash_dir = dir
	set_process(true)
	if next < 0 or next >= _allowed():
		Sfx.play(self, &"ui_back", -14.0)
		queue_redraw()
		return
	Sfx.play(self, &"ui_move", -12.0)
	set_index(next)


func _process(delta: float) -> void:
	_flash -= delta
	queue_redraw()
	if _flash <= 0.0:
		set_process(false)


func _gui_input(event: InputEvent) -> void:
	# O analógico manda vários eventos seguidos: um passo a cada 0,18 s.
	if event is InputEventJoypadMotion and Time.get_ticks_msec() - _last_step_ms < 180:
		if event.is_action("ui_left") or event.is_action("ui_right"):
			accept_event()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("esquerda"):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("direita"):
		step(1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var x: float = event.position.x
		if x < _value_rect().position.x + 40.0:
			step(-1)
		elif x > _value_rect().end.x - 40.0:
			step(1)
		else:
			step(1 if index + 1 < _allowed() else -index)
		accept_event()


func _value_rect() -> Rect2:
	var w := minf(300.0, size.x * 0.52)
	return Rect2(Vector2(size.x - w - 8.0, 6.0), Vector2(w, size.y - 12.0))


func _draw() -> void:
	var focused := has_focus()
	var rect := Rect2(Vector2.ZERO, size)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE if focused else Color(1, 1, 1, 0.9)
	box.set_corner_radius_all(int(size.y * 0.5))
	box.border_color = UiKit.YELLOW if focused else Color(0, 0, 0, 0.0)
	box.set_border_width_all(4 if focused else 0)
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	box.draw(get_canvas_item(), rect)
	var font: Font = UiKit.FONT_BODY
	var fs := 20
	var baseline := size.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(26, baseline), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK_SOFT)

	var vr := _value_rect()
	var pill := StyleBoxFlat.new()
	pill.bg_color = UiKit.NAVY_LIGHT if focused else UiKit.NAVY
	pill.set_corner_radius_all(int(vr.size.y * 0.5))
	pill.draw(get_canvas_item(), vr)
	var tf: Font = UiKit.FONT_ITALIC
	var tfs := 24
	var value := get_value()
	var tw := tf.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var tb := vr.position.y + vr.size.y * 0.5 + (tf.get_ascent(tfs) - tf.get_descent(tfs)) * 0.5
	draw_string(tf, Vector2(vr.get_center().x - tw * 0.5, tb), value, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, UiKit.YELLOW)
	# Setas: apagadas quando não dá para ir mais para aquele lado.
	for dir: int in [-1, 1]:
		var can := index + dir >= 0 and index + dir < _allowed()
		var nudge := (_flash / 0.2) * 5.0 * dir if _flash > 0.0 and _flash_dir == dir else 0.0
		var cx: float = (vr.position.x + 22.0 if dir < 0 else vr.end.x - 22.0) + nudge
		var cy := vr.get_center().y
		var col := Color.WHITE if can else Color(1, 1, 1, 0.25)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx + dir * 8.0, cy), Vector2(cx - dir * 6.0, cy - 9.0), Vector2(cx - dir * 6.0, cy + 9.0),
		]), col)
