# Medição de desempenho da versão web

Kit usado na otimização de 2026-11-14. Mede o jogo de verdade no navegador (Chrome
headless, sem janela e sem som), sem deixar nada no projeto: o probe só entra numa build
de teste e o `game_state.gd` volta igual logo depois do export.

| Arquivo | Para que serve |
| --- | --- |
| `zz_perf_probe.gd` | Probe: percorre menu, seleção de pistas, as 4 pistas, 2 e 4 jogadores; mede fps, percentis do quadro, draw calls, triângulos, travadas > 80 ms, tempo de carga de cada tela (`LOAD|`) e o custo de cada script (chama os `_process` de cada um e cronometra) |
| `export_probe.sh` | Exporta a build de teste com o probe e reverte o projeto |
| `serve.py` | Servidor com COOP/COEP para a build de teste |
| `run_chrome.mjs` | Abre a build no Chrome headless (CDP), grava as linhas `PERF|` e tira prints quando o probe pede |
| `report.py` | Resume um ou mais logs em tabela |
| `pck_list.py` | Lista o que ocupa espaço dentro de um `.pck` |
| `cpu_native.gd` | Probe nativo (headless): carga da corrida, custo por script e de cada parte do passo de física do kart (veja abaixo) |

## Uso

```sh
OUT=/tmp/ak_perf                      # fora do projeto
tools/perf/export_probe.sh $OUT/build
python3 -I tools/perf/serve.py $OUT/build 8071 &
node --experimental-websocket tools/perf/run_chrome.mjs \
    "http://127.0.0.1:8071/index.html?s=quick" $OUT/quick.log
python3 -I tools/perf/report.py $OUT/quick.log
```

Cenários (`?s=`): `quick` (menu, pistas, 1/2/4 jogadores + custo por script, e a
última pista carregada de novo, como "Reiniciar"), `full` (+ A/B de cada recurso gráfico
com o jogo pausado), `live` (A/B com a corrida andando), `cpuab` (A/B de CPU com a
corrida andando: sons 3D dos motores parados, pilotos congelados, motor sintetizado
desligado; mostra o quadro e o tempo do passo de física), `dpr` (o que pesa em tela de
alta densidade), `shots` (prints para comparar), `info`.

Opções do `run_chrome.mjs`: `--cpu=4` (CPU 4× mais lenta, como um notebook simples),
`--dpr=2 --size=1440,900` (tela Retina), `--vsync` (com o limite de 60 fps),
`--viewport=1920,1080` (área da página com tamanho exato, para prints). Depois de cada
print ele grava `window.__shot_saved` na página, para o probe poder esperar.

`PROBE=<arquivo.gd> tools/perf/export_probe.sh ...` exporta com outro probe (o de
`tools/track_shots/` usa isso).

Cuidados:

- O Chrome headless varia até 2× de uma rodada para outra. Compare builds
  **intercalando** as rodadas (antes, depois, antes, depois).
- Corridas do probe podem gravar recordes no armazenamento do Chrome de teste (perfil
  temporário, apagado no fim), nunca nos recordes do jogo instalado.
- Depois de criar scripts com `class_name`, rode `Godot --headless --path . --import`
  antes de exportar.
- Com CPU lenta (`--cpu=4`) o passo de física pode passar de 16,7 ms e o Godot roda
  vários passos por quadro para alcançar o tempo (até 8): o custo "por quadro" dos
  scripts de física sobe junto. Divida por passos (`frames=… ticks=…` na linha
  `TOTAL scripts`) para comparar.
- Para medir só uma mudança com outras sessões mexendo no projeto ao mesmo tempo, faça
  uma cópia do projeto (`rsync`, sem `.git`, `linux/dist`, `windows/dist`, `web/dist`),
  desfaça a mudança na cópia e exporte as duas: a única diferença entre as builds é ela.

## CPU no desktop, sem navegador

`cpu_native.gd` roda a corrida headless (sem janela, sem som) e imprime:
`LOAD|` (carga da corrida), `LIVE|` (custo por script, por passo de física e por quadro,
e o passo inteiro), `KARTPROF|` (com `patch=1`: por kart e por passo, IA, `move_and_slide`,
muros/marcas, visual e resto), `BENCH|` (funções isoladas) e `VOICES|` (quantos motores
3D tocam). Copie para `_probe/` e rode

```sh
Godot --headless --audio-driver Dummy --path . -s res://_probe/cpu_native.gd -- track=0 patch=1
```

Medido assim em 2026-11-17 (M4): o passo de física de uma corrida 1P custa ~1–2 ms, dos
quais ~1 ms é o kart.gd (IA ~30 µs, `move_and_slide` ~30–40 µs e visual ~15–25 µs por
kart) e ~0,4–0,7 ms é o motor (Jolt, interpolação, áreas). No headless os sons 3D não
custam nada mensurável, mas no navegador custam: com `cpuab` e `--cpu=4`, 7 motores
3D tocando custavam 3–4,4 ms por quadro (1P); com o limite de 3 vozes
(`Race._update_engine_voices`) sobram 0,2–0,5 ms. Para comparar duas versões
de um script, rode cada uma num processo separado (o estado de uma rodada vaza para a
seguinte no mesmo processo) e, para quatérnios, compare `min(|a-b|, |a+b|)`, não
`1-|a·b|` (os dos ossos não são unitários e essa conta nunca dá zero).

## Picos no meio da corrida (desktop, Forward+)

`zz_spikes_desktop.gd` mede cada quadro de corridas reais (J1 no piloto automático):
intervalo, process/physics, GPU, compilações de pipeline
(`Performance.PIPELINE_COMPILATIONS_*`), memória de vídeo e os eventos do jogo naquele
quadro (turbo, drift, moedas, caixas, batidas, troca de resolução, volta). Precisa de
janela (GPU de verdade): copie para `_probe/` e rode

```sh
Godot --path . --rendering-driver vulkan --audio-driver Dummy --resolution 1920x1080 \
    -s res://_probe/zz_spikes_desktop.gd -- tracks=0,1,2,3 secs=45 [warm=0] [scaletest=1]
```

`warm=0` troca a cena sem o warm_up (como era antes); `scaletest=1` força trocas de
resolução para medir o custo delas. Confira `undrawn=0` no resumo: o macOS para de
desenhar janelas cobertas e aí os tempos não valem. No Vulkan do Mac (MoltenVK) o tempo
de GPU inclui esperas, use mais o intervalo do quadro.

