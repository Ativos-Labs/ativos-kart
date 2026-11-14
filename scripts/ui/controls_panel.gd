class_name ControlsPanel
extends Control
## Janela "Controles": tabela com as teclas de cada ação e dicas de pilotagem.
## Usada no menu principal e no menu de pausa.

signal closed

const CONTROLS := [
	["Acelerar", ["W", "↑"], ["A", "RT"]],
	["Frear / ré", ["S", "↓"], ["B", "LT"]],
	["Virar", ["A", "D", "←", "→"], ["Analógico"]],
	["Pulo / drift", ["Espaço", "Shift"], ["RB", "X"]],
	["Reposicionar", ["R"], ["Y"]],
	["Pausar", ["Esc", "P"], ["Start"]],
]

@onready var grid: GridContainer = %ControlsGrid
@onready var back_button: Button = %ControlsBackButton
@onready var panel: Control = %Panel


func _ready() -> void:
	back_button.pressed.connect(close)
	_fill()
	hide()


func open() -> void:
	show()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.85
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28)
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pausa")):
		close()
		get_viewport().set_input_as_handled()


func _fill() -> void:
	for header in ["Ação", "Teclado", "Controle"]:
		var label := Label.new()
		label.text = header.to_upper()
		label.theme_type_variation = &"PanelSoft"
		label.add_theme_font_size_override("font_size", 15)
		grid.add_child(label)
	for row in CONTROLS:
		var action := Label.new()
		action.text = row[0]
		action.theme_type_variation = &"PanelLabel"
		action.add_theme_font_size_override("font_size", 21)
		grid.add_child(action)
		grid.add_child(_keys(row[1]))
		grid.add_child(_keys(row[2]))


func _keys(keys: Array) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for k in keys:
		var key := Label.new()
		key.text = k
		key.add_theme_font_size_override("font_size", 17)
		key.add_theme_color_override("font_color", Color.WHITE)
		var style := StyleBoxFlat.new()
		style.bg_color = UiKit.NAVY_LIGHT
		style.set_corner_radius_all(9)
		style.content_margin_left = 11
		style.content_margin_right = 11
		style.content_margin_top = 3
		style.content_margin_bottom = 5
		style.border_width_bottom = 4
		style.border_color = UiKit.NAVY
		key.add_theme_stylebox_override("normal", style)
		box.add_child(key)
	return box
