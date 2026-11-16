class_name KeyButton
extends Button
## Tecla de uma ação na tela de opções ("W", "↑"...). Confirmar (Enter, A ou clique)
## faz a tela esperar a tecla nova; enquanto espera, a tecla pisca.

## Código físico da tecla (0 = vaga vazia).
var physical := 0:
	set(value):
		physical = value
		queue_redraw()
## Esperando a tecla nova.
var listening := false:
	set(value):
		listening = value
		_time = 0.0
		set_process(value)
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(150, 42)
	focus_mode = Control.FOCUS_ALL
	text = ""
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	mouse_entered.connect(func(): grab_focus())
	set_process(false)


func _on_focus_changed(on: bool) -> void:
	queue_redraw()
	if on and is_visible_in_tree():
		Sfx.play(self, &"ui_move", -14.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var focused := has_focus()
	var rect := Rect2(Vector2(0, 2), size - Vector2(0, 4))
	var fill := UiKit.NAVY_LIGHT
	var ink := Color.WHITE
	if listening:
		fill = UiKit.YELLOW_LIGHT.lerp(UiKit.ORANGE, 0.5 + 0.5 * sin(_time * 8.0))
		ink = UiKit.INK
	elif focused:
		fill = UiKit.YELLOW
		ink = UiKit.INK
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(10)
	box.border_width_bottom = 4
	box.border_color = fill.darkened(0.35) if focused or listening else UiKit.NAVY
	box.shadow_color = Color(0, 0, 0, 0.2)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 2)
	box.draw(get_canvas_item(), rect)
	if focused and not listening:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_corner_radius_all(12)
		ring.set_border_width_all(3)
		ring.border_color = Color.WHITE
		ring.draw(get_canvas_item(), rect.grow(2.0))

	var label := "..." if listening else GameSettings.key_name(physical)
	if label == "":
		label = "—"
		ink = Color(ink, 0.4)
	var c := rect.get_center() - Vector2(0, 2)
	if UiKit.ARROW_KEYS.has(label):
		UiKit.draw_arrow(self, c, 9.0, UiKit.ARROW_KEYS[label], ink)
		return
	var font: Font = UiKit.FONT_BODY
	var fs := 19
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > rect.size.x - 16.0:
		fs = 15
		tw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(c.x - tw * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
