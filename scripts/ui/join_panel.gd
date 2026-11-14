class_name JoinPanel
extends Control
## Painel "Quem vai jogar?" do multijogador: cada jogador aperta A (ou Start) no
## controle dele — ou Enter/Espaço no teclado — e fica com a próxima vaga (J1, J2...).
## B/Esc no controle de quem já entrou tira ele; Esc antes de alguém entrar fecha o
## painel. Quando todas as vagas enchem, o painel avisa e emite `completed`.

signal completed(devices: Array[int])
signal cancelled

const SLOT_SIZE := Vector2(250, 178)

var needed := 2
## Controle de cada vaga, na ordem (J1, J2...).
var devices: Array[int] = []

var _panel: PanelContainer
var _slots_row: HBoxContainer
var _cards: Array[Control] = []
var _status: Label
var _done_timer: SceneTreeTimer
var _pulse: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.12, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_panel.add_child(box)
	var title := RibbonLabel.new()
	title.text = "QUEM VAI JOGAR?"
	title.font_size = 36
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(title)
	var help := Label.new()
	help.theme_type_variation = &"PanelSoft"
	help.text = "Cada jogador aperta  A  no controle dele (ou  Enter  no teclado) para entrar.\nB / Esc sai.  Os controles conectados aparecem aqui."
	help.add_theme_font_size_override("font_size", 17)
	box.add_child(help)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 16)
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_slots_row)
	_status = Label.new()
	_status.theme_type_variation = &"PanelLabel"
	_status.add_theme_font_override("font", UiKit.FONT_ITALIC)
	_status.add_theme_font_size_override("font_size", 26)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	hide()


func open(count: int) -> void:
	needed = clampi(count, 2, GameState.MAX_PLAYERS)
	devices.clear()
	_done_timer = null
	for c in _cards:
		c.queue_free()
	_cards.clear()
	for i in needed:
		var card := _SlotCard.new()
		card.custom_minimum_size = SLOT_SIZE
		card.index = i
		_slots_row.add_child(card)
		_cards.append(card)
	show()
	_refresh()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.85
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.28)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	if _pulse:
		_pulse.kill()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_status, "modulate:a", 0.45, 0.55).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_status, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)


func close() -> void:
	hide()
	if _pulse:
		_pulse.kill()
		_pulse = null


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var device := -99
	var join := false
	var leave := false
	if event is InputEventJoypadButton and event.pressed:
		device = event.device
		join = event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]
		leave = event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]
	elif event is InputEventKey and event.pressed and not event.echo:
		device = PlayerSlot.DEVICE_KEYBOARD
		join = event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		leave = event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]
	elif event is InputEventJoypadMotion or event is InputEventKey:
		get_viewport().set_input_as_handled()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	if join:
		_join(device)
	elif leave:
		_leave(device)


func _join(device: int) -> void:
	if devices.has(device) or devices.size() >= needed:
		return
	devices.append(device)
	Sfx.play(self, &"ui_accept", -8.0)
	var card := _cards[devices.size() - 1]
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 1.12
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(card, "scale", Vector2.ONE, 0.25)
	_refresh()
	if devices.size() == needed:
		var timer := get_tree().create_timer(0.9)
		_done_timer = timer
		await timer.timeout
		if _done_timer == timer and visible and devices.size() == needed:
			close()
			completed.emit(devices.duplicate())


func _leave(device: int) -> void:
	if devices.has(device):
		devices.erase(device)
		_done_timer = null
		Sfx.play(self, &"ui_back", -10.0)
		_refresh()
	elif devices.is_empty():
		Sfx.play(self, &"ui_back", -10.0)
		close()
		cancelled.emit()


func _refresh() -> void:
	for i in _cards.size():
		var card := _cards[i] as _SlotCard
		card.device = devices[i] if i < devices.size() else -99
		card.queue_redraw()
	if devices.size() == needed:
		_status.text = "Todos prontos!"
	else:
		_status.text = "Esperando o J%d…" % (devices.size() + 1)


## Uma vaga do painel: vazia ("Aperte A") ou com o jogador e o controle dele.
class _SlotCard extends Control:
	var index := 0
	var device := -99

	func _draw() -> void:
		var joined := device != -99
		var color: Color = PlayerSlot.COLORS[index]
		var rect := Rect2(Vector2.ZERO, size)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(20)
		box.shadow_color = Color(0, 0, 0, 0.25)
		box.shadow_size = 5
		box.shadow_offset = Vector2(0, 4)
		box.bg_color = color if joined else Color(0.86, 0.89, 0.94)
		box.border_color = Color.WHITE
		box.set_border_width_all(5)
		box.draw(get_canvas_item(), rect)
		var c := Vector2(size.x * 0.5, 66.0)
		draw_circle(c, 42.0, Color(1, 1, 1, 0.92) if joined else Color(1, 1, 1, 0.6))
		var tag := "J%d" % (index + 1)
		var font: Font = UiKit.FONT_ITALIC
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var ink := color.darkened(0.25) if joined else Color(0.55, 0.6, 0.7)
		draw_string(font, Vector2(c.x - tw * 0.5, c.y + 14.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, ink)
		var line := PlayerSlot.device_label(device) if joined else "Aperte A ou Enter"
		var body: Font = UiKit.FONT_BODY
		var fs := 18
		while fs > 12 and body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 24.0:
			fs -= 1
		var lw := body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var text_color := Color.WHITE if joined else UiKit.INK_SOFT
		if joined:
			UiKit.draw_outlined(self, body, Vector2((size.x - lw) * 0.5, 140.0), line, fs, text_color, Color(0, 0, 0, 0.35), 4)
		else:
			draw_string(body, Vector2((size.x - lw) * 0.5, 140.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		if joined:
			var ok := "PRONTO"
			var ow := font.get_string_size(ok, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			UiKit.draw_outlined(self, font, Vector2((size.x - ow) * 0.5, 166.0), ok, 20, UiKit.YELLOW, UiKit.NAVY, 6)
