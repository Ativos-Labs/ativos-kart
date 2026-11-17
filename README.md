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

As teclas do kart podem ser trocadas em **Opções → Teclas** (a pausa fica fixa).

Nos menus: **setas** ou analógico/direcional para navegar (segurando, repete),
**Enter** ou **A** para confirmar, **Esc** ou **B** para voltar. A faixa de dicas no
rodapé mostra as teclas ou os botões do controle, conforme o último que foi usado.

- **Drift com mini-turbo:** aperte o drift virando numa curva e segure. As faíscas
  ficam azuis → laranjas → roxas. Solte para ganhar turbo (quanto mais tempo, maior).
  Segurando para dentro da curva o drift fecha mais e carrega mais rápido. No drift as
  rodas de trás deixam **marcas de pneu** no chão (somem depois de alguns segundos) e
  levantam poeira com a cara do cenário: terra no Campo, areia na Praia, nuvens de
  poeira vermelha no Deserto e neve fofa na Neve. Fora do asfalto a marca fica da cor do
  chão.
- **Atrito nas curvas:** virar custa velocidade. Quanto mais forte a curva (velocidade ×
  giro), mais o kart perde: virando tudo na velocidade máxima ele cai uns 12% (menos com
  boa manobrabilidade). Derrapando ele perde bem menos (uns 5%) — e ainda ganha o
  mini-turbo —, então o drift é o jeito certo de fazer as curvas longas.
- **Moedas Ativos:** espalhadas em fileiras pela pista, quase sempre fora da trajetória
  ideal (dentro, fora ou no meio da curva, nas pontes, no arco dos pulos de rampa e no
  meio dos obstáculos). Cada moeda soma 0,6% na velocidade máxima, até 10 moedas (+6%).
  O contador fica em cima da posição; as moedas voltam a aparecer 12 s depois de pegas.
- **Obstáculos que se mexem**, um tipo por pista (o Circuito não tem): **ondas do mar**
  que passam por cima da mureta e varrem a pista na Ilha, **fardos de feno** rolando aos
  trancos no Cânion e **bolas de neve** enormes descendo do lado do morro no Pico. Quem
  é atingido roda (a onda só empurra e balança), perde velocidade e **3 moedas**. O
  movimento segue o relógio da corrida: o padrão é o mesmo em toda corrida, dá para
  aprender o tempo certo.
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

## Música e som

Cada cenário tem a sua trilha, todas originais e geradas por código como os efeitos
sonoros (`tools/music/build_music.mjs`): uma base de fusion/funk com bateria e baixo na
frente, e a instrumentação muda com o cenário.

| Faixa | Onde toca | Estilo |
|---|---|---|
| `menu` | Menus | City pop / fusion tranquilo, piano elétrico e baixo com slap (108 BPM) |
| `campo` | Circuito Ativos | Fusion-rock ensolarado, metais e lead em uníssono (144 BPM) |
| `praia` | Ilha Ativos | Calypso/soca: tambor de aço com rufo, marimba, cavaquinho, congas (126 BPM) |
| `deserto` | Cânion Ativos | Frígia dominante em Mi: violão com tremolo, galope, darbuka, assobio e trompetes (136 BPM) |
| `neve` | Pico Nevado | Guizos, glockenspiel e celesta, pizzicato, vibrafone e flauta (132 BPM) |
| `podio` | Resultado | Fanfarra de metais (112 BPM) |

Na corrida a trilha começa no "VAI!". Quando o primeiro jogador chega na **volta final**,
a música some durante a fanfarra e volta **mais rápida e um tom acima** (≈12%). Na pausa
ela fica baixinha; na chegada entra a do pódio. Quem cuida disso é o `MusicPlayer`
(filho do GameState).

O áudio tem três canais (`default_bus_layout.tres`): **Master** (com limitador),
**Musica** e **Efeitos** (sons do jogo, menus e motores). O volume de cada um fica em
**Opções → Som**.

Para mudar uma música: edite a partitura em `tools/music/build_music.mjs` e rode
`node tools/music/build_music.mjs [faixa]` (precisa do ffmpeg). O script mostra o volume
de cada instrumento e de cada faixa de frequência para ajudar na mixagem.

## Opções

Menu principal e pausa → **Opções** (salvas em `user://opcoes.cfg`):

- **Som:** volume geral, música e efeitos.
- **Tela:** tela cheia e resolução da janela (na web, só tela cheia).
- **Gráficos:** qualidade **Baixa / Média / Alta** para o jogo rodar liso num PC fraco,
  e cada parte separada: sombras (desligadas, simples, completas), luz e efeitos (SSAO
  e brilho), antisserrilhado (FXAA só no desktop, MSAA 2x/4x), resolução do 3D (fixa
  de 50% a 100% ou automática) e cenário (reduzido: sem grama e flores, menos neve,
  modelos simplificam mais cedo). Mostrar FPS liga um contador no topo da tela. Na
  primeira vez o nível vem da placa de vídeo (integrada → Média, renderização por
  software → Baixa). No desktop a troca vale na hora; na web, a partir da próxima tela
  (ligar/desligar sombras lá recompila todos os shaders e travaria o jogo).
- **Teclas:** duas teclas para cada ação do kart. Escolha a vaga, aperte a tecla nova
  (Esc cancela); se outra ação usava essa tecla, as duas trocam. "Restaurar padrão" volta
  às teclas originais. A tela de controles e a dica da largada mostram as teclas atuais.

LB/RB trocam de aba no controle.

## Fluxo das telas

Menu principal → **Modo de jogo** (e "Quem vai jogar?" com 2+ jogadores) → **Escolha seu
piloto** → **Escolha seu kart** (uma vez para cada jogador) → **Escolha a pista** (no Grand
Prix, a copa) → Corrida → Resultado (classificação dos 8 karts, suas voltas; correr de novo,
trocar pista, trocar piloto, trocar kart ou voltar ao menu). No Grand Prix o resultado
mostra a classificação geral com os pontos e o botão "Próxima corrida" (na última, "Nova
copa").

Na tela de pistas a vista aérea da pista escolhida aparece ao fundo (uma imagem pronta, sem
gerar a pista em 3D: a tela fica leve e troca de pista sem travar). À esquerda ficam
as copas (a **Copa Ativos** usa o logo "at") e os cartões das pistas; à direita, o mapa do
traçado, extensão, voltas, curvas, dificuldade e recordes. Vagas sem pista aparecem como "?".

## As pistas (Copa Ativos)

| Pista            | Cenário | Destaques                                                                 |
|------------------|---------|---------------------------------------------------------------------------|
| Circuito Ativos  | Campo   | Lagos, montanhas nevadas, "S" apertado no meio                            |
| Ilha Ativos      | Praia   | Ilha com lagoa no meio, ponte estaiada com o logo na torre, ponte sobre o mar, coqueiros, guarda-sóis, veleiros com o logo na vela, farol e ondas do mar invadindo a pista |
| Cânion Ativos    | Deserto | Traçado em "8" com viaduto passando por cima da própria pista, ponte em arco azul e viaduto de pedra sobre o rio do cânion, arco de pedra sobre a pista, caixa-d'água, letreiro gigante da Ativos e fardos de feno rolando |
| Pico Nevado      | Neve    | Subida até um platô, viaduto de pedra sobre o rio congelado, ponte estaiada, pinheiros nevados, chalés, bonecos de neve de cachecol azul, neve caindo e bolas de neve descendo o morro |

Todas usam as logos da Ativos no pórtico, nas muretas, outdoors, bandeiras, balões, dirigível,
no asfalto e nas pontes.

## Estrutura

```text
scenes/
  main_menu.tscn         Tela inicial (piloto no kart parado no grid, câmera girando)
  mode_select.tscn       Modo de jogo, jogadores, cilindrada, dificuldade + "Quem vai jogar?"
  character_select.tscn  Seleção de piloto (grade de retratos + personagem 3D)
  kart_select.tscn       Seleção de kart (kart com o piloto girando + atributos)
  track_select.tscn      Seleção de pista (vista aérea ao fundo, copas, cartões, mapa e recordes)
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
  game_settings.gd      Opções (filho do GameState): volumes, tela cheia, resolução e
                        teclas do kart, salvas em user://opcoes.cfg
  graphics_quality.gd   Qualidade gráfica (filho do GameSettings): níveis e partes,
                        aplicados em cada luz/ambiente/grama quando a tela entra
  music_player.gd       Música de fundo (filho do GameState): troca com fade, volta final
                        mais rápida, música baixa na pausa
  sfx.gd                Efeitos sonoros gerados por código (canal "Efeitos")
  player_slot.gd        Um jogador: controle, piloto, kart, cor; cria as ações dele
                        ("j2_acelerar"...) só com os botões do controle dele
  menu_input.gd         Controle nos menus: analógico vira ui_left/ui_right... um passo
                        por vez (com repetição), e se o jogador está no controle ou teclado
  grand_prix.gd         Copa em andamento: pistas, participantes, pontos, grid da próxima
  ghost.gd              Fantasma do contra-relógio: grava/salva/lê o percurso (user://fantasmas/)
  ghost_kart.gd         Kart transparente que refaz o percurso do fantasma
  mode_select.gd        Tela de modo de jogo
  kart.gd               Física arcade: aceleração, curva (com atrito), pulo, drift, turbo,
                        moedas, rodopio ao bater num obstáculo, marcas de pneu e poeira
  skid_marks.gd         Marcas de pneu de todos os karts numa malha só (anel de trechos;
                        só a parte nova vai para a GPU)
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
  track_coins.gd        Moedas Ativos da pista (MultiMesh, giro no shader, coleta por
                        distância, voltam depois de 12 s)
  track_obstacles.gd    Obstáculos que se mexem (pneus, ondas, feno, bolas de neve): cada
                        um é uma função do relógio da corrida, sem física
  mesh_merge.gd         Junta malhas primitivas numa só sem ler a malha de volta da GPU
                        (use no lugar de SurfaceTool.append_from); gera LODs se pedir
  render_scale.gd       Resolução do 3D: teto de pixels na web (telas Retina) e ajuste
                        automático quando o jogo não segura ~55 fps (web e desktop, com
                        FSR no desktop): no máximo uma queda por tela, escala guardada
                        por pista e aplicada atrás do fade
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
                        opção, etiqueta do jogador, o painel "Quem vai jogar?" e a janela
                        de opções (options_panel.gd, volume_slider.gd, key_button.gd)
shaders/                Céu com nuvens, terreno, água (e gelo), asfalto, zebras, muretas com placas,
                        vegetação (com neve), pedra em blocos, painéis com logo, placas de curva,
                        turbos, rampas de pulo, caixas de item, moedas, obstáculos, ondas,
                        marcas de pneu e fundos da interface
assets/logos/           Logos da Ativos usadas na pista e nas telas
data/karts/standard_kart.tres        Dados do Kart Padrão
data/karts/relampago.tres            Dados do Relâmpago (jon_arbuckles_kart_speed.glb)
data/karts/kart_de_treino.tres       Dados do Kart de Treino (practice_kart.glb)
data/karts/bolido.tres               Bólido (bolido.glb, kart azul clássico)
data/karts/cometa.tres               Cometa (cometa.glb, kart futurista)
data/karts/motoca.tres               Motoca (motoca.glb, moto)
data/karts/bugre.tres                Bugre (bugre.glb, buggy)
data/personagens/celerino.tres       Dados do Celerino
data/personagens/jarbas.tres         Dados do Jarbas (+ jarbas_esqueleto.tres: ossos,
                                     animações e jeito de pilotar)
data/rivais/*.tres                   Adversários do computador (Celerino recolorido)
data/pistas/*.tres                   Dados das pistas (nome, copa, descrição, dificuldade)
assets/pistas/                       Imagens da tela de pistas: vista aérea (fundo) e foto
                                     da largada (cartão), geradas por tools/track_shots/
assets/models/personagens/celerino.glb   Modelo do Celerino (veja RIG.md ao lado)
assets/models/personagens/jarbas.glb     Modelo do Jarbas (+ jarbas_atlas.png e
                                     jarbas_animacoes.res), gerados por tools/personagens/
assets/models/moeda/moeda.glb        Moeda Ativos (gerada por tools/moeda/build_moeda.py)
tools/karts/                         Gera bolido/cometa/motoca/bugre.glb a partir dos
                                     modelos originais (troca os adesivos pelas logos
                                     da Ativos). O Godot ignora a pasta tools/.
tools/personagens/                   Prepara o Jarbas: limpa o modelo e junta as texturas
                                     num atlas (build_jarbas.py) e monta as animações
                                     (gerar_animacoes.gd). Veja o README.md de lá.
tools/moeda/                         Gera a moeda do jogo a partir de original/MOEDA.glb
                                     (textura de 2048 → 512 px, sem os mapas de normal e
                                     rugosidade, malha centralizada: 2,4 MB → 198 KB)
assets/music/                        Músicas (.ogg em loop, geradas por tools/music/)
default_bus_layout.tres              Canais de áudio: Master, Musica e Efeitos
tools/music/build_music.mjs          Compõe e sintetiza as músicas (Node + ffmpeg)
tools/perf/                          Medição de desempenho da versão web (probe +
                                     Chrome headless, veja tools/perf/README.md)
tools/track_shots/                   Gera as imagens de assets/pistas/ (gerar.sh, veja o
                                     README.md de lá)
web/                                 Export para o navegador (veja web/README.md)
linux/                               Export do executável Linux (veja linux/README.md)
windows/                             Export do executável Windows (veja windows/README.md)
macos/                               Export do aplicativo macOS (veja macos/README.md)
```

## Os pilotos

São dois pilotos jogáveis: o **Celerino** (folha de papel, mascote da Ativos) e o
**Jarbas** (piloto de macacão e luva). Os dois usam o mesmo `CharacterRig`; o que muda de
um para o outro (nomes dos ossos, animações extras, jeito de pilotar) fica no
`CharacterSkeleton` de cada um (`scripts/character_skeleton.gd`: os valores padrão são
os do Celerino; o do Jarbas é `data/personagens/jarbas_esqueleto.tres`).

### Celerino

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

### Jarbas

O Jarbas vem de `assets/models/personagens/jarbas.glb`, preparado a partir do modelo
original por `tools/personagens/` (README lá, com todos os números).

- **No kart:** a pose sentada é montada para cada kart a partir das medidas do cockpit
  (banco, encosto, assoalho e pedais, no grupo "Cockpit" de cada `data/karts/*.tres`): o
  bumbum apoia no estofado com as costas no encosto, as pernas esticam por IK até o
  calcanhar apoiar no assoalho (ou nos pedais, se alcança) e os braços, com cotovelo,
  fecham as mãos no aro com a pegada medida no volante de referência do arquivo. Como os
  volantes ficam longe do banco, ele inclina a partir do quadril e desliza um pouco no
  estofado — o mínimo para alcançar, calculado por veículo. Na moto a pose vem da
  `POSE_Moto` do modelo, com o quadril no selim.
- **Expressões e piscada:** as do próprio modelo (alegria, surpresa, raiva, tristeza...).
  **Gestos, respiração, olhar e formatos de mão:** transferidos das animações do Celerino
  (`tools/personagens/gerar_animacoes.gd`).
- **Parado na seleção:** a `idle_stand` mexe o corpo todo (troca o peso de uma perna para
  a outra com os pés plantados, respira, olha em volta e solta os braços); a respiração
  do Celerino, que só mexe a coluna, deixava o Jarbas duro. Vale também para os retratos.
- **Uma malha só, com textura:** as 27 texturas da Tripo e os logos viram um atlas, e o
  `CharacterMesh` junta tudo numa superfície (`shaders/character_textured.gdshader`). No
  multijogador, o jogador que repete o Jarbas corre com o azul do macacão na cor dele.

### Ajustar o piloto no kart

- Altura/posição no banco: `seat_position` em `data/karts/standard_kart.tres`.
- Tamanho do personagem no kart: `kart_scale` no `.tres` do personagem (`seat_forward`
  adianta o corpo no banco).
- Volante: `steering_wheel_center`, `steering_wheel_axis`, `steering_wheel_radius` e
  `hand_angle` (posição das mãos no aro) no `.tres` do kart.
- Pernas, inclinação e pegada: grupo "Pose de piloto" do `CharacterSkeleton` (Celerino:
  padrão em `character_skeleton.gd`; Jarbas: `jarbas_esqueleto.tres`, grupos "Pose de
  piloto" e "Sentar no kart").
- Banco, encosto, assoalho e pedais (pilotos que sentam de verdade, como o Jarbas): grupo
  "Cockpit" no `.tres` do kart; `tools/personagens/medir_cockpit.gd` mede e sugere.

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

1. Coloque o modelo (`.glb`) em `assets/models/personagens/`.
2. Duplique `data/personagens/celerino.tres` e troque o modelo, o nome, a frase, as cores
   e os atributos (1 a 5; os atributos do piloto somam com os do kart, 3 = neutro).
3. Acrescente o novo `.tres` na lista `characters` em `scripts/game_state.gd`.
4. Em `tint_materials`, liste os materiais do modelo que podem ser recoloridos (no
   Celerino, os azuis). No multijogador, quem escolhe um piloto que outro jogador já pegou
   corre com ele nessa cor do jogador; sem a lista, o piloto repetido fica igual ao original.
   Modelo com textura: deixe a lista vazia e ponha em `tint_reference` a cor que deve
   trocar (só os pontos de matiz parecida mudam).
5. **Esqueleto diferente do do Celerino:** crie um `CharacterSkeleton` (como
   `data/personagens/jarbas_esqueleto.tres`) com os ossos de cada grupo, uma
   `AnimationLibrary` com as animações que faltarem (mesmos nomes das do Celerino) e o
   jeito de pilotar, e aponte `skeleton` do personagem para ele. O caminho do Jarbas
   (atlas de texturas, animações transferidas do Celerino, pegada medida) está em
   `tools/personagens/README.md`.

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
5. Em **Cockpit**, coloque as medidas do banco, encosto, assoalho e pedais (o Jarbas
   senta a partir delas): rode `tools/personagens/medir_cockpit.gd` e confira os valores
   no mapa que ele grava (veja `tools/personagens/README.md`).
6. Em **Turbo**, cadastre as saídas de escapamento (ou turbinas) da traseira: para cada
   uma, a **posição** do centro da boca e a **direção** em que a chama sai (espaço do kart,
   frente = -Z), o **raio** da boca, o **comprimento** da chama e o **estilo** (Fogo, Jato
   ou Plasma). É delas que sai o fogo do turbo. Sem nenhuma, o turbo usa uma saída genérica
   no meio da traseira.
7. Acrescente o novo `.tres` na lista `karts` em `scripts/game_state.gd`.

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

Depois de mudar o traçado ou o cenário, gere de novo as imagens da tela de pistas
(`tools/track_shots/gerar.sh`, veja `tools/track_shots/README.md`): elas são fotos prontas
e não mudam sozinhas.

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

### Moedas

No nó raiz, em **Moedas**: `coin_lines` são as fileiras, cada uma um `Vector3` com
x = meio da fileira (fração da volta), y = deslocamento lateral em metros (+ = direita;
até ~±5,5 m para ficar dentro das zebras) e z = quantidade de moedas; `coin_spacing` é a
distância entre elas. Com `coins_on_ramps` cada rampa ganha um arco de três moedas no ar,
na altura do pulo de quem chega rápido (a conta é a mesma do `Kart._launch`). Moedas em
cima da subida de uma rampa são puladas. Para a moeda pedir uma linha diferente, ponha a
fileira a uns 4 m ou mais da trajetória ideal (`RacingLine.lateral_at`): na trajetória
o piloto do computador pega todas.

### Obstáculos

No nó raiz, em **Obstáculos**: `obstacle_zones` são os trechos (frações da volta). O tipo
vem do cenário (pneus gigantes quicando no Campo, ondas na Praia, feno no Deserto, neve
na Neve; o Circuito está sem trechos, mas os pneus continuam prontos para usar) e os
ajustes de cada tipo ficam em `track_obstacles.gd` (`ROLLERS`, constantes `WAVE_*`).
Ponha os trechos em lugares sem ponte, rampa, caixas nem turbo, com ~30 m de chão livre
dos dois lados (os obstáculos vêm de fora da mureta). As bolas de neve descem do lado
mais alto e as ondas vêm do lado mais baixo (o mar), escolhidos sozinhos pelo terreno.
O piloto do computador desvia (`TrackObstacles.lane_danger`); os mais fracos às vezes
não veem o obstáculo.

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
4. Gere as imagens da tela de pistas (vista aérea e foto da largada) com
   `tools/track_shots/gerar.sh` e aponte `background`/`thumbnail` do `.tres` para elas
   (passo a passo em `tools/track_shots/README.md`). Sem imagem, o cartão mostra o logo
   "at" e o fundo fica liso.

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

## Versão Windows (executável)

`windows/export.sh` gera `windows/dist/AtivosKart.exe` (o jogo inteiro num arquivo, com o
`.pck` embutido) e um `.zip` com ele para mandar para outra máquina. No Windows, descompacte
e dê dois cliques em `AtivosKart.exe` (sem assinatura: o SmartScreen pede para confirmar na
primeira vez). Detalhes em `windows/README.md`.

## Versão macOS (aplicativo)

`macos/export.sh` gera `macos/dist/AtivosKart-macos-universal.zip` com o `Ativos Kart.app`
(binário universal: Apple Silicon e Intel). Em outro Mac o app, com assinatura ad-hoc,
precisa ser liberado na primeira vez (botão direito → Abrir). Detalhes em `macos/README.md`.

## Publicação automática (GitHub Actions)

`.github/workflows/release.yml` faz no GitHub o que os scripts acima fazem nesta máquina:
baixa o Godot 4.7.2 oficial e os templates (ficam no cache depois da primeira vez), importa
o projeto, roda `web/export.sh`, `windows/export.sh`, `linux/export.sh` e `macos/export.sh`,
abre o jogo sem janela para conferir que não há erro de script e então:

- **numa tag `v*`**: cria a Release do GitHub com os três pacotes (Windows, macOS, Linux) e
  um `SHA256SUMS.txt`, com as notas geradas a partir dos commits, e publica a web na Vercel
  (produção). A versão da tag vai para o jogo (`config/version` e o `Info.plist` do macOS);
- **em "Run workflow"** (aba *Actions*): exporta tudo, deixa os pacotes nos *artifacts* da
  execução e, se a opção estiver marcada, publica a web na Vercel. Não cria Release.

Para lançar uma versão:

```sh
git tag v0.2
git push origin v0.2
```

Configuração (uma vez só), em *Settings → Secrets and variables → Actions* do repositório:

| Segredo | De onde vem |
| --- | --- |
| `VERCEL_TOKEN` | Token criado em *vercel.com → Account Settings → Tokens* |
| `VERCEL_ORG_ID` | `orgId` de `web/dist/.vercel/project.json` (criado pelo primeiro `vercel deploy` local) |
| `VERCEL_PROJECT_ID` | `projectId` do mesmo arquivo |

Sem esses segredos a Release sai normalmente e só o passo da Vercel falha. O macOS é
exportado no Linux com a assinatura ad-hoc embutida do Godot; Windows e macOS continuam
sem certificado (veja os READMEs de cada pasta).

## Créditos

- Modelos dos karts "standard kart", "jon arbuckle's kart (speed)", "practice kart",
  "kartrider olypios", "pink excalibur" e "thermal buggy": amogusstrikesback2 (Sketchfab),
  licença CC BY 4.0; "Crash Team Racing Nitro-Fueled kart": drance (Sketchfab), licença
  CC BY-SA 4.0 — os quatro últimos modificados (adesivos da Ativos). Veja
  `assets/models/karts/CREDITOS.txt`.
- Celerino: mascote da Ativos (`assets/models/personagens/`).
- Jarbas: piloto da Ativos (`assets/models/personagens/jarbas.glb`, preparado a partir de
  `tools/personagens/originais/jarbas-piloto.glb`).
- Logos da Ativos (ícone "at" e marca "ativos"): `assets/logos/`.
- Fontes Lilita One e Nunito — SIL Open Font License (`assets/fonts/`).
- Músicas e efeitos sonoros: originais, gerados por código (`tools/music/`, `scripts/sfx.gd`).
