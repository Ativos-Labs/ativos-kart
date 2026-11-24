@tool
class_name TrackTerrain
extends RefCounted
## Terreno em volta da pista: plano perto do traçado, colinas e lagos mais longe e
## uma cadeia de montanhas no horizonte. Opcionais: colinas em degraus (mesas de
## deserto), mar em volta (ilha), rios cavando o chão e vão livre embaixo das pontes.
## Também responde a altura do chão e a distância até a pista em qualquer ponto
## (usado para pôr árvores, outdoors e balões no lugar certo).

## Tamanho (m) das células do mapa de distâncias até a pista e até os rios.
const CELL := 4.0
const RIVER_CELL := 6.0
## Quanto o mapa dos rios passa da área da pista (depois disso o rio some aos poucos).
const RIVER_MARGIN := 330.0

## Até essa distância do centro da pista o chão é plano (asfalto + grama + mureta).
var flat_distance := 16.0
## Largura da subida entre a parte plana e as colinas.
var rise_distance := 60.0
var hill_height := 13.0
var hill_bias := 2.0
var water_level := -1.4
var mountain_height := 190.0
## Distância do centro da pista onde as montanhas começam e onde chegam ao máximo.
var mountain_start := 300.0
var mountain_end := 650.0
## Altura dos degraus das colinas (0 = colinas lisas; ex.: 7 = mesas de deserto).
var terrace_step := 0.0
## Quanto do chão vira mar de dunas (0..1; veja Track.dune_cover). As dunas crescem
## longe da pista.
var dune_cover := 0.0
## Ilha: a partir dessa distância da pista o chão desce para o mar (0 = sem mar).
var sea_distance := 0.0
var sea_depth := 9.0
## Com mar: áreas que continuam terra firme mesmo longe da pista (o continente e o
## morro de uma ilha), Vector3(x, z, raio). A costa desce para o mar uns 45 m depois.
var land_spots := PackedVector3Array()
## Rios: largura do leito, profundidade abaixo da água e largura da margem.
var river_width := 22.0
var river_depth := 2.5
var river_bank := 12.0
## Quanto a margem alarga por metro de profundidade (0 = paredões retos).
var river_valley := 0.6
## Embaixo das pontes o chão fica pelo menos essa distância abaixo do asfalto.
var bridge_clearance := 2.4
## Meia largura ocupada pela pista (do centro até o lado de fora da mureta).
var deck_half := 14.0
## Centro (x, z) do traçado.
var center := Vector2.ZERO
## Meia largura da área do traçado (x, z).
var half_extent := Vector2.ZERO
## Áreas planas extras: Vector3(x, z, raio).
var flat_spots: Array[Vector3] = []

## Trechos especiais da pista (veja Track._setup_terrain_sections), uma entrada por
## amostra: fundo do lago/recife em volta (INF = nenhum), raio e força dele; força
## das dunas; 1 perto das bordas do vão de um vale.
var basin_floor := PackedFloat32Array()
var basin_radius := PackedFloat32Array()
var basin_strength := PackedFloat32Array()
var sand_strength := PackedFloat32Array()
## Trilha da mata (TrackSection SELVA): 0..1 em cada amostra; o chão em volta vira chão
## de mata (grama escura, folhas e terra) — vai para COLOR.a da malha.
var jungle_strength := PackedFloat32Array()
var gap_edge := PackedByteArray()
## Vales: {"line": PackedVector2Array (x, z), "half_top", "half_bed", "floor"}.
var valleys: Array[Dictionary] = []
## Expoente do perfil da encosta do vale (maior = paredão mais reto no alto).
var valley_steepness := 3.0

var _pts := PackedVector2Array()
var _ys := PackedFloat32Array()
var _mean_y := 0.0
## Pista toda na mesma altura (atalho: sem interpolar alturas).
var _flat := true
var _solid := Field.new()
var _bridge := Field.new()
## Para cada ponto do mapa das pontes: 2 = água embaixo, 1 = ponte comum.
var _bridge_kind := PackedByteArray()
var _river := Field.new()
var _basin := Field.new()
## Amostras no ar sobre os vales: só contam para a distância até a pista (enfeites longe
## do corredor do voo); o chão embaixo é o do vale.
var _gap := Field.new()
var _sand := Field.new()
var _jungle := Field.new()
## Chão de mata no último ponto de `_sample` (0..1).
var _jungle_f := 0.0
var _valley := Field.new()
## Vale de cada ponto de `_valley`.
var _valley_of := PackedInt32Array()
## Paredão do vale no último ponto calculado (0..1): vai para a cor do terreno (pedra).
var _cliff := 0.0
var _hills := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _coast := FastNoiseLite.new()


## Mapa de "ponto mais perto": para cada célula da grade guarda qual ponto da
## lista está mais perto (propagação em duas passadas, bem mais rápida que medir
## a distância para todos os pontos).
class Field:
	var cell := 4.0
	var origin := Vector2.ZERO
	var w := 0
	var h := 0
	var pts := PackedVector2Array()
	## Índice de cada ponto na lista original (amostras da pista).
	var ids := PackedInt32Array()
	var nearest := PackedInt32Array()

	func is_empty() -> bool:
		return pts.is_empty()

	func build(points: PackedVector2Array, point_ids: PackedInt32Array, min_p: Vector2, max_p: Vector2, p_cell: float) -> void:
		cell = p_cell
		pts = points
		ids = point_ids
		origin = min_p
		w = int(ceil((max_p.x - min_p.x) / cell)) + 1
		h = int(ceil((max_p.y - min_p.y) / cell)) + 1
		nearest.resize(w * h)
		nearest.fill(-1)
		if pts.is_empty():
			return
		var best := PackedFloat32Array()
		best.resize(w * h)
		best.fill(INF)
		for i in pts.size():
			var cx := int((pts[i].x - origin.x) / cell)
			var cz := int((pts[i].y - origin.y) / cell)
			if cx < 0 or cz < 0 or cx >= w or cz >= h:
				continue
			var k := cz * w + cx
			var d := _cell_center(cx, cz).distance_squared_to(pts[i])
			if d < best[k]:
				best[k] = d
				nearest[k] = i
		# Duas passadas: de cima para baixo olhando os vizinhos já vistos (esquerda e
		# linha de cima) e de baixo para cima olhando os do outro lado. As contas ficam
		# aqui dentro (uma chamada de função por célula custava quase metade do tempo).
		var fdx := PackedInt32Array([-1, -1, 0, 1])
		var fdz := PackedInt32Array([0, -1, -1, -1])
		for pass_i in 2:
			var dir := 1 if pass_i == 0 else -1
			var z0 := 0 if dir == 1 else h - 1
			var x0 := 0 if dir == 1 else w - 1
			for zi in h:
				var cz := z0 + zi * dir
				var cy := origin.y + (cz + 0.5) * cell
				for xi in w:
					var cx := x0 + xi * dir
					var k := cz * w + cx
					var c := Vector2(origin.x + (cx + 0.5) * cell, cy)
					var bk := best[k]
					var bi := nearest[k]
					for o in 4:
						var nx := cx + fdx[o] * dir
						var nz := cz + fdz[o] * dir
						if nx < 0 or nz < 0 or nx >= w or nz >= h:
							continue
						var i := nearest[nz * w + nx]
						if i < 0:
							continue
						var d := c.distance_squared_to(pts[i])
						if d < bk:
							# Lido de volta do array (32 bits), como antes: dá o mesmo vizinho.
							best[k] = d
							bk = best[k]
							bi = i
					nearest[k] = bi

	## Índice (em `pts`) do ponto mais perto, ou -1 fora da grade.
	func find(x: float, z: float) -> int:
		var fx := (x - origin.x) / cell
		var fz := (z - origin.y) / cell
		var cx := int(floor(fx))
		var cz := int(floor(fz))
		if cx < 0 or cz < 0 or cx >= w or cz >= h:
			return -1
		# Confere a célula e as vizinhas mais próximas do ponto (sem montar lista: é
		# chamado de 1 a 3 vezes por vértice do terreno).
		var ox := cx + (1 if fx - cx > 0.5 else -1)
		var oz := cz + (1 if fz - cz > 0.5 else -1)
		var p := Vector2(x, z)
		var best_i := nearest[cz * w + cx]
		var best := p.distance_squared_to(pts[best_i]) if best_i >= 0 else INF
		var x_ok := ox >= 0 and ox < w
		var z_ok := oz >= 0 and oz < h
		if x_ok:
			var i := nearest[cz * w + ox]
			if i >= 0:
				var d := p.distance_squared_to(pts[i])
				if d < best:
					best = d
					best_i = i
		if z_ok:
			var i := nearest[oz * w + cx]
			if i >= 0:
				var d := p.distance_squared_to(pts[i])
				if d < best:
					best = d
					best_i = i
			if x_ok:
				i = nearest[oz * w + ox]
				if i >= 0 and p.distance_squared_to(pts[i]) < best:
					best_i = i
		return best_i

	## Distância (m) do ponto até a borda da grade (negativa fora dela).
	func inside_margin(x: float, z: float) -> float:
		var lx := x - origin.x
		var lz := z - origin.y
		return minf(minf(lx, w * cell - lx), minf(lz, h * cell - lz))

	func _cell_center(cx: int, cz: int) -> Vector2:
		return origin + Vector2(cx + 0.5, cz + 0.5) * cell


## `bridge_mask[i]` = true nas amostras que ficam em cima de ponte (o chão não
## segue essas amostras). `rivers` = linhas centrais dos rios (x, z).
func setup(samples: PackedVector3Array, seed_value: int, bridge_mask := PackedByteArray(),
		rivers: Array[PackedVector2Array] = [], margin := 90.0) -> void:
	_hills.seed = seed_value
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.0075
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 4
	_ridges.seed = seed_value + 17
	_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridges.frequency = 0.0045
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 4
	_coast.seed = seed_value + 31
	_coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast.frequency = 0.02
	_coast.fractal_octaves = 2

	var count := samples.size()
	_pts.resize(count)
	_ys.resize(count)
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var sum_y := 0.0
	var solid_pts := PackedVector2Array()
	var solid_ids := PackedInt32Array()
	var bridge_pts := PackedVector2Array()
	var bridge_ids := PackedInt32Array()
	var gap_pts := PackedVector2Array()
	var gap_ids := PackedInt32Array()
	for i in count:
		var s := samples[i]
		_pts[i] = Vector2(s.x, s.z)
		_ys[i] = s.y
		min_p = min_p.min(_pts[i])
		max_p = max_p.max(_pts[i])
		var on_bridge := i < bridge_mask.size() and bridge_mask[i] != 0
		if on_bridge and bridge_mask[i] == 3:
			gap_pts.append(_pts[i])
			gap_ids.append(i)
		elif on_bridge:
			bridge_pts.append(_pts[i])
			bridge_ids.append(i)
			_bridge_kind.append(bridge_mask[i])
		else:
			solid_pts.append(_pts[i])
			solid_ids.append(i)
			sum_y += s.y
	_mean_y = sum_y / maxf(solid_pts.size(), 1)
	for y in _ys:
		if absf(y - _ys[0]) > 0.001:
			_flat = false
			break
	center = (min_p + max_p) * 0.5
	half_extent = (max_p - min_p) * 0.5
	var lo := min_p - Vector2(margin, margin)
	var hi := max_p + Vector2(margin, margin)
	_solid.build(solid_pts, solid_ids, lo, hi, CELL)
	if not bridge_pts.is_empty():
		_bridge.build(bridge_pts, bridge_ids, lo, hi, CELL)
	if not gap_pts.is_empty():
		var g_min := Vector2(INF, INF)
		var g_max := Vector2(-INF, -INF)
		for p in gap_pts:
			g_min = g_min.min(p)
			g_max = g_max.max(p)
		_gap.build(gap_pts, gap_ids, g_min - Vector2.ONE * 90.0, g_max + Vector2.ONE * 90.0, RIVER_CELL)

	# Rios: pontos a cada ~3 m ao longo das linhas.
	var river_pts := PackedVector2Array()
	for line in rivers:
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var steps := maxi(1, int(a.distance_to(b) / 3.0))
			for s in steps:
				river_pts.append(a.lerp(b, float(s) / steps))
		if line.size() > 0:
			river_pts.append(line[line.size() - 1])
	if not river_pts.is_empty():
		var r_ids := PackedInt32Array()
		r_ids.resize(river_pts.size())
		_river.build(river_pts, r_ids, min_p - Vector2.ONE * RIVER_MARGIN, max_p + Vector2.ONE * RIVER_MARGIN, RIVER_CELL)

	# Trechos especiais: amostras com lago/recife em volta e com dunas.
	var basin_pts := PackedVector2Array()
	var basin_ids := PackedInt32Array()
	var sand_pts := PackedVector2Array()
	var sand_ids := PackedInt32Array()
	var jungle_pts := PackedVector2Array()
	var jungle_ids := PackedInt32Array()
	for i in count:
		if i < jungle_strength.size() and jungle_strength[i] > 0.0:
			jungle_pts.append(_pts[i])
			jungle_ids.append(i)
		if i < basin_strength.size() and basin_strength[i] > 0.0:
			basin_pts.append(_pts[i])
			basin_ids.append(i)
		if i < sand_strength.size() and sand_strength[i] > 0.0:
			sand_pts.append(_pts[i])
			sand_ids.append(i)
	if not basin_pts.is_empty():
		var b_min := Vector2(INF, INF)
		var b_max := Vector2(-INF, -INF)
		for p in basin_pts:
			b_min = b_min.min(p)
			b_max = b_max.max(p)
		var reach := 0.0
		for i in basin_ids:
			reach = maxf(reach, basin_radius[i])
		_basin.build(basin_pts, basin_ids, b_min - Vector2.ONE * (reach + 30.0), b_max + Vector2.ONE * (reach + 30.0), RIVER_CELL)
	if not sand_pts.is_empty():
		_sand.build(sand_pts, sand_ids, lo - Vector2.ONE * 120.0, hi + Vector2.ONE * 120.0, RIVER_CELL)
	if not jungle_pts.is_empty():
		_jungle.build(jungle_pts, jungle_ids, lo - Vector2.ONE * 60.0, hi + Vector2.ONE * 60.0, RIVER_CELL)
	# Vales: pontos a cada ~3 m ao longo das linhas do meio.
	var valley_pts := PackedVector2Array()
	_valley_of = PackedInt32Array()
	var v_min := Vector2(INF, INF)
	var v_max := Vector2(-INF, -INF)
	for vi in valleys.size():
		var line: PackedVector2Array = valleys[vi].line
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var steps := maxi(1, int(a.distance_to(b) / 3.0))
			for s in steps:
				var p := a.lerp(b, float(s) / steps)
				valley_pts.append(p)
				_valley_of.append(vi)
				v_min = v_min.min(p)
				v_max = v_max.max(p)
		var half: float = valleys[vi].half_top + valleys[vi].get("plateau", 0.0)
		v_min -= Vector2.ONE * (half + 80.0)
		v_max += Vector2.ONE * (half + 80.0)
	if not valley_pts.is_empty():
		var v_ids := PackedInt32Array()
		v_ids.resize(valley_pts.size())
		_valley.build(valley_pts, v_ids, v_min, v_max, RIVER_CELL)


## Distância (no plano) até o centro da pista e altura do chão da pista ali perto
## (sem contar as pontes). Longe da pista (fora do mapa) devolve uma distância grande.
func nearest_info(x: float, z: float) -> Vector2:
	var k := _solid.find(x, z)
	if k < 0:
		var far := maxf(absf(x - center.x) - half_extent.x, absf(z - center.y) - half_extent.y)
		return Vector2(maxf(far, 120.0), _mean_y)
	var p := Vector2(x, z)
	if _flat:
		return Vector2(p.distance_to(_solid.pts[k]), _ys[0])
	return Vector2(p.distance_to(_solid.pts[k]), _interp_y(_solid.ids[k], p))


## Índice da amostra da pista (fora das pontes) mais perto do ponto, ou -1.
func nearest_track_index(x: float, z: float) -> int:
	var k := _solid.find(x, z)
	return _solid.ids[k] if k >= 0 else -1


## Distância até a pista, contando também os trechos em cima de ponte.
func distance_to_track(x: float, z: float) -> float:
	var d := nearest_info(x, z).x
	if not _bridge.is_empty():
		var k := _bridge.find(x, z)
		if k >= 0:
			d = minf(d, Vector2(x, z).distance_to(_bridge.pts[k]))
	if not _gap.is_empty():
		var k := _gap.find(x, z)
		if k >= 0:
			d = minf(d, Vector2(x, z).distance_to(_gap.pts[k]))
	return d


func height_at(x: float, z: float) -> float:
	return _sample(x, z).x


## 0..1: quanto o chão ali é chão de mata (perto da trilha da mata).
func jungle_at(x: float, z: float) -> float:
	_sample(x, z)
	return _jungle_f


## 0..1: quanto o chão ali é de dunas de areia (perto do trecho de areia).
func sand_at(x: float, z: float) -> float:
	return _sample(x, z).z


## 1 perto da pista (grama aparada em listras), 0 longe.
func mow_factor(distance: float) -> float:
	return 1.0 - smoothstep(flat_distance - 2.0, flat_distance + 16.0, distance)


## (altura do chão, fator de grama aparada, dunas, paredão do vale) num ponto.
func _sample(x: float, z: float) -> Vector4:
	_cliff = 0.0
	_jungle_f = 0.0
	if not _jungle.is_empty():
		var kj := _jungle.find(x, z)
		if kj >= 0:
			_jungle_f = jungle_strength[_jungle.ids[kj]] * (1.0 - smoothstep(55.0, 110.0, Vector2(x, z).distance_to(_jungle.pts[kj])))
	var k := _solid.find(x, z)
	var d: float
	var road_y: float
	var sid := -1
	if k < 0:
		var far := maxf(absf(x - center.x) - half_extent.x, absf(z - center.y) - half_extent.y)
		d = maxf(far, 120.0)
		road_y = _mean_y
	else:
		var p := Vector2(x, z)
		sid = _solid.ids[k]
		d = p.distance_to(_solid.pts[k])
		road_y = _ys[0] if _flat else _interp_y(sid, p)
	# Longe da pista a altura de base vai para a média (pistas com subidas não
	# deixam degraus na borda do mapa).
	var base := road_y if _flat else lerpf(road_y, _mean_y, smoothstep(40.0, 88.0, d))
	var m := smoothstep(flat_distance, flat_distance + rise_distance, d)
	for spot in flat_spots:
		m *= smoothstep(spot.z, spot.z + 40.0, Vector2(x - spot.x, z - spot.y).length())
	var h := base - 0.03
	var sand := 0.0
	if not _sand.is_empty():
		var ks := _sand.find(x, z)
		if ks >= 0:
			sand = sand_strength[_sand.ids[ks]] * (1.0 - smoothstep(70.0, 190.0, Vector2(x, z).distance_to(_sand.pts[ks])))
	# As montanhas do horizonte continuam de pedra (sem o mar de dunas).
	var ring := smoothstep(mountain_start, mountain_end, Vector2(x, z).distance_to(center))
	sand = maxf(sand, dune_cover * (1.0 - ring))
	if m > 0.0:
		var relief := 0.0
		# Só dunas (sem montanha): o relevo comum seria jogado fora, nem calcula.
		if sand < 1.0 or ring > 0.0:
			relief = _hills.get_noise_2d(x, z) * hill_height + hill_bias
			if ring > 0.0:
				relief += ring * mountain_height * (0.3 + 0.7 * clampf(_ridges.get_noise_2d(x, z) * 0.6 + 0.5, 0.0, 1.2))
			if terrace_step > 0.0:
				relief = _terrace(relief)
		if sand > 0.0:
			# Perto das dunas da pista o relevo vira um mar de dunas (sem mesas).
			relief = lerpf(relief, _dune_relief(x, z, d) + ring * relief, sand)
		h += m * relief
	if sea_distance > 0.0:
		var coast := _coast.get_noise_2d(x, z) * 14.0
		var sea := smoothstep(sea_distance, sea_distance + 42.0, d + coast)
		for spot in land_spots:
			if sea <= 0.0:
				break
			sea *= smoothstep(spot.z, spot.z + 45.0, Vector2(x - spot.x, z - spot.y).length() + coast)
		h -= sea_depth * sea
	if not _basin.is_empty():
		h = _carve_basin(x, z, h, d, sid)
	if not _river.is_empty():
		h = _carve_river(x, z, h, d)
	if not _valley.is_empty():
		h = _carve_valley(x, z, h, d, sid)
	if not _bridge.is_empty():
		h = _under_bridge(x, z, h, d)
	return Vector4(h, mow_factor(d), sand, _cliff)


## Dunas: cristas compridas atravessadas ao vento, com a face de trás suave e a da
## frente mais íngreme, e a altura variando aos poucos.
func _dune_relief(x: float, z: float, d_track := 0.0) -> float:
	# No mar de dunas (dune_cover) elas ficam mais altas e espaçadas longe da pista.
	var grow := dune_cover * smoothstep(60.0, 320.0, d_track)
	# Entorta as cristas (ruído de 2 oitavas: é chamado em todo vértice do mar de dunas).
	var warp := _coast.get_noise_2d(x * 0.26 + 300.0, z * 0.26) * 30.0
	var u := (x * 0.8 + z * 0.6 + warp) / (42.0 * (1.0 + grow * 0.8))
	var ph := u - floorf(u)
	var ridge := smoothstep(0.0, 0.72, ph) if ph < 0.72 else 1.0 - smoothstep(0.72, 1.0, ph)
	var amp := (6.0 + _coast.get_noise_2d(x * 0.25, z * 0.25) * 4.0) * (1.0 + grow * 1.6)
	return ridge * amp + 1.2


## Lago (ou recife) em volta do mergulho e do lago congelado: o chão desce até o fundo
## num raio em volta do trecho (outros trechos da pista ali perto continuam firmes).
func _carve_basin(x: float, z: float, h: float, d_track: float, sid: int) -> float:
	var kb := _basin.find(x, z)
	if kb < 0:
		return h
	var id := _basin.ids[kb]
	var r := basin_radius[id]
	var db := Vector2(x, z).distance_to(_basin.pts[kb])
	if db >= r:
		return h
	var carved := lerpf(basin_floor[id], h, smoothstep(r * 0.55, r, db + _coast.get_noise_2d(x, z) * 10.0))
	var protect := 1.0
	if sid >= 0 and (sid >= basin_strength.size() or basin_strength[sid] <= 0.0):
		protect = smoothstep(flat_distance - 2.0, flat_distance + 12.0, d_track)
	return lerpf(h, minf(h, carved), basin_strength[id] * protect)


## Vale cavado ao longo da linha "Vale": um planalto em volta (na altura `rim`, a da
## beira mais alta da pista) cortado por uma ravina — fundo estreito (o leito, com água
## se ficar abaixo do nível dela), encosta baixa e paredão até o alto. Na pista ao lado
## o chão fica firme, menos na beira do vão (o penhasco começa onde o asfalto acaba).
func _carve_valley(x: float, z: float, h: float, d_track: float, sid: int) -> float:
	var kv := _valley.find(x, z)
	if kv < 0:
		return h
	var v: Dictionary = valleys[_valley_of[kv]]
	var half_top: float = v.half_top
	var shelf: float = v.plateau
	var raw := Vector2(x, z).distance_to(_valley.pts[kv])
	if raw >= half_top + shelf + 7.0:
		return h
	var vd := raw + _coast.get_noise_2d(x * 0.6, z * 0.6) * 7.0
	if vd >= half_top + shelf:
		return h
	var fade := smoothstep(0.0, 60.0, _valley.inside_margin(x, z))
	# Planalto em volta da ravina (longe da pista: perto dela vale o aterro da pista).
	var rim: float = v.rim + _hills.get_noise_2d(x * 1.7, z * 1.7) * 2.5
	var lift := smoothstep(half_top + shelf, half_top + 12.0, vd) * smoothstep(flat_distance + 2.0, flat_distance + 22.0, d_track) * fade
	var hp := lerpf(h, maxf(h, rim), lift)
	if vd >= half_top:
		return hp
	var half_bed: float = v.half_bed
	var t := clampf((vd - half_bed) / maxf(half_top - half_bed, 1.0), 0.0, 1.0)
	# Leito quase plano, encosta baixa e o paredão no alto.
	var prof := 0.14 * smoothstep(0.0, 0.5, t) + 0.86 * smoothstep(0.5, 0.88, t)
	if terrace_step > 0.0:
		# Paredões em degraus (cânion).
		var steps := 4.0
		var st := floorf(prof * steps)
		prof = lerpf(prof, (st + smoothstep(0.55, 0.9, prof * steps - st)) / steps, 0.7)
	var floor_y: float = v.floor
	var carved := lerpf(floor_y, maxf(hp, floor_y), prof)
	var reach := 1.0 if sid >= 0 and sid < gap_edge.size() and gap_edge[sid] != 0 else flat_distance - 2.0
	var protect := smoothstep(reach, reach + 8.0, d_track)
	_cliff = smoothstep(0.42, 0.62, t) * (1.0 - smoothstep(0.9, 1.0, t)) * protect * fade
	return lerpf(hp, minf(hp, carved), protect * fade)


## Degraus: patamares planos e paredões entre eles (mesas e cânions).
func _terrace(h: float) -> float:
	var k := h / terrace_step
	var f := floorf(k)
	return (f + smoothstep(0.5, 0.85, k - f)) * terrace_step


## Leito do rio: fundo abaixo da água e margens subindo até o chão em volta.
## Não cava perto da pista (as cabeceiras das pontes ficam firmes).
func _carve_river(x: float, z: float, h: float, d_track: float) -> float:
	var k := _river.find(x, z)
	if k < 0:
		return h
	var rd := Vector2(x, z).distance_to(_river.pts[k])
	var half := river_width * 0.5
	var bed := water_level - river_depth
	# Onde o chão é alto o vale abre (encostas em "V"); com river_valley = 0 as
	# paredes ficam retas como num cânion.
	var bank := river_bank + maxf(0.0, h - bed) * river_valley
	if rd > half + bank:
		return h
	var carved := lerpf(bed, h, smoothstep(half * 0.45, half + bank, rd))
	var protect := smoothstep(flat_distance - 2.0, flat_distance + 10.0, d_track)
	var fade := smoothstep(0.0, 70.0, _river.inside_margin(x, z))
	return lerpf(h, minf(h, carved), protect * fade)


## Embaixo das pontes o chão fica abaixo do tabuleiro. Nas pontes com água embaixo
## ele afunda até o fundo do mar/lagoa (menos perto da pista, onde as cabeceiras
## ficam firmes).
func _under_bridge(x: float, z: float, h: float, d_track: float) -> float:
	var k := _bridge.find(x, z)
	if k < 0:
		return h
	# Vão de vale: sem tabuleiro, o vale já cavou o chão.
	if _bridge_kind[k] == 3:
		return h
	var p := Vector2(x, z)
	var bd := p.distance_to(_bridge.pts[k])
	var limit := deck_half + 2.0
	if _bridge_kind[k] == 2:
		var reach := limit + 34.0
		if bd < reach:
			var floor_y := water_level - 3.0 + smoothstep(limit, reach, bd) * 40.0
			var protect := smoothstep(flat_distance - 2.0, flat_distance + 12.0, d_track)
			h = lerpf(h, minf(h, floor_y), protect)
	if bd > limit + 26.0:
		return h
	var cap := _interp_y(_bridge.ids[k], p) - bridge_clearance + smoothstep(limit, limit + 26.0, bd) * 120.0
	return minf(h, cap)


## Altura da pista perto da amostra `i`, interpolando com a vizinha do lado de `p`.
func _interp_y(i: int, p: Vector2) -> float:
	var n := _pts.size()
	var c := _pts[i]
	var j := (i + 1) % n
	var seg := _pts[j] - c
	var t := (p - c).dot(seg) / maxf(seg.length_squared(), 0.0001)
	if t < 0.0:
		j = (i - 1 + n) % n
		seg = _pts[j] - c
		t = (p - c).dot(seg) / maxf(seg.length_squared(), 0.0001)
	return lerpf(_ys[i], _ys[j], clampf(t, 0.0, 1.0))


# --- Malha ------------------------------------------------------------------------

## Grade com células pequenas perto da pista e cada vez maiores para fora.
## `resolution` = células em x e z; `inner_half` = meia largura (x, z) da parte fina.
func build_mesh(resolution: Vector2i, inner_half: Vector2, outer_half: float, material: Material) -> ArrayMesh:
	var nx := maxi(resolution.x, 8)
	var nz := maxi(resolution.y, 8)
	var xs := PackedFloat32Array()
	for i in nx + 1:
		xs.append(_warp(float(i) / nx * 2.0 - 1.0, inner_half.x, outer_half))
	var zs := PackedFloat32Array()
	for j in nz + 1:
		zs.append(_warp(float(j) / nz * 2.0 - 1.0, inner_half.y, outer_half))
	var row := nx + 1
	var rows := nz + 1
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(row * rows)
	colors.resize(row * rows)
	for j in rows:
		for i in row:
			var x := center.x + xs[i]
			var z := center.y + zs[j]
			var s := _sample(x, z)
			verts[j * row + i] = Vector3(x, s.x, z)
			colors[j * row + i] = Color(s.y, s.z, s.w, _jungle_f)
	var normals := PackedVector3Array()
	normals.resize(row * rows)
	for j in rows:
		for i in row:
			var tx := verts[j * row + mini(i + 1, nx)] - verts[j * row + maxi(i - 1, 0)]
			var tz := verts[mini(j + 1, nz) * row + i] - verts[maxi(j - 1, 0) * row + i]
			normals[j * row + i] = tz.cross(tx).normalized()
	var indices := PackedInt32Array()
	indices.resize(nx * nz * 6)
	var k := 0
	for j in nz:
		for i in nx:
			var a := j * row + i
			var b := a + 1
			var c := a + row
			var d := c + 1
			# Ordem dos vértices: Godot desenha a face da frente no sentido horário.
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


static func _warp(u: float, inner_half: float, outer_half: float) -> float:
	var a := absf(u)
	var split := 0.72
	var slope := inner_half / split
	var r := a * slope
	if a > split:
		var t := (a - split) / (1.0 - split)
		var extra := outer_half - inner_half - slope * (1.0 - split)
		r = inner_half + slope * (a - split) + extra * t * t
	return signf(u) * r
