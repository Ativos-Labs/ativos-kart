# Medição de desempenho da versão web

Kit usado na otimização de 2026-11-14. Mede o jogo de verdade no navegador (Chrome
headless, sem janela e sem som), sem deixar nada no projeto: o probe só entra numa build
de teste e o `game_state.gd` volta igual logo depois do export.

| Arquivo | Para que serve |
| --- | --- |
| `zz_perf_probe.gd` | Probe: percorre menu, seleção de pistas, as 4 pistas, 2 e 4 jogadores; mede fps, percentis do quadro, draw calls, triângulos, travadas > 80 ms e o custo de cada script (chama os `_process` de cada um e cronometra) |
| `export_probe.sh` | Exporta a build de teste com o probe e reverte o projeto |
| `serve.py` | Servidor com COOP/COEP para a build de teste |
| `run_chrome.mjs` | Abre a build no Chrome headless (CDP), grava as linhas `PERF|` e tira prints quando o probe pede |
| `report.py` | Resume um ou mais logs em tabela |
| `pck_list.py` | Lista o que ocupa espaço dentro de um `.pck` |

## Uso

```sh
OUT=/tmp/ak_perf                      # fora do projeto
tools/perf/export_probe.sh $OUT/build
python3 -I tools/perf/serve.py $OUT/build 8071 &
node --experimental-websocket tools/perf/run_chrome.mjs \
    "http://127.0.0.1:8071/index.html?s=quick" $OUT/quick.log
python3 -I tools/perf/report.py $OUT/quick.log
```

Cenários (`?s=`): `quick` (menu, pistas, 1/2/4 jogadores + custo por script), `full`
(+ A/B de cada recurso gráfico com o jogo pausado), `live` (A/B com a corrida andando),
`dpr` (o que pesa em tela de alta densidade), `shots` (prints para comparar), `info`.

Opções do `run_chrome.mjs`: `--cpu=4` (CPU 4× mais lenta, como um notebook simples),
`--dpr=2 --size=1440,900` (tela Retina), `--vsync` (com o limite de 60 fps).

Cuidados:

- O Chrome headless varia até 2× de uma rodada para outra. Compare builds
  **intercalando** as rodadas (antes, depois, antes, depois).
- Corridas do probe podem gravar recordes no armazenamento do Chrome de teste (perfil
  temporário, apagado no fim), nunca nos recordes do jogo instalado.
- Depois de criar scripts com `class_name`, rode `Godot --headless --path . --import`
  antes de exportar.
