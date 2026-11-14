# Ativos Kart

Jogo de kart 3D inspirado em Mario Kart, feito em **Godot 4.7**.

## Como jogar

Abra a pasta no Godot (Importar → `project.godot`) e aperte **F5** (ou o botão ▶).

| Ação          | Teclado              | Controle                |
|---------------|----------------------|-------------------------|
| Acelerar      | W ou seta para cima  | A ou RT                 |
| Frear / ré    | S ou seta para baixo | B ou LT                 |
| Virar         | A / D ou setas       | Analógico ou direcional |
| Pulo / drift  | Espaço ou Shift      | RB ou X                 |
| Reposicionar  | R                    | Y                       |
| Pausar        | Esc ou P             | Start                   |

- **Drift com mini-turbo:** aperte o drift virando numa curva e segure. As faíscas
  ficam azuis → laranjas → roxas. Solte para ganhar turbo (quanto mais tempo, maior).
  Segurando para dentro da curva o drift fecha mais e carrega mais rápido.
- **Placas laranjas** na pista dão turbo.
- **Rampas de pulo:** o kart sai do chão na borda da rampa, faz um arco e cai de volta na
  pista — quanto mais rápido, mais longe (com turbo o pulo fica bem maior). Aperte o
  **drift logo na saída da rampa** para fazer uma manobra no ar: o kart dá um giro e
  ganha um turbo ao aterrissar. No ar dá para corrigir a direção só um pouco.
- **Caixas de item** (com o logo "at"): passe por elas para pegar um item. Elas estouram e
  voltam depois de alguns segundos. *(Os itens em si ainda não existem.)*
- **Turbo de largada:** comece a acelerar logo depois do "2" da contagem (o kart dispara
  com uma arrancada fortíssima, sem bater no kart da frente do grid).
- **Adversários:** você corre contra 7 pilotos do computador e larga em último, como num
  Grand Prix. A cada corrida a ordem do grid e os karts dos adversários são sorteados. A sua posição aparece no canto de baixo, à esquerda (1º, 2º... ouro, prata e
  bronze), e cada kart é um ponto colorido no mini-mapa. Encostar em outro kart empurra os
  dois para o lado — o mais pesado empurra mais.
- Na grama o kart fica mais lento. A corrida tem 3 voltas e os recordes ficam salvos
  (separados por cilindrada).

## Modos de jogo

Menu principal → **Jogar** abre a tela **Modo de jogo**:

| Modo | O que é |
|------|---------|
| **Grand Prix** | A Copa Ativos inteira: as 4 pistas em sequência contra o computador. Pontos por chegada (15, 12, 10, 8, 6, 4, 2, 1); os mesmos adversários (piloto, kart e nível) correm as 4. Na 1ª corrida os jogadores largam no fim do grid; nas outras, o grid segue a chegada da anterior. No fim, classificação geral e troféu. |
| **Corrida** | Uma corrida avulsa na pista escolhida, com ou sem adversários do computador. |
| **Contra-relógio** | Sem adversários. O melhor percurso de cada pista (e cilindrada) vira um **kart fantasma** transparente que corre junto na próxima vez; ao fechar cada volta aparece a diferença para ele (verde = na frente). |

Opções da mesma tela:

- **Jogadores:** 1 a 4 (um por controle conectado, mais o teclado). Veja abaixo.
- **Cilindrada:** 50cc (×0,8 de velocidade), 100cc (a velocidade de sempre) ou 150cc (×1,15).
  Multiplica a velocidade máxima e a aceleração de todos os karts (no 150cc o kart também
  vira um pouco mais). O pulo das rampas fica com o mesmo tempo no ar em qualquer
  cilindrada, só mais comprido ou mais curto. Os recordes e fantasmas são separados por
  cilindrada (os de 100cc são os de antes).
- **Dificuldade** (Grand Prix e Corrida): fácil, normal ou difícil.
- **Adversários** (só Corrida): com o computador (completa o grid de 8 karts) ou sem.

## Multijogador local (tela dividida)

Até 4 pessoas na mesma tela, cada uma com um controle (o teclado conta como um). Com 2
ou mais jogadores, depois de "Continuar" aparece o painel **Quem vai jogar?**: cada um aperta
**A** (ou Start) no próprio controle — ou **Enter** no teclado — e fica com a próxima vaga
(J1 azul, J2 vermelho, J3 verde, J4 amarelo). **B/Esc** sai da vaga. Daí cada jogador escolhe
o piloto e o kart na sua vez (a etiqueta "J2" aparece no topo); quem repete um piloto já
escolhido corre com ele recolorido na cor do jogador, e o adversário do computador dessa
cor fica de fora da corrida.

- **2 jogadores:** uma tela em cima da outra (a câmera fica mais afastada nessa faixa larga).
- **3 ou 4:** quatro quadrantes; com 3, o quarto mostra o mapa grande da pista.
- Cada tela tem um HUD compacto (posição, volta, tempo, velocímetro e mapa) e uma etiqueta
  "J2" flutua em cima do kart de cada jogador para os outros acharem ele.
- O elástico dos adversários se mede pelo jogador mais adiantado.
- A corrida acaba quando todos os jogadores chegam; depois que o primeiro chega, quem falta
  tem 30 s (contagem na tela). Quem não chegou ganha um tempo estimado.
- Se o controle de alguém desconecta no meio da corrida, o jogo pausa.
- No navegador o controle só aparece depois de apertar um botão nele.
- No navegador (WebGL) 2 jogadores rodam a ~90 fps e 4 jogadores a ~70 fps num MacBook M4
  (medido sem o limite de 60 fps); numa máquina mais fraca o 4 jogadores fica perto de 30.

## Fluxo das telas

Menu principal → **Modo de jogo** (e "Quem vai jogar?" com 2+ jogadores) → **Escolha seu
piloto** → **Escolha seu kart** (uma vez para cada jogador) → **Escolha a pista** (no Grand
Prix, a copa) → Corrida → Resultado (classificação dos 8 karts, suas voltas; correr de novo,
trocar pista, trocar piloto, trocar kart ou voltar ao menu). No Grand Prix o resultado
mostra a classificação geral com os pontos e o botão "Próxima corrida" (na última, "Nova
copa").

Na tela de pistas a pista escolhida aparece ao fundo num sobrevoo de câmera. À esquerda ficam
as copas (a **Copa Ativos** usa o logo "at") e os cartões das pistas; à direita, o mapa do
traçado, extensão, voltas, curvas, dificuldade e recordes. Vagas sem pista aparecem como "?".

## As pistas (Copa Ativos)

| Pista            | Cenário | Destaques                                                                 |
|------------------|---------|---------------------------------------------------------------------------|
| Circuito Ativos  | Campo   | Lagos, montanhas nevadas, "S" apertado no meio                            |
| Ilha Ativos      | Praia   | Ilha com lagoa no meio, ponte estaiada com o logo na torre, ponte sobre o mar, coqueiros, guarda-sóis, veleiros com o logo na vela e farol |
| Cânion Ativos    | Deserto | Traçado em "8" com viaduto passando por cima da própria pista, ponte em arco azul e viaduto de pedra sobre o rio do cânion, arco de pedra sobre a pista, caixa-d'água e letreiro gigante da Ativos |
| Pico Nevado      | Neve    | Subida até um platô, viaduto de pedra sobre o rio congelado, ponte estaiada, pinheiros nevados, chalés, bonecos de neve de cachecol azul e neve caindo |

Todas usam as logos da Ativos no pórtico, nas muretas, outdoors, bandeiras, balões, dirigível,
no asfalto e nas pontes.

## Estrutura

```text
scenes/
  main_menu.tscn         Tela inicial (piloto no kart parado no grid, câmera girando)
  mode_select.tscn       Modo de jogo, jogadores, cilindrada, dificuldade + "Quem vai jogar?"
  character_select.tscn  Seleção de piloto (grade de retratos + personagem 3D)
  kart_select.tscn       Seleção de kart (kart com o piloto girando + atributos)
  track_select.tscn      Seleção de pista (sobrevoo da pista, copas, cartões, mapa e recordes)
  race.tscn              Corrida (carrega a pista escolhida + kart + câmera + HUD + pausa)
  kart.tscn              O kart (física, faíscas, turbo, som do motor)
  tracks/circuito_ativos.tscn   Circuito Ativos (campo)
  tracks/ilha_ativos.tscn       Ilha Ativos (praia)
  tracks/canion_ativos.tscn     Cânion Ativos (deserto)
  tracks/pico_nevado.tscn       Pico Nevado (neve)
  ui/hud.tscn, ui/pause_menu.tscn, ui/controls_panel.tscn
scripts/
  game_state.gd         Autoload: modo, cilindrada, jogadores (piloto e kart de cada um),
                        pista ou copa, troca de telas, recordes
  player_slot.gd        Um jogador: controle, piloto, kart, cor; cria as ações dele
                        ("j2_acelerar"...) só com os botões do controle dele
  grand_prix.gd         Copa em andamento: pistas, participantes, pontos, grid da próxima
  ghost.gd              Fantasma do contra-relógio: grava/salva/lê o percurso (user://fantasmas/)
  ghost_kart.gd         Kart transparente que refaz o percurso do fantasma
  mode_select.gd        Tela de modo de jogo
  kart.gd               Física arcade: aceleração, curva, pulo, drift, turbo
  kart_visual.gd        Modelo do kart + piloto: rodas, volante girando, mãos no volante
  character_rig.gd      Personagem animado: camadas de animação, pose sentada, reações
  character_mesh.gd     Junta as malhas do personagem numa superfície só (cores nos
                        vértices, LODs refeitos, recoloração dos adversários no shader)
  character_data.gd     Recurso com os dados de cada personagem
  kart_data.gd          Recurso com os dados de cada kart (inclui banco e volante)
  kart_exhaust.gd       Recurso de uma saída de escapamento/turbina (posição, direção, raio, estilo)
  boost_exhaust_fx.gd   Fogo do turbo saindo dos escapamentos (chamas, faíscas, fumaça, luz)
  track_data.gd         Recurso com os dados de cada pista (nome, copa, cena, dificuldade)
  track.gd              Gera a pista a partir de uma curva (Path3D): asfalto, zebras, muretas
  track_terrain.gd      Terreno em volta: plano perto da pista, colinas, lagos e montanhas,
                        mesas em degraus, mar em volta (ilha), leito dos rios, vão das pontes
  track_scenery.gd      Decoração: árvores, grama, flores, outdoors, placas, bandeiras,
                        arquibancada, dirigível e balões (com as logos da Ativos)
  track_theme.gd        Cores e vegetação de cada cenário (Campo, Praia, Deserto, Neve)
  track_props.gd        Decorações de cada cenário (coqueiros, farol, veleiros, cactos,
                        caixa-d'água, letreiro, arco de pedra, chalés, bonecos de neve)
  track_bridge.gd       Recurso com os dados de uma ponte (trecho, altura, rampa, estilo)
  track_bridges.gd      Monta as pontes (tabuleiro, pilares, torre estaiada, arco, viaduto)
  track_ramp.gd         Recurso com os dados de uma rampa de pulo (posição, altura, ângulo)
  track_ramps.gd        Monta as rampas de pulo (malha, colisão, turbo, paredes invisíveis)
  jump_ramp.gd          Colisão da rampa com a borda de onde o kart decola
  item_box.gd           Caixa de item (gira e flutua no shader, estoura e volta)
  track_builder.gd      Gera o visual das pistas numa thread para a tela de pistas trocar
                        de pista sem travar (fica no GameState; o jogo fecha por
                        GameState.quit(), que espera a geração em andamento)
  mesh_merge.gd         Junta malhas primitivas numa só sem ler a malha de volta da GPU
                        (use no lugar de SurfaceTool.append_from); gera LODs se pedir
  render_scale.gd       Web: resolução do 3D (teto de pixels em telas Retina e ajuste
                        automático quando o jogo não segura 60 fps)
  snowfall.gd           Neve caindo em volta da câmera
  drifting_prop.gd      Movimento do dirigível e dos balões
  track_select.gd       Tela de seleção de pista
  race.gd               Grid com os adversários, contagem, voltas e posições de cada kart,
                        contramão, chegada e classificação
  kart_ai.gd            Piloto do computador (trajetória, drift, manobras, ultrapassagem)
  racing_line.gd        Trajetória de corrida dos adversários (calculada a cada corrida)
  chase_camera.gd       Câmera que segue o kart (e se ajusta à faixa larga do 2 jogadores)
  ui/                   Interface: ui_kit.gd (cores, fontes, desenho), botões, faixas,
                        barras de atributos, retratos, velocímetro, semáforo, HUD, pausa,
                        posição na corrida (place_badge.gd), linhas da classificação,
                        tela dividida (split_screen.gd), cartões de modo, seletor de
                        opção, etiqueta do jogador e o painel "Quem vai jogar?"
shaders/                Céu com nuvens, terreno, água (e gelo), asfalto, zebras, muretas com placas,
                        vegetação (com neve), pedra em blocos, painéis com logo, placas de curva,
                        turbos, rampas de pulo, caixas de item e fundos da interface
assets/logos/           Logos da Ativos usadas na pista e nas telas
data/karts/standard_kart.tres        Dados do Kart Padrão
data/karts/relampago.tres            Dados do Relâmpago (jon_arbuckles_kart_speed.glb)
data/karts/kart_de_treino.tres       Dados do Kart de Treino (practice_kart.glb)
data/karts/bolido.tres               Bólido (bolido.glb, kart azul clássico)
data/karts/cometa.tres               Cometa (cometa.glb, kart futurista)
data/karts/motoca.tres               Motoca (motoca.glb, moto)
data/karts/bugre.tres                Bugre (bugre.glb, buggy)
data/personagens/celerino.tres       Dados do Celerino
data/rivais/*.tres                   Adversários do computador (Celerino recolorido)
data/pistas/*.tres                   Dados das pistas (nome, copa, descrição, dificuldade)
assets/models/personagens/celerino.glb   Modelo do Celerino (veja RIG.md ao lado)
tools/karts/                         Gera bolido/cometa/motoca/bugre.glb a partir dos
                                     modelos originais (troca os adesivos pelas logos
                                     da Ativos). O Godot ignora a pasta tools/.
tools/perf/                          Medição de desempenho da versão web (probe +
                                     Chrome headless, veja tools/perf/README.md)
web/                                 Export para o navegador (veja web/README.md)
linux/                               Export do executável Linux (veja linux/README.md)
```

## O piloto (Celerino)

O Celerino vem de `assets/models/personagens/celerino.glb` (esqueleto de 65 ossos e
48 animações). O `CharacterRig` mistura as animações por código, em camadas com
máscaras de ossos (corpo, mãos, gestos, rosto, olhos, piscada), porque os clipes do
arquivo trazem trilhas para quase todos os ossos.

- **No kart:** ele senta no banco (`seat_position` do kart), as pernas dobram e as mãos
  seguram o aro do volante (IK com braço "elástico" de desenho animado). O volante gira
  com a direção e as mãos acompanham. Ele se inclina nas curvas, olha para o lado da
  curva, faz cara de concentrado no drift, se assusta nas batidas, grita no turbo e
  comemora com os braços para cima na chegada.
- **Nas telas de seleção:** fica em pé, respira, pisca, acena e comemora ao confirmar.
- **No HUD:** o retrato redondo imita as expressões do piloto durante a corrida (a 24
  quadros por segundo, o bastante para um selo pequeno).
- **Uma malha só:** ao carregar, as 10 malhas do modelo (35 superfícies, uma por material)
  viram uma superfície com a cor e a rugosidade de cada material nos vértices
  (`scripts/character_mesh.gd` + `shaders/character.gdshader`, que imita os materiais e
  recolore os adversários). No navegador cada superfície com esqueleto custava um passe
  de deformação na GPU a cada quadro; era o maior custo da corrida. Se o modelo trocar
  por um com texturas ou transparência, o jogo volta sozinho às malhas originais
  (`CharacterMesh.enabled = false` também força isso).

### Ajustar o piloto no kart

- Altura/posição no banco: `seat_position` em `data/karts/standard_kart.tres`.
- Tamanho do personagem no kart: `kart_scale` em `data/personagens/celerino.tres`.
- Volante: `steering_wheel_center`, `steering_wheel_axis`, `steering_wheel_radius` e
  `hand_angle` (posição das mãos no aro) no `.tres` do kart.
- Pernas, inclinação e pegada: propriedades do grupo "Pose de piloto" em `character_rig.gd`.

## Os adversários

São 7 pilotos do computador. Como o Celerino é uma folha de documento, eles são outros
documentos — o mesmo modelo recolorido: **Planilha** (verde), **Boleto** (amarelo),
**Recibo** (laranja), **Contrato** (vermelho), **Relatório** (roxo), **Protocolo** (ciano) e
**Certidão** (rosa). Cada um tem seus atributos.

**Sorteio a cada corrida** (`get_rival_lineup` e `get_rival_karts` em `scripts/game_state.gd`):

- A **ordem do grid** é sorteada — cada corrida um adversário diferente larga na frente.
- Os **karts** saem de um "baralho" com todos os karts da lista `karts`: cada um aparece
  uma vez antes de algum se repetir. Com 7 karts e 7 adversários, todos os modelos estão no
  grid, cada vez com um piloto diferente. Kart novo na lista entra no sorteio sozinho.
- A **habilidade** de cada adversário também é sorteada (entre o mínimo e o máximo da
  dificuldade).

- **Mudar nome, cor ou atributos:** edite os `.tres` de `data/rivais/`. `model_tint` é a cor
  que substitui o azul do Celerino (os tons claros e escuros acompanham); `color` é a cor
  do ponto no mini-mapa e da classificação.
- **Personagens novos** (os jogáveis da lista `characters`) entram automaticamente como
  adversários quando o jogador escolhe outro, antes dos documentos.
- **Quantos e qual dificuldade:** a dificuldade e "com/sem adversários" ficam na tela Modo
  de jogo (`difficulty` e `cpu_enabled` em `scripts/game_state.gd`). Eles completam o grid de
  8 karts (`RACE_SIZE`; `rival_count` é o máximo). A velocidade e a habilidade de cada
  dificuldade ficam em `DIFFICULTY`, no começo de `scripts/race.gd` (velocidades de 100cc,
  multiplicadas pela cilindrada).

Como eles pilotam (`kart_ai.gd`):

- Seguem uma **trajetória de corrida** (abrem a curva por fora, tangenciam por dentro),
  calculada a cada corrida a partir do traçado — vale para pistas novas sem configurar nada.
- **Derrapam** nas curvas longas e soltam o mini-turbo na saída, passam pelas **placas de
  turbo**, fazem **manobra** nos pulos e às vezes pegam a **rampa estreita** (atalho).
- **Ultrapassam** escolhendo a faixa mais livre e tiram o pé quando estão colados atrás de um
  kart mais lento. Os mais fracos abrem menos as curvas, derrapam menos e erram de vez em quando.
- **Elástico:** quem fica muito atrás do jogador ganha até 9% de velocidade, e quem dispara
  na frente perde até 10% — a corrida fica disputada, mas quem pilota bem ainda escapa.
- Encalhado, fora da pista ou caído de uma ponte por 4 s, o adversário volta para a pista.
- De longe da câmera, a animação do piloto é atualizada menos vezes (economiza CPU).

## Adicionar um personagem novo

1. Coloque o modelo (`.glb`) em `assets/models/personagens/`. Ele precisa usar o mesmo
   esqueleto do Celerino (mesmos nomes de ossos e animações).
2. Duplique `data/personagens/celerino.tres` e troque o modelo, o nome, a frase, as cores
   e os atributos (1 a 5; os atributos do piloto somam com os do kart, 3 = neutro).
3. Acrescente o novo `.tres` na lista `characters` em `scripts/game_state.gd`.
4. Em `tint_materials`, liste os materiais do modelo que podem ser recoloridos (no
   Celerino, os azuis). No multijogador, quem escolhe um piloto que outro jogador já pegou
   corre com ele nessa cor do jogador; sem a lista, o piloto repetido fica igual ao original.

Ele aparece no lugar de um dos "?" da grade de seleção.

## Adicionar um kart novo

1. Coloque o modelo (`.glb`) em `assets/models/karts/`.
2. Duplique `data/karts/standard_kart.tres` e, no Inspetor, troque o **Model Scene**,
   o nome, a descrição e os atributos (1 a 5). Ajuste **Model Scale** para o kart ficar
   com ~2,4 m e **Model Rotation** para a frente apontar para -Z.
3. (Opcional) Em **Rodas**, coloque os nomes das rodas para elas girarem. Podem ser nós
   do modelo ou ossos de um esqueleto (o Relâmpago usa ossos).
4. Em **Piloto e volante**, ajuste o banco e o volante. Se o volante for uma peça
   separada (nó ou osso), coloque o nome dela para ele girar; se fizer parte da
   carroceria (como no Kart de Treino), deixe vazio e as mãos ficam paradas nele.
5. Em **Turbo**, cadastre as saídas de escapamento (ou turbinas) da traseira: para cada
   uma, a **posição** do centro da boca e a **direção** em que a chama sai (espaço do kart,
   frente = -Z), o **raio** da boca, o **comprimento** da chama e o **estilo** (Fogo, Jato
   ou Plasma). É delas que sai o fogo do turbo. Sem nenhuma, o turbo usa uma saída genérica
   no meio da traseira.
6. Acrescente o novo `.tres` na lista `karts` em `scripts/game_state.gd`.

Ele aparece automaticamente na tela de seleção e no sorteio dos karts dos adversários.

### Os karts com adesivos da Ativos (Bólido, Cometa, Motoca, Bugre)

Os modelos originais ficam em `tools/karts/originais/` e os `.glb` do jogo são gerados por
`python3 tools/karts/build_karts.py` (precisa de Python 3 com Pillow). O script:

- **Bugre:** apaga todos os adesivos que vieram no modelo (textos, mascotes, desenhos) e
  cola a marca "ativos" nas laterais, o "at" no capô e nas aletas e a marca branca numa faixa
  na asa traseira (lida de trás, por quem vem atrás).
- **Motoca:** troca os emblemas de espada do tanque por um adesivo "at".
- **Cometa:** troca o emblema de raio das laterais pelo "at" brilhando (e corrige a UV de um
  dos lados, que deixaria a logo espelhada).
- **Bólido:** não tinha textura nem adesivos; o script cola adesivos da Ativos (marca nas
  laterais, "at" no bico e no encosto do banco) como malhas finas que acompanham a
  carroceria, e separa as rodas (vinham fundidas numa malha só) para elas girarem e
  esterçarem.

Para mudar posição ou tamanho de um adesivo, edite a função do kart no script
(`build_bugre`, `build_bolido`...), rode de novo e reabra o Godot para reimportar.

## Mudar a pista

Abra `scenes/tracks/circuito_ativos.tscn`, selecione o nó **Tracado** e arraste os
pontos da curva — o asfalto, as zebras, as muretas, o terreno e a decoração são refeitos
na hora (no editor a grama e o terreno ficam mais simples, para não pesar). No nó raiz dá
para mudar:

- **Formato:** largura do asfalto, do acostamento e das muretas.
- **Zebras:** largura nas retas e nas curvas fechadas (por dentro e por fora).
- **Turbos e decoração:** posição das placas de turbo, quantidade de árvores, grama,
  canteiros de flores e balões, o dirigível e a semente aleatória da decoração.
- **Paisagem:** altura da água dos lagos, das colinas e das montanhas.

- **Cenário:** Campo, Praia, Deserto ou Neve — muda as cores do chão, da água (Neve = gelo),
  a vegetação e as decorações típicas.
- **Paisagem:** além das alturas, `hill_bias` (colinas mais altas/baixas), `terrace_step`
  (colinas em degraus, como mesas de deserto) e `sea_distance` (a partir dessa distância da
  pista o chão desce para o mar — vira uma ilha).

O céu, a luz do sol e a névoa ficam nos nós **WorldEnvironment** e **Sol** da mesma cena
(no material do céu, `bounce_color` é a cor do chão refletida na luz ambiente).
As placas das muretas, o pórtico de largada, os outdoors, as bandeiras, o dirigível, os
balões e o logo pintado no asfalto usam as imagens de `assets/logos/`.

### Pontes

No nó raiz, em **Pontes**, acrescente itens (`TrackBridge`) com:

- **Start / End:** começo e fim da ponte em frações da volta (0 = largada, 0.5 = metade).
- **Height / Ramp:** quanto a pista sobe e o comprimento das rampas antes e depois — a
  subida é feita sozinha, não precisa mexer na curva.
- **Over Water:** o chão embaixo afunda abaixo da água (mar/lagoa).
- **Style:** Pilares, Estaiada (torre com o logo "at" e cabos), Arco (arco de aço azul com a
  marca no alto) ou Viaduto (arcos de pedra com medalhões do logo).

A ponte também pode passar por cima de outro trecho da pista (viaduto do Cânion): os pilares
não caem em cima do asfalto de baixo. O traçado também aceita altura nos próprios pontos da
curva (subidas como a do Pico Nevado); a colisão acompanha a pista e o kart inclina junto.

### Rampas de pulo

No nó raiz, em **Rampas**, acrescente itens (`TrackRamp`) com:

- **At:** posição da borda da rampa em fração da volta.
- **Length / Height / Angle:** comprimento da subida, altura da borda e ângulo de saída. A
  rampa começa rente ao asfalto e vai curvando até o ângulo da borda; o pulo sai com esse
  ângulo (velocidade × tangente do ângulo) e depois só a gravidade age — o kart não plana.
  Com 1,4 m e 22°: a 27 m/s ele fica 0,8 s no ar e anda ~21 m; com turbo, ~1 s e ~36 m.
- **Width / Offset:** largura em fração do asfalto e para que lado ela fica (rampa estreita
  num lado da pista = atalho opcional).
- **Turbo:** a rampa vira uma placa de turbo (pulo longo).

Ponha as rampas em retas, com uns 45 m livres depois da borda (no ar o kart vai quase reto).
No trecho do pulo a pista ganha paredes invisíveis em cima das muretas, para o kart nunca
sair da pista pelo ar; e se ele chegar torto, a rampa o endireita um pouco na decolagem.

### Caixas de item

No nó raiz, em **Caixas de item**: `item_rows` são as posições das fileiras (frações da
volta) e `item_boxes_per_row` quantas caixas cada fileira tem. Quando o kart pega uma caixa,
ele emite o sinal `item_box_collected`; a corrida (`race.gd`, `_on_item_box_collected`) é o
lugar para ligar a lógica dos itens. Os adversários também estouram as caixas, mas por
enquanto só o sinal do kart do jogador está ligado — quando os itens existirem, ligue o
sinal de cada kart (`racers` em `race.gd`) e ensine o `KartAI` a usar o item.

### Rios

Crie nós **Path3D** filhos da pista com nome começando por "Rio" e desenhe a linha do rio.
O chão é cavado ao longo dela, com água no fundo. Passe os rios por baixo das pontes — eles
não cavam perto da pista. No nó raiz, em **Rios**: largura, profundidade, margem e
`river_valley` (0 = paredões retos de cânion; 1 ou mais = vale aberto de montanha).

## Adicionar uma pista nova

1. Duplique uma das cenas de `scenes/tracks/`, troque o `track_id`/`track_name` no nó
   raiz, escolha o **Cenário** e desenhe o novo traçado no nó **Tracado** (pontes e rios
   como explicado acima).
2. Duplique `data/pistas/circuito_ativos.tres` e troque a cena, o `id` (igual ao
   `track_id`), o nome, a copa, a descrição, a dificuldade e as voltas.
3. Acrescente o novo `.tres` na lista `tracks` em `scripts/game_state.gd`.

Ela aparece no lugar de um dos "?" da tela de pistas. Pistas com outro nome de copa
ganham um emblema próprio na fileira de copas.

## Versão web (navegador)

O jogo também roda no navegador (Godot Web, WebGL 2) e está pronto para publicar na
Vercel. Resumo: `web/export.sh` gera `web/dist/`, `python3 web/serve.py` testa em
`http://localhost:8060` e `cd web/dist && vercel deploy --prod` publica. O passo a
passo, o que muda na web e as medições de desempenho estão em `web/README.md`.

## Versão Linux (executável)

`linux/export.sh` gera `linux/dist/AtivosKart.x86_64` (o jogo inteiro num arquivo, com o
`.pck` embutido) e um `.tar.gz` com ele para mandar para outra máquina. No Linux:
`tar xzf AtivosKart-linux-x86_64.tar.gz && ./AtivosKart.x86_64`. Detalhes em
`linux/README.md`.

## Créditos

- Modelos dos karts "standard kart", "jon arbuckle's kart (speed)", "practice kart",
  "kartrider olypios", "pink excalibur" e "thermal buggy": amogusstrikesback2 (Sketchfab),
  licença CC BY 4.0; "Crash Team Racing Nitro-Fueled kart": drance (Sketchfab), licença
  CC BY-SA 4.0 — os quatro últimos modificados (adesivos da Ativos). Veja
  `assets/models/karts/CREDITOS.txt`.
- Celerino: mascote da Ativos (`assets/models/personagens/`).
- Logos da Ativos (ícone "at" e marca "ativos"): `assets/logos/`.
- Fontes Lilita One e Nunito — SIL Open Font License (`assets/fonts/`).
