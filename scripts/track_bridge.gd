@tool
class_name TrackBridge
extends Resource
## Uma ponte da pista. O trecho entre `start` e `end` (frações da volta) vira
## ponte: a pista sobe `height` metros com rampas de `ramp` metros antes e depois,
## ganha tabuleiro, pilares e a estrutura do estilo escolhido, e o chão embaixo
## fica livre (rio, mar, cânion ou outro trecho da pista passando por baixo).

enum Style { PILARES, ESTAIADA, ARCO, VIADUTO }

## Começo e fim da ponte ao longo da volta (0 = largada, 0.5 = metade).
@export_range(0.0, 1.0, 0.001) var start := 0.2:
	set(value):
		start = value
		emit_changed()
@export_range(0.0, 1.0, 0.001) var end := 0.3:
	set(value):
		end = value
		emit_changed()
## Quanto a pista sobe em cima da ponte (além da altura do traçado).
@export_range(0.0, 20.0, 0.1) var height := 5.0:
	set(value):
		height = value
		emit_changed()
## Comprimento de cada rampa (subida antes e descida depois da ponte).
@export_range(5.0, 120.0, 1.0) var ramp := 40.0:
	set(value):
		ramp = value
		emit_changed()
## Água embaixo: o chão sob a ponte afunda abaixo do nível da água (mar, lagoa).
## Deixe desligado para pontes sobre outra parte da pista ou sobre rios (os rios
## já cavam o próprio leito).
@export var over_water := false:
	set(value):
		over_water = value
		emit_changed()
## Pilares: só colunas. Estaiada: torre com o logo e cabos. Arco: arco de aço
## azul com o logo no alto. Viaduto: arcos de pedra.
@export var style := Style.PILARES:
	set(value):
		style = value
		emit_changed()
