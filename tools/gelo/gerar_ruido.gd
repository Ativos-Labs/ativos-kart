extends SceneTree
## Gera assets/textures/ruido.png: ruído branco 256×256 (um valor aleatório por texel,
## sempre o mesmo — semente fixa), em tons de cinza. Os shaders da pista de neve e gelo
## leem ele em shaders/noise_tex.gdshaderinc como ruído de valor (cada texel é um ponto
## da grade): uma leitura de textura no lugar das quatro contas de hash do vnoise.
## Ruído branco repete sem emenda, então a textura pode ladrilhar.
## Uso: Godot --headless --path . -s res://tools/gelo/gerar_ruido.gd

const SIZE := 256
const OUT := "res://assets/textures/ruido.png"


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123
	var data := PackedByteArray()
	data.resize(SIZE * SIZE)
	for i in data.size():
		data[i] = rng.randi() & 255
	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, data)
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("ruido.png: ", error_string(err))
	quit()
