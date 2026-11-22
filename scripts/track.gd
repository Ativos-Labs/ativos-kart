@tool
class_name Track
extends Node3D
## Gera a pista inteira (asfalto, zebras, muretas com placas, terreno com lagos e
## montanhas, largada, turbos e decoração) a partir da curva do filho "Tracado" (Path3D).
## No editor: selecione "Tracado" e arraste os pontos da curva — a pista é
## reconstruída sozinha. Também dá para usar o botão "Reconstruir pista".

const ROAD_SHADER := preload("res://shaders/road.gdshader")
const CURB_SHADER := preload("res://shaders/curb.gdshader")
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const WALL_SHADER := preload("res://shaders/wall.gdshader")
const BOOST_SHADER := preload("res://shaders/boost_pad.gdshader")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")
const WORDMARK := preload("res://assets/logos/ativos_marca.png")
const WORDMARK_DARK := preload("res://assets/logos/ativos_marca_branca.png")

## Distância máxima entre as caixas de item de uma fileira (m): com a área de toque delas
## (ItemBox.TOUCH_SIZE), a fileira não deixa vão por onde um kart de 0,7 m passe sem pegar
## nenhuma.
const ITEM_BOX_SPACING := 1.7

@export var track_id := "circuito_ativos"
@export var track_name := "Circuito Ativos"

@export_group("Cenário")
## Cores do chão, da água e da vegetação e as decorações típicas de cada lugar
## (Campo: árvores e flores; Praia: coqueiros, guarda-sóis, veleiros e farol;
## Deserto: cactos, pedras, caixa-d'água e letreiro; Neve: pinheiros nevados,
## bonecos de neve, chalés e lago congelado). Todos usam as logos da Ativos.
@export var scenery := TrackTheme.Scenery.CAMPO:
	set(value):
		scenery = value
		_queue_rebuild()

@export_group("Pontes")
## Trechos da pista que viram ponte (veja track_bridge.gd). A pista sobe sozinha
## com rampas; o chão embaixo fica livre para rio, mar ou outro trecho da pista.
@export var bridges: Array[TrackBridge] = []:
	set(value):
		bridges = value
		_watch_bridges()
		_queue_rebuild()

@export_group("Rampas")
## Rampas de pulo (veja track_ramp.gd): o kart sai do chão na borda, faz um arco e
## cai de volta na pista. Ponha em retas com uns 45 m livres depois da borda.
@export var ramps: Array[TrackRamp] = []:
	set(value):
		ramps = value
		_watch_bridges()
		_queue_rebuild()

@export_group("Caixas de item")
## Fileiras de caixas de item ao longo da volta (0 = largada, 0.5 = metade).
@export var item_rows := PackedFloat32Array():
	set(value):
		item_rows = value
		_queue_rebuild()
## Caixas em cada fileira, espalhadas na largura do asfalto.
@export_range(1, 6) var item_boxes_per_row := 6:
	set(value):
		item_boxes_per_row = value
		_queue_rebuild()

@export_group("Moedas")
## Fileiras de moedas Ativos (cada moeda pega aumenta um pouco a velocidade máxima).
## Cada item: x = meio da fileira (fração da volta), y = deslocamento lateral (m,
## + = direita, até ~±5,5 dentro das zebras), z = quantidade de moedas.
@export var coin_lines := PackedVector3Array():
	set(value):
		coin_lines = value
		_queue_rebuild()
## Distância entre as moedas de uma fileira (m).
@export var coin_spacing := 4.0:
	set(value):
		coin_spacing = value
		_queue_rebuild()
## Três moedas no ar, no arco do pulo de cada rampa (pega quem chega rápido nela).
@export var coins_on_ramps := true:
	set(value):
		coins_on_ramps = value
		_queue_rebuild()

@export_group("Obstáculos")
## Trechos com obstáculos que se mexem (frações da volta). O tipo vem do cenário:
## pneus gigantes quicando (Campo), ondas do mar (Praia), fardos de feno (Deserto) e
## bolas de neve (Neve). Ponha em trechos sem ponte, rampa nem caixas, com uns 30 m
## de chão livre dos dois lados da pista (veja track_obstacles.gd).
@export var obstacle_zones := PackedFloat32Array():
	set(value):
		obstacle_zones = value
		_queue_rebuild()

@export_group("Rios")
## Rios: crie nós Path3D filhos com nome começando por "Rio" e desenhe a linha
## do rio. O chão é cavado ao longo dela (com água no fundo). Passe os rios por
## baixo das pontes — eles não cavam perto da pista.
@export var river_width := 22.0:
	set(value):
		river_width = value
		_queue_rebuild()
## Profundidade do leito abaixo do nível da água.
@export var river_depth := 2.5:
	set(value):
		river_depth = value
		_queue_rebuild()
## Largura da margem (menor = paredões mais íngremes, como num cânion).
@export var river_bank := 12.0:
	set(value):
		river_bank = value
		_queue_rebuild()
## Quanto a margem alarga onde o chão em volta é alto (0 = paredões retos de
## cânion; 1 ou mais = vale aberto de montanha).
@export var river_valley := 0.6:
	set(value):
		river_valley = value
		_queue_rebuild()

@export_group("Formato")
## Largura do asfalto em metros.
@export var road_width := 15.0:
	set(value):
		road_width = value
		_queue_rebuild()
## Faixa de grama entre o asfalto e a mureta.
@export var shoulder_width := 5.0:
	set(value):
		shoulder_width = value
		_queue_rebuild()
@export var wall_height := 1.1:
	set(value):
		wall_height = value
		_queue_rebuild()
@export var wall_thickness := 0.8:
	set(value):
		wall_thickness = value
		_queue_rebuild()
## Distância entre amostras da curva (menor = mais suave, mais pesado).
@export var sample_spacing := 2.0:
	set(value):
		sample_spacing = maxf(value, 0.5)
		_queue_rebuild()

@export_group("Zebras")
## Largura das zebras nas retas.
@export var curb_min_width := 0.6:
	set(value):
		curb_min_width = value
		_queue_rebuild()
## Largura das zebras do lado de dentro das curvas fechadas.
@export var curb_inner_width := 1.9:
	set(value):
		curb_inner_width = value
		_queue_rebuild()
## Largura das zebras do lado de fora das curvas fechadas.
@export var curb_outer_width := 1.2:
	set(value):
		curb_outer_width = value
		_queue_rebuild()

@export_group("Turbos e decoração")
## Posição das placas de turbo ao longo da volta (0 = largada, 0.5 = metade).
@export var boost_pads := PackedFloat32Array([0.03, 0.475, 0.66]):
	set(value):
		boost_pads = value
		_queue_rebuild()
@export var tree_count := 650:
	set(value):
		tree_count = value
		_queue_rebuild()
@export var grass_count := 9000:
	set(value):
		grass_count = value
		_queue_rebuild()
## Quantidade de canteiros de flores (cada um com ~20 flores).
@export var flower_count := 160:
	set(value):
		flower_count = value
		_queue_rebuild()
@export var balloon_count := 6:
	set(value):
		balloon_count = value
		_queue_rebuild()
@export var show_blimp := true:
	set(value):
		show_blimp = value
		_queue_rebuild()
@export var decoration_seed := 7:
	set(value):
		decoration_seed = value
		_queue_rebuild()

@export_group("Paisagem")
## Altura da água dos lagos (o chão perto da pista fica em 0).
@export var water_level := -1.4:
	set(value):
		water_level = value
		_queue_rebuild()
@export var hill_height := 13.0:
	set(value):
		hill_height = value
		_queue_rebuild()
@export var mountain_height := 190.0:
	set(value):
		mountain_height = value
		_queue_rebuild()
@export var hill_bias := 2.0:
	set(value):
		hill_bias = value
		_queue_rebuild()
## Colinas em degraus (0 = lisas). Ex.: 7 = mesas e paredões de deserto.
@export var terrace_step := 0.0:
	set(value):
		terrace_step = value
		_queue_rebuild()
## Ilha: a partir dessa distância da pista o chão desce para o mar (0 = sem mar).
@export var sea_distance := 0.0:
	set(value):
		sea_distance = value
		_queue_rebuild()

@export_tool_button("Reconstruir pista", "Reload") var rebuild_button := rebuild

## Sem colisão a pista é só o visual. Assim ela pode ser gerada numa thread, fora da
## árvore de cena (`build_geometry`): o servidor de física não pode ser usado fora da
## thread principal.
var with_collision := true

## Pontos amostrados no centro da pista (espaço local).
var samples := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()
var distances := PackedFloat32Array()
## Curvatura (1/raio) em cada amostra; positivo = curva para a direita.
var curvature := PackedFloat32Array()
## Comprimento de uma volta em metros.
var length := 0.0
## Terreno em volta da pista (altura do chão e distância até o traçado).
var terrain: TrackTerrain
## Amostras em cima de ponte: 1 = ponte, 2 = ponte com água embaixo (0 = chão).
var bridge_mask := PackedByteArray()
## Trechos de ponte: {"bridge": TrackBridge, "from": índice, "to": índice}.
var bridge_spans: Array[Dictionary] = []
## Moedas da pista (null se não tiver).
var coins: TrackCoins
## Obstáculos que se mexem (null se a pista não tiver).
var obstacles: TrackObstacles

var _generated: Node3D
var _rebuild_queued := false

## Terreno da última pista gerada no jogo (o objeto TrackTerrain e a malha do chão):
## reiniciar a corrida, ou voltar a ela depois de trocar de kart, não refaz o terreno,
## a parte mais pesada da carga (0,1 a 0,4 s no desktop, ~1 s na web). Guarda só um,
## para não segurar memória; no editor não guarda (a pista muda a toda hora).
static var _terrain_cache := {}


func _ready() -> void:
	var path := _get_path()
	if path and path.curve and not path.curve.changed.is_connected(_queue_rebuild):
		path.curve.changed.connect(_queue_rebuild)
	for river in _river_paths():
		if not river.curve.changed.is_connected(_queue_rebuild):
			river.curve.changed.connect(_queue_rebuild)
	_watch_bridges()
	# Pista gerada antes de entrar na árvore (`build_geometry`) não precisa gerar de novo.
	if not is_instance_valid(_generated):
		rebuild()


## No editor, mexer numa ponte ou rampa no Inspetor refaz a pista.
func _watch_bridges() -> void:
	for b in bridges:
		if b and not b.changed.is_connected(_queue_rebuild):
			b.changed.connect(_queue_rebuild)
	for r in ramps:
		if r and not r.changed.is_connected(_queue_rebuild):
			r.changed.connect(_queue_rebuild)


func is_bridge(index: int) -> bool:
	return index >= 0 and index < bridge_mask.size() and bridge_mask[index] != 0


func _river_paths() -> Array[Path3D]:
	var paths: Array[Path3D] = []
	for child in get_children():
		if child is Path3D and String(child.name).begins_with("Rio") and child.curve and child.curve.point_count >= 2:
			paths.append(child)
	return paths


## Linhas centrais dos rios (x, z), em pontos a cada ~4 m.
func _river_lines() -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	for river in _river_paths():
		var curve := river.curve
		var total := curve.get_baked_length()
		var steps := maxi(2, int(total / 4.0))
		var line := PackedVector2Array()
		for i in steps + 1:
			var p := river.transform * curve.sample_baked(total * i / steps)
			line.append(Vector2(p.x, p.z))
		lines.append(line)
	return lines


func _get_path() -> Path3D:
	return get_node_or_null("Tracado") as Path3D


func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_deferred_rebuild.call_deferred()


func _deferred_rebuild() -> void:
	_rebuild_queued = false
	rebuild()


func rebuild() -> void:
	prepare_layout()
	build_geometry()


## Só o traçado: amostras, pontes e curvatura (rápido, ~1 ms). Basta para as
## consultas (`get_point_at`, `length`...) e para o mapa da tela de pistas.
func prepare_layout() -> void:
	_sample_curve()
	if samples.size() >= 8:
		_compute_curvature()


## Gera as malhas da pista a partir do traçado (`prepare_layout` antes). É a parte
## pesada; com a pista fora da árvore e sem colisão pode rodar numa thread.
func build_geometry() -> void:
	if is_instance_valid(_generated):
		_generated.free()
	coins = null
	obstacles = null
	_generated = Node3D.new()
	_generated.name = "Gerado"
	add_child(_generated, false, Node.INTERNAL_MODE_FRONT)
	if samples.size() < 8:
		return
	var preview := Engine.is_editor_hint()
	var rivers := _river_lines()
	var cache_key := "" if preview else _terrain_key(rivers)
	var cached: Dictionary = _terrain_cache.get(cache_key, {})
	if cached.is_empty():
		terrain = TrackTerrain.new()
		terrain.water_level = water_level
		terrain.hill_height = hill_height
		terrain.hill_bias = hill_bias
		terrain.mountain_height = mountain_height
		terrain.terrace_step = terrace_step
		terrain.sea_distance = sea_distance
		terrain.river_width = river_width
		terrain.river_depth = river_depth
		terrain.river_bank = river_bank
		terrain.river_valley = river_valley
		terrain.deck_half = road_width * 0.5 + shoulder_width + wall_thickness
		terrain.flat_distance = road_width * 0.5 + shoulder_width + wall_thickness + 2.5
		terrain.setup(samples, decoration_seed, bridge_mask, rivers)
		# A largada (arquibancada) fica num terreno plano.
		var start := get_point_at(0.0)
		terrain.flat_spots.append(Vector3(start.x, start.z, 55.0))
		var ground_mesh := _build_ground(preview)
		if cache_key != "":
			_terrain_cache = {cache_key: {"terrain": terrain, "mesh": ground_mesh}}
	else:
		terrain = cached.terrain
		_build_ground(preview, cached.mesh)
	_build_water()
	_build_road()
	_build_curbs()
	_build_walls()
	_build_start_gate()
	_build_boost_pads()
	if not ramps.is_empty():
		TrackRampBuilder.new(self, _generated).build()
	_build_item_boxes()
	_build_coins()
	_build_obstacles()
	if not bridge_spans.is_empty():
		TrackBridgeBuilder.new(self, terrain, _generated).build(preview)
	TrackScenery.new(self, terrain, _generated).build(preview)


# --- Consultas usadas pela corrida ------------------------------------------------

## Índice da amostra mais próxima. Com `hint`, procura só perto dele (mais rápido
## e evita "pular" para outro trecho da pista).
func get_closest_index(local_pos: Vector3, hint := -1, window := 24) -> int:
	var count := samples.size()
	if count == 0:
		return 0
	var best := 0
	var best_dist := INF
	if hint < 0 or hint >= count:
		for i in count:
			var d := local_pos.distance_squared_to(samples[i])
			if d < best_dist:
				best_dist = d
				best = i
	else:
		for k in range(-window, window + 1):
			var i := (hint + k + count) % count
			var d := local_pos.distance_squared_to(samples[i])
			if d < best_dist:
				best_dist = d
				best = i
	return best


## Distância percorrida ao longo da pista (0 = linha de chegada).
func get_along(local_pos: Vector3, index: int) -> float:
	return distances[index] + (local_pos - samples[index]).dot(tangents[index])


## Distância lateral até o centro da pista (positivo = direita).
func get_lateral(local_pos: Vector3, index: int) -> float:
	return (local_pos - samples[index]).dot(rights[index])


func get_point_at(dist: float) -> Vector3:
	var count := samples.size()
	if count == 0:
		return Vector3.ZERO
	var f := fposmod(dist, length) / (length / count)
	var i := int(f) % count
	return samples[i].lerp(samples[(i + 1) % count], f - floorf(f))


func get_direction_at(dist: float) -> Vector3:
	var count := samples.size()
	if count == 0:
		return Vector3.FORWARD
	var f := fposmod(dist, length) / (length / count)
	var i := int(f) % count
	return tangents[i].lerp(tangents[(i + 1) % count], f - floorf(f)).normalized()


## Transformação (espaço local) num ponto da pista, olhando no sentido da corrida.
func get_transform_at(dist: float, lateral := 0.0) -> Transform3D:
	var p := get_point_at(dist)
	var t := get_direction_at(dist)
	var r := t.cross(Vector3.UP).normalized()
	return Transform3D(Basis.looking_at(t, Vector3.UP), p + r * lateral)


## Lado (+1 direita / -1 esquerda) com mais espaço livre num trecho da pista.
func outer_side_at(index: int) -> float:
	var best_side := 1.0
	var best_clearance := -1.0
	for side: float in [-1.0, 1.0]:
		var probe := samples[index] + rights[index] * side * 35.0
		var clearance := terrain.distance_to_track(probe.x, probe.z) if terrain else _distance_to_track(probe)
		if clearance > best_clearance:
			best_clearance = clearance
			best_side = side
	return best_side


# --- Amostragem da curva --------------------------------------------------------

func _sample_curve() -> void:
	samples = PackedVector3Array()
	tangents = PackedVector3Array()
	rights = PackedVector3Array()
	distances = PackedFloat32Array()
	length = 0.0
	bridge_mask = PackedByteArray()
	bridge_spans.clear()
	var path := _get_path()
	if path == null or path.curve == null or path.curve.point_count < 3:
		push_warning("Track: adicione um Path3D chamado 'Tracado' com pelo menos 3 pontos.")
		return
	var curve := path.curve
	var baked_length := curve.get_baked_length()
	if baked_length < 10.0:
		return
	var count := maxi(int(round(baked_length / sample_spacing)), 16)
	var step := baked_length / count
	for i in count:
		samples.append(path.transform * curve.sample_baked(i * step, true))
		distances.append(i * step)
	length = baked_length
	_apply_bridges()
	for i in count:
		var t := (samples[(i + 1) % count] - samples[(i - 1 + count) % count]).normalized()
		tangents.append(t)
		var r := t.cross(Vector3.UP)
		r.y = 0.0
		rights.append(r.normalized())


## Marca as amostras em cima de ponte e levanta a pista (rampas suaves antes e
## depois de cada ponte; onde duas rampas se encontram vale a mais alta).
func _apply_bridges() -> void:
	var count := samples.size()
	bridge_mask = PackedByteArray()
	bridge_mask.resize(count)
	bridge_spans.clear()
	var lift := PackedFloat32Array()
	lift.resize(count)
	for b in bridges:
		if b == null or b.end <= b.start:
			continue
		var a := b.start * length
		var e := b.end * length
		var first := -1
		var last := -1
		for i in count:
			var s := distances[i]
			var f := 0.0
			if s >= a and s <= e:
				f = 1.0
				bridge_mask[i] = 2 if b.over_water else 1
				if first < 0:
					first = i
				last = i
			else:
				var before := fposmod(a - s, length)
				var after := fposmod(s - e, length)
				if before < b.ramp:
					f = smoothstep(0.0, 1.0, 1.0 - before / b.ramp)
				elif after < b.ramp:
					f = smoothstep(0.0, 1.0, 1.0 - after / b.ramp)
			lift[i] = maxf(lift[i], b.height * f)
		if first >= 0 and last > first + 2:
			bridge_spans.append({"bridge": b, "from": first, "to": last})
	for i in count:
		samples[i].y += lift[i]


func _compute_curvature() -> void:
	var count := samples.size()
	var step := length / count
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in count:
		var d := tangents[(i + 2) % count] - tangents[(i - 2 + count) % count]
		raw[i] = d.dot(rights[i]) / (step * 4.0)
	curvature = PackedFloat32Array()
	curvature.resize(count)
	for i in count:
		var sum := 0.0
		for k in range(-4, 5):
			sum += raw[(i + k + count) % count]
		curvature[i] = sum / 9.0


# --- Construção ------------------------------------------------------------------

class MeshData:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	## Cor por vértice (opcional): se tiver uma por vértice, vai para o shader em COLOR.
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add_vertex(pos: Vector3, normal: Vector3, uv: Vector2) -> int:
		verts.append(pos)
		normals.append(normal)
		uvs.append(uv)
		return verts.size() - 1

	## Adiciona um triângulo virado para `facing` (corrige a ordem dos vértices).
	func add_tri(a: int, b: int, c: int, facing: Vector3) -> void:
		var pa := verts[a]
		if (verts[c] - pa).cross(verts[b] - pa).dot(facing) < 0.0:
			indices.append_array([a, c, b])
		else:
			indices.append_array([a, b, c])

	func to_mesh(material: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		if tangents.size() == verts.size() * 4:
			arrays[Mesh.ARRAY_TANGENT] = tangents
		if colors.size() == verts.size():
			arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		return mesh

	func collision_faces() -> PackedVector3Array:
		var faces := PackedVector3Array()
		for i in indices:
			faces.append(verts[i])
		return faces


## Faixa contínua ao longo da pista entre dois trilhos de pontos.
## Com `tangent_rail`, grava tangentes (direção de U) para o relevo do shader.
func _add_strip(md: MeshData, rail_a: PackedVector3Array, rail_b: PackedVector3Array,
		face_normals: PackedVector3Array, u_a: float, u_b: float, with_tangents := false) -> void:
	var count := samples.size()
	var base := md.verts.size()
	for i in count + 1:
		var j := i % count
		var v := distances[j] if i < count else length
		md.add_vertex(rail_a[j], face_normals[j], Vector2(u_a, v))
		md.add_vertex(rail_b[j], face_normals[j], Vector2(u_b, v))
		if with_tangents:
			var t := (rail_b[j] - rail_a[j]).normalized()
			md.tangents.append_array([t.x, t.y, t.z, 1.0, t.x, t.y, t.z, 1.0])
	for i in count:
		var a := base + i * 2
		md.add_tri(a, a + 1, a + 2, face_normals[i])
		md.add_tri(a + 1, a + 3, a + 2, face_normals[i])


func _offset_rail(lateral: float, height: float) -> PackedVector3Array:
	var rail := PackedVector3Array()
	for i in samples.size():
		rail.append(samples[i] + rights[i] * lateral + Vector3.UP * height)
	return rail


## Trilho com deslocamento lateral diferente em cada amostra.
func _variable_rail(laterals: PackedFloat32Array, height: float) -> PackedVector3Array:
	var rail := PackedVector3Array()
	for i in samples.size():
		rail.append(samples[i] + rights[i] * laterals[i] + Vector3.UP * height)
	return rail


func _repeat(v: Vector3) -> PackedVector3Array:
	var arr := PackedVector3Array()
	arr.resize(samples.size())
	arr.fill(v)
	return arr


func _scaled_rights(factor: float) -> PackedVector3Array:
	var arr := PackedVector3Array()
	for r in rights:
		arr.append(r * factor)
	return arr


## Normais de uma faixa inclinada que sobe `rise` metros em `run` metros para fora (`side`).
func _slope_normals(side: float, run: float, rise: float) -> PackedVector3Array:
	var arr := PackedVector3Array()
	for r in rights:
		arr.append((Vector3.UP * run - r * side * rise).normalized())
	return arr


func _add_mesh(mesh: Mesh, xform := Transform3D.IDENTITY, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	(parent if parent else _generated).add_child(mi)
	return mi


func _add_static_body(shape: Shape3D, xform := Transform3D.IDENTITY, group := "", parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.transform = xform
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	if group != "":
		body.add_to_group(group)
	(parent if parent else _generated).add_child(body)
	return body


func _bounds() -> AABB:
	var box := AABB(samples[0], Vector3.ZERO)
	for p in samples:
		box = box.expand(p)
	return box


func _is_flat() -> bool:
	for p in samples:
		if absf(p.y) > 0.01:
			return false
	return true


## Chave do terreno no cache: tudo o que muda o resultado de TrackTerrain e da malha.
func _terrain_key(rivers: Array[PackedVector2Array]) -> String:
	var sum := Vector3.ZERO
	for p in samples:
		sum += p
	var river_sum := Vector2.ZERO
	var river_points := 0
	for line in rivers:
		river_points += line.size()
		for p in line:
			river_sum += p
	var bridged := 0
	for b in bridge_mask:
		bridged += b
	return var_to_str([track_id, scenery, samples.size(), length, sum, bridged, river_points, river_sum,
			decoration_seed, water_level, hill_height, hill_bias, mountain_height, terrace_step,
			sea_distance, river_width, river_depth, river_bank, river_valley, road_width,
			shoulder_width, wall_thickness])


## Chão em volta da pista. Devolve a malha (gerada aqui ou a `mesh` do cache).
func _build_ground(preview: bool, mesh: Mesh = null) -> Mesh:
	if mesh == null:
		var mat := ShaderMaterial.new()
		mat.shader = TERRAIN_SHADER
		mat.set_shader_parameter("water_level", water_level)
		var params := TrackTheme.terrain_params(scenery)
		for key: String in params:
			mat.set_shader_parameter(key, params[key])
		# Grade com células de ~2,8 m perto da pista (pistas compridas ganham mais linhas).
		var inner_half := terrain.half_extent + Vector2(120.0, 120.0)
		var cell := 5.6 if preview else 2.8
		var res := Vector2i(int(inner_half.x / (0.36 * cell)), int(inner_half.y / (0.36 * cell)))
		mesh = terrain.build_mesh(res, inner_half, 1250.0, mat)
	var ground := _add_mesh(mesh)
	ground.name = "Terreno"
	# O chão não projeta sombra: a malha inteira entraria em todas as cascatas de
	# sombra do sol (centenas de milhares de triângulos) quase sem efeito visível.
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if with_collision:
		# O kart nunca sai das muretas: o chão de colisão é só um plano (grama = "offroad").
		var center := terrain.center
		var shape := BoxShape3D.new()
		shape.size = Vector3(1800.0, 2.0, 1800.0)
		_add_static_body(shape, Transform3D(Basis(), Vector3(center.x, -1.0, center.y)), "offroad")
	return mesh


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2600.0, 2600.0)
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	var params := TrackTheme.water_params(scenery)
	for key: String in params:
		mat.set_shader_parameter(key, params[key])
	plane.material = mat
	var water := _add_mesh(plane, Transform3D(Basis(), Vector3(terrain.center.x, water_level, terrain.center.y)))
	water.name = "Agua"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_road() -> void:
	var half := road_width * 0.5
	var md := MeshData.new()
	_add_strip(md, _offset_rail(-half, 0.0), _offset_rail(half, 0.0), _repeat(Vector3.UP), 0.0, 1.0, true)
	# Laterais do asfalto (dão volume quando a pista tem subidas).
	_add_strip(md, _offset_rail(-half, 0.0), _offset_rail(-half, -0.6), _scaled_rights(-1.0), 0.0, 0.0, true)
	_add_strip(md, _offset_rail(half, 0.0), _offset_rail(half, -0.6), _scaled_rights(1.0), 1.0, 1.0, true)
	var mat := ShaderMaterial.new()
	mat.shader = ROAD_SHADER
	mat.set_shader_parameter("road_width", road_width)
	mat.set_shader_parameter("track_length", length)
	mat.set_shader_parameter("curb_min", curb_min_width)
	mat.set_shader_parameter("logo_texture", LOGO_ICON)
	var road := _add_mesh(md.to_mesh(mat))
	road.name = "Asfalto"
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if with_collision and not _is_flat():
		# Pista com subidas/pontes: o chão de colisão acompanha a pista de mureta a
		# mureta (asfalto + acostamento), senão o kart cairia no acostamento elevado.
		var reach := half + shoulder_width + 0.15
		var col := MeshData.new()
		_add_strip(col, _offset_rail(-reach, 0.0), _offset_rail(reach, 0.0), _repeat(Vector3.UP), 0.0, 1.0)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(col.collision_faces())
		_add_static_body(shape, Transform3D.IDENTITY, "road")


## Zebras em relevo nas duas bordas, mais largas do lado de dentro das curvas.
func _build_curbs() -> void:
	var half := road_width * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = CURB_SHADER
	var md := MeshData.new()
	for side: float in [-1.0, 1.0]:
		var inner := PackedFloat32Array()
		var ramp := PackedFloat32Array()
		var count := samples.size()
		inner.resize(count)
		ramp.resize(count)
		for i in count:
			var k := curvature[i]
			var inside := (k > 0.0) == (side > 0.0)
			var t := smoothstep(0.01, 0.028, absf(k))
			var w := lerpf(curb_min_width, curb_inner_width if inside else curb_outer_width, t)
			inner[i] = side * (half - w)
			ramp[i] = side * (half - w + minf(0.22, w * 0.3))
		var top := 0.075
		var r0 := _variable_rail(inner, 0.012)
		var r1 := _variable_rail(ramp, top)
		var r2 := _offset_rail(side * (half - 0.07), top)
		var r3 := _offset_rail(side * half, 0.03)
		var r4 := _offset_rail(side * half, -0.15)
		_add_strip(md, r0, r1, _slope_normals(side, 0.22, top), 0.0, 0.15)
		_add_strip(md, r1, r2, _repeat(Vector3.UP), 0.15, 0.95)
		_add_strip(md, r2, r3, _slope_normals(side, 0.07, -0.045), 0.95, 1.0)
		_add_strip(md, r3, r4, _scaled_rights(side), 1.0, 1.0)
	var curbs := _add_mesh(md.to_mesh(mat))
	curbs.name = "Zebras"
	curbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_walls() -> void:
	var outer_mat := ShaderMaterial.new()
	outer_mat.shader = WALL_SHADER
	outer_mat.set_shader_parameter("outer_side", true)
	outer_mat.set_shader_parameter("wall_height", wall_height)
	var offset := road_width * 0.5 + shoulder_width
	var bevel := 0.1
	for side: float in [-1.0, 1.0]:
		# Do lado esquerdo, quem olha da pista vê o texto andando para a frente; do
		# direito, ao contrário — por isso o "mirror".
		var inner_mat := ShaderMaterial.new()
		inner_mat.shader = WALL_SHADER
		inner_mat.set_shader_parameter("mirror", -side)
		inner_mat.set_shader_parameter("wall_height", wall_height)
		inner_mat.set_shader_parameter("logo_icon", LOGO_ICON)
		inner_mat.set_shader_parameter("wordmark_light", WORDMARK)
		inner_mat.set_shader_parameter("wordmark_dark", WORDMARK_DARK)
		inner_mat.set_shader_parameter("icon_aspect", float(LOGO_ICON.get_width()) / LOGO_ICON.get_height())
		inner_mat.set_shader_parameter("wordmark_aspect", float(WORDMARK.get_width()) / WORDMARK.get_height())
		var inner := offset * side
		var outer := (offset + wall_thickness) * side
		var face := MeshData.new()
		_add_strip(face, _offset_rail(inner, -0.3), _offset_rail(inner, wall_height - bevel), _scaled_rights(-side), -0.3, wall_height - bevel)
		var rest := MeshData.new()
		var top_in := _offset_rail(inner + side * bevel, wall_height)
		var top_out := _offset_rail(outer - side * bevel, wall_height)
		_add_strip(rest, _offset_rail(inner, wall_height - bevel), top_in, _slope_normals(side, bevel, bevel), wall_height - bevel, wall_height)
		_add_strip(rest, top_in, top_out, _repeat(Vector3.UP), wall_height, wall_height)
		_add_strip(rest, top_out, _offset_rail(outer, wall_height - bevel), _slope_normals(side, bevel, -bevel), wall_height, wall_height - bevel)
		_add_strip(rest, _offset_rail(outer, wall_height - bevel), _offset_rail(outer, -0.3), _scaled_rights(side), wall_height - bevel, -0.3)
		var wall := _add_mesh(face.to_mesh(inner_mat))
		wall.name = "Mureta"
		_add_mesh(rest.to_mesh(outer_mat))
		if not with_collision:
			continue
		var faces := face.collision_faces()
		faces.append_array(rest.collision_faces())
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		_add_static_body(shape, Transform3D.IDENTITY, "wall")


## Pórtico de largada: colunas azuis, viga com a marca da Ativos dos dois lados
## e faixa quadriculada embaixo.
func _build_start_gate() -> void:
	var gate := Node3D.new()
	gate.name = "Largada"
	gate.transform = get_transform_at(0.0)
	_generated.add_child(gate)
	var half := road_width * 0.5 + 1.4
	var span := half * 2.0
	var blue := TrackScenery.color_material(TrackScenery.BRAND_BLUE, 0.35, 0.15)
	var white := TrackScenery.color_material(Color(0.96, 0.96, 0.98), 0.4)
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.6
	pillar.bottom_radius = 0.7
	pillar.height = 7.4
	pillar.radial_segments = 20
	pillar.material = blue
	var ring := CylinderMesh.new()
	ring.top_radius = 0.74
	ring.bottom_radius = 0.74
	ring.height = 0.3
	ring.radial_segments = 20
	ring.material = white
	var pillar_shape: CylinderShape3D = null
	if with_collision:
		pillar_shape = CylinderShape3D.new()
		pillar_shape.radius = 0.7
		pillar_shape.height = 7.4
	for side: float in [-1.0, 1.0]:
		var xf := Transform3D(Basis(), Vector3(side * half, 3.7, 0.0))
		_add_mesh(pillar, xf, gate)
		_add_mesh(ring, Transform3D(Basis(), Vector3(side * half, 0.15, 0.0)), gate)
		_add_mesh(ring, Transform3D(Basis(), Vector3(side * half, 4.6, 0.0)), gate)
		if pillar_shape:
			_add_static_body(pillar_shape, xf, "wall", gate)
	var beam := BoxMesh.new()
	beam.size = Vector3(span + 1.6, 2.3, 1.0)
	beam.material = TrackScenery.color_material(TrackScenery.NAVY, 0.4)
	_add_mesh(beam, Transform3D(Basis(), Vector3(0.0, 6.6, 0.0)), gate)
	var trim := BoxMesh.new()
	trim.size = Vector3(span + 1.8, 0.22, 1.1)
	trim.material = TrackScenery.color_material(TrackScenery.YELLOW, 0.4)
	for y: float in [5.42, 7.78]:
		_add_mesh(trim, Transform3D(Basis(), Vector3(0.0, y, 0.0)), gate)
	# Frente (quem chega para largar vê a marca) e verso (o ícone "at").
	var panel := QuadMesh.new()
	panel.size = Vector2(span + 1.4, 2.1)
	var aspect := panel.size.x / panel.size.y
	var front := _add_mesh(panel, Transform3D(Basis(), Vector3(0.0, 6.6, 0.51)), gate)
	front.material_override = TrackScenery.brand_material(WORDMARK_DARK, TrackScenery.NAVY, aspect, {"logo_fill": 0.68, "emission": 0.15})
	var back := _add_mesh(panel, Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 6.6, -0.51)), gate)
	back.material_override = TrackScenery.brand_material(LOGO_ICON, TrackScenery.BRAND_BLUE, aspect,
			{"logo_fill": 0.8, "logo_count": 3, "recolor": true, "recolor_main": Color.WHITE, "recolor_accent": TrackScenery.YELLOW, "emission": 0.1})
	# Faixa quadriculada.
	var img := Image.create(24, 2, false, Image.FORMAT_RGB8)
	for x in 24:
		for y in 2:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.07))
	var checker := StandardMaterial3D.new()
	checker.albedo_texture = ImageTexture.create_from_image(img)
	checker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	checker.cull_mode = BaseMaterial3D.CULL_DISABLED
	checker.roughness = 0.6
	var strip := QuadMesh.new()
	strip.size = Vector2(span - 1.4, 0.55)
	strip.material = checker
	_add_mesh(strip, Transform3D(Basis(), Vector3(0.0, 5.0, 0.0)), gate)


func _build_boost_pads() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BOOST_SHADER
	var md := MeshData.new()
	var w := 4.0
	var l := 5.6
	var a := md.add_vertex(Vector3(-w * 0.5, 0.04, l * 0.5), Vector3.UP, Vector2(0, 0))
	var b := md.add_vertex(Vector3(w * 0.5, 0.04, l * 0.5), Vector3.UP, Vector2(1, 0))
	var c := md.add_vertex(Vector3(-w * 0.5, 0.04, -l * 0.5), Vector3.UP, Vector2(0, 1))
	var d := md.add_vertex(Vector3(w * 0.5, 0.04, -l * 0.5), Vector3.UP, Vector2(1, 1))
	md.add_tri(a, b, c, Vector3.UP)
	md.add_tri(b, d, c, Vector3.UP)
	var pad_mesh := md.to_mesh(mat)
	var shape: BoxShape3D = null
	if with_collision:
		shape = BoxShape3D.new()
		shape.size = Vector3(w, 1.6, l)
	for frac in boost_pads:
		var pad: Node3D = Area3D.new() if with_collision else Node3D.new()
		pad.name = "Turbo"
		pad.transform = get_transform_at(wrapf(frac, 0.0, 1.0) * length)
		if pad is Area3D:
			var col := CollisionShape3D.new()
			col.shape = shape
			col.position.y = 0.8
			pad.add_child(col)
			(pad as Area3D).body_entered.connect(_on_boost_pad_body_entered)
		var mi := _add_mesh(pad_mesh, Transform3D.IDENTITY, pad)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_generated.add_child(pad)


## Fileiras de caixas de item (veja item_box.gd), atravessando o asfalto.
func _build_item_boxes() -> void:
	if item_rows.is_empty() or item_boxes_per_row < 1:
		return
	var mesh := ItemBox.make_mesh()
	var shadow := ItemBox.make_shadow_mesh()
	var holder := Node3D.new()
	holder.name = "CaixasDeItem"
	_generated.add_child(holder)
	var count := item_boxes_per_row
	var usable := road_width - 2.0 * curb_min_width - ItemBox.SIZE - 0.6
	var spacing := minf(ITEM_BOX_SPACING, usable / maxf(count - 1, 1))
	for frac in item_rows:
		var d := wrapf(frac, 0.0, 1.0) * length
		var dir := get_direction_at(d)
		var tilt := asin(clampf(dir.y, -1.0, 1.0))
		dir.y = 0.0
		dir = dir.normalized()
		var right := dir.cross(Vector3.UP).normalized()
		var basis := Basis.looking_at(dir, Vector3.UP)
		var center := get_point_at(d) + Vector3.UP * ItemBox.FLOAT_HEIGHT
		for i in count:
			var box := ItemBox.new()
			box.name = "CaixaDeItem"
			box.transform = Transform3D(basis, center + right * (i - (count - 1) * 0.5) * spacing)
			box.setup(mesh, shadow, with_collision, tilt)
			holder.add_child(box)


## Moedas Ativos (veja track_coins.gd): as fileiras de `coin_lines` e um arco de três
## moedas no pulo de cada rampa.
func _build_coins() -> void:
	var points := PackedVector3Array()
	var dirs := PackedVector3Array()
	for line in coin_lines:
		var count := maxi(int(line.z), 1)
		var center := wrapf(line.x, 0.0, 1.0) * length
		for i in count:
			var d := center + (i - (count - 1) * 0.5) * coin_spacing
			if _on_ramp(d):
				continue
			var xf := get_transform_at(d, line.y)
			points.append(xf.origin + Vector3.UP * TrackCoins.HEIGHT)
			dirs.append(get_direction_at(d))
	if coins_on_ramps:
		var inner_half := road_width * 0.5 - curb_min_width - 0.1
		for r in ramps:
			if r == null:
				continue
			var lip := wrapf(r.at, 0.0, 1.0) * length
			var lateral := r.offset * (inner_half - inner_half * r.width)
			if r.glider:
				# Voo de asa-delta: uma fileira de três moedas à esquerda e, mais à
				# frente, outra à direita, na altura do kart planando a 27 m/s (quem vira
				# no ar pega as duas).
				var base_y := get_point_at(lip).y + r.height
				for group: Vector2 in [Vector2(30.0, -3.2), Vector2(68.0, 3.2)]:
					for k in 3:
						var gx := group.x + k * 6.0
						var gp := get_transform_at(lip + gx, group.y).origin
						var gy := base_y + TrackRamp.glide_height(gx, 27.0) + TrackCoins.KART_CENTER
						points.append(Vector3(gp.x, maxf(gy, gp.y + TrackCoins.HEIGHT), gp.z))
						dirs.append(get_direction_at(lip + gx))
				continue
			# Arco do kart saindo da borda a 27 m/s (com turbo, mais longo): altura do
			# meio do kart = borda + subida - gravidade (como em Kart._launch).
			var v := 27.0 * (1.35 if r.turbo else 1.0)
			var vy := v * tan(r.lip_angle())
			var steps: Array = [7.0, 15.0, 23.0] if r.turbo else [5.0, 10.5, 16.0]
			for x: float in steps:
				var t := x / v
				var y := r.height + vy * t - 0.5 * Kart.GRAVITY * t * t + TrackCoins.KART_CENTER
				var xf := get_transform_at(lip + x, lateral)
				points.append(xf.origin + Vector3.UP * maxf(y, TrackCoins.HEIGHT))
				dirs.append(get_direction_at(lip + x))
	if points.is_empty():
		return
	coins = TrackCoins.new()
	coins.name = "MoedasAtivos"
	coins.setup(points, dirs, with_collision)
	_generated.add_child(coins)


## O ponto `d` (m) fica em cima da subida de alguma rampa?
func _on_ramp(d: float) -> bool:
	for r in ramps:
		if r == null:
			continue
		var to_lip := wrapf(wrapf(r.at, 0.0, 1.0) * length - d, -length * 0.5, length * 0.5)
		if to_lip > -2.0 and to_lip < r.length + 1.0:
			return true
	return false


## Obstáculos que se mexem nos trechos de `obstacle_zones` (veja track_obstacles.gd).
func _build_obstacles() -> void:
	if obstacle_zones.is_empty():
		return
	obstacles = TrackObstacles.new()
	obstacles.name = "Obstaculos"
	obstacles.setup(self, terrain, obstacle_zones, with_collision)
	_generated.add_child(obstacles)


func _on_boost_pad_body_entered(body: Node3D) -> void:
	if body.has_method("apply_boost"):
		body.apply_boost(1.1, 2)


## Distância (no plano) do ponto até o centro da pista (versão lenta, sem terreno).
func _distance_to_track(p: Vector3, stride := 2) -> float:
	var best := INF
	var flat := Vector2(p.x, p.z)
	for i in range(0, samples.size(), stride):
		var d := flat.distance_squared_to(Vector2(samples[i].x, samples[i].z))
		if d < best:
			best = d
	return sqrt(best)
