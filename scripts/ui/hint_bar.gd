class_name HintBar
extends Control
## Faixa no rodapé com as teclas de cada ação ("Enter Confirmar", "Esc Voltar"...).
## Cada dica é "Tecla|Ação"; várias teclas: "←  →|Escolher".
## Jogando no controle, as teclas viram os botões dele: Enter → A, Esc → B e as
## setas → "Direcional" (dicas só de mouse somem; dicas que ficam com o mesmo botão
## se juntam: "Direcional  Navegar e trocar").

## Teclas que têm um botão equivalente no controle (com a cor do botão).
const PAD_BUTTONS := {
	"Enter": ["A", Color(0.3, 0.7, 0.24)],
	"Esc": ["B", Color(0.86, 0.2, 0.2)],
}
const ARROWS: Array[String] = ["↑", "↓", "←", "→"]
const MOUSE_ONLY: Array[String] = ["Arraste"]

@export var hints: PackedStringArray = ["Enter|Confirmar", "Esc|Voltar"]:
	set(value):
		hints = value
		queue_redraw()

var _using_pad := false


func _ready() -> void:
	var menu_input := GameState.menu_input
	if menu_input:
		_using_pad = menu_input.using_pad
		menu_input.device_changed.connect(_on_device_changed)


func _on_device_changed(using_pad: bool) -> void:
	_using_pad = using_pad
	queue_redraw()


## [[teclas], ação] de cada dica, já trocadas pelos botões do controle se for o caso.
func _entries() -> Array:
	var out := []
	for hint in hints:
		var parts := hint.split("|")
		var action := parts[1] if parts.size() > 1 else ""
		var keys := Array(parts[0].split("  "))
		if _using_pad:
			var pad_keys := []
			for k: String in keys:
				if k in ARROWS:
					if not pad_keys.has("Direcional"):
						pad_keys.append("Direcional")
				elif PAD_BUTTONS.has(k):
					pad_keys.append(PAD_BUTTONS[k][0])
				elif not k in MOUSE_ONLY:
					pad_keys.append(k)
			if pad_keys.is_empty():
				continue
			if not out.is_empty() and out[-1][0] == pad_keys:
				out[-1][1] += " e " + action.to_lower()
				continue
			keys = pad_keys
		out.append([keys, action])
	return out


func _draw() -> void:
	var h := size.y
	UiKit.draw_gradient_poly(self, PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, h)]),
			Color(0.02, 0.04, 0.12, 0.35), Color(0.02, 0.04, 0.12, 0.75), 0.0, h)
	draw_line(Vector2(0, 0), Vector2(size.x, 0), Color(1, 1, 1, 0.25), 2.0)
	var font: Font = UiKit.FONT_BODY
	var fs := 19
	var key_h := h * 0.58
	var x := size.x - 36.0
	var entries := _entries()
	for i in range(entries.size() - 1, -1, -1):
		var keys: Array = entries[i][0]
		var action: String = entries[i][1]
		var action_w := font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x -= action_w
		var baseline := h * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(x, baseline), action, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		x -= 12.0
		for k in range(keys.size() - 1, -1, -1):
			var key_label: String = keys[k]
			var key_w := UiKit.key_width(key_label, key_h, 16)
			x -= key_w
			var button := _pad_button(key_label)
			if button.is_empty():
				UiKit.draw_key(self, Vector2(x, (h - key_h) * 0.5), key_h, key_label, 16)
			else:
				UiKit.draw_key(self, Vector2(x, (h - key_h) * 0.5), key_h, key_label, 16, button[1], Color.WHITE)
			x -= 6.0
		x -= 34.0


## [rótulo, cor] do botão do controle com esse rótulo ("A", "B"), ou [] se não for um.
func _pad_button(label: String) -> Array:
	if not _using_pad:
		return []
	for k: String in PAD_BUTTONS:
		if PAD_BUTTONS[k][0] == label:
			return PAD_BUTTONS[k]
	return []
