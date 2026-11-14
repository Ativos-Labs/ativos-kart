class_name RacingLine
extends RefCounted
## Trajetória de corrida dos adversários: para cada amostra da pista, quanto o kart
## fica para o lado do meio (m, positivo = direita) para abrir as curvas — entra por
## fora, tangencia por dentro e sai por fora.
##
## É calculada uma vez por corrida "esticando" a linha do meio como um elástico
## preso dentro do asfalto: cada ponto vai para o meio dos vizinhos, do mais longe
## (curvas longas) para o mais perto (detalhes), sem passar do limite das zebras.

var track: Track
## Deslocamento lateral em cada amostra da pista (positivo = direita).
var lateral := PackedFloat32Array()
## Curvatura da trajetória em cada amostra (1/raio; positivo = curva para a direita).
var curvature := PackedFloat32Array()
## Quanto a trajetória pode se afastar do meio (m).
var limit := 0.0

var _step := 2.0


## `margin` = distância mínima (m) entre o meio do kart e a borda do asfalto.
static func build(p_track: Track, margin := 2.4) -> RacingLine:
	var line := RacingLine.new()
	line.track = p_track
	var n := p_track.samples.size()
	line.limit = maxf(p_track.road_width * 0.5 - margin, 0.0)
	var lat := PackedFloat32Array()
	lat.resize(n)
	if n < 16:
		line.lateral = lat
		line.curvature.resize(n)
		return line
	line._step = p_track.length / n
	# Trabalha no plano (x, z): pontes e subidas não mudam a trajetória.
	var center := PackedVector2Array()
	var right := PackedVector2Array()
	center.resize(n)
	right.resize(n)
	for i in n:
		center[i] = Vector2(p_track.samples[i].x, p_track.samples[i].z)
		right[i] = Vector2(p_track.rights[i].x, p_track.rights[i].z)
	var lim := line.limit
	for k: int in [18, 12, 7, 4, 2]:
		for _it in 36:
			for i in n:
				var a := (i - k + n) % n
				var b := (i + k) % n
				var mid := (center[a] + right[a] * lat[a] + center[b] + right[b] * lat[b]) * 0.5
				var target := (mid - center[i]).dot(right[i])
				lat[i] = clampf(lerpf(lat[i], target, 0.5), -lim, lim)
	line.lateral = lat
	line._compute_curvature(center, right)
	return line


func _compute_curvature(center: PackedVector2Array, right: PackedVector2Array) -> void:
	var n := lateral.size()
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		pts[i] = center[i] + right[i] * lateral[i]
	var dirs := PackedVector2Array()
	dirs.resize(n)
	for i in n:
		dirs[i] = (pts[(i + 1) % n] - pts[(i - 1 + n) % n]).normalized()
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		var a := (i - 2 + n) % n
		var b := (i + 2) % n
		var span := maxf(pts[a].distance_to(pts[b]), 0.01)
		# Virar para a direita = a direção gira para o lado de `right`.
		raw[i] = (dirs[b] - dirs[a]).dot(right[i]) / span
	curvature.resize(n)
	for i in n:
		var sum := 0.0
		for k in range(-3, 4):
			sum += raw[(i + k + n) % n]
		curvature[i] = sum / 7.0


func _sample(arr: PackedFloat32Array, dist: float) -> float:
	var n := arr.size()
	if n == 0:
		return 0.0
	var f := fposmod(dist, track.length) / _step
	var i := int(f) % n
	return lerpf(arr[i], arr[(i + 1) % n], f - floorf(f))


## Deslocamento lateral da trajetória numa distância da volta.
func lateral_at(dist: float) -> float:
	return _sample(lateral, dist)


## Curvatura da trajetória numa distância da volta (positivo = direita).
func curvature_at(dist: float) -> float:
	return _sample(curvature, dist)


## Maior curvatura (em módulo) entre `from` e `from + span`.
func max_curvature(from: float, span: float) -> float:
	var best := 0.0
	var d := 0.0
	while d <= span:
		best = maxf(best, absf(curvature_at(from + d)))
		d += _step
	return best


## Quanto a trajetória vira (rad, positivo = direita) entre `from` e `from + span`.
func turn_between(from: float, span: float) -> float:
	var total := 0.0
	var d := 0.0
	while d < span:
		total += curvature_at(from + d) * _step
		d += _step
	return total
