# Pista de praia (Baía Ativos)

| Arquivo | Para que serve |
| --- | --- |
| `fotos_baia.gd` | Probe da build web de teste: fotografa a Baía com a corrida montada — largada, vila, praia, passarela (de dentro e de lado), decolagem, voo, entrada da mata, mata, arco de pedra, baixio (de dentro, na rampa e de cima), grampo, dunas e uma vista aérea |

Fotos (build web de teste com o probe, Chrome headless, sem janela e sem som):

```sh
OUT=/tmp/ak_baia
PROBE=tools/praia/fotos_baia.gd tools/perf/export_probe.sh $OUT/build
python3 -I tools/perf/serve.py $OUT/build 8073 &
node --experimental-websocket tools/perf/run_chrome.mjs \
    "http://127.0.0.1:8073/index.html?t=4" $OUT/fotos.log --viewport=1600,900 --size=1600,1000
```

`?t=` é o índice da pista em `GameState.tracks`; `&only=arco,baixio` tira só essas fotos.

Cuidados (2026-11-24):

- As cores foram acertadas olhando a web (Compatibility): lá as cores dos materiais
  entram sem conversão e o tonemap ACES desbota o que é claro. Areia "branca" com albedo
  ~0,95 virava branco puro; ~0,76/0,67/0,49 sai creme. No desktop (Forward+) fica um pouco
  mais escuro.
- A espuma da água usava a distância até o fundo ao longo da vista: com a pista 20 cm
  debaixo d'água, o raso ficava branco perto da câmera. Na praia (`vertical_foam`) ela usa a
  profundidade na vertical.
- O anel de montanhas do horizonte fazia a baía parecer um lago: na Baía `mountain_start`
  fica além da borda do terreno e as ilhas do horizonte são malhas (`TrackBeach._build_far_islands`).
- O arco de pedra com bolas empilhadas parecia algodão: virou um tubo com ruído 3D, e a
  rocha (`shaders/beach_rock.gdshader`) usa projeção nos três planos (a projeção pelo lado
  da face fazia listras verticais).
- O "§" em cima dos karts nas fotos é o efeito do item Juridiquês mostrado no warm-up da
  corrida, não da pista.
