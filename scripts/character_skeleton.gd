class_name CharacterSkeleton
extends Resource
## Como o CharacterRig anima um modelo: os ossos de cada grupo (corpo, braços, rosto...),
## as animações extras e o jeito de pilotar (pose sentada, pegada no volante).
##
## Os valores padrão são os do Celerino (folha de papel com braço elástico). Um
## personagem com outro esqueleto ganha um .tres próprio (ex.: o do Jarbas, em
## res://data/personagens/) apontado por CharacterData.skeleton.

@export_group("Ossos")
## Coluna, de baixo para cima (respiração e inclinações do corpo).
@export var body := PackedStringArray(["body_01", "body_02", "body_03", "body_04", "body_05"])
## Quadril (gira junto com a pose sentada). Vazio = sem osso de quadril separado.
@export var hips := PackedStringArray()
## Clavículas (só seguem a pose sentada). Vazio = não tem.
@export var shoulders := PackedStringArray()
## Braço esquerdo: braço, antebraço e mão (nesta ordem). O direito, igual.
@export var arm_left := PackedStringArray(["upper_arm.L", "forearm.L", "hand.L"])
@export var arm_right := PackedStringArray(["upper_arm.R", "forearm.R", "hand.R"])
## Pernas: coxa, canela, pé e ponta do pé da esquerda e depois da direita.
@export var legs := PackedStringArray(["thigh.L", "shin.L", "foot.L", "toe.L", "thigh.R", "shin.R", "foot.R", "toe.R"])
@export var fingers_left := PackedStringArray(["index_01.L", "index_02.L", "index_03.L", "middle_01.L",
		"middle_02.L", "middle_03.L", "pinky_01.L", "pinky_02.L", "pinky_03.L", "thumb_01.L", "thumb_02.L", "thumb_03.L"])
@export var fingers_right := PackedStringArray(["index_01.R", "index_02.R", "index_03.R", "middle_01.R",
		"middle_02.R", "middle_03.R", "pinky_01.R", "pinky_02.R", "pinky_03.R", "thumb_01.R", "thumb_02.R", "thumb_03.R"])
## Ossos das expressões (camada do rosto).
@export var face := PackedStringArray(["brow.L", "brow.R", "eye.L", "eye.R", "eyelid.L", "eyelid.R", "mouth",
		"jaw", "teeth_lower", "teeth_upper", "tongue", "lip_corner.L", "lip_corner.R"])
## Olhos (para onde o personagem olha).
@export var eyes := PackedStringArray(["eye.L", "eye.R"])
## Pálpebras (piscada).
@export var lids := PackedStringArray(["eyelid.L", "eyelid.R"])
## Pálpebras que fecham descendo (deslocamento em Y, como no Celerino): quanto descem
## até fechar. 0 = pálpebras que fecham girando; o limite sai da animação `blink`.
@export var eyelid_closed_offset := -0.332
## Ossos auxiliares que levam uma fração (`follow_share`) do giro de outro osso: osso
## auxiliar → osso seguido. No Blender é uma restrição (Copy Rotation com influência),
## que o glb não leva. O Ulysses tem um no meio do cotovelo, do joelho e de cada lado do
## quadril, seguindo metade do giro do antebraço, da canela e da coxa: a malha da dobra
## gira só a metade e não murcha. O CharacterRig refaz o giro deles a cada quadro,
## depois do IK de braços e pernas.
@export var follow_bones := {}
@export_range(0.0, 1.0, 0.05) var follow_share := 0.5

@export_group("Animações")
## Animações que completam ou substituem as do modelo (mesmos nomes do Celerino:
## idle, gesture_*, face_*, hand_*, body_*, eyes_look_*, blink...).
@export var animations: AnimationLibrary
## Animação parada em pé (telas de seleção e retratos) que mexe o corpo todo: quadril,
## coluna, clavículas, braços e pernas. Vazio = `idle` só na coluna e nos braços (a
## respiração do Celerino).
@export var stand_idle := &""

@export_group("Pose de piloto")
## Animação com a pose sentada no kart (quadril, pernas, braços e dedos). Vazio = pose
## montada por código: pernas apontadas por thigh_direction e shin_direction.
@export var drive_pose := &""
## Pose sentada na moto (veículos com turn_lean_degrees). Vazio = a mesma do kart.
@export var bike_pose := &""
## Direção das coxas e canelas sem drive_pose (espaço do personagem: +Z = frente).
@export var thigh_direction := Vector3(0.12, -0.12, 1.0)
@export var shin_direction := Vector3(0.05, -0.5, 1.0)
## Inclinação para a frente ao pilotar (peso da animação body_lean_forward).
@export var lean_forward := 0.25
## Braços com cotovelo (IK de dois ossos, como uma pessoa). Desligado = braço reto e
## elástico de desenho animado (o do Celerino).
@export var bend_elbows := false
## Para onde o cotovelo esquerdo aponta (espaço do personagem: +X = esquerda dele,
## +Z = frente). O direito usa o espelho.
@export var elbow_pole := Vector3(1.0, -1.0, 0.0)
## Ponto da mão esquerda fechada (espaço do osso da mão) por onde passa a barra do
## volante. A mão direita usa o espelho em X.
@export var grip_point := Vector3(0.03, 0.18, 0.0)
## Direção da barra dentro da mão esquerda fechada, para o lado do polegar (espaço do
## osso da mão). A mão direita usa o espelho em X.
@export var grip_axis := Vector3(0.0, 0.0, 1.0)
## Pegada da mão direita quando ela não é o espelho da esquerda (pose assimétrica, como a
## do Henrique): ponto e direção da barra no espaço do osso da mão direita. Zero = o
## espelho em X de grip_point e grip_axis.
@export var grip_point_right := Vector3.ZERO
@export var grip_axis_right := Vector3.ZERO
## Quanto o braço pode esticar (1 = tamanho normal). Com cotovelo, ele só estica
## depois de ficar reto e de o tronco já ter inclinado o máximo.
@export var max_arm_stretch := 2.6
## Quanto o punho pode dobrar (graus) para a mão acompanhar a barra.
@export var max_wrist_bend_degrees := 35.0
## Para as mãos alcançarem o volante (só com cotovelo), o personagem primeiro
## desliza para a frente no banco até `max_seat_slide` (no modelo, em metros), depois
## inclina o tronco até `max_reach_lean` (peso extra de body_lean_forward; 1 = a
## inclinação inteira da animação) e só então estica o braço.
@export var max_seat_slide := 0.0
@export var max_reach_lean := 0.0

@export_group("Sentar no kart")
## Monta a pose sentada a partir do cockpit de cada kart (KartData, grupo Cockpit) em vez
## de usar a da animação como está: o bumbum apoia no estofado e encosta no encosto, o
## tronco fica paralelo ao encosto e inclina a partir do quadril para alcançar o volante
## (antes de deslizar no banco), e as pernas esticam por IK até o calcanhar apoiar no
## estofado ou no assoalho, sem passar dos pedais. Kart sem medidas: pose da animação.
## Na moto só o quadril se ajusta (no selim); as pernas ficam as da `bike_pose`.
@export var fit_seat := false
## Articulação do quadril (osso de `hips`) em relação ao bumbum, no modelo: altura acima
## da base e distância à frente das costas.
@export var hip_above_seat := 0.112
@export var hip_ahead_of_back := 0.13
## Quanto o tronco da `drive_pose` deita para trás (graus). O quadril gira para ele ficar
## paralelo ao encosto do kart.
@export var pose_recline := 14.0
## Inclinação para a frente a partir do quadril com `max_reach_lean` = 1 (graus).
@export_range(0.0, 60.0, 0.5) var max_hip_lean := 35.0
## Fração da inclinação usada antes de deslizar no banco (o resto vem depois de deslizar
## tudo o que o estofado deixa).
@export_range(0.0, 1.0, 0.05) var lean_before_slide := 0.6
## Quanto o pescoço e a cabeça desfazem da inclinação (0 = acompanham, 1 = a cabeça fica
## como estava): o piloto continua olhando a pista.
@export_range(0.0, 1.0, 0.05) var head_counter := 0.6
## Fração da perna esticada até onde o pé vai (o resto dobra no joelho).
@export_range(0.5, 1.0, 0.01) var leg_extension := 0.96
## Pé apoiado no calcanhar: comprimento (do tornozelo à ponta, no modelo), altura do
## tornozelo acima do apoio (no modelo) e inclinação (graus acima da horizontal).
@export var foot_length := 0.2
@export var ankle_lift := 0.07
@export_range(0.0, 90.0, 1.0) var foot_pitch := 55.0
## Para onde o joelho esquerdo aponta (x = para fora, y = para cima, z = para a frente).
@export var knee_pole := Vector3(0.35, 1.0, 0.3)

