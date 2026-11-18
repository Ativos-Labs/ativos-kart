class_name GrandPrix
extends RefCounted
## Grand Prix (copa): as pistas da copa em sequência, os mesmos adversários em todas
## as corridas e pontos pela posição de chegada. Fica em `GameState.grand_prix`
## enquanto a copa dura.
##
## Na primeira corrida os jogadores largam no fim do grid; nas outras o grid segue a
## ordem de chegada da corrida anterior (quem venceu larga na frente).

## Pontos por posição (1º, 2º...). Quem chega depois do 8º não pontua.
const POINTS := [15, 12, 10, 8, 6, 4, 2, 1]


## Um participante da copa (jogador ou adversário do computador).
class Entrant:
	## "j1".."j4" para os jogadores, "cpu0".. para o computador.
	var id := ""
	## Índice do jogador em GameState.players (-1 = computador).
	var player := -1
	var character: CharacterData
	var kart: KartData
	var glider: GliderData
	## Nível do adversário (0 = o mais fraco do grid, 1 = o mais forte).
	var level := 0.5
	var points := 0
	## Pontos e posição da última corrida.
	var last_points := 0
	var last_place := 0

	func is_human() -> bool:
		return player >= 0


var cup_name := ""
var tracks: Array[TrackData] = []
## Corrida atual (0 = primeira).
var race_index := 0
var entrants: Array[Entrant] = []
## Ordem de chegada da última corrida (ids), para o grid da próxima.
var last_order: PackedStringArray = []


func current_track() -> TrackData:
	return tracks[clampi(race_index, 0, tracks.size() - 1)]


func race_count() -> int:
	return tracks.size()


func is_last_race() -> bool:
	return race_index >= tracks.size() - 1


func get_entrant(id: String) -> Entrant:
	for e in entrants:
		if e.id == id:
			return e
	return null


## Ordem do grid da corrida atual (o primeiro larga na pole).
func grid_order() -> Array[Entrant]:
	var out: Array[Entrant] = []
	if last_order.is_empty():
		for e in entrants:
			if not e.is_human():
				out.append(e)
		out.shuffle()
		for e in entrants:
			if e.is_human():
				out.append(e)
		return out
	for id in last_order:
		var e := get_entrant(id)
		if e:
			out.append(e)
	for e in entrants:
		if not out.has(e):
			out.append(e)
	return out


## Soma os pontos da corrida. `order` = ids na ordem de chegada.
func award(order: PackedStringArray) -> void:
	for e in entrants:
		e.last_points = 0
		e.last_place = 0
	for i in order.size():
		var e := get_entrant(order[i])
		if e == null:
			continue
		e.last_place = i + 1
		e.last_points = POINTS[i] if i < POINTS.size() else 0
		e.points += e.last_points
	last_order = order


## Classificação geral: mais pontos primeiro; no empate, quem foi melhor na última
## corrida.
func standings() -> Array[Entrant]:
	var out := entrants.duplicate()
	out.sort_custom(func(a: Entrant, b: Entrant) -> bool:
		if a.points != b.points:
			return a.points > b.points
		return a.last_place < b.last_place)
	var typed: Array[Entrant] = []
	typed.assign(out)
	return typed


func advance() -> void:
	race_index = mini(race_index + 1, tracks.size() - 1)
