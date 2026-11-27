class_name FancyButton
extends Button
## Botão de menu brilhante em formato de flecha dupla (hexágono alongado).
## Selecionado (teclado, controle ou mouse): fica amarelo, cresce um pouco e mostra
## setas piscando nas pontas. O desenho é todo feito em _draw().

@export var play_sounds := true
## Ícone à esquerda: play, flag, gamepad, exit, retry, home, back, next, person, kart, pause, trophy.
@export var icon_kind := ""
## Texto alinhado à esquerda (menus em coluna) em vez de centralizado.
@export var align_left := false
## Botão de destaque (ex.: "Correr!"): fica amarelo mesmo sem estar selecionado.
@export var primary := false

## Escolha confirmada (o botão que confirmou): fica amarelo, maior e com as setas
## paradas nas pontas até a tela seguir ou a escolha ser desfeita.
var picked := false:
	set(value):
		if picked == value:
			return
		picked = value
		_animate_scale(1.08 if value else (1.05 if _selected else 1.0))
		queue_redraw()

var _tween: Tween
var _time := 0.0
var _selected := false


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)
	resized.connect(_update_pivot)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	if custom_minimum_size.y < 1.0:
		custom_minimum_size.y = 62.0
	# O Button continua cuidando de foco, clique e tamanho mínimo; o visual padrão some.
	var h := custom_minimum_size.y
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = h * 0.32 + (h * 0.95 if icon_kind != "" else 0.0) + 20.0
	empty.content_margin_right = h * 0.32 + 26.0
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(color, Color(0, 0, 0, 0))
	set_process(false)
	_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_mouse_entered() -> void:
	if not disabled and focus_mode != FOCUS_NONE:
		grab_focus()


func _on_focus_entered() -> void:
	_selected = true
	_time = 0.0
	set_process(true)
	_animate_scale(1.05)
	if play_sounds and is_visible_in_tree():
		Sfx.play(self, &"ui_move", -14.0)


func _on_focus_exited() -> void:
	_selected = false
	set_process(false)
	_animate_scale(1.08 if picked else 1.0)
	queue_redraw()


func _on_pressed() -> void:
	if play_sounds:
		Sfx.play(get_tree().root, &"ui_accept", -10.0)
	# Pulinho ao confirmar.
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale = Vector2.ONE * 0.94
	_tween.tween_property(self, "scale", Vector2.ONE * (1.08 if picked else (1.05 if _selected else 1.0)), 0.2)


func _animate_scale(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target, 0.16)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var notch := h * 0.32
	var rect := Rect2(Vector2.ZERO, size)
	var hot := (_selected or primary or picked) and not disabled
	var down := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED

	var outer := UiKit.hex_points(rect, notch)
	var inner := UiKit.hex_points(rect.grow(-3.5), notch - 1.2)
	draw_colored_polygon(UiKit.offset_points(outer, Vector2(0, 5)), Color(0, 0, 0, 0.3))
	draw_colored_polygon(outer, Color.WHITE if hot else Color(0.72, 0.76, 0.84))

	var top := UiKit.WHITE_TOP
	var bottom := UiKit.WHITE_BOTTOM
	if disabled:
		top = Color(0.86, 0.87, 0.9)
		bottom = Color(0.68, 0.7, 0.75)
	elif down or picked:
		top = UiKit.YELLOW_DARK
		bottom = UiKit.ORANGE
	elif hot:
		var pulse := 0.5 + 0.5 * sin(_time * 6.0) if _selected else 0.0
		top = UiKit.YELLOW_LIGHT.lerp(Color.WHITE, pulse * 0.25)
		bottom = UiKit.YELLOW_DARK
	UiKit.draw_gradient_poly(self, inner, top, bottom, 3.5, h - 3.5)

	# Brilho na metade de cima.
	var in_notch := notch - 1.2
	var gy := 3.5 + (h - 7.0) * 0.44
	var gloss := PackedVector2Array([
		Vector2(3.5 + in_notch, 3.5), Vector2(w - 3.5 - in_notch, 3.5),
		Vector2(w - 3.5 - in_notch * 0.12, gy), Vector2(3.5 + in_notch * 0.12, gy),
	])
	UiKit.draw_gradient_poly(self, gloss, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.08), 3.5, gy)

	# Ícone num círculo à esquerda.
	var content_left := notch + 20.0
	if icon_kind != "":
		var ic := Vector2(notch * 0.6 + h * 0.42, h * 0.5)
		var ir := h * 0.34
		draw_circle(ic, ir + 2.0, Color(1, 1, 1, 0.9))
		draw_circle(ic, ir, Color(1, 1, 1, 0.45) if hot else Color(0.8, 0.85, 0.93))
		UiKit.draw_icon(self, icon_kind, ic, ir * 0.72, UiKit.INK if not disabled else UiKit.INK_SOFT)
		content_left = ic.x + ir + 16.0

	# Texto.
	var font := get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := content_left if align_left else maxf(content_left, (w - tw) * 0.5 + (content_left - notch - 20.0) * 0.5)
	var baseline := h * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var ink := UiKit.INK if not disabled else Color(UiKit.INK, 0.45)
	draw_string(font, Vector2(x, baseline + 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

	# Setas piscando nas pontas quando selecionado.
	if (_selected or picked) and not disabled:
		var bob := 6.0 if picked else (0.5 + 0.5 * sin(_time * 7.0)) * 6.0
		_draw_chevron(-12.0 - bob, h, notch, -1.0)
		_draw_chevron(w + 12.0 + bob, h, notch, 1.0)


func _draw_chevron(tip_x: float, h: float, notch: float, dir: float) -> void:
	var t := 9.0
	var k := notch + 2.0
	var pts := PackedVector2Array([
		Vector2(tip_x, h * 0.5),
		Vector2(tip_x - dir * k, -3.0),
		Vector2(tip_x - dir * (k + t), -3.0),
		Vector2(tip_x - dir * t, h * 0.5),
		Vector2(tip_x - dir * (k + t), h + 3.0),
		Vector2(tip_x - dir * k, h + 3.0),
	])
	draw_colored_polygon(UiKit.offset_points(pts, Vector2(0, 3)), Color(0, 0, 0, 0.25))
	draw_colored_polygon(pts, UiKit.YELLOW)
	draw_polyline(UiKit.closed(pts), UiKit.YELLOW_DARK, 2.0, true)
