class_name TrackCard
extends Button
## Cartão de pista na tela de seleção: foto da pista (ou "?" se bloqueada) e o nome
## numa faixa. Selecionado: borda amarela piscando e etiqueta "1P". Pista liberada
## que ainda não tem foto mostra o logo "at" nas cores da pista.

const LOGO := preload("res://assets/logos/ativos_icone.png")

var data: TrackData
var thumbnail: Texture2D:
	set(value):
		thumbnail = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		_time = 0.0
		set_process(value)
		queue_redraw()

var _time := 0.0


func setup(d: TrackData) -> void:
	data = d
	custom_minimum_size = Vector2(236, 160)
	# A foto (448×300) aparece reduzida: com mipmaps ela não serrilha.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	focus_mode = Control.FOCUS_NONE
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
	var r := Rect2(Vector2.ZERO, size)
	var radius := 18
	var unlocked := data.is_unlocked()
	var base := data.color if unlocked else Color(0.3, 0.35, 0.48)
	var dark := data.color_dark if unlocked else Color(0.14, 0.17, 0.26)
	_box(r, Color(0, 0, 0, 0.35), radius, Vector2(0, 7))
	_box(r, dark, radius)

	# Foto (ou "?" num fundo listrado).
	var photo := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	if unlocked and thumbnail:
		draw_texture_rect(thumbnail, photo, false)
	else:
		UiKit.draw_gradient_poly(self, PackedVector2Array([photo.position, Vector2(photo.end.x, photo.position.y), photo.end, Vector2(photo.position.x, photo.end.y)]),
				base, dark, photo.position.y, photo.end.y)
		for i in 9:
			var x := photo.position.x + i * 34.0 - 40.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, photo.position.y), Vector2(x + 16, photo.position.y),
					Vector2(x + 16 + 60, photo.end.y), Vector2(x + 60, photo.end.y)]), Color(1, 1, 1, 0.05))
	if unlocked and not thumbnail:
		# Pista liberada que ainda não ganhou foto: o logo "at" nas cores da pista.
		var lw := photo.size.x * 0.36
		var lh := lw / (float(LOGO.get_width()) / LOGO.get_height())
		var logo_rect := Rect2(photo.get_center() - Vector2(lw * 0.5, lh * 0.5 + 16.0), Vector2(lw, lh))
		_box(logo_rect.grow(10.0), Color(1, 1, 1, 0.94), 16)
		draw_texture_rect(LOGO, logo_rect, false)
	elif not unlocked:
		var font: Font = UiKit.FONT_TITLE
		var fs := int(size.y * 0.44)
		var tw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UiKit.draw_outlined(self, font, Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.2), "?", fs,
				Color(1, 1, 1, 0.85), Color(0.05, 0.07, 0.16, 0.6), 8)

	# Faixa com o nome.
	var strip := Rect2(Vector2(-6, size.y - 46), Vector2(size.x * 0.86, 36))
	UiKit.draw_ribbon(self, strip, 12.0, base if unlocked else Color(0.25, 0.29, 0.4))
	var name_font: Font = UiKit.FONT_ITALIC
	var label := data.display_name if unlocked else "Em breve"
	var nfs := 21
	while nfs > 12 and name_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > strip.size.x - 40.0:
		nfs -= 1
	UiKit.draw_outlined(self, name_font, Vector2(strip.position.x + 22, strip.position.y + 26), label, nfs,
			Color.WHITE, Color(0.02, 0.04, 0.12, 0.8), 5)

	# Borda.
	var hot := is_hovered()
	if selected:
		var pulse := 0.5 + 0.5 * sin(_time * 7.0)
		_border(r.grow(4.0 + pulse * 3.0), UiKit.YELLOW.lerp(Color.WHITE, pulse * 0.4), 7, radius + 5)
		_border(r, Color.WHITE, 6, radius)
		var tag := Rect2(Vector2(-10, -16), Vector2(54, 30))
		UiKit.draw_ribbon(self, tag, 8.0, UiKit.RED)
		draw_string(UiKit.FONT_ITALIC, Vector2(tag.position.x + 11, tag.position.y + 23), "1P", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	else:
		_border(r, Color(1, 1, 1, 1.0 if hot else 0.85), 6, radius)
	if not unlocked:
		_draw_lock(Vector2(size.x - 30, 30))


func _draw_lock(c: Vector2) -> void:
	draw_circle(c, 17, Color(0.05, 0.07, 0.16, 0.75))
	draw_arc(c + Vector2(0, -3), 6.5, PI, TAU, 12, Color.WHITE, 3.0, true)
	draw_rect(Rect2(c + Vector2(-8, -3), Vector2(16, 12)), Color.WHITE)


func _box(r: Rect2, color: Color, radius: int, offset := Vector2.ZERO) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.draw(get_canvas_item(), Rect2(r.position + offset, r.size))


func _border(r: Rect2, color: Color, width: int, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.draw(get_canvas_item(), r)
