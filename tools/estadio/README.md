# Estádio Celerino (cidade neon)

| Arquivo | Para que serve |
| --- | --- |
| `fotos_estadio.gd` | Probe da build web de teste: fotografa a pista com a corrida montada — largada, reta, arquibancada de perto, boxes, curva 1, chicane, túneis (chegando, por dentro e por fora), cidade, subida do elevado, decolagem, voo, canal de lado, o Celerino gigante (da reta e de perto), o telão e duas vistas aéreas |

Fotos (build web de teste com o probe, Chrome headless, sem janela e sem som):

```sh
OUT=/tmp/ak_estadio
PROBE=tools/estadio/fotos_estadio.gd tools/perf/export_probe.sh $OUT/build
python3 -I tools/perf/serve.py $OUT/build 8073 &
node --experimental-websocket tools/perf/run_chrome.mjs \
    "http://127.0.0.1:8073/index.html?t=5" $OUT/fotos.log --viewport=1600,900 --size=1600,1000
```

`?t=` é o índice da pista em `GameState.tracks`; `&only=telao,tunel_saida` tira só essas fotos.

Cuidados (2026-11-24):

- O traçado é original (`tools/pistas/tracado.py`, pontos na cena); o estádio é um
  retângulo arredondado (`Track.stadium_center`/`stadium_radii`) que a pista cruza duas
  vezes no lado sul: ali `TrackStadium` tira as filas de baixo e faz o túnel. Mudou o
  anel ou o traçado? Confira que o anel não passa a menos de ~15 m da pista em outro lugar
  (vira túnel sem querer) e regere as imagens (`IDS=estadio_celerino tools/track_shots/gerar.sh`).
- A torcida é desenho no shader dos degraus (`shaders/stadium_crowd.gdshader`): de longe
  ela mistura com a cor média para não piscar.
- A luz que volta do gramado deixava o forro claro da cobertura verde: o forro é azul
  escuro (`ROOF_UNDER`). De cima, o azul da marca desbota na web: o telhado usa `ROOF_TOP`.
- Num anel curvo, uma viga curva na frente do túnel escondia as pontas do letreiro: a viga
  vai reta de uma ponta à outra do trecho, com o letreiro chapado nela.
- O Celerino gigante é um `CharacterRig` de verdade (`update_every` = 2) com um `Timer`
  que chama `play_pick_gesture`; no editor fica só o pedestal.

Cidade neon à noite (2026-11-24, mais tarde; `Track.city_track`):

- A noite é toda do ambiente: céu quase preto com estrelas e o brilho rosa da cidade
  (`stars`, `city_glow`), lua azulada fraca com sombra, luz ambiente roxa (cor + céu) e glow
  em modo screen com limiar 0,95 — o neon é cor de vértice acesa acima de 1
  (`shaders/neon.gdshader`), por isso brilha sem luz de verdade. As únicas luzes reais são os
  dois refletores do Celerino.
- O asfalto molhado reflete o céu: com `wet` 1 e rugosidade 0,06 as poças viravam espelho e
  manchas; ficou `wet` 0,75 e rugosidade mínima 0,16.
- A torcida escurecida 55% sumia: à noite ela escurece só 25% e ganha bastões de luz e
  celulares. Os letreiros (Label3D) ficam sem sombreamento (acesos).
- A face de fora das muretas acesas brilhava lilás embaixo do elevado: ela fica escura.
- A cachoeira do canal tinha arco-íris (de dia): sem arco-íris com `city_track`.
- Web (rodadas intercaladas com a Baía): 153–157 fps contra 116–124, 430–575 draw calls
  contra 540–590, carga ~0,8 s. Os prédios ficam em blocos de 320 m (poucas chamadas).

Neblina (2026-11-24, mais tarde):

- Névoa do ambiente mais densa (`fog_density` 0,0038) e bem mais densa perto do chão
  (`fog_height` 7, `fog_height_density` 0,09): as ruas somem na névoa e o elevado e as torres
  saem acima dela. O `zz_track_shots.gd` reduz também a de altura (`FOG_SCALE`).
- Bancos de neblina (`shaders/city_mist.gdshader`, `TrackCity._build_mist`): três camadas
  (0,45 m por cima de tudo, inclusive da pista; 1,8 m e 4,5 m fora das muretas), placas de
  24 m que seguem o chão pelos cantos e somem nas beiradas (`COLOR.a`), perto da câmera e
  onde encostam em algo (profundidade da cena, com a conversão do Compatibility). Com a altura
  por célula apareciam degraus e bordas retas no canal.
- Web, rodadas intercaladas com a Baía: 138–167 fps contra 106–108.
