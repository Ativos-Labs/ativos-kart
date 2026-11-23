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
