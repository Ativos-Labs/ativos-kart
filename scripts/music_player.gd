class_name MusicPlayer
extends Node
## Música de fundo (filho do GameState: continua tocando de uma tela para outra). O
## tema dos menus, uma trilha por cenário de pista e a do pódio, compostas e
## sintetizadas por tools/music/build_music.mjs (assets/music/*.ogg, todas em loop).
##
## Na corrida a trilha começa no "VAI!". Na volta final ela some durante a fanfarra e
## volta mais rápida (e um tom acima, o jeito clássico de dar urgência). Na pausa fica
## baixinha. Toca no canal "Musica" (volume na tela de opções).

const TRACKS := {
	&"menu": "res://assets/music/menu.ogg",
	&"campo": "res://assets/music/campo.ogg",
	&"praia": "res://assets/music/praia.ogg",
	&"deserto": "res://assets/music/deserto.ogg",
	&"neve": "res://assets/music/neve.ogg",
	&"podio": "res://assets/music/podio.ogg",
}
## Trilha de cada cenário de pista (na ordem de TrackTheme.Scenery).
const SCENERY_TRACKS: Array[StringName] = [&"campo", &"praia", &"deserto", &"neve"]
## Volume com o canal no máximo: as faixas vêm normalizadas e o motor e os avisos
## precisam ficar por cima delas.
const BASE_DB := -10.0
## Volume na pausa (fração).
const DUCK := 0.3
## Volta final: velocidade da música depois da fanfarra. 2^(2/12): um tom acima.
const FINAL_LAP_PITCH := 1.122462
## Tempo em silêncio para a fanfarra da volta final tocar sozinha.
const FINAL_LAP_GAP := 0.6

## Faixa tocando (vazio = silêncio).
var current := &""
## A trilha já está no ritmo da volta final.
var final_lap := false

## Dois tocadores: um some enquanto o outro começa.
var _players: Array[AudioStreamPlayer] = []
## Volume de cada tocador (fração, animado nos fades) e o da pausa.
var _levels: Array[float] = [0.0, 0.0]
var _duck := 1.0
var _active := 0
var _tweens: Array[Tween] = [null, null]
var _duck_tween: Tween
var _pending: Tween
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Musica%d" % (i + 1)
		p.bus = GameSettings.BUS_MUSIC
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


func _exit_tree() -> void:
	release()


## Para tudo e solta as faixas (ao fechar o jogo: se ainda estivesse tocando, o
## servidor de áudio continuaria segurando a faixa na saída).
func release() -> void:
	if _pending:
		_pending.kill()
		_pending = null
	current = &""
	for p in _players:
		p.stop()
		p.stream = null
	_streams.clear()


func _process(_delta: float) -> void:
	for i in 2:
		var p := _players[i]
		if not p.playing:
			continue
		var db := BASE_DB + linear_to_db(maxf(_levels[i] * _duck, 0.0001))
		if absf(p.volume_db - db) > 0.05:
			p.volume_db = db


## Faixa do cenário da pista (TrackTheme.Scenery).
static func scenery_track(scenery: int) -> StringName:
	return SCENERY_TRACKS[clampi(scenery, 0, SCENERY_TRACKS.size() - 1)]


## Carrega a faixa. Na web também a deixa pronta para o navegador tocar: preparar uma
## faixa trava o jogo por um instante, então chame atrás da tela de carregamento.
func prepare(id: StringName) -> AudioStream:
	if not TRACKS.has(id):
		return null
	if _streams.has(id):
		return _streams[id]
	var stream := load(TRACKS[id]) as AudioStream
	if stream == null:
		return null
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	# Das trilhas de pista fica guardada só a última (na web cada faixa preparada
	# ocupa a memória do navegador já descomprimida).
	if id in SCENERY_TRACKS:
		for other: StringName in SCENERY_TRACKS:
			if other != id and other != current:
				_streams.erase(other)
	if OS.has_feature("web") and not AudioServer.is_stream_registered_as_sample(stream):
		AudioServer.register_stream_as_sample(stream)
	_streams[id] = stream
	return stream


## Toca a faixa `id` (vazio = silêncio) do começo. A que estava tocando some em
## `fade` segundos e a nova entra depois dela (ou depois de `delay`, se for maior).
## Pedir a faixa que já está tocando não faz nada.
func play(id: StringName, fade := 0.5, delay := 0.0) -> void:
	if id == current and (id == &"" or _players[_active].playing):
		return
	if _pending:
		_pending.kill()
		_pending = null
	current = id
	final_lap = false
	set_ducked(false)
	var was_playing := _players[_active].playing
	_fade(_active, 0.0, fade, true)
	if id == &"":
		return
	var stream := prepare(id)
	if stream == null:
		push_warning("Música não encontrada: %s" % id)
		current = &""
		return
	var wait := maxf(delay, fade if was_playing else 0.0)
	if wait > 0.0:
		_pending = create_tween()
		_pending.tween_interval(wait)
		_pending.tween_callback(_start.bind(stream))
	else:
		_start(stream)


func stop(fade := 0.5) -> void:
	play(&"", fade)


## Volta final: a música some para a fanfarra e volta mais rápida.
func start_final_lap() -> void:
	if final_lap or current == &"" or not _players[_active].playing:
		return
	final_lap = true
	var i := _active
	var p := _players[i]
	if _tweens[i]:
		_tweens[i].kill()
	var tw := create_tween()
	tw.tween_method(_set_level.bind(i), _levels[i], 0.0, 0.12)
	tw.tween_interval(FINAL_LAP_GAP)
	tw.tween_callback(func(): p.pitch_scale = FINAL_LAP_PITCH)
	tw.tween_method(_set_level.bind(i), 0.0, 1.0, 0.4)
	_tweens[i] = tw


## Música baixinha (pausa).
func set_ducked(on: bool) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(v: float): _duck = v, _duck, DUCK if on else 1.0, 0.25)


func _start(stream: AudioStream) -> void:
	_pending = null
	_active = 1 - _active
	var p := _players[_active]
	if _tweens[_active]:
		_tweens[_active].kill()
	p.stream = stream
	p.pitch_scale = 1.0
	_levels[_active] = 1.0
	p.volume_db = BASE_DB + linear_to_db(maxf(_duck, 0.0001))
	p.play()


func _fade(i: int, to: float, time: float, stop_after: bool) -> void:
	if _tweens[i]:
		_tweens[i].kill()
		_tweens[i] = null
	var p := _players[i]
	if not p.playing or time <= 0.0:
		_levels[i] = to
		if stop_after:
			p.stop()
		return
	var tw := create_tween()
	tw.tween_method(_set_level.bind(i), _levels[i], to, time)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[i] = tw


func _set_level(v: float, i: int) -> void:
	_levels[i] = v
