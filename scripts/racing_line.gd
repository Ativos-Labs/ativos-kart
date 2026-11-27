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
## Soma da curvatura das amostras antes de cada índice (n + 1 valores): dá a soma de
## qualquer trecho com duas leituras (turn_between).
var _curv_sum := PackedFloat64Array()
## Curvatura em módulo (max_curvature).
var _abs_curv := PackedFloat32Array()

## Trajetórias já calculadas (a pista não muda durante o jogo): chave -> RacingLine.
## Reiniciar a corrida ou voltar a uma pista não refaz a conta (~15 ms, ~60 na web).
static var _cache := {}


## `margin` = distância mínima (m) entre o meio do kart e a borda do asfalto.
static func build(p_track: Track, margin := 2.4) -> RacingLine:
	var n := p_track.samples.size()
	var key := "%s|%d|%.3f|%.3f|%.3f" % [p_track.track_id, n, p_track.length, p_track.road_width, margin]
	var cached: RacingLine = _cache.get(key)
	if cached:
		return cached._bound_to(p_track)
	var line := _compute(p_track, margin)
	_cache[key] = line
	return line._bound_to(p_track)


## Cópia que lê a pista `p_track` (as tabelas são as mesmas, só leitura).
func _bound_to(p_track: Track) -> RacingLine:
	var line := RacingLine.new()
	line.track = p_track
	line.lateral = lateral
	line.curvature = curvature
	line.limit = limit
	line._step = _step
	line._curv_sum = _curv_sum
	line._abs_curv = _abs_curv
	return line


static func _compute(p_track: Track, margin: float) -> RacingLine:
	var line := RacingLine.new()
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
		right[i] = Vector2(p_track.rights[i].x, p_track.rights[i].z).normalized()
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
	line._index_curvature()
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


## Tabelas para as consultas de trecho (chamadas a cada passo por cada adversário).
func _index_curvature() -> void:
	var n := curvature.size()
	_curv_sum.resize(n + 1)
	_abs_curv.resize(n)
	var acc := 0.0
	for i in n:
		_curv_sum[i] = acc
		acc += curvature[i]
		_abs_curv[i] = absf(curvature[i])
	_curv_sum[n] = acc


## Maior curvatura (em módulo) entre `from` e `from + span`, olhando a cada amostra
## (o mesmo que medir com curvature_at a cada `_step` metros, sem as contas de cada
## leitura).
func max_curvature(from: float, span: float) -> float:
	var n := _abs_curv.size()
	if n == 0:
		return 0.0
	var f := fposmod(from, track.length) / _step
	var i := int(f) % n
	var t := f - floorf(f)
	var count := int(span / _step) + 1
	var best := 0.0
	var a := _abs_curv[i]
	var ca := curvature[i]
	for k in count:
		var j := i + 1
		if j >= n:
			j -= n
		var cb := curvature[j]
		# |lerp| só precisa da conta quando os dois lados podem passar do melhor.
		if a > best or _abs_curv[j] > best:
			best = maxf(best, absf(lerpf(ca, cb, t)))
		i = j
		ca = cb
		a = _abs_curv[j]
	return best


## Quanto a trajetória vira (rad, positivo = direita) entre `from` e `from + span`:
## a soma da curvatura a cada `_step` metros (interpolada), vezes `_step`.
func turn_between(from: float, span: float) -> float:
	var n := curvature.size()
	if n == 0 or _curv_sum.size() != n + 1:
		return 0.0
	var count := ceili(span / _step)
	if count <= 0:
		return 0.0
	var f := fposmod(from, track.length) / _step
	var i := int(f) % n
	var t := f - floorf(f)
	# Cada leitura é lerp(c[i+k], c[i+k+1], t): somando, (1-t)·Σc[i..] + t·Σc[i+1..].
	return ((1.0 - t) * _range_sum(i, count) + t * _range_sum(i + 1, count)) * _step


## Soma de `count` amostras seguidas a partir de `first` (dando a volta na pista).
func _range_sum(first: int, count: int) -> float:
	var n := curvature.size()
	var laps := count / n
	var rest := count - laps * n
	var start := first % n
	var total := _curv_sum[n] * laps
	var end := start + rest
	if end <= n:
		total += _curv_sum[end] - _curv_sum[start]
	else:
		total += _curv_sum[n] - _curv_sum[start] + _curv_sum[end - n]
	return total
