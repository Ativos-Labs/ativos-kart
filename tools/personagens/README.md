# Jarbas, Henrique e Ulysses — modelos e animações

O Jarbas, o Henrique e o Ulysses são os pilotos jogáveis de proporção de gente. Ao contrário do
Celerino (folha de papel, braço elástico), eles têm esqueleto estilo Mixamo, textura e
cotovelos. Esta pasta guarda os modelos originais e os passos que os preparam para o
jogo. O Godot ignora `tools/` (`.gdignore`).

Os três vêm do Blender já nas proporções finais e em metros (1,03, 1,06 e 1,03 m de
altura) e entram no jogo em escala 1, pelo padrão "Encaixe piloto × kart" (veja abaixo e
o README do jogo).

| Arquivo | O que é |
|---|---|
| `originais/jarbas-piloto.glb` | Modelo do Jarbas como veio do Blender: 95 ossos (com controles de IK e 2 auxiliares no quadril), 27 texturas da Tripo, 2 logos, 10 animações (`ANIM_Piscar`, `EXP_*`, `POSE_Kart`, `POSE_Moto`) e o volante/guidão de referência |
| `originais/henrique-piloto.glb` | Modelo do Henrique: o mesmo esqueleto de 95 ossos do Jarbas (com os nomes iguais), as mesmas 10 animações feitas para ele, 1 textura de 4096 px (+ normal), 2 logos e o volante/guidão de referência |
| `originais/ulysses-piloto.glb` | Modelo do Ulysses: 99 ossos (os do Jarbas + 4 auxiliares de cotovelo e joelho), as mesmas 10 animações, 2 texturas de 4096 px (cabeça da Tripo e corpo), 2 logos e o volante/guidão de referência |
| `build_personagem.py` | Passo 1 (Python + Pillow): grava `assets/models/personagens/<nome>.glb` |
| `gerar_animacoes.gd` | Passo 2 (Godot headless): grava `assets/models/personagens/<nome>_animacoes.res` |
| `poses_nos_karts.gd` | Confere o encaixe de um piloto em cada veículo pelo checklist do documento (tabela abaixo) e grava um glb da cena posada por veículo |
| `render_poses.py` | Renderiza esses glb no Blender (lado, 3/4, cima, perto do piloto e um corte que mostra pernas e pés) |
| `medir_cockpit.gd` | Mapa de ocupação lateral de cada kart (banco, encosto, assoalho, pedais) com valores sugeridos para o grupo "Cockpit" do `KartData` (usado pelo `fit_seat`, hoje desligado nos três) |

O kart de cada um, o tamanho dos veículos e a medida do assento ficam em
`tools/karts/encaixe_karts.py`.

## Regerar

```sh
python3 tools/personagens/build_personagem.py jarbas     # ou henrique, ulysses
Godot --headless --path . --import
Godot --headless --path . -s res://tools/personagens/gerar_animacoes.gd -- jarbas
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

Em `data/personagens/<nome>.tres`: `standard_fit` ligado, `showcase_scale` 1,85 nos três
(em pé na seleção, todos na mesma escala), retrato `portrait_scale` 2,6 com
`portrait_offset` −0,80 (Jarbas), −0,86 (Henrique) e −0,75 (Ulysses), para os olhos
ficarem na mesma altura da grade. Recoloração (jogador repetindo o personagem): só os
pontos com matiz perto da `tint_reference` trocam de cor.
