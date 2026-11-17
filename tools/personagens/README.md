# Jarbas — modelo e animações

O Jarbas é o segundo piloto jogável. Ao contrário do Celerino (folha de papel, braço
elástico), ele tem proporção de gente: esqueleto estilo Mixamo, textura, cotovelos. Esta
pasta guarda o modelo original e os dois passos que o preparam para o jogo. O Godot
ignora `tools/` (`.gdignore`).

| Arquivo | O que é |
|---|---|
| `originais/jarbas-piloto.glb` | Modelo como veio do Blender: 93 ossos (com controles de IK), 27 texturas da Tripo, 2 logos, 10 animações (`ANIM_Piscar`, `EXP_*`, `POSE_Kart`, `POSE_Moto`) e o volante/guidão de referência das poses |
| `build_jarbas.py` | Passo 1 (Python + Pillow): grava `assets/models/personagens/jarbas.glb` |
| `gerar_animacoes.gd` | Passo 2 (Godot headless): grava `assets/models/personagens/jarbas_animacoes.res` |
| `medir_cockpit.gd` | Mede banco, encosto, assoalho e pedais de cada kart (grupo "Cockpit" do `KartData`) e grava um mapa por kart |

## Regerar

```sh
python3 tools/personagens/build_jarbas.py
Godot --headless --path . --import
Godot --headless --path . -s res://tools/personagens/gerar_animacoes.gd
```

O passo 2 lê o `jarbas.glb` importado e o `celerino.glb`: rode de novo depois de mudar
qualquer um dos dois.

## Passo 1: `build_jarbas.py`

- Tira o volante e o guidão de referência (`Ref_*`) e os desenhos de controle (`WGT_*`).
- Tira os 25 ossos sem peso (IK, polos, alvos do olhar, pontas dos dedos e dos pés):
  sobram 68. No Godot eles não fazem nada e o `CharacterRig` percorre todos os ossos a
  cada quadro. Os ossos `mixamorig:Xxx` viram `Xxx`.
- Junta as 27 texturas e os 2 logos num atlas de 2048 × 2048 (`jarbas_atlas.png`,
  extraído pelo Godot com compressão de VRAM). As peças são recortadas pela área que os
  UVs usam, reduzidas na mesma proporção (a Tripo já escolhe a resolução pelo tamanho da
  parte; as de 4096 viram ~940 px) e empacotadas. O fundo preto de cada peça é preenchido
  com a cor das bordas (push-pull), senão o filtro e os mipmaps puxam o preto para as
  costuras. As partes de cor lisa (olhos, boca, luvas, pálpebras) apontam para um
  quadradinho branco no canto e mantêm a cor no material.
- Logos: os UVs passam de [0, 1] (a textura original era "clamp", com borda
  transparente), então cada logo entra no atlas com margem vazia. A transparência vira
  recorte (alpha scissor) em vez de mistura.

Com tudo numa textura só, o `CharacterMesh` junta o piloto numa superfície
(`shaders/character_textured.gdshader`), como faz com o Celerino. Resultado: 29 mil
vértices e 52 mil triângulos (o Celerino tem 40 mil e 58 mil).

## Passo 2: `gerar_animacoes.gd`

Monta uma `AnimationLibrary` com os nomes que o jogo usa (os do Celerino) e as poses
sentadas:

| Animações | De onde vêm |
|---|---|
| `face_neutral/happy/surprised/angry`, `face_confused`/`face_sad` (Tristeza), `face_eepy`/`face_sleeping` (Olhos fechados) | `EXP_*` do modelo, só os ossos do rosto |
| `face_smiling` (Alegria de boca fechada), `face_screaming` (Surpresa + boca aberta) | misturas das `EXP_*` |
| `blink` | `ANIM_Piscar` (pálpebras) |
| `drive_kart`, `drive_moto` | `POSE_Kart` e `POSE_Moto` (corpo todo menos o rosto) |
| `idle`, `gesture_*`, `hand_*_L/R`, `eyes_*` | transferidas do Celerino |
| `body_lean_*`, `body_bend_*`, `body_twist_*` | geradas: giro espalhado por `Spine`, `Spine1`, `Spine2`; pescoço e cabeça desfazem parte da inclinação para a frente (ele continua olhando a pista) |

Transferência do Celerino: os dois estão em pose T, de frente para +Z. Cada osso do braço,
da coluna e os olhos recebem o mesmo giro, no espaço do personagem, que o osso
equivalente do Celerino. Diferença: na pose T a palma do Celerino olha para a frente e a
do Jarbas para baixo (88°). Nos gestos a mão do Jarbas gira junto para palma e polegar
ficarem como os do Celerino (o giro é espalhado: 25% no braço, 75% no antebraço, 100% na
mão); na respiração (`idle`, braços caídos) não, e as palmas ficam viradas para o corpo.
Os dedos dobram na mesma proporção (0 = esticado, 1 = a mão fechada da `POSE_Kart`); o
Celerino não tem anelar, o do Jarbas segue o médio.

## Pilotando (`data/personagens/jarbas_esqueleto.tres`)

O `CharacterSkeleton` diz ao `CharacterRig` quais ossos são o quê e como ele pilota:

- **Pose sentada montada para cada kart** (`fit_seat`): a `POSE_Kart` do arquivo foi
  feita para um volante de referência e não para os karts do jogo (os joelhos subiam até o
  volante, os pés ficavam no ar ou atravessavam a carenagem, e o quadril flutuava sobre o
  estofado). Dela ficam só os braços, os dedos e a curva da coluna; o resto sai das
  medidas do cockpit de cada kart (veja "Cockpit dos karts"):
  - o bumbum apoia no estofado com as costas no encosto, e o tronco gira no quadril até
    ficar paralelo ao encosto (a pose deita 14°, `pose_recline`);
  - as pernas esticam por IK (96%, `leg_extension`) até o calcanhar apoiar no estofado ou
    no assoalho, sem a ponta do pé passar dos pedais/parede da frente; o pé fica
    inclinado 55° (`foot_pitch`) e o joelho aponta para cima e para fora (`knee_pole`);
  - o pulinho do corpo (batidas, pulos) sobe o quadril; pés e mãos ficam presos no kart.
  - Na moto (`bike_pose`, POSE_Moto) só o quadril se ajusta, no selim; a moto não tem
    pedaleiras no modelo e os pés da pose (recolhidos sob a rabeta) combinam com ela.
- **Braço com cotovelo** (`bend_elbows`): IK de dois ossos; o cotovelo aponta para
  `elbow_pole` (para fora e para baixo, como na `POSE_Kart`) e acompanha o peito.
- **Pegada medida na `POSE_Kart`**: o ponto da barra dentro da mão esquerda fechada
  (`grip_point` = 0,012; 0,062; −0,028 no espaço do osso `LeftHand`) e a direção da barra
  para o lado do polegar (`grip_axis` = 0,945; 0,233; −0,232) saíram do volante de
  referência do arquivo original (aro de raio 0,125 m). A mão direita usa o espelho em X.
  A mão parte da orientação que tinha na pose em relação ao antebraço e gira o mínimo
  para a barra seguir o aro: a torção do antebraço é livre (até 100°, metade dela vai para
  o osso do antebraço), a dobra do punho para em `max_wrist_bend_degrees`.
- **Alcance**: os volantes dos karts ficam 0,46–0,71 m à frente do encosto (foram
  posicionados para o braço elástico do Celerino); o braço do Jarbas alcança ~0,4 m.
  Quando falta braço ele faz o que um piloto faria: inclina para a frente a partir do
  quadril, girando em volta do apoio no estofado (até 60% de `max_hip_lean`, 35°),
  desliza para a frente no estofado (até `max_seat_slide`, sem o bumbum passar da frente
  do banco), inclina o resto e só então o osso do braço estica (`max_arm_stretch`). A
  meta é o punho a 95% do braço esticado (cotovelo levemente dobrado). Conta feita com a
  média das duas mãos, para o corpo não ir e vir quando o volante gira. O pescoço e a
  cabeça desfazem 90% da inclinação (`head_counter`): ele continua olhando a pista.

Medido (headless, mãos no ponto do volante com erro 0,0 cm e braço sem esticar nos 7
veículos):

| Veículo | Inclinou | Deslizou | Pés |
|---|---|---|---|
| Kart Padrão | 21° | 0,11 | no assoalho, perna quase esticada |
| Relâmpago | 16° | 0 | no piso da "banheira", perna quase esticada |
| Kart de Treino | 24° | 0,05 | no assoalho, perna quase esticada |
| Bólido | 21° | 0,02 | nos pedais, joelho dobrado |
| Cometa | 19° | 0 | nos pedais, joelho dobrado (embaixo do painel) |
| Motoca | 31° | 0 | pose da moto |
| Bugre | 21° | 0,13 | no assoalho, perna quase esticada |

## Cockpit dos karts

Medidas no grupo "Cockpit" de cada `data/karts/*.tres` (espaço do kart, frente = −Z),
lidas de mapas de ocupação da faixa por onde passam as pernas (x de 0,06 a 0,16 m):

| Campo | O que é |
|---|---|
| `seat_back_point` | canto entre o estofado e o encosto: altura do estofado (y) e onde as costas encostam (z) |
| `seat_back_angle` | quanto o encosto deita para trás (graus) |
| `seat_front_z` | onde o estofado acaba na frente |
| `floor_height` | assoalho na frente do banco |
| `foot_limit_z` | até onde vão os pés (parede da frente, pedais) |
| `foot_spread` | distância do meio do kart até cada pé |

O `seat_position` dos karts (usado pelo Celerino) fica 0 a 9 cm acima do estofado, porque
foi ajustado para a base do corpo dele; por isso o Jarbas não usa esse ponto.

Kart novo: rode

```sh
Godot --headless --path . -s res://tools/personagens/medir_cockpit.gd -- /tmp/cockpit
```

Ele imprime valores sugeridos e grava `cockpit_<kart>.png` (vista de lado, frente à
esquerda, grade de 10 cm, amarela a cada 50 cm; vermelho = `seat_position`, azul =
centro do volante). Confira no mapa antes de copiar: em karts sem encosto alto (o
Relâmpago) ou sem banco de kart (a moto) a sugestão erra, e volante, coluna e pedais
podem enganar a medida do assoalho e do limite dos pés.

Em `data/personagens/jarbas.tres`: `kart_scale` 1,1, `seat_height` 0,335 e
`seat_forward` 0,04 (só valem em kart sem medidas de cockpit),
`showcase_scale` 1,6, retrato com `portrait_scale` 2,2 e `portrait_offset` −0,75 (rosto
e ombros, como o retrato do Celerino). Recoloração (jogador repetindo o personagem): só
os pontos com matiz perto da do azul do macacão (`tint_reference`) trocam de cor; pele,
cabelo e branco ficam.

Custo: o rig do Jarbas leva ~86 µs por quadro (o do Celerino, ~54 µs; M4, nativo).
