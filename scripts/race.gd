extends Node3D
## Controla a corrida: monta o grid (jogadores + adversários do computador), faz a
## contagem, conta voltas e posições de cada kart, mostra a contramão e, na chegada,
## a classificação.
##
## Até 4 jogadores na mesma tela (dividida, veja SplitScreen), nos três modos
## (GameState.mode): Grand Prix (copa de 4 corridas com pontos), Corrida (avulsa,
## com ou sem adversários) e Contra-relógio (sem adversários, com o fantasma do
## recorde da pista). A classe de velocidade (50/100/150cc) vale para todos os karts.
##
## A pista traz as moedas Ativos (Track.coins) e os obstáculos que se mexem
## (Track.obstacles, com o relógio acertado pela largada: o padrão é o mesmo em toda
## corrida). Aqui ficam as marcas de pneu (SkidMarks) e os sons/avisos de cada jogador.
##
## Os itens das caixas (roleta, slot, Deságio, Juridiquês, Cessão de crédito) ficam em
## RaceItems, filho desta cena.
##
## Música (GameState.music): a trilha do cenário da pista entra no "VAI!", acelera
## quando o primeiro jogador chega na volta final e vira a do pódio no fim.

enum State { COUNTDOWN, RACING, FINISHED }

const KART_SCENE := preload("res://scenes/kart.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
## Distância (m) entre a primeira fila do grid e a linha de chegada.
const GRID_OFFSET := 10.0
## Distância entre as filas do grid (m); a coluna da direita fica meia fila atrás.
const GRID_ROW := 6.5
## Distância (m) de cada coluna do grid até o meio da pista.
const GRID_SIDE := 3.4
const INTRO_TIME := 3.2
## Habilidade (mín, máx) e velocidade máxima em m/s (mín, máx, em 100cc) dos
## adversários em cada dificuldade (GameState.difficulty). Para comparar: o Celerino
## no Kart Padrão chega a 27,1 m/s. A velocidade do kart do adversário pesa só um
## pouco (STAT_SPEED_WEIGHT), senão quem pega o Relâmpago dispara.
const DIFFICULTY := [
	{"skill": Vector2(0.15, 0.5), "speed": Vector2(20.8, 22.4)},
	{"skill": Vector2(0.3, 0.8), "speed": Vector2(22.4, 24.0)},
	{"skill": Vector2(0.6, 1.0), "speed": Vector2(24.2, 25.8)},
]
const STAT_SPEED_WEIGHT := 0.25
const REFERENCE_SPEED := 27.1
## Adversário parado ou fora da pista por esse tempo (s) volta para a pista.
const AI_RESCUE_TIME := 4.0
## Multijogador: depois que o primeiro jogador chega, os outros têm esse tempo (s).
const FINISH_TIMEOUT := 30.0
## Motores dos adversários tocando ao mesmo tempo: os mais perto de alguma câmera,
## dentro do alcance do som (Kart.ENGINE_3D_RANGE). Cada som 3D tocando custa um
## cálculo de volume e direção por passo de física (era ~1/3 do passo na web com 7).
const ENGINE_VOICES := 3
## De quanto em quanto tempo (s) a escolha é refeita.
const ENGINE_VOICE_INTERVAL := 0.25
## Quem já está tocando conta como esse tanto (m) mais perto: dois karts lado a lado
## não ficam trocando de lugar (liga/desliga) a cada escolha.
const ENGINE_VOICE_KEEP := 4.0
## Camada de desenho (1..20) da etiqueta "J1" em cima do kart do J1; a do J2 é a
## seguinte, e assim por diante. A câmera de cada jogador não vê a etiqueta dele.
const TAG_LAYER := 11


## Um kart na corrida (um jogador ou um adversário).
class Racer:
	var kart: Kart
	## Piloto do computador (null = jogador).
	var ai: KartAI
	var character: CharacterData
	## Jogador (null = computador).
	var slot: PlayerSlot
	## Câmera e HUD do jogador.
	var camera: ChaseCamera
	var hud: Hud
	## Grand Prix: o participante da copa.
	var entrant: GrandPrix.Entrant
	## Metros andados desde a linha de chegada (negativo no grid).
	var progress := 0.0
	var start_progress := 0.0
	var index := -1
	var along := 0.0
	var laps_done := 0
	var lap_start := 0.0
	var lap_times: Array[float] = []
	var finished := false
	var finish_time := -1.0
	## Posição na corrida (1 = primeiro).
	var place := 1
	var rescue := 0.0
	var wrong_way := 0.0
	var showing_wrong_way := false
	var throttle_pressed_at := -1.0
	var autopilot_index := -1
	## Percurso sendo gravado (vira o fantasma se for recorde).
	var recording: Ghost
	var record_total := false
	var record_lap := false
	var saved_ghost := false

	func is_human() -> bool:
		return slot != null

	func display_name() -> String:
		return character.display_name if character else "-"


@onready var camera: ChaseCamera = $Camera
@onready var hud: Hud = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var karts_root: Node3D = $Karts

var track: Track
## O kart do J1.
var kart: Kart
## O J1.
var player: Racer
## Os jogadores (J1 primeiro).
var humans: Array[Racer] = []
var racers: Array[Racer] = []
var state := State.COUNTDOWN
## Modo de jogo (GameState.Mode).
var mode := 0
var laps := 3
var race_time := 0.0
## Tempos de volta do J1.
var lap_times: Array[float] = []
## Tela dividida (null com um jogador só).
var split: SplitScreen
## Contra-relógio: o fantasma do recorde (null se ainda não tem).
var ghost: Ghost
var ghost_kart: GhostKart
## Marcas de pneu de todos os karts.
var skid_marks: SkidMarks
## Itens das caixas (roleta, item guardado de cada kart e os poderes).
var items: RaceItems

var _karts: Array[Kart] = []
## Compilando os shaders atrás da tela de carregamento (a contagem ainda não começou).
var _warming := false
## A corrida está sendo montada aos poucos (`_setup`), atrás da tela de carregamento.
var loading := true
## Montagem terminada (GameState.goto_scene espera por ele antes do warm_up).
signal loaded
## Começo do pedaço de montagem deste quadro (veja `_yield_if_busy`).
var _slice_start := 0
## Quanto da montagem cabe num quadro (ms) antes de devolver a vez ao ícone de
## carregamento.
const SETUP_BUDGET_MS := 12
var _clock := 0.0
var _count_step := 0
## Multijogador: tempo até acabar a corrida para quem não chegou (-1 = sem prazo).
var _finish_timer := -1.0
var _record_class := ""
var _engine_voice_timer := 0.0


func _ready() -> void:
	# Nada de pausa até a corrida estar montada.
	pause_menu.can_pause = false
	_setup()


## Monta a corrida aos poucos, devolvendo a vez a cada SETUP_BUDGET_MS para o ícone de
## carregamento continuar animando (tudo de uma vez travava a tela por 0,3 a 0,7 s).
## A árvore fica pausada enquanto isso (GameState.goto_scene): nada da corrida roda
## pela metade.
func _setup() -> void:
	_slice_start = Time.get_ticks_msec()
	mode = GameState.mode
	_record_class = GameState.get_speed_class_name()
	# A pista escolhida na tela de seleção (ou a da vez na copa) é carregada aqui.
	var track_data := GameState.get_race_track()
	# Normalmente já vem gerada (numa thread, atrás do fade: GameState.goto_scene).
	track = GameState.take_prebuilt_track(track_data)
	if track == null:
		track = track_data.scene.instantiate()
		track.name = "Pista"
	add_child(track)
	move_child(track, 0)
	laps = GameState.laps
	await _yield_if_busy()
	skid_marks = SkidMarks.new()
	add_child(skid_marks)
	if track.obstacles:
		# O relógio dos obstáculos segue a corrida (contagem + tempo de prova).
		track.obstacles.external_clock = true
		track.obstacles.clock = 0.0
	# Sombras do sol (2 divisões na web e com 3 ou 4 telas, ou o que o jogador escolheu
	# em Opções → Gráficos): GraphicsQuality ajusta a luz quando a pista entra.
	if GameState.is_multiplayer():
		_setup_split_screen()
	await _yield_if_busy()
	await _build_grid()
	await _yield_if_busy()
	_setup_views()
	await _yield_if_busy()
	items = RaceItems.new()
	add_child(items)
	items.setup(self)
	await _yield_if_busy()
	if GameState.dev_mode:
		# F1: painel para testar os itens (DevPanel).
		var dev := DevPanel.new()
		add_child(dev)
		dev.setup(self)
	if mode == GameState.Mode.TIME_TRIAL:
		_load_ghost()
	_update_places()
	# Carrega as músicas agora, atrás da tela de carregamento (na web prepará-las trava).
	GameState.music.prepare(_music_id())
	GameState.music.prepare(&"podio")

	hud.restart_requested.connect(_restart)
	hud.next_requested.connect(_next_race)
	hud.change_kart_requested.connect(_change_selection.bind(GameState.SCENE_KART_SELECT))
	hud.change_character_requested.connect(_change_selection.bind(GameState.SCENE_CHARACTER_SELECT))
	hud.change_track_requested.connect(func(): GameState.goto_scene(GameState.SCENE_TRACK_SELECT))
	hud.menu_requested.connect(func(): GameState.goto_scene(GameState.SCENE_MAIN_MENU))
	pause_menu.restart_requested.connect(_restart)
	pause_menu.menu_requested.connect(func(): GameState.goto_scene(GameState.SCENE_MAIN_MENU))
	pause_menu.resume_requested.connect(func(): pause_menu.set_info(_pause_info()))
	pause_menu.set_info(_pause_info())
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	pause_menu.can_pause = true
	loading = false
	loaded.emit()


## Passou do orçamento do quadro: espera o próximo.
func _yield_if_busy() -> void:
	if Time.get_ticks_msec() - _slice_start >= SETUP_BUDGET_MS:
		await get_tree().process_frame
		_slice_start = Time.get_ticks_msec()


func _exit_tree() -> void:
	# A janela principal volta a desenhar o 3D (desligado na tela dividida).
	if split:
		get_viewport().disable_3d = false


# --- Montagem ----------------------------------------------------------------------

func _setup_split_screen() -> void:
	split = SplitScreen.new()
	split.name = "TelaDividida"
	add_child(split)
	split.setup(GameState.players.size())
	# Cada jogador vê o mundo pela tela dele; a janela só mostra as telas e o HUD.
	get_viewport().disable_3d = true


## Monta o grid. Corrida e Grand Prix (1ª corrida): os adversários na frente e os
## jogadores largando no fim, como num Grand Prix; nas outras corridas da copa o grid
## segue a chegada da anterior. Contra-relógio: só os jogadores, na primeira fila.
func _build_grid() -> void:
	var entries := _grid_entries()
	var has_ai := entries.any(func(e: Dictionary): return e.slot == null)
	var line: RacingLine = RacingLine.build(track) if has_ai else null
	var diff: Dictionary = DIFFICULTY[clampi(GameState.difficulty, 0, DIFFICULTY.size() - 1)]
	var skill_range: Vector2 = diff.skill
	var speed_range: Vector2 = diff.speed
	var class_speed := GameState.get_speed_multiplier()
	var lone := entries.filter(func(e: Dictionary): return e.slot != null).size() == 1
	for i in entries.size():
		var e: Dictionary = entries[i]
		var slot: PlayerSlot = e.slot
		var ai: KartAI = null if slot else KartAI.new()
		await _yield_if_busy()
		var r := _add_racer(e.character, e.kart, i, ai, slot, lone, e.get("glider"))
		r.entrant = e.get("entrant")
		if ai:
			var level: float = e.level
			ai.setup(r.kart, track, line, _karts, lerpf(skill_range.x, skill_range.y, level))
			var top := lerpf(speed_range.x, speed_range.y, level) * class_speed \
					* pow(r.kart.max_speed / (REFERENCE_SPEED * class_speed), STAT_SPEED_WEIGHT)
			ai.pace = top / r.kart.max_speed
			r.kart.speed_multiplier = ai.pace
		else:
			humans.append(r)
	humans.sort_custom(func(a: Racer, b: Racer): return a.slot.index < b.slot.index)
	pause_menu.players.assign(humans.map(func(r: Racer): return r.slot))
	player = humans[0]
	kart = player.kart
	for r in humans:
		_connect_human(r)


## Quem larga e onde (o primeiro da lista larga na pole). Cada entrada:
## {character, kart, glider, slot (PlayerSlot ou null), level (adversário, 0..1), entrant}.
func _grid_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gp := GameState.grand_prix
	if mode == GameState.Mode.GRAND_PRIX and gp:
		for e in gp.grid_order():
			out.append({
				"character": e.character,
				"kart": e.kart,
				"glider": e.glider,
				"slot": GameState.players[e.player] if e.is_human() and e.player < GameState.players.size() else null,
				"level": e.level,
				"entrant": e,
			})
		return out
	var lineup := GameState.get_rival_lineup()
	var rival_karts := GameState.get_rival_karts(lineup.size())
	var rival_gliders := GameState.get_rival_gliders(lineup.size())
	# Níveis espalhados entre o mais fraco e o mais forte, sorteados pelo grid.
	var levels: Array[float] = []
	for i in lineup.size():
		levels.append(float(i) / maxf(lineup.size() - 1, 1.0))
	levels.shuffle()
	for i in lineup.size():
		out.append({"character": lineup[i], "kart": rival_karts[i], "slot": null, "level": levels[i],
				"glider": rival_gliders[i] if i < rival_gliders.size() else null})
	for i in GameState.players.size():
		out.append({
			"character": GameState.get_player_character(i),
			"kart": GameState.get_player_kart(i),
			"glider": GameState.get_player_glider(i),
			"slot": GameState.players[i],
			"level": 0.0,
		})
	return out


func _add_racer(character: CharacterData, kart_data: KartData, slot_index: int, ai: KartAI,
		slot: PlayerSlot, lone: bool, glider: GliderData = null) -> Racer:
	var r := Racer.new()
	r.character = character
	r.ai = ai
	r.slot = slot
	var k: Kart = KART_SCENE.instantiate()
	k.data = kart_data
	k.character = character
	k.glider = glider
	k.is_player = slot != null
	k.lone_player = lone
	k.input_prefix = slot.input_prefix() if slot else ""
	k.speed_class = GameState.get_speed_multiplier()
	var players := GameState.players.size()
	k.lod_scale = 1.0 if players <= 1 else (1.4 if players == 2 else 2.0)
	if slot:
		k.name = "Jogador" if slot.index == 0 else "Jogador%d" % (slot.index + 1)
	else:
		k.name = character.display_name if character else "Adversario"
	karts_root.add_child(k)
	k.set_skid_marks(skid_marks)
	k.set_ground_theme(track.scenery)
	k.obstacle_hit.connect(_on_obstacle_hit.bind(k))
	var row := slot_index >> 1
	var column := slot_index % 2
	var dist := GRID_OFFSET + row * GRID_ROW + column * GRID_ROW * 0.5
	var side := GRID_SIDE if column == 1 else -GRID_SIDE
	k.teleport(track.global_transform * track.get_transform_at(-dist, side))
	if ai:
		k.autopilot = ai.drive
	if players > 1:
		_lighten_driver(k, 45.0 if players == 2 else 30.0)
	r.kart = k
	r.progress = -dist
	r.start_progress = -dist
	var local := track.to_local(k.global_position)
	r.index = track.get_closest_index(local)
	r.along = track.get_along(local, r.index)
	racers.append(r)
	_karts.append(k)
	return r


## Tela dividida: cada piloto é desenhado em até 4 telas (e na sombra de cada uma), e
## o personagem é a parte do kart com mais pedaços (medido no navegador: esconder os 8
## pilotos levava 4 jogadores de ~50 para ~90 fps). Ele não faz sombra e, de longe,
## onde vira poucos pixels numa tela pequena, some.
func _lighten_driver(k: Kart, view_range: float) -> void:
	if k.driver == null:
		return
	for node in k.driver.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.visibility_range_end = view_range
		gi.visibility_range_end_margin = 4.0


func _connect_human(r: Racer) -> void:
	var k := r.kart
	k.bumped.connect(_on_kart_bumped.bind(r))
	k.kart_bumped.connect(_on_karts_bumped.bind(r))
	k.boost_started.connect(_on_kart_boost.bind(r))
	k.drift_level_changed.connect(_on_drift_level)
	k.jumped.connect(_on_kart_jumped)
	k.landed.connect(_on_kart_landed.bind(r))
	k.trick_performed.connect(_on_kart_trick)
	k.glider_opened.connect(_on_glider_opened.bind(r))
	k.glider_closed.connect(_on_glider_closed)
	k.item_box_collected.connect(_on_item_box_collected.bind(r))
	k.coin_collected.connect(_on_coin_collected.bind(r))
	k.coins_changed.connect(_on_coins_changed.bind(r))
	k.obstacle_hit.connect(_on_human_hit.bind(r))


## Câmera e HUD de cada jogador. Sozinho: a câmera e o HUD da cena, como sempre. Na
## tela dividida cada um ganha os seus dentro da tela dele, e o HUD da cena fica por
## cima de tudo com o mapa e o resultado.
func _setup_views() -> void:
	var best_total := GameState.get_record(track.track_id, GameState.record_key("total"))
	var best_lap := GameState.get_record(track.track_id, GameState.record_key("lap"))
	if split == null:
		player.camera = camera
		player.hud = hud
		camera.add_to_group(&"race_camera")
		_start_camera(player)
		hud.setup(track, kart, _karts, laps, best_total, best_lap)
		_set_track_title(hud)
		return
	var aspect := split.aspect()
	for r in humans:
		var vp := split.viewports[r.slot.index]
		var cam: ChaseCamera
		if r.slot.index == 0:
			cam = camera
			remove_child(cam)
		else:
			cam = ChaseCamera.new()
			cam.name = "Camera%d" % (r.slot.index + 1)
		vp.add_child(cam)
		cam.current = true
		cam.fit_aspect(aspect)
		cam.add_to_group(&"race_camera")
		# A câmera de cada um não vê a etiqueta "J" do próprio kart.
		cam.set_cull_mask_value(TAG_LAYER + r.slot.index, false)
		r.camera = cam
		_start_camera(r)
		var h: Hud = HUD_SCENE.instantiate()
		h.name = "HUD%d" % (r.slot.index + 1)
		vp.add_child(h)
		h.setup(track, r.kart, _karts, laps, best_total, best_lap, Hud.Layout.PLAYER, r.slot)
		r.hud = h
		_add_player_tag(r)
	hud.setup(track, kart, _karts, laps, best_total, best_lap, Hud.Layout.OVERLAY)
	if split.count == 3:
		# Com 3 jogadores o mapa grande fica no quadrante livre (e não em cada tela).
		for r in humans:
			r.hud.map_panel.hide()
		hud.place_map(_map_rect(), track.track_name)
	else:
		hud.map_panel.hide()
	# A neve acompanha a câmera de cada jogador.
	for node in track.find_children("*", "GPUParticles3D", true, false):
		if node is Snowfall:
			var snow := node as Snowfall
			snow.target_camera = humans[0].camera
			for i in range(1, humans.size()):
				var extra := Snowfall.new()
				extra.name = "Neve%d" % (i + 1)
				extra.target_camera = humans[i].camera
				snow.get_parent().add_child(extra)


func _start_camera(r: Racer) -> void:
	r.camera.target = r.kart
	r.camera.intro = 1.0
	r.camera.snap()


## Mapa grande no quadrante livre (3 jogadores). Com 2 ou 4 cada um tem o seu.
func _map_rect() -> Rect2:
	var free := split.free_rect()
	var side := minf(free.size.x, free.size.y) * 0.76
	return Rect2(free.get_center() - Vector2(side, side) * 0.5 + Vector2(0.0, 18.0), Vector2(side, side))


## Etiqueta "J2" flutuando em cima do kart do jogador (para os outros acharem ele).
func _add_player_tag(r: Racer) -> void:
	var label := Label3D.new()
	label.name = "Etiqueta"
	label.text = r.slot.tag
	label.font = UiKit.FONT_ITALIC
	label.font_size = 44
	label.outline_size = 12
	label.modulate = r.slot.color.lightened(0.2)
	label.outline_modulate = UiKit.NAVY
	label.pixel_size = 0.0016
	label.fixed_size = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 1.9 * KartScale.ITEMS, 0.0)
	# Colado na câmera (kart do lado) a etiqueta só atrapalha.
	label.visibility_range_begin = 6.0
	label.visibility_range_end = 140.0
	label.layers = 1 << (TAG_LAYER + r.slot.index - 1)
	r.kart.add_child(label)


func _set_track_title(h: Hud) -> void:
	var gp := GameState.grand_prix
	if mode == GameState.Mode.GRAND_PRIX and gp:
		h.track_name.text = "%s  •  Corrida %d de %d" % [track.track_name, gp.race_index + 1, gp.race_count()]
	elif mode == GameState.Mode.TIME_TRIAL:
		h.track_name.text = "%s  •  Contra-relógio %s" % [track.track_name, _record_class]
	elif GameState.speed_class != 1:
		h.track_name.text = "%s  •  %s" % [track.track_name, _record_class]


func _pause_info() -> String:
	var parts := PackedStringArray()
	parts.append(GameState.get_mode_name())
	var gp := GameState.grand_prix
	if mode == GameState.Mode.GRAND_PRIX and gp:
		parts.append("Corrida %d de %d" % [gp.race_index + 1, gp.race_count()])
	parts.append(_record_class)
	if humans.size() > 1:
		parts.append("%d jogadores" % humans.size())
	else:
		parts.append(player.display_name())
		parts.append(kart.data.display_name if kart.data else "-")
	parts.append("%d voltas" % laps)
	return "  •  ".join(parts)


## Contra-relógio: o fantasma do recorde desta pista e classe corre junto.
func _load_ghost() -> void:
	ghost = Ghost.load_for(track.track_id, _record_class)
	if ghost == null:
		return
	ghost_kart = GhostKart.new()
	add_child(ghost_kart)
	if not ghost_kart.setup(ghost):
		ghost_kart.queue_free()
		ghost_kart = null
		return
	ghost_kart.reset_physics_interpolation()


# --- Shaders --------------------------------------------------------------------------

## Pontos da pista por onde a câmera passa ao compilar os shaders.
const WARM_UP_VIEWS := 12


## Cada shader/pipeline é compilado na primeira vez em que aparece na tela. No
## Compatibility (web) isso travava a corrida de 0,1 a 1,5 s (pontes, rampas, fogo do
## turbo, faíscas...); no Forward+ (Windows/Vulkan/D3D12) os ubershaders seguram a
## imagem enquanto a variante final compila em segundo plano, mas ainda dá pico de GPU
## quando muita coisa nova aparece junta (D3D12 é o que mais custa para criar
## pipelines). O GameState chama isto atrás do fade de carregamento: os efeitos que só
## aparecem depois ficam ligados por uns quadros e a câmera passa pela pista inteira,
## então tudo compila antes da largada.
func warm_up() -> void:
	if humans.is_empty():
		return
	_warming = true
	var cam: Camera3D = humans[0].camera
	for r in humans:
		r.camera.set_physics_process(false)
	# A câmera de sempre (atrás do J1): o grid inteiro. Os efeitos entram um grupo por
	# quadro: tudo de uma vez compilava os shaders num quadro só (~0,4 s) e travava o
	# ícone de carregamento.
	cam.global_transform = _chase_view(humans[0])
	cam.reset_physics_interpolation()
	await RenderingServer.frame_post_draw
	for k in _karts:
		k.prewarm_effects(true)
	await RenderingServer.frame_post_draw
	# Moedas voando (pegas) na frente do J1.
	if track.coins:
		track.coins.prewarm(true, humans[0].kart.global_position + humans[0].kart.get_forward() * 6.0)
		await RenderingServer.frame_post_draw
	# Efeitos dos itens (raio, "deságio −%", "§", Celerino-fantasma e o contrato) à vista.
	items.prewarm(true, 0)
	await RenderingServer.frame_post_draw
	for step in ItemAttacks.PREWARM_STEPS:
		items.prewarm(true, 1, step)
		await RenderingServer.frame_post_draw
	for i in 3:
		await RenderingServer.frame_post_draw
	items.prewarm(false)
	for k in _karts:
		k.prewarm_effects(false)
	if track.coins:
		track.coins.prewarm(false)
	# Obstáculos: todos à vista em cima da pista, olhando cada trecho.
	if track.obstacles:
		track.obstacles.prewarm(true)
		for xf in track.obstacles.zone_points():
			# 16 m antes do trecho, na altura da câmera, olhando para a frente.
			cam.global_transform = Transform3D(xf.basis, xf.origin + xf.basis.z * 16.0 + Vector3.UP * 3.0)
			cam.reset_physics_interpolation()
			for i in 2:
				await RenderingServer.frame_post_draw
		track.obstacles.prewarm(false)
	# Volta inteira olhando para a frente, na altura da câmera.
	for i in WARM_UP_VIEWS:
		var along := track.length * (float(i) + 0.5) / WARM_UP_VIEWS
		var xf := track.global_transform * track.get_transform_at(along)
		cam.global_transform = Transform3D(xf.basis, xf.origin + Vector3.UP * 2.2)
		cam.reset_physics_interpolation()
		await RenderingServer.frame_post_draw
	for r in humans:
		r.camera.set_physics_process(true)
		_start_camera(r)
	_warming = false


## Onde a câmera de perseguição fica atrás do kart deste jogador.
func _chase_view(r: Racer) -> Transform3D:
	var k := r.kart
	var fwd := k.get_forward()
	var pos := k.global_position - fwd * 3.2 * KartScale.CAMERA + Vector3.UP * 1.6 * KartScale.CAMERA
	return Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)


# --- Quadro a quadro ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _warming or loading:
		return
	_update_engine_voices(delta)
	if track.obstacles:
		track.obstacles.clock = _clock + race_time
	match state:
		State.COUNTDOWN:
			_update_countdown(delta)
		State.RACING:
			race_time += delta
			for r in humans:
				if not r.finished:
					r.hud.set_time(race_time)
					if r.recording:
						r.recording.capture(r.kart, race_time)
			_update_finish_timer(delta)
		State.FINISHED:
			race_time += delta
	if ghost_kart and state != State.COUNTDOWN:
		ghost_kart.show_at(race_time, delta)
	var lead := _lead_human_progress()
	for r in racers:
		_update_racer(r, delta, lead)
	if state != State.COUNTDOWN:
		_update_places()
	if state == State.RACING:
		for r in humans:
			if not r.finished:
				_update_wrong_way(r, delta)


## Escolhe quais motores 3D tocam: os dos jogadores sempre (tela dividida) e os
## ENGINE_VOICES adversários mais perto de uma câmera de jogador, se estiverem ao
## alcance do som. Os outros ficam parados (longe, ninguém os ouviria mesmo).
func _update_engine_voices(delta: float) -> void:
	_engine_voice_timer -= delta
	if _engine_voice_timer > 0.0:
		return
	_engine_voice_timer = ENGINE_VOICE_INTERVAL
	var cams := PackedVector3Array()
	for r in humans:
		if r.camera and r.camera.is_inside_tree():
			cams.append(r.camera.global_position)
	var rivals: Array[Kart] = []
	var keys := {}
	for k in _karts:
		if not is_instance_valid(k):
			continue
		if k.is_player:
			k.set_engine_audible(true)
			continue
		var d2 := INF
		for c in cams:
			d2 = minf(d2, c.distance_squared_to(k.global_position))
		var d := sqrt(d2)
		keys[k] = d - (ENGINE_VOICE_KEEP if k.is_engine_audible() else 0.0)
		rivals.append(k)
	rivals.sort_custom(func(a: Kart, b: Kart) -> bool: return keys[a] < keys[b])
	for i in rivals.size():
		var k := rivals[i]
		k.set_engine_audible(i < ENGINE_VOICES and keys[k] < Kart.ENGINE_3D_RANGE)


func _unhandled_input(event: InputEvent) -> void:
	if state != State.RACING:
		return
	for r in humans:
		if not r.finished and event.is_action_pressed(r.slot.action(&"reposicionar")):
			_respawn(r)
			get_viewport().set_input_as_handled()
			return


# --- Largada ---------------------------------------------------------------------

func _update_countdown(delta: float) -> void:
	_clock += delta
	var intro := clampf(1.0 - _clock / INTRO_TIME, 0.0, 1.0)
	for r in humans:
		r.camera.intro = intro
		# Turbo de largada: comece a acelerar logo depois do "2".
		if r.throttle_pressed_at < 0.0 and Input.is_action_pressed(r.slot.action(&"acelerar")):
			r.throttle_pressed_at = _clock
	var step := int(_clock)
	if step > _count_step and step <= 4:
		_count_step = step
		for r in humans:
			r.hud.set_start_lights(step)
		match step:
			1, 2, 3:
				var colors := [UiKit.RED, UiKit.ORANGE, UiKit.YELLOW]
				for r in humans:
					r.hud.show_center(str(4 - step), colors[step - 1], 0.45)
					# Acelerando parado o piloto fica concentrado (Kart._update_rev).
					if step == 1 and r.kart.driver and not r.kart.is_revving():
						r.kart.driver.set_face(&"face_smiling")
				Sfx.play(self, &"beep", -6.0)
			4:
				_start_race()


func _start_race() -> void:
	state = State.RACING
	for r in racers:
		r.kart.controls_enabled = true
		# Os bons pilotos do computador também acertam o turbo de largada.
		if r.ai and randf() < lerpf(0.2, 0.85, r.ai.skill):
			r.kart.apply_boost(1.0, 1, false)
	Sfx.play(self, &"go", -5.0)
	GameState.music.play(_music_id(), 0.0)
	for r in humans:
		r.camera.intro = 0.0
		r.hud.show_center("VAI!", UiKit.GREEN, 0.6)
		r.hud.show_hint(false)
		if r.kart.driver:
			r.kart.driver.set_face(&"face_happy")
			r.kart.driver.bounce(1.0)
		var good_start := r.throttle_pressed_at >= 2.3 and r.throttle_pressed_at <= 3.6
		if good_start and Input.is_action_pressed(r.slot.action(&"acelerar")):
			r.kart.apply_boost(1.0, 1, false)
		r.recording = Ghost.start_recording(track.track_id, _record_class, r.kart)
		r.recording.capture(r.kart, 0.0)


## A corrida está valendo (depois do "VAI!" e antes do fim)?
func is_racing() -> bool:
	return state == State.RACING


## Trilha do cenário desta pista.
func _music_id() -> StringName:
	return MusicPlayer.scenery_track(track.scenery)


# --- Progresso, voltas e posições -------------------------------------------------

## Quanto andou o jogador mais adiantado que ainda corre (o elástico dos adversários
## se mede por ele).
func _lead_human_progress() -> float:
	var best := -INF
	for r in humans:
		if not r.finished:
			best = maxf(best, r.progress)
	if best == -INF:
		for r in humans:
			best = maxf(best, r.progress)
	return best


func _update_racer(r: Racer, delta: float, lead: float) -> void:
	var k := r.kart
	var local := track.to_local(k.global_position)
	var index := track.get_closest_index(local, r.index, KartAI.SEARCH_WINDOW)
	var along := track.get_along(local, index)
	var step := along - r.along
	if step < -track.length * 0.5:
		step += track.length
	elif step > track.length * 0.5:
		step -= track.length
	r.progress += step
	r.along = along
	r.index = index
	var lateral := track.get_lateral(local, index)
	k.is_offroad = absf(lateral) > track.road_width * 0.5 + 0.4

	if state == State.COUNTDOWN:
		return
	if not r.finished:
		var done := maxi(0, floori(r.progress / track.length))
		if done > r.laps_done:
			r.laps_done = done
			_on_lap_completed(r)
	if k.global_position.y < -20.0:
		_respawn(r)
	elif r.ai:
		r.ai.gap_to_player = r.progress - lead
		# Parado de propósito (rivais parados do modo dev) não precisa de resgate.
		if k.controls_enabled:
			_check_rescue(r, lateral, delta)


## Adversário encalhado, fora da pista ou caído de uma ponte: volta para a pista.
func _check_rescue(r: Racer, lateral: float, delta: float) -> void:
	var k := r.kart
	# Parado na fila do tribunal (esperando a senha) não está encalhado.
	var lost := (absf(k.speed) < 2.0 and not k.is_waiting()) \
			or absf(lateral) > track.road_width * 0.5 + track.shoulder_width + 1.0 \
			or k.global_position.y < (track.global_transform * track.samples[r.index]).y - 5.0
	r.rescue = r.rescue + delta if lost else 0.0
	if r.rescue > AI_RESCUE_TIME:
		_respawn(r)


## Ordem da corrida: quem chegou (pela ordem de chegada) e depois quem andou mais.
static func _ahead_of(a: Racer, b: Racer) -> bool:
	if a.finished != b.finished:
		return a.finished
	if a.finished:
		return a.finish_time < b.finish_time
	return a.progress > b.progress


func _update_places() -> void:
	var order := racers.duplicate()
	order.sort_custom(_ahead_of)
	for i in order.size():
		(order[i] as Racer).place = i + 1
	for r in humans:
		r.hud.set_place(r.place, racers.size())


func _on_lap_completed(r: Racer) -> void:
	r.lap_times.append(race_time - r.lap_start)
	r.lap_start = race_time
	if r.laps_done >= laps:
		r.finished = true
		r.finish_time = race_time
		if r.ai:
			r.ai.cruising = true
			# Quem chega no pódio comemora (como o jogador).
			var arrived := racers.filter(func(o: Racer): return o.finished).size()
			if arrived <= 3 and r.kart.driver:
				r.kart.driver.celebrate()
		else:
			_on_human_finished(r)
		return
	if r.ai:
		return
	if r == player:
		lap_times = r.lap_times
	r.hud.set_lap_times(r.lap_times)
	r.hud.set_lap(r.laps_done + 1, laps)
	var split_text := _ghost_split_text(r)
	if r.laps_done == laps - 1:
		r.hud.show_banner("VOLTA FINAL!" + split_text, Color(0.85, 0.12, 0.18), 1.3)
		Sfx.play(self, &"final_lap", -6.0)
		# A música acelera com o primeiro jogador que chega na volta final.
		GameState.music.start_final_lap()
		if r.kart.driver:
			r.kart.driver.set_face(&"face_surprised", 1.0)
	else:
		var color := UiKit.NAVY
		if split_text != "":
			color = Color(0.1, 0.55, 0.25) if race_time <= ghost.split_time(r.laps_done) else Color(0.75, 0.2, 0.2)
		r.hud.show_banner("VOLTA %d" % (r.laps_done + 1) + split_text, color, 0.9)
		Sfx.play(self, &"lap", -6.0)


## Contra-relógio: diferença para o fantasma ao fechar a volta ("  -0.420").
func _ghost_split_text(r: Racer) -> String:
	if ghost == null:
		return ""
	var ref := ghost.split_time(r.laps_done)
	if ref < 0.0:
		return ""
	var diff := race_time - ref
	return "   %s%.3f" % ["+" if diff >= 0.0 else "-", absf(diff)]


func _update_wrong_way(r: Racer, delta: float) -> void:
	var tangent := track.global_basis * track.tangents[r.index]
	if r.kart.get_forward().dot(tangent) < -0.35 and r.kart.speed > 3.0:
		r.wrong_way += delta
	else:
		r.wrong_way = 0.0
	var wrong := r.wrong_way > 1.0
	if wrong != r.showing_wrong_way:
		r.showing_wrong_way = wrong
		r.hud.set_warning("CONTRAMÃO!" if wrong else "")
		if r.kart.driver:
			r.kart.driver.set_face(&"face_confused" if wrong else r.kart.driver.default_face)


# --- Chegada ------------------------------------------------------------------------

## Um jogador cruzou a chegada na última volta: salva os recordes (e o fantasma, se
## bateu o recorde da pista) e o kart dele segue sozinho, devagar. Com um jogador só
## a corrida acaba aqui; no multijogador ela acaba quando todos chegarem (ou no fim
## do prazo, contado a partir do primeiro).
func _on_human_finished(r: Racer) -> void:
	r.hud.set_lap_times(r.lap_times)
	r.hud.set_lap(laps, laps)
	r.hud.set_time(race_time)
	r.hud.show_final_time()
	r.hud.set_warning("")
	r.hud.set_timeout(-1.0)
	if r == player:
		lap_times = r.lap_times
	_update_places()
	var podium := r.place <= 3 or racers.size() == 1
	if r.kart.driver:
		if podium:
			r.kart.driver.celebrate()
		else:
			r.kart.driver.set_face(&"face_confused", 2.5)
			r.kart.driver.play_gesture(&"gesture_shrug", 1.8)
	var best_lap: float = r.lap_times.min()
	# Com itens do painel de dev (DevPanel) a corrida não vale recorde.
	if not items.dev_used:
		r.record_total = GameState.submit_record(track.track_id, GameState.record_key("total"), race_time)
		r.record_lap = GameState.submit_record(track.track_id, GameState.record_key("lap"), best_lap)
	if r.record_total and r.recording:
		r.recording.capture(r.kart, race_time)
		r.recording.total_time = race_time
		r.recording.lap_times = PackedFloat32Array(r.lap_times)
		r.saved_ghost = r.recording.save()
	r.recording = null
	r.autopilot_index = r.index
	r.kart.autopilot = _cooldown_autopilot.bind(r)
	if humans.size() == 1:
		_end_race()
		return
	r.hud.show_center("%dº" % r.place, Color.WHITE, 1.4)
	Sfx.play(self, &"finish" if podium else &"finish_low", -8.0)
	if humans.all(func(o: Racer): return o.finished):
		_end_race()
	elif _finish_timer < 0.0:
		_finish_timer = FINISH_TIMEOUT


func _update_finish_timer(delta: float) -> void:
	if _finish_timer < 0.0:
		return
	_finish_timer -= delta
	for r in humans:
		if not r.finished:
			r.hud.set_timeout(maxf(_finish_timer, 0.0))
	if _finish_timer <= 0.0:
		_finish_timer = -1.0
		_end_race()


func _end_race() -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	pause_menu.can_pause = false
	for r in humans:
		r.hud.set_warning("")
		r.hud.set_timeout(-1.0)
		if not r.finished:
			# Acabou o prazo: quem não chegou segue devagar como os outros.
			r.autopilot_index = r.index
			r.kart.autopilot = _cooldown_autopilot.bind(r)
			r.recording = null
	_update_places()
	var standings := _standings()
	# Depois da chegada a corrida dos outros segue sem elástico.
	for r in racers:
		if r.ai:
			r.ai.rubber_band = 0.0
	var best_human := humans[0]
	for r in humans:
		if r.place < best_human.place:
			best_human = r
	if humans.size() == 1:
		var podium := best_human.place <= 3 or racers.size() == 1
		player.hud.show_center("CHEGADA!", Color.WHITE, 1.2)
		Sfx.play(self, &"finish" if podium else &"finish_low", -5.0)
	# A trilha some, o som de chegada toca sozinho e entra a música do pódio.
	GameState.music.play(&"podio", 0.5, 1.8)
	if mode == GameState.Mode.GRAND_PRIX and GameState.grand_prix:
		_show_grand_prix_results(standings)
	else:
		_show_race_results(standings, best_human)


## Resultado de uma corrida avulsa ou do contra-relógio.
func _show_race_results(standings: Array[Dictionary], best: Racer) -> void:
	var options := {}
	var me := player
	var record_total := false
	var record_lap := false
	if humans.size() == 1:
		record_total = me.record_total
		record_lap = me.record_lap
		if me.saved_ghost and mode == GameState.Mode.TIME_TRIAL:
			var notes := PackedStringArray(["NOVO RECORDE!"])
			if record_lap:
				notes.append("Melhor volta!")
			notes.append("Fantasma salvo")
			options.record_text = "   ".join(notes)
	else:
		# Multijogador: o título diz quem ganhou (entre os jogadores) e os recordes
		# dizem de quem são.
		if best.place == 1 or racers.size() == humans.size():
			options.title = "%s VENCEU!" % best.slot.tag
		else:
			options.title = "%s: %dº LUGAR" % [best.slot.tag, best.place]
		options.title_color = best.slot.color.darkened(0.1)
		options.laps_text = ""
		var notes := PackedStringArray()
		for r in humans:
			if r.record_total:
				notes.append("%s: NOVO RECORDE!" % r.slot.tag)
			elif r.record_lap:
				notes.append("%s: melhor volta!" % r.slot.tag)
		options.record_text = "   ".join(notes)
	hud.show_results(standings, me.place if humans.size() == 1 else best.place, race_time, me.lap_times,
			record_total, record_lap, options)


## Grand Prix: soma os pontos da corrida e mostra a classificação geral da copa.
func _show_grand_prix_results(standings: Array[Dictionary]) -> void:
	var gp := GameState.grand_prix
	var order := PackedStringArray()
	for s in standings:
		order.append(s.id)
	gp.award(order)
	var final := gp.is_last_race()
	var rows: Array[Dictionary] = []
	var table := gp.standings()
	for i in table.size():
		var e := table[i]
		var r := _racer_of(e)
		rows.append({
			"place": i + 1,
			"name": e.character.display_name if e.character else "-",
			"color": e.character.color if e.character else UiKit.YELLOW,
			"value": "%d pts" % e.points,
			"gain": "+%d" % e.last_points,
			"is_player": e.is_human(),
			"tag": r.slot.tag if r and r.slot and humans.size() > 1 else "",
		})
	# Melhor jogador na classificação geral.
	var best_place := 99
	var best_tag := ""
	var best_color := UiKit.NAVY_LIGHT
	for i in table.size():
		if table[i].is_human() and i + 1 < best_place:
			best_place = i + 1
			var slot := GameState.players[table[i].player]
			best_tag = slot.tag
			best_color = slot.color.darkened(0.1)
	var options := {"buttons": "gp_final" if final else "gp_next"}
	var cup := gp.cup_name.to_upper()
	if final:
		var titles := ["CAMPEÃO!", "2º LUGAR NA COPA", "3º LUGAR NA COPA"]
		var who := "" if humans.size() == 1 else best_tag + (" " if best_place == 1 else ": ")
		options.title = who + (titles[best_place - 1] if best_place <= 3 else "%dº LUGAR NA COPA" % best_place)
		options.title_color = [Color(0.93, 0.6, 0.02), Color(0.45, 0.52, 0.66), Color(0.72, 0.38, 0.16)][best_place - 1] \
				if best_place <= 3 else UiKit.NAVY_LIGHT
		options.laps_text = "%s  •  %s  •  CLASSIFICAÇÃO FINAL" % [cup, _record_class]
		if best_place == 1:
			for r in humans:
				if r.entrant == table[0] and r.kart.driver:
					r.kart.driver.celebrate()
	else:
		options.title = "CORRIDA %d DE %d" % [gp.race_index + 1, gp.race_count()]
		options.title_color = best_color if humans.size() > 1 else UiKit.NAVY
		options.laps_text = "%s  •  %s  •  PRÓXIMA: %s" % [cup, _record_class, gp.tracks[gp.race_index + 1].display_name.to_upper()]
	var notes := PackedStringArray()
	for r in humans:
		if r.record_total:
			notes.append(("%s: " % r.slot.tag if humans.size() > 1 else "") + "NOVO RECORDE DA PISTA!")
	options.record_text = "   ".join(notes)
	var no_laps: Array[float] = []
	hud.show_results(rows, best_place, race_time, no_laps, false, false, options)


func _racer_of(e: GrandPrix.Entrant) -> Racer:
	for r in racers:
		if r.entrant == e:
			return r
	return null


## Classificação final. Quem ainda não chegou ganha um tempo estimado pelo ritmo
## médio dele (e nunca melhor que o de quem está na frente).
func _standings() -> Array[Dictionary]:
	var order := racers.duplicate()
	order.sort_custom(_ahead_of)
	var out: Array[Dictionary] = []
	var last_time := 0.0
	var multi := humans.size() > 1
	for item in order:
		var r := item as Racer
		var time := r.finish_time
		if not r.finished:
			var done := r.progress - r.start_progress
			var avg := maxf(done / maxf(race_time, 0.1), 5.0)
			time = race_time + maxf(laps * track.length - r.progress, 0.0) / avg
		time = maxf(time, last_time + 0.05)
		last_time = time
		var id := ""
		if r.entrant:
			id = r.entrant.id
		out.append({
			"id": id,
			"place": r.place,
			"name": r.display_name(),
			"color": r.character.color if r.character else UiKit.YELLOW,
			"time": time,
			"is_player": r.is_human(),
			"tag": r.slot.tag if r.slot and multi else "",
		})
	return out


func _cooldown_autopilot(k: Kart, r: Racer) -> Dictionary:
	var local := track.to_local(k.global_position)
	r.autopilot_index = track.get_closest_index(local, r.autopilot_index)
	var along := track.get_along(local, r.autopilot_index)
	var target := track.global_transform * track.get_point_at(along + 14.0)
	var to_target := target - k.global_position
	to_target.y = 0.0
	var angle := k.get_forward().signed_angle_to(to_target.normalized(), Vector3.UP)
	return {
		"throttle": 0.55 if k.speed < k.max_speed * 0.55 else 0.0,
		"brake": 0.0,
		"steer": clampf(angle * 2.5, -1.0, 1.0),
		"drift": false,
		"drift_pressed": false,
	}


## Põe o kart de volta no meio da pista (ou ao lado, se tiver outro kart ali).
func _respawn(r: Racer) -> void:
	var local := track.to_local(r.kart.global_position)
	var index := track.get_closest_index(local, r.index)
	var dist := track.distances[index]
	var xf := track.get_transform_at(dist, _free_lateral(dist, r.kart))
	xf.origin += Vector3.UP * 0.6
	r.kart.teleport(track.global_transform * xf)
	r.rescue = 0.0
	if r.ai:
		r.ai.reset()
	if r.camera:
		r.camera.snap()


func _free_lateral(dist: float, who: Kart) -> float:
	for lateral: float in [0.0, -3.5, 3.5, -6.0, 6.0]:
		var p := track.global_transform * track.get_transform_at(dist, lateral).origin
		var free := true
		for k in _karts:
			if k != who and k.global_position.distance_to(p) < 3.5:
				free = false
				break
		if free:
			return lateral
	return 0.0


func _restart() -> void:
	GameState.goto_scene(GameState.SCENE_RACE)


## Grand Prix: próxima corrida da copa ou, depois da última, uma copa nova com os
## mesmos jogadores.
func _next_race() -> void:
	var gp := GameState.grand_prix
	if gp == null:
		_restart()
		return
	if gp.is_last_race():
		GameState.start_grand_prix(gp.cup_name)
	else:
		GameState.next_grand_prix_race()
	GameState.goto_scene(GameState.SCENE_RACE)


## Trocar piloto ou kart: todos os jogadores escolhem de novo (ao mesmo tempo).
func _change_selection(scene: String) -> void:
	GameState.goto_scene(scene)


## O controle de um jogador desconectou no meio da corrida: pausa até ele voltar.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or state == State.FINISHED:
		return
	for r in humans:
		if r.slot.device == device and not r.finished:
			pause_menu.set_info("O controle do %s desconectou. Conecte de novo e aperte Continuar." % r.slot.tag)
			if not pause_menu.visible and pause_menu.can_pause:
				pause_menu.open()
			return


# --- Efeitos ---------------------------------------------------------------------

func _on_kart_bumped(strength: float, r: Racer) -> void:
	r.camera.shake(0.4 + strength)
	Sfx.play(self, &"bump", -8.0 + strength * 6.0)


func _on_karts_bumped(_other: Kart, strength: float, r: Racer) -> void:
	r.camera.shake(0.12 + strength * 0.45)
	Sfx.play(self, &"bump", -13.0 + strength * 7.0, 1.15)


func _on_kart_boost(power: int, r: Racer) -> void:
	r.camera.shake(0.15)
	Sfx.play(self, &"boost", -9.0, 0.9 + power * 0.1)


func _on_drift_level(level: int) -> void:
	if level > 0:
		Sfx.play(self, &"drift_level", -14.0, 0.8 + level * 0.25)


func _on_kart_jumped() -> void:
	Sfx.play(self, &"boost", -15.0, 0.6)


func _on_kart_landed(strength: float, r: Racer) -> void:
	r.camera.shake(0.12 + strength * 0.35)
	Sfx.play(self, &"bump", -13.0 + strength * 5.0, 0.7)


func _on_kart_trick() -> void:
	Sfx.play(self, &"trick", -9.0)


## A asa-delta de um jogador abriu (o tecido estala) / fechou na aterrissagem.
func _on_glider_opened(r: Racer) -> void:
	r.camera.shake(0.12)
	Sfx.play(self, &"glider_open", -6.0)


func _on_glider_closed() -> void:
	Sfx.play(self, &"glider_close", -9.0)


## Moeda pega por um jogador.
func _on_coin_collected(_r: Racer) -> void:
	Sfx.play(self, &"coin", -11.0)


func _on_coins_changed(coins: int, r: Racer) -> void:
	if r.hud:
		r.hud.set_coins(coins)


## Um kart (jogador ou não) foi atingido por um obstáculo: as moedas perdidas saltam dele.
func _on_obstacle_hit(lost: int, _splash: bool, k: Kart) -> void:
	if lost > 0 and track.coins:
		track.coins.burst(k.global_position, lost)


## Um jogador foi atingido por um obstáculo (rodou ou levou uma onda).
func _on_human_hit(lost: int, splash: bool, r: Racer) -> void:
	r.camera.shake(0.7)
	if splash:
		Sfx.play(self, &"splash", -5.0)
	else:
		Sfx.play(self, &"bump", -4.0)
		Sfx.play(self, &"spin", -11.0)
	if lost > 0:
		Sfx.play(self, &"coin_lost", -12.0)


## Caixa de item pega por um jogador: o som e a cara do piloto. O sorteio, o slot no
## HUD e o uso dos itens ficam em RaceItems.
func _on_item_box_collected(_box: Node3D, r: Racer) -> void:
	Sfx.play(self, &"item_box", -8.0)
	if r.kart.driver:
		r.kart.driver.set_face(&"face_happy", 0.8)
