class_name SpeedGauge
extends Control
## Velocímetro em arco com o número grande no meio. Fica laranja no turbo e mostra
## a cor do mini-turbo durante o drift.
##
## O desenho fica em camadas para não refazer polígonos a cada quadro: o fundo é
## desenhado uma vez, o arco e o número só quando o valor mostrado muda, e a
## bolinha do drift pulsa mudando só a escala.

const DRIFT_COLORS := [Color(1, 1, 1), Color(0.3, 0.7, 1.0), Color(1.0, 0.6, 0.15), Color(0.95, 0.4, 1.0)]
const START := deg_to_rad(150.0)
const END := deg_to_rad(390.0)
const WIDTH := 16.0
## Passos do arco (480 = meio grau): o arco só é redesenhado quando muda de passo.
const FILL_STEPS := 480

## Camada de desenho do tamanho do velocímetro inteiro.
class Layer extends Control:
	var _paint: Callable

	func _init(paint: Callable) -> void:
		_paint = paint
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		_paint.call(self)


var kmh := 0.0:
	set(value):
		kmh = value
		var shown := roundi(value)
		if shown != _shown_kmh:
			_shown_kmh = shown
			_number.queue_redraw()
## 0 a 1 (velocidade / velocidade máxima).
var ratio := 0.0:
	set(value):
		ratio = value
		var steps := roundi(clampf(value, 0.0, 1.0) * FILL_STEPS)
		if steps != _fill_steps:
			_fill_steps = steps
			_fill.queue_redraw()
var boosting := false:
	set(value):
		if value != boosting:
			boosting = value
			_fill.queue_redraw()
			_number.queue_redraw()
## -1 = sem drift; 0..3 = nível do mini-turbo.
var drift_level := -1:
	set(value):
		if value != drift_level:
			drift_level = value
			_drift.visible = value >= 0
			if value >= 0:
				_drift.color = DRIFT_COLORS[clampi(value, 0, 3)]

var _shown_kmh := 0
var _fill_steps := 0
var _fill := Layer.new(_draw_fill)
var _number := Layer.new(_draw_number)
var _drift := PulseDot.new()


func _init() -> void:
	add_child(_fill)
	_drift.visible = false
	_drift.core_radius = 7.0
	_drift.ring_radius = 0.0
	_drift.halo_radius = 9.0
	_drift.halo_alpha = 0.35
	_drift.pulse_speed = 0.02
	add_child(_drift)
	add_child(_number)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _layout() -> void:
	_drift.position = _center() + Vector2(0.0, -_radius() * 0.62)


func _center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.58)


func _radius() -> float:
	return minf(size.x * 0.5, size.y * 0.58) - 10.0


func _font_size() -> int:
	return int(_radius() * 0.78)


## Fundo: trilho do arco, marcas e "km/h".
func _draw() -> void:
	var c := _center()
	var r := _radius()
	draw_arc(c + Vector2(0, 3), r, START, END, 48, Color(0, 0, 0, 0.35), WIDTH + 6.0, true)
	draw_arc(c, r, START, END, 48, Color(0.04, 0.07, 0.18, 0.8), WIDTH + 6.0, true)
	for i in 11:
		var a := lerpf(START, END, i / 10.0)
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * (r - WIDTH * 0.5 - 2.0), c + dir * (r - WIDTH * 0.5 - (9.0 if i % 5 == 0 else 5.0)),
				Color(1, 1, 1, 0.7), 2.0, true)
	var unit := "km/h"
	var uf := UiKit.FONT_BODY
	var uw := uf.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	UiKit.draw_outlined(self, uf, Vector2(c.x - uw * 0.5, c.y + _font_size() * 0.3 + 24.0), unit, 17, UiKit.YELLOW, UiKit.NAVY, 6)


## Arco preenchido: uma linha só, com a cor variando ao longo dela.
func _draw_fill(ci: CanvasItem) -> void:
	var shown := float(_fill_steps) / FILL_STEPS
	if shown <= 0.005:
		return
	var c := _center()
	var r := _radius()
	var to := lerpf(START, END, shown)
	var segments := maxi(2, ceili(48.0 * shown))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in segments + 1:
		var t := float(i) / segments
		pts.append(c + Vector2.from_angle(lerpf(START, to, t)) * r)
		var k := t * shown
		cols.append(UiKit.ORANGE.lerp(UiKit.RED, k) if boosting else UiKit.YELLOW_LIGHT.lerp(UiKit.ORANGE, k))
	ci.draw_polyline_colors(pts, cols, WIDTH, true)


func _draw_number(ci: CanvasItem) -> void:
	var c := _center()
	var font: Font = UiKit.FONT_ITALIC
	var fs := _font_size()
	var txt := str(_shown_kmh)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var col_text := Color(1, 0.8, 0.35) if boosting else Color.WHITE
	UiKit.draw_outlined(ci, font, Vector2(c.x - tw * 0.5, c.y + fs * 0.3), txt, fs, col_text, UiKit.NAVY, 12)
