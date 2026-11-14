class_name Minimap
extends Control
## Mini-mapa da pista visto de cima, com a posição de cada kart (na cor do piloto).
## O kart do jogador tem seta, é maior e fica por cima dos outros.
## O traçado é desenhado uma vez só; cada kart é um PulseDot que só muda de posição
## e rotação a cada quadro.

var track: Track
var karts: Array[Kart] = []

var _points := PackedVector2Array()
var _scale := 1.0
var _offset := Vector2.ZERO
var _min := Vector2.ZERO
var _markers: Array[PulseDot] = []


## `focus` = o kart do dono deste mapa (fica por cima de todos). Os jogadores têm seta.
func setup(p_track: Track, p_karts: Array[Kart], focus: Kart = null) -> void:
	track = p_track
	karts = p_karts
	for marker in _markers:
		marker.queue_free()
	_markers.clear()
	for kart in karts:
		var marker := PulseDot.new()
		marker.color = kart.character.color if kart.character else UiKit.YELLOW
		if kart.is_player:
			marker.arrow = true
			marker.z_index = 2 if kart == focus else 1
		else:
			marker.core_radius = 4.5
			marker.ring_radius = 6.5
			marker.halo_alpha = 0.0
		add_child(marker)
		_markers.append(marker)
	_rebuild()
	if not resized.is_connected(_rebuild):
		resized.connect(_rebuild)


func _rebuild() -> void:
	if track == null or track.samples.is_empty() or size.x < 40.0 or size.y < 40.0:
		return
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for s in track.samples:
		min_p = min_p.min(Vector2(s.x, s.z))
		max_p = max_p.max(Vector2(s.x, s.z))
	var pad := 16.0
	var extent := max_p - min_p
	_scale = minf((size.x - pad * 2.0) / maxf(extent.x, 1.0), (size.y - pad * 2.0) / maxf(extent.y, 1.0))
	_min = min_p
	_offset = (size - extent * _scale) * 0.5
	_points = PackedVector2Array()
	for s in track.samples:
		_points.append(_to_map(Vector3(s.x, 0.0, s.z)))
	if not _points.is_empty():
		_points.append(_points[0])
	queue_redraw()


func _to_map(local_pos: Vector3) -> Vector2:
	return (Vector2(local_pos.x, local_pos.z) - _min) * _scale + _offset


func _process(_delta: float) -> void:
	for i in _markers.size():
		var kart := karts[i]
		var marker := _markers[i]
		marker.visible = is_instance_valid(kart) and _points.size() >= 2
		if not marker.visible:
			continue
		marker.position = _to_map(track.to_local(kart.global_position))
		if marker.arrow:
			var f := track.global_basis.inverse() * kart.get_forward()
			marker.rotation = Vector2(f.x, f.z).angle()


func _draw() -> void:
	if _points.size() < 2:
		return
	draw_polyline(UiKit.offset_points(_points, Vector2(0, 3)), Color(0, 0, 0, 0.3), 14.0, true)
	draw_polyline(_points, Color(0.04, 0.06, 0.16, 0.9), 14.0, true)
	draw_polyline(_points, Color(0.95, 0.96, 1.0, 0.98), 8.0, true)
	# Linha de largada quadriculada.
	var start := _points[0]
	var dir := (_points[1] - _points[0]).normalized()
	var normal := Vector2(-dir.y, dir.x)
	for i in 4:
		var a := start + normal * (-8.0 + i * 4.0)
		draw_line(a, a + normal * 4.0, Color.BLACK if i % 2 == 0 else Color.WHITE, 5.0)
