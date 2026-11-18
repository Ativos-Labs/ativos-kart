class_name GliderData
extends Resource
## Uma asa-delta: abre em cima do kart quando ele decola de uma rampa de asa-delta
## (TrackRamp.glider) e o leva planando. Todas planam igual — a escolha é só de estilo.
## Para criar uma asa nova: gere a textura em tools/asas/build_asas.py, duplique um
## .tres de res://data/asas/ e acrescente-o na lista em GameState.

@export var display_name := "Asa-delta"
@export_multiline var description := ""
## Crédito do modelo 3D (aparece na tela de seleção).
@export var credits := ""
## Textura da asa: atlas de tools/asas/build_asas.py (metade esquerda = a vela vista
## de cima, metade direita = vista de baixo; moldura e cordas iguais nas duas).
@export var texture: Texture2D
## Cor de destaque da asa na tela de seleção.
@export var accent := Color(1.0, 0.82, 0.1)
