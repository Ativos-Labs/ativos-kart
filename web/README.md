# Versão web (navegador) e publicação na Vercel

Tudo o que é preciso para gerar a versão do jogo que roda no navegador e publicá-la
na Vercel. A pasta tem um `.gdignore`, então o Godot não importa nada daqui nem põe
estes arquivos dentro do jogo.

| Arquivo | Para que serve |
| --- | --- |
| `export.sh` | Exporta o jogo para `web/dist/` e copia o `vercel.json` para lá |
| `serve.py` | Servidor local para testar o export antes de publicar (mesmos cabeçalhos da Vercel) |
| `vercel.json` | Cabeçalhos COOP/COEP que a versão com threads exige |
| `shell.html` | Página do jogo: tela de carregamento com o logo, a barra e os textos em português |
| `dist/` | Saída do export (não vai para o git; é a pasta que sobe para a Vercel) |

Os presets ficam em `export_presets.cfg`, na raiz do projeto: **Web** (padrão, com
threads) e **Web (sem threads)**.

## 1. Exportar

```sh
web/export.sh                 # versão final, com threads
web/export.sh --sem-threads   # só para hosts que não deixam configurar cabeçalhos
web/export.sh --debug         # template debug (mais mensagens no console do navegador)
```

Precisa do Godot **4.7.2** e dos templates de exportação **Web** dessa versão. Nesta
máquina eles já estão instalados (só os da Web) em
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Em outra máquina:
no editor, *Editor → Gerenciar Templates de Exportação → Baixar e Instalar*.

O script acha o Godot em `$GODOT`, no `PATH` (`godot`/`godot4`) ou no caminho padrão
desta máquina. Ele apaga só os arquivos do export anterior e mantém `dist/.vercel/` (o
vínculo com o projeto na Vercel).

## 2. Testar no navegador

```sh
python3 web/serve.py          # http://localhost:8060
```

Abra no Chrome, Edge, Firefox ou Safari atualizados. Abrir o `index.html` direto do
disco não funciona: precisa ser servido por HTTP.

## 3. Publicar na Vercel

Na primeira vez, instale a CLI e entre na sua conta:

```sh
npm i -g vercel
vercel login
```

Depois, a cada versão nova:

```sh
web/export.sh
cd web/dist && vercel deploy --prod
```

No primeiro deploy a CLI pergunta em qual projeto publicar (pode criar um novo; não há
build: são só arquivos estáticos). O `vercel.json` vai junto e configura os cabeçalhos.

Também dá para não fazer nada disso à mão: uma tag `v*` enviada ao GitHub (ou o "Run
workflow" da aba *Actions*) exporta e publica pela workflow `.github/workflows/release.yml`.
Ela usa os segredos `VERCEL_TOKEN`, `VERCEL_ORG_ID` e `VERCEL_PROJECT_ID`; veja "Publicação
automática" no `README.md` da raiz.

Depois de publicar, vale conferir duas coisas no DevTools (aba *Network*):

- `index.wasm` e `index.pck` com `Content-Encoding: br` ou `gzip` (comprimidos, o
  download cai de ~46 MB para ~13 MB com gzip, um pouco menos com brotli);
- no console, `crossOriginIsolated` deve dar `true`.

O plano gratuito (Hobby) é só para uso pessoal e não comercial; para uso da empresa,
o certo é o plano Pro.

## O que muda na versão web

- **Renderer Compatibility (WebGL 2).** É o único que o Godot usa na web, e o projeto
  já cai nele sozinho (`rendering_method.web`). Sem SSAO (o sombreado de contato nos
  cantos); o resto (glow, neblina, sombras, água, céu) funciona igual.
- **Sombras do sol com 2 divisões até 140 m** (no desktop: 4 até 190 m), em
  `Race._tune_shadows`. Cada divisão redesenha tudo o que faz sombra; na tela a
  diferença quase não aparece.
- **Resolução do 3D** (`scripts/render_scale.gd`): o 3D usa no máximo 1920×1080 pixels
  e é esticado, enquanto a interface fica na resolução cheia. Em telas Retina (ou no
  Windows com escala de 150%) o navegador pede o canvas em pixels físicos (2880×1626
  numa janela de 1440×813). Se o jogo não segurar ~55 fps, a resolução do 3D desce
  sozinha, aos poucos, até 60%. Se descer não ajudar (o limite é a CPU), ela volta e
  para de mexer. Cada tela nova começa da resolução cheia.
- **Shaders compilados no carregamento:** o WebGL compila cada shader na primeira vez
  que ele aparece, e isso travava a corrida de 0,1 a 1,5 s (pontes, rampas, fogo do
  turbo...). Agora, atrás do "Carregando…", a câmera passa pela pista e os efeitos
  ficam ligados por alguns quadros (`Race.warm_up`). A seleção de karts mostra todos
  os karts por um quadro (`kart_select.gd`).
- **Carregamento:** `shell.html` mostra o logo do jogo e a barra de progresso. Depois
  do download, o fundo azul-marinho do boot splash (`boot_splash/*.web` no
  `project.godot`) troca para o menu sem mostrar o logo do Godot.
- **"Carregando…"** aparece durante o fade das trocas de tela (`GameState.goto_scene`),
  porque gerar a pista na web leva alguns segundos na primeira vez.
- **Pausa automática:** trocar de aba ou clicar fora do jogo abre o menu de pausa da
  corrida (`PauseMenu._notification`).
- **Som do motor:** o `EngineAudio` toca pelo mixer do Godot (`PLAYBACK_TYPE_STREAM`),
  porque o modo "sample" da web não aceita o som gerado em tempo real.
- **Recordes:** o `user://recordes.cfg` fica no armazenamento do navegador (IndexedDB),
  separado por site. Em janela anônima ele some ao fechar.
- **Sem botão "Sair"** no menu (no navegador não há o que fechar).
- **Controles:** teclado e controle (gamepad) funcionam. Não há controles de toque,
  então no celular não dá para jogar.

## Desempenho medido (MacBook M4, Chrome, 1280×720)

Medido em 2026-11-14 com o kit de `tools/perf/` (Chrome headless sem o limite de 60 fps,
média de duas rodadas intercaladas; "CPU 4×" simula um notebook simples).

| Cena | Antes | Depois | CPU 4×: antes → depois |
| --- | --- | --- | --- |
| Corrida, 1 jogador (4 pistas) | 70–79 fps | 115–127 fps | 34–43 → 54–62 fps |
| Corrida, 2 jogadores | 66 fps | 92 fps | 34 → 46 fps |
| Corrida, 4 jogadores | 48 fps | 68 fps | 27 → 29 fps |
| Travadas na largada/corrida (1ª visita) | 5–19, até 218 ms | nenhuma | 38 → 5 (até 125 ms) |

- O que mais pesava: cada uma das 35 superfícies do Celerino deformada pela GPU a cada
  quadro (8 pilotos + retrato do HUD), as sombras em 4 divisões e a compilação de
  shaders no meio da corrida. Draw calls da corrida: ~1.400–1.900 → ~590.
- **Primeira visita:** a compilação dos shaders agora acontece atrás do "Carregando…":
  cada corrida leva ~0,3 s a mais para carregar na primeira vez. Nas visitas seguintes o
  Chrome guarda os shaders.
- **Tela Retina (DPR 2):** sem o teto de resolução o menu levava 15 ms por quadro só
  no 3D; com ele, 10 ms. Na tela dividida, 2 jogadores 36 → 47 fps e 4 jogadores
  31 → 44 fps.
- Com a CPU lenta o limite passa a ser a física e a IA dos 8 karts (~4 ms por quadro
  com CPU 4×) e o 4 jogadores fica perto de 30 fps.
- **Com threads**, as outras pistas são geradas em segundo plano e trocar de pista na
  seleção não trava. **Sem threads**, essa geração trava a tela 0,6–1,2 s por pista e
  a corrida leva ~1,2 s para carregar. Por isso o padrão é com threads.
