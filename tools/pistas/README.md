# Traçado e trechos especiais das pistas

Ferramentas usadas em 2026-11-23, quando as 4 pistas ganharam a volta nova com o vale da
asa-delta e os trechos especiais (mergulho, dunas, lago congelado). Nada daqui entra no
jogo (`.gdignore`).

| Arquivo | Para que serve |
| --- | --- |
| `tracado.py` | Gera o `Curve3D` de um traçado a partir de pontos de controle `(x, z, y[, 'flat'])` com alças estilo Catmull-Rom (`handles` + `data_string`), e converte frações da volta antiga para a nova (`remap`): para reaproveitar caixas, moedas, pontes e turbos depois de mudar a curva |
| `analise_tracado.gd` | Sonda headless: comprimento, raio mínimo, retas (≥ 40 m), trechos que passam a menos de 46 m um do outro, vãos dos vales e um PNG de cima com pontes, trechos especiais, rios e a linha do vale |
| `sonda_trechos.gd` | Sonda headless de corrida (J1 no piloto automático + 7 adversários): voos sobre o vale (tempo, distância, folga de altura na beira do pouso, quedas), tempo debaixo d'água, respingos, superfícies pisadas, pulinhos nas dunas, voltas e resgates |
| `fotos_trechos.gd` | Probe da build web de teste: fotografa cada vale (da rampa, do meio do voo, de lado, a cachoeira de perto) e cada trecho especial (de dentro e de cima) com a corrida montada |

## Uso

As sondas `.gd` rodam de `_probe/` (pasta ignorada pelo git). Sem som e sem janela:

```sh
G=/caminho/do/Godot
cp tools/pistas/analise_tracado.gd tools/pistas/sonda_trechos.gd _probe/
$G --headless --path . --audio-driver Dummy -s res://_probe/analise_tracado.gd -- out=/tmp/ak tracks=0,1,2,3
$G --headless --path . --audio-driver Dummy -s res://_probe/sonda_trechos.gd -- track=2 cls=0 secs=150
```

`cls` = 0 (50cc), 1 (100cc), 2 (150cc); `pull=1` faz o J1 segurar o freio no voo inteiro.
O pior caso do vão é o 50cc: confira a "folga mínima na beira do pouso". Quedas no vale
quase sempre são karts atingidos por item no meio do voo (a sonda imprime `GOLPE no voo`).

Fotos (build web de teste com o probe, Chrome headless, sem janela):

```sh
PROBE=tools/pistas/fotos_trechos.gd tools/perf/export_probe.sh /tmp/ak_fotos/build
python3 -I tools/perf/serve.py /tmp/ak_fotos/build 8073 &
node --experimental-websocket tools/perf/run_chrome.mjs \
    "http://127.0.0.1:8073/index.html?t=0,1,2,3" /tmp/ak_fotos/fotos.log --viewport=1600,900 --size=1600,1000
```

## Números de 2026-11-23

| Pista | Volta | Vão | Beiras (decolagem → pouso) | Pouso depois da beira (50cc / 150cc) |
| --- | --- | --- | --- | --- |
| Circuito | 1539 m | 100 m | 15 → 7 m | 12–18 m / 8–58 m |
| Ilha | 1333 m | 100 m | 16 → 8 m | 2–18 m / 18–34 m |
| Cânion | 1664 m | 94 m | 16 → 8,5 m | 6–22 m / 16–30 m |
| Pico | 1597 m | 98 m | 20 → 10 m | 8–22 m / 16–46 m |

O voo dura 3,5–6 s: passada a beira do pouso, a corrida faz a asa descer (`Kart.glide_land`).
Antes disso (primeira versão do mesmo dia) o voo seguia planando 6–9 s e pousava 100–200 m
depois da beira no 150cc — longe demais, o jogador passava do fim do trecho.

Voltas do J1 (piloto automático, habilidade 0,8): ~50 s no 100cc, ~40–48 s no 150cc, ~65–77 s
no 50cc. No 50cc a folga mínima na beira do pouso ficou em 0–2 m (com a decolagem mínima de
88% da velocidade máxima); sem ela, karts batidos antes da rampa caíam no vale. Quedas que
sobram são de itens no meio do voo (golpe, PEC no líder).

### Pico Nevado de neve e gelo (2026-11-23, mais tarde)

O Pico virou pista sem asfalto (`Track.snow_track`): neve batida (aderência ×0,72) e três
trechos de gelo (×0,24) — o lago (0,728–0,806) e dois riachos sem lago (`basin` = 0):
a descida 0,625–0,722 (raios de 75–150 m) e a reta final 0,885–0,952. Sonda de corrida,
A/B contra o asfalto antigo (mesma build, 200 s): J1 passa ~25% do tempo no gelo; voltas
+1–5% (mais no 50cc), nenhum resgate, nenhuma queda no vale. As curvas fechadas do platô
(raios de 33–45 m) ficaram de neve de propósito: gelo ali derrubaria a IA.

### Cânion do Egito (2026-11-23, mais tarde)

O Cânion virou deserto do Egito sem asfalto (`Track.sand_track`, aderência ×0,84) e
ganhou um laço de baixo maior (1664 → 2003 m): dunas 0,565–0,676, rampa de pulo em 0,699 e
o oásis numa depressão (o traçado desce até y −9; `SUBMERSO` 0,755–0,795, `ramp` 55 m,
`depth` 7, `basin` 78). Frações da parte de cima (largada até o viaduto) = antigas ×
1664,5/2003. Recordes do Cânion recomeçam (`GameState.TRACK_LAYOUT_OF`).
A sonda agora espera a corrida montar (a pista é gerada numa thread).

| Classe | Voltas do J1 | Voos (ar / pouso depois da beira / folga mínima) | Debaixo d'água | Resgates |
| --- | --- | --- | --- | --- |
| 50cc | 93–99 s | 4,9–6,3 s / 6–18 m / 1,1 m | ~6 s por volta | nenhum |
| 100cc | ~75 s (antes 58–63 s em 1664 m) | 3,8–5,6 s / 14–30 m / 4,4 m | ~4 s | nenhum |
| 150cc | 60–62 s | 3,3–4,2 s / 26–42 m / 7,5 m | ~5 s | nenhum |

Velocidade média do J1 no 100cc: 26,7 m/s (antes 27,9): a areia batida, a areia fofa das
dunas (o J1 passa ~4 s por volta nela) e o mergulho custam ~4%.

## Cuidados

- O terreno não tem colisão: quem passa da mureta ou cai no vale só para em `y < -20` (ou
  na regra do vale, 6 m abaixo da linha entre as bordas). Pistas com subidas, mergulho ou
  vale usam só a faixa de colisão da pista (o plano do chão em `y = 0` atrapalharia o
  mergulho e seguraria quem cai no vale).
- A névoa soma a cor dela em materiais aditivos (`blend_add`): os raios de sol debaixo
  d'água viravam placas claras até ganharem `fog_disabled`.
- Mudou o traçado? Regere as imagens da tela de pistas (`tools/track_shots/gerar.sh`).

### Baía Ativos (2026-11-24)

Pista nova de praia (Copa Verão), 2033 m, sem asfalto (`Track.beach_track`). Traçado feito
com `tracado.py` (pontos em `scenes/tracks/baia_ativos.tscn`), raio mínimo 29 m (o grampo
das dunas), nenhum trecho a menos de 60 m de outro. Passarela 0,172–0,290 (altura 0, a
subida até 10 m vem da curva), vão de 104 m da ponta do píer (y 10) até a ilha (y 1,0),
trilha da mata (`SELVA`) 0,37–0,565, baixio (`RASO`) 0,604–0,700 (`depth` 0,2, `basin` 64)
com uma rampa de pulo em 0,656.

| Classe | Voltas do J1 | Voos (ar / pouso depois da beira / folga mínima) | Quedas | Resgates |
| --- | --- | --- | --- | --- |
| 50cc | 86–94 s | 4,6–6,5 s / 2–22 m / 1,5 m (era 0 m com a beira do pouso em y 1,8) | 1 (golpe de item no voo) | 1 (a queda) |
| 100cc | ~71 s | 4,4–5,6 s / 18–28 m / 6,1 m | 0 | 0 |
| 150cc | 61–65 s | 3,8–5,5 s / 14–34 m / 5,4 m | 0 | 0 |

Por volta o J1 passa ~18 s nas tábuas, ~36–48 s na terra da trilha e ~18 s no baixio
(dois respingos: entrando e saindo). Web (Chrome headless, M4, 1 jogador): 101–110 fps
contra 111–112 no Cânion, ~700 draw calls, carga da corrida ~6 s.

### Estádio Celerino (2026-11-24)

Pista nova (Copa Verão), 1763 m, traçado original feito com `tracado.py` (pontos em
`scenes/tracks/estadio_celerino.tscn`): raio mínimo 40 m na análise (28 m pelo `tracado.py`,
na chicane do miolo), nenhum trecho a menos de 50 m de outro. Vão de 104 m sobre o lago
(beira y 15 → pouso y 7), rampa de pulo em 0,872. O estádio (`Track.stadium_track`) é um
anel em volta de (72, −63) com semieixos 106 × 160 m que a pista cruza duas vezes (túneis).

| Classe | Voltas do J1 | Voos (ar / pouso depois da beira / folga) | Quedas no lago | Resgates |
| --- | --- | --- | --- | --- |
| 50cc | ~82 s | 5,1 s / 18 m / 6,0 m (o 2º voo levou um item no ar) | 0 | 1 (o item) |
| 150cc | 58–65 s | 3,6 s / 42 m / 9,7 m (um voo lento depois de levar item na subida) | 0 | 1 |

Web (Chrome headless, 1 jogador, rodadas intercaladas com a Baía): 52–61 fps contra 51–69
na Baía (ruído do Chrome), 500–530 draw calls contra 570–740, 1,4–1,5 M triângulos contra
1,7 M; a maior travada da carga 1,6–1,7 s contra 2,4–2,5 s.

Mais tarde no mesmo dia a pista virou **cidade neon à noite** e a subida e a descida do parque
viraram elevado (`TrackBridge` PILARES, altura 0: 0,455–0,645 e 0,704–0,835) sobre a cidade,
com o vale virando canal (`valley_plateau` 0). Sonda de corrida: nenhuma queda e nenhum
resgate; folga mínima no pouso 2,3 m (50cc) e 6,5 m (150cc); voltas ~83 s (50cc) e 54–60 s
(150cc).
