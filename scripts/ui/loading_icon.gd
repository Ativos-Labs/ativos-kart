class_name LoadingIcon
extends Control
## Ícone da tela de carregamento: o Celerino no kart visto de lado, em branco, com
## baforadas de fumaça saindo do escapamento, ficando transparentes e diminuindo.
## Fica no canto inferior direito, sobre o fade da troca de tela (GameState.goto_scene).
##
## A imagem sai de tools/loading/render_icone.gd. Cada baforada é um nó desenhado uma
## vez só; a animação mexe apenas posição, escala e transparência (redesenhar a cada
## quadro recria os polígonos na GPU).

const TEXTURE := preload("res://assets/ui/carregando_celerino.png")
## Altura do kart na tela (px).
const HEIGHT := 56.0
## Distância até os cantos da tela (px).
const MARGIN := 36.0
## Escapamento na imagem (fração do tamanho): traseira do kart, embaixo.
const EXHAUST := Vector2(0.03, 0.72)
## Intervalo entre baforadas e quanto cada uma dura (s).
const PUFF_EVERY := 0.26
const PUFF_LIFE := 0.75
## Para onde a fumaça vai (px/s): para trás e um pouco para cima.
const PUFF_VELOCITY := Vector2(-46.0, -14.0)
const PUFF_RADIUS := 6.0
const PUFFS := 4

var _kart := TextureRect.new()
var _puffs: Array[Node2D] = []
## Idade de cada baforada (s); < 0 = parada esperando a vez.
var _ages: PackedFloat32Array = []
## Desvio de cada baforada (para a fumaça não sair em fila reta).
var _drift: PackedVector2Array = []
var _next := 0
var _clock := 0.0
var _spawn := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_size := Vector2(TEXTURE.get_size())
	var size_px := Vector2(HEIGHT * tex_size.x / tex_size.y, HEIGHT)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -MARGIN - size_px.x
	offset_top = -MARGIN - size_px.y
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	# A fumaça (atrás do kart) primeiro, o kart por cima.
	for i in PUFFS:
		var puff := _Puff.new()
		puff.radius = PUFF_RADIUS
		puff.visible = false
		add_child(puff)
		_puffs.append(puff)
		_ages.append(-1.0)
		_drift.append(Vector2.ZERO)
	_kart.texture = TEXTURE
	_kart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_kart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_kart.size = size_px
	_kart.pivot_offset = Vector2(size_px.x * 0.5, size_px.y)
	_kart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kart)
	visibility_changed.connect(_restart)


func _restart() -> void:
	if not visible:
		return
	_clock = 0.0
	_spawn = 0.0
	for i in _puffs.size():
		_ages[i] = -1.0
		_puffs[i].visible = false
	# Já entra com a fumaça saindo (e não com o rastro vazio).
	for i in ceili(PUFF_LIFE * 30.0):
		_step(1.0 / 30.0)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		# Travadas longas (a troca de tela) não viram um salto na animação.
		_step(minf(delta, 1.0 / 20.0))


func _step(delta: float) -> void:
	_clock += delta
	# O kart trepida de leve, como se o motor estivesse ligado.
	_kart.position.y = -absf(sin(_clock * 22.0)) * 1.5
	_kart.rotation = sin(_clock * 11.0) * 0.012

	_spawn -= delta
	if _spawn <= 0.0:
		_spawn += PUFF_EVERY
		_ages[_next] = 0.0
		_drift[_next] = Vector2(randf_range(-6.0, 6.0), randf_range(-10.0, 4.0))
		_puffs[_next].visible = true
		_next = (_next + 1) % _puffs.size()

	var origin := _kart.position + _kart.size * EXHAUST
	for i in _puffs.size():
		if _ages[i] < 0.0:
			continue
		_ages[i] += delta
		var t := _ages[i] / PUFF_LIFE
		var puff := _puffs[i]
		if t >= 1.0:
			_ages[i] = -1.0
			puff.visible = false
			continue
		var ease_out := 1.0 - (1.0 - t) * (1.0 - t)
		puff.position = origin + (PUFF_VELOCITY + _drift[i]) * PUFF_LIFE * ease_out
		# Sai cheia e encolhe até sumir; a transparência acompanha.
		puff.scale = Vector2.ONE * lerpf(1.0, 0.25, t)
		puff.modulate.a = 0.75 * (1.0 - t)


class _Puff extends Node2D:
	var radius := 6.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color.WHITE, true, -1.0, true)
