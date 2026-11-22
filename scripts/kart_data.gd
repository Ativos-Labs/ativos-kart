class_name KartData
extends Resource
## Dados de um kart: modelo 3D, ajustes de escala e atributos.
## Para criar um kart novo: duplique res://data/karts/standard_kart.tres,
## troque o modelo e os atributos, e adicione-o na lista em GameState.
##
## Tamanho: padrão "Encaixe piloto × kart". Os pilotos (Jarbas, Henrique, Ulysses) nunca
## mudam de escala: o veículo é que se ajusta a eles, pela distância do assento
## (`seat_point`) ao centro do volante (`steering_wheel_center`), igual à do kart de
## referência (o Kart Padrão, com o modelo original na escala 0,06). Kart novo: meça o
## assento e rode tools/karts/encaixe_karts.py, que escala o modelo e todas as medidas
## deste recurso (veja "Encaixe piloto × kart" no README do jogo).

const STAT_KEYS := ["speed", "acceleration", "handling", "weight"]

## Kart de referência do encaixe (espaço do kart: frente = -Z, Y para cima, em metros):
## S · assento (vinco entre o fundo do banco e o encosto, na linha central) e W · centro
## do volante. Com o piloto em escala 1 e a origem dele na origem do kart, a POSE_Kart
## põe o quadril sobre S e as mãos no aro em volta de W (aro de Ø 0,217 m na linha de
## pega, inclinado 59°, mãos a 70° do topo).
const REF_SEAT := Vector3(0.0, 0.111, 0.118)
const REF_WHEEL := Vector3(0.0, 0.307, -0.196)
## Na moto (POSE_Moto, média dos pilotos): o selim embaixo do quadril e o meio do guidão.
const REF_SADDLE := Vector3(0.0, 0.282, 0.030)
const REF_BAR := Vector3(0.0, 0.502, -0.326)

@export var display_name := "Kart"
@export_multiline var description := ""
## Crédito do modelo 3D (aparece na seleção de kart).
@export var credits := ""

@export_group("Modelo 3D")
@export var model_scene: PackedScene
## Escala aplicada ao modelo (sai do encaixe: tools/karts/encaixe_karts.py).
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
## (Arrays empacotados: declare com `:= PackedStringArray()`. Com `: PackedStringArray
## = []` o export do Godot 4.7 grava o valor vazio no .res e as rodas ficam paradas no
## executável e na web, mesmo girando no editor.)
## Nomes dos nós das rodas dianteiras dentro do modelo (giram e esterçam).
@export var front_wheels := PackedStringArray()
## Nomes dos nós das rodas traseiras dentro do modelo (só giram).
@export var rear_wheels := PackedStringArray()
## Raio das rodas em metros (já na escala do jogo).
@export var front_wheel_radius := 0.22
@export var rear_wheel_radius := 0.27

@export_group("Piloto e volante")
## S · assento do encaixe: ponto da linha central onde o fundo do banco encontra o encosto
## (o vinco), no espaço do kart (frente = -Z). Na moto, o ponto do selim embaixo do
## quadril. Os pilotos do padrão entram com a origem em driver_origin().
@export var seat_point := Vector3.ZERO
## Ponto do banco onde fica a base do corpo do Celerino e dos adversários (espaço do
## kart, frente = -Z). Os pilotos do padrão usam seat_point.
@export var seat_position := Vector3(0, 0.33, 0.3)
## Nós do volante dentro do modelo (giram quando o kart vira).
@export var steering_wheel_nodes := PackedStringArray()
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
## Onde fica o tornozelo DIREITO dos pilotos do padrão (espaço do kart; o esquerdo é o
## espelho em X), em veículos cujo painel ou capô é mais baixo que o do kart de
## referência: as pernas da POSE_Kart (joelhos altos) atravessariam a carenagem, então
## esticam por IK até aqui, com o quadril onde a pose deixou. Zero = pernas da pose.
@export var foot_point := Vector3.ZERO
## Pegada que não fica num aro (guidão de moto): ponto da manopla onde a mão DIREITA
## segura, no espaço do kart. A esquerda é o espelho em volta do centro do volante.
## Zero = as mãos seguram o aro (raio + ângulo acima).
@export var hand_grip_point := Vector3.ZERO
## Direção da manopla nesse ponto, para onde aponta o polegar da mão direita (num
## guidão: para dentro, em direção ao meio da moto).
@export var hand_grip_axis := Vector3.ZERO

@export_group("Cockpit")
## Medidas do banco e do assoalho para pilotos de proporção humana (o Jarbas), que
## sentam no estofado, encostam no encosto e esticam as pernas até o assoalho. O
## Celerino não usa. Medidas no modelo (espaço do kart, frente = -Z) com mapas de
## ocupação da faixa das pernas (x de 0,06 a 0,16 m); veja tools/personagens/README.md.
## Zero = sem medida: o piloto usa a pose da animação em `seat_position`.
## Canto entre o estofado e o encosto: altura do estofado (y) e onde as costas encostam (z).
@export var seat_back_point := Vector3.ZERO
## Quanto o encosto deita para trás (graus a partir da vertical). Em motos não vale.
@export_range(0.0, 45.0, 0.5) var seat_back_angle := 0.0
## Onde o estofado acaba na frente (z). Daí para a frente os pés apoiam no assoalho.
@export var seat_front_z := 0.0
## Altura do assoalho na frente do banco.
@export var floor_height := 0.0
## Até onde os pés podem ir (z da parede da frente ou dos pedais): a ponta do pé para aí.
@export var foot_limit_z := 0.0
## Distância do meio do kart até o meio de cada pé (x).
@export var foot_spread := 0.12

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


## Origem do piloto do padrão "Encaixe piloto × kart" no espaço do kart: o assento menos
## o assento de referência (o piloto entra em escala 1, sem giro além de virar para a
## frente, e a pose sentada leva o corpo até o banco e as mãos até o volante).
func driver_origin() -> Vector3:
	return seat_point - (REF_SADDLE if is_bike() else REF_SEAT)


## Moto (deita nas curvas, piloto na POSE_Moto).
func is_bike() -> bool:
	return turn_lean_degrees > 0.0


## Medidas do cockpit para o CharacterRig (vazio = sem medida). Espaço do kart.
func cockpit() -> Dictionary:
	if seat_back_point == Vector3.ZERO:
		return {}
	return {
		"seat_back_point": seat_back_point, "seat_back_angle": seat_back_angle,
		"seat_front_z": seat_front_z, "floor_height": floor_height,
		"foot_limit_z": foot_limit_z, "foot_spread": foot_spread,
	}


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
