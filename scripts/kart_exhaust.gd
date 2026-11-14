class_name KartExhaust
extends Resource
## Uma saída de escapamento (ou turbina) do kart: de onde sai o fogo do turbo.
## Fica em KartData.exhausts; as posições são no espaço do kart (frente = -Z,
## traseira = +Z), as mesmas de seat_position e steering_wheel_center.

enum Style {
	## Chama de combustão: núcleo azulado na boca, amarelo, laranja e ponta vermelha.
	FOGO,
	## Turbina a jato: núcleo branco-azulado com "diamantes" de choque e cauda violeta.
	JATO,
	## Propulsor de plasma: ciano brilhante que esfria para violeta.
	PLASMA,
}

## Centro da boca do escapamento.
@export var position := Vector3.ZERO
## Para onde a chama sai (não precisa estar normalizado).
@export var direction := Vector3.BACK
## Raio da boca em metros (a chama abre um pouco mais que isso).
@export_range(0.01, 0.3, 0.001) var radius := 0.05
## Comprimento da chama no turbo normal (m). 0 = automático pelo raio.
@export_range(0.0, 2.0, 0.01) var length := 0.0
@export var style := Style.FOGO


func get_length() -> float:
	return length if length > 0.0 else 0.3 + radius * 6.0
