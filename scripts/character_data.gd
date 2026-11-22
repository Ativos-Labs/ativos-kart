class_name CharacterData
extends Resource
## Dados de um personagem (piloto): modelo 3D, cores da interface e atributos.
## Para criar um personagem novo: duplique res://data/personagens/celerino.tres,
## troque o modelo e os textos, e acrescente-o na lista `characters` em GameState.
## Com um esqueleto diferente do do Celerino, aponte `skeleton` para um
## CharacterSkeleton com os ossos e as animações dele (veja o do Jarbas).

@export var display_name := "Personagem"
## Frase curta mostrada embaixo do nome na seleção.
@export var tagline := ""
@export_multiline var description := ""
## Personagens bloqueados aparecem como "?" na grade de seleção.
@export var locked := false

@export_group("Modelo 3D")
@export var model_scene: PackedScene
## Ossos, animações extras e jeito de pilotar do modelo. Vazio = o esqueleto do Celerino.
@export var skeleton: CharacterSkeleton
## Piloto do padrão "Encaixe piloto × kart" (Jarbas, Henrique, Ulysses): o .glb já está em
## metros, nas proporções finais, e entra em todo veículo em escala 1, com a origem na
## origem do piloto do veículo (KartData.driver_origin). A pose sentada (drive_kart na
## POSE_Kart, drive_moto na POSE_Moto) leva o corpo até o assento e as mãos até o volante;
## o veículo é que foi escalado para isso dar certo. kart_scale, seat_height e
## seat_forward não valem para ele.
@export var standard_fit := false
## Escala do personagem sentado no kart (o modelo do Celerino tem 2 m de altura).
@export var kart_scale := 0.55
## Escala do personagem em pé nas telas de seleção.
@export var showcase_scale := 1.0
## Escala e deslocamento do personagem no retrato (grade de seleção, seleção de kart e
## HUD). A câmera do retrato fica a 1,42 m de altura e enquadra ~1,5 m: o Celerino
## (2 m) aparece da barriga para cima; personagens menores crescem e descem até o rosto
## ficar no mesmo lugar.
@export var portrait_scale := 1.0
@export var portrait_offset := Vector3.ZERO
## Altura (no modelo, em metros) da base do corpo — é o ponto que encosta no banco.
@export var seat_height := 0.54
## Quanto o personagem senta à frente do ponto do banco do kart (no modelo, em
## metros). Para personagens de corpo grosso, cujas costas passariam do encosto.
@export var seat_forward := 0.0

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
## Modelos com textura: cor de referência das partes recoloridas. Só os pontos da
## textura com matiz parecida com a dela trocam de cor (o azul do macacão, não a pele);
## ela vira a `model_tint` e o resto mantém a proporção. Transparente = recolore o
## material inteiro pela cor do primeiro de `tint_materials` (modelos de cor lisa).
@export var tint_reference := Color(0, 0, 0, 0)

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
