class_name CharacterTile
extends Button
## Quadradinho da grade de seleção de personagem: retrato animado ou "?" (bloqueado).

var data: CharacterData
var selected := false:
	set(value):
		selected = value
		_time = 0.0
		set_process(value)
		queue_redraw()

var portrait: CharacterPortrait
var _time := 0.0


func setup(d: CharacterData) -> void:
	data = d
	custom_minimum_size = Vector2(124, 124)
	focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	if is_unlocked():
		portrait = CharacterPortrait.new()
		add_child(portrait)
		portrait.setup(d, 220)
	set_process(false)


func is_unlocked() -> bool:
	return data != null and not data.locked and data.model_scene != null


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var radius := 20
	_box(r.grow(-1.0), Color(0, 0, 0, 0.32), radius, Vector2(0, 6))
	var base := data.color if is_unlocked() else Color(0.36, 0.42, 0.56)
	var dark := data.color_dark if is_unlocked() else Color(0.2, 0.24, 0.34)
	_box(r, dark, radius)
	_box(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.62)), base, radius, Vector2.ZERO, true)
	_box(Rect2(r.position + Vector2(6, 5), Vector2(r.size.x - 12, r.size.y * 0.3)), Color(1, 1, 1, 0.16), radius - 6)
	if portrait:
		draw_texture_rect(portrait.get_texture(), r.grow(-2.0), false)
	else:
		var font: Font = UiKit.FONT_TITLE
		var fs := int(size.y * 0.56)
		var tw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UiKit.draw_outlined(self, font, Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.36), "?", fs,
				Color(1, 1, 1, 0.85), Color(0.08, 0.1, 0.2, 0.6), 8)
	# Borda: branca, ou amarela piscando quando selecionado.
	if selected:
		var pulse := 0.5 + 0.5 * sin(_time * 7.0)
		_border(r.grow(4.0 + pulse * 3.0), UiKit.YELLOW.lerp(Color.WHITE, pulse * 0.4), 7, radius + 5)
		_border(r.grow(-1.0), Color.WHITE, 3, radius)
		_draw_tag()
	else:
		_border(r, Color(1, 1, 1, 0.9), 4, radius)


func _draw_tag() -> void:
	var font: Font = UiKit.FONT_ITALIC
	var tag := Rect2(Vector2(-10, -16), Vector2(54, 30))
	# No multijogador o selo mostra quem está escolhendo (J2...), na cor dele.
	var slot := GameState.players[GameState.picking_player] if GameState.is_multiplayer() else null
	UiKit.draw_ribbon(self, tag, 8.0, slot.color if slot else UiKit.RED)
	draw_string(font, Vector2(tag.position.x + 11, tag.position.y + 23), slot.tag if slot else "1P", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _box(r: Rect2, color: Color, radius: int, offset := Vector2.ZERO, top_only := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if top_only:
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
	sb.draw(get_canvas_item(), Rect2(r.position + offset, r.size))


func _border(r: Rect2, color: Color, width: int, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.draw(get_canvas_item(), r)
