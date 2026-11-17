#!/usr/bin/env bash
# Gera o jogo para macOS (Apple Silicon + Intel, binário universal) em macos/dist/.
#
# Uso:  macos/export.sh            # versão final (release)
#       macos/export.sh --debug    # template debug (mostra erros no terminal)
#
# Sai macos/dist/AtivosKart-macos-universal.zip, com o "Ativos Kart.app" dentro (o jogo
# vai embutido no .app). O app tem assinatura ad-hoc (não há certificado de
# desenvolvedor Apple), então em outro Mac o Gatekeeper pede confirmação — veja
# macos/README.md.
#
# O Godot é procurado em $GODOT, depois no PATH (godot / godot4) e por fim no
# caminho padrão desta máquina. Precisa do template de exportação macOS da mesma
# versão do Godot (4.7.2, arquivo macos.zip) — veja macos/README.md.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="--export-release"
for arg in "$@"; do
	case "$arg" in
		--debug) MODE="--export-debug" ;;
		*) echo "Opção desconhecida: $arg" >&2; exit 2 ;;
	esac
done

GODOT="${GODOT:-$(command -v godot || command -v godot4 || echo /Users/marcosbueno/Downloads/Godot.app/Contents/MacOS/Godot)}"
if [ ! -x "$GODOT" ]; then
	echo "Godot não encontrado. Defina GODOT=/caminho/do/Godot e rode de novo." >&2
	exit 1
fi

DIST="macos/dist"
# O Godot exporta para um zip com o .app dentro (o nome do .app vem do projeto).
OUT="$DIST/AtivosKart.zip"
PACKAGE="$DIST/AtivosKart-macos-universal.zip"
mkdir -p "$DIST"
rm -rf "$DIST"/AtivosKart*

echo "Exportando \"macOS\" ($MODE) para $OUT ..."
# O export guarda os .tres/.tscn já convertidos para binário em .godot/exported e só
# refaz um deles quando o arquivo muda, não quando o script dele muda (assim um
# conserto em KartData não chegava ao jogo exportado). Limpa para converter tudo de novo.
rm -rf .godot/exported
"$GODOT" --headless --path . "$MODE" "macOS" "$OUT"

if [ ! -s "$OUT" ]; then
	echo "O export falhou (não gerou $OUT). Veja as mensagens acima." >&2
	exit 1
fi
mv "$OUT" "$PACKAGE"

echo
echo "Pronto:"
ls -lh "$DIST" | awk 'NR > 1 { printf "  %-34s %s\n", $9, $5 }'
echo
echo "No Mac: descompacte AtivosKart-macos-universal.zip e abra \"Ativos Kart.app\""
echo "(em outro Mac: botão direito → Abrir, ou  xattr -dr com.apple.quarantine \"Ativos Kart.app\")"
