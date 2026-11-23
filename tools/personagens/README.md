# Jarbas, Henrique, Ulysses e Rafael — modelos e animações

O Jarbas, o Henrique, o Ulysses e o Rafael são os pilotos jogáveis de proporção de gente. Ao contrário do
Celerino (folha de papel, braço elástico), eles têm esqueleto estilo Mixamo, textura e
cotovelos. Esta pasta guarda os modelos originais e os passos que os preparam para o
jogo. O Godot ignora `tools/` (`.gdignore`).

Os quatro vêm do Blender já nas proporções finais e em metros (1,03, 1,06, 1,03 e 1,03 m de
altura) e entram no jogo em escala 1, pelo padrão "Encaixe piloto × kart" (veja abaixo e
o README do jogo).

| Arquivo | O que é |
|---|---|
| `originais/jarbas-piloto.glb` | Modelo do Jarbas como veio do Blender: 95 ossos (com controles de IK e 2 auxiliares no quadril), 27 texturas da Tripo, 2 logos, 10 animações (`ANIM_Piscar`, `EXP_*`, `POSE_Kart`, `POSE_Moto`) e o volante/guidão de referência |
| `originais/henrique-piloto.glb` | Modelo do Henrique: o mesmo esqueleto de 95 ossos do Jarbas (com os nomes iguais), as mesmas 10 animações feitas para ele, 1 textura de 4096 px (+ normal), 2 logos e o volante/guidão de referência |
| `originais/ulysses-piloto.glb` | Modelo do Ulysses: 99 ossos (os do Jarbas + 4 auxiliares de cotovelo e joelho), as mesmas 10 animações, 2 texturas de 4096 px (cabeça da Tripo e corpo), 2 logos e o volante/guidão de referência |
| `originais/rafael-piloto.glb` (+ `.blend`) | Modelo do Rafael: o esqueleto do Ulysses (99 ossos), 1 textura de 4096 px da Tripo + boca e olhos de 1024, e o **rosto em shape keys** (35, veja abaixo), com 34 animações (as 10 de sempre, mais expressões, olhar, fala `ANIM_Fala` e os visemas `VIS_*`) |
| `build_personagem.py` | Passo 1 (Python + Pillow): grava `assets/models/personagens/<nome>.glb` |
| `gerar_animacoes.gd` | Passo 2 (Godot headless): grava `assets/models/personagens/<nome>_animacoes.res` |
| `gestos_escolha.gd` | Gestos de escolha (o que cada piloto faz ao ser escolhido na seleção), usado pelo passo 2; vale também para o Celerino |
| `quadros_gesto.gd` | Grava glb de um piloto em vários instantes do gesto de escolha (malhas deformadas na CPU) |
| `render_gestos.py` | Renderiza esses glb no Blender e monta uma folha (uma linha por vista, uma coluna por quadro) |
| `poses_nos_karts.gd` | Confere o encaixe de um piloto em cada veículo pelo checklist do documento (tabela abaixo) e grava um glb da cena posada por veículo |
| `render_poses.py` | Renderiza esses glb no Blender (lado, 3/4, cima, perto do piloto e um corte que mostra pernas e pés) |
| `build_garrafa.py` | Rótulo da garrafa do gesto do Rafael (`assets/textures/personagens/garrafa_rotulo.png`) |
| `medir_cockpit.gd` | Mapa de ocupação lateral de cada kart (banco, encosto, assoalho, pedais) com valores sugeridos para o grupo "Cockpit" do `KartData` (usado pelo `fit_seat`, hoje desligado nos três) |

O kart de cada um, o tamanho dos veículos e a medida do assento ficam em
`tools/karts/encaixe_karts.py`.

## Regerar

```sh
python3 tools/personagens/build_personagem.py jarbas     # ou henrique, ulysses, rafael
Godot --headless --path . --import
Godot --headless --path . -s res://tools/personagens/gerar_animacoes.gd -- jarbas
```

O Celerino ganha do passo 2 só o gesto de escolha (o resto vem do `celerino.glb`):
`gerar_animacoes.gd -- celerino` grava `celerino_animacoes.res`, apontada pelo
`data/personagens/celerino_esqueleto.tres` (os outros valores são os padrão).

Modelo novo vindo do Blender: ponha em `originais/<nome>-piloto.glb` (não na raiz do
projeto: um .glb em qualquer lugar de `res://` é importado e exportado com o jogo) e rode
os três comandos. O `.glb` do jogo é gerado: não copie o arquivo do Blender por cima dele.

Personagem novo: o import extrai o atlas sem compressão de VRAM na primeira vez; copie as
opções de `henrique_atlas.png.import` (`compress/mode=2`, `detect_3d/compress_to=0`) para o
`.import` do atlas novo e rode o `--import` de novo.

O passo 2 lê o modelo importado e o `celerino.glb`: rode de novo depois de mudar qualquer
um deles.

Conferir o encaixe em todos os veículos (sem janela):

```sh
Godot --headless --path . -s res://tools/personagens/poses_nos_karts.gd -- /tmp/poses henrique
Blender -b --factory-startup -P tools/personagens/render_poses.py -- /tmp/poses/r_ /tmp/poses/henrique_*.glb
```

## Passo 1: `build_personagem.py`

Igual para todos (o que muda está no início do arquivo, em `CHARACTERS`). Materiais que
usam a mesma imagem (no Jarbas, por exemplo, `PELE__`, `TECIDO__` e `CABELO__` da mesma
parte da Tripo) viram uma peça só do atlas; mapas de normal e metal/rugosidade saem.

- Tira o volante e o guidão de referência (`Ref_*`) e os desenhos de controle (`WGT_*`),
  as cores de vértice (`COLOR_n`) e o segundo UV.
- Tira os 25 ossos sem peso (IK, polos, alvos do olhar, pontas dos dedos e dos pés): sobram
  70 no Jarbas e no Henrique e 74 no Ulysses. No Godot eles não fazem nada e o
  `CharacterRig` percorre todos os ossos a cada quadro. A raiz (`Raiz`) fica. Os ossos
  `mixamorig:Xxx` viram `Xxx`.
- Junta as texturas e os logos num atlas de 2048 × 2048 (`<nome>_atlas.png`, extraído pelo
  Godot com compressão de VRAM). As peças são recortadas pela área que os UVs usam,
  reduzidas na mesma proporção e empacotadas. O fundo preto de cada peça é preenchido com a
  cor das bordas (push-pull), senão o filtro e os mipmaps puxam o preto para as costuras.
  As partes de cor lisa (olhos, boca, luvas, pálpebras) apontam para um quadradinho branco
  no canto e mantêm a cor no material.
- Logos (materiais com transparência: `BLEND` nos modelos antigos, `MASK` nos refeitos):
  os UVs passam de [0, 1] (a textura original era "clamp", com borda transparente), então
  cada logo entra no atlas inteira, com a transparência e uma margem vazia, e o material
  fica com recorte (alpha scissor, corte 0,5) em vez de mistura. Se a logo entrasse como
  textura comum, ela perderia a transparência e apareceria com o fundo da imagem — um
  retângulo em volta da logo e do símbolo no macacão (aconteceu na primeira versão dos
  modelos refeitos, que trocaram BLEND por MASK).
- **Atlas por ilha de UV** (`"islands": True`, no Ulysses): as duas texturas de 4096 px dele
  usam só parte da área; recortadas por ilha (os triângulos ligados pelos vértices ou pelo
  mesmo ponto do UV), as peças entram maiores no atlas (escala 0,38). Os vãos entre as
  peças pegam a cor das bordas.
- **Aba do boné sem sombra (Henrique).** Com sombras ligadas, a aba projetava uma sombra
  grande em diagonal sobre olho, testa e bochecha. Os 80 triângulos dela vão para uma
  primitiva com uma cópia do material chamada `SemSombra_Aba_Bone` (`no_shadow` em
  `CHARACTERS`: material `TECIDO__`, centro do triângulo acima de y 0,91, algum vértice à
  frente de z 0,095 e azul no centro; a frente da copa, logo acima, não passa de z 0,09).
  Mesma textura, mesma peça do atlas: a aparência não muda. No jogo, o `CharacterMesh`
  marca os materiais `SemSombra_*` (+ 4 em `CUSTOM0.a`) e o
  `character_textured.gdshader` descarta esses pixels no passe de sombra.

Com tudo numa textura só, o `CharacterMesh` junta o piloto numa superfície
(`shaders/character_textured.gdshader`), como faz com o Celerino.

- **Shape keys (Rafael).** As malhas escondidas no `.blend` saem (`drop` em `CHARACTERS`:
  as pálpebras à parte, `Palpebras`, e a cópia do corpo sem esqueleto,
  `_REF_Corpo_original`). As primitivas que algum shape key mexe vão para uma malha
  própria, `Rafael_Rosto`, com os shape keys e as trilhas de peso das animações; o resto do
  corpo (`Rafael_Corpo`: tecido e sapatos) fica sem eles (`_split_shape_keys`). Os shape
  keys vêm do Blender como accessors esparsos (só os vértices que mexem): o
  `tools/karts/gltf_util.py` lê e regrava assim. Os ossos de lábios, sobrancelhas e
  pálpebras não têm peso no Rafael e saem (sobram 62).
- **Luz embaixo dos olhos (Rafael).** A pálpebra de baixo do modelo aponta para baixo e para
  dentro da órbita (normal com y ≈ −0,35); com a luz do jogo vindo de cima, a faixa
  embaixo de cada olho ficava escura e parecia olheira (a textura ali é clara, e não era
  sombra projetada). `fill_under_eyes` gira as normais dessa faixa (de 0,8 a 3,6 cm abaixo
  do centro do olho, 3,4 cm para cada lado, com transição suave) 70% para a frente e um
  pouco para cima: a malha não muda, só como ela recebe luz (878 vértices).

## Passo 2: `gerar_animacoes.gd`

Monta uma `AnimationLibrary` com os nomes que o jogo usa (os do Celerino) e as poses
sentadas:

| Animações | De onde vêm |
|---|---|
| `face_neutral/happy/surprised/angry`, `face_confused`/`face_sad` (Tristeza), `face_eepy`/`face_sleeping` (Olhos fechados) | `EXP_*` do modelo, só os ossos do rosto |
| `face_smiling` (Alegria de boca fechada), `face_screaming` (Surpresa + boca aberta) | misturas das `EXP_*` |
| `blink` | `ANIM_Piscar` (pálpebras) |
| `drive_kart`, `drive_moto` | `POSE_Kart` e `POSE_Moto` (corpo todo menos o rosto), com o deslocamento da raiz passado para o quadril (abaixo) |
| `idle`, `gesture_*`, `hand_*_L/R`, `eyes_*` | transferidas do Celerino |
| `body_lean_*`, `body_bend_*`, `body_twist_*` | geradas: giro espalhado por `Spine`, `Spine1`, `Spine2`; pescoço e cabeça desfazem parte da inclinação para a frente (ele continua olhando a pista) |
| `idle_stand` | gerada: parado em pé nas telas de seleção e nos retratos (`stand_idle` do esqueleto), corpo todo, laço de 12 s (veja abaixo) |
| `face_smug` | Alegria de boca fechada com as pálpebras de cima 40% fechadas (convencido: a do Jarbas ao ser escolhido) |
| `gesture_point_forward`, `gesture_arms_crossed`, `gesture_hair_fix`, `gesture_sextou` | gesto de escolha de cada um (`gestos` em `CHARACTERS`), gerado por `gestos_escolha.gd` (veja abaixo) |
| `face_sextou` (Rafael) | a fala animada do gesto dele (`falas` em `CHARACTERS`, `_face_timeline`, chaves em `gestos_escolha.gd`) |

**Rosto por shape keys (Rafael).** Os sorrisos, sobrancelhas, piscada e a boca da fala são
blend shapes da malha `Rafael_Rosto`, ligados no Blender por drivers a propriedades do osso
`Controles` (o glb leva o resultado como trilhas de peso). No passo 2 as expressões levam
as trilhas de blend shape (`shapes`), a piscada só `eye_blink_L/R` (`blink_shapes`), e as
caras de sorriso e de convencido usam as expressões dele (`face_smiling` =
`EXP_Sorriso_Fechado`, `face_smug` = `EXP_Debochado`; `faces`). No jogo:

- o `CharacterMesh` junta o corpo numa superfície e as malhas com blend shapes numa
  segunda ("Rosto", 5,1 mil vértices, 35 blend shapes, modo NORMALIZED: as formas em
  posição absoluta, como o importador entrega). No Compatibility cada blend shape ligado é
  um passe de transform feedback sobre a malha inteira a cada quadro em que o esqueleto
  mexe: por isso o rosto fica separado dos 21 mil vértices do corpo;
- as camadas de rosto e de piscada do `CharacterRig` (`SHAPE_GROUPS`) mexem nos blend
  shapes pelo nome, em qualquer malha do modelo; a piscada soma por cima da expressão e
  cada valor fica entre 0 e 1;
- `eye_blink_L/R_corr` (o meio da piscada) não vêm das animações: são 4·w·(1 − w) do
  `eye_blink` do mesmo lado, como o driver do Blender (`corrective_shapes` no esqueleto).

Os visemas do modelo são discretos (no próprio Blender o "U" é uma abertura pequena); a
fala do gesto soma o bico (`mouth_pucker`, `mouth_funnel`), tira o sorriso de base do
neutro e abre um pouco a mandíbula no O e no U gritados.

**A raiz na pose sentada.** Na `POSE_Kart` é o osso `Raiz` que desce o corpo 0,19 m até o
assento (na `POSE_Moto` ela fica no lugar). O `CharacterRig` não anima a raiz, então
`_drive_pose` passa o giro e o deslocamento dela para o quadril: com a raiz no repouso, o
quadril fica onde a pose o põe em relação à origem do piloto — (0; 0,211; −0,026) no
Jarbas, (0; 0,218; −0,035) no Henrique e (0; 0,218; −0,030) no Ulysses, como no documento.

**Parado em pé (`idle_stand`).** A `idle` transferida do Celerino mexe só a coluna (0,5°)
e um braço (3°), em 2 s: num piloto de proporção humana ele parecia uma estátua. A
`idle_stand` mexe o corpo todo, com cada movimento num ritmo próprio (todos dão um número
inteiro de voltas em 12 s, então o laço emenda):

- troca o peso de uma perna para a outra (6 s para cada lado, parando um pouco em cada
  uma): o quadril vai 3 cm para o lado do apoio, sobe desse lado (2,5°) e gira (3°); os
  ombros inclinam para o outro lado (contrapposto). Os pés ficam plantados por IK: a perna
  de apoio fica quase reta e a outra solta o joelho (13° a 32°);
- respira a cada 4 s: o peito abre e as clavículas sobem 4°;
- a cabeça olha devagar em volta (até ~10° para os lados);
- os braços continuam pendurados (seguem o giro do peito, não a inclinação) e balançam
  atrasados em relação ao quadril, com cotovelo e punho soltos.

Os números estão em `_idle_stand`; o gerador imprime a faixa de dobra dos joelhos e quanto
da perna o quadril usa (tem de ficar abaixo de 100%, senão o pé sai do chão; hoje 99,1 a
99,4%).

Transferência do Celerino: os dois estão em pose T, de frente para +Z. Cada osso do braço,
da coluna e os olhos recebem o mesmo giro, no espaço do personagem, que o osso
equivalente do Celerino. Diferença: na pose T a palma do Celerino olha para a frente e a
dos pilotos para baixo (88°). Nos gestos a mão gira junto para palma e polegar ficarem como
os do Celerino (o giro é espalhado: 25% no braço, 75% no antebraço, 100% na mão); na
respiração (`idle`, braços caídos) não, e as palmas ficam viradas para o corpo. Os dedos
dobram na mesma proporção (0 = esticado, 1 = a mão fechada da `POSE_Kart`); o Celerino não
tem anelar, o dos pilotos segue o médio.

## Gestos de escolha (`gestos_escolha.gd`)

Ao ser escolhido na seleção de personagem, cada piloto faz um gesto do corpo inteiro
(`pick_gesture` e `pick_face` no `.tres` do personagem; o jogo toca com
`CharacterRig.play_body_gesture`, por cima da animação parada, e a pose final fica parada):

| Piloto | Gesto | Expressão | Duração |
|---|---|---|---|
| Celerino | `gesture_air_guitar`: guitarra invisível. Abaixa o corpo e inclina para trás, toca 4 palhetadas (0,24 s cada) balançando a cabeça, com a outra mão correndo pelo braço da guitarra; estica o braço direito acima da folha, gira pelo lado (moinho), dá a palhetada grande e termina com o braço esticado para cima fazendo chifrinho | `face_screaming` | 2,6 s |
| Jarbas | `gesture_arms_crossed`: cruza os braços se achando. Respira (ombros sobem), cruza os braços na frente do peito (o esquerdo por cima), estufa o peito, ergue o queixo e vira a cabeça de lado, com o peso numa perna; depois olha de volta com um aceno curto | `face_smug` | 2,1 s |
| Henrique | `gesture_point_forward`: aponta para quem está escolhendo. Puxa o braço para trás (o tronco gira), estica o braço de uma vez com o indicador e dá mais uma "cutucada"; o outro braço fica solto ao lado do corpo | `face_happy` | 2,0 s |
| Rafael | `gesture_sextou`: "SEXTOUU!" com uma long neck. A mão direita vai para trás do quadril e volta com a garrafa (que aparece ali, escondida pelo corpo), ergue a garrafa ao lado da cabeça (braço aberto, antebraço inclinado para a frente) e grita, com o tronco para trás e o queixo para cima; no "UUU" a garrafa sobe duas vezes e a mão esquerda fechada dá dois socos no ar. Termina num brinde para a câmera ("tim-tim") e pisca o olho esquerdo | `face_sextou` (fala animada) | 2,6 s |
| Ulysses | `gesture_hair_fix`: arruma o cabelo. A palma encosta na frente do cabelo e desliza para trás por cima da orelha, com a cabeça inclinando para o lado da mão; passa de novo, mais curto, e a mão desce solta; termina de queixo erguido | `face_smiling` | 2,4 s |

Cada gesto é uma coreografia em curvas com chaves no tempo (deslocamento e giro do quadril,
giro do peito, da cabeça e das clavículas; ponto do punho ou do meio da palma, direção dos
dedos, da palma e do cotovelo; quanto cada dedo fecha). A cada quadro (30 por segundo):

- o tronco gira (a coluna leva o giro do peito aos poucos) e as pernas seguem por IK com os
  pés plantados;
- cada braço por IK de dois ossos: o cotovelo aponta para o lado pedido e a dobra fica no
  plano em que o cotovelo dobra na pose T (para a frente, nos dois esqueletos); a mão fica
  na orientação pedida e metade da torção vai para o antebraço;
- os dedos fecham entre a mão aberta do repouso e o punho fechado (da `POSE_Kart`; no
  Celerino, das `hand_fist_*`);
- os pontos dos braços podem acompanhar o peito ou a cabeça (a mão no cabelo segue a cabeça
  que inclina; a guitarra segue o corpo), com uma curva de 0 a 1 para soltar aos poucos;
- os pontos saem de medidas do modelo: ombros, braços caídos da `idle` (onde o gesto
  começa), frente do peito e caixa da cabeça e do quadril (malha). Os braços cruzados do
  Jarbas ficam a 6–8,5 cm da frente do peito; a palma do Ulysses anda 1–2 cm fora do cabelo;
- "mão solta" (`limp_*`): a mão acompanha o antebraço com o punho reto. Sem isso, a mão do
  Ulysses girava ao contrário do antebraço na descida (o punho chegava a dobrar 160°);
- Celerino: braço elástico como no kart. Um ponto fora do alcance estica o braço reto (só o
  osso do braço; o antebraço desfaz a escala e não entorta): no moinho e no chifrinho ele
  chega a 1,9× o braço.

**Objeto na mão e balão (Rafael).** A coreografia pode ter `prop` (`{"bone": "right",
"show": t}`): o `bake` grava no metadado "prop" da animação o osso, a transformação do
objeto no espaço do osso e quando ele aparece. O gargalo passa pelo bolso da mão fechada
(`prop_grip` em `CHARACTERS`), com a tampa para o lado do polegar e o rótulo virado o mais
possível para a câmera no último quadro. O bolso foi medido com a luva deformada na CPU, em
cortes perpendiculares ao gargalo: é o vão entre a palma, o gancho dos dedos (90% fechados
na mão da garrafa) e o polegar (80%), ~1,2 cm de raio, 2,5 cm para o lado da palma em
relação à pegada do volante (`grip_point`). A pegada do volante fica dentro da mão: na
primeira versão a garrafa passava por ela e atravessava a palma e as costas da mão. A garrafa atravessa o punho
perpendicular à mão, então para ela ficar em pé a mão tem de apontar para a frente: o
antebraço também vai inclinado para a frente (com ele em pé o punho dobrava ~70° e parecia
que ele segurava com o punho virado). O gerador imprime, nos instantes de conferência, para
onde vão tampa e rótulo e quanto o punho dobra (erguida e no brinde: 31–38°). No jogo,
`CharacterRig.play_pick_gesture` cria um `PickExtras` (`scripts/pick_extras.gd`) que põe o
objeto (`CharacterData.pick_prop`, a `scenes/props/garrafa_cerveja.tscn`) na mão a cada
quadro, crescendo com um pulinho, e o balão de fala (`pick_shout` "SEXTOUU!", letras uma a
uma a cada 0,1 s a partir de `pick_shout_time` 0,32 s; elipse em `shaders/balao_fala.gdshader`,
de frente para a câmera e por cima de tudo, ao lado dos olhos). Quando o gesto acaba (ou é
desfeito), os dois encolhem e somem e a expressão volta para a padrão.

A garrafa (`scripts/garrafa_cerveja.gd`) é uma malha de revolução feita por código, nas
medidas da mão: 27 cm, corpo de Ø 5,8 cm e gargalo reto e fino (Ø 2,4 cm) por 9 cm, porque o
punho fechado cobre 9,1 cm dele (de 4,4 cm abaixo a 4,7 cm acima da pegada). Assim o ombro
alarga abaixo do mindinho, o anel e a tampinha saem acima do polegar e o rótulo fica todo à
mostra embaixo da mão. Vidro verde
opaco com reflexos em faixas, borda acesa e gotinhas (`shaders/garrafa_vidro.gdshader`),
tampinha de metal ondulada e o rótulo oval (estrela vermelha, faixa branca "Sextou",
`build_garrafa.py`). Lembra a lager da foto de referência sem usar nome nem marca.

O gerador imprime, por gesto, a maior dobra do punho, a maior torção do antebraço, quanto o
braço esticou e quantos quadros o punho ou o pé não alcançaram o alvo (tem de ser 0; o pé
sai do chão se o quadril subir, porque a perna em repouso já está quase esticada).

Conferir sem janela (12 quadros do gesto, vistas da câmera da seleção e 3/4):

```sh
Godot --headless --path . -s res://tools/personagens/quadros_gesto.gd -- /tmp/gesto ulysses
Blender -b --factory-startup -P tools/personagens/render_gestos.py -- /tmp/gesto/folha.png jogo,34 /tmp/gesto/ulysses_*.glb
```

Na tela de verdade: probe web (`PROBE=… tools/perf/export_probe.sh`) que chama
`character_select._select(i, false)`, congela o rig (`set_process(false)`), toca o gesto e
avança `rig._process(0.1)` por print; o personagem fica em ~(730, 40)–(1090, 480) a 1280×720.

## Encaixe piloto × kart (`data/personagens/*_esqueleto.tres`)

O documento "Encaixe Piloto × Kart" (cena Proporcoes_Finais do kart-compare.blend) define
as regras; o jogo segue assim:

- **Escala 1, origem na origem do piloto.** `CharacterData.standard_fit = true`: o
  `KartVisual` põe o modelo em escala 1 em `KartData.driver_origin()` (o assento do kart
  menos o assento de referência, (0; 0,111; −0,118) no espaço do piloto), virado para a
  frente. `kart_scale`, `seat_height` e `seat_forward` não valem para eles.
- **A pose faz o resto.** `drive_kart` (ou `drive_moto` na moto) dá quadril, coluna,
  clavículas, braços, dedos e pernas; os veículos foram escalados para o assento e o volante
  ficarem onde a pose espera (`tools/karts/encaixe_karts.py`). `fit_seat` (a pose montada
  pelas medidas do cockpit, de antes) fica desligado. Expressões e piscada só mexem nos
  ossos do rosto.
- **Mãos no volante por IK.** O volante gira e as mãos acompanham (braço com cotovelo,
  `bend_elbows`). A pegada saiu da `POSE_Kart` contra o aro do documento (Ø 0,217 m na linha
  de pega, inclinado 59°, mãos a 70° do topo, pegas em (±0,102; 0,339; 0,215)): é o ponto da
  barra dentro da mão fechada e a direção dela para o lado do polegar, no espaço do osso da
  mão. A pose do Henrique é assimétrica, então a mão direita dele tem pegada própria
  (`grip_point_right`/`grip_axis_right`).

| Piloto | `grip_point` (mão esquerda) | `grip_axis` | Punho → pega |
|---|---|---|---|
| Jarbas | (−0,0035; 0,0804; −0,0358) | (0,9956; 0,0004; −0,0932) | 8,8 cm |
| Henrique | (0,0002; 0,0524; −0,0038); direita (0,0160; 0,0604; −0,0279) | (1; 0,0004; 0,0016); direita (−0,8769; 0,0004; −0,4808) | 5,3 / 6,8 cm |
| Ulysses | (0,0001; 0,0604; −0,0038) | (1; 0,0004; 0,0004) | 6,1 cm |

- **Volante longe ou baixo.** Nos veículos de volante bem mais baixo que o da referência
  (Relâmpago, Cometa, Bugre) o punho passaria de 95% do braço esticado: o tronco inclina um
  pouco a partir da coluna até ele chegar (`max_reach_lean` 0,4 = até 12° da
  `body_lean_forward`). No Kart Padrão, no Kart de Treino e no Bólido os cotovelos ficam
  dobrados e ele não inclina.
- **Painel baixo.** Nesses mesmos três os joelhos altos da `POSE_Kart` atravessariam o capô
  ou o painel: as pernas esticam por IK até `foot_point` (no `.tres` do kart, o tornozelo
  direito), com o quadril e o plano do joelho da pose (`_pose_legs_to_targets`).
- **Ossos auxiliares.** `Quadril_Meio.L/R` (os três) e `Cotovelo_Meio`/`Joelho_Meio` (Ulysses)
  levam exatamente 50% do giro da coxa, do antebraço e da canela (no Blender é uma
  restrição Copy Rotation, que o glb não leva; medido nas poses: 0,500). O `CharacterRig`
  refaz o giro deles a cada quadro, depois do IK (`follow_bones`, `follow_share`).

### Conferência (`poses_nos_karts.gd`, 2026-11-21)

Erro do IK das mãos 0,0 cm em todos os casos. "Virado" = maior esticada de braço com o
volante todo virado (0,85 rad); com o volante reto nenhum braço estica. Joelho: ângulo
interno (180° = reto) e distância do centro do joelho ao aro.

| Veículo | Jarbas | Henrique | Ulysses |
|---|---|---|---|
| Kart Padrão (referência) | topo 0,836; punho 8,8 cm; cotovelo 116°; virado 1,04; joelho 113°, 11,3 cm | 0,872; 5,3/6,8 cm; 128°/124°; 1,00; 119°, 8,9 cm | 0,839; 6,1 cm; 124°; 1,00; 114°, 8,9 cm |
| Kart de Treino | 0,836; 114°; 1,00; joelho 113°, 8,5 cm | 0,872; 131°/127°; 1,00; 119°, 7,4 cm | 0,839; 125°; 1,00; 114°, 7,7 cm |
| Bólido | 0,836; 113°; 1,04; 113°, 16,3 cm | 0,872; 119°/117°; 1,01; 119°, 13,7 cm | 0,839; 118°; 1,00; 114°, 13,4 cm |
| Relâmpago (pernas no `foot_point`) | 0,837; 144°; 1,05; pernas retas, 7,2 cm | 0,872; 157°/146°; 1,11; retas, 6,9 cm | 0,842; 151°; 1,10; retas, 7,2 cm |
| Cometa (pernas no `foot_point`) | 0,836; 143°; 1,00; 164°, 4,3 cm | 0,872; 156°/148°; 1,06; retas, 4,6 cm | 0,842; 150°; 1,06; retas, 4,7 cm |
| Bugre (pernas no `foot_point`) | 0,836; 139°; 1,00; 132°, 7,9 cm | 0,872; 149°/140°; 1,00; 137°, 6,6 cm | 0,842; 145°; 1,01; 137°, 6,5 cm |
| Motoca (`POSE_Moto`) | topo 0,956; 138°/153°; 1,03 | 0,959; 134°/161°; 1,06 | 0,966; 125°/132°; 1,00 |

O topo da cabeça é medido acima da origem do piloto (no Kart Padrão, o chão): no kart de
referência sai igual ao documento (0,836 / 0,872 / 0,839 m). Na Motoca as manoplas ficam a
±0,32 m do meio (a pose segura a ±0,16): os braços abrem para alcançar.

O **Rafael** tem a mesma `POSE_Kart` e as mesmas mãos do Ulysses (pegada recalculada pelos
pontos do documento: igual até a 4ª casa): topo da cabeça 0,836, punho a 6,1 cm da pega,
erro do IK 0,0 cm em todos os veículos, cotovelos e joelhos como os do Ulysses.

Em `data/personagens/<nome>.tres`: `standard_fit` ligado, `showcase_scale` 1,85 nos quatro
(em pé na seleção, todos na mesma escala), retrato `portrait_scale` 2,6 com
`portrait_offset` −0,80 (Jarbas), −0,86 (Henrique), −0,75 (Ulysses) e −0,78 (Rafael), para
os olhos ficarem na mesma altura da grade. Recoloração (jogador repetindo o personagem): só os
pontos com matiz perto da `tint_reference` trocam de cor.
