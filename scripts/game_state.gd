extends Node
## Estado global do jogo (autoload "GameState").
## Guarda o modo de jogo, os jogadores (até 4 na mesma tela) com o personagem e o kart
## de cada um, a pista ou a copa escolhida, faz a transição entre telas e salva os
## recordes.

const RECORDS_PATH := "user://recordes.cfg"

const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_MODE_SELECT := "res://scenes/mode_select.tscn"
const SCENE_CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SCENE_KART_SELECT := "res://scenes/kart_select.tscn"
const SCENE_GLIDER_SELECT := "res://scenes/glider_select.tscn"
const SCENE_TRACK_SELECT := "res://scenes/track_select.tscn"
const SCENE_RACE := "res://scenes/race.tscn"

## Modos de jogo.
enum Mode {
	## Copa: as 4 pistas em sequência, com pontos.
	GRAND_PRIX,
	## Uma corrida avulsa (com ou sem adversários).
	VERSUS,
	## Contra-relógio: sem adversários, com o fantasma do recorde.
	TIME_TRIAL,
}
const MODE_NAMES := ["Grand Prix", "Corrida", "Contra-relógio"]
## Classes de velocidade: multiplicam a velocidade máxima e a aceleração de todos os
## karts. As pistas foram feitas para 100cc (os recordes antigos são de 100cc).
const SPEED_CLASSES := [
	{"name": "50cc", "speed": 0.8},
	{"name": "100cc", "speed": 1.0},
	{"name": "150cc", "speed": 1.15},
]
const DIFFICULTY_NAMES := ["Fácil", "Normal", "Difícil"]
const MAX_PLAYERS := 4
## Karts no grid (jogadores + adversários).
const RACE_SIZE := 8
## Cores parecidas (diferença de matiz) com a de um jogador: o adversário dessa cor
## fica de fora, para ninguém se confundir com o J2 vermelho, o J3 verde...
const SIMILAR_HUE := 0.035

## Karts disponíveis na tela de seleção.
## Para adicionar um kart novo, crie um .tres (KartData) em res://data/karts/
## e acrescente-o nesta lista.
## Os adversários também correm com eles (sorteados a cada corrida).
var karts: Array[KartData] = [
	preload("res://data/karts/standard_kart.tres"),
	preload("res://data/karts/relampago.tres"),
	preload("res://data/karts/kart_de_treino.tres"),
	preload("res://data/karts/bolido.tres"),
	preload("res://data/karts/cometa.tres"),
	preload("res://data/karts/motoca.tres"),
	preload("res://data/karts/bugre.tres"),
]

## Asas-deltas da tela de seleção (abrem nas rampas de asa-delta; só mudam o visual).
## Para adicionar uma asa nova, crie um .tres (GliderData) em res://data/asas/ e
## acrescente-o nesta lista. Os adversários também usam (sorteadas a cada corrida).
var gliders: Array[GliderData] = [
	preload("res://data/asas/asa_rubra.tres"),
	preload("res://data/asas/asa_ativos.tres"),
	preload("res://data/asas/bandeirada.tres"),
	preload("res://data/asas/por_do_sol.tres"),
]

## Personagens da tela de seleção (o primeiro é o padrão).
## Para adicionar um personagem novo, crie um .tres (CharacterData) em
## res://data/personagens/ e acrescente-o nesta lista.
var characters: Array[CharacterData] = [
	preload("res://data/personagens/celerino.tres"),
	preload("res://data/personagens/jarbas.tres"),
	preload("res://data/personagens/henrique.tres"),
	preload("res://data/personagens/ulysses.tres"),
]
## Quantas vagas "?" (em breve) aparecem na grade de personagens.
var character_slots := 8

## Adversários controlados pelo computador (o Celerino recolorido, como outros
## documentos). Os personagens jogáveis que o jogador não escolheu entram primeiro;
## estes completam o grid. Para mudar nome, cor ou atributos, edite os .tres de
## res://data/rivais/.
var rivals: Array[CharacterData] = [
	preload("res://data/rivais/planilha.tres"),
	preload("res://data/rivais/boleto.tres"),
	preload("res://data/rivais/recibo.tres"),
	preload("res://data/rivais/contrato.tres"),
	preload("res://data/rivais/relatorio.tres"),
	preload("res://data/rivais/protocolo.tres"),
	preload("res://data/rivais/certidao.tres"),
]
## Máximo de adversários numa corrida (completam o grid de RACE_SIZE karts).
var rival_count := 7
## Dificuldade dos adversários: 0 = fácil, 1 = normal, 2 = difícil.
var difficulty := 1
## Modo de jogo escolhido (tela "Modo de jogo").
var mode := Mode.VERSUS
## Classe de velocidade (índice em SPEED_CLASSES): 0 = 50cc, 1 = 100cc, 2 = 150cc.
var speed_class := 1
## Corrida avulsa com adversários do computador (no Grand Prix eles sempre correm;
## no contra-relógio nunca).
var cpu_enabled := true
## Jogadores humanos (1 a 4). O primeiro é o J1.
var players: Array[PlayerSlot] = [PlayerSlot.new()]
## Jogador escolhendo agora nas telas de piloto e de kart (uma vez cada um).
var picking_player := 0
## Copa em andamento (null fora do Grand Prix).
var grand_prix: GrandPrix

## Pistas da tela de seleção (a primeira é a padrão).
## Para adicionar uma pista nova, crie um .tres (TrackData) em res://data/pistas/
## e acrescente-o nesta lista.
var tracks: Array[TrackData] = [
	preload("res://data/pistas/circuito_ativos.tres"),
	preload("res://data/pistas/ilha_ativos.tres"),
	preload("res://data/pistas/canion_ativos.tres"),
	preload("res://data/pistas/pico_nevado.tres"),
]
## Quantas pistas cabem em cada copa e quantas copas aparecem (as vagas que
## sobram ficam como "?", em breve).
var track_slots := 4
var cup_slots := 4
## Resolução do 3D na web (teto de pixels + ajuste automático). null fora da web.
var render_scale: RenderScale
## Analógico e direcional do controle nos menus; sabe se o jogador está no controle.
var menu_input: MenuInput
## Opções (volume, tela, teclas), salvas em user://opcoes.cfg.
var settings: GameSettings
## Música de fundo (menus, uma trilha por cenário, pódio).
var music: MusicPlayer
## Modo dev: na corrida, F1 abre o painel para testar os itens (DevPanel). Ligado ao
## rodar pelo editor (build de debug), com `-- --dev` na linha de comando ou com `?dev`
## no endereço da versão web.
var dev_mode := false

## Kart e piloto do J1.
var selected_kart_index: int:
	get:
		return players[0].kart_index
	set(value):
		players[0].kart_index = value
var selected_character_index: int:
	get:
		return players[0].character_index
	set(value):
		players[0].character_index = value
var selected_track_index := 0
## Voltas da corrida (a tela de pistas usa o valor da pista escolhida).
var laps := 3

var _records := ConfigFile.new()
## Personagens recoloridos para quem escolheu um piloto que outro jogador já pegou.
var _tinted := {}
var _fade_rect: ColorRect
## "Carregando…" sobre o fade (só na web).
var _loading_label: Label
var _changing_scene := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dev_mode = _wants_dev_mode()
	_records.load(RECORDS_PATH)
	menu_input = MenuInput.new()
	menu_input.name = "MenuInput"
	add_child(menu_input)
	settings = GameSettings.new()
	settings.name = "Opcoes"
	add_child(settings)
	music = MusicPlayer.new()
	music.name = "Musica"
	add_child(music)
	# Fechar a janela passa por `quit()` (solta a música antes de sair).
	get_tree().auto_accept_quit = false
	# Resolução do 3D automática (web e desktop): evita picos de GPU em telas grandes.
	render_scale = RenderScale.new()
	render_scale.name = "RenderScale"
	add_child(render_scale)

	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.04, 0.05, 0.12, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)

	# Na web gerar a pista da próxima tela leva alguns segundos (no desktop, menos de
	# meio): avisa durante o fade em vez de deixar a tela escura parada.
	if OS.has_feature("web"):
		_loading_label = Label.new()
		_loading_label.text = "Carregando…"
		_loading_label.add_theme_font_override("font", preload("res://assets/fonts/LilitaOne-Regular.woff2"))
		_loading_label.add_theme_font_size_override("font_size", 34)
		_loading_label.add_theme_color_override("font_color", Color.WHITE)
		_loading_label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.12))
		_loading_label.add_theme_constant_override("outline_size", 10)
		_loading_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
		_loading_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_loading_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_loading_label.hide()
		layer.add_child(_loading_label)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


## Modo dev (veja dev_mode): editor, `--dev` ou `?dev` na web.
func _wants_dev_mode() -> bool:
	if OS.is_debug_build() or OS.get_cmdline_user_args().has("--dev"):
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('dev')", true))
	return false


func _exit_tree() -> void:
	CharacterMesh.clear_cache()
	GliderVisual.clear_cache()
	TrackCoins.clear_cache()
	TrackTheme.clear_cache()


## Fecha o jogo (use no lugar de `get_tree().quit()`).
func quit() -> void:
	# A música para antes e o servidor de áudio ganha um instante para soltá-la
	# (senão a faixa que tocava aparece como vazamento na saída).
	music.release()
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()


func get_selected_kart() -> KartData:
	return get_player_kart(0)


func get_selected_track() -> TrackData:
	if tracks.is_empty():
		return null
	return tracks[clampi(selected_track_index, 0, tracks.size() - 1)]


func get_selected_character() -> CharacterData:
	return get_player_character(0)


func get_player_kart(i: int) -> KartData:
	var slot := players[clampi(i, 0, players.size() - 1)]
	return karts[clampi(slot.kart_index, 0, karts.size() - 1)]


## Asa-delta do jogador `i` (null se não houver asas).
func get_player_glider(i: int) -> GliderData:
	if gliders.is_empty():
		return null
	var slot := players[clampi(i, 0, players.size() - 1)]
	return gliders[clampi(slot.glider_index, 0, gliders.size() - 1)]


## Piloto do jogador `i`. Se um jogador anterior já escolheu o mesmo personagem, este
## vem recolorido com a cor do jogador (o J2 vermelho, o J3 verde...).
func get_player_character(i: int) -> CharacterData:
	if characters.is_empty():
		return null
	i = clampi(i, 0, players.size() - 1)
	var index := clampi(players[i].character_index, 0, characters.size() - 1)
	var base := characters[index]
	var repeated := false
	for j in i:
		if players[j].character_index == index:
			repeated = true
			break
	if not repeated:
		return base
	var key := "%d:%d" % [index, i]
	if not _tinted.has(key):
		var c := base.duplicate() as CharacterData
		var color := players[i].color
		c.model_tint = color
		c.color = color
		c.color_dark = color.darkened(0.7)
		_tinted[key] = c
	return _tinted[key]


## Mais de um jogador (tela dividida).
func is_multiplayer() -> bool:
	return players.size() > 1


## Define quantos jogadores vão jogar e o controle de cada um. Com um jogador só ele
## usa o teclado e todos os controles; com mais, `devices[i]` é o controle do J(i+1).
func set_players(devices: Array[int]) -> void:
	var old := players
	players = []
	for i in maxi(devices.size(), 1):
		var slot := PlayerSlot.new(i, devices[i] if devices.size() > 1 else PlayerSlot.DEVICE_ALL)
		if i < old.size():
			slot.character_index = old[i].character_index
			slot.kart_index = old[i].kart_index
			slot.glider_index = old[i].glider_index
		slot.apply_input_map()
		players.append(slot)
	picking_player = 0
	_tinted.clear()


func get_speed_class_name() -> String:
	return SPEED_CLASSES[clampi(speed_class, 0, SPEED_CLASSES.size() - 1)].name


func get_speed_multiplier() -> float:
	return SPEED_CLASSES[clampi(speed_class, 0, SPEED_CLASSES.size() - 1)].speed


func get_mode_name() -> String:
	return MODE_NAMES[mode]


## Pista da próxima corrida (no Grand Prix, a da vez na copa).
func get_race_track() -> TrackData:
	if mode == Mode.GRAND_PRIX and grand_prix:
		return grand_prix.current_track()
	return get_selected_track()


## Quantos adversários do computador entram na corrida.
func get_rival_count() -> int:
	if mode == Mode.TIME_TRIAL or (mode == Mode.VERSUS and not cpu_enabled):
		return 0
	return clampi(RACE_SIZE - players.size(), 0, rival_count)


## Pilotos dos adversários desta corrida, já na ordem do grid (sorteada a cada
## corrida). Entram primeiro os personagens jogáveis que nenhum jogador escolheu (e não
## bloqueados) e depois os da lista `rivals`, sorteados se não couberem todos. Quem
## tem a cor de um jogador só entra se faltar gente.
func get_rival_lineup(count := -1) -> Array[CharacterData]:
	if count < 0:
		count = get_rival_count()
	var chosen: Array[CharacterData] = []
	var player_colors: Array[Color] = []
	for i in players.size():
		chosen.append(characters[clampi(players[i].character_index, 0, characters.size() - 1)])
		player_colors.append(get_player_character(i).color)
	var lineup: Array[CharacterData] = []
	for c in characters:
		if not chosen.has(c) and not c.locked and c.model_scene:
			lineup.append(c)
	var others: Array[CharacterData] = []
	var similar: Array[CharacterData] = []
	for c in rivals:
		if chosen.has(c):
			continue
		if player_colors.any(func(pc: Color): return _similar_color(pc, c.color)):
			similar.append(c)
		else:
			others.append(c)
	others.shuffle()
	similar.shuffle()
	lineup.append_array(others)
	lineup.append_array(similar)
	lineup = lineup.slice(0, clampi(count, 0, lineup.size()))
	lineup.shuffle()
	return lineup


static func _similar_color(a: Color, b: Color) -> bool:
	if a.s < 0.3 or b.s < 0.3:
		return false
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d) < SIMILAR_HUE


## Karts dos adversários desta corrida, sorteados como cartas de um baralho com todos
## os karts: cada um aparece uma vez antes de algum se repetir (com 7 karts e 7
## adversários, todos os modelos estão no grid, cada corrida numa ordem diferente).
func get_rival_karts(count: int) -> Array[KartData]:
	var out: Array[KartData] = []
	var deck: Array[KartData] = []
	while out.size() < count and not karts.is_empty():
		if deck.is_empty():
			deck = karts.duplicate()
			deck.shuffle()
		out.append(deck.pop_back())
	return out


## Asas-deltas dos adversários desta corrida, sorteadas como os karts (cada asa
## aparece uma vez antes de alguma se repetir).
func get_rival_gliders(count: int) -> Array[GliderData]:
	var out: Array[GliderData] = []
	var deck: Array[GliderData] = []
	while out.size() < count and not gliders.is_empty():
		if deck.is_empty():
			deck = gliders.duplicate()
			deck.shuffle()
		out.append(deck.pop_back())
	return out


## Começa uma copa com as pistas de `cup_name` e os jogadores atuais. Os adversários
## (pilotos, karts e nível de cada um) ficam os mesmos nas 4 corridas.
func start_grand_prix(cup_name: String) -> void:
	var gp := GrandPrix.new()
	gp.cup_name = cup_name
	for t in tracks:
		if t.cup_name == cup_name and t.is_unlocked():
			gp.tracks.append(t)
	if gp.tracks.is_empty():
		gp.tracks.append(get_selected_track())
	for i in players.size():
		var e := GrandPrix.Entrant.new()
		e.id = "j%d" % (i + 1)
		e.player = i
		e.character = get_player_character(i)
		e.kart = get_player_kart(i)
		e.glider = get_player_glider(i)
		gp.entrants.append(e)
	var lineup := get_rival_lineup(clampi(RACE_SIZE - players.size(), 0, rival_count))
	var rival_karts := get_rival_karts(lineup.size())
	var rival_gliders := get_rival_gliders(lineup.size())
	var levels: Array[float] = []
	for i in lineup.size():
		levels.append(float(i) / maxf(lineup.size() - 1, 1.0))
	levels.shuffle()
	for i in lineup.size():
		var e := GrandPrix.Entrant.new()
		e.id = "cpu%d" % i
		e.character = lineup[i]
		e.kart = rival_karts[i]
		e.glider = rival_gliders[i] if i < rival_gliders.size() else null
		e.level = levels[i]
		gp.entrants.append(e)
	grand_prix = gp
	laps = gp.current_track().laps


## Vai para a próxima corrida da copa.
func next_grand_prix_race() -> void:
	if grand_prix == null:
		return
	grand_prix.advance()
	laps = grand_prix.current_track().laps


## Troca de tela com um fade escuro.
func goto_scene(path: String) -> void:
	if _changing_scene:
		return
	_changing_scene = true
	if render_scale:
		render_scale.hold(true)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# Nos menus toca o tema do menu (sem recomeçar de uma tela para outra); a corrida
	# começa em silêncio e a trilha da pista entra no "VAI!".
	music.play(&"" if path == SCENE_RACE else &"menu", 0.4)
	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "color:a", 1.0, 0.22)
	await fade_out.finished
	if _loading_label:
		# Garante um quadro desenhado com o aviso antes da troca (que trava a tela).
		_loading_label.show()
		await RenderingServer.frame_post_draw
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	# Resolução do 3D desta tela escolhida ainda no escuro: trocar a escala realoca os
	# buffers do 3D (pico de 30-150 ms), e o warm_up abaixo já compila nela.
	if render_scale:
		if path == SCENE_RACE:
			render_scale.reset("race:%d:%d" % [selected_track_index, players.size()], "race:%d" % players.size())
		else:
			render_scale.reset(path, "menu")
		await render_scale.prewarm()
	# A tela nova pode compilar os shaders dela ainda atrás do fade (sem isso cada coisa
	# que aparece pela primeira vez trava o jogo por um instante: web e Forward+). Em
	# --headless não há quadros desenhados (frame_post_draw nunca dispara): pula.
	var scene := get_tree().current_scene
	if scene and scene.has_method(&"warm_up") and DisplayServer.get_name() != "headless":
		await scene.warm_up()
	if _loading_label:
		_loading_label.hide()
	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, 0.3)
	await fade_in.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_changing_scene = false
	if render_scale:
		render_scale.hold(false)


# --- Recordes -----------------------------------------------------------

## Chave do recorde na classe de velocidade atual ("total", "lap" em 100cc;
## "total_150cc"... nas outras).
func record_key(base: String) -> String:
	return base if speed_class == 1 else "%s_%s" % [base, get_speed_class_name()]


func get_record(track_id: String, key: String) -> float:
	return float(_records.get_value(track_id, key, -1.0))


## Salva o tempo se for recorde. Retorna true quando é um recorde novo.
func submit_record(track_id: String, key: String, time: float) -> bool:
	var old := get_record(track_id, key)
	if old < 0.0 or time < old:
		_records.set_value(track_id, key, time)
		_records.save(RECORDS_PATH)
		return true
	return false


static func format_time(t: float) -> String:
	if t < 0.0:
		return "-:--.---"
	var minutes := int(t / 60.0)
	var seconds := fmod(t, 60.0)
	return "%d:%06.3f" % [minutes, seconds]
