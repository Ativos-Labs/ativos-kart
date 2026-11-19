# Jarbas e Henrique — modelos e animações

O Jarbas e o Henrique são os pilotos jogáveis de proporção de gente. Ao contrário do
Celerino (folha de papel, braço elástico), eles têm esqueleto estilo Mixamo, textura e
cotovelos. Esta pasta guarda os modelos originais e os passos que os preparam para o
jogo. O Godot ignora `tools/` (`.gdignore`).

| Arquivo | O que é |
|---|---|
| `originais/jarbas-piloto.glb` | Modelo do Jarbas como veio do Blender: 93 ossos (com controles de IK), 27 texturas da Tripo, 2 logos, 10 animações (`ANIM_Piscar`, `EXP_*`, `POSE_Kart`, `POSE_Moto`) e o volante/guidão de referência das poses |
| `originais/henrique-piloto.glb` | Modelo do Henrique como veio do Blender: **só as malhas**, em pose T (sem esqueleto e sem animações), 1 textura de 4096 px (+ normal, metal/rugosidade), 2 logos e o volante/guidão de referência |
| `rig_henrique.py` | Passo 0, só do Henrique (Python do Blender + Blender): monta o esqueleto e os pesos e grava `henrique_esqueleto.json` (veja "Henrique: o esqueleto") |
| `blender_pesos.py` | Roda dentro do Blender, chamado pelo `rig_henrique.py`: pesos automáticos (bone heat) e cores da textura |
| `henrique_esqueleto.json` | Esqueleto e pesos do Henrique (gerado; o passo 1 lê daqui, sem precisar do Blender) |
| `build_personagem.py` | Passo 1 (Python + Pillow): grava `assets/models/personagens/<nome>.glb` |
| `gerar_animacoes.gd` | Passo 2 (Godot headless): grava `assets/models/personagens/<nome>_animacoes.res` |
| `medir_cockpit.gd` | Mede banco, encosto, assoalho e pedais de cada kart (grupo "Cockpit" do `KartData`) e grava um mapa por kart |
| `poses_nos_karts.gd` | Confere a pose de um piloto em cada veículo: imprime as medidas (tabelas abaixo) e grava um glb da cena posada por veículo |
| `render_poses.py` | Renderiza esses glb no Blender (lado, 3/4, cima, perto do piloto e um corte que mostra pernas e pés) |

## Regerar

```sh
# Jarbas
python3 tools/personagens/build_personagem.py jarbas
Godot --headless --path . --import
Godot --headless --path . -s res://tools/personagens/gerar_animacoes.gd -- jarbas

# Henrique (o passo 0 só precisa rodar de novo se o modelo original mudar)
/Applications/Blender.app/Contents/Resources/5.3/python/bin/python3.13 tools/personagens/rig_henrique.py
python3 tools/personagens/build_personagem.py henrique
Godot --headless --path . --import
Godot --headless --path . -s res://tools/personagens/gerar_animacoes.gd -- henrique
```

O passo 2 lê o modelo importado e o `celerino.glb` (o do Henrique lê também o
`jarbas.glb`, de onde vêm as expressões e as poses dele): rode de novo depois de mudar
qualquer um deles.

Conferir a pose em todos os veículos (sem janela):

```sh
Godot --headless --path . -s res://tools/personagens/poses_nos_karts.gd -- /tmp/poses henrique
Blender -b --factory-startup -P tools/personagens/render_poses.py -- /tmp/poses/r_ /tmp/poses/henrique_*.glb
```

## Passo 1: `build_personagem.py`

Igual para os dois (o que muda está no início do arquivo, em `CHARACTERS`). No Henrique,
antes de tudo, entram o esqueleto e os pesos do `henrique_esqueleto.json` (nós dos
ossos, skin, `JOINTS_0`/`WEIGHTS_0`), e saem as cores de vértice e o segundo UV, que o
jogo não usa. Materiais que usam a mesma imagem (o corpo e a pele da boca do Henrique)
viram uma peça só do atlas; mapas de normal e metal/rugosidade saem.

**Aba do boné sem sombra (Henrique).** Com sombras ligadas, a aba projetava uma sombra
grande em diagonal sobre olho, testa e bochecha (na tela de seleção e na corrida). Os 76
triângulos dela vão para uma primitiva com uma cópia do material do corpo chamada
`SemSombra_Aba_Bone` (`no_shadow` em `CHARACTERS`: centro do triângulo acima de y 0,87,
algum vértice à frente de z 0,075 e azul no centro; a pele da testa, no mesmo lugar, tem
outra matiz, e a copa é azul-marinho e fica atrás). Mesma textura, mesma peça do atlas:
a aparência não muda. No jogo, o `CharacterMesh` marca os materiais `SemSombra_*` (+ 4 em
`CUSTOM0.a`) e o `character_textured.gdshader` descarta esses pixels no passe de sombra
(`IN_SHADOW_PASS`). O resto do corpo continua fazendo sombra no chão e no kart.

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
| `idle_stand` | gerada: parado em pé nas telas de seleção e nos retratos (`stand_idle` do esqueleto), corpo todo, laço de 12 s (veja abaixo) |

**Parado em pé (`idle_stand`).** A `idle` transferida do Celerino mexe só a coluna (0,5°)
e um braço (3°), em 2 s: no Jarbas, de proporção humana, ele parecia uma estátua. A
`idle_stand` mexe o corpo todo, com cada movimento num ritmo próprio (todos dão um número
inteiro de voltas em 12 s, então o laço emenda):

- troca o peso de uma perna para a outra (6 s para cada lado, parando um pouco em cada
  uma): o quadril vai 3 cm para o lado do apoio, sobe desse lado (2,5°) e gira (3°); os
  ombros inclinam para o outro lado (contrapposto). Os pés ficam plantados por IK: a perna
  de apoio fica quase reta e a outra solta o joelho (14° a 30°);
- respira a cada 4 s: o peito abre e as clavículas sobem 4°;
- a cabeça olha devagar em volta (até ~10° para os lados);
- os braços continuam pendurados (seguem o giro do peito, não a inclinação) e balançam
  atrasados em relação ao quadril, com cotovelo e punho soltos.

Os números estão em `_idle_stand` (`gerar_animacoes.gd`); o gerador imprime a faixa de
dobra dos joelhos e quanto da perna o quadril usa (tem de ficar abaixo de 100%, senão o pé
sai do chão).

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

## Henrique: o esqueleto (`rig_henrique.py`)

O modelo do Henrique veio do Blender só com as malhas (sem `Armature`, sem pesos e sem
nenhuma animação), mas feito no mesmo molde do Jarbas: mesmas peças (`Boca`, `Olhos`,
`Palpebras`, `Mao.L/R`, `Logos_Ativos`), e as luvas são a mesma malha das luvas do
Jarbas (escala 0,708 e giro de ~5°, erro de 1 mm por vértice). Em vez de pedir outro
arquivo, o `rig_henrique.py` dá a ele o esqueleto do Jarbas (os mesmos 68 ossos, com os
mesmos nomes), ajustado ao corpo dele:

- **Articulações do corpo**: cada articulação do Jarbas vai para o lugar equivalente. A
  altura sai de uma interpolação entre pontos medidos nos dois corpos (chão,
  entreperna, eixo dos braços, fenda da boca, olhos); dentro do corpo, a mesma posição
  relativa no corte da perna, do tronco ou do braço naquela altura (cortes exatos da
  malha por planos). Ombro e cotovelo: a mesma fração entre a lateral do tronco e o
  punho.
- **Mãos e dedos**: vão junto com a luva (a mesma escala e o mesmo giro). A pegada no
  volante (`grip_point`) é a do Jarbas × 0,708.
- **Rosto**: olhos e pálpebras no centro de cada globo (esfera ajustada à malha);
  mandíbula pela posição relativa a olhos e boca; lábios e cantos da boca na fenda da
  boca (o meio do tubo `Boca_Interior`, onde os lábios entram para dentro);
  sobrancelhas pelos pontos escuros da textura entre os olhos e a aba do boné (elas
  são pintadas, não são peças como as do Jarbas).
- **Orientação**: cada osso aponta (eixo Y) para a articulação seguinte, como no
  Blender (o IK de braços e pernas do `CharacterRig` usa isso); os outros eixos ficam o
  mais perto possível dos do Jarbas, e os do rosto são iguais aos dele. Assim as
  animações do Jarbas passam para o Henrique (`_transfer` no `gerar_animacoes.gd`).

Pesos:

| Malha | Pesos |
|---|---|
| Corpo | automáticos do Blender (bone heat, `blender_pesos.py`) numa cópia com os vértices repetidos juntados, nos ossos do corpo; por cima, na cabeça: mandíbula (tudo abaixo da fenda da boca, na frente da orelha e acima do pescoço; dentro da boca a separação é seca, dos cantos para fora se espalha pela bochecha), lábios (raio de 2,6 cm), cantos da boca (2,2 cm) e sobrancelhas (2 cm) |
| Luvas | as do Jarbas, vértice a vértice |
| Olhos, pálpebras | cada peça no seu osso (4 pálpebras: de cima com os cílios, de baixo) |
| Boca por dentro | dentes e gengiva de cima na cabeça; de baixo e língua na mandíbula; o fundo dividido pela altura da fenda |
| Logos | os pesos do ponto mais perto do corpo |

As animações próprias (expressões, piscada, `POSE_Kart`, `POSE_Moto`) são as do Jarbas
transferidas: cada osso recebe o mesmo giro no espaço do personagem; os deslocamentos
dos lábios, cantos da boca e sobrancelhas vão na escala do rosto dele (0,72 × 0,68 ×
0,61 do Jarbas); as pálpebras giram 0,573 do ângulo, porque abertas elas cobrem 49° do
olho (as do Jarbas, 86°: as do Henrique são mais caídas). O resto (gestos, `idle_stand`,
inclinações) sai como para o Jarbas. `idle_stand`: joelhos de 16° a 32°, quadril até o
pé 99,0% da perna.

Em `data/personagens/henrique.tres`: `kart_scale` 1,3 (fica com 1,30 m no kart; o Jarbas,
1,32 m), `showcase_scale` 1,9, retrato `portrait_scale` 2,7 e `portrait_offset` −0,8 (a
cabeça dele é bem menor que a do Jarbas em proporção: 0,22 m de largura num corpo de
1 m, contra 0,40 m em 1,2 m). Medidas do assento no `henrique_esqueleto.tres`, na
proporção das do Jarbas: quadril 0,102 acima do apoio, 0,111 à frente das costas, pé
0,165, tornozelo 0,063. Recoloração: referência no azul do meio (matiz 0,61), para o
marinho e o azul-claro do macacão e do boné trocarem juntos.

Resultado: 38 mil vértices numa superfície só (o Jarbas tem 29 mil, o Celerino 40 mil);
o rig custa o mesmo que o do Jarbas (~87 µs por quadro com o kart, M4).

## Pose em cada veículo (`poses_nos_karts.gd`)

Medido em 2026-11-18, mãos com erro 0,0 cm nos 7 veículos e nenhum braço esticado com o
volante reto. Ângulos de cotovelo e joelho são o ângulo interno (180° = reto); "do aro"
é a distância do centro do joelho ao aro do volante.

| Veículo | Henrique | Jarbas |
|---|---|---|
| Kart Padrão | inclina 21°, desliza 0,11; pés no assoalho, joelho 147°, 14 cm do aro | 21°, 0,11; assoalho, 147°, 16 cm |
| Relâmpago | 20°, 0; no fundo da "banheira", joelho 147°, 13 cm | 16°, 0; 147°, 15 cm |
| Kart de Treino | 29°, 0,04; pés nos pedais, joelho 130°, 5 cm (logo abaixo do aro) | 24°, 0,05; assoalho, 147°, 7 cm |
| Bólido | 21°, 0,03; pés nos pedais, joelho 82° (joelhos altos: o banco fica longe dos pedais para a perna dele) | 21°, 0,02; pedais, 97° |
| Cometa | 22°, 0,02; pés nos pedais embaixo do painel, joelho 86°, 5 cm do aro | 19°, 0; pedais, 110°, 5 cm |
| Motoca | 32° (pose da moto); deitado sobre o tanque, a barba encosta no suporte do guidão | 32°, igual (a barba dele também encosta) |
| Bugre | 24°, 0,12; pés nos pedais, joelho 145°, 7 cm do manche | 21°, 0,13; assoalho, 147°, 11 cm |

Com o volante todo virado (0,85 rad), o braço de fora estica no Kart Padrão (1,38) e no
Bólido (1,33): o volante desses dois fica longe e baixo. O Jarbas estica mais (1,46 e
1,38); nos outros veículos nenhum dos dois estica. Na Motoca, o guidão é largo (manoplas
a 42 cm do meio) e o selim não deixa deslizar: só deitando o tronco os braços alcançam.
