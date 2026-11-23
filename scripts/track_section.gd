@tool
class_name TrackSection
extends Resource
## Um trecho especial da pista, entre `start` e `end` (frações da volta):
## - SUBMERSO: a pista mergulha no lago ou no mar e passa por baixo d'água (kart mais
##   leve nos pulos e um pouco mais lento, bolhas, luz azulada, corais e peixes).
## - AREIA: dunas no deserto — o asfalto vira areia batida que sobe e desce, com areia
##   fofa nas bordas (segura o kart) e redemoinhos de areia movediça (`pits`).
## - GELO: a pista atravessa um lago congelado — o gelo escorrega (pouca aderência).
## - VALE: a pista acaba na beira de um vale e só continua do outro lado: ponha uma
##   rampa de asa-delta (`TrackRamp.glider`) com a borda em `start` — o kart plana por
##   cima do vale (rio, cachoeira, penhascos...) e pousa em `end`. A linha do meio do
##   vale é o filho Path3D "Vale" da pista (o começo dele é a cabeceira, com a
##   cachoeira). Quem cai no vale volta para a pista do outro lado.

enum Kind { SUBMERSO, AREIA, GELO, VALE }

@export var kind := Kind.SUBMERSO:
	set(value):
		kind = value
		emit_changed()
## Começo e fim do trecho (frações da volta). No SUBMERSO e no GELO é onde a pista
## já está na altura do fundo (ou do gelo): as rampas de `ramp` m ficam por fora.
@export_range(0.0, 1.0, 0.001) var start := 0.4:
	set(value):
		start = value
		emit_changed()
@export_range(0.0, 1.0, 0.001) var end := 0.5:
	set(value):
		end = value
		emit_changed()
## Comprimento das rampas antes e depois (m): descida para dentro d'água, subida de
## volta e a transição do asfalto para a areia ou o gelo.
@export_range(5.0, 120.0, 1.0) var ramp := 45.0:
	set(value):
		ramp = value
		emit_changed()

@export_group("Água e gelo")
## SUBMERSO: quantos metros abaixo da superfície fica o asfalto. GELO: use um valor
## negativo pequeno (a pista fica rente ao gelo, um pouco acima da água).
@export_range(-1.0, 20.0, 0.05) var depth := 8.0:
	set(value):
		depth = value
		emit_changed()
## Raio (m) em volta da pista em que o chão fica no fundo (o lago, o recife ou o
## lago congelado em volta do trecho).
@export_range(0.0, 200.0, 1.0) var basin := 70.0:
	set(value):
		basin = value
		emit_changed()

@export_group("Dunas")
## Altura das dunas (m) e distância entre as cristas (m). Rápido, o kart sai do chão
## um pouquinho no alto de cada uma.
@export_range(0.0, 8.0, 0.1) var dune_height := 3.6:
	set(value):
		dune_height = value
		emit_changed()
@export_range(20.0, 120.0, 1.0) var dune_length := 48.0:
	set(value):
		dune_length = value
		emit_changed()
## Redemoinhos de areia movediça: x = fração da volta, y = lateral (m, + = direita),
## z = raio (m). Puxam o kart para o meio e seguram a velocidade.
@export var pits := PackedVector3Array():
	set(value):
		pits = value
		emit_changed()

@export_group("Vale")
## Largura do vale no alto (m). Deixe perto do comprimento do vão.
@export_range(30.0, 300.0, 1.0) var valley_width := 110.0:
	set(value):
		valley_width = value
		emit_changed()
## Altura do fundo do vale. Abaixo do nível da água vira rio (ou mar, ou gelo).
@export var valley_floor := -3.0:
	set(value):
		valley_floor = value
		emit_changed()
## Largura do fundo plano do vale (o leito do rio).
@export_range(4.0, 120.0, 1.0) var valley_bed := 26.0:
	set(value):
		valley_bed = value
		emit_changed()
## Largura do planalto em volta da ravina (m): o chão dos dois lados sobe até a altura
## da beira mais alta da pista, e a ravina fica funda de verdade.
@export_range(0.0, 200.0, 1.0) var valley_plateau := 70.0:
	set(value):
		valley_plateau = value
		emit_changed()


func is_basin() -> bool:
	return kind == Kind.SUBMERSO or kind == Kind.GELO
