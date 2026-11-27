class_name SlantedBackdrop
extends Control
## Fundo da tela de copas (cup_select.gd): as vistas aéreas das pistas de uma copa lado a
## lado, em colunas da altura da tela (duas: metade cada; três: um terço; quatro: um
## quarto), separadas por linhas pretas inclinadas (como as faixas da interface: o alto
## mais à direita que o pé). Cada imagem cobre a coluna dela sem distorcer (cortando o
## que sobra). Imagem ainda carregando: a coluna fica escura.

## Quanto cada linha anda para a direita de baixo até em cima, em fração da altura da tela.
const SLANT := 0.25
## Espessura da linha preta entre as colunas (px).
const SEAM := 2.0
const EMPTY := Color(0.06, 0.09, 0.22)

var _textures: Array[Texture2D] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Quantas colunas (uma por pista).
func set_count(n: int) -> void:
	_textures.resize(n)
	queue_redraw()


func set_texture(k: int, texture: Texture2D) -> void:
	if k < _textures.size():
		_textures[k] = texture
		queue_redraw()


func _draw() -> void:
	var n := _textures.size()
	if n == 0:
		return
	var w := size.x
	var h := size.y
	var lean := h * SLANT
	# Linha j: x em cima e embaixo (as das pontas são a borda da tela, retas).
	var top := PackedFloat32Array()
	var bottom := PackedFloat32Array()
	for j in n + 1:
		var x := w * j / n
		var tilt := 0.0 if j == 0 or j == n else lean * 0.5
		top.append(x + tilt)
		bottom.append(x - tilt)
	for k in n:
		var pts := PackedVector2Array([Vector2(top[k], 0), Vector2(top[k + 1], 0),
				Vector2(bottom[k + 1], h), Vector2(bottom[k], h)])
		var tex := _textures[k]
		if tex == null:
			draw_colored_polygon(pts, EMPTY)
			continue
		draw_polygon(pts, PackedColorArray([Color.WHITE]), _cover_uvs(pts, tex), tex)
	for j in range(1, n):
		draw_line(Vector2(top[j], -2), Vector2(bottom[j], h + 2), Color.BLACK, SEAM, true)


## UVs para a imagem cobrir o retângulo em volta da coluna sem distorcer (centralizada,
## cortando as sobras).
static func _cover_uvs(pts: PackedVector2Array, tex: Texture2D) -> PackedVector2Array:
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	var box_aspect := box.size.x / maxf(box.size.y, 1.0)
	var tex_aspect := float(tex.get_width()) / tex.get_height()
	var span := Vector2.ONE
	if box_aspect > tex_aspect:
		span.y = tex_aspect / box_aspect
	else:
		span.x = box_aspect / tex_aspect
	var start := (Vector2.ONE - span) * 0.5
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(start + (p - box.position) / box.size * span)
	return uvs
