class_name PulseDot
extends Node2D
## Ponto colorido com anel branco, halo pulsando e (opcional) seta de direção.
## Usado nos mapas e no velocímetro.
##
## É desenhado uma vez só: o pulso muda apenas a escala do halo, e quem usa muda só
## a posição e a rotação do nó. Refazer o desenho a cada quadro (draw_circle,
## draw_polyline...) recria os polígonos na GPU e custa caro.
## Configure os raios antes de adicionar o nó à cena.

var color := UiKit.YELLOW:
	set(value):
		color = value
		queue_redraw()
		_halo.queue_redraw()
var core_radius := 6.5
## Anel branco em volta do ponto (0 = sem anel).
var ring_radius := 9.0
var halo_radius := 13.0
## Quanto o halo cresce no pulso (em pixels).
var halo_grow := 3.0
var halo_alpha := 0.25
## Velocidade do pulso (radianos por milissegundo).
var pulse_speed := 0.006
## Seta apontando para +X (gire o nó para indicar a direção).
var arrow := false

var _halo := Node2D.new()


func _init() -> void:
	_halo.show_behind_parent = true
	_halo.draw.connect(_draw_halo)
	add_child(_halo)


func _process(_delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * pulse_speed)
	_halo.scale = Vector2.ONE * ((halo_radius + pulse * halo_grow) / halo_radius)


func _draw_halo() -> void:
	_halo.draw_circle(Vector2.ZERO, halo_radius, Color(color, halo_alpha))


func _draw() -> void:
	if arrow:
		draw_colored_polygon(PackedVector2Array([Vector2(15.0, 0.0), Vector2(0.0, 7.0), Vector2(0.0, -7.0)]), Color.WHITE)
	if ring_radius > 0.0:
		draw_circle(Vector2.ZERO, ring_radius, Color.WHITE)
	draw_circle(Vector2.ZERO, core_radius, color)
