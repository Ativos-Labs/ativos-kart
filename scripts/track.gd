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
const SNOW_ROAD_SHADER := preload("res://shaders/snow_road.gdshader")
const SNOW_BANK_SHADER := preload("res://shaders/snow_bank.gdshader")
const SAND_ROAD_SHADER := preload("res://shaders/sand_road.gdshader")
const SAND_BANK_SHADER := preload("res://shaders/sand_bank.gdshader")
const BEACH_ROAD_SHADER := preload("res://shaders/beach_road.gdshader")
## Hieróglifos (grade 4×4, veja tools/deserto/gerar_hieroglifos.py) das pedras do Egito.
const GLYPHS := preload("res://assets/textures/hieroglifos.png")
## Ruído branco dos shaders que usam noise_tex.gdshaderinc (neve, gelo e água congelada).
const NOISE_TEXTURE := preload("res://assets/textures/ruido.png")
const LOGO_ICON := preload("res://assets/logos/ativos_icone.png")
const WORDMARK := preload("res://assets/logos/ativos_marca.png")
const WORDMARK_DARK := preload("res://assets/logos/ativos_marca_branca.png")

## Distância máxima entre as caixas de item de uma fileira (m): com a área de toque delas
## (ItemBox.TOUCH_SIZE), a fileira não deixa vão por onde um kart de 0,7 m passe sem pegar
## nenhuma.
const ITEM_BOX_SPACING := 1.7
## Nas dunas, a faixa de areia fofa junto de cada borda do asfalto (m).
const SOFT_SAND_EDGE := 2.2
## Quanto o asfalto do trecho de gelo fica acima da água congelada (m).
const ICE_ROAD_LIFT := 0.06
## Quanto (m) a inclinação das curvas é alisada ao longo da pista.
const BANK_SMOOTH := 10.0
## Onde a pista gira nas curvas inclinadas: 0 = no meio, 1 = na borda de dentro.
const BANK_PIVOT := 0.2
## Folga (m) da água em volta dos vales e rios numa pista com curvas inclinadas.
const WATER_AREA_MARGIN := 100.0
## Largura máxima (m) de cada faixa da pista nas pistas com curvas inclinadas.
const BANK_STRIP_WIDTH := 1.25

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
## Pista inteira de neve e gelo, sem asfalto: neve batida com trilhas de pneu e brilho
## (escorrega um pouco), montes de neve no lugar das zebras e das muretas, e os trechos
## de GELO viram rio congelado transparente (com bolhas, rachaduras e peixes embaixo).
@export var snow_track := false:
	set(value):
		snow_track = value
		_queue_rebuild()
## Pista inteira de areia, sem asfalto (deserto do Egito): areia batida com trilhas de
## pneu, ondinhas do vento e pedrinhas (solta um pouco a traseira), montes de areia com
## blocos de arenito cheios de hieróglifos no lugar das muretas e leira de areia no
## lugar das zebras. As dunas e o mergulho continuam como trechos especiais.
@export var sand_track := false:
	set(value):
		sand_track = value
		_queue_rebuild()
## Pista de praia, sem asfalto: areia branca de praia com trilhas de pneu e conchinhas
## (solta um pouco a traseira, como a areia do deserto), cercas de corda com postes de
## madeira no lugar das muretas, tábuas nas passarelas (TrackBridge PASSARELA), boias no
## baixio (TrackSection RASO), quiosques de sapê e o portal de bambu na largada (veja
## track_beach.gd).
@export var beach_track := false:
	set(value):
		beach_track = value
		_queue_rebuild()
## Estádio (veja track_stadium.gd): anel de arquibancadas lotadas, com cobertura, em
## volta de `stadium_center` (retângulo arredondado de semieixos `stadium_radii`), com
## túneis onde a pista passa por baixo, torres de luz, telão, boxes com torre de
## controle, pódio e o Celerino gigante no miolo; pórtico de treliça na largada. O chão
## dentro do anel fica plano.
@export var stadium_track := false:
	set(value):
		stadium_track = value
		_queue_rebuild()
## Cidade neon à noite (veja track_city.gd): prédios com janelas acesas e letreiros
## holográficos da Ativos, horizonte de arranha-céus, portais de neon por cima da pista,
## postes, tubos de neon nas muretas, asfalto molhado com faixas acesas, zebras de neon,
## muretas de LED e canal de concreto. O céu (estrelas, brilho da cidade) e a lua ficam
## nos nós WorldEnvironment e Sol.
@export var city_track := false:
	set(value):
		city_track = value
		_queue_rebuild()
@export var stadium_center := Vector2.ZERO:
	set(value):
		stadium_center = value
		_queue_rebuild()
@export var stadium_radii := Vector2(100.0, 150.0):
	set(value):
		stadium_radii = value
		_queue_rebuild()
## Quanto do chão em volta vira mar de dunas (0 = relevo comum, 1 = só dunas; as
## montanhas do horizonte ficam).
@export_range(0.0, 1.0, 0.05) var dune_cover := 0.0:
	set(value):
		dune_cover = value
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

@export_group("Trechos especiais")
## Trechos com cara e física próprias (veja track_section.gd): mergulho por baixo
## d'água, dunas de areia, lago congelado e vale para atravessar de asa-delta.
@export var sections: Array[TrackSection] = []:
	set(value):
		sections = value
		_watch_bridges()
		_queue_rebuild()

@export_group("Curvas inclinadas")
## Trechos em que a pista deita para dentro da curva (veja track_bank.gd); com ângulo
## alto viram parede (a gravidade do kart segue o chão).
@export var banks: Array[TrackBank] = []:
	set(value):
		banks = value
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
## pneus gigantes quicando (Campo), ondas do mar (Praia), tambores de coluna (Deserto) e
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
## Distância (m) do centro do mapa onde as montanhas do horizonte começam a subir e
## onde chegam na altura toda.
@export var mountain_start := 300.0:
	set(value):
		mountain_start = value
		_queue_rebuild()
@export var mountain_end := 650.0:
	set(value):
		mountain_end = value
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
## Profundidade do mar longe da pista (m abaixo do chão).
@export var sea_depth := 9.0:
	set(value):
		sea_depth = value
		_queue_rebuild()
## Com mar: áreas de terra firme mesmo longe da pista (x, z, raio): o continente, o
## morro de uma ilha.
@export var land_spots := PackedVector3Array():
	set(value):
		land_spots = value
		_queue_rebuild()

@export_tool_button("Reconstruir pista", "Reload") var rebuild_button := rebuild

## Sem colisão a pista é só o visual. Assim ela pode ser gerada numa thread, fora da
## árvore de cena (`build_geometry`): o servidor de física não pode ser usado fora da
## thread principal.
var with_collision := true
## Gerando numa thread (`build_geometry(true)`): o que usa o servidor de física (formas,
## corpos e áreas) fica guardado aqui e só é criado depois, na thread principal, por
## `finish_physics()`.
var _defer_physics := false
var _physics_jobs: Array[Callable] = []

## Pontos amostrados no centro da pista (espaço local).
var samples := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()
## "Cima" da pista em cada amostra: Vector3.UP, menos nas curvas inclinadas (aí
## `rights` também deita junto, ao longo do chão). Vazio = pista sem inclinação.
var ups := PackedVector3Array()
## Inclinação de cada amostra (rad, + = o lado direito sobe). Vazio sem `banks`.
var bank_angles := PackedFloat32Array()
## As amostras antes de inclinar (o terreno segue estas: a borda de dentro).
var ground_samples := PackedVector3Array()
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
## Trecho especial de cada amostra (índice em `sections`, -1 = nenhum) e quanto ele
## vale ali (1 dentro, 0..1 nas rampas de transição).
var section_of := PackedInt32Array()
var section_blend := PackedFloat32Array()
## Amostras no ar, sobre o vale (sem asfalto): 1. Nelas `bridge_mask` = 3.
var gap_mask := PackedByteArray()
## Trechos sobre vales: {"section": TrackSection, "from": 1ª amostra no ar, "to": última}.
var gap_spans: Array[Dictionary] = []
## Cristas das dunas (m da largada): passando rápido por uma, o kart dá um pulinho.
var dune_crests := PackedFloat32Array()
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
	for s in sections:
		if s and not s.changed.is_connected(_queue_rebuild):
			s.changed.connect(_queue_rebuild)
	for b in banks:
		if b and not b.changed.is_connected(_queue_rebuild):
			b.changed.connect(_queue_rebuild)


## Ponte ou trecho no ar sobre um vale (o chão embaixo não segue a pista).
func is_bridge(index: int) -> bool:
	return index >= 0 and index < bridge_mask.size() and bridge_mask[index] != 0


## Amostra no ar, em cima de um vale (sem asfalto embaixo).
func is_gap(index: int) -> bool:
	return index >= 0 and index < gap_mask.size() and gap_mask[index] != 0


## Trecho especial na amostra (null = pista comum).
func section_at(index: int) -> TrackSection:
	if index < 0 or index >= section_of.size() or section_of[index] < 0:
		return null
	return sections[section_of[index]]


## Tipo do trecho especial na amostra (TrackSection.Kind) ou -1. Nas rampas de
## transição só conta a partir da metade.
func section_kind_at(index: int) -> int:
	var s := section_at(index)
	if s == null or section_blend[index] < 0.5:
		return -1
	return s.kind


## Amostra comum: sem ponte, vale, água, gelo ou areia (para placas e enfeites).
func is_plain(index: int) -> bool:
	return not is_bridge(index) and (index >= section_of.size() or section_of[index] < 0)


## A pista passa por baixo d'água em algum trecho?
func has_underwater() -> bool:
	for s in sections:
		if s and s.kind == TrackSection.Kind.SUBMERSO:
			return true
	return false


## Algum kart pode ficar submerso (mergulho, ou cair no rio de um vale)?
func has_water_sections() -> bool:
	if has_underwater():
		return true
	for s in sections:
		if s and s.kind == TrackSection.Kind.VALE and s.valley_floor < water_level:
			return true
		if s and s.kind == TrackSection.Kind.RASO:
			return true
	return false


## Vistas (espaço local) de cada trecho especial para Race.warm_up compilar os shaders
## de lá: [{"xform": Transform3D, "under": debaixo d'água}].
func section_views() -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for s in sections:
		if s == null:
			continue
		var a := s.start * length
		var e := s.end * length
		var mid := (a + e) * 0.5
		match s.kind:
			TrackSection.Kind.VALE:
				var xf := get_transform_at(a - 6.0)
				views.append({"xform": Transform3D(xf.basis, xf.origin + Vector3.UP * 6.0), "under": false})
				# Olhando para a cabeceira do vale (cachoeira) e para o outro lado.
				for side: float in [-1.0, 1.0]:
					var b := xf.basis.rotated(Vector3.UP, side * 1.2)
					views.append({"xform": Transform3D(b, get_point_at(mid) + Vector3.UP * 4.0), "under": false})
			_:
				var xf := get_transform_at(mid)
				var under := s.kind == TrackSection.Kind.SUBMERSO
				views.append({"xform": Transform3D(xf.basis, xf.origin + Vector3.UP * 2.0), "under": under})
				var back := get_transform_at(a + 10.0)
				views.append({"xform": Transform3D(back.basis.rotated(Vector3.UP, 0.7), back.origin + Vector3.UP * 2.5), "under": under})
	return views


## Metros depois da beira do pouso de um vale (a primeira amostra com chão depois do
## vão) até a amostra `index`, ou -1 se ela não fica logo depois de um vale (até 250 m).
func past_gap(index: int) -> float:
	var n := samples.size()
	for span in gap_spans:
		var e: int = (int(span.to) + 1) % n
		var d := fposmod(distances[index] - distances[e], length)
		if d < 250.0:
			return d
	return -1.0


## Primeira amostra com chão depois do vale que contém `index` (ou `index`).
func gap_exit(index: int) -> int:
	for span in gap_spans:
		var from: int = span.from
		var to: int = span.to
		if index >= from - 1 and index <= to + 1:
			return (to + 1) % samples.size()
	return index


## O que o kart pisa (lateral em m, + = direita): Kart.Surface.
func surface_at(index: int, lateral: float) -> int:
	var kind := section_kind_at(index)
	if snow_track and kind != TrackSection.Kind.GELO:
		return Kart.Surface.NEVE
	if sand_track and kind != TrackSection.Kind.AREIA and kind != TrackSection.Kind.GELO:
		return Kart.Surface.AREIA_BATIDA
	if kind == TrackSection.Kind.RASO:
		return Kart.Surface.AGUA_RASA
	if kind == TrackSection.Kind.SELVA:
		return Kart.Surface.TERRA
	if beach_track and kind != TrackSection.Kind.AREIA and kind != TrackSection.Kind.GELO:
		# Tábuas da passarela: firmes como o asfalto.
		if index >= 0 and index < bridge_mask.size() and (bridge_mask[index] == 1 or bridge_mask[index] == 2):
			return Kart.Surface.ASFALTO
		return Kart.Surface.AREIA_BATIDA
	match kind:
		TrackSection.Kind.GELO:
			return Kart.Surface.GELO
		TrackSection.Kind.AREIA:
			var s := section_at(index)
			var along := distances[index]
			for pit in s.pits:
				var d := absf(wrapf(pit.x * length - along, -length * 0.5, length * 0.5))
				if d < pit.z and absf(lateral - pit.y) < pit.z:
					if Vector2(d, lateral - pit.y).length() < pit.z:
						return Kart.Surface.AREIA_MOVEDICA
			# Areia fofa nas bordas (perto das muretas).
			if absf(lateral) > road_width * 0.5 - SOFT_SAND_EDGE:
				return Kart.Surface.AREIA_FOFA
			return Kart.Surface.AREIA
	return Kart.Surface.ASFALTO


## Centro (espaço local) do redemoinho de areia movediça mais perto, ou Vector3.INF.
func pit_center(index: int, lateral: float) -> Vector4:
	var s := section_at(index)
	if s == null or s.kind != TrackSection.Kind.AREIA:
		return Vector4.INF
	var along := distances[index]
	for pit in s.pits:
		var d := wrapf(pit.x * length - along, -length * 0.5, length * 0.5)
		if absf(d) < pit.z + 1.0 and absf(lateral - pit.y) < pit.z + 1.0:
			var c := get_transform_at(pit.x * length, pit.y).origin
			return Vector4(c.x, c.y, c.z, pit.z)
	return Vector4.INF


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
## pesada; com a pista fora da árvore pode rodar numa thread, com `defer_physics` = true
## (a colisão fica para `finish_physics()`, na thread principal).
func build_geometry(defer_physics := false) -> void:
	_defer_physics = defer_physics
	_physics_jobs.clear()
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
		terrain.dune_cover = dune_cover
		terrain.mountain_start = mountain_start
		terrain.mountain_end = mountain_end
		terrain.sea_distance = sea_distance
		terrain.sea_depth = sea_depth
		terrain.land_spots = land_spots
		terrain.river_width = river_width
		terrain.river_depth = river_depth
		terrain.river_bank = river_bank
		terrain.river_valley = river_valley
		terrain.deck_half = road_width * 0.5 + shoulder_width + wall_thickness
		terrain.flat_distance = road_width * 0.5 + shoulder_width + wall_thickness + 2.5
		_setup_terrain_sections()
		terrain.setup(ground_samples, decoration_seed, bridge_mask, rivers)
		# A largada (arquibancada) fica num terreno plano.
		var start := get_point_at(0.0)
		terrain.flat_spots.append(Vector3(start.x, start.z, 55.0))
		if stadium_track:
			# O estádio inteiro (arquibancadas, torres e telão) num chão plano.
			terrain.flat_spots.append(Vector3(stadium_center.x, stadium_center.y,
					maxf(stadium_radii.x, stadium_radii.y) + TrackStadium.OUT_U + 16.0))
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
	if has_banks():
		_build_bank_decks()
	_build_start_gate()
	_build_boost_pads()
	if not ramps.is_empty():
		TrackRampBuilder.new(self, _generated).build()
	_build_item_boxes()
	_build_coins()
	_build_obstacles()
	if not bridge_spans.is_empty():
		TrackBridgeBuilder.new(self, terrain, _generated).build(preview)
	if not sections.is_empty():
		TrackSectionBuilder.new(self, terrain, _generated).build(preview)
	TrackScenery.new(self, terrain, _generated).build(preview)


## Cria a colisão guardada por `build_geometry(true)`. Na thread principal, com a pista
## ainda fora da árvore (os corpos entram no mundo da física junto com ela).
func finish_physics() -> void:
	for job in _physics_jobs:
		job.call()
	_physics_jobs.clear()
	_defer_physics = false


## Roda `job` (que cria formas, corpos ou áreas) agora ou, gerando numa thread, guarda
## para `finish_physics()`. As contas pesadas (as faces da colisão) ficam fora do job.
func physics_job(job: Callable) -> void:
	if _defer_physics:
		_physics_jobs.append(job)
	else:
		job.call()


## Passa ao terreno o que os trechos especiais mudam no chão: o fundo do lago/recife
## em volta do mergulho e do lago congelado, as dunas em volta da areia e as linhas
## dos vales (filhos Path3D "Vale").
func _setup_terrain_sections() -> void:
	var count := samples.size()
	terrain.basin_floor = PackedFloat32Array()
	terrain.basin_floor.resize(count)
	terrain.basin_floor.fill(INF)
	terrain.basin_radius = PackedFloat32Array()
	terrain.basin_radius.resize(count)
	terrain.basin_strength = PackedFloat32Array()
	terrain.basin_strength.resize(count)
	terrain.sand_strength = PackedFloat32Array()
	terrain.sand_strength.resize(count)
	terrain.jungle_strength = PackedFloat32Array()
	terrain.jungle_strength.resize(count)
	terrain.gap_edge = PackedByteArray()
	terrain.gap_edge.resize(count)
	for i in count:
		var sec := section_at(i)
		if sec == null:
			continue
		var f := section_blend[i]
		match sec.kind:
			TrackSection.Kind.SUBMERSO, TrackSection.Kind.RASO:
				terrain.basin_floor[i] = samples[i].y - 0.03
				terrain.basin_radius[i] = sec.basin
				terrain.basin_strength[i] = f
			TrackSection.Kind.GELO:
				if not sec.is_basin():
					continue
				terrain.basin_floor[i] = lerpf(samples[i].y - 0.03, water_level - 1.2, f * f)
				terrain.basin_radius[i] = sec.basin
				terrain.basin_strength[i] = f
			TrackSection.Kind.AREIA:
				terrain.sand_strength[i] = f
			TrackSection.Kind.SELVA:
				terrain.jungle_strength[i] = f
	# Perto das bordas do vão o chão fica firme só embaixo da pista: o penhasco começa
	# logo onde o asfalto acaba.
	var step := length / maxf(count, 1)
	var edge := int(ceil(22.0 / step))
	for span in gap_spans:
		for side: int in [span.from - 1, span.to + 1]:
			for k in range(-edge, edge + 1):
				terrain.gap_edge[(side + k + count) % count] = 1
	terrain.valleys.clear()
	var vale_paths := _valley_paths()
	for gi in gap_spans.size():
		if gi >= vale_paths.size():
			break
		var sec: TrackSection = gap_spans[gi].section
		var line := PackedVector2Array()
		var path := vale_paths[gi]
		var total := path.curve.get_baked_length()
		var steps := maxi(2, int(total / 3.0))
		for k in steps + 1:
			var p := path.transform * path.curve.sample_baked(total * k / steps)
			line.append(Vector2(p.x, p.z))
		var count_s := samples.size()
		var rim := maxf(samples[(int(gap_spans[gi].from) - 1 + count_s) % count_s].y,
				samples[(int(gap_spans[gi].to) + 1) % count_s].y) + 1.5
		terrain.valleys.append({"line": line, "half_top": sec.valley_width * 0.5,
				"half_bed": sec.valley_bed * 0.5, "floor": sec.valley_floor, "rim": rim, "plateau": sec.valley_plateau})


## Linhas do meio dos vales: filhos Path3D com nome começando por "Vale", na ordem.
func _valley_paths() -> Array[Path3D]:
	var paths: Array[Path3D] = []
	for child in get_children():
		if child is Path3D and String(child.name).begins_with("Vale") and child.curve and child.curve.point_count >= 2:
			paths.append(child)
	return paths


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
	if not ups.is_empty():
		var up := get_up_at(dist)
		return Transform3D(Basis.looking_at(t, up), p + get_right_at(dist) * lateral)
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
	section_of = PackedInt32Array()
	section_blend = PackedFloat32Array()
	gap_mask = PackedByteArray()
	gap_spans.clear()
	dune_crests = PackedFloat32Array()
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
	_apply_sections()
	_compute_frames()
	ups = PackedVector3Array()
	bank_angles = PackedFloat32Array()
	ground_samples = samples.duplicate()
	if not banks.is_empty():
		_apply_banks()


func _compute_frames() -> void:
	var count := samples.size()
	tangents = PackedVector3Array()
	rights = PackedVector3Array()
	for i in count:
		var t := (samples[(i + 1) % count] - samples[(i - 1 + count) % count]).normalized()
		tangents.append(t)
		var r := t.cross(Vector3.UP)
		r.y = 0.0
		rights.append(r.normalized())


## Curvas inclinadas: a borda de dentro fica onde estava e a pista gira em volta dela
## (o meio sobe e chega um pouco para dentro). Depois refaz tangentes e laterais e
## deita `rights`/`ups` junto com o chão.
func _apply_banks() -> void:
	var count := samples.size()
	bank_angles.resize(count)
	bank_angles.fill(0.0)
	for b in banks:
		if b == null or b.end <= b.start or b.angle <= 0.0:
			continue
		var a := b.start * length
		var e := b.end * length
		var dir := float(b.side)
		if dir == 0.0:
			# Lado de fora da curva: virando para a direita, o esquerdo sobe.
			var turn := 0.0
			for i in count:
				if distances[i] >= a and distances[i] <= e:
					turn += tangents[i].cross(tangents[(i + 1) % count]).y
			dir = -1.0 if turn < 0.0 else 1.0
		var full := deg_to_rad(b.angle) * dir
		for i in count:
			var s := distances[i]
			var f := 0.0
			if s >= a and s <= e:
				f = 1.0
			else:
				var before := fposmod(a - s, length)
				var after := fposmod(s - e, length)
				if before < b.ramp:
					f = _ease_bank(1.0 - before / b.ramp)
				elif after < b.ramp:
					f = _ease_bank(1.0 - after / b.ramp)
			# Somando (com o sinal) os trechos vizinhos emendam: de uma inclinação para a
			# outra sem voltar a ficar plana nem trocar de lado de repente.
			bank_angles[i] += full * f
	_smooth_banks()
	# Gira em volta de um ponto entre o meio e a borda de dentro (BANK_PIVOT): o meio
	# sobe só uma parte e a borda de dentro afunda um pouco, com o chão em volta (o
	# terreno segue `ground_samples`). Girando na borda de dentro o meio subia rápido
	# demais logo no começo da transição, antes de a pista deitar.
	var reach := road_width * 0.5 + shoulder_width
	for i in count:
		var ang := bank_angles[i]
		if ang == 0.0:
			continue
		var s := signf(ang)
		samples[i] += (rights[i] * (cos(ang) - 1.0) + Vector3.UP * sin(ang)) * reach * BANK_PIVOT * s
		ground_samples[i].y -= reach * (1.0 - BANK_PIVOT) * absf(sin(ang))
	_compute_frames()
	ups.resize(count)
	for i in count:
		var ang := bank_angles[i]
		if ang == 0.0:
			ups[i] = Vector3.UP
			continue
		var r := rights[i]
		var up0 := r.cross(tangents[i]).normalized()
		rights[i] = (r * cos(ang) + up0 * sin(ang)).normalized()
		ups[i] = (up0 * cos(ang) - r * sin(ang)).normalized()


## Transição suave (smootherstep): o giro começa e termina devagar, sem tranco.
static func _ease_bank(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


## Alisa a inclinação ao longo da pista (média gaussiana de ~BANK_SMOOTH m) e limita a
## 85°: some qualquer quina entre um trecho e outro.
func _smooth_banks() -> void:
	var count := bank_angles.size()
	var step := length / count
	var sigma := BANK_SMOOTH / step
	var reach := int(ceil(sigma * 2.5))
	var weights := PackedFloat32Array()
	for k in range(-reach, reach + 1):
		weights.append(exp(-0.5 * (k / sigma) * (k / sigma)))
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var sum := 0.0
		var wsum := 0.0
		for k in range(-reach, reach + 1):
			var w := weights[k + reach]
			sum += bank_angles[(i + k + count) % count] * w
			wsum += w
		var v := clampf(sum / wsum, -deg_to_rad(85.0), deg_to_rad(85.0))
		out[i] = v if absf(v) > 0.0005 else 0.0
	bank_angles = out


func has_banks() -> bool:
	return not ups.is_empty()


## "Cima" da pista na amostra `i` (Vector3.UP sem curvas inclinadas).
func up_at_index(i: int) -> Vector3:
	return ups[i] if not ups.is_empty() else Vector3.UP


func get_up_at(dist: float) -> Vector3:
	var count := samples.size()
	if ups.is_empty() or count == 0:
		return Vector3.UP
	var f := fposmod(dist, length) / (length / count)
	var i := int(f) % count
	return ups[i].slerp(ups[(i + 1) % count], f - floorf(f)).normalized()


func get_right_at(dist: float) -> Vector3:
	var count := samples.size()
	if count == 0:
		return Vector3.RIGHT
	if ups.is_empty():
		return get_direction_at(dist).cross(Vector3.UP).normalized()
	var f := fposmod(dist, length) / (length / count)
	var i := int(f) % count
	return rights[i].lerp(rights[(i + 1) % count], f - floorf(f)).normalized()


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


## Trechos especiais: o mergulho (a pista desce até `depth` m abaixo da água), o lago
## congelado (rente ao gelo), as dunas (sobe e desce) e o vale (amostras no ar, em
## linha reta da borda de um lado até a do outro).
func _apply_sections() -> void:
	var count := samples.size()
	section_of.resize(count)
	section_of.fill(-1)
	section_blend.resize(count)
	section_blend.fill(0.0)
	gap_mask.resize(count)
	gap_mask.fill(0)
	for si in sections.size():
		var sec := sections[si]
		if sec == null or sec.end <= sec.start:
			continue
		var a := sec.start * length
		var e := sec.end * length
		var target := water_level - sec.depth
		if sec.kind == TrackSection.Kind.GELO:
			target = water_level + ICE_ROAD_LIFT
		# No vale: a altura das bordas (para ligar as duas em linha reta).
		var ya := _height_at_distance(a)
		var ye := _height_at_distance(e)
		var dunes := maxi(1, roundi((e - a) / sec.dune_length))
		if sec.kind == TrackSection.Kind.AREIA and sec.dune_height > 0.0:
			for k in dunes:
				dune_crests.append(a + (e - a) * (k + 0.5) / dunes)
		var first := -1
		var last := -1
		for i in count:
			var s := distances[i]
			var f := 0.0
			if s >= a and s <= e:
				f = 1.0
			else:
				var before := fposmod(a - s, length)
				var after := fposmod(s - e, length)
				var reach := sec.ramp if sec.is_basin() else minf(sec.ramp, 25.0)
				if sec.kind != TrackSection.Kind.VALE:
					if before < reach:
						f = smoothstep(0.0, 1.0, 1.0 - before / reach)
					elif after < reach:
						f = smoothstep(0.0, 1.0, 1.0 - after / reach)
			if f <= 0.0:
				continue
			if f > section_blend[i] or section_of[i] < 0:
				section_of[i] = si
				section_blend[i] = f
			match sec.kind:
				TrackSection.Kind.SUBMERSO, TrackSection.Kind.GELO, TrackSection.Kind.RASO:
					# Riacho congelado (GELO sem lago): a pista fica na altura dela.
					if sec.is_basin():
						samples[i].y = lerpf(samples[i].y, target, f)
				TrackSection.Kind.AREIA:
					if f >= 1.0:
						var u := (s - a) / (e - a) * dunes
						samples[i].y += sec.dune_height * 0.5 * (1.0 - cos(TAU * u))
				TrackSection.Kind.VALE:
					if s > a and s < e:
						samples[i].y = lerpf(ya, ye, (s - a) / (e - a))
						gap_mask[i] = 1
						bridge_mask[i] = 3
						if first < 0:
							first = i
						last = i
		if sec.kind == TrackSection.Kind.VALE and first >= 0:
			gap_spans.append({"section": sec, "from": first, "to": last})


## Altura da pista (com pontes) a `dist` m da largada, interpolando as amostras.
func _height_at_distance(dist: float) -> float:
	var count := samples.size()
	var f := fposmod(dist, length) / (length / count)
	var i := int(f) % count
	return lerpf(samples[i].y, samples[(i + 1) % count].y, f - floorf(f))


func _compute_curvature() -> void:
	var count := samples.size()
	var step := length / count
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in count:
		var d := tangents[(i + 2) % count] - tangents[(i - 2 + count) % count]
		var r := rights[i]
		if not ups.is_empty():
			r = Vector3(r.x, 0.0, r.z).normalized()
		raw[i] = d.dot(r) / (step * 4.0)
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
## `colors` (uma por amostra) vai para COLOR. Não desenha os pedaços em que uma das
## pontas está em `skip` (padrão: o vão dos vales).
func _add_strip(md: MeshData, rail_a: PackedVector3Array, rail_b: PackedVector3Array,
		face_normals: PackedVector3Array, u_a: float, u_b: float, with_tangents := false,
		colors := PackedColorArray(), skip := PackedByteArray()) -> void:
	var count := samples.size()
	var base := md.verts.size()
	if skip.is_empty():
		skip = gap_mask
	for i in count + 1:
		var j := i % count
		var v := distances[j] if i < count else length
		md.add_vertex(rail_a[j], face_normals[j], Vector2(u_a, v))
		md.add_vertex(rail_b[j], face_normals[j], Vector2(u_b, v))
		if with_tangents:
			var t := (rail_b[j] - rail_a[j]).normalized()
			md.tangents.append_array([t.x, t.y, t.z, 1.0, t.x, t.y, t.z, 1.0])
		if not colors.is_empty():
			md.colors.append_array([colors[j], colors[j]])
	var skipping := skip.size() == count
	for i in count:
		if skipping and (skip[i] != 0 or skip[(i + 1) % count] != 0):
			continue
		var a := base + i * 2
		md.add_tri(a, a + 1, a + 2, face_normals[i])
		md.add_tri(a + 1, a + 3, a + 2, face_normals[i])


## Faixa lisa de `lat_a` a `lat_b`. Numa pista com curvas inclinadas ela é dividida em
## faixas estreitas: onde a pista torce, cada quadrado de 2 m × a largura toda deixa de
## ser plano e os dois triângulos formariam uma quina de ~10 cm (o kart pulava nela).
func _add_split_strip(md: MeshData, lat_a: float, lat_b: float, height: float, u_a: float, u_b: float,
		with_tangents := false, colors := PackedColorArray(), skip := PackedByteArray()) -> void:
	var cols := 1 if ups.is_empty() else maxi(1, ceili(absf(lat_b - lat_a) / BANK_STRIP_WIDTH))
	var normals := _repeat(Vector3.UP)
	for c in cols:
		var t0 := float(c) / cols
		var t1 := float(c + 1) / cols
		_add_strip(md, _offset_rail(lerpf(lat_a, lat_b, t0), height), _offset_rail(lerpf(lat_a, lat_b, t1), height),
				normals, lerpf(u_a, u_b, t0), lerpf(u_a, u_b, t1), with_tangents, colors, skip)


func _offset_rail(lateral: float, height: float) -> PackedVector3Array:
	var rail := PackedVector3Array()
	for i in samples.size():
		rail.append(samples[i] + rights[i] * lateral + up_at_index(i) * height)
	return rail


## Trilho com deslocamento lateral diferente em cada amostra.
func _variable_rail(laterals: PackedFloat32Array, height: float) -> PackedVector3Array:
	var rail := PackedVector3Array()
	for i in samples.size():
		rail.append(samples[i] + rights[i] * laterals[i] + up_at_index(i) * height)
	return rail


func _repeat(v: Vector3) -> PackedVector3Array:
	if v == Vector3.UP and not ups.is_empty():
		return ups.duplicate()
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
	for i in rights.size():
		arr.append((up_at_index(i) * run - rights[i] * side * rise).normalized())
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
	var special := []
	for s in sections:
		if s:
			special.append([s.kind, s.start, s.end, s.ramp, s.depth, s.basin, s.dune_height, s.dune_length,
					s.valley_width, s.valley_floor, s.valley_bed, s.valley_plateau])
	for path in _valley_paths():
		special.append(path.curve.get_baked_length())
		special.append(path.curve.sample_baked(0.0))
	return var_to_str([track_id, scenery, samples.size(), length, sum, bridged, river_points, river_sum, special,
			decoration_seed, water_level, hill_height, hill_bias, mountain_height, terrace_step, dune_cover, mountain_start, mountain_end,
			sea_distance, river_width, river_depth, river_bank, river_valley, road_width,
			shoulder_width, wall_thickness, sea_depth, land_spots, beach_track, stadium_track, stadium_center, stadium_radii, city_track])


## Chão em volta da pista. Devolve a malha (gerada aqui ou a `mesh` do cache).
func _build_ground(preview: bool, mesh: Mesh = null) -> Mesh:
	if mesh == null:
		var mat := ShaderMaterial.new()
		mat.shader = TERRAIN_SHADER
		mat.set_shader_parameter("water_level", water_level)
		var params := TrackTheme.terrain_params(scenery)
		if beach_track:
			params.merge(TrackTheme.beach_terrain_params(), true)
		if city_track:
			params.merge(TrackTheme.city_terrain_params(), true)
		for key: String in params:
			mat.set_shader_parameter(key, params[key])
		# Grade com células de ~2,8 m perto da pista (pistas compridas ganham mais linhas).
		var inner_half := terrain.half_extent + Vector2(120.0, 120.0)
		var cell := 5.6 if preview else 3.0
		var res := Vector2i(int(inner_half.x / (0.36 * cell)), int(inner_half.y / (0.36 * cell)))
		mesh = terrain.build_mesh(res, inner_half, 1250.0, mat)
	var ground := _add_mesh(mesh)
	ground.name = "Terreno"
	# O chão não projeta sombra: a malha inteira entraria em todas as cascatas de
	# sombra do sol (centenas de milhares de triângulos) quase sem efeito visível.
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if with_collision and _is_flat():
		# O kart nunca sai das muretas: o chão de colisão é só um plano (grama = "offroad").
		# Pista com subidas, mergulho ou vale usa a faixa de colisão da pista (veja
		# _build_road): o plano atrapalharia (a pista passa abaixo dele) ou seguraria
		# quem cai no vale.
		var center := terrain.center
		physics_job(func() -> void:
			var shape := BoxShape3D.new()
			shape.size = Vector3(1800.0, 2.0, 1800.0)
			_add_static_body(shape, Transform3D(Basis(), Vector3(center.x, -1.0, center.y)), "offroad"))
	return mesh


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2600.0, 2600.0)
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("noise_tex", NOISE_TEXTURE)
	var params := TrackTheme.water_params(scenery)
	if beach_track:
		params.merge(TrackTheme.beach_water_params(), true)
		params["sun_dir"] = _sun_dir()
	if city_track:
		params.merge(TrackTheme.city_water_params(), true)
		params["sun_dir"] = _sun_dir()
	for key: String in params:
		mat.set_shader_parameter(key, params[key])
	plane.material = mat
	var center := Vector3(terrain.center.x, water_level, terrain.center.y)
	var area := _bank_safe_water_area()
	if area.size != Vector2.ZERO:
		# Com curvas inclinadas o chão afunda embaixo delas (abaixo do nível da água):
		# a água fica só onde ela existe de verdade (vales e rios), longe dessas curvas.
		plane.size = area.size
		center = Vector3(area.get_center().x, water_level, area.get_center().y)
	var water := _add_mesh(plane, Transform3D(Basis(), center))
	water.name = "Agua"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Retângulo (x, z) da água numa pista com curvas inclinadas e sem mar: os vales e rios
## com folga. Vazio = a água cobre o mapa todo, como nas outras pistas.
func _bank_safe_water_area() -> Rect2:
	if not has_banks() or sea_distance > 0.0:
		return Rect2()
	var pts := PackedVector2Array()
	for path in _valley_paths() + _river_paths():
		for k in path.curve.point_count:
			var p := path.transform * path.curve.get_point_position(k)
			pts.append(Vector2(p.x, p.z))
	if pts.is_empty():
		return Rect2()
	var area := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		area = area.expand(p)
	return area.grow(WATER_AREA_MARGIN)


## Cor de cada amostra para o asfalto (COLOR): r = areia batida (na praia, a terra da
## trilha da mata), g = debaixo d'água (algas e cáusticas; na praia, o fundo do baixio),
## b = gelo (na praia, as tábuas das passarelas).
func _road_colors() -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(samples.size())
	for i in samples.size():
		var c := Color(0.0, 0.0, 0.0, 1.0)
		if beach_track and (bridge_mask[i] == 1 or bridge_mask[i] == 2):
			c.b = 1.0
		var sec := section_at(i)
		if sec:
			var f := section_blend[i]
			match sec.kind:
				TrackSection.Kind.AREIA, TrackSection.Kind.SELVA:
					c.r = f
				TrackSection.Kind.SUBMERSO:
					c.g = smoothstep(water_level + 0.4, water_level - 1.6, samples[i].y)
				TrackSection.Kind.RASO:
					# O fundo molhado começa um pouco antes da água (areia da beirada).
					c.g = smoothstep(water_level + 0.5, water_level - 0.1, samples[i].y)
				TrackSection.Kind.GELO:
					c.b = f
		colors[i] = c
	return colors


func _build_road() -> void:
	var half := road_width * 0.5
	var md := MeshData.new()
	var colors := _road_colors()
	_add_split_strip(md, -half, half, 0.0, 0.0, 1.0, true, colors)
	# Laterais do asfalto (dão volume quando a pista tem subidas).
	_add_strip(md, _offset_rail(-half, 0.0), _offset_rail(-half, -0.6), _scaled_rights(-1.0), 0.0, 0.0, true, colors)
	_add_strip(md, _offset_rail(half, 0.0), _offset_rail(half, -0.6), _scaled_rights(1.0), 1.0, 1.0, true, colors)
	var mat := ShaderMaterial.new()
	if snow_track:
		mat.shader = SNOW_ROAD_SHADER
		mat.set_shader_parameter("sun_dir", _sun_dir())
		mat.set_shader_parameter("noise_tex", NOISE_TEXTURE)
	elif sand_track:
		mat.shader = SAND_ROAD_SHADER
		mat.set_shader_parameter("noise_tex", NOISE_TEXTURE)
		mat.set_shader_parameter("soft_edge", SOFT_SAND_EDGE)
	elif beach_track:
		mat.shader = BEACH_ROAD_SHADER
		mat.set_shader_parameter("noise_tex", NOISE_TEXTURE)
		mat.set_shader_parameter("soft_edge", SOFT_SAND_EDGE)
	else:
		mat.shader = ROAD_SHADER
		mat.set_shader_parameter("curb_min", curb_min_width)
		mat.set_shader_parameter("soft_edge", SOFT_SAND_EDGE)
		if city_track:
			# Asfalto escuro e molhado, faixas acesas em ciano e o logo da largada em magenta.
			mat.set_shader_parameter("asphalt_light", Color(0.2, 0.2, 0.25))
			mat.set_shader_parameter("asphalt_dark", Color(0.1, 0.1, 0.13))
			mat.set_shader_parameter("line_color", Color(0.3, 0.95, 1.0))
			mat.set_shader_parameter("paint_accent", Color(1.0, 0.25, 0.8))
			mat.set_shader_parameter("wet", 0.75)
			mat.set_shader_parameter("line_glow", 0.9)
	mat.set_shader_parameter("road_width", road_width)
	mat.set_shader_parameter("track_length", length)
	mat.set_shader_parameter("logo_texture", LOGO_ICON)
	var road := _add_mesh(md.to_mesh(mat))
	road.name = "Neve" if snow_track else ("Areia" if sand_track or beach_track else "Asfalto")
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if with_collision and not _is_flat():
		# Pista com subidas/pontes: o chão de colisão acompanha a pista de mureta a
		# mureta (asfalto + acostamento), senão o kart cairia no acostamento elevado.
		var reach := half + shoulder_width + 0.15
		var col := MeshData.new()
		_add_split_strip(col, -reach, reach, 0.0, 0.0, 1.0)
		var faces := col.collision_faces()
		physics_job(func() -> void:
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(faces)
			_add_static_body(shape, Transform3D.IDENTITY, "road"))


## Zebras em relevo nas duas bordas, mais largas do lado de dentro das curvas.
## Na pista de neve, uma leira baixa de neve empurrada no lugar delas.
func _build_curbs() -> void:
	if snow_track:
		_build_snow_lips()
		return
	if sand_track:
		_build_sand_lips()
		return
	if beach_track:
		# Na praia a pista é a própria areia: sem zebras.
		return
	var half := road_width * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = CURB_SHADER
	if city_track:
		# Zebras de neon: magenta aceso e blocos escuros.
		mat.set_shader_parameter("color_a", Color(1.0, 0.12, 0.7))
		mat.set_shader_parameter("color_b", Color(0.07, 0.07, 0.11))
		mat.set_shader_parameter("glow", 1.3)
	var md := MeshData.new()
	# Sem zebras nas dunas (nem no vão do vale).
	var skip := gap_mask.duplicate()
	for i in samples.size():
		var sec := section_at(i)
		if sec and sec.kind == TrackSection.Kind.AREIA and section_blend[i] > 0.15:
			skip[i] = 1
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
		_add_strip(md, r0, r1, _slope_normals(side, 0.22, top), 0.0, 0.15, false, PackedColorArray(), skip)
		_add_strip(md, r1, r2, _repeat(Vector3.UP), 0.15, 0.95, false, PackedColorArray(), skip)
		_add_strip(md, r2, r3, _slope_normals(side, 0.07, -0.045), 0.95, 1.0, false, PackedColorArray(), skip)
		_add_strip(md, r3, r4, _scaled_rights(side), 1.0, 1.0, false, PackedColorArray(), skip)
	var curbs := _add_mesh(md.to_mesh(mat))
	curbs.name = "Zebras"
	curbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Muretas da cidade: placas de LED acesas em roxo, magenta, azul-noite e o amarelo da
## marca, com a base escura.
## A face de fora (vista de baixo do elevado) fica escura, com pouco brilho.
static func _city_wall_colors(mat: ShaderMaterial, outer := false) -> void:
	mat.set_shader_parameter("brand_blue", Color(0.32, 0.08, 0.62))
	mat.set_shader_parameter("brand_light", Color(1.0, 0.25, 0.85))
	mat.set_shader_parameter("navy", Color(0.03, 0.03, 0.09))
	mat.set_shader_parameter("trim_color", Color(0.78, 0.9, 1.0))
	mat.set_shader_parameter("base_color", Color(0.05, 0.05, 0.08))
	mat.set_shader_parameter("glow", 0.45)
	if outer:
		mat.set_shader_parameter("brand_blue", Color(0.14, 0.05, 0.3))
		mat.set_shader_parameter("trim_color", Color(0.12, 0.12, 0.18))
		mat.set_shader_parameter("glow", 0.25)


## Muretas com placas. Na pista de neve elas ficam só na colisão (invisíveis) e o que
## aparece são barrancos de neve (`_build_snow_banks`).
func _build_walls() -> void:
	if snow_track:
		_build_snow_banks()
	elif sand_track:
		_build_sand_banks()
	elif beach_track:
		TrackBeach.new(self, terrain, _generated).build_fences()
	var outer_mat := ShaderMaterial.new()
	outer_mat.shader = WALL_SHADER
	outer_mat.set_shader_parameter("outer_side", true)
	outer_mat.set_shader_parameter("wall_height", wall_height)
	if city_track:
		_city_wall_colors(outer_mat, true)
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
		if city_track:
			_city_wall_colors(inner_mat)
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
		if not snow_track and not sand_track and not beach_track:
			var wall := _add_mesh(face.to_mesh(inner_mat))
			wall.name = "Mureta"
			_add_mesh(rest.to_mesh(outer_mat))
		if not with_collision:
			continue
		var faces := face.collision_faces()
		faces.append_array(rest.collision_faces())
		physics_job(func() -> void:
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(faces)
			_add_static_body(shape, Transform3D.IDENTITY, "wall"))


# --- Curvas inclinadas ---------------------------------------------------------------

## Nas curvas inclinadas o terreno fica lá embaixo: o acostamento vira laje de concreto
## deitada junto com a pista e, do lado que sobe, uma parede fecha tudo até o chão.
func _build_bank_decks() -> void:
	var count := samples.size()
	var half := road_width * 0.5
	var offset := half + shoulder_width
	var outer := offset + wall_thickness
	var flat := PackedByteArray()
	flat.resize(count)
	for i in count:
		flat[i] = 1 if bank_angles[i] == 0.0 else 0
	var deck := MeshData.new()
	var skirt := MeshData.new()
	for side: float in [-1.0, 1.0]:
		_add_split_strip(deck, side * (half - 0.05), side * (offset + 0.05), -0.02, 0.0, 1.0, false, PackedColorArray(), flat)
		# Parede embaixo da borda que sobe (só onde este lado está acima do chão).
		var skip := flat.duplicate()
		var bottom := PackedVector3Array()
		var normals := PackedVector3Array()
		for i in count:
			if signf(bank_angles[i]) != side:
				skip[i] = 1
			var r := Vector3(rights[i].x, 0.0, rights[i].z).normalized()
			var g := ground_samples[i] + r * side * outer
			g.y = ground_samples[i].y - 1.5
			bottom.append(g)
			normals.append(r * side)
		_add_strip(skirt, _offset_rail(side * outer, -0.3), bottom, normals, 0.0, 1.0, false, PackedColorArray(), skip)
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.13, 0.13, 0.17) if city_track else Color(0.5, 0.5, 0.52)
	deck_mat.roughness = 0.55 if city_track else 0.85
	var deck_mi := _add_mesh(deck.to_mesh(deck_mat))
	deck_mi.name = "LajeInclinada"
	deck_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skirt_mat := ShaderMaterial.new()
	skirt_mat.shader = WALL_SHADER
	skirt_mat.set_shader_parameter("outer_side", true)
	skirt_mat.set_shader_parameter("wall_height", wall_height)
	if city_track:
		_city_wall_colors(skirt_mat, true)
	var skirt_mi := _add_mesh(skirt.to_mesh(skirt_mat))
	skirt_mi.name = "ParedeInclinada"


# --- Pista de neve e gelo -----------------------------------------------------------

## Perfil do barranco de neve: (para fora da linha da mureta, altura) em m.
const SNOW_BANK_PROFILE := [Vector2(-0.75, -0.3), Vector2(-0.6, 0.04), Vector2(-0.42, 0.3),
		Vector2(-0.2, 0.6), Vector2(0.05, 0.88), Vector2(0.32, 1.06), Vector2(0.62, 1.15),
		Vector2(0.95, 1.1), Vector2(1.28, 0.92), Vector2(1.62, 0.6), Vector2(2.0, 0.2), Vector2(2.45, -0.3)]
## Perfil da leira de neve na borda da pista: (para fora da borda, altura) em m.
const SNOW_LIP_PROFILE := [Vector2(-0.85, 0.012), Vector2(-0.5, 0.045), Vector2(-0.2, 0.085),
		Vector2(0.1, 0.1), Vector2(0.45, 0.055), Vector2(0.8, -0.05)]


## Direção (espaço da pista) para o sol: o DirectionalLight3D filho da pista ilumina
## para o -Z dele.
func _sun_dir() -> Vector3:
	for child in get_children():
		if child is DirectionalLight3D:
			return (child as DirectionalLight3D).transform.basis.z.normalized()
	return Vector3(0.43, 0.64, 0.63)


## Escala de cada amostra que faz o monte de neve subir e descer devagar (calombos).
func _snow_lumps(side: float, base: float, amp: float) -> PackedFloat32Array:
	var arr := PackedFloat32Array()
	arr.resize(samples.size())
	for i in samples.size():
		var d := distances[i]
		arr[i] = base + amp * (0.4 * sin(d * 0.083 + side * 1.3) + 0.3 * sin(d * 0.29 + side * 2.1)
				+ 0.2 * sin(d * 0.97 + side * 0.4) + 0.1 * sin(d * 1.31 + side * 3.3))
	return arr


## Faixa com um perfil (pontos (para fora, altura) a partir de `base` m do centro, do
## lado `side`) ao longo da pista, com normais suaves e tangentes. UV.x = metros pelo
## perfil, UV.y = metros ao longo; COLOR por amostra. Pula o vão dos vales. `bump` (m)
## empurra os pontos de dentro do perfil para fora/dentro em calombos irregulares (as
## normais são refeitas pela malha, então a luz pega nos calombos).
func _add_profile(md: MeshData, side: float, base: float, profile: Array,
		scale_h: PackedFloat32Array, scale_w: PackedFloat32Array, colors: PackedColorArray, bump := 0.0) -> void:
	var count := samples.size()
	var cols := profile.size()
	var first := md.verts.size()
	for i in count + 1:
		var j := i % count
		var v := distances[j] if i < count else length
		var out := rights[j] * side
		var arc := 0.0
		var prev := Vector2.ZERO
		for c in cols:
			var raw: Vector2 = profile[c]
			var pr := Vector2(raw.x * scale_w[j], raw.y * scale_h[j])
			if c > 0:
				arc += pr.distance_to(prev)
			prev = pr
			var a: Vector2 = profile[maxi(c - 1, 0)]
			var b: Vector2 = profile[mini(c + 1, cols - 1)]
			var t := Vector2((b.x - a.x) * scale_w[j], (b.y - a.y) * scale_h[j]).normalized()
			var n2 := Vector2(-t.y, t.x)
			var normal := (out * n2.x + Vector3.UP * n2.y).normalized()
			var pos := samples[j] + out * (base + pr.x) + Vector3.UP * pr.y
			if bump > 0.0 and c > 0 and c < cols - 1:
				var d := distances[j] + side * 37.0
				var fc := float(c)
				pos += normal * bump * (0.45 * sin(d * 0.62 + fc * 1.3) + 0.35 * sin(d * 1.17 + fc * 2.9)
						+ 0.2 * sin(d * 1.53 + fc * 0.7))
			md.add_vertex(pos, normal, Vector2(arc, v))
			var tw := (out * t.x + Vector3.UP * t.y).normalized()
			md.tangents.append_array([tw.x, tw.y, tw.z, 1.0])
			md.colors.append(colors[j])
	if bump > 0.0:
		# Normais pela malha (com os calombos), viradas para o lado da do perfil.
		var rows := count + 1
		var fresh := PackedVector3Array()
		fresh.resize(rows * cols)
		for i in rows:
			for c in cols:
				var k := first + i * cols + c
				var across := md.verts[first + i * cols + mini(c + 1, cols - 1)] - md.verts[first + i * cols + maxi(c - 1, 0)]
				var i0 := maxi(i - 1, 0)
				var i1 := mini(i + 1, rows - 1)
				var along := md.verts[first + i1 * cols + c] - md.verts[first + i0 * cols + c]
				var n := across.cross(along).normalized()
				if n.dot(md.normals[k]) < 0.0:
					n = -n
				fresh[i * cols + c] = n if n.length_squared() > 0.5 else md.normals[k]
		for k in fresh.size():
			md.normals[first + k] = fresh[k]
	var skipping := gap_mask.size() == count
	for i in count:
		if skipping and (gap_mask[i] != 0 or gap_mask[(i + 1) % count] != 0):
			continue
		for c in cols - 1:
			var a := first + i * cols + c
			var b := a + cols
			md.add_tri(a, a + 1, b, md.normals[a])
			md.add_tri(a + 1, b + 1, b, md.normals[a])


## Quanto de rio congelado em cada amostra (para o pé dos montes de neve virar gelo).
func _ice_colors() -> PackedColorArray:
	var road := _road_colors()
	var out := PackedColorArray()
	out.resize(road.size())
	for i in road.size():
		out[i] = Color(road[i].b, 0.0, 0.0)
	return out


## Barrancos de neve na linha das muretas (só visual; a colisão é a da mureta). Nas
## pontes o lado de fora fica mais curto (não passa muito da beira do tabuleiro).
func _build_snow_banks() -> void:
	var offset := road_width * 0.5 + shoulder_width
	var colors := _ice_colors()
	for side: float in [-1.0, 1.0]:
		var heights := _snow_lumps(side, 1.1, 0.3)
		var widths := _snow_lumps(-side, 1.0, 0.18)
		var md := MeshData.new()
		var profile: Array = SNOW_BANK_PROFILE
		_add_profile(md, side, offset, profile, heights, widths, colors, 0.16)
		if not bridge_spans.is_empty():
			# Em cima das pontes: o perfil some para dentro da beira do tabuleiro.
			var cols := profile.size()
			for i in samples.size():
				if bridge_mask[i] == 0 or bridge_mask[i] == 3:
					continue
				for c in cols:
					var raw: Vector2 = profile[c]
					if raw.x <= 0.5:
						continue
					var k := i * cols + c
					var pull := (raw.x - 0.5) * widths[i] * 0.6
					md.verts[k] -= rights[i] * side * pull
		var mat := ShaderMaterial.new()
		mat.shader = SNOW_BANK_SHADER
		mat.set_shader_parameter("sun_dir", _sun_dir())
		mat.set_shader_parameter("noise_tex", NOISE_TEXTURE)
		mat.set_shader_parameter("mirror", -side)
		mat.set_shader_parameter("wordmark", WORDMARK)
		mat.set_shader_parameter("wordmark_aspect", float(WORDMARK.get_width()) / WORDMARK.get_height())
		var bank := _add_mesh(md.to_mesh(mat))
		bank.name = "MonteDeNeve"


## Leira baixa de neve empurrada nas duas bordas da pista (no lugar das zebras).
func _build_snow_lips() -> void:
	var half := road_width * 0.5
	var colors := _ice_colors()
	var md := MeshData.new()
	for side: float in [-1.0, 1.0]:
		# Montinhos que somem aqui e ali (a leira não é uma faixa contínua).
		var heights := _snow_lumps(side * 3.0, 0.6, 0.8)
		for i in heights.size():
			heights[i] = maxf(heights[i], 0.05)
		_add_profile(md, side, half, SNOW_LIP_PROFILE, heights, _snow_lumps(side * 5.0, 1.0, 0.2), colors, 0.025)
	var mat := ShaderMaterial.new()
	mat.shader = SNOW_BANK_SHADER
	mat.set_shader_parameter("sun_dir", _sun_dir())
	mat.set_shader_parameter("noise_tex", NOISE_TEXTURE)
	mat.set_shader_parameter("lip", true)
	var lips := _add_mesh(md.to_mesh(mat))
	lips.name = "LeiraDeNeve"
	lips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Pista de areia (deserto) ---------------------------------------------------------

## Perfil do monte de areia: (para fora da linha da mureta, altura) em m. Mais largo e
## baixo que o de neve, com a face de fora comprida (como uma duna pequena).
const SAND_BANK_PROFILE := [Vector2(-0.95, -0.3), Vector2(-0.78, 0.03), Vector2(-0.52, 0.3),
		Vector2(-0.22, 0.64), Vector2(0.12, 0.95), Vector2(0.48, 1.14), Vector2(0.85, 1.2),
		Vector2(1.3, 1.1), Vector2(1.85, 0.86), Vector2(2.45, 0.52), Vector2(3.1, 0.2), Vector2(3.8, -0.3)]
## Leira de areia empurrada na borda da pista.
const SAND_LIP_PROFILE := [Vector2(-0.9, 0.01), Vector2(-0.55, 0.04), Vector2(-0.22, 0.08),
		Vector2(0.1, 0.095), Vector2(0.5, 0.05), Vector2(0.85, -0.05)]


## Cor de cada amostra para os montes de areia: r = debaixo d'água, g = dunas.
func _sand_colors() -> PackedColorArray:
	var road := _road_colors()
	var out := PackedColorArray()
	out.resize(road.size())
	for i in road.size():
		out[i] = Color(road[i].g, road[i].r, 0.0)
	return out


## Em cima das pontes o perfil do monte some para dentro da beira do tabuleiro (os
## pontos com x > 0,5 m são puxados para dentro).
func _pull_profile_on_bridges(md: MeshData, first: int, profile: Array, widths: PackedFloat32Array, side: float) -> void:
	if bridge_spans.is_empty():
		return
	var cols := profile.size()
	for i in samples.size():
		if bridge_mask[i] == 0 or bridge_mask[i] == 3:
			continue
		for c in cols:
			var raw: Vector2 = profile[c]
			if raw.x <= 0.5:
				continue
			var k := first + i * cols + c
			md.verts[k] -= rights[i] * side * (raw.x - 0.5) * widths[i] * 0.75


## Montes de areia na linha das muretas (só visual; a colisão é a da mureta), com um
## bloco de arenito entalhado (marca da Ativos e hieróglifos) a cada trecho.
func _build_sand_banks() -> void:
	var offset := road_width * 0.5 + shoulder_width
	var colors := _sand_colors()
	for side: float in [-1.0, 1.0]:
		var heights := _snow_lumps(side * 1.7, 1.0, 0.22)
		var widths := _snow_lumps(-side * 2.3, 1.0, 0.22)
		var md := MeshData.new()
		_add_profile(md, side, offset, SAND_BANK_PROFILE, heights, widths, colors, 0.1)
		_pull_profile_on_bridges(md, 0, SAND_BANK_PROFILE, widths, side)
		var mat := ShaderMaterial.new()
		mat.shader = SAND_BANK_SHADER
		mat.set_shader_parameter("noise_tex", NOISE_TEXTURE)
		mat.set_shader_parameter("glyph_tex", GLYPHS)
		mat.set_shader_parameter("mirror", -side)
		mat.set_shader_parameter("wordmark", WORDMARK)
		mat.set_shader_parameter("wordmark_aspect", float(WORDMARK.get_width()) / WORDMARK.get_height())
		var bank := _add_mesh(md.to_mesh(mat))
		bank.name = "MonteDeAreia"


## Leira baixa de areia empurrada nas duas bordas da pista (no lugar das zebras).
func _build_sand_lips() -> void:
	var half := road_width * 0.5
	var colors := _sand_colors()
	var md := MeshData.new()
	for side: float in [-1.0, 1.0]:
		var heights := _snow_lumps(side * 2.6, 0.7, 0.7)
		for i in heights.size():
			heights[i] = maxf(heights[i], 0.08)
		_add_profile(md, side, half, SAND_LIP_PROFILE, heights, _snow_lumps(side * 4.0, 1.0, 0.25), colors, 0.02)
	var mat := ShaderMaterial.new()
	mat.shader = SAND_BANK_SHADER
	mat.set_shader_parameter("noise_tex", NOISE_TEXTURE)
	mat.set_shader_parameter("glyph_tex", GLYPHS)
	mat.set_shader_parameter("lip", true)
	var lips := _add_mesh(md.to_mesh(mat))
	lips.name = "LeiraDeAreia"
	lips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Pórtico de largada: colunas azuis, viga com a marca da Ativos dos dois lados
## e faixa quadriculada embaixo.
func _build_start_gate() -> void:
	var gate := Node3D.new()
	gate.name = "Largada"
	gate.transform = get_transform_at(0.0)
	_generated.add_child(gate)
	if scenery == TrackTheme.Scenery.DESERTO:
		# No deserto, um portal de templo egípcio (veja track_egypt.gd).
		TrackEgypt.new(self, terrain, _generated).build_start_gate(gate)
		return
	if beach_track:
		# Na praia, um portal de bambu com telhado de sapê (veja track_beach.gd).
		TrackBeach.new(self, terrain, _generated).build_start_gate(gate)
		return
	if stadium_track:
		# No estádio, um pórtico de treliça com placar e luzes de largada.
		TrackStadium.new(self, terrain, _generated).build_start_gate(gate)
		return
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
	for side: float in [-1.0, 1.0]:
		var xf := Transform3D(Basis(), Vector3(side * half, 3.7, 0.0))
		_add_mesh(pillar, xf, gate)
		_add_mesh(ring, Transform3D(Basis(), Vector3(side * half, 0.15, 0.0)), gate)
		_add_mesh(ring, Transform3D(Basis(), Vector3(side * half, 4.6, 0.0)), gate)
	if with_collision:
		physics_job(func() -> void:
			var pillar_shape := CylinderShape3D.new()
			pillar_shape.radius = 0.7
			pillar_shape.height = 7.4
			for side: float in [-1.0, 1.0]:
				_add_static_body(pillar_shape, Transform3D(Basis(), Vector3(side * half, 3.7, 0.0)), "wall", gate))
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
	var pads: Array[Node3D] = []
	for frac in boost_pads:
		var pad := Node3D.new()
		pad.name = "Turbo"
		pad.transform = get_transform_at(wrapf(frac, 0.0, 1.0) * length)
		var mi := _add_mesh(pad_mesh, Transform3D.IDENTITY, pad)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_generated.add_child(pad)
		pads.append(pad)
	if with_collision and not pads.is_empty():
		physics_job(func() -> void:
			var shape := BoxShape3D.new()
			shape.size = Vector3(w, 1.6, l)
			for pad in pads:
				var area := Area3D.new()
				area.name = "Toque"
				var col := CollisionShape3D.new()
				col.shape = shape
				col.position.y = 0.8
				area.add_child(col)
				area.body_entered.connect(_on_boost_pad_body_entered)
				pad.add_child(area))


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
			box.setup(mesh, shadow, tilt)
			holder.add_child(box)
			if with_collision:
				physics_job(box.add_touch_area)


## Moedas Ativos (veja track_coins.gd): as fileiras de `coin_lines` e um arco de três
## moedas no pulo de cada rampa.
func _build_coins() -> void:
	var points := PackedVector3Array()
	var dirs := PackedVector3Array()
	# Ponto do asfalto embaixo de cada moeda (para a sombra).
	var grounds := PackedVector3Array()
	for line in coin_lines:
		var count := maxi(int(line.z), 1)
		var center := wrapf(line.x, 0.0, 1.0) * length
		for i in count:
			var d := center + (i - (count - 1) * 0.5) * coin_spacing
			if _on_ramp(d):
				continue
			var xf := get_transform_at(d, line.y)
			points.append(xf.origin + xf.basis.y * TrackCoins.HEIGHT)
			dirs.append(get_direction_at(d))
			grounds.append(xf.origin)
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
						grounds.append(gp)
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
				grounds.append(xf.origin)
	if points.is_empty():
		return
	coins = TrackCoins.new()
	coins.name = "MoedasAtivos"
	coins.setup(points, dirs, with_collision, grounds)
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
