class_name VolumeSlider
extends Control
## Linha de volume "Música   ▂▃▄▅▆▇ 80%" (tela de opções). Com o foco, ← e → mudam de
## 10 em 10%; o mouse clica ou arrasta na barra.

signal changed(value: float)

const STEPS := 10

var caption := ""
## 0 a 1.
var value := 1.0

var _dragging := false


func setup(p_caption: String, p_value: float) -> void:
	caption = p_caption
	value = _snap(p_value)
	custom_minimum_size = Vector2(600, 48)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func(): grab_focus())
	queue_redraw()


func set_value(v: float, emit := true) -> void:
	v = _snap(v)
	if is_equal_approx(v, value):
		return
	value = v
	queue_redraw()
	if emit:
		changed.emit(value)


func step(dir: int) -> void:
	var next := value + float(dir) / STEPS
	if next < -0.001 or next > 1.001:
		Sfx.play(self, &"ui_back", -14.0)
		return
	set_value(next)
	# Depois de mudar: no volume dos efeitos o bipe já sai no volume novo.
	Sfx.play(self, &"ui_move", -10.0)


func _snap(v: float) -> float:
	return clampf(roundf(v * STEPS) / STEPS, 0.0, 1.0)


func _gui_input(event: InputEvent) -> void:
	# O analógico chega como ui_left/ui_right (MenuInput), um passo por vez.
	if event is InputEventJoypadMotion:
		return
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("esquerda", true):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("direita", true):
		step(1)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_from_mouse(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_mouse(event.position.x)
		accept_event()


func _set_from_mouse(x: float) -> void:
	var bar := _bar_rect()
	var before := value
	set_value(clampf((x - bar.position.x) / bar.size.x, 0.0, 1.0))
	if not is_equal_approx(before, value):
		Sfx.play(self, &"ui_move", -10.0)


func _value_rect() -> Rect2:
	var w := minf(300.0, size.x * 0.52)
	return Rect2(Vector2(size.x - w - 8.0, 6.0), Vector2(w, size.y - 12.0))


## Onde ficam os degraus (dentro da pílula azul, antes do número).
func _bar_rect() -> Rect2:
	var vr := _value_rect()
	return Rect2(vr.position + Vector2(18.0, 6.0), Vector2(vr.size.x - 100.0, vr.size.y - 12.0))


func _draw() -> void:
	var focused := has_focus()
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE if focused else Color(1, 1, 1, 0.9)
	box.set_corner_radius_all(int(size.y * 0.5))
	box.border_color = UiKit.YELLOW if focused else Color(0, 0, 0, 0.0)
	box.set_border_width_all(4 if focused else 0)
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	box.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var font: Font = UiKit.FONT_BODY
	var fs := 20
	var baseline := size.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(26, baseline), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.INK_SOFT)

	var vr := _value_rect()
	var pill := StyleBoxFlat.new()
	pill.bg_color = UiKit.NAVY_LIGHT if focused else UiKit.NAVY
	pill.set_corner_radius_all(int(vr.size.y * 0.5))
	pill.draw(get_canvas_item(), vr)
	# Degraus que crescem da esquerda para a direita (os acesos até o volume).
	var bar := _bar_rect()
	var gap := 3.0
	var w := (bar.size.x - gap * (STEPS - 1)) / STEPS
	var lit := roundi(value * STEPS)
	for i in STEPS:
		var h := bar.size.y * lerpf(0.35, 1.0, float(i) / (STEPS - 1))
		var r := Rect2(bar.position.x + i * (w + gap), bar.end.y - h, w, h)
		var col := UiKit.YELLOW if i < lit else Color(1, 1, 1, 0.16)
		draw_rect(r, col)
	var tf: Font = UiKit.FONT_ITALIC
	var tfs := 22
	var text := "%d%%" % roundi(value * 100.0) if value > 0.0 else "Mudo"
	var tw := tf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var tb := vr.position.y + vr.size.y * 0.5 + (tf.get_ascent(tfs) - tf.get_descent(tfs)) * 0.5
	draw_string(tf, Vector2(vr.end.x - 18.0 - tw, tb), text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs,
			UiKit.YELLOW if value > 0.0 else Color(1, 1, 1, 0.55))
