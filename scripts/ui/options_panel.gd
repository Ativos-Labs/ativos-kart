class_name OptionsPanel
extends Control
## Janela "Opções" (menu principal e pausa), em três abas:
## - Som: volume geral, da música e dos efeitos (canais de default_bus_layout.tres);
## - Tela: tela cheia e resolução da janela (no navegador só a tela cheia);
## - Teclas: duas teclas para cada ação do kart. Escolha a vaga e aperte a tecla nova
##   (Esc cancela); se outra ação usava essa tecla, as duas trocam.
## Tudo é salvo na hora (GameSettings, user://opcoes.cfg).

signal closed

const TABS := [["Som", "speaker"], ["Tela", "screen"], ["Teclas", "keyboard"]]
const PAGE_HINTS := [
	"Efeitos inclui o motor dos karts e os sons dos menus.",
	"A resolução vale para a janela; a tela cheia usa a do monitor.",
	"Escolha uma tecla e aperte a nova. Os botões do controle não mudam.",
]
const WEB_SCREEN_HINT := "No navegador o jogo ocupa a página; Esc sai da tela cheia."

var _panel: PanelContainer
var _tabs: Array[TabPill] = []
var _pages: Array[Control] = []
## Controles de cada página, de cima para baixo (para o foco andar só dentro da janela).
var _page_items: Array = [[], [], []]
var _page := 0
var _volumes := {}
var _fullscreen: OptionSelector
var _resolution: OptionSelector
var _resolutions: Array[Vector2i] = []
## Ação → [KeyButton, KeyButton].
var _key_buttons := {}
var _reset_button: FancyButton
var _back_button: FancyButton
var _hint: Label
var _listening: KeyButton
var _listen_action := &""
var _listen_slot := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	GameState.settings.keys_changed.connect(_refresh_keys)
	hide()


func open() -> void:
	_refresh_all()
	show()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.85
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.28)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	_select_page(0)
	_tabs[0].grab_focus()


func close() -> void:
	_stop_listening()
	hide()
	closed.emit()


# --- Montagem ------------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.12, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var title := RibbonLabel.new()
	title.text = "OPÇÕES"
	title.font_size = 36
	title.custom_minimum_size = Vector2(0, 52)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	for i in TABS.size():
		var tab := TabPill.new()
		tab.text = TABS[i][0]
		tab.icon_kind = TABS[i][1]
		tab.custom_minimum_size = Vector2(150, 48)
		tab.focus_entered.connect(_select_page.bind(i))
		tab.pressed.connect(_on_tab_pressed.bind(i))
		top.add_child(tab)
		_tabs.append(tab)

	var pages := Control.new()
	pages.custom_minimum_size = Vector2(0, 396)
	box.add_child(pages)
	for i in TABS.size():
		var page := VBoxContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 10)
		pages.add_child(page)
		_pages.append(page)
	_build_sound(_pages[0])
	_build_screen(_pages[1])
	_build_keys(_pages[2])

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 20)
	box.add_child(bottom)
	_hint = Label.new()
	_hint.theme_type_variation = &"PanelSoft"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Com largura mínima: texto com quebra de linha sem ela deixa o primeiro layout da
	# linha torto e o botão "Voltar" chega a ser desenhado sem tamanho.
	_hint.custom_minimum_size = Vector2(460, 0)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_hint)
	_back_button = FancyButton.new()
	_back_button.text = "Voltar"
	_back_button.icon_kind = "back"
	_back_button.custom_minimum_size = Vector2(230, 58)
	_back_button.pressed.connect(close)
	bottom.add_child(_back_button)


func _build_sound(page: Control) -> void:
	for entry in [[GameSettings.BUS_MASTER, "Volume geral"], [GameSettings.BUS_MUSIC, "Música"],
			[GameSettings.BUS_SFX, "Efeitos"]]:
		var bus: StringName = entry[0]
		var slider := VolumeSlider.new()
		slider.setup(entry[1], GameState.settings.get_volume(bus))
		slider.changed.connect(func(v: float): GameState.settings.set_volume(bus, v))
		page.add_child(slider)
		_volumes[bus] = slider
		_page_items[0].append(slider)


func _build_screen(page: Control) -> void:
	_fullscreen = OptionSelector.new()
	_fullscreen.setup("Tela cheia", PackedStringArray(["Desligada", "Ligada"]), 0)
	_fullscreen.changed.connect(_on_fullscreen_changed)
	page.add_child(_fullscreen)
	_page_items[1].append(_fullscreen)
	_resolution = OptionSelector.new()
	_resolution.setup("Resolução", PackedStringArray(["-"]), 0)
	_resolution.changed.connect(_on_resolution_changed)
	page.add_child(_resolution)
	if GameState.settings.can_resize():
		_page_items[1].append(_resolution)
	else:
		_resolution.hide()


func _build_keys(page: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	page.add_child(grid)
	for header in ["Ação", "Tecla", "Outra tecla"]:
		var label := Label.new()
		label.text = header.to_upper()
		label.theme_type_variation = &"PanelSoft"
		label.add_theme_font_size_override("font_size", 14)
		if header != "Ação":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(label)
	for action in GameSettings.KEY_ACTIONS:
		var label := Label.new()
		label.text = GameSettings.KEY_ACTION_NAMES[action]
		label.theme_type_variation = &"PanelLabel"
		label.add_theme_font_size_override("font_size", 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var buttons: Array[KeyButton] = []
		for slot in GameSettings.KEY_SLOTS:
			var b := KeyButton.new()
			b.custom_minimum_size = Vector2(170, 42)
			b.pressed.connect(_listen.bind(action, slot, b))
			grid.add_child(b)
			buttons.append(b)
		_key_buttons[action] = buttons
		_page_items[2].append(buttons)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	page.add_child(row)
	_reset_button = FancyButton.new()
	_reset_button.text = "Restaurar padrão"
	_reset_button.icon_kind = "retry"
	_reset_button.custom_minimum_size = Vector2(300, 52)
	_reset_button.add_theme_font_size_override("font_size", 22)
	_reset_button.pressed.connect(func(): GameState.settings.reset_keys())
	row.add_child(_reset_button)
	_page_items[2].append(_reset_button)


# --- Abas e foco ---------------------------------------------------------------------

func _on_tab_pressed(i: int) -> void:
	_select_page(i)
	# Confirmar na aba entra nela.
	var first = _page_items[i][0]
	(first[0] if first is Array else first).grab_focus()


func _select_page(i: int) -> void:
	_page = i
	for j in _pages.size():
		_pages[j].visible = j == i
		_tabs[j].active = j == i
	_update_hint()
	_link_focus()


## O foco anda só dentro da janela (sem escapar para os botões do menu atrás dela):
## abas em linha, a página aberta em coluna e o "Voltar" embaixo.
func _link_focus() -> void:
	var items: Array = _page_items[_page]
	var first: Control = items[0][0] if items[0] is Array else items[0]
	var last: Control = items[-1][0] if items[-1] is Array else items[-1]
	for j in _tabs.size():
		var tab := _tabs[j]
		_link(tab, _tabs[(j - 1 + _tabs.size()) % _tabs.size()], _tabs[(j + 1) % _tabs.size()], tab, first)
	for r in items.size():
		var up_row = items[r - 1] if r > 0 else null
		var down_row = items[r + 1] if r + 1 < items.size() else null
		var row: Array = items[r] if items[r] is Array else [items[r]]
		for c in row.size():
			var control: Control = row[c]
			var up: Control = _tabs[_page] if up_row == null else _pick(up_row, c)
			var down: Control = _back_button if down_row == null else _pick(down_row, c)
			var left: Control = row[c - 1] if c > 0 else control
			var right: Control = row[c + 1] if c + 1 < row.size() else control
			_link(control, left, right, up, down)
	_link(_back_button, _back_button, _back_button, last, _tabs[_page])
	# Tab / Shift+Tab: na ordem da página.
	var order: Array[Control] = []
	order.append_array(_tabs)
	for it in items:
		if it is Array:
			order.append_array(it)
		else:
			order.append(it)
	order.append(_back_button)
	for k in order.size():
		order[k].focus_next = order[k].get_path_to(order[(k + 1) % order.size()])
		order[k].focus_previous = order[k].get_path_to(order[(k - 1 + order.size()) % order.size()])


func _pick(row, column: int) -> Control:
	if row is Array:
		return row[mini(column, row.size() - 1)]
	return row


func _link(c: Control, left: Control, right: Control, up: Control, down: Control) -> void:
	c.focus_neighbor_left = c.get_path_to(left)
	c.focus_neighbor_right = c.get_path_to(right)
	c.focus_neighbor_top = c.get_path_to(up)
	c.focus_neighbor_bottom = c.get_path_to(down)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _listening:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pausa"):
		Sfx.play(self, &"ui_back", -10.0)
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed \
			and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		# LB / RB trocam de aba.
		var dir := -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
		_tabs[(_page + dir + _tabs.size()) % _tabs.size()].grab_focus()
		get_viewport().set_input_as_handled()


# --- Valores -------------------------------------------------------------------------

func _refresh_all() -> void:
	for bus in _volumes:
		(_volumes[bus] as VolumeSlider).set_value(GameState.settings.get_volume(bus), false)
	_fullscreen.set_index(1 if GameState.settings.is_fullscreen() else 0, false)
	_refresh_resolution()
	_refresh_keys()


func _refresh_resolution() -> void:
	var full := GameState.settings.is_fullscreen()
	if full:
		var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
		_resolutions = [screen]
	else:
		_resolutions = GameState.settings.available_resolutions()
	var names := PackedStringArray()
	for r in _resolutions:
		names.append(GameSettings.format_resolution(r))
	_resolution.options = names
	_resolution.index = maxi(_resolutions.find(GameState.settings.get_resolution()), 0) if not full else 0
	_resolution.enabled = not full and _resolutions.size() > 1
	_resolution.queue_redraw()


func _refresh_keys() -> void:
	for action in _key_buttons:
		var keys := GameState.settings.get_keys(action)
		var buttons: Array = _key_buttons[action]
		for slot in buttons.size():
			(buttons[slot] as KeyButton).physical = keys[slot]
	_reset_button.disabled = GameState.settings.keys_are_default()
	_reset_button.focus_mode = Control.FOCUS_ALL


func _on_fullscreen_changed(index: int) -> void:
	GameState.settings.set_fullscreen(index == 1)
	# O tamanho da janela muda um pouco depois (animação da tela cheia no macOS).
	_refresh_resolution()
	for wait in [0.3, 1.0]:
		get_tree().create_timer(wait, true).timeout.connect(_refresh_resolution)


func _on_resolution_changed(index: int) -> void:
	if index < _resolutions.size():
		GameState.settings.set_resolution(_resolutions[index])


func _update_hint() -> void:
	if _listening:
		_hint.text = "Aperte a nova tecla para \"%s\"  •  Esc cancela" % GameSettings.KEY_ACTION_NAMES[_listen_action]
		_hint.add_theme_color_override("font_color", UiKit.INK)
		return
	_hint.remove_theme_color_override("font_color")
	if _page == 1 and not GameState.settings.can_resize():
		_hint.text = WEB_SCREEN_HINT
	else:
		_hint.text = PAGE_HINTS[_page]


# --- Trocar tecla --------------------------------------------------------------------

func _listen(action: StringName, slot: int, button: KeyButton) -> void:
	if _listening:
		return
	_listening = button
	_listen_action = action
	_listen_slot = slot
	button.listening = true
	_update_hint()


func _stop_listening() -> void:
	if _listening:
		_listening.listening = false
	_listening = null
	_update_hint()


## Esperando a tecla nova: tudo passa por aqui antes da interface (o Enter não
## confirma, o Esc não fecha a janela).
func _input(event: InputEvent) -> void:
	if not visible or _listening == null:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			var key := event as InputEventKey
			if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
				Sfx.play(self, &"ui_back", -10.0)
			else:
				var physical: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
				GameState.settings.set_key(_listen_action, _listen_slot, physical)
				Sfx.play(self, &"ui_accept", -8.0)
			_stop_listening()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton or event is InputEventMouseButton:
		# B ou um clique cancelam; os outros botões não fazem nada aqui.
		var cancel: bool = event.pressed and (event is InputEventMouseButton or event.button_index == JOY_BUTTON_B)
		if cancel:
			Sfx.play(self, &"ui_back", -10.0)
			_stop_listening()
		get_viewport().set_input_as_handled()
	elif event is InputEventAction or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
