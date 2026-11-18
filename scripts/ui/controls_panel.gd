class_name ControlsPanel
extends Control
## Janela "Controles": tabela com as teclas de cada ação e dicas de pilotagem.
## Usada no menu principal e no menu de pausa. As teclas são as atuais (dá para
## trocá-las na tela de opções); os botões do controle são fixos.

signal closed

## [nome, ações cujas teclas aparecem (ou teclas fixas), botões do controle].
const CONTROLS := [
	["Acelerar", [&"acelerar"], ["A", "RT"]],
	["Frear / ré", [&"frear"], ["B", "LT"]],
	["Virar", [&"esquerda", &"direita"], ["Analógico"]],
	["Pulo / drift", [&"drift"], ["RB", "X"]],
	["Usar item", [&"usar_item"], ["LB"]],
	["Reposicionar", [&"reposicionar"], ["Y"]],
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
	_fill()
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
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
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
		var keys := PackedStringArray()
		for k in row[1]:
			if k is StringName:
				keys.append_array(GameState.settings.key_labels(k))
			else:
				keys.append(k)
		grid.add_child(_keys(keys))
		grid.add_child(_keys(PackedStringArray(row[2])))


func _keys(keys: PackedStringArray) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for k in keys:
		box.add_child(KeyCap.new(k))
	return box
