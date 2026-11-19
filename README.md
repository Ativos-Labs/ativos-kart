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
- **Rampas de asa-delta** (painel azul aceso com setas brancas e moldura amarela): o kart
  sobe alto, a **asa-delta abre** em cima dele (presa na carroceria por quatro cordas) e ele **plana** de 3 a 7 s, descendo
  devagar. No ar o direcional vira (o kart inclina como um avião) e **segurar o freio
  levanta o bico** — desce mais devagar, mas perde velocidade. Paredes invisíveis altas
  seguram o voo dentro da pista; ao tocar o chão a asa fecha. Também dá para fazer a
  manobra na decolagem (o turbo vem na aterrissagem). Há uma em cada pista, três delas
  saindo do alto de uma ponte, e moedas no ar pelo caminho (uma fileira de cada lado).
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
  (separados por cilindrada).

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
- Cada tela tem um HUD compacto (moedas, volta, posição e mapa; o tempo aparece na
  chegada) e uma etiqueta
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
piloto** → **Escolha seu kart** → **Escolha sua asa-delta** (cada uma uma vez para cada
jogador) → **Escolha a pista** (no Grand Prix, a copa) → Corrida → Resultado (classificação dos 8 karts, suas voltas; correr de novo,
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
| Circuito Ativos  | Campo   | Lagos, montanhas nevadas, "S" apertado no meio, rampa de asa-delta na reta antes da curva longa |
| Ilha Ativos      | Praia   | Ilha com lagoa no meio, ponte estaiada com o logo na torre, ponte sobre o mar, coqueiros, guarda-sóis, veleiros com o logo na vela, farol, ondas do mar invadindo a pista e rampa de asa-delta no alto da ponte estaiada (voa por baixo da torre, sobre o mar) |
| Cânion Ativos    | Deserto | Traçado em "8" com viaduto passando por cima da própria pista, ponte em arco azul e viaduto de pedra sobre o rio do cânion, arco de pedra sobre a pista, caixa-d'água, letreiro gigante da Ativos, fardos de feno rolando e rampa de asa-delta no alto do viaduto (8,5 m): o voo mais longo, ~6,5 s descendo pela diagonal do "8" |
| Pico Nevado      | Neve    | Subida até um platô, viaduto de pedra sobre o rio congelado, ponte estaiada, pinheiros nevados, chalés, bonecos de neve de cachecol azul, neve caindo, bolas de neve descendo o morro e rampa de asa-delta na ponte estaiada (no 150cc dá para cruzar a chegada voando) |

Todas usam as logos da Ativos no pórtico, nas muretas, outdoors, bandeiras, balões, dirigível,
no asfalto e nas pontes.

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
  track_props.gd        Decorações de cada cenário (coqueiros, farol, veleiros, cactos,
                        caixa-d'água, letreiro, arco de pedra, chalés, bonecos de neve)
  track_bridge.gd       Recurso com os dados de uma ponte (trecho, altura, rampa, estilo)
  track_bridges.gd      Monta as pontes (tabuleiro, pilares, torre estaiada, arco, viaduto)
  track_ramp.gd         Recurso com os dados de uma rampa de pulo ou de asa-delta (posição,
                        altura, ângulo, alcance do voo)
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
shaders/                Céu com nuvens, terreno, água (e gelo), asfalto, zebras, muretas com placas,
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
assets/models/moeda/moeda.glb        Moeda Ativos (gerada por tools/moeda/build_moeda.py)
tools/karts/                         Gera bolido/cometa/motoca/bugre.glb e o
                                     standard_kart.glb (azul, com o "A" da Ativos) a
                                     partir dos modelos originais (troca os adesivos
                                     pelas logos da Ativos). O Godot ignora a pasta tools/.
tools/personagens/                   Prepara o Jarbas, o Henrique e o Ulysses: monta o esqueleto do
                                     Henrique (rig_henrique.py, com o Blender), limpa o
                                     modelo e junta as texturas num atlas
                                     (build_personagem.py), monta as animações
                                     (gerar_animacoes.gd) e confere a pose em cada kart
                                     (poses_nos_karts.gd). Veja o README.md de lá.
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
web/                                 Export para o navegador (veja web/README.md)
linux/                               Export do executável Linux (veja linux/README.md)
windows/                             Export do executável Windows (veja windows/README.md)
macos/                               Export do aplicativo macOS (veja macos/README.md)
```

## Os pilotos

São quatro pilotos jogáveis: o **Celerino** (folha de papel, mascote da Ativos), o
**Jarbas** (piloto de macacão e luva), o **Henrique** (de boné e barba) e o **Ulysses**
(de topete e macacão preto). Todos usam o mesmo `CharacterRig`; o que muda de um para o
outro (nomes dos ossos, animações extras, jeito de pilotar) fica no
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

O **Henrique** e o **Ulysses** seguem o mesmo caminho do Jarbas (pose montada por kart,
expressões próprias, gestos do Celerino, `idle_stand`, atlas numa superfície). O Henrique
veio sem esqueleto: ganhou o do Jarbas, ajustado ao corpo dele. O Ulysses veio com
esqueleto e animações e tem ossos auxiliares no meio do cotovelo, do joelho e do quadril
que giram metade do osso seguinte (no Blender é uma restrição; no jogo,
`follow_bones` no `ulysses_esqueleto.tres`), para a dobra não murchar. Detalhes e
números em `tools/personagens/README.md`.

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

### Rampas de asa-delta

Uma rampa com **Glider** ligado (grupo "Asa-delta" do `TrackRamp`) vira rampa de asa-delta:
o kart decola sempre com a mesma subida (15 m/s, não importa a velocidade), a asa abre 0,4 s
depois e ele desce a 2 m/s (0,8 m/s segurando o freio), na velocidade máxima dele; depois de
4,5 s planando a asa "cansa" e desce cada vez mais rápido, então o voo sempre acaba. Em chão
plano são ~3,5 s e 80–140 m; saindo de uma ponte, mais (o chão fica mais longe). As paredes
invisíveis do voo têm 32 m de altura e vão até **Glide Distance** m depois da borda. As
rampas atuais usam 14 m de subida, 2,2 m de altura e 26°.

Ponha a rampa onde caibam uns 150 m (até ~220 m saindo de uma ponte alta) de pista sem
outro trecho passando por cima, sem rampa de pulo, obstáculos ou caixas embaixo do voo —
caixas e turbos ficam logo depois da aterrissagem. O alto de uma ponte é o melhor lugar: o
voo passa por cima do rio, do mar ou do vale. Para conferir, rode a sonda de voos de
`tools/asas/` (tempo no ar, distância, onde aterrissa, batidas na parede, quedas).

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
  CC BY-SA 4.0 — o "standard kart" e os quatro últimos modificados (pintura azul e
  emblema "A" no primeiro; adesivos da Ativos nos outros). Veja
  `assets/models/karts/CREDITOS.txt`.
- Celerino: mascote da Ativos (`assets/models/personagens/`).
- Jarbas, Henrique e Ulysses: pilotos da Ativos (`assets/models/personagens/*.glb`,
  preparados a partir de `tools/personagens/originais/*-piloto.glb`).
- Logos da Ativos (ícone "at" e marca "ativos"): `assets/logos/`.
- Fontes Lilita One e Nunito — SIL Open Font License (`assets/fonts/`).
- Músicas e efeitos sonoros: originais, gerados por código (`tools/music/`, `scripts/sfx.gd`).
