class_name RenderScale
extends Node
## Resolução do 3D (filho do GameState): teto de pixels + ajuste automático.
##
## Web: em telas de alta densidade (Retina, Windows com escala de 150%...) o navegador
## entrega o canvas em pixels físicos: uma janela de 1440×813 vira 2880×1626, 4,5 vezes
## os pixels de uma tela comum (medido num M4: até o menu caía para 58 fps). Lá o 3D é
## desenhado com no máximo WEB_MAX_3D_PIXELS pixels e esticado; a interface (2D)
## continua na resolução cheia, nítida.
## Desktop (Forward+): em monitores 1440p/4K o custo do quadro cresce com os pixels
## (MSAA, SSAO, sombras e brilho trabalham todos na resolução cheia) e uma placa
## integrada ou antiga não segura 60 fps. O 3D é esticado com FSR 1.0.
##
## Ajuste automático sem picos. Trocar a escala realoca todos os buffers do 3D: medido
## (Vulkan, 2940×1846) 150 ms na primeira troca, 30-80 ms nas seguintes e centenas de MB
## de memória de vídeo indo e voltando. Por isso:
## - a escala só muda de verdade atrás do fade de carregamento (`reset`, chamado pelo
##   GameState antes do warm_up) e fica guardada por tipo de tela: cada pista com cada
##   número de jogadores tem a sua (os menus pesam bem menos e não podem puxar a
##   corrida de volta para cima); pista nova começa da última corrida com os mesmos
##   jogadores;
## - no meio de uma tela ela cai no máximo UMA vez, direto para a escala estimada
##   (nunca degrau por degrau, nunca volta atrás no meio da corrida);
## - no desktop a decisão usa o tempo de GPU medido: se o quadro está lento mas a GPU
##   não, o limite é a CPU e baixar a resolução só daria um pico à toa.

## Web, 1920×1080: até aí o 3D fica na resolução da janela.
const WEB_MAX_3D_PIXELS := 1920.0 * 1080.0
## Desktop, 3840×2160: só limita telas acima de 4K; abaixo disso quem manda é o ajuste
## automático (placa boa continua em resolução cheia).
const DESKTOP_MAX_3D_PIXELS := 3840.0 * 2160.0
## Menor fração (do teto acima) que o ajuste automático usa.
const MIN_DYNAMIC := 0.6
## Passo das escalas (evita realocar por diferenças pequenas).
const SNAP := 0.05
## Quadro acima disto (~55 fps) = lento demais.
const SLOW_FRAME := 1.0 / 55.0
## Tempo de GPU que a escala estimada mira (ms): folga abaixo de 60 fps.
const TARGET_GPU_MS := 13.5
## Na tela seguinte sobe a escala se a GPU ficou abaixo disto (ms).
const ROOMY_GPU_MS := 8.0
## Quadros por medição (~1,5 s a 60 fps).
const WINDOW := 90
## Medições lentas seguidas antes de cair (~3 s): um trecho pesado curto não conta.
const SLOW_WINDOWS := 2
## Grupo das SubViewports de 3D que seguem a escala (as telas da tela dividida).
const GROUP := &"scaled_3d_viewport"

## Fração atual do ajuste automático (1 = sem redução).
var dynamic := 1.0
## Fração fixa escolhida nas opções (Gráficos → Resolução 3D, GraphicsQuality) no lugar
## do ajuste automático; 0 = automática. O teto de pixels continua valendo.
var fixed := 0.0:
	set(value):
		if is_equal_approx(value, fixed):
			return
		fixed = value
		_frames.clear()
		_gpu.clear()
		if is_inside_tree():
			apply()

var _max_pixels := WEB_MAX_3D_PIXELS
## Desktop (RenderingDevice): dá para medir o tempo de GPU de cada viewport.
var _gpu_timing := false
var _frames := PackedFloat32Array()
var _gpu := PackedFloat32Array()
var _held := false
var _slow_count := 0
## Já caiu nesta tela (só cai uma vez por tela).
var _dropped := false
var _before_drop := 1.0
## Web: conferindo se a queda ajudou (sem tempo de GPU, só o quadro diz).
var _checking := false
var _frame_before := 0.0
var _drop_helped := true
## Medições da tela atual (para decidir a escala da próxima vez que ela abrir).
var _max_gpu_ms := 0.0
var _had_slow := false
var _windows := 0
## Escala aprendida por tela (`key`) e a última por família ("race:2", "menu"...).
var _learned := {}
var _family_last := {}
var _key := ""
var _family := ""
var _fsr_warmed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_max_pixels = WEB_MAX_3D_PIXELS
	else:
		_max_pixels = DESKTOP_MAX_3D_PIXELS
		if RenderingServer.get_current_rendering_method() != "gl_compatibility":
			# FSR só existe nos renderers Forward+/Mobile; com escala 1.0 não custa nada.
			get_tree().root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			_gpu_timing = DisplayServer.get_name() != "headless"
	get_tree().root.size_changed.connect(apply)
	apply()


## Pausa o ajuste (troca de tela: os quadros do carregamento não contam).
func hold(on: bool) -> void:
	_held = on
	_frames.clear()
	_gpu.clear()


## Tela nova (atrás do fade): guarda o que a tela anterior aprendeu e aplica a escala
## desta. `key` identifica a tela (corrida: pista + jogadores) e `family` o grupo de
## telas parecidas, de onde vem a escala inicial de uma tela nunca vista.
func reset(key := "", family := "") -> void:
	if _key != "":
		_learned[_key] = _next_scale()
		_family_last[_family] = _learned[_key]
	_key = key
	_family = family
	dynamic = float(_learned.get(key, _family_last.get(family, 1.0)))
	_dropped = false
	_checking = false
	_drop_helped = true
	_slow_count = 0
	_had_slow = false
	_max_gpu_ms = 0.0
	_windows = 0
	_frames.clear()
	_gpu.clear()
	apply()


## Desktop, uma vez por sessão e atrás do fade: liga o FSR por 2 quadros. A primeira
## vez que a escala sai de 1.0 custava ~100-150 ms (medido); as quedas seguintes, quase
## nada. Assim a única queda possível no meio de uma corrida não trava.
func prewarm() -> void:
	if _fsr_warmed or not _gpu_timing:
		return
	_fsr_warmed = true
	if current_scale() < 1.0:
		return # esta tela já desenha com FSR (o warm_up dela aquece)
	for vp in _viewports():
		vp.scaling_3d_scale = 0.95
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	apply()


## Escala para a próxima visita a esta tela, pelo que ela mediu agora.
func _next_scale() -> float:
	if _dropped and not _drop_helped:
		# Web: cair não melhorou o quadro (limite era a CPU): volta ao que era.
		return _before_drop
	if _dropped or dynamic >= 1.0 or _had_slow:
		return dynamic
	if _gpu_timing and _max_gpu_ms > 0.0 and _max_gpu_ms < ROOMY_GPU_MS:
		# Sobrou GPU até no trecho mais pesado: sobe até onde a medição diz que cabe.
		return _snap(minf(1.0, dynamic * sqrt(TARGET_GPU_MS * 0.8 / _max_gpu_ms)))
	if not _gpu_timing and _windows >= 4:
		return _snap(minf(1.0, dynamic + 0.1))
	return dynamic


## Fração da resolução usada agora no 3D (teto de pixels × escala fixa ou ajuste
## automático).
func current_scale() -> float:
	var root := get_tree().root
	var pixels := float(root.size.x) * float(root.size.y)
	var cap := minf(1.0, sqrt(_max_pixels / maxf(pixels, 1.0)))
	return clampf(snappedf(cap * (fixed if fixed > 0.0 else dynamic), 0.01), 0.3, 1.0)


func apply() -> void:
	var s := current_scale()
	for vp in _viewports():
		if not is_equal_approx(vp.scaling_3d_scale, s):
			vp.scaling_3d_scale = s
		if _gpu_timing:
			RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)


func _viewports() -> Array[Viewport]:
	var out: Array[Viewport] = [get_tree().root]
	for node in get_tree().get_nodes_in_group(GROUP):
		if node is Viewport:
			out.append(node)
	return out


## Tempo de GPU do último quadro medido (ms), somando as telas da tela dividida.
func _gpu_ms() -> float:
	var total := 0.0
	for vp in _viewports():
		total += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
	return total


func _process(delta: float) -> void:
	# Escala fixa nas opções: sem ajuste automático.
	if _held or get_tree().paused or fixed > 0.0:
		_frames.clear()
		_gpu.clear()
		return
	_frames.append(delta)
	if _gpu_timing:
		_gpu.append(_gpu_ms())
	if _frames.size() < WINDOW:
		return
	var frame := _percentile(_frames, 0.7)
	var gpu := _percentile(_gpu, 0.5) if _gpu_timing else 0.0
	_frames.clear()
	_gpu.clear()
	_windows += 1
	_max_gpu_ms = maxf(_max_gpu_ms, gpu)
	if _checking:
		_checking = false
		_drop_helped = frame < _frame_before * 0.93
		return
	if _dropped:
		return
	var gpu_bound := not _gpu_timing or gpu > SLOW_FRAME * 1000.0 * 0.85
	if frame > SLOW_FRAME and gpu_bound:
		_slow_count += 1
		_had_slow = true
	else:
		_slow_count = 0
	if _slow_count < SLOW_WINDOWS or dynamic <= MIN_DYNAMIC + 0.001:
		return
	# O custo da GPU acompanha os pixels (escala²): uma queda só, direto ao alvo.
	var ratio := (TARGET_GPU_MS / gpu) if _gpu_timing else (1.0 / 62.0) / frame
	var want := _snap(clampf(dynamic * sqrt(ratio), MIN_DYNAMIC, dynamic - SNAP))
	_before_drop = dynamic
	_frame_before = frame
	dynamic = want
	_dropped = true
	_checking = not _gpu_timing
	apply()


func _snap(v: float) -> float:
	return clampf(snappedf(v, SNAP), MIN_DYNAMIC, 1.0)


static func _percentile(a: PackedFloat32Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(s.size() * p))]
