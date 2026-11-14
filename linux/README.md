# Versão Linux (executável)

Gera o jogo como um executável para Linux de 64 bits (x86_64). A pasta tem um
`.gdignore`, então o Godot não importa nada daqui nem põe estes arquivos dentro do jogo.

| Arquivo | Para que serve |
| --- | --- |
| `export.sh` | Exporta o jogo para `linux/dist/` |
| `dist/` | Saída do export (não vai para o git) |

O preset fica em `export_presets.cfg`, na raiz do projeto: **Linux**.

## 1. Exportar

```sh
linux/export.sh            # versão final
linux/export.sh --debug    # template debug (mostra erros no terminal)
```

Sai em `linux/dist/`:

- `AtivosKart.x86_64`: o jogo inteiro num arquivo só (o `.pck` vai embutido);
- `AtivosKart-linux-x86_64.tar.gz`: o mesmo arquivo compactado, com a permissão de
  execução guardada (é o que se manda para outra máquina).

Precisa do Godot **4.7.2** e dos templates de exportação **Linux** dessa versão
(`linux_release.x86_64` e `linux_debug.x86_64`). Nesta máquina eles já estão em
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Em outra: no
editor, *Editor → Gerenciar Templates de Exportação → Baixar e Instalar*.

## 2. Rodar no Linux

```sh
tar xzf AtivosKart-linux-x86_64.tar.gz
./AtivosKart.x86_64
```

- Renderer **Forward+ (Vulkan)**, como no editor. Se a placa de vídeo não tiver Vulkan,
  o Godot cai sozinho para OpenGL (o mesmo renderer da versão web).
- Recordes e fantasmas ficam em `~/.local/share/godot/app_userdata/Ativos Kart/`.
- Controles: teclado e controle (gamepad), como nas outras versões.
- O executável não é assinado. Se o sistema reclamar de permissão, rode
  `chmod +x AtivosKart.x86_64`.
