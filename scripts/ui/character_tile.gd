class_name CharacterTile
extends Button
## Quadradinho da grade de seleção de personagem: retrato animado ou "?" (bloqueado).
## No multijogador mostra o cursor de cada jogador que está nele (aro e etiqueta J1,
## J2... na cor dele; a etiqueta fica num canto diferente para cada jogador).

var data: CharacterData
var selected := false:
	set(value):
		selected = value
		_time = 0.0
		_update_process()
		queue_redraw()
## Escolha confirmada (sozinho): fica com o aro firme e o selo de visto até seguir ou
## desfazer (UiKit.draw_picked).
var picked := false:
	set(value):
		picked = value
		_time = 0.0
		_update_process()
		queue_redraw()
## Multijogador: jogadores (0 = J1...) com o cursor aqui e quais deles já confirmaram.
var cursors: Array[int] = []
var cursors_ready: Array[bool] = []

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


func set_cursors(players: Array[int], ready: Array[bool]) -> void:
	if players == cursors and ready == cursors_ready:
		return
	cursors = players
	cursors_ready = ready
	_update_process()
	queue_redraw()


func _update_process() -> void:
	set_process(selected or picked or not cursors.is_empty())


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
	# Borda: branca, ou amarela piscando quando selecionado. No multijogador, um aro
	# por jogador (piscando até ele confirmar).
	if not cursors.is_empty():
		for k in cursors.size():
			var color: Color = PlayerSlot.COLORS[cursors[k]]
			var pulse := 0.0 if cursors_ready[k] else 0.5 + 0.5 * sin(_time * 7.0)
			var grow := 4.0 + k * 7.0 + pulse * 2.0
			_border(r.grow(grow), color.lerp(Color.WHITE, pulse * 0.35), 6, radius + int(grow))
		_border(r.grow(-1.0), Color.WHITE, 3, radius)
		for k in cursors.size():
			_draw_player_tag(cursors[k], cursors_ready[k])
	elif picked:
		UiKit.draw_picked(self, r, radius, _time)
		_draw_tag()
	elif selected:
		var pulse := 0.5 + 0.5 * sin(_time * 7.0)
		_border(r.grow(4.0 + pulse * 3.0), UiKit.YELLOW.lerp(Color.WHITE, pulse * 0.4), 7, radius + 5)
		_border(r.grow(-1.0), Color.WHITE, 3, radius)
		_draw_tag()
	else:
		_border(r, Color(1, 1, 1, 0.9), 4, radius)


func _draw_tag() -> void:
	var font: Font = UiKit.FONT_ITALIC
	var tag := Rect2(Vector2(-10, -16), Vector2(54, 30))
	UiKit.draw_ribbon(self, tag, 8.0, UiKit.RED)
	draw_string(font, Vector2(tag.position.x + 11, tag.position.y + 23), "1P", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


## Etiqueta do jogador `p` no canto dele (J1 em cima à esquerda, J2 em cima à direita,
## J3 embaixo à esquerda, J4 embaixo à direita); amarela quando ele confirmou.
func _draw_player_tag(p: int, ready: bool) -> void:
	var font: Font = UiKit.FONT_ITALIC
	var w := 52.0
	var h := 28.0
	var x := -8.0 if p % 2 == 0 else size.x - w + 8.0
	var y := -9.0 if p < 2 else size.y - h + 9.0
	var tag := Rect2(x, y, w, h)
	UiKit.draw_ribbon(self, tag, 8.0, PlayerSlot.COLORS[p], UiKit.YELLOW if ready else Color(1, 1, 1, 0.9))
	var text := "J%d" % (p + 1)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	UiKit.draw_outlined(self, font, Vector2(tag.get_center().x - tw * 0.5, tag.position.y + 21.0), text, 21,
			UiKit.YELLOW if ready else Color.WHITE, Color(0.02, 0.04, 0.12, 0.6), 4)


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
