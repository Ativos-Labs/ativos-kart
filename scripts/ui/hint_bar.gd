class_name HintBar
extends Control
## Faixa no rodapé com as teclas de cada ação ("Enter Confirmar", "Esc Voltar"...).
## Cada dica é "Tecla|Ação"; várias teclas: "←  →|Escolher".

@export var hints: PackedStringArray = ["Enter|Confirmar", "Esc|Voltar"]:
	set(value):
		hints = value
		queue_redraw()


func _draw() -> void:
	var h := size.y
	UiKit.draw_gradient_poly(self, PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, h)]),
			Color(0.02, 0.04, 0.12, 0.35), Color(0.02, 0.04, 0.12, 0.75), 0.0, h)
	draw_line(Vector2(0, 0), Vector2(size.x, 0), Color(1, 1, 1, 0.25), 2.0)
	var font: Font = UiKit.FONT_BODY
	var fs := 19
	var key_h := h * 0.58
	var x := size.x - 36.0
	for i in range(hints.size() - 1, -1, -1):
		var parts := hints[i].split("|")
		var action := parts[1] if parts.size() > 1 else ""
		var keys := parts[0].split("  ")
		var action_w := font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x -= action_w
		var baseline := h * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(x, baseline), action, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		x -= 12.0
		for k in range(keys.size() - 1, -1, -1):
			var key_label := keys[k]
			var key_w := maxf(key_h, font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + key_h * 0.6)
			x -= key_w
			UiKit.draw_key(self, Vector2(x, (h - key_h) * 0.5), key_h, key_label, 16)
			x -= 6.0
		x -= 34.0
