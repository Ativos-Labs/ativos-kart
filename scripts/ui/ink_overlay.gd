class_name InkOverlay
extends Control
## Juridiquês na tela: borrões de tinta cheios de texto jurídico miúdo ("Outrossim,
## data venia, considerando-se…") cobrem boa parte da visão por alguns segundos, depois
## escorrem e somem. Fica embaixo do resto do HUD (posição, moedas e item continuam à
## vista). Cada borrão é desenhado uma vez; a animação só mexe em escala, posição e
## opacidade.

const LEGAL := "Outrossim, data venia, considerando-se o quanto exposto alhures e a teor do disposto no art. 286 do Código Civil, c/c o art. 1.º, § 2.º, inciso IV, alínea b, ex vi legis, mister se faz consignar que o cedente, doravante denominado CEDENTE, in casu, sem prejuízo do ora avençado, data maxima venia, impende salientar que a presente avença rege-se pelo pacta sunt servanda, ad referendum, sob pena de preclusão, nos termos retrocitados, destarte, mutatis mutandis, à guisa de conclusão, requer-se a juntada, ipso facto, inaudita altera pars, conforme cláusula décima quarta, parágrafo único, ressalvadas as disposições em contrário."
const INK_COLOR := Color(0.05, 0.06, 0.12, 0.97)
const TEXT_COLOR := Color(0.88, 0.85, 0.74, 0.8)
## Borrões: centro (fração da tela) e raio (fração da altura).
const LAYOUT: Array[Vector3] = [
	Vector3(0.3, 0.36, 0.27), Vector3(0.65, 0.3, 0.23), Vector3(0.47, 0.64, 0.25),
	Vector3(0.83, 0.6, 0.19), Vector3(0.13, 0.68, 0.16), Vector3(0.62, 0.88, 0.14),
]
## Tempo (s) para escorrer e sumir no fim.
const FADE_TIME := 1.5

## Tamanho da letra do texto miúdo.
var text_size := 11
var _blobs: Array[Control] = []
var _tween: Tween


## Um borrão: mancha ondulada, gotinhas em volta, pingos escorrendo e o texto por dentro.
class InkBlob:
	extends Control

	var radius := 100.0
	var seed_value := 0.0
	var words := PackedStringArray()
	var first_word := 0
	var font_size := 11

	func _init(p_radius: float, p_seed: float, p_words: PackedStringArray, p_first: int, p_font_size: int) -> void:
		radius = p_radius
		seed_value = p_seed
		words = p_words
		first_word = p_first
		font_size = p_font_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2.ONE * radius * 3.2
		pivot_offset = size * 0.5

	func _draw() -> void:
		var c := size * 0.5
		var ink := InkOverlay.INK_COLOR
		var rng := RandomNumberGenerator.new()
		rng.seed = int(seed_value * 1000.0)
		for i in 7:
			var a := rng.randf() * TAU
			var d := radius * rng.randf_range(1.12, 1.45)
			draw_circle(c + Vector2(cos(a), sin(a)) * d, radius * rng.randf_range(0.04, 0.11), ink)
		for i in 3:
			var x := rng.randf_range(-0.6, 0.6)
			var top := c.y + radius * 0.75 * sqrt(1.0 - x * x)
			var w := radius * rng.randf_range(0.07, 0.12)
			var length := radius * rng.randf_range(0.3, 0.75)
			draw_rect(Rect2(c.x + x * radius - w * 0.5, top - w, w, length), ink)
			draw_circle(Vector2(c.x + x * radius, top - w + length), w * 0.72, ink)
		draw_colored_polygon(RaceItem.blob_points(c, radius, seed_value, 56), ink)
		draw_circle(c + Vector2(-0.4, -0.44) * radius, radius * 0.12, Color(1, 1, 1, 0.05))
		# Texto miúdo dentro da mancha: cada linha cabe na largura da elipse naquela altura.
		var font: Font = UiKit.FONT_BODY
		var line_h := font_size * 1.3
		var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var wi := first_word
		var y := -radius * 0.7
		while y < radius * 0.7:
			var k := y / (radius * 0.76)
			var half := radius * 0.82 * sqrt(maxf(1.0 - k * k, 0.0))
			if half > font_size * 2.5:
				var line := ""
				var width := 0.0
				for guard in 40:
					var word := words[wi % words.size()]
					var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					var add := ww + (space if line != "" else 0.0)
					if line != "" and width + add > half * 2.0:
						break
					line += (" " if line != "" else "") + word
					width += add
					wi += 1
				draw_string(font, Vector2(c.x - width * 0.5, c.y + y + font_size * 0.35), line,
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, InkOverlay.TEXT_COLOR)
			y += line_h


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Cobre a tela de tinta por `duration` segundos (o fim escorre e some).
func splat(duration: float) -> void:
	clear()
	var area := size if size.x > 1.0 else get_viewport_rect().size
	var words := LEGAL.split(" ", false)
	var start := randi() % words.size()
	_tween = create_tween().set_parallel()
	for i in LAYOUT.size():
		var l := LAYOUT[i]
		var c := Vector2(l.x + randf_range(-0.05, 0.05), l.y + randf_range(-0.05, 0.05)) * area
		var r := l.z * area.y * randf_range(0.9, 1.12)
		var blob := InkBlob.new(r, randf() * 10.0, words, start + i * 23, text_size)
		blob.position = c - blob.size * 0.5
		blob.rotation = randf_range(-0.3, 0.3)
		blob.scale = Vector2.ONE * 0.15
		add_child(blob)
		_blobs.append(blob)
		_tween.tween_property(blob, "scale", Vector2.ONE, 0.24).set_delay(i * 0.05) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var hold := maxf(duration - FADE_TIME, 0.4) + i * 0.05
		_tween.tween_property(blob, "position:y", blob.position.y + area.y * 0.08, FADE_TIME).set_delay(hold) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(blob, "modulate:a", 0.0, FADE_TIME).set_delay(hold) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(clear)


## Tira a tinta na hora.
func clear() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	for b in _blobs:
		if is_instance_valid(b):
			b.queue_free()
	_blobs.clear()


func is_active() -> bool:
	return not _blobs.is_empty()
