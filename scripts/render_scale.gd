class_name RenderScale
extends Node
## Resolução do 3D na versão web (filho do GameState, só na web).
##
## Em telas de alta densidade (Retina, Windows com escala de 150%...) o navegador
## entrega o canvas em pixels físicos: uma janela de 1440×813 vira 2880×1626, 4,5 vezes
## os pixels de uma tela comum (medido num M4: até o menu caía para 58 fps). Aqui o 3D
## é desenhado com no máximo MAX_3D_PIXELS pixels e esticado; a interface (2D) continua
## na resolução cheia, nítida.
##
## E se o jogo não segurar ~55 fps (mediana de WINDOW quadros), a resolução do 3D desce
## STEP por vez até MIN_DYNAMIC. Se descer não melhorar o tempo do quadro, o limite é a
## CPU e não a placa de vídeo: a resolução volta um passo e para de mudar naquela tela.
## Cada tela nova começa de novo da resolução cheia (`reset`).

## 1920×1080: até aí o 3D fica na resolução da janela.
const MAX_3D_PIXELS := 1920.0 * 1080.0
## Menor fração (do teto acima) que o ajuste automático usa.
const MIN_DYNAMIC := 0.6
const STEP := 0.12
## Mediana do quadro acima disto (~55 fps) = lento demais.
const SLOW_FRAME := 1.0 / 55.0
## Quadros por medição (~1,5 s a 60 fps).
const WINDOW := 90
## Grupo das SubViewports de 3D que seguem a escala (as telas da tela dividida).
const GROUP := &"scaled_3d_viewport"

## Fração atual do ajuste automático (1 = sem redução).
var dynamic := 1.0

var _frames := PackedFloat32Array()
var _held := false
## Acabou de descer: a próxima medição confere se ajudou.
var _checking := false
var _median_before := 0.0
## Descer não ajudou (o limite é a CPU): fica como está até a próxima tela.
var _locked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(apply)
	apply()


## Pausa o ajuste (troca de tela: os quadros do carregamento não contam).
func hold(on: bool) -> void:
	_held = on
	_frames.clear()


## Tela nova: volta para a resolução cheia e mede de novo.
func reset() -> void:
	dynamic = 1.0
	_locked = false
	_checking = false
	_frames.clear()
	apply()


## Fração da resolução usada agora no 3D (teto de pixels × ajuste automático).
func current_scale() -> float:
	var root := get_tree().root
	var pixels := float(root.size.x) * float(root.size.y)
	var cap := minf(1.0, sqrt(MAX_3D_PIXELS / maxf(pixels, 1.0)))
	return clampf(snappedf(cap * dynamic, 0.01), 0.3, 1.0)


func apply() -> void:
	var s := current_scale()
	var root := get_tree().root
	if not is_equal_approx(root.scaling_3d_scale, s):
		root.scaling_3d_scale = s
	for node in get_tree().get_nodes_in_group(GROUP):
		var vp := node as Viewport
		if vp and not is_equal_approx(vp.scaling_3d_scale, s):
			vp.scaling_3d_scale = s


func _process(delta: float) -> void:
	if _held or _locked or get_tree().paused:
		_frames.clear()
		return
	_frames.append(delta)
	if _frames.size() < WINDOW:
		return
	var sorted := _frames.duplicate()
	sorted.sort()
	var median := sorted[sorted.size() / 2]
	_frames.clear()
	if _checking:
		_checking = false
		if median > _median_before * 0.93:
			dynamic = minf(1.0, dynamic + STEP)
			_locked = true
			apply()
			return
	if median > SLOW_FRAME and dynamic > MIN_DYNAMIC + 0.001:
		_median_before = median
		dynamic = maxf(MIN_DYNAMIC, dynamic - STEP)
		_checking = true
		apply()
