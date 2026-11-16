class_name KartData
extends Resource
## Dados de um kart: modelo 3D, ajustes de escala e atributos.
## Para criar um kart novo: duplique res://data/karts/standard_kart.tres,
## troque o modelo e os atributos, e adicione-o na lista em GameState.

const STAT_KEYS := ["speed", "acceleration", "handling", "weight"]

@export var display_name := "Kart"
@export_multiline var description := ""
## Crédito do modelo 3D (aparece na seleção de kart).
@export var credits := ""

@export_group("Modelo 3D")
@export var model_scene: PackedScene
## Escala aplicada ao modelo (o kart deve ficar com ~2,4 m de comprimento).
@export var model_scale := 1.0
## Rotação do modelo. A frente do kart precisa apontar para -Z.
@export var model_rotation_degrees := Vector3(0, 180, 0)
## Deslocamento para centralizar o modelo no corpo do kart.
@export var model_offset := Vector3.ZERO

@export_group("Na corrida")
## Escala do modelo com o piloto durante a corrida (as telas de seleção usam 1).
## Menor que 1 em veículos altos, para não taparem a pista atrás da câmera.
@export_range(0.5, 1.5, 0.01) var race_scale := 1.0
## Inclinação máxima (graus) para DENTRO da curva, como uma moto: veículo e piloto
## deitam juntos para o lado da curva. 0 = kart comum (a carroceria balança um
## pouco para fora).
@export_range(0.0, 45.0, 0.5) var turn_lean_degrees := 0.0
## Caixa de batida (largura, altura, comprimento em m, já na escala da corrida, centrada
## no kart): paredes, outros karts, caixas de item, obstáculos e moedas. Zero = a caixa
## padrão dos karts (a de res://scenes/kart.tscn). Veículos bem mais estreitos ou curtos
## que um kart (como a moto) precisam da sua.
@export var hitbox_size := Vector3.ZERO

@export_group("Atributos (1 a 5)")
@export_range(1, 5) var speed := 3
@export_range(1, 5) var acceleration := 3
@export_range(1, 5) var handling := 3
@export_range(1, 5) var weight := 3

@export_group("Rodas")
## Nomes dos nós das rodas dianteiras dentro do modelo (giram e esterçam).
@export var front_wheels: PackedStringArray = []
## Nomes dos nós das rodas traseiras dentro do modelo (só giram).
@export var rear_wheels: PackedStringArray = []
## Raio das rodas em metros (já na escala do jogo).
@export var front_wheel_radius := 0.22
@export var rear_wheel_radius := 0.27

@export_group("Piloto e volante")
## Ponto do banco onde fica a base do corpo do piloto (espaço do kart, frente = -Z).
@export var seat_position := Vector3(0, 0.33, 0.3)
## Nós do volante dentro do modelo (giram quando o kart vira).
@export var steering_wheel_nodes: PackedStringArray = []
## Centro do volante (espaço do kart). É o pivô do giro e o centro do aro.
@export var steering_wheel_center := Vector3(0, 0.665, -0.16)
## Eixo do volante, apontando para o piloto.
@export var steering_wheel_axis := Vector3(0, 0.545, 0.839)
## Raio da linha central do aro na altura das mãos (onde a barra passa pelo punho).
## Em volantes retangulares (manche), é a distância até a barra lateral.
@export var steering_wheel_radius := 0.24
## Posição das mãos no aro, em graus a partir do topo (70 ≈ "10 e 2", 90 = "9 e 3",
## nas barras laterais de um manche).
@export var hand_angle := 70.0
## Pegada que não fica num aro (guidão de moto): ponto da manopla onde a mão DIREITA
## segura, no espaço do kart. A esquerda é o espelho em volta do centro do volante.
## Zero = as mãos seguram o aro (raio + ângulo acima).
@export var hand_grip_point := Vector3.ZERO
## Direção da manopla nesse ponto, para onde aponta o polegar da mão direita (num
## guidão: para dentro, em direção ao meio da moto).
@export var hand_grip_axis := Vector3.ZERO

@export_group("Turbo")
## Saídas de escapamento/turbinas na traseira, de onde sai o fogo do turbo
## (espaço do kart). Vazio = uma saída genérica no meio da traseira.
@export var exhausts: Array[KartExhaust] = []


## As saídas do turbo (ou uma genérica, se o kart não tiver nenhuma mapeada).
func get_exhausts() -> Array[KartExhaust]:
	if not exhausts.is_empty():
		return exhausts
	var fallback := KartExhaust.new()
	fallback.position = Vector3(0, 0.45, 1.15)
	fallback.radius = 0.08
	return [fallback]


## Cria o modelo 3D já com escala, rotação e deslocamento aplicados.
func instantiate_model() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Modelo"
	if model_scene == null:
		push_warning("KartData '%s' está sem modelo 3D." % display_name)
		return holder
	var model := model_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * model_scale
	model.rotation_degrees = model_rotation_degrees
	model.position = model_offset
	holder.add_child(model)
	return holder


## Atributos finais (1 a 5) do kart com o piloto: o piloto soma (valor - 3) a cada um.
func combined_stats(character: CharacterData) -> Dictionary:
	var out := {}
	for key in STAT_KEYS:
		var value: int = get(key)
		if character:
			value += int(character.get(key)) - 3
		out[key] = clampi(value, 1, 5)
	return out
