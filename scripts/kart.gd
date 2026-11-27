class_name Kart
extends CharacterBody3D
## Kart arcade no estilo Mario Kart.
## Acelerar, frear/ré, virar, pulinho + drift com mini-turbo (azul, laranja, roxo),
## pulos de rampa (com manobra no ar que dá turbo na aterrissagem) e caixas de item.
## Curvas têm atrito (o kart perde velocidade virando; derrapando perde menos), as
## moedas Ativos aumentam um pouco a velocidade máxima e os obstáculos da pista fazem
## o kart rodar e perder moedas. No drift as rodas de trás deixam marcas no chão e
## levantam poeira (ou neve) com a cara do cenário.
## Nas rampas de asa-delta o kart sobe alto, a asa abre em cima dele e ele plana: desce
## devagar, vira com o direcional (inclinando como um avião) e o freio levanta o bico
## (desce mais devagar, mas perde velocidade). Ao tocar o chão a asa fecha.
## Itens (a lógica fica em RaceItems): o raio do Deságio faz o kart rodar e encolher
## (mais lento, leve, motor fininho; um kart grande que encosta o amassa) e a tinta do
## Juridiquês marca `blind_time` (o piloto do computador ziguezagueia). Na
## Superpreferência o kart vira o ofício gigante: anda sozinho num trilho que a corrida
## calcula (start_super), sem bater em nada e sem levar golpe, e quem ele alcança fica
## achatado (run_over). O foguete da RPV levanta o modelo (`visual_lift`).
## Os itens de Ataque (carimbo, envelope, calculadora) acertam com hit_by_item (roda,
## perde moedas; a explosão joga o kart para o alto) e a Constituição da PEC dos
## Precatórios deixa o kart "parcelado" (parcel): ele anda aos pedacinhos, em trancos.

signal bumped(strength: float)
signal boost_started(power: int)
signal drift_level_changed(level: int)
## Decolou de uma rampa de pulo.
signal jumped
## Voltou ao chão depois de um pulo de rampa (`strength` 0..1 = força da queda).
signal landed(strength: float)
## Fez uma manobra no ar (drift apertado logo na saída da rampa).
signal trick_performed
## Passou por uma caixa de item. A lógica dos itens entra em quem ouve este sinal.
signal item_box_collected(box: Node3D)
## Encostou em outro kart (`strength` 0..1). Os dois karts emitem.
signal kart_bumped(other: Kart, strength: float)
## Pegou uma moeda (mesmo com o máximo de moedas).
signal coin_collected
## O número de moedas mudou.
signal coins_changed(coins: int)
## Foi atingido por um obstáculo da pista (rodou ou levou uma onda) e perdeu `lost` moedas.
signal obstacle_hit(lost: int, splash: bool)
## A asa-delta abriu (decolou de uma rampa de asa-delta) / fechou (tocou o chão).
signal glider_opened
signal glider_closed
## Encolheu (raio do Deságio) / voltou ao tamanho normal.
signal shrunk(on: bool)
## Encolhido, foi atropelado por um kart de tamanho normal (ficou amassado).
signal squashed
## Parcelado (PEC dos Precatórios): andou mais um pedacinho (`paid` de `total`).
signal parcel_paid(paid: int, total: int)
## Com o Trânsito em julgado, passou por cima de outro kart e o derrubou.
signal knocked(other: Kart)
## Entrou (true) ou saiu (false) da água.
signal splashed(entering: bool)

## Chão embaixo do kart (a corrida define com Track.surface_at): areia batida nas dunas
## (igual ao asfalto), areia fofa nas bordas das dunas, redemoinho de areia movediça,
## gelo (escorrega), neve batida (pista de neve: escorrega um pouco), areia batida da
## pista do deserto e da praia (escorrega bem pouco), água rasa da praia (segura um
## pouco e levanta respingos) e terra batida da trilha da mata (quase como o asfalto).
enum Surface { ASFALTO, AREIA, AREIA_FOFA, AREIA_MOVEDICA, GELO, NEVE, AREIA_BATIDA, AGUA_RASA, TERRA }

const GRAVITY := 32.0
## Quão rápido o "cima" do kart segue o da pista nas curvas inclinadas (1/s).
const UP_FOLLOW_SHARPNESS := 18.0
const HOP_VELOCITY := 4.6
const MIN_DRIFT_SPEED := 9.0
## Tempo de drift (s) para atingir cada nível de mini-turbo.
const DRIFT_LEVEL_TIMES := [0.0, 0.8, 1.8, 3.0]
## Duração do turbo (s) ao soltar o drift em cada nível.
const DRIFT_BOOST_TIMES := [0.0, 0.6, 1.05, 1.6]
## Giro no drift como fração do turn_rate: direcional para fora (arco aberto)
## e para dentro (arco fechado). Solto fica no meio.
const DRIFT_TURN_WIDE := 0.3
const DRIFT_TURN_TIGHT := 0.85
## Quanto o modelo gira para dentro da curva no drift (rad), e o extra ao fechar o arco.
const DRIFT_VISUAL_YAW := 0.13
const DRIFT_VISUAL_YAW_TIGHT := 0.04
## Motos (KartData.turn_lean_degrees > 0): fração da velocidade máxima em que a
## inclinação chega ao máximo, e rapidez com que o veículo deita e levanta.
const BIKE_LEAN_FULL_SPEED := 0.55
const BIKE_LEAN_SHARPNESS := 6.0
## --- Pulos de rampa ---
## A frente do kart passou da borda da rampa (m antes da borda): decola.
const LIP_REACH := 0.9 * KartScale.ITEMS
## Desvio máximo (rad) entre o kart e a rampa na decolagem; acima disso a rampa
## endireita o kart (assim ninguém sai voando de lado por cima da mureta).
const RAMP_ALIGN_MAX := 0.24
## Manobra: apertar o drift até TRICK_WINDOW s depois de decolar (ou até
## TRICK_EARLY s antes, ainda na rampa). Dá TRICK_BOOST s de turbo ao aterrissar.
const TRICK_WINDOW := 0.4
const TRICK_EARLY := 0.25
const TRICK_BOOST := 0.9
## Manobras no ar. A cada pulo uma é sorteada (nunca a mesma do pulo anterior).
##   GIRO: giro completo de lado (em volta do eixo do kart), piloto com os braços para cima.
##   MORTAL: mortal para trás (bico sobe e dá a volta), piloto gritando, agarrado no volante.
##   PIAO: um giro completo na horizontal, meio deitado, piloto com o braço de fora no
##         alto (rodeio).
##   PARAFUSO: giro fora do eixo (no meio da volta o kart fica quase de lado), mãozinhas.
##   DEITADO: o kart deita de lado, segura e volta; o piloto dá tchau com o braço de cima.
##   SEM_MAOS: empina o bico e balança, o piloto solta o volante e abre os braços.
## Os gestos precisam aparecer por cima do encosto (a câmera fica atrás): apontar e
## joinha ficam escondidos atrás do banco.
enum Trick { GIRO, MORTAL, PIAO, PARAFUSO, DEITADO, SEM_MAOS }
## Duração (s) de cada manobra quando o pulo dá tempo; em pulo curto ela acelera para
## terminar antes de aterrissar (mas não fica mais curta que TRICK_MIN_TIME).
const TRICK_TIMES := [0.55, 0.62, 0.52, 0.6, 0.66, 0.62]
const TRICK_MIN_TIME := 0.3
## Folga (s) entre o fim da manobra e a aterrissagem prevista.
const TRICK_LAND_MARGIN := 0.1
## Altura do eixo do giro da manobra (meio do kart).
const TRICK_PIVOT := 0.55 * KartScale.ITEMS
## Queda livre (sem rampa) a partir deste tempo no ar também conta como pulo.
const LONG_AIR_TIME := 0.5
## --- Asa-delta ---
## Velocidade de subida (m/s) na borda de uma rampa de asa-delta: a mesma para todos
## (o voo não depende de chegar rápido na rampa).
const GLIDE_LAUNCH_VY := 15.0
## A asa abre este tempo (s) depois da decolagem, perto do alto do arco (dá tempo de
## fazer a manobra antes).
const GLIDE_OPEN_DELAY := 0.4
## Planando: velocidade de descida (m/s) normal e segurando o freio (bico para cima).
const GLIDE_SINK := 2.0
const GLIDE_SINK_SLOW := 0.8
## Com que força (m/s²) a descida vai até a velocidade de planeio (subindo ou caindo).
const GLIDE_GRAVITY := 9.0
## Depois deste tempo planando (s) a asa cansa: a descida aumenta GLIDE_TIRED_SINK m/s a
## cada segundo (o voo sempre acaba dentro do trecho cercado da rampa).
const GLIDE_TIRED_TIME := 4.5
const GLIDE_TIRED_SINK := 1.6
## No ar a asa vira esta fração do giro no chão (sem asa, só 0,35) e segura o kart na
## direção para onde ele aponta com esta fração da aderência (sem asa, 0,4).
const GLIDE_TURN := 0.8
const GLIDE_TRACTION := 0.6
## Planando a velocidade vai até a máxima do kart (m/s²); segurando o freio, até esta
## fração dela.
const GLIDE_SPEED_RATE := 3.0
const GLIDE_SLOW_SPEED := 0.72
## Inclinação para dentro da curva (rad, direcional todo) e bico para baixo planando.
const GLIDE_BANK := 0.32
const GLIDE_NOSE := -0.06
## Velocidade mínima (fração da máxima) na decolagem de uma rampa de asa-delta.
const GLIDE_MIN_LAUNCH := 0.88
## Pouso: passada a beira do outro lado do vale (glide_land), a asa desce até esta
## velocidade (m/s), ganhando GLIDE_LAND_ACCEL m/s por segundo — o kart toca o chão
## logo depois da beira, em qualquer cilindrada.
const GLIDE_LAND_SINK := 12.0
const GLIDE_LAND_ACCEL := 26.0
## Bico para baixo na descida do pouso (rad).
const GLIDE_LAND_NOSE := -0.16
## Asa usada quando o kart não recebeu uma (`glider` vazio).
const DEFAULT_GLIDER := "res://data/asas/asa_rubra.tres"

## Debaixo d'água: fração da gravidade (pulos longos e lentos), da velocidade máxima e
## da aceleração.
const UNDERWATER_GRAVITY := 0.5
const UNDERWATER_SPEED := 0.94
const UNDERWATER_ACCEL := 0.85
## Quanto do meio do kart precisa estar abaixo da superfície para contar como submerso.
const UNDERWATER_DEPTH := 0.5
## Gelo: fração da aderência (o kart desliza de lado), no drift e do giro.
const ICE_GRIP := 0.24
const ICE_DRIFT_GRIP := 0.45
const ICE_TURN := 0.9
## Neve batida (pista de neve e gelo): fração da aderência, fora e dentro do drift — o
## kart solta um pouco a traseira, mas bem menos que no gelo.
const SNOW_GRIP := 0.72
const SNOW_DRIFT_GRIP := 0.9
## Na neve, acima dessa velocidade (m/s) as rodas levantam um véu de neve fina, com
## essa fração das partículas da poeira.
const SNOW_SPRAY_SPEED := 18.0
const SNOW_SPRAY := 0.22
## Areia batida (pista do deserto): fração da aderência, fora e dentro do drift, e o véu
## de areia que as rodas levantam rápido (como a neve).
const SAND_GRIP := 0.84
const SAND_DRIFT_GRIP := 0.95
const SAND_SPRAY_SPEED := 17.0
const SAND_SPRAY := 0.25
## Água rasa da praia (TrackSection RASO): fração da velocidade máxima, da aceleração
## e da aderência; acima de SHALLOW_SPRAY_SPEED (m/s) as rodas jogam água para os lados.
const SHALLOW_SPEED := 0.96
const SHALLOW_ACCEL := 0.9
const SHALLOW_GRIP := 0.9
const SHALLOW_SPRAY_SPEED := 6.0
## Terra batida (trilha da mata na pista de praia): fração da aderência, fora e dentro
## do drift.
const DIRT_GRIP := 0.92
const DIRT_DRIFT_GRIP := 0.97
## Areia fofa (bordas das dunas) e areia movediça: fração da velocidade máxima.
const SOFT_SAND_SPEED := 0.78
const QUICKSAND_SPEED := 0.55
## Puxão do redemoinho de areia movediça para o meio dele (m/s²) e o giro que ele dá.
const QUICKSAND_PULL := 34.0
const QUICKSAND_SPIN := 0.7
const ICE_MARK := Color(0.82, 0.9, 1.0, 0.45)
## Pulinho na crista de uma duna: velocidade (m/s) a partir da qual o kart sai do chão
## e quanto ele sobe por m/s acima dela (m/s), até o máximo.
const DUNE_HOP_FROM := 19.0
const DUNE_HOP_GAIN := 0.27
const DUNE_HOP_MAX := 3.6
## --- Moedas ---
## Máximo de moedas e quanto cada uma soma na velocidade máxima (fração).
const MAX_COINS := 10
const COIN_SPEED_BONUS := 0.006
## Empurrãozinho (m/s) ao pegar uma moeda.
const COIN_PUSH := 0.6
## Moedas perdidas ao ser atingido por um obstáculo.
const COIN_LOSS := 3
## --- Obstáculos ---
## Duração do rodopio (s), parte dele sem controle, e tempo protegido depois de um
## acerto (o mesmo obstáculo não acerta duas vezes seguidas).
const SPIN_TIME := 0.9
const SPIN_LOCK := 0.65
const HIT_COOLDOWN := 1.6
## Deságio (item): tamanho do kart encolhido e quanto da velocidade máxima sobra.
const SHRINK_SCALE := 0.5
const SHRINK_SPEED := 0.8
## Encolhido e atropelado por um kart grande: fica amassado por esse tempo (s), sem
## acelerar no começo, e sobra essa fração da velocidade.
const FLAT_TIME := 1.4
const FLAT_LOCK := 0.45
const FLAT_SLOW := 0.3
## PEC dos Precatórios (parcelado): duração de cada parcela (s), a fração dela em que o
## kart anda, a velocidade desse tranco (× a máxima) e o pulinho no começo de cada uma
## (m/s). No resto da parcela ele quase para.
const PARCEL_STEP := 0.5
const PARCEL_MOVE := 0.4
const PARCEL_SPEED := 0.7
const PARCEL_HOP := 2.6
## Trânsito em julgado (invencível): velocidade máxima (×), aceleração (×) e o empurrão
## (m/s) em quem ele derruba. Fora do asfalto ele não perde velocidade.
const JUDGED_SPEED := 1.18
const JUDGED_ACCEL := 2.4
const JUDGED_PUSH := 9.0
## Fila do tribunal: freada (m/s²) até parar esperando a senha.
const QUEUE_BRAKE := 42.0
## --- Atrito nas curvas ---
## Desaceleração (m/s²) quando a curva segura o kart abaixo da velocidade dele.
const CORNER_SCRUB := 4.5
## --- Som do motor ---
## Amostras da forma de onda do motor sintetizado (uma volta inteira da fase, 0 a 4π).
const ENGINE_TABLE_SIZE := 4096
## Alcance (m) do som 3D do motor dos adversários: mais longe que isso ele não se ouve.
const ENGINE_3D_RANGE := 60.0
## --- Acelerando parado na largada ---
## Na contagem regressiva, segurando o acelerador, o kart "esquenta" no lugar (como no
## Mario Kart 8 Deluxe): as rodas de trás patinam, sai fumaça dos pneus e a traseira
## escorrega de leve para um lado e para o outro. Só nos karts dos jogadores.
## Rapidez (por s) com que a patinada chega ao máximo e some ao soltar ou na largada.
const REV_RISE := 2.5
const REV_FALL := 3.0
## Velocidade (m/s) que as rodas de trás giram a mais que o chão com o acelerador todo.
const REV_WHEEL_SPEED := 14.0
## Balanço da traseira (rad, em volta do eixo da frente), tremida do motor (rad de
## inclinação e m de pulinho) e o bico que sobe com a traseira agachada (rad).
const REV_SWAY := 0.05
const REV_SHAKE := 0.012 * KartScale.ITEMS
const REV_BOUNCE := 0.01 * KartScale.ITEMS
const REV_SQUAT := 0.03
## Fumaça dos pneus: partículas por roda de trás e duração de cada uma (s).
const REV_SMOKE_AMOUNT := 18
const REV_SMOKE_LIFETIME := 0.95
## --- Marcas de pneu ---
const MARK_WIDTH := 0.27 * KartScale.ITEMS
const ROAD_MARK := Color(0.04, 0.04, 0.05, 0.62)
const DRIFT_COLORS := [
	Color(1.0, 0.95, 0.8, 0.55),
	Color(0.25, 0.65, 1.0),
	Color(1.0, 0.55, 0.1),
	Color(0.95, 0.35, 1.0),
]

## Dados do kart (modelo e atributos). Defina antes de adicionar à cena.
@export var data: KartData
## Piloto sentado no kart (opcional). Defina antes de adicionar à cena.
@export var character: CharacterData
## Asa-delta que abre nas rampas de asa-delta (null = a primeira de GameState). Defina
## antes de adicionar à cena.
@export var glider: GliderData
## Kart de um jogador (lê o controle dele). Os adversários do computador usam o
## `autopilot`. Defina antes de adicionar à cena.
@export var is_player := true
## Só um jogador na corrida: o kart dele tem o som de motor sintetizado e a luz do
## turbo. Na tela dividida todos usam o som 3D mais leve (cada jogador ouve o seu
## kart mais perto da câmera dele). Defina antes de adicionar à cena.
@export var lone_player := true
## Prefixo das ações do controle deste jogador ("" = teclado e todos os controles;
## "j2_" = só o controle do J2). Veja PlayerSlot.
@export var input_prefix := ""
## Classe de velocidade (GameState.SPEED_CLASSES): multiplica a velocidade máxima e a
## aceleração. Defina antes de adicionar à cena.
@export var speed_class := 1.0

@export_group("Direção")
@export var max_speed := 27.0
@export var acceleration := 15.0
@export var brake_force := 32.0
@export var reverse_speed := 9.0
@export var coast_drag := 5.0
@export var turn_rate := 1.72
## Fração do giro que sobra na velocidade máxima (menor = mais estável em alta).
@export var high_speed_turn := 0.75
@export var grip := 9.0
## Aderência no drift: baixa demais faz o kart rodar em vez de deslizar.
@export var drift_grip := 7.25
## Fator de velocidade máxima na grama.
@export var offroad_factor := 0.5
## Multiplicador de velocidade máxima durante o turbo.
@export var boost_factor := 1.35
## Atrito nas curvas: fração da velocidade máxima perdida virando tudo na velocidade
## máxima (a perda cresce com a força da curva). Derrapando perde bem menos.
@export var corner_slowdown := 0.12
@export var drift_corner_slowdown := 0.05

@export_group("Sensibilidade")
## Quão rápido o volante vai até o fim (por segundo). Menor = mais suave.
@export var steer_speed := 4.5
## Quão rápido o volante volta ao centro (por segundo).
@export var steer_return_speed := 7.0
## Curva do analógico: acima de 1 os movimentos pequenos viram menos (mais precisão).
@export var steer_curve := 1.5
## Suavização da rotação do kart (maior = responde mais rápido).
@export var yaw_smoothing := 10.0

## Liga/desliga o controle (desligado na contagem regressiva).
var controls_enabled := false
## Se válido, substitui o controle do jogador: func(kart) -> Dictionary.
var autopilot: Callable
## Velocidade para frente em m/s (negativa = ré).
var speed := 0.0
var steer_input := 0.0
var throttle_input := 0.0
## Definido pela corrida: true quando o kart está fora do asfalto.
var is_offroad := false
## Chão embaixo (Surface), definido pela corrida a cada quadro.
var surface := Surface.ASFALTO
## Centro (global) e raio do redemoinho de areia movediça em que o kart está.
var pit_center := Vector4.INF
## Altura (global) da água da pista: abaixo dela o kart fica submerso (-INF = sem água).
var water_level := -INF
var underwater := false
## Andando no baixio da praia (Surface.AGUA_RASA).
var _in_shallows := false
## Pulinho de duna pedido pela corrida (aplicado no próximo passo de física).
var _dune_hop := 0.0
## Bolhas e respingos (criados na primeira vez que a pista tem água).
var water_fx: KartWaterFx
var drifting := false
var drift_dir := 0
var drift_level := 0
var boost_time := 0.0
## Multiplica a velocidade máxima (o piloto do computador usa para o ritmo e o elástico).
var speed_multiplier := 1.0
## Peso (1 a 5, kart + piloto): nas batidas entre karts o mais pesado empurra mais.
var weight_stat := 3
## Tela dividida: cada tela é menor e o kart aparece menor de longe, então o detalhe do
## piloto cai mais perto da câmera (as distâncias contam multiplicadas por isto).
var lod_scale := 1.0
## Moedas Ativos (0 a MAX_COINS): cada uma soma COIN_SPEED_BONUS na velocidade máxima.
var coins := 0
## Marcas de pneu da corrida (null = sem marcas, como nas telas de seleção).
var skid_marks: SkidMarks
## Caixa de batida em uso (largura, altura, comprimento em m; KartData.hitbox_size).
var hitbox_size := Vector3.ZERO
## Quanto a caixa de batida é menor que a padrão dos karts, de cada lado (m): x = na
## largura, y = no comprimento. 0 nos karts comuns; obstáculos e moedas descontam isso
## do alcance deles (a moto, mais estreita, passa mais perto sem bater nem pegar).
var hitbox_shrink := Vector2.ZERO

var _vertical := 0.0
var _steer := 0.0
var _yaw_rate := 0.0
var _want_drift := false
var _drift_time := 0.0
var _prev_speed := 0.0
var _visual_yaw := 0.0
var _visual_roll := 0.0
var _visual_pitch := 0.0
## Inclinação do chão (rampas e pontes) aplicada ao modelo.
var _ground_pitch := 0.0
var _ground_roll := 0.0
var _was_on_floor := true
## "Cima" da pista embaixo do kart (a corrida atualiza; Vector3.UP fora das curvas
## inclinadas). Nas curvas inclinadas a gravidade e o corpo do kart seguem este eixo,
## por isso dá para andar na parede.
var ground_up := Vector3.UP
var _up := Vector3.UP
var _bump_cooldown := 0.0
var _kart_bump_cooldown := 0.0
## true no ar depois de decolar de uma rampa (até aterrissar).
var ramp_jump := false
var _air_time := 0.0
## Velocidade vertical do chão sob o kart (subindo uma rampa = positiva).
var _ground_vy := 0.0
var _trick_buffer := 0.0
var _trick_window := 0.0
## Manobra em andamento (Trick) ou -1.
var trick := -1
## Progresso da manobra em segundos (-1 = sem manobra) e a duração dela.
var _trick_t := -1.0
var _trick_len := 0.5
var _trick_dir := 1.0
var _trick_boost := false
## Última manobra feita (o sorteio não repete) e tempo no ar previsto na decolagem.
var _last_trick := -1
var _air_expected := 0.0
## Planando com a asa-delta aberta (até tocar o chão).
var gliding := false
## Decolou de uma rampa de asa-delta e a asa ainda vai abrir.
var _glide_pending := false
## Tempo planando (s) e o freio segurado no ar (0..1, suavizado): bico para cima.
var _glide_time := 0.0
var _glide_pull := 0.0
## Descendo para o pouso (veja glide_land).
var _glide_landing := false
## A asa em cima do kart (null sem asa) e onde ela fica no modelo (GliderVisual.fit_to).
var glider_visual: GliderVisual
var _glider_mount := Vector3.ZERO
## Mola da suspensão (aterrissagem): deslocamento vertical do modelo e velocidade.
var _squash := 0.0
var _squash_vel := 0.0
var _land_dust := 0.0
var _engine: AudioStreamGeneratorPlayback
var _engine_phase := 0.0
var _engine_rev := 0.0
## Motor dos adversários: um som curto em loop, com o tom mudando pela velocidade.
var _engine_3d: AudioStreamPlayer3D
## Rampas de pulo da pista (relidas de vez em quando, veja _current_ramp).
var _ramps: Array[Node] = []
var _ramps_frame := -1
## Rodopio de um obstáculo: progresso (s, -1 = sem), voltas (0 = só balança, onda) e lado.
var _spin_t := -1.0
var _spin_turns := 1.0
var _spin_dir := 1.0
var _hit_cooldown := 0.0
## Deságio: segundos que faltam encolhido (0 = tamanho normal).
var shrink_time := 0.0
## Juridiquês: segundos com a visão coberta de tinta. O jogador vê a tinta no HUD; o
## piloto do computador ziguezagueia e alivia o pé (KartAI).
var blind_time := 0.0
## Altura extra do modelo (m): o foguete da RPV passa embaixo dele.
var visual_lift := 0.0
## Tamanho do modelo (1 = normal; mola até SHRINK_SCALE e de volta, com um balanço).
var _size := 1.0
var _size_vel := 0.0
## Tempo desde que foi amassado (-1 = não está).
var _flat_t := -1.0
## Parcelado: tempo que falta (s), o que falta da parcela atual (s) e as parcelas pagas.
var _parcel_left := 0.0
var _parcel_phase := 0.0
var _parcel_count := 0
var _parcel_paid := 0
## Superpreferência: devolve a posição do kart neste passo (veja start_super).
var _super_rail: Callable
var _super_layer := 1
## Trânsito em julgado: tempo (s) que falta invencível.
var judged_time := 0.0
## Fila do tribunal: tempo (s) que falta parado, esperando a senha ser chamada.
var queue_time := 0.0
## Perda de velocidade (fração) pela curva neste quadro.
var _corner_loss := 0.0
## Rodas de trás (espaço do kart, no chão): uma trilha de marca e uma poeira por roda.
var _rear_points := PackedVector3Array()
var _skid_trails := PackedInt32Array()
var _marking := false
var _offroad_mark := Color(0.2, 0.24, 0.08, 0.5)
var _dust_emitters: Array[GPUParticles3D] = []
## Acelerando parado na largada: força (0..1, suavizada), relógio do balanço, se o
## acelerador está apertado, a fumaça de cada roda de trás (só jogadores) e o eixo da
## frente (espaço do Visual), em volta do qual a traseira balança.
var _rev := 0.0
var _rev_t := 0.0
var _revving := false
var _rev_smoke: Array[GPUParticles3D] = []
var _rev_smoke_ratio := -1.0
var _rev_pivot := Vector3(0.0, 0.0, -0.7)
## Formas de colisão e posições das faíscas como vêm da cena (a caixa padrão dos karts).
var _scene_body_shape: BoxShape3D
var _scene_floor_shape: CapsuleShape3D
var _scene_body_bottom := 0.0
var _scene_spark_points := PackedVector3Array()
var _dust_ratio := -1.0
## Rodas e volante longe da câmera: refeitos a cada N passos (acumulando o tempo).
var _motion_every := 1
var _motion_skipped := 0
var _motion_delta := 0.0
var _engine_buffer := PackedVector2Array()
## Forma de onda do motor sintetizado (veja _engine_wave).
static var _engine_table := PackedFloat32Array()
## Câmeras de corrida deste quadro (lidas uma vez por quadro, não uma vez por kart).
static var _cams: Array[Node] = []
static var _cams_frame := -1

@onready var visual: Node3D = $Visual
@onready var model_slot: Node3D = $Visual/ModelSlot
@onready var sparks_left: GPUParticles3D = $Visual/SparksL
@onready var sparks_right: GPUParticles3D = $Visual/SparksR
@onready var dust: GPUParticles3D = $Visual/Dust
@onready var engine_audio: AudioStreamPlayer = $EngineAudio

## Modelo do kart com o piloto (rodas, volante e personagem).
var kart_visual: KartVisual
## Fogo do turbo saindo dos escapamentos deste kart (KartData.exhausts).
var boost_fx: BoostExhaustFx
## O personagem sentado no kart (null se o kart estiver sem piloto).
var driver: CharacterRig:
	get:
		return kart_visual.driver if kart_visual else null


func _ready() -> void:
	add_to_group(&"kart")
	# O material das faíscas é da cena: cada kart precisa do seu, senão a cor do
	# drift de um kart muda as faíscas de todos.
	var spark_mat := sparks_left.process_material.duplicate() as ParticleProcessMaterial
	sparks_left.process_material = spark_mat
	sparks_right.process_material = spark_mat
	# Uma poeira por roda de trás (a da cena vira a da esquerda).
	_dust_emitters = [dust]
	var dust_right := dust.duplicate() as GPUParticles3D
	dust_right.name = "DustR"
	visual.add_child(dust_right)
	_dust_emitters.append(dust_right)
	if data:
		apply_data(data, character)
	_set_sparks(-1)
	_setup_engine_audio()


## Monta o modelo com o piloto e ajusta a física pelos atributos do kart + piloto.
func apply_data(d: KartData, c: CharacterData = null) -> void:
	data = d
	character = c
	for child in model_slot.get_children():
		child.queue_free()
	kart_visual = KartVisual.new()
	kart_visual.name = "KartVisual"
	model_slot.add_child(kart_visual)
	kart_visual.setup(d, c)
	kart_visual.scale = Vector3.ONE * d.race_scale
	boost_fx = BoostExhaustFx.new()
	boost_fx.name = "FogoTurbo"
	kart_visual.add_child(boost_fx)
	# Só o kart do jogador acende uma luz no chão, e não na web: lá cada luz extra
	# redesenha o que ela ilumina (asfalto incluído), caro para um enfeite.
	boost_fx.setup(d, is_player and lone_player and not OS.has_feature("web"))
	_setup_glider()
	var stats := d.combined_stats(c)
	max_speed = (22.0 + stats.speed * 1.7) * speed_class
	acceleration = (9.0 + stats.acceleration * 2.0) * speed_class
	# No 150cc o kart vira um pouco mais (senão as curvas fechadas ficam impossíveis);
	# no 50cc vira o mesmo, com o raio de curva menor pela velocidade.
	turn_rate = (1.3 + stats.handling * 0.14) * sqrt(maxf(speed_class, 1.0))
	grip = 7.5 + stats.handling * 0.5
	drift_grip = 6.5 + stats.handling * 0.25
	offroad_factor = 0.44 + stats.weight * 0.02
	weight_stat = stats.weight
	# Quem tem mais manobrabilidade perde menos velocidade nas curvas.
	corner_slowdown = 0.155 - stats.handling * 0.012
	drift_corner_slowdown = corner_slowdown * 0.4
	_rear_points = kart_visual.rear_contact_points()
	for i in _rear_points.size():
		_rear_points[i] *= d.race_scale
	for i in _dust_emitters.size():
		var p := _dust_emitters[i]
		p.visible = i < _rear_points.size()
		if p.visible:
			p.position = _rear_points[i] + Vector3(0.0, 0.08, 0.15) * KartScale.ITEMS
	_rev_pivot = kart_visual.front_axle_center() * d.race_scale
	_setup_rev_smoke()
	_apply_hitbox(d.hitbox_size)
	_place_sparks()
	if skid_marks:
		set_skid_marks(skid_marks)


## Monta a asa-delta (escondida até a primeira rampa de asa-delta), com as cordas
## presas na carroceria. Ela fica fora do modelo: acompanha a inclinação do kart, mas
## não gira junto nas manobras.
func _setup_glider() -> void:
	if glider_visual:
		glider_visual.queue_free()
		glider_visual = null
	var g := glider
	if g == null and ResourceLoader.exists(DEFAULT_GLIDER):
		# Sem asa escolhida (sondas, testes): a primeira da tela de seleção. Lida pelo
		# caminho, sem o GameState: as rampas (@tool) usam as constantes deste script.
		g = load(DEFAULT_GLIDER) as GliderData
	if g == null:
		return
	glider_visual = GliderVisual.new()
	glider_visual.name = "AsaDelta"
	add_child(glider_visual)
	glider_visual.setup(g)
	_glider_mount = glider_visual.fit_to(kart_visual) if kart_visual else Vector3(0.0, 0.9 * KartScale.ITEMS, 0.0)
	if gliding:
		glider_visual.set_open(true, true)


## Troca a caixa de batida pela do veículo (zero = a padrão da cena). As formas da cena
## são as mesmas para todos os karts, então quem tem caixa própria ganha cópias suas.
## A base da caixa fica na mesma altura; o apoio no chão (cápsula) encurta junto.
func _apply_hitbox(size: Vector3) -> void:
	var body := $ColisaoCorpo as CollisionShape3D
	var floor_col := $ColisaoChao as CollisionShape3D
	if _scene_body_shape == null:
		_scene_body_shape = body.shape as BoxShape3D
		_scene_floor_shape = floor_col.shape as CapsuleShape3D
		_scene_body_bottom = body.position.y - _scene_body_shape.size.y * 0.5
	var base := _scene_body_shape.size
	if size == Vector3.ZERO or size.is_equal_approx(base):
		hitbox_size = base
		hitbox_shrink = Vector2.ZERO
		body.shape = _scene_body_shape
		body.position.y = _scene_body_bottom + base.y * 0.5
		floor_col.shape = _scene_floor_shape
		return
	hitbox_size = size
	hitbox_shrink = Vector2(base.x - size.x, base.z - size.z) * 0.5
	var box := BoxShape3D.new()
	box.size = size
	body.shape = box
	body.position.y = _scene_body_bottom + size.y * 0.5
	var capsule := _scene_floor_shape.duplicate() as CapsuleShape3D
	capsule.radius = minf(capsule.radius, size.x * 0.5)
	capsule.height = maxf(_scene_floor_shape.height - hitbox_shrink.y * 2.0, capsule.radius * 2.0)
	floor_col.shape = capsule


## Faíscas do drift: nos karts ficam nas laterais da traseira (posição da cena); na moto
## (uma roda atrás) saem dos dois lados do pneu, senão brotariam no ar ao lado dela.
func _place_sparks() -> void:
	if _scene_spark_points.is_empty():
		_scene_spark_points = PackedVector3Array([sparks_left.position, sparks_right.position])
	sparks_left.position = _scene_spark_points[0]
	sparks_right.position = _scene_spark_points[1]
	if _rear_points.size() == 1:
		var p := _rear_points[0]
		sparks_left.position = Vector3(p.x - 0.1 * KartScale.ITEMS, _scene_spark_points[0].y, p.z)
		sparks_right.position = Vector3(p.x + 0.1 * KartScale.ITEMS, _scene_spark_points[1].y, p.z)
	elif _rear_points.size() == 2:
		# Nas rodas de trás, um pouco para fora (o tamanho de cada kart saiu do encaixe).
		var l := _rear_points[0] if _rear_points[0].x < _rear_points[1].x else _rear_points[1]
		var r := _rear_points[1] if _rear_points[0].x < _rear_points[1].x else _rear_points[0]
		sparks_left.position = Vector3(l.x - 0.04, _scene_spark_points[0].y, l.z)
		sparks_right.position = Vector3(r.x + 0.04, _scene_spark_points[1].y, r.z)


## Fumaça dos pneus da largada (só nos karts dos jogadores): uma por roda de trás, com
## a malha da poeira e um material de partícula com os mesmos recursos do dela
## (TrackTheme.dust_material), então nenhum shader novo compila na hora.
func _setup_rev_smoke() -> void:
	if not is_player:
		return
	if _rev_smoke.is_empty():
		var mat := _rev_smoke_material()
		for i in 2:
			var p := GPUParticles3D.new()
			p.name = "FumacaLargada%d" % i
			p.emitting = false
			p.amount = REV_SMOKE_AMOUNT
			p.lifetime = REV_SMOKE_LIFETIME
			p.randomness = 0.4
			p.process_material = mat
			p.draw_pass_1 = dust.draw_pass_1
			visual.add_child(p)
			_rev_smoke.append(p)
	for i in _rev_smoke.size():
		var p := _rev_smoke[i]
		p.visible = i < _rear_points.size()
		if p.visible:
			p.position = _rear_points[i] + Vector3(0.0, 0.1, 0.12) * KartScale.ITEMS


## Fumaça branca de pneu: sai para trás e para cima, perde a força logo, sobe devagar
## abrindo em nuvens grandes e some aos poucos.
func _rev_smoke_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.1, 0.03, 0.06) * KartScale.ITEMS
	m.direction = Vector3(0.0, 1.0, 0.8)
	m.spread = 35.0
	m.initial_velocity_min = 1.0 * KartScale.ITEMS
	m.initial_velocity_max = 2.2 * KartScale.ITEMS
	m.damping_min = 1.5 * KartScale.ITEMS
	m.damping_max = 2.5 * KartScale.ITEMS
	m.gravity = Vector3(0.0, 1.8, 0.0) * KartScale.ITEMS
	m.scale_min = 1.1
	m.scale_max = 2.0
	m.color = Color(0.86, 0.86, 0.86, 0.62)
	var size := Curve.new()
	size.add_point(Vector2(0.0, 0.3))
	size.add_point(Vector2(1.0, 1.0))
	var size_tex := CurveTexture.new()
	size_tex.curve = size
	m.scale_curve = size_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.5, Color(1, 1, 1, 0.65))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	m.color_ramp = fade_tex
	return m


## Acelerando parado na largada (veja REV_*): a força sobe enquanto o jogador segura o
## acelerador com o controle ainda desligado (contagem) e cai rápido ao soltar ou na
## largada. Também liga a fumaça dos pneus e põe o piloto concentrado.
func _update_rev(delta: float) -> void:
	var target := _engine_rev if is_player and not controls_enabled else 0.0
	_rev = move_toward(_rev, target, (REV_RISE if target > _rev else REV_FALL) * delta)
	_rev_t = _rev_t + delta if _rev > 0.0 else 0.0
	var revving := target > 0.5
	if revving != _revving:
		_revving = revving
		# Na largada (controle ligado) quem muda a cara é a corrida.
		if driver and not controls_enabled:
			driver.set_face(&"face_angry" if revving else &"face_smiling")
	if _rev_smoke.is_empty():
		return
	var smoking := _rev > 0.15 and is_on_floor()
	if smoking:
		# Mais fumaça com a patinada mais forte (só muda o que dá para notar).
		var ratio := snappedf(lerpf(0.35, 1.0, _rev), 0.1)
		if not is_equal_approx(ratio, _rev_smoke_ratio):
			_rev_smoke_ratio = ratio
			for p in _rev_smoke:
				p.amount_ratio = ratio
	for i in mini(_rev_smoke.size(), _rear_points.size()):
		var p := _rev_smoke[i]
		if p.emitting != smoking:
			p.emitting = smoking


## Na contagem, o jogador está segurando o acelerador (o kart patina parado).
func is_revving() -> bool:
	return _revving


## Liga as marcas de pneu (uma trilha por roda de trás).
func set_skid_marks(marks: SkidMarks) -> void:
	skid_marks = marks
	_skid_trails.clear()
	_marking = false
	if marks == null:
		return
	for i in _rear_points.size():
		_skid_trails.append(marks.new_trail())


## Poeira e marcas com a cara do cenário da pista (TrackTheme.Scenery).
## Passou rápido pela crista de uma duna: sai do chão um pouquinho.
func crest_hop() -> void:
	if not is_on_floor() or drifting or gliding:
		return
	_dune_hop = clampf((absf(speed) - DUNE_HOP_FROM) * DUNE_HOP_GAIN, 0.0, DUNE_HOP_MAX)


## A pista tem água em `level` (altura global): o kart passa a ficar submerso abaixo
## dela (bolhas, gravidade menor) e respinga ao entrar e sair.
func set_water_level(level: float) -> void:
	water_level = level
	if water_fx == null:
		water_fx = KartWaterFx.new()
		add_child(water_fx)
		water_fx.position = Vector3(0.0, 0.25, 0.45) * KartScale.ITEMS


## Entrou ou saiu da água neste passo? Na água rasa da praia o kart nunca conta como
## submerso: ele respinga ao entrar e ao sair do baixio e joga água enquanto anda.
func _update_water() -> void:
	if water_level == -INF:
		return
	var shallow := surface == Surface.AGUA_RASA and global_position.y > water_level - 1.0
	if shallow != _in_shallows:
		_in_shallows = shallow
		if water_fx:
			water_fx.burst(Vector3(global_position.x, water_level, global_position.z))
		splashed.emit(shallow)
	if water_fx:
		water_fx.set_spray(shallow and is_on_floor() and absf(speed) > SHALLOW_SPRAY_SPEED, absf(speed) / maxf(max_speed, 1.0))
	var now := global_position.y + UNDERWATER_DEPTH * KartScale.ITEMS < water_level and not shallow
	# Curva inclinada: a borda de baixo pode ficar abaixo do nível da água (o chão afunda
	# junto), mas ali não tem água — senão o kart entraria e sairia dela a cada volta.
	if ground_up != Vector3.UP:
		now = false
	if now == underwater:
		return
	underwater = now
	if water_fx:
		water_fx.set_underwater(now)
		water_fx.burst(Vector3(global_position.x, water_level, global_position.z))
	splashed.emit(now)


## Luzes do jogador nas pistas à noite: uma luz suave em volta do kart (para ver o
## chão, as muretas e os outros karts por perto) e um farol iluminando a pista à frente.
## Sem sombra (barato também na web).
func add_player_lights() -> void:
	if has_node("LuzEmVolta"):
		return
	var glow := OmniLight3D.new()
	glow.name = "LuzEmVolta"
	glow.position = Vector3(0.0, 2.4, 0.4)
	glow.omni_range = 11.0
	glow.omni_attenuation = 0.9
	glow.light_energy = 1.6
	glow.light_color = Color(0.86, 0.82, 1.0)
	glow.light_specular = 0.25
	glow.shadow_enabled = false
	add_child(glow)
	var beam := SpotLight3D.new()
	beam.name = "Farol"
	beam.position = Vector3(0.0, 1.3, -0.6)
	beam.rotation = Vector3(deg_to_rad(-9.0), 0.0, 0.0)
	beam.spot_range = 42.0
	beam.spot_angle = 30.0
	beam.spot_angle_attenuation = 1.4
	beam.spot_attenuation = 0.8
	beam.light_energy = 3.2
	beam.light_color = Color(1.0, 0.95, 0.86)
	beam.light_specular = 0.35
	beam.shadow_enabled = false
	add_child(beam)


func set_ground_theme(scenery: int) -> void:
	_offroad_mark = TrackTheme.offroad_mark_color(scenery)
	var mat := TrackTheme.dust_material(scenery)
	var life := TrackTheme.dust_lifetime(scenery)
	for p in _dust_emitters:
		p.process_material = mat
		p.lifetime = life
		p.amount = 20


func get_forward() -> Vector3:
	var f := -global_basis.z
	if _up == Vector3.UP:
		f.y = 0.0
	else:
		f -= _up * f.dot(_up)
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


## "Cima" do kart: o da pista embaixo dele (Vector3.UP fora das curvas inclinadas).
func get_up() -> Vector3:
	return _up


## Segue `ground_up` aos poucos: gira o corpo do kart (mantendo a frente) para o novo
## "cima". Fora das curvas inclinadas fica exatamente em Vector3.UP.
func _follow_ground_up(delta: float) -> void:
	if ground_up == Vector3.UP and _up == Vector3.UP:
		return
	var goal := ground_up.normalized()
	var next := _up.slerp(goal, 1.0 - exp(-UP_FOLLOW_SHARPNESS * delta)).normalized()
	if next.dot(goal) > 0.99995:
		next = goal
	var turn := Quaternion(_up, next)
	_up = Vector3.UP if next.is_equal_approx(Vector3.UP) else next
	var fwd := turn * -global_basis.z
	fwd -= _up * fwd.dot(_up)
	if fwd.length_squared() < 0.0001:
		fwd = get_forward()
	global_basis = Basis.looking_at(fwd.normalized(), _up)
	velocity = turn * velocity
	up_direction = _up


func get_speed_kmh() -> float:
	return absf(speed) * 3.6


## Dá um turbo por `duration` segundos. Com `instant` a velocidade pula na hora;
## sem (turbo de largada, com karts logo à frente no grid) ela sobe bem rápido.
func apply_boost(duration: float, power := 1, instant := true) -> void:
	boost_time = maxf(boost_time, duration)
	if instant:
		speed = maxf(speed, max_speed * speed_multiplier * 1.12)
	boost_started.emit(power)
	if boost_fx:
		boost_fx.ignite(power)
	if driver:
		driver.react_boost(power)


## Coloca o kart numa posição e zera o movimento.
func teleport(xform: Transform3D) -> void:
	if is_super():
		end_super(false)
	# O corpo do kart fica sempre em pé (só gira no eixo vertical); numa rampa a
	# inclinação aparece só no modelo (veja _update_visuals).
	var up := xform.basis.y.normalized()
	if up.dot(Vector3.UP) > 0.9999:
		up = Vector3.UP
	_up = up
	ground_up = up
	up_direction = up
	var fwd := -xform.basis.z
	fwd -= up * fwd.dot(up)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(fwd.normalized(), up), xform.origin)
	_ground_pitch = 0.0
	_ground_roll = 0.0
	velocity = Vector3.ZERO
	speed = 0.0
	_vertical = 0.0
	boost_time = 0.0
	_steer = 0.0
	_yaw_rate = 0.0
	_want_drift = false
	_cancel_drift()
	ramp_jump = false
	_air_time = 0.0
	_ground_vy = 0.0
	_trick_t = -1.0
	trick = -1
	_trick_boost = false
	_trick_window = 0.0
	_trick_buffer = 0.0
	_spin_t = -1.0
	_flat_t = -1.0
	_parcel_left = 0.0
	queue_time = 0.0
	_corner_loss = 0.0
	_glide_pending = false
	_glide_pull = 0.0
	surface = Surface.ASFALTO
	pit_center = Vector4.INF
	if gliding:
		gliding = false
		glider_closed.emit()
	if glider_visual:
		glider_visual.set_open(false, true)
	_break_skid_marks()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var input := _gather_input()
	var throttle: float = input.throttle
	var brake: float = input.brake
	var raw_steer: float = input.steer
	var drift_held: bool = input.drift
	var drift_pressed: bool = input.drift_pressed
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	blind_time = maxf(blind_time - delta, 0.0)
	judged_time = maxf(judged_time - delta, 0.0)
	queue_time = maxf(queue_time - delta, 0.0)
	if shrink_time > 0.0:
		shrink_time -= delta
		if shrink_time <= 0.0:
			shrink_time = 0.0
			shrunk.emit(false)
	if _super_rail.is_valid():
		_super_step(delta)
		return
	if (_spin_t >= 0.0 and _spin_t < SPIN_LOCK) or (_flat_t >= 0.0 and _flat_t < FLAT_LOCK) or queue_time > 0.0:
		# Rodando depois de um obstáculo (ou amassado, ou na fila do tribunal): sem
		# controle por um instante.
		throttle = 0.0
		brake = 0.0
		raw_steer = 0.0
		drift_held = false
		drift_pressed = false
	var steer := _smooth_steer(raw_steer, delta)
	steer_input = steer
	throttle_input = throttle
	_update_water()
	_follow_ground_up(delta)
	var on_floor := is_on_floor()
	var ramp := _current_ramp() if on_floor else null
	_trick_buffer = maxf(_trick_buffer - delta, 0.0)
	_trick_window = maxf(_trick_window - delta, 0.0)

	# --- Asa-delta: abre perto do alto do arco; no ar o freio levanta o bico. ----
	if _glide_pending and not on_floor and _air_time >= GLIDE_OPEN_DELAY:
		_open_glider()
	_glide_pull = move_toward(_glide_pull, brake if gliding else 0.0, 3.0 * delta)
	if gliding:
		_glide_time += delta

	# --- Pulinho, drift e manobra --------------------------------------------
	if drift_pressed:
		if ramp:
			# Na rampa o botão não dá pulinho (estragaria a decolagem): vale como
			# manobra assim que o kart sair da borda.
			_trick_buffer = TRICK_EARLY
			_want_drift = true
		elif on_floor:
			# Na subida o pulinho soma a velocidade com que o chão sobe.
			_vertical = HOP_VELOCITY + maxf(_ground_vy, 0.0)
			on_floor = false
			_want_drift = true
			if driver:
				driver.bounce(-0.5)
		elif _trick_window > 0.0 and _trick_t < 0.0:
			_start_trick(raw_steer)
			_want_drift = true
	if not drift_held:
		_want_drift = false
		if drifting:
			_release_drift()
	# O lado do drift usa o direcional cru, para responder na hora do pulinho.
	if _want_drift and not drifting and on_floor and ramp == null and absf(raw_steer) > 0.25 and speed > MIN_DRIFT_SPEED:
		_start_drift(1 if raw_steer > 0.0 else -1)

	# --- Velocidade ----------------------------------------------------------
	# Moedas somam na velocidade máxima; a curva (atrito) e o Deságio (encolhido) tiram.
	var coin_bonus := (1.0 + coins * COIN_SPEED_BONUS) * _size_speed()
	_corner_loss = _corner_slowdown() if on_floor else 0.0
	# Trânsito em julgado: mais rápido e a grama não segura.
	var judged := judged_time > 0.0
	var offroad := is_offroad and on_floor and not judged
	var top := max_speed * speed_multiplier * coin_bonus * (offroad_factor if offroad else 1.0)
	# Areia fofa e movediça seguram o kart (a grama de fora já segura mais).
	var ground_factor := 1.0
	if on_floor and not judged and not offroad:
		if surface == Surface.AREIA_FOFA:
			ground_factor = SOFT_SAND_SPEED
		elif surface == Surface.AREIA_MOVEDICA:
			ground_factor = QUICKSAND_SPEED
	if underwater:
		ground_factor *= UNDERWATER_SPEED
	elif surface == Surface.AGUA_RASA and on_floor and not judged:
		ground_factor *= SHALLOW_SPEED
	top *= ground_factor
	var sinking := ground_factor < 0.95 and on_floor
	if judged:
		top *= JUDGED_SPEED
	top *= 1.0 - _corner_loss
	if boost_time > 0.0:
		boost_time -= delta
		# No turbo a curva pesa a metade (o mini-turbo sai ainda virando).
		top = max_speed * boost_factor * speed_multiplier * coin_bonus * (1.0 - _corner_loss * 0.5)
		if speed < top:
			speed = move_toward(speed, top, acceleration * 3.0 * delta)
		else:
			speed = move_toward(speed, top, (coast_drag + CORNER_SCRUB) * delta)
	elif gliding:
		# Planando: a asa leva o kart na velocidade máxima dele (freando, mais devagar).
		var glide_top := max_speed * speed_multiplier * coin_bonus * lerpf(1.0, GLIDE_SLOW_SPEED, _glide_pull)
		speed = move_toward(speed, glide_top, GLIDE_SPEED_RATE * delta)
	elif not on_floor:
		pass # No ar não há chão para acelerar nem frear: a velocidade se mantém.
	elif throttle > 0.05 and brake < 0.5:
		if speed < 0.0:
			speed = move_toward(speed, 0.0, brake_force * delta)
		var target := top * throttle
		if speed < target:
			var ratio := clampf(speed / max_speed, 0.0, 1.0)
			var accel := acceleration * lerpf(1.5, 0.45, ratio) * (JUDGED_ACCEL if judged else 1.0)
			if underwater:
				accel *= UNDERWATER_ACCEL
			elif surface == Surface.AGUA_RASA:
				accel *= SHALLOW_ACCEL
			speed = move_toward(speed, target, accel * delta)
		else:
			# Acima do alvo: na grama (e na areia fofa) freia forte; na curva o atrito
			# segura aos poucos.
			var drag := 16.0 if offroad or sinking else coast_drag + (CORNER_SCRUB if _corner_loss > 0.005 else 0.0)
			speed = move_toward(speed, target, drag * delta)
	elif brake > 0.05:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, brake_force * brake * delta)
		else:
			speed = move_toward(speed, -reverse_speed * brake, acceleration * 0.6 * delta)
	else:
		speed = move_toward(speed, 0.0, (coast_drag + (10.0 if offroad else 0.0)) * delta)
	if _parcel_left > 0.0:
		on_floor = _update_parcel(delta, throttle, on_floor)
	if queue_time > 0.0:
		# Fila do tribunal: para e espera a senha.
		boost_time = 0.0
		speed = move_toward(speed, 0.0, QUEUE_BRAKE * delta)

	# --- Curva ----------------------------------------------------------------
	var turn_factor := clampf(absf(speed) / 7.0, 0.0, 1.0)
	var yaw := 0.0
	if drifting:
		# O drift sempre curva para o lado escolhido; o direcional só abre ou fecha
		# o arco. Segurando para dentro ele fecha mais e carrega mais rápido.
		var rel := steer * drift_dir
		yaw = drift_dir * turn_rate * remap(rel, -1.0, 1.0, DRIFT_TURN_WIDE, DRIFT_TURN_TIGHT) * turn_factor
		_drift_time += delta * (1.0 + 0.6 * maxf(rel, 0.0))
		_update_drift_level()
		if speed < MIN_DRIFT_SPEED * 0.6 or brake > 0.5:
			_cancel_drift()
	else:
		var high_speed := lerpf(1.0, high_speed_turn, clampf(absf(speed) / max_speed, 0.0, 1.0))
		yaw = steer * turn_rate * turn_factor * high_speed * (1.0 if speed >= 0.0 else -1.0)
	if not on_floor:
		yaw *= GLIDE_TURN if gliding else 0.35
	elif surface == Surface.GELO:
		yaw *= ICE_TURN
	# Suaviza a velocidade de giro: o kart não dá trancos ao entrar/sair do drift.
	_yaw_rate = lerpf(_yaw_rate, yaw, 1.0 - exp(-yaw_smoothing * delta))
	if _up == Vector3.UP:
		rotate_y(_yaw_rate * delta)
	else:
		rotate(_up, _yaw_rate * delta)

	# --- Movimento ------------------------------------------------------------
	var fwd := get_forward()
	var horizontal := velocity - _up * velocity.dot(_up)
	var traction := drift_grip if drifting else grip
	if not on_floor:
		traction *= GLIDE_TRACTION if gliding else 0.4
	elif surface == Surface.GELO and not judged:
		# No gelo a velocidade demora para seguir o bico: o kart escorrega de lado.
		traction *= ICE_DRIFT_GRIP if drifting else ICE_GRIP
	elif surface == Surface.NEVE and not judged:
		traction *= SNOW_DRIFT_GRIP if drifting else SNOW_GRIP
	elif surface == Surface.AREIA_BATIDA and not judged:
		traction *= SAND_DRIFT_GRIP if drifting else SAND_GRIP
	elif surface == Surface.AGUA_RASA and not judged:
		traction *= SHALLOW_GRIP
	elif surface == Surface.TERRA and not judged:
		traction *= DIRT_DRIFT_GRIP if drifting else DIRT_GRIP
	horizontal = horizontal.lerp(fwd * speed, 1.0 - exp(-traction * delta))
	if surface == Surface.AREIA_MOVEDICA and on_floor and pit_center != Vector4.INF and not judged:
		# Redemoinho: puxa para o meio e gira o kart devagar.
		var to_center := Vector3(pit_center.x - global_position.x, 0.0, pit_center.z - global_position.z)
		var reach := clampf(to_center.length() / maxf(pit_center.w, 0.1), 0.0, 1.0)
		if to_center.length_squared() > 0.04:
			horizontal += to_center.normalized() * QUICKSAND_PULL * (0.4 + 0.6 * reach) * delta
		rotate_y(QUICKSAND_SPIN * (1.0 - reach) * delta)
	# Decolagem: quando a frente do kart passa da borda da rampa ele sai do chão
	# com a inclinação da borda (só a gravidade age a partir daí).
	if ramp and _vertical <= 0.0:
		var along := horizontal.dot(ramp.get_forward())
		if along > 2.0 and ramp.to_lip_space(global_position).z + along * delta >= -LIP_REACH:
			horizontal = _launch(ramp, horizontal)
			on_floor = false
	if _dune_hop > 0.0 and on_floor and _vertical <= 0.0:
		_vertical = _dune_hop
		on_floor = false
		if driver:
			driver.bounce(-0.6)
	_dune_hop = 0.0
	if on_floor and _vertical <= 0.0:
		_vertical = -2.0
	elif gliding:
		_vertical = move_toward(_vertical, -_glide_sink(), (GLIDE_LAND_ACCEL if _glide_landing else GLIDE_GRAVITY) * delta)
	else:
		_vertical -= GRAVITY * (UNDERWATER_GRAVITY if underwater else 1.0) * delta
	velocity = horizontal + _up * _vertical
	move_and_slide()
	var now_on_floor := is_on_floor()
	if now_on_floor:
		if not _was_on_floor:
			_on_landed(-_vertical)
		if _vertical < 0.0:
			_vertical = 0.0
		var n := get_floor_normal()
		var n_up := n.dot(_up)
		_ground_vy = -(n - _up * n_up).dot(horizontal) / maxf(n_up, 0.3)
		_air_time = 0.0
	else:
		if _was_on_floor and _vertical < 0.0:
			# Passou de uma borda sem pular: continua subindo com a velocidade com
			# que o chão subia (sem isso o kart "grudaria" e cairia reto).
			_vertical = maxf(_vertical, _ground_vy)
		_air_time += delta
	_was_on_floor = now_on_floor
	_handle_walls(fwd, delta)
	_update_skid_marks(now_on_floor)

	_update_visuals(delta, steer)
	_prev_speed = speed


func _process(_delta: float) -> void:
	if _engine_3d:
		_update_driver_detail()
		if _engine_3d.playing:
			# Só muda o tom quando a diferença é perceptível: na web cada troca vai para o
			# áudio do navegador.
			var pitch := _engine_frequency() / Sfx.ENGINE_BASE_FREQ
			if absf(pitch - _engine_3d.pitch_scale) > _engine_3d.pitch_scale * 0.004:
				_engine_3d.pitch_scale = pitch
	else:
		_fill_engine_audio()


## Liga ou desliga o som 3D do motor (adversários e tela dividida). Cada som 3D tocando
## recalcula volume e direção a cada passo de física, mesmo longe demais para ser ouvido;
## a corrida deixa tocar só os mais perto da câmera (Race._update_engine_voices).
func set_engine_audible(on: bool) -> void:
	if _engine_3d == null or _engine_3d.playing == on:
		return
	if on:
		_engine_3d.pitch_scale = _engine_frequency() / Sfx.ENGINE_BASE_FREQ
		_engine_3d.play()
	else:
		_engine_3d.stop()


func is_engine_audible() -> bool:
	return _engine_3d != null and _engine_3d.playing


func _exit_tree() -> void:
	_engine = null
	if engine_audio:
		engine_audio.stop()


func _gather_input() -> Dictionary:
	if is_player:
		_engine_rev = Input.get_action_strength(input_prefix + "acelerar")
	if not controls_enabled:
		return {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "drift": false, "drift_pressed": false}
	if autopilot.is_valid():
		return autopilot.call(self)
	var steer := Input.get_axis(input_prefix + "direita", input_prefix + "esquerda")
	# No analógico, toques leves viram pouco (o teclado continua indo de 0 a 1).
	steer = signf(steer) * pow(absf(steer), steer_curve)
	return {
		"throttle": Input.get_action_strength(input_prefix + "acelerar"),
		"brake": Input.get_action_strength(input_prefix + "frear"),
		"steer": steer,
		"drift": Input.is_action_pressed(input_prefix + "drift"),
		"drift_pressed": Input.is_action_just_pressed(input_prefix + "drift"),
	}


## Leva o volante até o valor pedido aos poucos (no teclado, de 0 a 1 em ~0,2 s)
## e o devolve ao centro um pouco mais rápido.
func _smooth_steer(target: float, delta: float) -> float:
	var returning := absf(target) < absf(_steer) or target * _steer < 0.0
	_steer = move_toward(_steer, target, (steer_return_speed if returning else steer_speed) * delta)
	return _steer


func _handle_walls(fwd: Vector3, delta: float) -> void:
	_bump_cooldown -= delta
	_kart_bump_cooldown -= delta
	var wall_done := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider() as Kart
		if other:
			_bump_kart(other, collision.get_normal(), fwd)
			continue
		if wall_done:
			continue
		var normal := collision.get_normal()
		var n_up := normal.dot(_up)
		if absf(n_up) > 0.6:
			continue
		normal = (normal - _up * n_up).normalized()
		var impact := -fwd.dot(normal) * speed
		if impact > 4.0 and _bump_cooldown <= 0.0:
			var strength := clampf(impact / max_speed, 0.0, 1.0)
			speed *= lerpf(0.8, 0.3, strength)
			velocity += normal * minf(impact * 0.45, 8.0)
			if drifting:
				_cancel_drift()
			_bump_cooldown = 0.25
			bumped.emit(strength)
			if driver:
				driver.react_bump(strength)
		else:
			speed = move_toward(speed, 0.0, 6.0 * delta)
		wall_done = true


## Encostou em outro kart: os dois se empurram para os lados (o mais pesado empurra
## mais). Quem bate por trás perde velocidade; o da frente quase nada.
## `normal` aponta do outro kart para este.
func _bump_kart(other: Kart, normal: Vector3, fwd: Vector3) -> void:
	if _kart_bump_cooldown > 0.0 or other._kart_bump_cooldown > 0.0:
		return
	var push := normal - _up * normal.dot(_up)
	if push.length_squared() < 0.04:
		# Em cima do outro kart (caiu de um pulo): escorrega para o lado.
		push = global_position - other.global_position
		push -= _up * push.dot(_up)
	if push.length_squared() < 0.0001:
		push = global_basis.x
	push = push.normalized()
	if is_judged() != other.is_judged():
		# Trânsito em julgado: quem está invencível derruba o outro e segue sem perder nada.
		var winner: Kart = self if is_judged() else other
		var loser: Kart = other if is_judged() else self
		if loser.hit_by_item((-push if winner == self else push) * JUDGED_PUSH, 0.35, 1.0):
			winner.knocked.emit(loser)
		_kart_bump_cooldown = 0.3
		other._kart_bump_cooldown = 0.3
		return
	var closing := maxf((fwd * speed - other.get_forward() * other.speed).dot(-push), 0.0)
	var strength := clampf(closing / 12.0, 0.0, 1.0)
	# Encolhido (Deságio) o kart é leve: o grande empurra e ainda passa por cima.
	var my_weight := _bump_weight()
	var other_weight := other._bump_weight()
	var my_share := other_weight / (my_weight + other_weight)
	if is_shrunk() and not other.is_shrunk():
		squash()
	elif other.is_shrunk() and not is_shrunk():
		other.squash()
	var impulse := 3.0 + closing * 0.55
	velocity += push * impulse * my_share * 2.0
	other.velocity -= push * impulse * (1.0 - my_share) * 2.0
	var nose_hit := -fwd.dot(push)
	if nose_hit > 0.5 and speed > other.speed:
		speed = lerpf(speed, other.speed, 0.5 * nose_hit)
	if strength > 0.35:
		if drifting:
			_cancel_drift()
		if driver:
			driver.react_bump(strength * 0.6)
		if other.driver:
			other.driver.react_bump(strength * 0.6)
	_kart_bump_cooldown = 0.3
	other._kart_bump_cooldown = 0.3
	kart_bumped.emit(other, strength)
	other.kart_bumped.emit(self, strength)


## Recebe uma caixa de item (chamado pela caixa).
func collect_item_box(box: Node3D) -> void:
	item_box_collected.emit(box)


# --- Atrito nas curvas -------------------------------------------------------------

## Fração da velocidade máxima que a curva tira agora. Cresce com a força lateral
## (velocidade × giro), comparada à de uma curva com o volante todo na velocidade
## máxima. Derrapando a perda é bem menor (e o drift ainda dá mini-turbo).
func _corner_slowdown() -> float:
	var full := turn_rate * high_speed_turn * max_speed
	var load := clampf(absf(_yaw_rate * speed) / maxf(full, 0.1), 0.0, 1.25)
	return load * (drift_corner_slowdown if drifting else corner_slowdown)


## Perda de velocidade (fração) pela curva no último quadro (0 = reta).
func get_corner_loss() -> float:
	return _corner_loss


# --- Moedas ---------------------------------------------------------------------

## Pegou uma moeda da pista (chamado por TrackCoins).
func add_coin() -> void:
	if coins < MAX_COINS:
		coins += 1
		coins_changed.emit(coins)
	if is_on_floor() and speed > 0.0:
		speed += COIN_PUSH
	coin_collected.emit()


## Perde até `count` moedas. Devolve quantas perdeu.
func lose_coins(count: int) -> int:
	var lost := mini(count, coins)
	if lost > 0:
		coins -= lost
		coins_changed.emit(coins)
	return lost


# --- Obstáculos ------------------------------------------------------------------

## Atingido por um obstáculo da pista (TrackObstacles). `push` = empurrão (m/s, no
## plano), `slow` = fração da velocidade que sobra e `spin` = roda uma volta inteira
## (pneu, fardo, bola de neve); sem `spin` o kart só balança (onda). Perde moedas.
## Devolve false se o kart ainda estava protegido do acerto anterior.
func hit_by_obstacle(push: Vector3, slow := 0.35, spin := true) -> bool:
	if _hit_cooldown > 0.0 or is_immune():
		return false
	_hit_cooldown = HIT_COOLDOWN
	_want_drift = false
	_cancel_drift()
	boost_time = 0.0
	_trick_boost = false
	speed *= slow
	push.y = 0.0
	velocity += push
	_spin_t = 0.0
	_spin_turns = 1.0 if spin else 0.0
	# Gira para o lado do empurrão.
	_spin_dir = -1.0 if push.dot(global_basis.x) > 0.0 else 1.0
	var lost := lose_coins(COIN_LOSS)
	obstacle_hit.emit(lost, not spin)
	if driver:
		driver.react_bump(1.0)
		driver.set_face(&"face_surprised", 1.4)
	return true


## Está rodando depois de um obstáculo?
func is_spinning() -> bool:
	return _spin_t >= 0.0


## Atingido por um item de Ataque (RaceItems): como um obstáculo (perde velocidade, o
## turbo e moedas), rodando `turns` voltas (0 = só balança) e, com `lift` (m/s), jogado
## para o alto (a explosão da Impugnação dos cálculos). Devolve false se o kart estava
## protegido (acabou de levar outro golpe, é o ofício da Superpreferência ou está com o
## Trânsito em julgado).
func hit_by_item(push: Vector3, slow := 0.3, turns := 1.0, lift := 0.0) -> bool:
	if not hit_by_obstacle(push, slow, true):
		return false
	_spin_turns = turns
	if lift > 0.0:
		_vertical = lift
		ramp_jump = false
		_close_glider()
	return true


## PEC dos Precatórios: o kart fica parcelado por `count` parcelas (PARCEL_STEP cada) —
## anda aos trancos, um pedacinho por vez, com um pulinho no começo de cada parcela.
func parcel(count: int) -> void:
	if is_immune():
		return
	_parcel_count = count
	_parcel_paid = 0
	_parcel_phase = 0.0
	_parcel_left = count * PARCEL_STEP
	_want_drift = false
	_cancel_drift()
	boost_time = 0.0


func is_parceled() -> bool:
	return _parcel_left > 0.0


## Um passo parcelado: no começo de cada parcela o kart dá um pulinho e um tranco para a
## frente; no resto dela freia quase até parar. O turbo não escapa. Devolve se o kart
## continua no chão.
func _update_parcel(delta: float, throttle: float, on_floor: bool) -> bool:
	_want_drift = false
	if drifting:
		_cancel_drift()
	if _parcel_phase <= 0.0 and _parcel_paid < _parcel_count:
		_parcel_phase = PARCEL_STEP
		_parcel_paid += 1
		parcel_paid.emit(_parcel_paid, _parcel_count)
		if on_floor and throttle > 0.05:
			_vertical = PARCEL_HOP
			on_floor = false
			_squash_vel -= 0.5 * KartScale.ITEMS
	_parcel_phase -= delta
	_parcel_left -= delta
	var moving := _parcel_phase > PARCEL_STEP * (1.0 - PARCEL_MOVE)
	var cap := max_speed * speed_multiplier * (PARCEL_SPEED if moving else 0.04)
	if speed > cap:
		speed = move_toward(speed, cap, 60.0 * delta)
	elif moving and throttle > 0.05:
		speed = move_toward(speed, cap * throttle, 80.0 * delta)
	if _parcel_left <= 0.0:
		_parcel_left = 0.0
	return on_floor


# --- Itens (RaceItems) -------------------------------------------------------------

## Atingido pelo raio do Deságio: roda uma volta, perde velocidade (e o turbo/drift) e
## fica pequeno por `duration` segundos. Não perde moedas.
func zap(duration: float) -> void:
	if is_immune():
		return
	_want_drift = false
	_cancel_drift()
	boost_time = 0.0
	_trick_boost = false
	speed *= 0.45
	_spin_t = 0.0
	_spin_turns = 1.0
	_spin_dir = 1.0 if randf() < 0.5 else -1.0
	shrink(duration)
	if driver:
		driver.react_bump(1.0)
		driver.set_face(&"face_surprised", 1.6)


## Fica pequeno (mais lento e leve) por pelo menos `duration` segundos.
func shrink(duration: float) -> void:
	var was := is_shrunk()
	shrink_time = maxf(shrink_time, duration)
	if not was:
		shrunk.emit(true)


## Volta ao tamanho normal na hora (quem usa o Deságio estando pequeno).
func grow() -> void:
	if shrink_time > 0.0:
		shrink_time = 0.0
		shrunk.emit(false)


func is_shrunk() -> bool:
	return shrink_time > 0.0


## Pequeno e atropelado por um kart grande: achata por um instante e quase para.
func squash() -> void:
	if _flat_t >= 0.0 or is_immune():
		return
	_flat_t = 0.0
	speed *= FLAT_SLOW
	_want_drift = false
	_cancel_drift()
	boost_time = 0.0
	squashed.emit()
	if driver:
		driver.set_face(&"face_surprised", 1.4)


## Está achatado (atropelado)?
func is_flat() -> bool:
	return _flat_t >= 0.0


## Atropelado pelo ofício da Superpreferência: achata, quase para e é jogado para o lado
## (`push`, m/s no plano).
func run_over(push: Vector3) -> void:
	if is_immune() or is_flat():
		return
	squash()
	push.y = 0.0
	velocity += push
	_spin_t = 0.0
	_spin_turns = 0.5
	_spin_dir = -1.0 if push.dot(global_basis.x) > 0.0 else 1.0


## Fila do tribunal: pegou a caixa falsa. Para e fica esperando a senha ser chamada por
## `duration` s, sem controle. Devolve false se o kart estava protegido.
func hold_in_line(duration: float) -> bool:
	if _hit_cooldown > 0.0 or is_immune():
		return false
	_hit_cooldown = HIT_COOLDOWN
	queue_time = duration
	_want_drift = false
	_cancel_drift()
	boost_time = 0.0
	_trick_boost = false
	if driver:
		driver.react_bump(0.6)
		driver.set_face(&"face_confused", duration)
	return true


## Está parado na fila do tribunal?
func is_waiting() -> bool:
	return queue_time > 0.0


# --- Trânsito em julgado ---------------------------------------------------------------

## Fica invencível por `duration` s: nada o atinge, ele derruba quem encosta, corre mais
## e a grama não o segura. Cura o que estava pegando (pequeno, amassado, parcelado, na
## fila) e dá um tranco de turbo.
func start_judged(duration: float) -> void:
	judged_time = maxf(judged_time, duration)
	grow()
	_spin_t = -1.0
	_flat_t = -1.0
	_parcel_left = 0.0
	queue_time = 0.0
	blind_time = 0.0
	apply_boost(0.45, 2)


func is_judged() -> bool:
	return judged_time > 0.0


## Nada o atinge agora (ofício da Superpreferência ou Trânsito em julgado)?
func is_immune() -> bool:
	return is_super() or judged_time > 0.0


# --- Superpreferência ----------------------------------------------------------------

## Vira o ofício: a cada passo de física `rail.call(kart, delta)` devolve onde o kart
## está (Transform3D global, base só girando no eixo vertical). O modelo some (o ofício
## é desenhado por ItemEffects), o corpo sai da colisão (ninguém bate nele, ele não pega
## caixas) e drift, pulo, asa-delta e encolhimento acabam.
func start_super(rail: Callable) -> void:
	if not is_super():
		_super_layer = collision_layer
	_super_rail = rail
	_want_drift = false
	_cancel_drift()
	ramp_jump = false
	_trick_t = -1.0
	trick = -1
	_trick_boost = false
	_trick_window = 0.0
	_glide_pending = false
	if gliding:
		gliding = false
		glider_closed.emit()
	if glider_visual:
		glider_visual.set_open(false, true)
	_spin_t = -1.0
	_flat_t = -1.0
	_parcel_left = 0.0
	queue_time = 0.0
	grow()
	_break_skid_marks()
	collision_layer = 0
	visual.visible = false


## Volta a ser kart (com um turbo curto, se `boost`), andando para a frente.
func end_super(boost := true) -> void:
	if not is_super():
		return
	_super_rail = Callable()
	collision_layer = _super_layer
	visual.visible = true
	velocity = get_forward() * speed
	_vertical = 0.0
	_was_on_floor = true
	if boost:
		apply_boost(0.8, 2)


func is_super() -> bool:
	return _super_rail.is_valid()


## Velocidade de giro do kart (rad/s, + = esquerda), suavizada.
func get_yaw_rate() -> float:
	return _yaw_rate


## Um passo no trilho da Superpreferência (veja start_super).
func _super_step(delta: float) -> void:
	var before := get_forward()
	var xf: Transform3D = _super_rail.call(self, delta)
	if not is_super():
		return
	var moved := xf.origin - global_position
	velocity = moved / maxf(delta, 0.0001)
	speed = Vector2(velocity.x, velocity.z).length()
	global_transform = xf
	_yaw_rate = lerpf(_yaw_rate, before.signed_angle_to(get_forward(), Vector3.UP) / maxf(delta, 0.0001), 1.0 - exp(-8.0 * delta))
	steer_input = 0.0
	throttle_input = 1.0
	boost_time = 0.0
	_vertical = 0.0
	_air_time = 0.0
	_was_on_floor = true
	_corner_loss = 0.0
	if boost_fx:
		boost_fx.update(delta, false)


## Fração da velocidade máxima pelo tamanho (acompanha a mola do modelo encolhendo).
func _size_speed() -> float:
	return lerpf(SHRINK_SPEED, 1.0, clampf((_size - SHRINK_SCALE) / (1.0 - SHRINK_SCALE), 0.0, 1.0))


## Peso nas batidas entre karts (encolhido quase não pesa).
func _bump_weight() -> float:
	return maxf(weight_stat * 0.3, 0.6) if is_shrunk() else float(weight_stat)


# --- Marcas de pneu ----------------------------------------------------------------

## No drift, cada roda de trás risca o chão: borracha escura no asfalto e a cor do
## cenário fora dele (grama, areia, terra ou neve).
func _update_skid_marks(on_floor: bool) -> void:
	if skid_marks == null or _skid_trails.is_empty():
		return
	var marking := drifting and on_floor and absf(speed) > 4.0
	if not marking:
		if _marking:
			_break_skid_marks()
		return
	_marking = true
	var n := get_floor_normal()
	var color := _offroad_mark if is_offroad or surface == Surface.AREIA_FOFA or surface == Surface.AREIA_MOVEDICA else ROAD_MARK
	if surface == Surface.GELO:
		color = ICE_MARK
	elif surface == Surface.AREIA or surface == Surface.NEVE or surface == Surface.AREIA_BATIDA:
		color = _offroad_mark
	# Mais forte com o drift carregado.
	color.a *= 0.75 + 0.1 * drift_level
	var origin := global_position
	# As rodas acompanham o modelo, que aponta para dentro da curva no drift.
	var xf := global_transform * Transform3D(Basis(Vector3.UP, _visual_yaw), Vector3.ZERO)
	var side := xf.basis.x
	side.y = 0.0
	side = side.normalized()
	for i in _skid_trails.size():
		var p := xf * _rear_points[i]
		# No plano do chão (rampas e pontes inclinadas).
		p.y = origin.y - (n.x * (p.x - origin.x) + n.z * (p.z - origin.z)) / maxf(n.y, 0.3)
		skid_marks.add_point(_skid_trails[i], p, side, MARK_WIDTH, color)


func _break_skid_marks() -> void:
	_marking = false
	if skid_marks == null:
		return
	for t in _skid_trails:
		skid_marks.break_trail(t)


# --- Rampas e manobras -----------------------------------------------------------

## A rampa embaixo do kart (só vale com o kart no chão), ou null.
func _current_ramp() -> JumpRamp:
	# As rampas só mudam com a pista: a lista é relida a cada segundo, não a cada
	# quadro (eram 8 karts × 60 listas novas por segundo).
	var frame := Engine.get_physics_frames()
	if _ramps_frame < 0 or frame - _ramps_frame >= 60:
		_ramps = get_tree().get_nodes_in_group(&"jump_ramp")
		_ramps_frame = frame
	for node in _ramps:
		if not is_instance_valid(node):
			continue
		var r := node as JumpRamp
		if r and r.contains(global_position):
			return r
	return null


## Sai do chão na borda da rampa. Devolve a velocidade horizontal (endireitada).
func _launch(ramp: JumpRamp, horizontal: Vector3) -> Vector3:
	var dir := ramp.get_forward()
	var heading := horizontal.normalized() if horizontal.length_squared() > 0.01 else get_forward()
	var deviation := dir.signed_angle_to(heading, Vector3.UP)
	if absf(deviation) > RAMP_ALIGN_MAX:
		var fix := (absf(deviation) - RAMP_ALIGN_MAX) * signf(deviation)
		rotate_y(-fix)
		horizontal = horizontal.rotated(Vector3.UP, -fix)
	# A subida não rouba velocidade: decola com a velocidade do kart.
	horizontal = horizontal.normalized() * maxf(horizontal.length(), absf(speed))
	# A subida é dividida pela classe de velocidade: o tempo no ar fica o mesmo e o
	# pulo só fica mais comprido (no 150cc com turbo ainda cai na reta depois da rampa).
	_vertical = horizontal.dot(dir) * tan(ramp.launch_angle) / maxf(speed_class, 0.1)
	ramp_jump = true
	_air_time = 0.0
	# Tempo até voltar ao asfalto (o kart decola um pouco antes da borda, mais baixo
	# que ela): dá a duração das manobras. Se a pista cair ou subir depois da rampa,
	# a manobra termina rápido ao aterrissar (veja _update_visuals).
	var h := maxf(ramp.to_lip_space(global_position).y, 0.0)
	_air_expected = (_vertical + sqrt(_vertical * _vertical + 2.0 * GRAVITY * h)) / GRAVITY
	if ramp.glider:
		# Rampa de asa-delta: sobe sempre igual e a asa abre logo depois (a manobra tem
		# tempo de sobra: o voo é longo). Quem chega devagar (batido, saindo de uma
		# rodada) decola com pelo menos GLIDE_MIN_LAUNCH da velocidade máxima: o vão de
		# um vale sempre dá para atravessar.
		_vertical = GLIDE_LAUNCH_VY
		_glide_pending = true
		_air_expected = GLIDE_OPEN_DELAY + 1.0
		var least := max_speed * speed_multiplier * GLIDE_MIN_LAUNCH
		if absf(speed) < least:
			speed = least
			horizontal = horizontal.normalized() * least if horizontal.length_squared() > 0.01 else dir * least
	_trick_window = TRICK_WINDOW
	jumped.emit()
	if _trick_buffer > 0.0:
		_start_trick(steer_input)
	return horizontal


func _start_trick(steer: float) -> void:
	trick = _pick_trick()
	_last_trick = trick
	_trick_t = 0.0
	var air_left := _air_expected - _air_time - TRICK_LAND_MARGIN
	_trick_len = clampf(air_left, TRICK_MIN_TIME, TRICK_TIMES[trick])
	# Gira para o lado do direcional (ou alterna, com o direcional no meio).
	_trick_dir = signf(steer) if absf(steer) > 0.2 else -_trick_dir
	_trick_boost = true
	_trick_window = 0.0
	_trick_buffer = 0.0
	trick_performed.emit()
	if driver:
		_trick_reaction()


## Sorteia a manobra do pulo (qualquer uma menos a do pulo anterior).
func _pick_trick() -> int:
	var count := Trick.size()
	if _last_trick < 0:
		return randi() % count
	return (_last_trick + 1 + randi() % (count - 1)) % count


## Cara, braços e corpo do piloto em cada manobra. Os lados são do kart: com
## _trick_dir > 0 o kart gira/deita para a esquerda, e o braço de fora (ou de cima)
## é o direito do piloto (play_gesture: 1 = braço esquerdo, 2 = direito).
func _trick_reaction() -> void:
	var hold := _trick_len + 0.05
	var outer_arm := 2 if _trick_dir > 0.0 else 1
	driver.bounce(0.5)
	match trick:
		Trick.GIRO:
			driver.set_face(&"face_happy", hold + 0.4)
			driver.play_gesture(&"gesture_cheer", hold)
			driver.strike_pose(Vector3(0.3, 0.0, 0.0), hold)
		Trick.MORTAL:
			# Agarrado no volante, jogando o corpo para trás junto com o mortal.
			driver.set_face(&"face_screaming", hold + 0.3)
			driver.strike_pose(Vector3(1.0, 0.0, 0.0), hold)
		Trick.PIAO:
			driver.set_face(&"face_happy", hold + 0.4)
			driver.play_gesture(&"gesture_cheer", hold, outer_arm)
			driver.strike_pose(Vector3(0.2, 0.0, 0.9 * _trick_dir), hold)
		Trick.PARAFUSO:
			driver.set_face(&"face_surprised", hold + 0.3)
			driver.play_gesture(&"gesture_jazz_hands", hold)
			driver.strike_pose(Vector3(0.4, -0.6 * _trick_dir, 0.0), hold)
		Trick.DEITADO:
			# O corpo fica mais em pé que o kart (dobra para o lado de cima).
			driver.set_face(&"face_smiling", hold + 0.4)
			driver.play_gesture(&"gesture_wave", hold, outer_arm)
			driver.strike_pose(Vector3(0.1, -1.0 * _trick_dir, 0.3 * _trick_dir), hold)
		Trick.SEM_MAOS:
			driver.set_face(&"face_happy", hold + 0.4)
			driver.play_gesture(&"gesture_shrug", hold)
			driver.strike_pose(Vector3(0.9, 0.0, 0.0), hold)


## Posição do modelo durante a manobra (`k` = progresso 0..1), no espaço do kart.
func _trick_transform(k: float) -> Transform3D:
	var d := _trick_dir
	var e := k * k * (3.0 - 2.0 * k)
	# Sobe rápido, segura e volta (manobras de pose).
	var hold := smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.72, 1.0, k))
	var spin := Basis.IDENTITY
	match trick:
		Trick.GIRO:
			spin = Basis(Vector3.BACK, TAU * e * d)
		Trick.MORTAL:
			# Positivo em X = bico para cima: dá a volta por trás.
			spin = Basis(Vector3.RIGHT, TAU * e)
		Trick.PIAO:
			spin = Basis(Vector3.UP, TAU * e * d) * Basis(Vector3.BACK, sin(PI * k) * 0.35 * d)
		Trick.PARAFUSO:
			# Eixo de giro inclinado para o lado: na meia-volta o kart fica quase de lado.
			var axis := Basis(Vector3.BACK, 0.7 * d) * Vector3.UP
			spin = Basis(axis, TAU * e * d)
		Trick.DEITADO:
			spin = Basis(Vector3.UP, 0.4 * hold * d) * Basis(Vector3.BACK, 1.2 * hold * d) \
					* Basis(Vector3.RIGHT, 0.15 * hold)
		Trick.SEM_MAOS:
			var rock := sin(k * TAU * 1.5) * 0.12 * hold
			spin = Basis(Vector3.RIGHT, 0.55 * hold) * Basis(Vector3.BACK, rock * d)
	var pivot := Vector3(0.0, TRICK_PIVOT, 0.0)
	return Transform3D(spin, pivot - spin * pivot)


## A asa-delta abre: o kart passa a planar (veja GLIDE_*).
func _open_glider() -> void:
	_glide_pending = false
	gliding = true
	_glide_time = 0.0
	_glide_landing = false
	# Sem manobra nova debaixo da asa; um drift carregado vira o turbo dele.
	_trick_window = 0.0
	_trick_buffer = 0.0
	if drifting:
		_release_drift()
	if glider_visual:
		glider_visual.set_open(true)
	if driver:
		driver.set_face(&"face_happy", 1.5)
		driver.bounce(0.6)
	glider_opened.emit()


## Passou da beira do outro lado do vale: a asa desce para o pouso (a corrida chama).
## O freio não segura mais o voo.
func glide_land() -> void:
	if gliding:
		_glide_landing = true


## Está descendo para o pouso?
func is_glide_landing() -> bool:
	return gliding and _glide_landing


## A asa-delta fecha (tocou o chão, ou o kart foi reposicionado).
func _close_glider() -> void:
	_glide_landing = false
	_glide_pending = false
	if not gliding:
		return
	gliding = false
	_glide_pull = 0.0
	if glider_visual:
		glider_visual.set_open(false)
	glider_closed.emit()


## Velocidade de descida planando agora (m/s).
func _glide_sink() -> float:
	if _glide_landing:
		return GLIDE_LAND_SINK
	var sink := lerpf(GLIDE_SINK, GLIDE_SINK_SLOW, _glide_pull)
	if _glide_time > GLIDE_TIRED_TIME:
		sink += (_glide_time - GLIDE_TIRED_TIME) * GLIDE_TIRED_SINK
	return sink


## Fração do giro do chão que o kart tem agora (1 no chão, menos no ar).
func get_turn_scale() -> float:
	if is_on_floor():
		return 1.0
	return GLIDE_TURN if gliding else 0.35


## Tocou o chão. `fall_speed` = velocidade de queda (m/s) no toque.
func _on_landed(fall_speed: float) -> void:
	_close_glider()
	var big := ramp_jump or _air_time > LONG_AIR_TIME
	ramp_jump = false
	_trick_window = 0.0
	if not big:
		if driver:
			driver.bounce(-0.8)
		return
	var strength := clampf(fall_speed / 22.0, 0.0, 1.0)
	# A suspensão afunda e volta (mola no _update_visuals).
	_squash_vel -= (0.6 + strength * 1.1) * KartScale.ITEMS
	_land_dust = 0.3
	if driver:
		driver.bounce(-1.0 - strength * 1.2)
	landed.emit(strength)
	if _trick_boost:
		_trick_boost = false
		apply_boost(TRICK_BOOST, 1)


# --- Drift ---------------------------------------------------------------------

func _start_drift(dir: int) -> void:
	drifting = true
	drift_dir = dir
	drift_level = 0
	_drift_time = 0.0
	_set_sparks(0)


func _update_drift_level() -> void:
	var level := 0
	for i in range(DRIFT_LEVEL_TIMES.size() - 1, 0, -1):
		if _drift_time >= DRIFT_LEVEL_TIMES[i]:
			level = i
			break
	if level != drift_level:
		drift_level = level
		_set_sparks(level)
		drift_level_changed.emit(level)
		if driver:
			driver.react_drift(level)


func _release_drift() -> void:
	var level := drift_level
	_cancel_drift()
	if level > 0:
		apply_boost(DRIFT_BOOST_TIMES[level], level)


func _cancel_drift() -> void:
	if drifting and driver:
		driver.react_drift_end()
	drifting = false
	drift_dir = 0
	drift_level = 0
	_drift_time = 0.0
	_set_sparks(-1)


## Liga os efeitos que só aparecem durante a corrida (turbo, faíscas do drift, poeira)
## para os shaders deles compilarem atrás da tela de carregamento (Race.warm_up).
func prewarm_effects(on: bool) -> void:
	if boost_fx:
		boost_fx.prewarm(on)
	if glider_visual:
		glider_visual.set_open(on, true)
		if on:
			_place_glider(visual.transform)
	var emitters: Array[GPUParticles3D] = [sparks_left, sparks_right]
	emitters.append_array(_dust_emitters)
	emitters.append_array(_rev_smoke)
	if water_fx:
		water_fx.prewarm(on)
	for p in emitters:
		if on:
			p.emitting = true
		else:
			p.restart()
			p.emitting = false


func _set_sparks(level: int) -> void:
	if sparks_left == null:
		return
	var on := level >= 0
	sparks_left.emitting = on
	sparks_right.emitting = on
	if on:
		var mat := sparks_left.process_material as ParticleProcessMaterial
		if mat:
			mat.color = DRIFT_COLORS[level]


# --- Visual -----------------------------------------------------------------------

func _update_visuals(delta: float, steer: float) -> void:
	var speed_ratio := clampf(absf(speed) / max_speed, 0.0, 1.0)
	var smooth := 1.0 - exp(-8.0 * delta)
	# No drift o bico aponta para dentro da curva; fechando o arco ele aponta mais.
	var target_yaw := drift_dir * (DRIFT_VISUAL_YAW + DRIFT_VISUAL_YAW_TIGHT * steer * drift_dir) if drifting else 0.0
	var target_roll := -steer * 0.05 * speed_ratio - drift_dir * 0.07
	var roll_smooth := smooth
	if data and data.turn_lean_degrees > 0.0:
		target_roll = _bike_lean(steer, speed_ratio)
		roll_smooth = 1.0 - exp(-BIKE_LEAN_SHARPNESS * delta)
	if gliding:
		# Na asa o kart inclina para dentro da curva, como um avião.
		target_roll = steer * GLIDE_BANK
		roll_smooth = 1.0 - exp(-4.0 * delta)
	var accel := (speed - _prev_speed) / maxf(delta, 0.0001)
	var target_pitch := clampf(accel / 45.0, -0.05, 0.05)
	_visual_yaw = lerpf(_visual_yaw, target_yaw, smooth)
	_visual_roll = lerpf(_visual_roll, target_roll, roll_smooth)
	_visual_pitch = lerpf(_visual_pitch, target_pitch, smooth * 0.6)
	# Acompanha a inclinação do chão (rampas e pontes): bico para cima na subida.
	var ground_pitch := 0.0
	var ground_roll := 0.0
	var ground_rate := 10.0
	if is_on_floor():
		var n := get_floor_normal()
		ground_pitch = -asin(clampf(n.dot(get_forward()), -1.0, 1.0))
		ground_roll = -asin(clampf(n.dot(global_basis.x), -1.0, 1.0))
	elif gliding:
		# Planando: bico um pouco para baixo; freando, o bico sobe.
		ground_pitch = GLIDE_LAND_NOSE if _glide_landing else GLIDE_NOSE + 0.22 * _glide_pull
		ground_rate = 3.0
	elif ramp_jump or _air_time > LONG_AIR_TIME:
		# No pulo o bico acompanha o arco: sobe na decolagem e desce na queda.
		var hs := Vector2(velocity.x, velocity.z).length()
		ground_pitch = clampf(atan2(_vertical, maxf(hs, 4.0)) * 0.75, -0.4, 0.4)
		ground_rate = 5.0
	else:
		ground_pitch = _ground_pitch * 0.98
		ground_roll = _ground_roll * 0.98
	var ground_smooth := 1.0 - exp(-ground_rate * delta)
	_ground_pitch = lerpf(_ground_pitch, ground_pitch, ground_smooth)
	_ground_roll = lerpf(_ground_roll, ground_roll, ground_smooth)
	# Mola da suspensão (afunda na aterrissagem e volta).
	_squash_vel += (-_squash * 170.0 - _squash_vel * 13.0) * delta
	_squash = clampf(_squash + _squash_vel * delta, -0.16 * KartScale.ITEMS, 0.08 * KartScale.ITEMS)
	var xf := Transform3D(Basis.from_euler(Vector3(_visual_pitch + _ground_pitch, _visual_yaw, _visual_roll + _ground_roll)),
			Vector3(0.0, _squash + visual_lift, 0.0))
	# Deságio: o modelo encolhe (e volta) numa mola com um balanço.
	var size_goal := SHRINK_SCALE if shrink_time > 0.0 else 1.0
	if _size != size_goal or _size_vel != 0.0:
		_size_vel += ((size_goal - _size) * 120.0 - _size_vel * 11.0) * delta
		_size = clampf(_size + _size_vel * delta, 0.3, 1.25)
		if absf(_size - size_goal) < 0.002 and absf(_size_vel) < 0.01:
			_size = size_goal
			_size_vel = 0.0
	_place_glider(xf)
	# Acelerando parado na largada: a traseira escorrega de um lado para o outro (gira
	# em volta do eixo da frente, num ritmo meio irregular), o motor faz o kart tremer
	# e a traseira agacha com a força das rodas.
	_update_rev(delta)
	if _rev > 0.0:
		var t := _rev_t
		var sway := (sin(t * 12.0) * 0.75 + sin(t * 19.5 + 1.1) * 0.25) * REV_SWAY * _rev
		var shake := sin(t * 47.0) * REV_SHAKE * _rev
		var hop := absf(sin(t * 29.0)) * REV_BOUNCE * _rev
		var rev_basis := Basis.from_euler(Vector3(REV_SQUAT * _rev, sway, shake))
		xf = xf * Transform3D(rev_basis, _rev_pivot - rev_basis * _rev_pivot + Vector3(0.0, hop, 0.0))
	# Rodopio de um obstáculo: uma volta inteira freando no fim (ou só um balanço).
	if _spin_t >= 0.0:
		_spin_t += delta
		var k := clampf(_spin_t / SPIN_TIME, 0.0, 1.0)
		var turn := _spin_dir * (TAU * _spin_turns * (1.0 - pow(1.0 - k, 3.0)) + sin(k * PI * 3.0) * 0.32 * (1.0 - k))
		xf.basis = Basis(Vector3.UP, turn) * xf.basis
		if k >= 1.0:
			_spin_t = -1.0
	# Manobra sorteada no pulo (termina rápido se o kart aterrissar antes).
	if _trick_t >= 0.0:
		_trick_t += delta * (3.0 if is_on_floor() else 1.0)
		var k := clampf(_trick_t / _trick_len, 0.0, 1.0)
		if k >= 1.0:
			_trick_t = -1.0
			trick = -1
		else:
			xf = xf * _trick_transform(k)
	# Tamanho (Deságio) e amassado (atropelado pequeno: achata e volta num pulo).
	var size_xz := _size
	var size_y := _size
	if _flat_t >= 0.0:
		_flat_t += delta
		var k := clampf(_flat_t / FLAT_TIME, 0.0, 1.0)
		var flat := 1.0 - smoothstep(0.72, 1.0, k)
		size_y *= lerpf(1.0, 0.22, flat)
		size_xz *= lerpf(1.0, 1.3, flat)
		if k >= 1.0:
			_flat_t = -1.0
	if size_xz != 1.0 or size_y != 1.0:
		xf.basis = xf.basis * Basis.from_scale(Vector3(size_xz, size_y, size_xz))
	visual.transform = xf

	# Rodas, guidão/volante e piloto. Longe da câmera (veja _update_driver_detail) é
	# refeito a cada poucos passos, com o tempo acumulado: de longe ninguém vê a roda.
	if kart_visual:
		_motion_delta += delta
		_motion_skipped += 1
		if _motion_skipped >= _motion_every:
			kart_visual.update_motion(_motion_delta, speed, steer, drift_dir, REV_WHEEL_SPEED * _rev)
			_motion_skipped = 0
			_motion_delta = 0.0

	if boost_fx:
		boost_fx.update(delta, boost_time > 0.0)
	_land_dust = maxf(_land_dust - delta, 0.0)
	# Poeira (ou neve) das rodas de trás: fora do asfalto, no drift e na aterrissagem.
	# Na água rasa a poeira dá lugar aos respingos (KartWaterFx).
	var grounded := is_on_floor() and not underwater and surface != Surface.AGUA_RASA
	# Nas dunas (e no redemoinho) a areia voa sempre que o kart anda.
	var sandy := surface == Surface.AREIA_FOFA or surface == Surface.AREIA_MOVEDICA \
			or (surface == Surface.AREIA and absf(speed) > 14.0)
	var offroad_dust := (is_offroad or sandy) and absf(speed) > 4.0 and grounded
	var drift_dust := drifting and absf(speed) > 6.0 and grounded
	# Na neve batida, rápido, um véu fino de neve sai das rodas.
	var powder := surface == Surface.NEVE and absf(speed) > SNOW_SPRAY_SPEED and grounded
	# Na areia batida, rápido, um véu de areia.
	var veil := surface == Surface.AREIA_BATIDA and absf(speed) > SAND_SPRAY_SPEED and grounded
	var dusty := offroad_dust or drift_dust or _land_dust > 0.0 or powder or veil
	var ratio := 1.0 if offroad_dust or _land_dust > 0.0 else (0.45 + 0.18 * drift_level if drift_dust else (SAND_SPRAY if veil else SNOW_SPRAY))
	if dusty and not is_equal_approx(ratio, _dust_ratio):
		_dust_ratio = ratio
		for p in _dust_emitters:
			p.amount_ratio = ratio
	for i in mini(_dust_emitters.size(), maxi(_rear_points.size(), 1)):
		var p := _dust_emitters[i]
		if p.emitting != dusty:
			p.emitting = dusty


## Põe a asa-delta em cima do kart com a inclinação do modelo dele, mas sem as
## manobras e o rodopio (ela fica fora do nó Visual).
func _place_glider(xf: Transform3D) -> void:
	if glider_visual == null or not (glider_visual.visible or glider_visual.is_open()):
		return
	var s := (data.race_scale if data else 1.0) * _size
	var mount := _glider_mount * s
	glider_visual.transform = Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * s), xf.origin + xf.basis * mount)
	glider_visual.lift = 0.18 * _glide_pull


## Inclinação de moto (rad, positivo = deita para a esquerda): para dentro da curva,
## crescendo com a velocidade. No drift deita para o lado da derrapagem (mais ao
## fechar o arco, menos ao abrir) e no pulo quase endireita.
func _bike_lean(steer: float, speed_ratio: float) -> float:
	var max_lean := deg_to_rad(data.turn_lean_degrees)
	var k := clampf(speed_ratio / BIKE_LEAN_FULL_SPEED, 0.0, 1.0)
	var lean := steer
	if drifting:
		lean = drift_dir * (0.8 + 0.3 * clampf(steer * drift_dir, -1.0, 1.0))
	if not is_on_floor() and (ramp_jump or _air_time > LONG_AIR_TIME):
		lean *= 0.3
	return clampf(lean * k, -1.1, 1.1) * max_lean


# --- Som do motor (sintetizado) --------------------------------------------------

func _setup_engine_audio() -> void:
	if not (is_player and lone_player):
		# Adversários (e todos os karts na tela dividida): som 3D (mais alto perto da
		# câmera) feito com um loop curto. O motor sintetizado do jogador gera cada
		# amostra em GDScript, caro para 8 karts.
		engine_audio.queue_free()
		engine_audio = null
		_engine_3d = AudioStreamPlayer3D.new()
		_engine_3d.name = "Motor3D"
		_engine_3d.stream = Sfx.get_engine_loop()
		_engine_3d.bus = GameSettings.BUS_SFX
		_engine_3d.volume_db = -8.0 if is_player else -12.0
		_engine_3d.unit_size = 5.0
		_engine_3d.max_distance = 60.0
		_engine_3d.position = Vector3(0.0, 0.5, 0.4)
		add_child(_engine_3d)
		_engine_3d.play()
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.1
	engine_audio.stream = generator
	engine_audio.bus = GameSettings.BUS_SFX
	# Na web o padrão é tocar como "sample" (Web Audio), que não aceita stream gerado
	# em tempo real; o motor precisa passar pelo mixer do Godot.
	engine_audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	engine_audio.play()
	_engine = engine_audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _fill_engine_audio() -> void:
	if _engine == null:
		return
	var frames := _engine.get_frames_available()
	if frames <= 0:
		return
	var freq := _engine_frequency()
	var volume := 0.16 + maxf(throttle_input, _engine_rev) * 0.08
	var step := TAU * freq / 22050.0
	# A forma de onda vem de uma tabela pronta (4 senos por amostra em GDScript eram
	# ~0,2 µs cada, ~370 amostras por quadro) e vai para o gerador num bloco só.
	var table := _engine_wave()
	var period := TAU * 2.0
	var to_index := ENGINE_TABLE_SIZE / period
	var phase := _engine_phase
	_engine_buffer.resize(frames)
	for i in frames:
		phase += step
		if phase >= period:
			phase -= period
		var s := table[int(phase * to_index)] * volume
		_engine_buffer[i] = Vector2(s, s)
	_engine_phase = phase
	_engine.push_buffer(_engine_buffer)


## Uma volta da forma de onda do motor (fase de 0 a 4π, por causa do sen(p/2)), já com
## a saturação. Tem uma amostra a mais no fim (igual à primeira) para o índice nunca
## passar do tamanho.
static func _engine_wave() -> PackedFloat32Array:
	if _engine_table.is_empty():
		_engine_table.resize(ENGINE_TABLE_SIZE + 1)
		for i in ENGINE_TABLE_SIZE + 1:
			var p := TAU * 2.0 * float(i % ENGINE_TABLE_SIZE) / ENGINE_TABLE_SIZE
			var s := sin(p) * 0.55 + sin(p * 2.0) * 0.3 + sin(p * 3.0 + 0.4) * 0.12 + sin(p * 0.5) * 0.3
			_engine_table[i] = clampf(s * 1.3, -1.0, 1.0)
	return _engine_table


## Frequência do ronco do motor (Hz) pela velocidade (e pelo acelerador na largada).
func _engine_frequency() -> float:
	var ratio := clampf(absf(speed) / max_speed, 0.0, 1.4)
	var rev := maxf(ratio, _engine_rev * (0.35 if not controls_enabled else 0.0))
	# Pequeno (Deságio), o motor fica fininho.
	var tiny := 1.0 + (1.0 - _size) * 0.9
	return (42.0 + rev * 92.0 + (16.0 if boost_time > 0.0 else 0.0)) * tiny


## Piloto longe da câmera: a pose é refeita menos vezes (ninguém vê a diferença e o
## personagem é a parte mais cara de cada kart: cada pose nova também deforma a malha
## na GPU). Na tela dividida vale a câmera mais perto (grupo "race_camera").
func _update_driver_detail() -> void:
	var frame := Engine.get_process_frames()
	if frame != _cams_frame:
		_cams_frame = frame
		_cams = get_tree().get_nodes_in_group(&"race_camera")
	var cams := _cams
	if cams.is_empty():
		var main_cam := get_viewport().get_camera_3d()
		if main_cam == null:
			return
		cams = [main_cam]
	var every := 6
	var pos := global_position
	for node in cams:
		if not is_instance_valid(node):
			continue
		var cam := node as Camera3D
		if cam == null or not cam.is_inside_tree():
			continue
		var d2 := cam.global_position.distance_squared_to(pos) * lod_scale * lod_scale
		if cam.is_position_behind(pos):
			every = mini(every, 6)
		elif d2 < 15.0 * 15.0:
			every = 1
		elif d2 < 35.0 * 35.0:
			every = mini(every, 2)
		elif d2 < 70.0 * 70.0:
			every = mini(every, 3)
		else:
			every = mini(every, 5)
	# Rodas e volante: até 35 m em todo passo; mais longe, junto com a pose do piloto.
	_motion_every = 1 if every <= 2 else every
	var rig := driver
	if rig:
		rig.update_every = every
