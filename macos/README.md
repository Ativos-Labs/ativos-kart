# Versão macOS (aplicativo)

Gera o jogo como um aplicativo para macOS, um binário universal que roda em Mac com
Apple Silicon (arm64) e em Mac Intel (x86_64). A pasta tem um `.gdignore`, então o
Godot não importa nada daqui nem põe estes arquivos dentro do jogo.

| Arquivo | Para que serve |
| --- | --- |
| `export.sh` | Exporta o jogo para `macos/dist/` |
| `dist/` | Saída do export (não vai para o git) |

O preset fica em `export_presets.cfg`, na raiz do projeto: **macOS**.

## 1. Exportar

```sh
macos/export.sh            # versão final
macos/export.sh --debug    # template debug (mostra erros no terminal)
```

Sai em `macos/dist/`:

- `AtivosKart-macos-universal.zip`: o `Ativos Kart.app` compactado (é o que se manda para
  outra máquina). O jogo vai dentro do `.app`, em `Contents/Resources/Ativos Kart.pck`.

Precisa do Godot **4.7.2** e do template de exportação **macOS** dessa versão (o arquivo
`macos.zip`). Nesta máquina ele já está em
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Em outra: no
editor, *Editor → Gerenciar Templates de Exportação → Baixar e Instalar*.

Para exportar para Apple Silicon o Godot exige as texturas também em ETC2/ASTC; por isso
o `project.godot` tem `textures/vram_compression/import_etc2_astc=true` (os presets de
Windows, Linux e web não incluem essas texturas, então o tamanho deles não muda).

## 2. Rodar no Mac

Descompacte o zip e dê dois cliques em `Ativos Kart.app`.

- Precisa do macOS 13 ou mais novo no Apple Silicon e do macOS 11 ou mais novo no Intel
  (mínimos do Godot 4.7, gravados no `Info.plist`).
- Renderer **Forward+ (Metal)**, como no editor.
- Recordes e fantasmas ficam em `~/Library/Application Support/Godot/app_userdata/Ativos Kart/`.
- Controles: teclado e controle (gamepad), como nas outras versões.
- O app tem assinatura **ad-hoc** (a assinatura embutida do Godot, `codesign/codesign=1`
  no preset, que funciona também quando o export roda no Linux do GitHub Actions): não há
  certificado de desenvolvedor Apple nem notarização. No Mac em que foi exportado ele abre direto; em outro Mac, depois de baixar
  da internet, o Gatekeeper bloqueia na primeira vez. Libere com botão direito →
  *Abrir* → *Abrir*, ou, no Terminal:

  ```sh
  xattr -dr com.apple.quarantine "Ativos Kart.app"
  ```
