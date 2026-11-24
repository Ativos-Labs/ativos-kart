class_name CupBadge
extends Button
## Emblema redondo de uma copa, com o logo "at" no anel da cor da copa (a Copa Ativos no
## azul da marca); copas bloqueadas mostram "?".

const LOGO := preload("res://assets/logos/ativos_icone.png")

var cup_name := ""
var unlocked := true
## Cor do anel.
var tint := Color("263dbf")
var selected := false:
	set(value):
		selected = value
		_time = 0.0
		set_process(value)
		queue_redraw()

var _time := 0.0


func setup(p_name: String, p_unlocked: bool, p_tint := Color("263dbf")) -> void:
	cup_name = p_name
	unlocked = p_unlocked
	tint = p_tint
	custom_minimum_size = Vector2(92, 92)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = p_name if p_unlocked else "Em breve"
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 6.0
	if selected:
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		draw_circle(c, r + 6.0 + pulse * 3.0, UiKit.YELLOW.lerp(Color.WHITE, pulse * 0.35))
	draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color.WHITE)
	if unlocked:
		draw_circle(c, r - 5.0, tint)
		draw_circle(c - Vector2(0, r * 0.3), r * 0.7, Color(1, 1, 1, 0.12))
		draw_circle(c, r - 12.0, Color.WHITE)
		var w := (r - 14.0) * 1.62
		var h := w / (float(LOGO.get_width()) / LOGO.get_height())
		draw_texture_rect(LOGO, Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h)), false)
	else:
		draw_circle(c, r - 5.0, Color(0.32, 0.37, 0.5) if is_hovered() else Color(0.27, 0.31, 0.43))
		var font: Font = UiKit.FONT_TITLE
		var fs := int(r * 1.05)
		var tw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UiKit.draw_outlined(self, font, Vector2(c.x - tw * 0.5, c.y + fs * 0.36), "?", fs,
				Color(1, 1, 1, 0.8), Color(0.05, 0.07, 0.16, 0.5), 6)
