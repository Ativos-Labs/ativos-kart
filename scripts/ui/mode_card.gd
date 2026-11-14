class_name ModeCard
extends Button
## Cartão grande de um modo de jogo (Grand Prix, Corrida, Contra-relógio): ícone,
## nome, uma linha de destaque e a descrição. Selecionado (foco do teclado/controle
## ou mouse em cima): borda amarela piscando e um pouco maior.

var title := ""
var subtitle := ""
var description := ""
var icon_name := ""
var color := UiKit.BLUE
var selected := false:
	set(value):
		if value == selected:
			return
		selected = value
		_time = 0.0
		set_process(value)
		_animate_scale(1.04 if value else 1.0)
		queue_redraw()

var _time := 0.0
var _tween: Tween


func setup(p_title: String, p_subtitle: String, p_description: String, p_icon: String, p_color: Color) -> void:
	title = p_title
	subtitle = p_subtitle
	description = p_description
	icon_name = p_icon
	color = p_color
	custom_minimum_size = Vector2(372, 246)
	focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	mouse_entered.connect(func(): grab_focus())
	resized.connect(func(): pivot_offset = size * 0.5)
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _animate_scale(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target, 0.18)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var radius := 22
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.3)
	shadow.set_corner_radius_all(radius)
	shadow.draw(get_canvas_item(), Rect2(rect.position + Vector2(0, 7), rect.size))
	if selected:
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		var glow := StyleBoxFlat.new()
		glow.bg_color = UiKit.YELLOW.lerp(Color.WHITE, pulse * 0.4)
		glow.set_corner_radius_all(radius + 6)
		glow.draw(get_canvas_item(), rect.grow(6.0 + pulse * 2.0))
	var border := StyleBoxFlat.new()
	border.bg_color = Color.WHITE
	border.set_corner_radius_all(radius)
	border.draw(get_canvas_item(), rect)
	var inner := rect.grow(-5.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(radius - 4)
	fill.draw(get_canvas_item(), inner)
	# Brilho na metade de cima e faixa escura embaixo (onde fica o texto).
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.16)
	gloss.corner_radius_top_left = radius - 4
	gloss.corner_radius_top_right = radius - 4
	gloss.draw(get_canvas_item(), Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.42)))
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.02, 0.04, 0.12, 0.28)
	band.corner_radius_bottom_left = radius - 4
	band.corner_radius_bottom_right = radius - 4
	band.draw(get_canvas_item(), Rect2(inner.position + Vector2(0, 108), Vector2(inner.size.x, inner.size.y - 108)))

	# Ícone num círculo branco.
	var ic := Vector2(64, 60)
	draw_circle(ic + Vector2(0, 4), 40, Color(0, 0, 0, 0.25))
	draw_circle(ic, 40, Color.WHITE)
	draw_circle(ic, 34, color.lightened(0.75))
	UiKit.draw_icon(self, icon_name, ic, 26.0, UiKit.INK)

	var tf: Font = UiKit.FONT_ITALIC
	UiKit.draw_outlined(self, tf, Vector2(118, 62), title, 36, Color.WHITE, UiKit.NAVY, 10)
	UiKit.draw_outlined(self, UiKit.FONT_BODY, Vector2(120, 90), subtitle, 16, UiKit.YELLOW, UiKit.NAVY, 6)
	draw_multiline_string(UiKit.FONT_BODY, Vector2(26, 138), description, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 52.0, 16, 5, Color(1, 1, 1, 0.96))
