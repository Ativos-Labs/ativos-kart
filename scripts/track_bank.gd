@tool
class_name TrackBank
extends Resource
## Uma curva inclinada da pista. Entre `start` e `end` (frações da volta) a pista
## deita `angle` graus para dentro da curva (o lado de fora sobe), com transições de
## `ramp` metros antes e depois. A borda de dentro fica na altura do traçado; o resto
## sobe, então com ângulos altos a pista vira parede.
##
## Na parte inclinada a gravidade do kart segue o chão (o kart "gruda" na pista), então
## dá para passar de 60–80° sem escorregar — é a parede da cidade neon.

## Começo e fim do trecho inclinado (0 = largada, 0.5 = metade).
@export_range(0.0, 1.0, 0.001) var start := 0.2:
	set(value):
		start = value
		emit_changed()
@export_range(0.0, 1.0, 0.001) var end := 0.3:
	set(value):
		end = value
		emit_changed()
## Inclinação no meio do trecho, em graus (0 = plana, 80 = quase uma parede).
@export_range(0.0, 85.0, 0.5) var angle := 25.0:
	set(value):
		angle = value
		emit_changed()
## Comprimento de cada transição (de plana até `angle` e de volta).
@export_range(5.0, 120.0, 1.0) var ramp := 30.0:
	set(value):
		ramp = value
		emit_changed()
## Lado que sobe: 0 = o de fora da curva (automático), +1 = o direito, −1 = o esquerdo.
@export_range(-1, 1, 1) var side := 0:
	set(value):
		side = value
		emit_changed()
