class_name CharacterData
extends Resource
## Dados de um personagem (piloto): modelo 3D, cores da interface e atributos.
## Para criar um personagem novo: duplique res://data/personagens/celerino.tres,
## troque o modelo e os textos, e acrescente-o na lista `characters` em GameState.
## O modelo precisa usar o mesmo esqueleto do Celerino (veja CharacterRig).

@export var display_name := "Personagem"
## Frase curta mostrada embaixo do nome na seleção.
@export var tagline := ""
@export_multiline var description := ""
## Personagens bloqueados aparecem como "?" na grade de seleção.
@export var locked := false

@export_group("Modelo 3D")
@export var model_scene: PackedScene
## Escala do personagem sentado no kart (o modelo do Celerino tem 2 m de altura).
@export var kart_scale := 0.55
## Escala do personagem em pé nas telas de seleção.
@export var showcase_scale := 1.0
## Altura (no modelo, em metros) da base do corpo — é o ponto que encosta no banco.
@export var seat_height := 0.54

@export_group("Cores")
## Cor principal (faixa do nome, destaque do retrato).
@export var color := Color(0.17, 0.38, 0.93)
## Cor secundária (gradiente do fundo da seleção).
@export var color_dark := Color(0.05, 0.12, 0.42)
## Recolore o modelo 3D (cor transparente = cores originais). Os materiais de
## `tint_materials` trocam de matiz: o primeiro vira esta cor e os outros ficam
## proporcionalmente mais claros ou escuros. Os adversários são o Celerino recolorido.
@export var model_tint := Color(0, 0, 0, 0)
## Materiais do modelo que a `model_tint` recolore (no Celerino: os azuis).
@export var tint_materials := PackedStringArray()

@export_group("Atributos (1 a 5)")
## Os atributos do personagem se somam aos do kart (3 = neutro).
@export_range(1, 5) var speed := 3
@export_range(1, 5) var acceleration := 3
@export_range(1, 5) var handling := 3
@export_range(1, 5) var weight := 3


## Cria o personagem montado (CharacterRig) pronto para adicionar na cena.
func instantiate_rig() -> CharacterRig:
	var rig := CharacterRig.new()
	rig.name = "Piloto"
	rig.data = self
	return rig
