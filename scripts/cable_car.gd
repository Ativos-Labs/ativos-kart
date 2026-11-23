class_name CableCar
extends Node3D
## Cabine do teleférico do vale (Pico Nevado): vai e volta entre as duas torres pelo
## cabo, parando um pouco em cada ponta. (Não roda no editor, só no jogo.)

## Pontas do cabo (no espaço do pai).
var from := Vector3.ZERO
var to := Vector3.ZERO
## Defasagem no ciclo (0..1): duas cabines em fase oposta se cruzam no meio.
var phase := 0.0
## Duração de uma ida + volta (s).
var period := 36.0

var _t := 0.0


func _ready() -> void:
	_t = phase * period


func _process(delta: float) -> void:
	_t = fposmod(_t + delta, period)
	# Ida e volta com parada nas pontas (o cosseno desacelera chegando).
	var k := 0.5 - 0.5 * cos(TAU * _t / period)
	k = smoothstep(0.08, 0.92, k)
	var p := from.lerp(to, k)
	# O cabo cede um pouco no meio.
	p.y -= 3.0 * 4.0 * k * (1.0 - k)
	position = p
