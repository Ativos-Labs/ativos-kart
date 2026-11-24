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
| Usar item     | E ou Enter           | LB                      |
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
- **Moedas Ativos (Correção monetária):** com o "at" na frente e um **"%" gravado** no
  verso, espalhadas em fileiras pela pista, quase sempre fora da trajetória
  ideal (dentro, fora ou no meio da curva, nas pontes, no arco dos pulos de rampa e no
  meio dos obstáculos). Cada moeda soma 0,6% na velocidade máxima, até 10 moedas (+6%).
  O contador fica no canto inferior esquerdo, ao lado da volta; as moedas voltam a
  aparecer 12 s depois de pegas.
- **Tela limpa:** durante a corrida o HUD mostra só o mapa, as moedas e a volta (duas
  pílulas escuras no canto inferior esquerdo) e a posição (canto inferior direito); o
  canto superior esquerdo só mostra o item guardado (vazio, ele some). O tempo e o recorde aparecem no canto superior direito quando você cruza a
  chegada — no contra-relógio o relógio fica na tela o tempo todo.
- **Obstáculos que se mexem**, um tipo por pista (o Circuito não tem): **ondas do mar**
  que passam por cima da mureta e varrem a pista na Ilha, **tambores de coluna de templo** rolando aos
  trancos no Cânion e **bolas de neve** enormes descendo do lado do morro no Pico. Quem
  é atingido roda (a onda só empurra e balança), perde velocidade e **3 moedas**. O
  movimento segue o relógio da corrida: o padrão é o mesmo em toda corrida, dá para
  aprender o tempo certo.
- **Placas laranjas** na pista dão turbo.
- **Rampas de pulo:** o kart sai do chão na borda da rampa, faz um arco e cai de volta na
  pista — quanto mais rápido, mais longe (com turbo o pulo fica bem maior). Aperte o
  **drift logo na saída da rampa** para fazer uma manobra no ar: o kart dá um giro e
  ganha um turbo ao aterrissar. No ar dá para corrigir a direção só um pouco.
- **Rampas de asa-delta** (painel azul aceso com setas brancas e moldura amarela): o kart
  sobe alto, a **asa-delta abre** em cima dele (presa na carroceria por quatro cordas) e ele **plana** de 3,5 a 6 s, descendo
  devagar. No ar o direcional vira (o kart inclina como um avião) e **segurar o freio
  levanta o bico** — desce mais devagar, mas perde velocidade. Paredes invisíveis altas
  seguram o voo dentro da pista; ao tocar o chão a asa fecha. Também dá para fazer a
  manobra na decolagem (o turbo vem na aterrissagem). Há uma em cada pista, sempre na
  **beira de um vale**: a pista acaba no penhasco e só continua do outro lado, uns 100 m
  depois e mais baixo — o voo passa por cima de uma ravina com rio, cachoeira e o cenário
  de cada lugar (veja **As pistas**). Passada a beira do outro lado, a asa **desce para
  o pouso** (bico para baixo) e o kart toca o chão logo depois dela. A rampa ocupa a pista toda, e quem chega devagar
  decola com pelo menos 88% da velocidade máxima: o vão sempre dá para atravessar. Quem
  leva um golpe de item no meio do voo perde a asa e cai no vale — e volta para a pista
  do outro lado. Moedas no ar pelo caminho (uma fileira de cada lado).
- **Trechos especiais** (cada pista tem o seu):
  - **Debaixo d'água** (Circuito, Ilha e Cânion): a pista mergulha no lago, no mar ou no
    oásis. Lá embaixo a
    câmera fica azul-esverdeada, a superfície brilha lá em cima, raios de sol, algas, peixes,
    bolhas saindo do kart e respingo ao entrar e sair. O kart fica **mais leve** (pulos
    longos e lentos, gravidade pela metade) e um pouco mais lento.
  - **Dunas** (Cânion): a areia sobe e desce; rápido, o kart dá
    um **pulinho na crista** de cada duna. A **areia fofa** junto das muretas segura o
    kart, e os **redemoinhos de areia movediça** puxam para o meio e giram o kart (com
    turbo dá para escapar).
  - **Pista de neve e gelo** (Pico): não tem asfalto. A pista inteira é **neve batida**
    (sulcos da máquina de neve, trilhas de pneu, cristais que brilham contra o sol; o kart
    solta um pouco a traseira e levanta um véu de neve quando anda rápido), com montes de
    neve no lugar das muretas e das zebras. Três trechos viram **rio congelado** — gelo
    liso e transparente com rachaduras, bolhas presas e peixes nadando embaixo, que
    **escorrega**: o kart demora para seguir o bico e desliza de lado nas curvas. A
    descida do platô é um riacho congelado que deságua no lago, e a reta final é outro
    riacho (com as bolas de neve). Cristais de gelo gigantes nas margens e um arco de
    gelo sobre cada riacho; no céu, o halo de 22° em volta do sol.
  - **Pista de areia** (Cânion, deserto do Egito): também sem asfalto. A pista inteira é
    **areia batida** (trilhas de pneu, ondinhas do vento, areia solta soprada por cima,
    pedrinhas; o kart solta um pouquinho a traseira e levanta um véu de areia quando anda
    rápido), com montes de areia no lugar das muretas — com blocos de arenito meio
    enterrados, entalhados com a marca da Ativos e hieróglifos pintados — e uma leira de
    areia no lugar das zebras. Depois das dunas a pista desce uma depressão até o
    **oásis** e passa por baixo d'água no meio das ruínas de um templo afundado.
  - **Pista de praia** (Baía): também sem asfalto. **Areia branca de praia** (trilhas de
    pneu, conchinhas; solta um pouquinho a traseira, como a areia do deserto), cercas de
    corda com postes brancos no lugar das muretas, **passarela de tábuas** sobre a baía
    (firme como o asfalto), a **trilha da mata** de terra batida alaranjada (aderência um
    pouco menor, cerca de madeira escura e murinhos de pedra com flores) e o **baixio**:
    a pista passa uns 20 cm debaixo d'água, entre linhas de boias — o kart fica um pouco
    mais lento, joga água para os lados e respinga ao entrar e sair do mar.
- **Caixas de item** (com o logo "at"): passe por elas para pegar um item. Elas estouram e
  voltam depois de alguns segundos. O item aparece no **slot do canto superior esquerdo**
  (como no Mario Kart) depois de uma **roleta vertical** (os ícones descem e freiam até
  parar no sorteado). Os de Caos, Ataque, Armadilha e Defesa ficam guardados até você
  usar (**E**, **Enter** ou **LB**; a tecla aparece no canto do slot) — segurando o
  **freio** na hora, o carimbo e a calculadora vão **para trás**; os de Velocidade (turbos
  e moedas) são usados assim que a roleta para. Com item guardado, a caixa não dá outro. Veja **Itens**
  abaixo.
- **Turbo de largada:** comece a acelerar logo depois do "2" da contagem (o kart dispara
  com uma arrancada fortíssima, sem bater no kart da frente do grid).
- **Adversários:** você corre contra 7 pilotos do computador e larga em último, como num
  Grand Prix. A cada corrida a ordem do grid e os karts dos adversários são sorteados. A sua posição aparece no canto de baixo, à direita (só o número: 1º, 2º...; ouro, prata e
  bronze), e cada kart é um ponto colorido no mini-mapa. Encostar em outro kart empurra os
  dois para o lado — o mais pesado empurra mais.
- Na grama o kart fica mais lento. A corrida tem 3 voltas e os recordes ficam salvos
  (separados por cilindrada). Os recordes e fantasmas são do traçado atual
  (`GameState.TRACK_LAYOUT`): quando as pistas mudam de traçado eles recomeçam.

## Itens

O sorteio depende da posição: quem está na frente tira mais moedas, carimbos, Juridiquês
e armadilhas (pilhas de papel e caixas falsas); no meio saem mais Intimações e
calculadoras; quem está atrás tira mais turbos, Deságio, Antecipação, a PEC dos
Precatórios e o Trânsito em julgado, e só os últimos tiram a Superpreferência (o líder
nunca recebe Deságio, Antecipação, Superpreferência, Intimação, PEC, calculadora nem
Trânsito em julgado). A Liminar é rara em qualquer posição, um pouco menos para o líder.
Deságio, Antecipação, Superpreferência e a PEC existem um de cada vez na pista: não saem
na roleta enquanto alguém tem um nem logo depois de alguém usar. Os pilotos do computador também
pegam e usam itens (esperam um pouco; cada item tem um tempo mínimo entre usos do
computador, para ninguém levar um poder atrás do outro). No contra-relógio e numa corrida
sem rivais as caixas não dão item.

**Caos** — ficam guardados no slot até você usar:

| Item | O que faz |
|------|-----------|
| **Deságio** (o raio) | Todo mundo encolhe, menos você. Um **"deságio" vermelho gigante aparece no céu** (com um "−%" pequeno embaixo), um raio cai em cada rival (rodam e perdem velocidade) e eles ficam pequenos de 4,5 a 7,5 s (quem está mais na frente fica mais tempo): 20% mais lentos, leves nas batidas e com o motor fininho. Um kart grande que encosta num pequeno **amassa** ele. Se você estiver pequeno, volta ao normal. |
| **Juridiquês** (a tinta na tela) | Cobre a visão dos rivais à frente com borrões de tinta cheios de **texto jurídico miúdo** ("Outrossim, data venia, considerando-se…") por 5 s; depois a tinta escorre e some. Quem leva fica com um "§" flutuando em cima do kart; os pilotos do computador ziguezagueiam e aliviam o pé. Usado pelo líder, pega quem vem atrás. |
| **Cessão de crédito** (o fantasma) | Rouba o item do rival mais perto à frente (ou atrás, se não houver ninguém à frente). **O Celerino, de fantasma, assina um contrato no ar** em cima do rival — no seu HUD aparece o contrato com cedente, cessionário, a assinatura e o carimbo "CEDIDO" — e o item muda de dono. Não rouba outra Cessão; se ninguém tiver item, o crédito vem novo (a roleta gira de novo). |

**Velocidade** — usados assim que a roleta para (o slot mostra o item um instante e some):

| Item | O que faz |
|------|-----------|
| **RPV** (o cogumelo) | Turbo curto (1,7 s). **Uma guia de pagamento verde vira foguete embaixo do kart**: a guia aparece esticada, enrola num tubo, ganha bico, aletas e fogo, e o kart sobe em cima dela; no fim o foguete solta e fica para trás. A RPV é paga em uns 60 dias, então é o crédito rápido (está escrito na guia). |
| **Antecipação Celer** (o cogumelo dourado) | Turbo à vontade por 7 s. **O Celerino aparece voando ao lado do kart com uma maleta dourada**, a maleta abre (com os maços de notas dentro) e solta o primeiro jato; depois **cada toque no botão de item solta um jato de notas atrás do kart** e um turbo. O slot fica com a maleta, a tecla e um anel dourado que esvazia. No fim ele fecha a maleta, acena e vai embora. |
| **Superpreferência** (o Bill Bala) | Piloto automático que fura a fila, de 4,5 s (meio do pelotão) a 6,5 s (último). **O kart vira um ofício gigante** (folha A4 de 3 m voando como um tapete, com o texto do ofício) e **o carimbo PRIORIDADE bate em cima** — idosos e doentes graves furam a ordem de pagamento. Ele anda sozinho pela pista a 1,6× a velocidade máxima, perto da trajetória ideal, sem bater em nada e sem levar raio, tinta ou obstáculo, e **passa por cima de todo mundo**: quem ele alcança fica achatado e é jogado para o lado. A câmera sobe para mostrar a folha; no fim ela sai voando e o kart volta com um turbo. |
| **Correção monetária** (as moedas) | **Três moedas com "%" gravado** aparecem em cima do kart e caem dentro dele, uma por uma: cada uma aumenta um pouco a velocidade máxima, como as da pista (até 10). Sai menos para quem já tem quase todas. |

**Ataque** — ficam guardados no slot até você usar; acertam os rivais (quem leva roda,
perde velocidade e 3 moedas):

| Item | O que faz |
|------|-----------|
| **Carimbo INDEFERIDO** (o casco verde) | Um **carimbo de borracha** (cabo vermelho, base de madeira, etiqueta "INDEFERIDO") sai voando baixo, girando, em linha reta, e **ricocheteia nas muretas** até 5 vezes (ou 7 s). Segurando o freio, sai para trás. Depois da primeira batida pode acertar você mesmo. O rival atingido fica com a **marca vermelha "INDEFERIDO" estampada** atrás do kart por alguns segundos. |
| **Intimação** (o casco vermelho) | Um **envelope oficial com asinhas** (verso com o lacre de cera e "INTIMAÇÃO"; na frente, PODER JUDICIÁRIO e o carimbo URGENTE) voa pela pista atrás do kart que está logo à sua frente e, chegando perto, vai direto nele ("INTIMADO!"). Acerta quem estiver no caminho. Quem é o alvo vê o aviso **INTIMAÇÃO!** no alto da tela. |
| **PEC dos Precatórios** (o casco azul) | Uma **Constituição gigante** (livro de 4 × 5,4 m, capa azul com letras douradas e um post-it "PEC DOS PRECATÓRIOS") sobe com asas de penas e voa alto pela pista até o **1º lugar**, para em cima dele, recolhe as asas e **cai de chapa**: o líder fica amassado e depois **parcelado** — avança aos pedacinhos, em 6 trancos com um pulinho cada ("PARCELA 1/6"… "6/6"), por 3 s. Quem está perto do líder roda. O líder vê o aviso **PEC A CAMINHO!**. Só uma por vez na pista. |
| **Impugnação dos cálculos** (a bomba) | Uma **calculadora** é jogada num arco para a frente (ou largada atrás, segurando o freio). No chão ela **apita em contagem regressiva** — o visor mostra 3, 2, 1 e "ERRO", o LED pisca e um anel vermelho marca o alcance — e **estoura numa chuva de números** (algarismos, "%", "R$", sinais): todo mundo a até 7 m (você também) roda e voa para o alto. Estoura antes se um kart encostar nela ou se um carimbo ou envelope passar por ela. |

**Armadilha** — ficam guardadas no slot até você usar; são largadas atrás do kart e ficam
na pista (até 80 s, no máximo 14 ao mesmo tempo — a mais velha some):

| Item | O que faz |
|------|-----------|
| **Pendência documental** (a banana) | Uma **pilha de papel com um clipe gigante** cai atrás do kart; a folha de cima é a lista do que falta (procuração, certidão negativa, RG autenticado…, cada um com um "X" vermelho) e o carimbo PENDENTE. Quem bate **escorrega e roda numa chuva de folhas** (perde velocidade e 3 moedas). |
| **Fila do tribunal** (a caixa falsa) | Uma caixa **igual à de item, só que com o logo de cabeça para baixo**, flutuando e girando como as de verdade. Quem pega vê a caixa estourar normalmente... e **fica parado na fila** por 2,4 s, **segurando no alto a senha "AGUARDE SUA VEZ"**, enquanto um painel vermelho chama as senhas ("CHAMANDO 084", "085"…) até chegar na dele — o painel fica verde, toca o "plim-plom" e a senha voa longe. |

**Defesa** — ficam guardados no slot até você usar:

| Item | O que faz |
|------|-----------|
| **Trânsito em julgado** (a estrela) | **Invencível por 7,5 s**: o kart e o piloto ficam **banhados de dourado** (com um reflexo varrendo), uma aura e um brilho no chão os envolvem, brilhos sobem em espiral e **um martelo de juiz gigante gira em volta, batendo** — nada mais muda a decisão. Nenhum item, obstáculo, raio, tinta ou PEC pega; quem encosta **roda** (martelada); o kart corre 18% mais, acelera mais forte e a grama não segura. Cura o que estava pegando (pequeno, amassado, parcelado, na fila). Pisca nos últimos segundos. |
| **Liminar** (a super buzina) | **Uma onda verde sai do kart** (buzina de metais) e um **escudo-documento com LIMINAR DEFERIDA** aparece em cima dele: tudo a até 7 m é destruído — carimbos, envelopes, calculadoras (desarmadas, sem estourar), pilhas de papel e caixas falsas — e quem está em volta roda. **A PEC dos Precatórios também**: voando por perto, parada em cima de você ou caindo, ela sai voando girando e não parcela ninguém — o aviso **PEC A CAMINHO!** fica verde: **PEC SUSPENSA!** |

Os pilotos do computador miram: jogam o carimbo e a calculadora quando há alguém na
frente (ou colado atrás, e aí jogam para trás), a Intimação quando não estão em primeiro e
a PEC sempre que não lideram. Largam armadilhas quando há alguém colado atrás, usam o
Trânsito em julgado quando um ataque vem neles (ou para alcançar quem está na frente) e a
Liminar quando a PEC ou um tiro chega perto, ou com rivais em volta — o líder guarda a
Liminar para a PEC. Eles desviam das pilhas de papel (os bons quase sempre), mas quase
ninguém percebe a caixa falsa.

Para criar um item novo: acrescente-o em `RaceItem` (`Kind`, `INFO` e o desenho do ícone
em `draw_icon`), o peso no sorteio em `RaceItems._draw_item` e o efeito em
`RaceItems._use`. Item de uso imediato (um turbo, por exemplo) leva `"auto": true` em
`INFO`: sai da roleta e já é usado, sem ficar no slot; `"single": true` deixa só um na
pista por vez. Itens que voam ou ficam na pista (Ataque, Armadilha e a onda da Liminar)
ficam em `ItemAttacks`. Os
efeitos 3D ficam em `ItemEffects` e mexem só em passos de física
(tweens de física); todo visual novo também aparece em `ItemEffects.prewarm` (os shaders
compilam atrás da tela de carregamento).

As texturas da guia da RPV, do ofício, do carimbo PRIORIDADE, da nota, da marca
INDEFERIDO, do envelope, da asa, da capa da Constituição, da calculadora, dos números da
explosão, da folha da Pendência, da senha e do escudo da Liminar são geradas por
`python3 tools/itens/build_item_textures.py` (Pillow e as fontes do macOS). A caixa falsa
usa o mesmo shader das caixas de verdade (`upside_down` vira o logo).

### Modo dev (testar os itens)

Rodando pelo editor (F5) o modo dev já vem ligado; na build exportada, use `-- --dev` na
linha de comando ou `?dev` no endereço da versão web. Numa corrida com rivais, **F1** ou a
tecla à esquerda do **1** (no Mac o F1 pede o `fn`) abre o painel (`DevPanel`, etiqueta
"DEV" no alto da tela):

- **1–9, 0, −** (ou clique): você ganha o item na hora, com uma roleta curta. As
  Armadilhas e Defesas ficam nas letras: **B** Pendência documental (a banana), **F** Fila
  do tribunal, **J** Trânsito em julgado, **L** Liminar.
- **Alt/Option + tecla** (ou clique direito): um rival usa o item em você — quem está logo
  atrás para Juridiquês, Intimação, PEC e Superpreferência; o mais perto para os outros. Os
  ataques miram em você (a PEC cai em você mesmo sem você ser o líder, a calculadora corrige
  o voo no ar) e as armadilhas caem na pista logo à sua frente. Na Cessão sem item, você
  ganha um carimbo e o rival o rouba logo depois.
- **I** item infinito · **N** rivais sem itens · **T** rivais parados (alvos).

Usou o painel, a corrida não vale recorde. Só o J1 recebe os itens.

## Modos de jogo

Menu principal → **Jogar** abre a tela **Modo de jogo**:

| Modo | O que é |
|------|---------|
| **Grand Prix** | Uma copa inteira (a Copa Ativos são as 4 primeiras pistas; a Copa Verão, por enquanto, a Baía Ativos e o Estádio Celerino) em sequência contra o computador. Pontos por chegada (15, 12, 10, 8, 6, 4, 2, 1); os mesmos adversários (piloto, kart e nível) correm as 4. Na 1ª corrida os jogadores largam no fim do grid; nas outras, o grid segue a chegada da anterior. No fim, classificação geral e troféu. |
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
(J1 azul, J2 vermelho, J3 verde, J4 amarelo). **B/Esc** sai da vaga. Daí todos escolhem
piloto, kart e asa-delta **ao mesmo tempo**, cada um no próprio controle:

- **Pilotos:** a grade fica no meio e cada jogador tem um cursor na cor dele (etiqueta
  J1/J2/J3/J4 num canto do quadradinho); o cartão de cada um, nos cantos da tela, mostra o
  piloto dele no palco, o nome e os atributos.
- **Karts e asas:** um cartão por jogador (lado a lado com 2, quadrantes com 3 ou 4), com
  o kart dele girando no palco; **←/→** troca.
- **A/Enter** confirma (selo "PRONTO!" e aro amarelo), **B/Esc** desfaz; B de quem ainda
  não confirmou volta para a tela anterior. Quando todos confirmam, a tela segue sozinha.
  O mouse vale pelo jogador do teclado (ou pelo J1): clique no quadradinho ou nas setas, e
  no palco do próprio cartão para confirmar.
- Quem repete um piloto já escolhido por um jogador anterior corre com ele recolorido na
  cor do jogador, e o adversário do computador dessa cor fica de fora da corrida.
- Cada cartão tem o próprio mundo 3D (`PickStage`, uma SubViewport no tamanho real do
  cartão); a janela principal desliga o 3D nessas telas. A entrada de cada controle e o
  "todos prontos" ficam no `MultiPick`.

- **2 jogadores:** uma tela em cima da outra (a câmera fica mais afastada nessa faixa larga).
- **3 ou 4:** quatro quadrantes; com 3, o quarto mostra o mapa grande da pista.
- Cada tela tem um HUD compacto (moedas, volta, posição e mapa; o tempo aparece na
  chegada) e uma etiqueta
  "J2" flutua em cima do kart de cada jogador para os outros acharem ele.
- O elástico dos adversários se mede pelo jogador mais adiantado.
- A corrida acaba quando todos os jogadores chegam; depois que o primeiro chega, quem falta
  tem 30 s (contagem na tela). Quem não chegou ganha um tempo estimado.
- Só quem pausou mexe na pausa (e nos painéis de Controles e Opções dentro dela); uma
  etiqueta "J2 pausou" ao lado do título mostra quem é. Os outros controles, o teclado e o
  mouse ficam de fora até a pausa fechar.
- Se o controle de alguém desconecta no meio da corrida, o jogo pausa, e aí qualquer um
  mexe (o mesmo vale se o controle de quem pausou desconecta).
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
| `campo` | Circuito Ativos e Estádio Celerino | Fusion-rock ensolarado, metais e lead em uníssono (144 BPM) |
| `praia` | Ilha Ativos e Baía Ativos | Calypso/soca: tambor de aço com rufo, marimba, cavaquinho, congas (126 BPM) |
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
  software → Baixa). Enquanto ninguém mexe nas opções, o executável também mede a placa:
  se numa corrida de um jogador ela só seguraria 60 fps com o 3D abaixo de ~1600×900, o
  nível desce um degrau (Alta → Média → Baixa) na próxima troca de tela e fica guardado
  (`nivel_automatico`); escolher qualquer coisa nas opções desliga isso. No desktop a
  troca vale na hora; na web, a partir da próxima tela (ligar/desligar sombras lá
  recompila todos os shaders e travaria o jogo).
- **Teclas:** duas teclas para cada ação do kart. Escolha a vaga, aperte a tecla nova
  (Esc cancela); se outra ação usava essa tecla, as duas trocam. "Restaurar padrão" volta
  às teclas originais. A tela de controles e a dica da largada mostram as teclas atuais.

LB/RB trocam de aba no controle.

## Fluxo das telas

Menu principal → **Modo de jogo** (e "Quem vai jogar?" com 2+ jogadores) → **Escolha seu
piloto** → **Escolha seu kart** → **Escolha sua asa-delta** (cada uma uma vez para cada
jogador) → **Escolha a pista** (no Grand Prix, a copa) → Corrida → Resultado (classificação dos 8 karts, suas voltas; correr de novo,
trocar pista, trocar piloto, trocar kart ou voltar ao menu). No Grand Prix o resultado
mostra a classificação geral com os pontos e o botão "Próxima corrida" (na última, "Nova
copa").

Na tela de pistas a vista aérea da pista escolhida aparece ao fundo (uma imagem pronta, sem
gerar a pista em 3D: a tela fica leve e troca de pista sem travar). À esquerda ficam
as copas (emblemas com o logo "at" no anel da cor da copa) e os cartões das pistas da copa
escolhida; à direita, o mapa do traçado, extensão, voltas, curvas, dificuldade e recordes.
Vagas sem pista aparecem como "?". Cada copa é uma página de 4 cartões: troca-se clicando
no emblema, com **Page Up / Page Down** ou com **LB / RB** no controle (a copa de cada
pista é o `cup_name` do `TrackData`, na ordem da lista `GameState.tracks`).

## As pistas

### Copa Ativos

| Pista            | Cenário | Destaques                                                                 |
|------------------|---------|---------------------------------------------------------------------------|
| Circuito Ativos  | Campo   | 1,5 km. Lagos, montanhas nevadas, "S" apertado no meio. Nova volta pelo leste: sobe uma colina, salta de asa-delta sobre o **Vale da Cachoeira** (cânion de pedra com rio, pedras, ponte pênsil de madeira, cachoeira com arco-íris e pássaros) e depois **mergulha no lago** (algas, nenúfares, cardumes, barco a remo afundado, píer com a bandeira da Ativos) |
| Ilha Ativos      | Praia   | 1,3 km. Ilha com lagoa no meio, ponte estaiada com o logo na torre (com rampa de turbo), coqueiros, guarda-sóis, veleiros, farol e ondas do mar invadindo a pista. A asa-delta sai de um penhasco sobre a **Enseada dos Penhascos** (rochas no mar, golfinhos pulando, barco encalhado, cachoeira caindo no mar com arco-íris) e a pista **mergulha no recife** (corais, estrelas-do-mar, cardumes coloridos, navio pirata naufragado com o baú do tesouro da Ativos e o submarino amarelo da Ativos) |
| Cânion Ativos    | Deserto | 2,0 km, **deserto do Egito sem asfalto**: areia batida do começo ao fim num mar de dunas, largada num portal de templo (pilonos com hieróglifos, bandeiras e o disco alado com o logo). Traçado em "8" com o viaduto por cima da própria pista e um viaduto de pedra sobre o rio; a asa-delta cruza a **Garganta do Cânion** (paredões, rio com margens verdes, cachoeira, tamareiras, urubus). O laço de baixo, maior, passa pelas **dunas** (pulinhos, areia fofa, areia movediça), pula de uma rampa e desce até o **oásis** — tamareiras, papiros, lótus azuis, um cais com obeliscos e um barco à vela da Ativos, camelos bebendo água — e **mergulha** entre colunas de um templo afundado, a cabeça de um faraó e ânforas. Na volta, a **avenida de esfinges**, o portal do templo com colunata e obeliscos e a esfinge gigante; a pirâmide com a ponta de ouro e o logo "at" no meio do laço (com uma caravana de camelos dando a volta) e mais duas no horizonte |
| Pico Nevado      | Neve    | 1,6 km, **sem asfalto**: neve batida e rio congelado do começo ao fim, num dia de sol com halo em volta do sol. Subida até o platô, viaduto de pedra sobre o rio congelado, pinheiros, chalés, bonecos de neve e bolas de neve rolando. Do alto do platô a asa-delta atravessa o **Vale Glacial** (paredões de pedra nevada, cascata congelada, rio congelado, teleférico com cabines azul e amarela indo e vindo, águias); na volta, um **riacho congelado** desce do platô por baixo de um arco de gelo e deságua no **lago congelado** (blocos de gelo, cabanas de pesca, pinguins patinando em roda), e a reta final é outro riacho com bolas de neve. Cristais de gelo gigantes nas margens e peixes nadando debaixo do gelo |

### Copa Verão

| Pista            | Cenário | Destaques                                                                 |
|------------------|---------|---------------------------------------------------------------------------|
| Baía Ativos      | Praia   | 2,0 km, **praia de areia branca sem asfalto**, num meio-dia de sol (mar turquesa no raso e azul no fundo, ondinhas de espuma chegando na areia, brilho do sol na água, ilhas no horizonte). Largada numa **vila de quiosques de sapê** (portal de bambu com telhado de palha e a placa da Ativos, bandeirinhas, guarda-sóis listrados, espreguiçadeiras, pranchas de surfe, farol); a reta da praia leva a uma **passarela de tábuas** sobre a baía, entre **palafitas**, que vai subindo até a ponta do píer: dali a asa-delta voa sobre o **canal** (ilhotas de pedra com coqueiros, golfinhos) até a ilha. Na ilha, a **trilha da mata** de terra batida (cerca de madeira escura, murinhos de pedra com flores vermelhas, bananeiras, samambaias e árvores grandes) passa por baixo de um **arco de pedra** com cipós e coqueiros em cima; na volta, o **baixio**: a pista atravessa o mar raso entre linhas de boias, bancos de areia com coqueiros e estrelas-do-mar no fundo (com uma rampa de pulo no meio), e termina nas curvas das dunas, com um grampo, até a vila |
| Estádio Celerino | Cidade  | 1,8 km, **cidade neon à noite** (cyberpunk): céu estrelado com o brilho rosa da cidade no horizonte, asfalto molhado com as faixas acesas em ciano, zebras de neon, muretas de LED com tubos de neon, postes, **portais de neon** por cima da pista, **neblina** roxa nas ruas, no canal e rente ao asfalto, prédios com janelas acesas e **letreiros holográficos** da Ativos e do Celerino no kart, arranha-céus no horizonte e holofotes varrendo o céu. Largada num **estádio lotado** (torcida com bastões de luz e celulares, frisos de neon, telão de LED, boxes com as garagens acesas, pórtico de treliça com neon) com o **Celerino gigante** sob dois refletores coloridos. A pista sai por um **túnel** sob a arquibancada, sobe um **elevado** entre os prédios, salta de asa-delta sobre o **canal**, desce pelo outro elevado e volta pelo segundo túnel até a reta dos boxes |

Todas usam as logos da Ativos no pórtico, nas muretas, outdoors, bandeiras, balões, dirigível,
no asfalto e nas pontes (na Baía, nas placas de madeira penduradas nas cercas e nos quiosques).

## Estrutura

```text
scenes/
  main_menu.tscn         Tela inicial (piloto no kart parado no grid, câmera girando)
  mode_select.tscn       Modo de jogo, jogadores, cilindrada, dificuldade + "Quem vai jogar?"
  character_select.tscn  Seleção de piloto (grade de retratos + personagem 3D)
  kart_select.tscn       Seleção de kart (kart com o piloto girando + atributos)
  glider_select.tscn     Seleção de asa-delta (kart e piloto com a asa aberta girando)
  track_select.tscn      Seleção de pista (vista aérea ao fundo, copas, cartões, mapa e recordes)
  race.tscn              Corrida (carrega a pista escolhida + kart + câmera + HUD + pausa)
  kart.tscn              O kart (física, faíscas, turbo, som do motor)
  tracks/circuito_ativos.tscn   Circuito Ativos (campo)
  tracks/ilha_ativos.tscn       Ilha Ativos (praia)
  tracks/canion_ativos.tscn     Cânion Ativos (deserto)
  tracks/pico_nevado.tscn       Pico Nevado (neve)
  tracks/baia_ativos.tscn       Baía Ativos (praia de areia branca, Copa Verão)
  tracks/estadio_celerino.tscn  Estádio Celerino (estádio na cidade neon à noite, Copa Verão)
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
                        moedas, rodopio ao bater num obstáculo, marcas de pneu e poeira,
                        voo com a asa-delta (GLIDE_*)
  glider_data.gd        Recurso com os dados de cada asa-delta (nome, textura)
  glider_visual.gd      A asa-delta em cima do kart (abre/fecha, balança no ar, cordas
                        esticadas até a carroceria)
  glider_select.gd      Tela de seleção de asa-delta
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
  track_props.gd        Decorações de cada cenário (coqueiros, farol, veleiros,
                        tamareiras, chalés, bonecos de neve)
  track_egypt.gd        Monumentos do deserto: pirâmides, esfinges, obeliscos, templo com
                        colunata, ruínas, camelos (caravan.gd) e o portal de largada
  track_beach.gd        Pista de praia: cercas de corda e boias, portal de bambu, vila de
                        quiosques, palafitas, guarda-sóis, bandeirinhas, arco de pedra,
                        ilhotas, ilhas no horizonte e a mata da trilha (cerca, murinhos)
  track_stadium.gd      Estádio: anel de arquibancadas com a torcida pintada, cobertura,
                        túneis, torres de luz, telão, boxes, tendas, pódio, o Celerino
                        gigante e o pórtico de treliça da largada (à noite, com neon)
  track_city.gd         Cidade neon: prédios com janelas acesas, letreiros holográficos,
                        arranha-céus no horizonte, portais e tubos de neon, postes e
                        holofotes varrendo o céu
  track_bridge.gd       Recurso com os dados de uma ponte (trecho, altura, rampa, estilo)
  track_bridges.gd      Monta as pontes (tabuleiro, pilares, torre estaiada, arco, viaduto,
                        passarela de madeira)
  track_ramp.gd         Recurso com os dados de uma rampa de pulo ou de asa-delta (posição,
                        altura, ângulo, alcance do voo)
  track_ramps.gd        Monta as rampas de pulo (malha, colisão, turbo, paredes invisíveis)
  track_section.gd      Recurso de um trecho especial (submerso, dunas, gelo, vale, baixio,
                        trilha da mata)
  track_sections.gd     Monta o visual dos trechos especiais (fundo do mar/lago, dunas,
                        lago congelado, vale com cachoeira e os destaques de cada cenário)
  kart_water_fx.gd      Bolhas e respingo do kart na água
  cable_car.gd          Cabine do teleférico do Pico Nevado
  jump_ramp.gd          Colisão da rampa com a borda de onde o kart decola
  item_box.gd           Caixa de item (gira e flutua no shader, estoura e volta)
  track_coins.gd        Moedas Ativos da pista (MultiMesh, giro no shader, coleta por
                        distância, voltam depois de 12 s)
  track_obstacles.gd    Obstáculos que se mexem (pneus, ondas, tambores de coluna, bolas de neve): cada
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
  race_item.gd          Os itens (Deságio, Juridiquês, Cessão de crédito, RPV, Antecipação
                        Celer, Superpreferência, Correção monetária, Carimbo INDEFERIDO,
                        Intimação, PEC dos Precatórios, Impugnação dos cálculos, Pendência
                        documental, Fila do tribunal, Trânsito em julgado, Liminar): nomes,
                        cores e ícones
  race_items.gd         Itens na corrida: sorteio, item guardado de cada kart, uso e poderes
                        (com o trilho do ofício da Superpreferência)
  item_effects.gd       Efeitos 3D dos itens: raio, "−%" no céu, "§" de tinta, chuva de
                        moedas da Correção monetária, aura do Trânsito em julgado
  cessao_ghost.gd       Celerino-fantasma que assina o contrato da Cessão de crédito
  rpv_rocket.gd         Guia da RPV que enrola e vira foguete embaixo do kart
  antecipacao_celer.gd  Celerino voando com a maleta dourada que solta jatos de notas
  oficio_super.gd       Ofício gigante com o carimbo PRIORIDADE (Superpreferência)
  item_attacks.gd       Itens de Ataque em jogo: voo, ricochete nas muretas, perseguição pela
                        pista, a PEC até o líder, a calculadora e os acertos (marca
                        INDEFERIDO, "INTIMADO!", "PARCELA 2/6", aviso no HUD); as
                        armadilhas na pista e a onda da Liminar
  carimbo_indeferido.gd Carimbo de borracha voador e a marca INDEFERIDO atrás do kart
  intimacao_envelope.gd Envelope da Intimação com asinhas
  pec_constituicao.gd   Constituição gigante com asas (PEC dos Precatórios)
  impugnacao_calculadora.gd  Calculadora com visor, LED, anel de perigo e chuva de números
  pendencia_papelada.gd Pilha de papel com clipe da Pendência documental
  chuva_de_folhas.gd    Folhas voando de quem escorrega na pilha
  senha_tribunal.gd     Senha "AGUARDE SUA VEZ" na mão do piloto e o painel CHAMANDO
  transito_julgado.gd   Aura dourada e martelo de juiz girando (Trânsito em julgado)
  liminar_escudo.gd     Escudo LIMINAR DEFERIDA e a onda verde
  item_wings.gd         Par de asinhas de penas que batem (envelope e Constituição)
  racing_line.gd        Trajetória de corrida dos adversários (calculada a cada corrida)
  chase_camera.gd       Câmera que segue o kart (e se ajusta à faixa larga do 2 jogadores)
  ui/                   Interface: ui_kit.gd (cores, fontes, desenho), botões, faixas,
                        barras de atributos, retratos, pílulas do HUD (hud_pill.gd), slot do item com a roleta
                        (item_slot.gd), aviso de item vindo (item_alert.gd), tinta do Juridiquês (ink_overlay.gd), contrato da Cessão
                        (contract_card.gd), painel do modo dev (dev_panel.gd), semáforo, HUD, pausa,
                        posição na corrida (place_badge.gd), linhas da classificação,
                        tela dividida (split_screen.gd), cartões de modo, seletor de
                        opção, etiqueta do jogador, o painel "Quem vai jogar?" e a janela
                        de opções (options_panel.gd, volume_slider.gd, key_button.gd)
shaders/                Céu com nuvens (e halo de 22°), terreno, água (e gelo), asfalto, neve batida e
                        rio congelado, montes de neve, cristais de gelo, zebras, muretas com placas,
                        vegetação (com neve), pedra em blocos, painéis com logo, placas de curva,
                        turbos, rampas de pulo, caixas de item, moedas (com o "%" gravado no
                        verso), obstáculos, ondas, marcas de pneu, foguete da RPV, ofício da
                        Superpreferência e fundos da interface
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
data/personagens/henrique.tres       Dados do Henrique (+ henrique_esqueleto.tres)
data/personagens/ulysses.tres        Dados do Ulysses (+ ulysses_esqueleto.tres)
data/personagens/rafael.tres         Dados do Rafael (+ rafael_esqueleto.tres)
data/rivais/*.tres                   Adversários do computador (Celerino recolorido)
data/asas/*.tres                     Asas-deltas (Asa Rubra, Asa Ativos, Bandeirada, Pôr do Sol)
assets/models/asas/                  Asa-delta (asa_delta.glb) e a textura de cada asa,
                                     gerados por tools/asas/ (créditos em CREDITOS.txt)
data/pistas/*.tres                   Dados das pistas (nome, copa, descrição, dificuldade)
assets/pistas/                       Imagens da tela de pistas: vista aérea (fundo) e foto
                                     da largada (cartão), geradas por tools/track_shots/
assets/models/personagens/celerino.glb   Modelo do Celerino (veja RIG.md ao lado)
assets/models/personagens/jarbas.glb     Modelo do Jarbas (+ jarbas_atlas.png e
                                     jarbas_animacoes.res), gerados por tools/personagens/
assets/models/personagens/henrique.glb   Modelo do Henrique (+ henrique_atlas.png e
                                     henrique_animacoes.res), gerados por tools/personagens/
assets/models/personagens/ulysses.glb    Modelo do Ulysses (+ ulysses_atlas.png e
                                     ulysses_animacoes.res), gerados por tools/personagens/
assets/models/personagens/rafael.glb     Modelo do Rafael (+ rafael_atlas.png e
                                     rafael_animacoes.res), gerados por tools/personagens/
scenes/props/garrafa_cerveja.tscn    A long neck do gesto do Rafael (scripts/garrafa_cerveja.gd;
                                     rótulo de tools/personagens/build_garrafa.py)
assets/models/moeda/moeda.glb        Moeda Ativos (gerada por tools/moeda/build_moeda.py)
tools/karts/                         Gera bolido/cometa/motoca/bugre.glb e o
                                     standard_kart.glb (azul, com o "A" da Ativos) a
                                     partir dos modelos originais (troca os adesivos
                                     pelas logos da Ativos) e escala cada kart para os
                                     pilotos (encaixe_karts.py, veja "Encaixe piloto ×
                                     kart"). O Godot ignora a pasta tools/.
tools/personagens/                   Prepara o Jarbas, o Henrique, o Ulysses e o Rafael: limpa o
                                     modelo e junta as texturas num atlas
                                     (build_personagem.py), monta as animações
                                     (gerar_animacoes.gd) e confere o encaixe em cada
                                     veículo (poses_nos_karts.gd). Veja o README.md de lá.
tools/asas/                          Gera a asa-delta do jogo e as texturas das asas a partir
                                     do modelo original (build_asas.py) e traz a sonda que
                                     mede os voos (veja o README.md de lá)
tools/moeda/                         Gera a moeda do jogo a partir de original/MOEDA.glb
                                     (textura de 2048 → 512 px, sem os mapas de normal e
                                     rugosidade, malha centralizada: 2,4 MB → 198 KB; o
                                     "$" do verso vira um disco liso para o "%" do shader)
assets/textures/itens/               Guia da RPV, ofício, carimbo PRIORIDADE e nota de
                                     dinheiro, gerados por tools/itens/build_item_textures.py
assets/music/                        Músicas (.ogg em loop, geradas por tools/music/)
default_bus_layout.tres              Canais de áudio: Master, Musica e Efeitos
tools/music/build_music.mjs          Compõe e sintetiza as músicas (Node + ffmpeg)
tools/perf/                          Medição de desempenho da versão web (probe +
                                     Chrome headless, veja tools/perf/README.md)
tools/track_shots/                   Gera as imagens de assets/pistas/ (gerar.sh, veja o
                                     README.md de lá)
tools/pistas/                        Traçado (curva + conversão de frações), análise do
                                     traçado, sonda dos trechos especiais e fotos (veja o
                                     README.md de lá)
tools/gelo/gerar_ruido.gd            Gera assets/textures/ruido.png (ruído branco 256×256 dos
                                     shaders da pista de neve e gelo; veja
                                     shaders/noise_tex.gdshaderinc)
web/                                 Export para o navegador (veja web/README.md)
linux/                               Export do executável Linux (veja linux/README.md)
windows/                             Export do executável Windows (veja windows/README.md)
macos/                               Export do aplicativo macOS (veja macos/README.md)
```

## Os pilotos

São cinco pilotos jogáveis: o **Celerino** (folha de papel, mascote da Ativos), o
**Jarbas** (piloto de macacão e luva), o **Henrique** (de boné e barba), o **Ulysses**
(de topete e macacão preto) e o **Rafael** (de barba curta e sorrisão). Todos usam o mesmo `CharacterRig`; o que muda de um para o
outro (nomes dos ossos, animações extras, jeito de pilotar) fica no
`CharacterSkeleton` de cada um (`scripts/character_skeleton.gd`: os valores padrão são
os do Celerino; o do Jarbas é `data/personagens/jarbas_esqueleto.tres`).

**Ao ser escolhido** na seleção de personagem, cada um faz o seu gesto, com o corpo
inteiro: o Celerino toca guitarra invisível (e termina com o braço esticado fazendo
chifrinho), o Jarbas cruza os braços se achando, o Henrique aponta para quem está
escolhendo, o Ulysses arruma o cabelo e o Rafael tira uma long neck de trás das costas,
ergue a garrafa e grita "SEXTOUU!" (a boca fala, com um balão de quadrinho ao lado), e
termina num brinde para quem está escolhendo, com uma piscadela. A garrafa e o balão só
existem durante o gesto (`pick_prop`, `pick_shout` no `.tres`; `scripts/pick_extras.gd`)
e somem quando ele acaba ou é desfeito. Jogando sozinho, a tela espera o gesto acabar e
segue para os karts (A/Enter pula a espera, B/Esc desfaz a escolha); no multijogador a
tela espera o gesto de quem confirmou por último. O gesto e a expressão ficam em
`pick_gesture` e `pick_face` no `.tres` do personagem; as animações são geradas por
`tools/personagens/gestos_escolha.gd` (veja o README de lá).

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
- **Nas telas de seleção:** fica em pé, respira, pisca, acena e, ao ser escolhido, toca
  guitarra invisível (a única animação dele que não vem do `.glb`: está em
  `celerino_animacoes.res`, pelo `data/personagens/celerino_esqueleto.tres`).
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

- **No kart:** encaixe piloto × kart (veja abaixo): o modelo entra em escala 1, com a
  origem na origem do piloto do veículo, e a `POSE_Kart` do arquivo põe o quadril no banco
  e as mãos no aro — o kart é que foi escalado para isso dar certo. As mãos seguem o
  volante por IK (braços com cotovelo, pegada medida na `POSE_Kart`); nos veículos de
  volante mais baixo que o da referência o tronco inclina um pouco para alcançar, e nos de
  painel baixo as pernas esticam até o assoalho (`foot_point` do kart). Na moto a pose vem
  da `POSE_Moto`.
- **Expressões e piscada:** as do próprio modelo (alegria, surpresa, raiva, tristeza...).
  **Gestos, respiração, olhar e formatos de mão:** transferidos das animações do Celerino
  (`tools/personagens/gerar_animacoes.gd`).
- **Parado na seleção:** a `idle_stand` mexe o corpo todo (troca o peso de uma perna para
  a outra com os pés plantados, respira, olha em volta e solta os braços); a respiração
  do Celerino, que só mexe a coluna, deixava o Jarbas duro. Vale também para os retratos.
- **Uma malha só, com textura:** as 27 texturas da Tripo e os logos viram um atlas, e o
  `CharacterMesh` junta tudo numa superfície (`shaders/character_textured.gdshader`). No
  multijogador, o jogador que repete o Jarbas corre com o azul do macacão na cor dele.

O **Henrique** e o **Ulysses** seguem o mesmo caminho do Jarbas (encaixe com a
`POSE_Kart`, expressões próprias, gestos do Celerino, `idle_stand`, atlas numa
superfície). Os três vieram do Blender com esqueleto, poses e expressões, já nas
proporções finais. O **Rafael** também, com uma diferença: o rosto dele é feito de shape
keys (sorriso, piscada, sobrancelhas e os visemas da fala), não de ossos. O build separa o
rosto numa malha com os blend shapes, o `CharacterMesh` junta o corpo numa superfície e o
rosto noutra (só os ~5 mil vértices do rosto pagam a mistura dos blend shapes a cada
quadro) e as camadas de rosto e de piscada do `CharacterRig` mexem neles pelo nome. Os
quatro têm ossos auxiliares no quadril (o Ulysses e o Rafael também no meio do
cotovelo e do joelho) que giram metade do osso seguinte (no Blender é uma restrição; no
jogo, `follow_bones` no `CharacterSkeleton`), para a dobra não murchar. Detalhes e números
em `tools/personagens/README.md`.

### Encaixe piloto × kart (tamanho dos karts e dos pilotos)

Segue o documento "Encaixe Piloto × Kart" (medidas da cena Proporcoes_Finais do
kart-compare.blend):

- **Os pilotos nunca mudam de escala.** Jarbas, Henrique, Ulysses e Rafael entram em escala
  1 (os `.glb` já estão em metros: 1,03, 1,06, 1,03 e 1,03 m de altura) em todo veículo.
- **O veículo é que se ajusta:** cada kart foi escalado pela distância do assento (S, o
  vinco entre o fundo do banco e o encosto, na linha central) ao centro do volante (W),
  igual à do kart de referência (0,370 m: o Kart Padrão, com o modelo original na escala
  0,06). Quando o volante do veículo fica bem mais baixo ou mais alto que o da referência
  (as escalas pela horizontal e pela vertical diferem mais de 10%), vale a horizontal
  (alcance dos braços) e o IK das mãos cuida da altura. O tamanho de cada kart sai disso:
  o Padrão tem 1,13 m de comprimento; os outros, de 1,11 m (Bugre) a 1,67 m (Motoca).
- **Origem do piloto:** `KartData.driver_origin()` = assento − assento de referência; a pose
  sentada (`POSE_Kart`, ou `POSE_Moto` na moto) leva o corpo ao banco e as mãos ao volante.
  No Kart Padrão o resultado é o do documento: topo da cabeça a 0,836 / 0,872 / 0,839 m
  (Jarbas / Henrique / Ulysses), punho a 8,8 / 5,3 / 6,1 cm da pega, quadril 10 cm acima do
  assento. O Rafael tem a mesma `POSE_Kart` e as mesmas mãos do Ulysses: 0,836 m e 6,1 cm.
- `python3 tools/karts/encaixe_karts.py` imprime a conferência de cada kart (k, erro do
  volante, diâmetro da pega, inclinação do volante); com `--gravar`, escala um kart novo.
- As pistas e a física não mudaram: a câmera, as caixas de batida, as caixas de item, as
  moedas, os tiros e os efeitos, feitos para os karts de antes, usam as proporções de
  `scripts/kart_scale.gd` (itens e efeitos 0,55, câmera 0,75). Nas telas de seleção de kart
  e de asa o kart com o piloto aparece 1,6× maior (o conjunto inteiro, sem mudar a
  proporção). As fileiras de caixas de item têm 6 caixas, mais juntas, para continuarem
  pegando qualquer kart que passe.
- O Celerino e os adversários (o Celerino recolorido) ficaram com `kart_scale` 0,43, na mesma
  proporção dos pilotos novos.

### Ajustar o piloto no kart

- Onde os pilotos sentam: `seat_point` no `.tres` do kart (o vinco do banco); o Celerino
  e os adversários usam `seat_position`.
- Tamanho do kart: sai do encaixe (`tools/karts/encaixe_karts.py`); não mude
  `model_scale` à mão.
- Volante: `steering_wheel_center`, `steering_wheel_axis`, `steering_wheel_radius` e
  `hand_angle` (posição das mãos no aro) no `.tres` do kart.
- Pernas em veículo de painel baixo: `foot_point` no `.tres` do kart (onde fica o
  tornozelo direito; zero = as pernas da `POSE_Kart`).
- Pegada e inclinação para alcançar o volante: grupo "Pose de piloto" do
  `CharacterSkeleton` (Celerino: padrão em `character_skeleton.gd`; Jarbas:
  `jarbas_esqueleto.tres`).
- Tamanho do Celerino e dos adversários no kart: `kart_scale` no `.tres` deles.

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
6. **Gesto ao ser escolhido:** ponha em `pick_gesture` uma animação do esqueleto (corpo
   inteiro, termina na pose que fica parada) e em `pick_face` a expressão. Vazio = ele
   comemora com os braços para cima (`gesture_cheer`). Gestos novos: uma coreografia em
   `tools/personagens/gestos_escolha.gd`.

Ele aparece no lugar de um dos "?" da grade de seleção.

## Adicionar um kart novo

1. Coloque o modelo (`.glb`) em `assets/models/karts/`.
2. Duplique `data/karts/standard_kart.tres` e, no Inspetor, troque o **Model Scene**,
   o nome, a descrição e os atributos (1 a 5). Ajuste **Model Rotation** para a frente
   apontar para -Z; **Model Scale** pode ficar numa escala qualquer em que dê para medir
   (o tamanho final sai do passo 5).
3. (Opcional) Em **Rodas**, coloque os nomes das rodas para elas girarem. Podem ser nós
   do modelo ou ossos de um esqueleto (o Relâmpago usa ossos).
4. Em **Piloto e volante**, ajuste o banco e o volante. Se o volante for uma peça
   separada (nó ou osso), coloque o nome dela para ele girar; se fizer parte da
   carroceria (como no Kart de Treino), deixe vazio e as mãos ficam paradas nele.
5. **Encaixe:** meça o assento S (o vinco entre o fundo do banco e o encosto, na linha
   central; sem encosto, o ponto mais de trás do fundo) no espaço do kart, acrescente em
   `MEDIDAS` de `tools/karts/encaixe_karts.py` e rode
   `python3 tools/karts/encaixe_karts.py --gravar`: o script escala o modelo e todas as
   medidas do `.tres` (rodas, volante, escapamentos, caixa de batida...) para os pilotos
   caberem em escala 1 e grava o `seat_point`. Confira o piloto sentado com
   `tools/personagens/poses_nos_karts.gd`; se os joelhos atravessarem o painel, ponha um
   `foot_point`.
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

## Adicionar uma asa-delta nova

As asas são o mesmo modelo (`assets/models/asas/asa_delta.glb`) com texturas diferentes.
Todas planam igual — a escolha é só de estilo.

1. Em `tools/asas/build_asas.py`, acrescente um estilo em `ESTILOS`: as cores das faixas da
   borda da vela e do contorno, a função que pinta o desenho do meio da vela (recebe a
   posição na vela em `u`, `v`) e as cores da moldura, das amarrações/cordas e das tiras.
2. Rode `python3 tools/asas/build_asas.py <nome>` (precisa de Pillow): grava
   `assets/models/asas/<nome>.png`. Na importação, deixe os mipmaps ligados.
3. Duplique um `.tres` de `data/asas/`, troque o nome, a descrição, a textura e a cor de
   destaque (a bolinha da tela de seleção).
4. Acrescente o `.tres` na lista `gliders` em `scripts/game_state.gd`.

Ela aparece na tela de seleção e no sorteio das asas dos adversários.

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
- **Snow Track** (pista de neve e gelo, ligado no Pico Nevado): tira o asfalto, as zebras e
  as placas das muretas. A pista vira neve batida (`shaders/snow_road.gdshader`; o kart
  pisa `Kart.Surface.NEVE`, aderência ×0,72), as muretas viram barrancos de neve (só o
  visual: a colisão continua a da mureta) com blocos de gelo com a marca da Ativos, as
  zebras viram uma leira baixa de neve, e os trechos **GELO** viram rio congelado
  (`shaders/ice.gdshaderinc`, o mesmo gelo da água congelada) com cristais de gelo nas
  margens e um arco de gelo sobre cada riacho. O ruído desses shaders vem de uma textura
  (`assets/textures/ruido.png`, `shaders/noise_tex.gdshaderinc`): com ruído por hash, a
  pista custava até ~2,7 ms a mais por quadro na web (1080p, M4); com a textura, o mesmo
  que o asfalto.
- **Sand Track** (pista de areia, ligado no Cânion): igual ao Snow Track, com areia batida
  (`shaders/sand_road.gdshader`, `Kart.Surface.AREIA_BATIDA`, aderência ×0,84), montes de
  areia com blocos de arenito (`shaders/sand_bank.gdshader`) e a leira de areia; as dunas
  e o mergulho continuam como trechos especiais. Os hieróglifos são uma textura gerada
  (`assets/textures/hieroglifos.png`, `tools/deserto/gerar_hieroglifos.py`) usada também
  pelo arenito dos monumentos (`shaders/egypt_stone.gdshader`). **Dune Cover** transforma o
  chão em volta num mar de dunas (mais altas longe da pista); `mountain_start` /
  `mountain_end` afastam as montanhas do horizonte.
- **Beach Track** (pista de praia, ligado na Baía): areia branca de praia no lugar do
  asfalto (`shaders/beach_road.gdshader`, `Kart.Surface.AREIA_BATIDA`), sem zebras, cercas
  de corda com postes brancos no lugar das muretas (só o visual: a colisão continua a da
  mureta) com placas de madeira da Ativos, portal de bambu na largada, vila de quiosques,
  palafitas, arco de pedra, ilhotas e ilhas no horizonte (`scripts/track_beach.gd`). O
  chão perto da pista vira areia (`TrackTheme.beach_terrain_params`: faixa de areia molhada
  na beira e fundo turquesa debaixo d'água) e a água ganha cor pela profundidade de
  verdade, ondinhas de espuma na areia e brilho do sol (`TrackTheme.beach_water_params`,
  `vertical_foam` no `shaders/water.gdshader`). As cores foram acertadas na web
  (Compatibility usa as cores sem converter e o ACES desbota o claro): areia ~0,76/0,67/0,49.
- **Stadium Track** (estádio, ligado no Estádio Celerino): anel de arquibancadas em volta de
  `stadium_center` (retângulo arredondado de semieixos `stadium_radii`; o chão dentro dele
  fica plano), com a torcida pintada nos degraus (`shaders/stadium_crowd.gdshader`: nada de
  malha por pessoa), propaganda na mureta, cobertura com a marca, torres de luz, telão
  (`shaders/telao.gdshader`), boxes com torre de controle, tendas, pódio, o Celerino gigante
  (o modelo do jogo, ×6,5) e o pórtico de treliça com placar e luzes de largada
  (`scripts/track_stadium.gd`). Onde a pista cruza o anel as filas de baixo somem e ela
  passa num túnel por baixo das de cima. Sem árvores, moitas e outdoors dentro do anel.
- **City Track** (cidade neon à noite, ligado no Estádio Celerino): prédios em quadras fora
  da pista, do estádio e do canal (`shaders/city_building.gdshader`: janelas acesas
  desenhadas no shader, sem malha por janela), faixas de neon nos prédios
  (`shaders/neon.gdshader`, cor de vértice acesa para o glow), letreiros holográficos da
  Ativos e do Celerino no kart, arranha-céus no horizonte, portais de neon, postes e tubos
  de neon nas muretas e holofotes (`shaders/light_beam.gdshader`) e neblina baixa em três
  camadas — rasante por cima da pista, e nas ruas, no canal e no gramado do estádio
  (`shaders/city_mist.gdshader`, some perto da câmera, onde encosta nos prédios e nas
  beiradas; fica no grupo de detalhes) (`scripts/track_city.gd`). No `track.gd` ela deixa o
  asfalto molhado (`wet`) com as faixas acesas (`line_glow`), as zebras de neon (`glow` do
  curb), as muretas de LED (`glow` da mureta) e o chão e a água de concreto e canal
  (`TrackTheme.city_terrain_params`/`city_water_params`); as pontes viram elevado de
  concreto escuro com friso aceso, sem arco-íris na cachoeira. A névoa do WorldEnvironment é
  mais densa perto do chão (`fog_height`/`fog_height_density`; as fotos da tela de pistas a
  reduzem junto). O céu de noite usa `stars` e `city_glow` do `shaders/sky.gdshader` (tudo
  desligado nas outras pistas).
- **Paisagem:** além das alturas, `hill_bias` (colinas mais altas/baixas), `terrace_step`
  (colinas em degraus, como mesas de deserto) e `sea_distance` (a partir dessa distância da
  pista o chão desce para o mar — vira uma ilha), com `sea_depth` (profundidade do mar) e
  `land_spots` (círculos x, z, raio que continuam terra firme: o continente e o morro da
  ilha da Baía). Com `mountain_start` além da borda do terreno (~1250 m) o horizonte fica
  só mar.

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
  marca no alto), Viaduto (arcos de pedra com medalhões do logo) ou Passarela (píer de
  tábuas em cima de estacas com mãos-francesas e lampiões; o piso da pista vira tábuas —
  na Baía ela tem altura 0 e a subida até a ponta do píer vem da própria curva).

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

### Rampas de asa-delta

Uma rampa com **Glider** ligado (grupo "Asa-delta" do `TrackRamp`) vira rampa de asa-delta:
o kart decola sempre com a mesma subida (15 m/s, não importa a velocidade) e com pelo
menos 88% da velocidade máxima (`Kart.GLIDE_MIN_LAUNCH`), a asa abre 0,4 s depois e ele
desce a 2 m/s (0,8 m/s segurando o freio), na velocidade máxima dele; depois de 4,5 s
planando a asa "cansa" e desce cada vez mais rápido, então o voo sempre acaba. Em chão
plano são ~3,5 s e 80–140 m. Sobre um vale, passada a beira do outro lado, ela desce para
pousar (veja **Vale da asa-delta**). As
paredes invisíveis do voo têm 32 m de altura e vão até **Glide Distance** m depois da
borda. As rampas atuais usam 14 m de subida, 2,2 m de altura, 26° e **Full Width** (de
mureta a mureta).

Hoje todas ficam na beira de um vale (veja **Vale da asa-delta**). Sem vale, ponha a rampa
onde caibam uns 150 m de pista sem outro trecho passando por cima, sem rampa de pulo,
obstáculos ou caixas embaixo do voo — caixas e turbos ficam logo depois da aterrissagem.
Para conferir, rode a sonda de voos de `tools/asas/` ou a de trechos de `tools/pistas/`.

### Trechos especiais

No nó raiz, em **Trechos especiais**, acrescente itens (`TrackSection`). Cada um tem
**Start / End** (frações da volta) e **Ramp** (transição antes e depois) e um **Kind**:

- **SUBMERSO:** a pista desce até **Depth** m abaixo da água entre `start` e `end` (as
  rampas de `ramp` m ficam por fora) e o chão num raio de **Basin** m em volta vira o
  fundo do lago/mar. Ali o kart fica submerso (`Kart.water_level`, gravidade ×0,5,
  velocidade ×0,94), a câmera troca para um ambiente com névoa da cor da água
  (`TrackTheme.underwater_fog`) e o asfalto ganha algas e cáusticas. Ponha onde a pista
  já está perto da água e uns 70 m livres de outro trecho.
- **AREIA:** dunas — o asfalto vira areia batida que sobe **Dune Height** m a cada
  **Dune Length** m, sem zebras; o terreno em volta vira um mar de dunas. A faixa de
  `Track.SOFT_SAND_EDGE` m junto de cada borda é areia fofa (×0,78) e **Pits** são os
  redemoinhos de areia movediça (x = fração, y = lateral, z = raio; ×0,55 e puxam para o
  meio). Deixe ~6 m livres ao lado de cada redemoinho: o computador desvia por ali.
- **GELO:** rio congelado — com **Basin** > 0 é um lago congelado: a pista fica rente ao
  gelo (use **Depth** −0,06) e o chão em **Basin** m vira lago. Com **Basin** = 0 é um
  riacho congelado: a pista fica na altura dela e só o piso vira gelo (dá para pôr em
  descidas). No gelo a aderência cai para 24% (o kart desliza): evite curvas com menos
  de ~75 m de raio.
- **VALE:** veja abaixo.
- **RASO:** baixio de praia — a pista desce até **Depth** m (~0,2) abaixo da água e o chão
  em **Basin** m vira um banco de areia raso. O kart pisa `Kart.Surface.AGUA_RASA`
  (velocidade ×0,96, aceleração ×0,9, aderência ×0,9), nunca conta como submerso, joga água
  para trás (`KartWaterFx.spray`) e respinga ao entrar e sair. Na pista de praia as
  muretas viram linhas de boias, e o trecho ganha bancos de areia com coqueiros,
  estrelas-do-mar e gaivotas. Com **Depth** acima de ~0,22 o kart passaria a contar como
  submerso.
- **SELVA:** trilha da mata na pista de praia — o piso vira terra batida alaranjada
  (`Kart.Surface.TERRA`, aderência ×0,92), a cerca de corda vira cerca de madeira escura de
  duas traves, com murinhos de pedra cobertos de grama e flores atrás, e o chão em volta
  vira chão de mata (`TrackTerrain.jungle_strength` → `COLOR.a` do terreno) com árvores,
  coqueiros, bananeiras, samambaias e moitas floridas (`TrackBeach.build_jungle`).

### Vale da asa-delta

Um trecho **VALE** tira a pista entre `start` e `end`: as duas pontas viram a beira de um
penhasco (paredão de pedra com colisão) e no meio não há asfalto nem colisão. Ponha uma
rampa de asa-delta com **At** = `start` e **Full Width** ligado (a rampa ocupa até as
muretas). A linha do vale é um filho **Path3D** chamado "Vale" (o primeiro ponto é a
cabeceira, com a cachoeira; desenhe-a atravessando a pista no meio do vão). O terreno vira
um planalto em volta (**Valley Plateau** m de largura, na altura da beira mais alta) e uma
ravina de **Valley Width** m no alto, com o fundo plano de **Valley Bed** m em
**Valley Floor** (abaixo da água vira rio, mar ou gelo); os paredões são sempre de pedra.

Regras que funcionaram (sonda `tools/pistas/sonda_trechos.gd`): vão de ~95–100 m e a beira
do pouso 7–10 m mais baixa que a da decolagem; mesmo no 50cc o kart passa a beira do pouso
com folga. Passados `Race.LAND_AFTER_EDGE` m da beira do pouso, a corrida chama
`Kart.glide_land`: a asa desce até `GLIDE_LAND_SINK` (12 m/s) e o kart pousa ~5–20 m
depois da beira no 50cc e ~15–55 m no 150cc (o voo inteiro dura 3,5–6 s). Deixe uns 80 m
de pista quase reta depois da beira; `glide_distance` (~200–210 m) cobre o pouso. Quem cai no vale
(o kart fica 6 m abaixo da linha entre as bordas) volta para a pista 4 amostras depois do
vão. Os destaques de cada cenário (ponte pênsil, rochas no mar e golfinhos, arco de pedra e
torres, teleférico) e a cachoeira são montados sozinhos a partir da linha do vale.

### Caixas de item

No nó raiz, em **Caixas de item**: `item_rows` são as posições das fileiras (frações da
volta) e `item_boxes_per_row` quantas caixas cada fileira tem. Quando o kart pega uma caixa,
ele emite o sinal `item_box_collected`; os itens (sorteio, uso, computador) ficam em
`RaceItems` (veja **Itens**). O kart virado ofício (Superpreferência) não pega caixa.

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
vem do cenário (pneus gigantes quicando no Campo, ondas na Praia, tambores de coluna no Deserto, neve
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
  CC BY-SA 4.0 — o "standard kart" e os quatro últimos modificados (pintura azul e
  emblema "A" no primeiro; adesivos da Ativos nos outros). Veja
  `assets/models/karts/CREDITOS.txt`.
- Celerino: mascote da Ativos (`assets/models/personagens/`).
- Jarbas, Henrique, Ulysses e Rafael: pilotos da Ativos (`assets/models/personagens/*.glb`,
  preparados a partir de `tools/personagens/originais/*-piloto.glb`).
- Garrafa do Rafael: modelo e rótulo ("Sextou") originais, feitos por código
  (`scripts/garrafa_cerveja.gd`, `tools/personagens/build_garrafa.py`).
- Logos da Ativos (ícone "at" e marca "ativos"): `assets/logos/`.
- Fontes Lilita One e Nunito — SIL Open Font License (`assets/fonts/`).
- Músicas e efeitos sonoros: originais, gerados por código (`tools/music/`, `scripts/sfx.gd`).
