class_name PickPanel
extends Control
## Cartão de um jogador nas telas de escolha do multijogador (piloto, kart e asa-delta,
## todos escolhendo ao mesmo tempo): a etiqueta dele (J2 + o controle), o palco 3D
## (PickStage), o nome do que está escolhendo (com setas, nas telas de kart e de asa),
## uma linha de detalhe e o que a tela puser em `extra` (atributos, cores da asa).
## Confirmado, o aro fica amarelo e aparece o selo "PRONTO!".
##
## Cartão largo (3 ou 4 jogadores): palco à esquerda e texto à direita. Alto (2
## jogadores): palco em cima e texto embaixo.

## Setas clicadas com o mouse (-1 / 1).
signal step_requested(dir: int)
## Clique no palco (o jogador do mouse confirma ou desfaz).
signal stage_clicked

const RADIUS := 22
const BORDER := 6.0
const PAD := 14.0
## Largura / altura a partir da qual o cartão fica deitado (palco ao lado do texto).
const WIDE := 1.45
## Fundo claro do cartão (o mesmo dos painéis do tema).
const CARD := Color(0.97, 0.98, 1.0)

var slot: PlayerSlot
var stage: PickStage
var title: Label
var detail: Label
## Espaço para o que cada tela acrescenta embaixo do nome.
var extra: VBoxContainer
## Fração da largura do cartão deitado que fica com o palco.
var stage_ratio := 0.5
## Confirmou a escolha ("PRONTO!").
var confirmed := false:
	set(value):
		if value == confirmed:
			return
		confirmed = value
		_stamp.play(value)
		queue_redraw()

var _view: TextureRect
var _info: VBoxContainer
var _view_rect := Rect2()
var _prev: ArrowButton
var _next: ArrowButton
var _tag: PlayerTag
var _stamp: _Stamp


## `podium_radius`: raio do pedestal (m); `arrows`: setas dos lados do nome.
func setup(p_slot: PlayerSlot, podium_radius: float, arrows: bool) -> void:
	slot = p_slot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = PickStage.new()
	stage.name = "Palco"
	add_child(stage)
	stage.setup(slot.color, podium_radius)

	_view = TextureRect.new()
	_view.texture = stage.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	add_child(_view)
	_stamp = _Stamp.new()
	add_child(_stamp)

	_info = VBoxContainer.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_constant_override("separation", 4)
	add_child(_info)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_info.add_child(row)
	title = Label.new()
	title.theme_type_variation = &"PanelLabel"
	title.add_theme_font_override("font", UiKit.FONT_ITALIC)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if arrows:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prev = _arrow(-1)
		_next = _arrow(1)
		row.add_child(_prev)
		row.add_child(title)
		row.add_child(_next)
	else:
		row.add_child(title)
	detail = Label.new()
	detail.theme_type_variation = &"PanelSoft"
	detail.add_theme_font_size_override("font_size", 16)
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if arrows:
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(detail)
	extra = VBoxContainer.new()
	extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extra.add_theme_constant_override("separation", 0)
	_info.add_child(extra)

	_tag = PlayerTag.new()
	_tag.setup_slot(slot, _shorten(slot.device_name(), 22))
	add_child(_tag)
	resized.connect(_layout)
	get_tree().root.size_changed.connect(_resize_stage)


## Cartão deitado (palco ao lado do texto).
func is_wide() -> bool:
	return size.x >= size.y * WIDE


## Seta da esquerda (-1) ou da direita (1) dá um "empurrãozinho" (troca pelo controle).
func flash_arrow(dir: int) -> void:
	var arrow := _prev if dir < 0 else _next
	if arrow:
		arrow.flash()


## Texto grande no meio do palco (o "?" de um piloto que ainda não chegou); "" = nada.
func set_placeholder(text: String) -> void:
	_stamp.placeholder = text
	_stamp.queue_redraw()


## Pulinho do cartão inteiro (troca de escolha).
func bump() -> void:
	_view.pivot_offset = _view.size * 0.5
	_view.scale = Vector2.ONE * 1.04
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_view, "scale", Vector2.ONE, 0.25)


func _arrow(dir: int) -> ArrowButton:
	var a := ArrowButton.new()
	a.direction = dir
	a.focus_mode = Control.FOCUS_NONE
	a.custom_minimum_size = Vector2(40, 40)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	a.pressed.connect(func(): step_requested.emit(dir))
	return a


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		stage_clicked.emit()


func _layout() -> void:
	if _info == null:
		return
	var inner := Rect2(Vector2.ONE * BORDER, size - Vector2.ONE * BORDER * 2.0)
	var wide := is_wide()
	title.add_theme_font_size_override("font_size", 26 if wide else 32)
	var info_h := _info.get_combined_minimum_size().y
	if wide:
		var w := roundf(inner.size.x * stage_ratio)
		_view_rect = Rect2(inner.position, Vector2(w, inner.size.y))
		var x := _view_rect.end.x + PAD
		_info.position = Vector2(x, inner.position.y + maxf((inner.size.y - info_h) * 0.5, PAD))
		_info.size = Vector2(inner.end.x - PAD - x, info_h)
	else:
		_view_rect = Rect2(inner.position, Vector2(inner.size.x, inner.size.y - info_h - PAD * 2.0))
		_info.position = Vector2(inner.position.x + PAD, _view_rect.end.y + PAD)
		_info.size = Vector2(inner.size.x - PAD * 2.0, info_h)
	_view.position = _view_rect.position
	_view.size = _view_rect.size
	_stamp.position = _view_rect.position
	_stamp.size = _view_rect.size
	_tag.size = _tag.get_combined_minimum_size()
	_tag.position = Vector2(-10.0, -14.0)
	_resize_stage()
	queue_redraw()


## O palco renderiza no tamanho real em pixels da janelinha (nítido em qualquer tela),
## com o teto de resolução do 3D (RenderScale) valendo para ele também.
func _resize_stage() -> void:
	if stage == null or _view_rect.size.x < 1.0:
		return
	var full := get_viewport().get_visible_rect().size
	var window := get_window()
	var px := Vector2(window.size) / full if window and full.x > 0.0 else Vector2.ONE
	var s := GameState.render_scale.current_scale() if GameState.render_scale else 1.0
	stage.size = Vector2i(maxi(int(round(_view_rect.size.x * px.x * s)), 16),
			maxi(int(round(_view_rect.size.y * px.y * s)), 16))


func _draw() -> void:
	if slot == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	var edge := UiKit.YELLOW if confirmed else slot.color
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.3)
	shadow.set_corner_radius_all(RADIUS)
	shadow.draw(get_canvas_item(), Rect2(r.position + Vector2(0, 7), r.size))
	var card := StyleBoxFlat.new()
	card.bg_color = CARD
	card.border_color = edge
	card.set_border_width_all(int(BORDER))
	card.set_corner_radius_all(RADIUS)
	card.draw(get_canvas_item(), r)

	# Janela do palco na cor do jogador, com uma luz de holofote atrás do pedestal.
	var inner_radius := RADIUS - int(BORDER)
	var window := StyleBoxFlat.new()
	window.bg_color = slot.color.lightened(0.12)
	window.set_corner_radius_all(inner_radius)
	if is_wide():
		window.corner_radius_top_right = 6
		window.corner_radius_bottom_right = 6
	else:
		window.corner_radius_bottom_left = 6
		window.corner_radius_bottom_right = 6
	window.draw(get_canvas_item(), _view_rect)
	var spot := Vector2(_view_rect.get_center().x, _view_rect.position.y + _view_rect.size.y * 0.72)
	var spot_r := minf(_view_rect.size.x * 0.48, _view_rect.size.y * 0.9)
	draw_set_transform(spot, 0.0, Vector2(1.0, 0.38))
	for k in 4:
		draw_circle(Vector2.ZERO, spot_r * (1.0 - k * 0.2), Color(1, 1, 1, 0.07))
	draw_set_transform(Vector2.ZERO)
	if is_wide():
		draw_line(Vector2(_view_rect.end.x, _view_rect.position.y), _view_rect.end, edge, 3.0)
	else:
		draw_line(Vector2(_view_rect.position.x, _view_rect.end.y), _view_rect.end, edge, 3.0)


static func _shorten(text: String, max_chars: int) -> String:
	return text if text.length() <= max_chars else text.substr(0, max_chars - 1).strip_edges() + "…"


## Selo "PRONTO!" (e o "?" de quem ainda não chegou) sobre o palco.
class _Stamp extends Control:
	var placeholder := ""
	var _tween: Tween
	var _amount := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func play(on: bool) -> void:
		if _tween:
			_tween.kill()
		_tween = create_tween()
		if on:
			_amount = 0.0
			_tween.tween_method(_set_amount, 0.0, 1.0, 0.35)
		else:
			_tween.tween_method(_set_amount, _amount, 0.0, 0.15)

	func _set_amount(v: float) -> void:
		_amount = v
		queue_redraw()

	func _draw() -> void:
		if placeholder != "":
			var big: Font = UiKit.FONT_TITLE
			var bs := int(size.y * 0.5)
			var bw := big.get_string_size(placeholder, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
			UiKit.draw_outlined(self, big, Vector2((size.x - bw) * 0.5, size.y * 0.42 + bs * 0.36), placeholder, bs,
					Color(1, 1, 1, 0.85), Color(0.05, 0.07, 0.16, 0.6), maxi(8, bs / 9))
		if _amount <= 0.001:
			return
		var font: Font = UiKit.FONT_ITALIC
		var fs := clampi(int(minf(size.x * 0.17, size.y * 0.24)), 26, 64)
		var text := "PRONTO!"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# Entra grande e assenta (com um quique), inclinado como um carimbo.
		var t := _amount
		var grow := 1.0 + (1.0 - _ease_out_back(t)) * 0.8
		var c := Vector2(size.x * 0.5, size.y * 0.8)
		draw_set_transform(c, -0.1, Vector2.ONE * grow)
		var band := Rect2(Vector2(-w * 0.5 - 22.0, -fs * 0.62), Vector2(w + 44.0, fs * 1.18))
		var color := Color(UiKit.NAVY, 0.82 * minf(t * 2.0, 1.0))
		UiKit.draw_ribbon(self, band, fs * 0.3, color, Color(UiKit.YELLOW, minf(t * 2.0, 1.0)))
		var baseline := (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - fs * 0.04
		UiKit.draw_outlined(self, font, Vector2(-w * 0.5, baseline), text, fs,
				Color(UiKit.YELLOW, minf(t * 2.0, 1.0)), Color(UiKit.NAVY, minf(t * 2.0, 1.0)), maxi(6, fs / 6))
		draw_set_transform(Vector2.ZERO)

	static func _ease_out_back(t: float) -> float:
		var c1 := 1.70158
		var c3 := c1 + 1.0
		return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
