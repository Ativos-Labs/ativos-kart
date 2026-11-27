class_name CupCard
extends Button
## Cartão de uma copa na tela de copas (cup_select.gd): o emblema da copa (CupBadge) no
## alto, o nome e as fotos das pistas dela numa grade 2×2 (vaga sem pista: "?"). Copa
## bloqueada: tudo cinza com "?". Selecionado: borda amarela piscando e
## etiqueta "1P"; confirmado: aro firme e selo de visto (UiKit.draw_picked).

const COLUMNS := 2
const GAP := 8.0
const PAD := 14.0
## Altura da faixa do alto (emblema e nome).
const HEAD := 96.0
const RADIUS := 20

var cup_name := ""
var unlocked := true
## Cor da copa (a da primeira pista dela) e a escura.
var tint := Color("263dbf")
var tint_dark := Color(0.06, 0.09, 0.22)
## Pistas da copa, já completadas com vagas bloqueadas ("?").
var tracks: Array[TrackData] = []
var selected := false:
	set(value):
		selected = value
		_time = 0.0
		if _badge:
			_badge.selected = value
		set_process(value or picked)
		queue_redraw()
var picked := false:
	set(value):
		picked = value
		_time = 0.0
		set_process(value or selected)
		queue_redraw()

var _thumbs: Array[Texture2D] = []
var _badge: CupBadge
var _time := 0.0


func setup(p_name: String, p_unlocked: bool, p_tracks: Array[TrackData]) -> void:
	cup_name = p_name
	unlocked = p_unlocked
	tracks = p_tracks
	custom_minimum_size = Vector2(276, 296)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	if unlocked and not tracks.is_empty():
		tint = tracks[0].color
		tint_dark = tracks[0].color_dark
	# Fotos prontas da largada (448×300, poucos ms cada).
	for t in tracks:
		_thumbs.append(load(t.thumbnail) if t.is_unlocked() and t.thumbnail != "" else null)
	_badge = CupBadge.new()
	_badge.setup(cup_name if unlocked else "???", unlocked, tint)
	_badge.custom_minimum_size = Vector2(70, 70)
	_badge.size = _badge.custom_minimum_size
	_badge.position = Vector2(PAD - 2.0, PAD - 2.0)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.tooltip_text = ""
	add_child(_badge)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var base := tint if unlocked else Color(0.36, 0.42, 0.56)
	var dark := tint_dark if unlocked else Color(0.16, 0.19, 0.28)
	_box(Rect2(r.position + Vector2(0, 7), r.size), Color(0, 0, 0, 0.35), RADIUS)
	_box(r, dark, RADIUS)
	_box(Rect2(r.position, Vector2(r.size.x, HEAD)), base, RADIUS, true)
	_box(Rect2(Vector2(6, 5), Vector2(r.size.x - 12, HEAD * 0.42)), Color(1, 1, 1, 0.14), RADIUS - 6)

	# Nome da copa ao lado do emblema (quebra em duas linhas se não couber).
	var font: Font = UiKit.FONT_TITLE
	var name_x := PAD + 78.0
	var name_w := size.x - name_x - PAD
	var label := cup_name if unlocked else "???"
	var lines := _wrap(label, font, 30, name_w)
	var fs := 30 if lines.size() == 1 else 25
	var line_h := fs * 1.0
	var y := HEAD * 0.5 - line_h * lines.size() * 0.5 + fs * 0.82
	for line: String in lines:
		UiKit.draw_outlined(self, font, Vector2(name_x, y), line, fs, Color.WHITE, Color(0.02, 0.04, 0.12, 0.7), 6)
		y += line_h

	# Fotos das pistas, 2×2.
	var grid_w := size.x - PAD * 2.0
	var cell_w := (grid_w - GAP) / COLUMNS
	var cell_h := cell_w / 1.49
	var top := HEAD + PAD
	for k in tracks.size():
		var cell := Rect2(PAD + (k % COLUMNS) * (cell_w + GAP), top + (k / COLUMNS) * (cell_h + GAP), cell_w, cell_h)
		_box(cell.grow(2.0), Color(1, 1, 1, 0.9), 10)
		var tex: Texture2D = _thumbs[k] if k < _thumbs.size() else null
		if tex:
			draw_texture_rect(tex, cell, false)
		else:
			_box(cell, Color(0.22, 0.26, 0.38), 8)
			var qs := int(cell_h * 0.6)
			var qw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, qs).x
			UiKit.draw_outlined(self, font, Vector2(cell.get_center().x - qw * 0.5, cell.get_center().y + qs * 0.36), "?", qs,
					Color(1, 1, 1, 0.7), Color(0.05, 0.07, 0.16, 0.5), 5)

	# Borda.
	if picked:
		# O selo de visto fica no canto da etiqueta "1P": ela sai.
		UiKit.draw_picked(self, r, RADIUS, _time)
	elif selected:
		var pulse := 0.5 + 0.5 * sin(_time * 7.0)
		_border(r.grow(4.0 + pulse * 3.0), UiKit.YELLOW.lerp(Color.WHITE, pulse * 0.4), 7, RADIUS + 5)
		_border(r, Color.WHITE, 6, RADIUS)
		_draw_tag()
	else:
		_border(r, Color(1, 1, 1, 1.0 if is_hovered() else 0.8), 6, RADIUS)


func _draw_tag() -> void:
	var tag := Rect2(Vector2(size.x - 44, -16), Vector2(54, 30))
	UiKit.draw_ribbon(self, tag, 8.0, UiKit.RED)
	draw_string(UiKit.FONT_ITALIC, Vector2(tag.position.x + 11, tag.position.y + 23), "1P", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


## Quebra `text` em até duas linhas de largura `width`.
static func _wrap(text: String, font: Font, fs: int, width: float) -> PackedStringArray:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return PackedStringArray([text])
	var words := text.split(" ")
	var best := PackedStringArray([text])
	for k in range(1, words.size()):
		var a := " ".join(words.slice(0, k))
		var b := " ".join(words.slice(k))
		best = PackedStringArray([a, b])
		if font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 5).x <= width:
			break
	return best


func _box(r: Rect2, color: Color, radius: int, top_only := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if top_only:
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
	sb.draw(get_canvas_item(), r)


func _border(r: Rect2, color: Color, width: int, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.draw(get_canvas_item(), r)
