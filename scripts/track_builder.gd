class_name TrackBuilder
extends Node
## Prepara as pistas da tela de seleção sem travar o jogo. Gerar uma pista leva de
## 0,2 a 0,6 s (terreno, pontes, cenário); aqui o visual de cada uma (sem colisão)
## é gerado numa thread, fora da árvore de cena, uma pista por vez. As prontas ficam
## guardadas até `clear()` — a tela só as põe e tira da árvore (instantâneo).
## Fica no GameState (`GameState.track_builder`) porque uma geração em andamento
## pode passar do fim da tela que a pediu.
##
## Cuidado: a thread às vezes espera a thread principal (o RenderingServer devolve
## os dados das malhas que o SurfaceTool junta). Por isso a thread principal nunca
## fica parada esperando a thread: só confere a cada quadro se ela terminou. Pelo
## mesmo motivo o jogo só fecha depois que a geração em andamento termina (`quit`).

## Uma pista terminou de ser gerada em segundo plano.
signal track_built(data: TrackData)

## TrackData → Track fora da árvore, com o traçado pronto (`prepare_layout`).
var _tracks := {}
## TrackData → true para as pistas com as malhas já geradas.
var _built := {}
var _queue: Array[TrackData] = []
var _task := -1
var _job_data: TrackData
var _job_track: Track
## A tela que pediu a pista fechou: ela é liberada assim que a thread terminar.
var _job_discarded := false
var _quitting := false


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	# Fim do jogo: solta o que ainda estiver guardado (com `quit` a geração em
	# andamento já terminou).
	clear()


## A pista com o traçado pronto (amostras, comprimento, curvas, turbos) para o mapa
## e os números da tela. As malhas só existem quando `is_built(data)`.
func get_track(data: TrackData) -> Track:
	var track: Track = _tracks.get(data)
	if track == null:
		track = data.scene.instantiate()
		track.with_collision = false
		track.prepare_layout()
		_tracks[data] = track
	return track


func is_built(data: TrackData) -> bool:
	return _built.has(data)


## Gera a pista agora, na thread principal (trava enquanto gera: use só atrás do
## fade de troca de tela). Devolve null se ela já estiver sendo gerada na thread.
func build_now(data: TrackData) -> Track:
	var track := get_track(data)
	if not is_built(data):
		if track == _job_track:
			return null
		track.build_geometry()
		_built[data] = true
	return track


## Pistas a gerar em segundo plano, na ordem (as prontas são puladas). Substitui o
## pedido anterior; a pista que já está sendo gerada continua.
func request(order: Array[TrackData]) -> void:
	_queue.clear()
	for data in order:
		if data and data.is_unlocked() and not is_built(data) and get_track(data) != _job_track:
			_queue.append(data)
	_start_next()


## Solta as pistas guardadas que estão fora da árvore (as que estão numa cena são
## liberadas com ela). A que estiver sendo gerada é liberada quando terminar.
func clear() -> void:
	_queue.clear()
	for data: TrackData in _tracks:
		var track: Track = _tracks[data]
		if track == _job_track:
			_job_discarded = true
		elif is_instance_valid(track) and track.get_parent() == null:
			track.free()
	_tracks.clear()
	_built.clear()


## Fecha o jogo — depois que a geração em andamento terminar (fechar no meio
## travaria: o Godot espera a thread, e ela espera a thread principal).
func quit() -> void:
	_queue.clear()
	if _task < 0:
		get_tree().quit()
	else:
		_quitting = true


func _start_next() -> void:
	if _task >= 0 or _quitting or _queue.is_empty():
		return
	_job_data = _queue.pop_front()
	_job_track = get_track(_job_data)
	_job_discarded = false
	_task = WorkerThreadPool.add_task(_job_track.build_geometry, false, "Gerar pista %s" % _job_data.id)
	set_process(true)


func _process(_delta: float) -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var data := _job_data
	var track := _job_track
	_job_data = null
	_job_track = null
	if _job_discarded:
		track.free()
	else:
		_built[data] = true
		track_built.emit(data)
	if _quitting:
		get_tree().quit()
		return
	_start_next()
	set_process(_task >= 0)
