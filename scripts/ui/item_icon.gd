class_name ItemIcon
extends Control
## Ícone de um item (RaceItem.draw_icon) do tamanho do controle. Redesenha só quando o
## item muda; na roleta do ItemSlot os ícones só mudam de posição.

var kind := RaceItem.NONE:
	set(value):
		if value != kind:
			kind = value
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if kind != RaceItem.NONE:
		RaceItem.draw_icon(self, kind, size * 0.5, minf(size.x, size.y) * 0.5 * 0.86)
