class_name TrackData
extends Resource
## Dados de uma pista para a tela de seleção (nome, copa, cena, dificuldade...).
## Para criar uma pista nova: duplique `data/pistas/circuito_ativos.tres`, troque a
## cena e os textos e acrescente o .tres na lista `tracks` de `scripts/game_state.gd`.

## Identificador usado nos recordes (igual ao `track_id` da cena da pista).
@export var id := "pista"
@export var display_name := "Pista"
## Copa (grupo de pistas) em que ela aparece.
@export var cup_name := "Copa Ativos"
@export_multiline var description := ""
@export var scene: PackedScene
@export_range(1, 5) var difficulty := 2
@export_range(1, 9) var laps := 3
## Cores do cartão na tela de seleção.
@export var color := Color("263dbf")
@export var color_dark := Color("0f1838")
## Pistas bloqueadas aparecem como "?" (em breve).
@export var locked := false


func is_unlocked() -> bool:
	return not locked and scene != null
