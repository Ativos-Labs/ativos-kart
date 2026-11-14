class_name TrackPreview
extends Control
## Mapa do traçado na tela de seleção: a linha se desenha sozinha, mostra a
## largada quadriculada, as placas de turbo e um ponto correndo pela pista.
## O traçado só é redesenhado enquanto aparece; o ponto é um PulseDot que só muda
## de posição a cada quadro.

var _points := PackedVector2Array()
var _boosts := PackedVector2Array()
var _reveal := 1.0:
	set(value):
		_reveal = value
		queue_redraw()
var _run := 0.0
var _locked := false
var _color := UiKit.YELLOW
var _track: Track
var _dot := PulseDot.new()


## Mostra o traçado da pista (ou "?" se `track` for nulo).
func show_track(track: Track, color := UiKit.YELLOW) -> void:
	_track = track
	_locked = track == null
	_color = color
	_dot.color = color
	_rebuild()
	_reveal = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_reveal", 1.0, 0.9)


func _ready() -> void:
	_dot.halo_alpha = 0.3
	_dot.pulse_speed = 0.008
	add_child(_dot)
	resized.connect(_rebuild)


func _rebuild() -> void:
	_points = PackedVector2Array()
	_boosts = PackedVector2Array()
	if _track == null or _track.samples.is_empty() or size.x < 40.0:
		queue_redraw()
		return
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for s in _track.samples:
		min_p = min_p.min(Vector2(s.x, s.z))
		max_p = max_p.max(Vector2(s.x, s.z))
	var pad := 18.0
	var extent := max_p - min_p
	var k := minf((size.x - pad * 2.0) / maxf(extent.x, 1.0), (size.y - pad * 2.0) / maxf(extent.y, 1.0))
	var offset := (size - extent * k) * 0.5
	for s in _track.samples:
		_points.append((Vector2(s.x, s.z) - min_p) * k + offset)
	_points.append(_points[0])
	for frac in _track.boost_pads:
		var p := _track.get_point_at(wrapf(frac, 0.0, 1.0) * _track.length)
		_boosts.append((Vector2(p.x, p.z) - min_p) * k + offset)
	queue_redraw()


func _process(delta: float) -> void:
	_run = fposmod(_run + delta * 0.12, 1.0)
	_dot.visible = not _locked and _points.size() >= 3 and _reveal >= 0.999
	if _dot.visible:
		var f := _run * (_points.size() - 1)
		var i0 := int(f)
		_dot.position = _points[i0].lerp(_points[mini(i0 + 1, _points.size() - 1)], f - i0)


func _draw() -> void:
	if _locked or _points.size() < 3:
		var font: Font = UiKit.FONT_TITLE
		var fs := int(size.y * 0.5)
		var tw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.16, 0.21, 0.25))
		return
	var count := int(ceil((_points.size() - 1) * _reveal)) + 1
	var pts := _points.slice(0, mini(count, _points.size()))
	if pts.size() < 2:
		return
	draw_polyline(UiKit.offset_points(pts, Vector2(0, 4)), Color(0, 0, 0, 0.18), 18.0, true)
	draw_polyline(pts, UiKit.NAVY, 18.0, true)
	draw_polyline(pts, Color(0.95, 0.96, 1.0), 10.0, true)
	draw_polyline(pts, Color(0.75, 0.79, 0.88), 2.0, true)
	if _reveal < 0.999:
		return
	for b in _boosts:
		draw_circle(b, 6.0, UiKit.ORANGE)
		draw_circle(b, 3.0, UiKit.YELLOW_LIGHT)
	# Largada quadriculada.
	var start := _points[0]
	var dir := (_points[1] - _points[0]).normalized()
	var normal := Vector2(-dir.y, dir.x)
	for i in 4:
		var a := start + normal * (-10.0 + i * 5.0)
		draw_line(a, a + normal * 5.0, Color.BLACK if i % 2 == 0 else Color.WHITE, 7.0)
