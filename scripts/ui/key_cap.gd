class_name KeyCap
extends Control
## Tecla desenhada, só para mostrar (tela de controles): texto ou seta.

var label := ""
var font_size := 17
var fill := UiKit.NAVY_LIGHT
var text_color := Color.WHITE


func _init(p_label := "", height := 32.0) -> void:
	label = p_label
	custom_minimum_size = Vector2(UiKit.key_width(label, height, font_size), height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	UiKit.draw_key(self, Vector2.ZERO, size.y, label, font_size, fill, text_color)
