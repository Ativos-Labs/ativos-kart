# Deserto do Egito (Cânion Ativos)

Ferramentas da pista de areia com o oásis (2026-11-23). Nada daqui entra no jogo
(`.gdignore`).

| Arquivo | Para que serve |
| --- | --- |
| `gerar_hieroglifos.py` | Gera `assets/textures/hieroglifos.png` (16 símbolos simples numa grade 4×4; R = desenho, G = linhas das colunas de escrita, B = número do símbolo). Precisa do Pillow. Importe sem compressão e com mipmaps |
| `fotos_egito.gd` | Probe da build web de teste: fotografa largada, dunas, descida e fundo do oásis, templo, esfinge, pirâmides, viaduto, vale e a vista de cima (`?v=nome1,nome2` escolhe as vistas) |

## Fotos

```sh
PROBE=tools/deserto/fotos_egito.gd tools/perf/export_probe.sh /tmp/ak_egito/build
python3 -I tools/perf/serve.py /tmp/ak_egito/build 8073 &
node --experimental-websocket tools/perf/run_chrome.mjs \
    "http://127.0.0.1:8073/index.html?t=2" /tmp/ak_egito/fotos.log --viewport=1280,720 --size=1280,800
```

## Onde fica cada coisa

- Pista de areia: `Track.sand_track` (`shaders/sand_road.gdshader`, montes de areia e leira
  em `shaders/sand_bank.gdshader`), `Kart.Surface.AREIA_BATIDA`.
- Mar de dunas em volta: `Track.dune_cover` (`TrackTerrain._dune_relief` cresce longe da
  pista); montanhas do horizonte afastadas com `mountain_start`/`mountain_end`.
- Monumentos: `scripts/track_egypt.gd` (posições achadas pelo traçado: a pirâmide do meio no
  maior vazio dentro dele, o grupo do horizonte onde a pista mais aponta, o templo na reta
  mais reta entre 0,82 e 0,98 da volta). Arenito com hieróglifos: `shaders/egypt_stone.gdshader`
  + `shaders/glyphs.gdshaderinc`.
- Oásis: `TrackSectionBuilder._build_oasis` (trecho SUBMERSO no cenário DESERTO); a grama
  verde da margem é a faixa `grass_band` do `shaders/terrain.gdshader`.
