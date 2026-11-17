# Versão Windows (executável)

Gera o jogo como um `.exe` para Windows de 64 bits (x86_64). A pasta tem um
`.gdignore`, então o Godot não importa nada daqui nem põe estes arquivos dentro do jogo.

| Arquivo | Para que serve |
| --- | --- |
| `export.sh` | Exporta o jogo para `windows/dist/` |
| `dist/` | Saída do export (não vai para o git) |

O preset fica em `export_presets.cfg`, na raiz do projeto: **Windows**.

## 1. Exportar

```sh
windows/export.sh            # versão final
windows/export.sh --debug    # template debug (abre um console com os erros)
```

Sai em `windows/dist/`:

- `AtivosKart.exe`: o jogo inteiro num arquivo só (o `.pck` vai embutido);
- `AtivosKart-windows-x86_64.zip`: o mesmo arquivo compactado (é o que se manda para
  outra máquina).

Precisa do Godot **4.7.2** e dos templates de exportação **Windows** dessa versão
(`windows_release_x86_64.exe` e `windows_debug_x86_64.exe`, mais os `_console.exe`).
Nesta máquina eles já estão em
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Em outra: no
editor, *Editor → Gerenciar Templates de Exportação → Baixar e Instalar*.

## 2. Rodar no Windows

Descompacte o zip e dê dois cliques em `AtivosKart.exe`.

- Renderer **Forward+ (Vulkan/D3D12)**, como no editor; sem suporte, o Godot cai para
  OpenGL (o mesmo renderer da versão web).
- Para não dar pico de GPU no meio da corrida:
  - os shaders da corrida e da seleção de kart compilam atrás do fade de carregamento;
  - se a placa não segura ~55 fps (medido pelo tempo de GPU), o 3D baixa a resolução
    (até 60%, com upscale FSR) **uma vez só** e direto para a escala que cabe; essa
    escala fica guardada para aquela pista e entra já no carregamento da próxima
    corrida. Trocar a resolução realoca os buffers do 3D (medido: 30-150 ms), por isso
    ela nunca fica subindo e descendo durante a corrida.
- Recordes e fantasmas ficam em `%APPDATA%\Godot\app_userdata\Ativos Kart\`.
- Controles: teclado e controle (gamepad), como nas outras versões.
- O `.exe` não é assinado nem tem o ícone do jogo (trocar o ícone exige o `rcedit`, que
  não roda no Mac). Na primeira execução o SmartScreen pode avisar "editor desconhecido":
  *Mais informações → Executar assim mesmo*.
