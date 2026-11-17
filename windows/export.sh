#!/usr/bin/env bash
# Gera o executável do jogo para Windows (x86_64) em windows/dist/.
#
# Uso:  windows/export.sh            # versão final (release)
#       windows/export.sh --debug    # template debug (abre console com os erros)
#
# Sai um .exe só, windows/dist/AtivosKart.exe, com o jogo embutido (pck dentro do
# executável), mais um .zip para mandar para outra máquina.
#
# O Godot é procurado em $GODOT, depois no PATH (godot / godot4) e por fim no
# caminho padrão desta máquina. Precisa dos templates de exportação Windows da mesma
# versão do Godot (4.7.2) — veja windows/README.md.
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

DIST="windows/dist"
OUT="$DIST/AtivosKart.exe"
mkdir -p "$DIST"
rm -f "$DIST"/AtivosKart*

echo "Exportando \"Windows\" ($MODE) para $OUT ..."
# O export guarda os .tres/.tscn já convertidos para binário em .godot/exported e só
# refaz um deles quando o arquivo muda, não quando o script dele muda (assim um
# conserto em KartData não chegava ao jogo exportado). Limpa para converter tudo de novo.
rm -rf .godot/exported
"$GODOT" --headless --path . "$MODE" "Windows" "$OUT"

if [ ! -s "$OUT" ]; then
	echo "O export falhou (não gerou $OUT). Veja as mensagens acima." >&2
	exit 1
fi
# Pacote para mandar para outra máquina.
(cd "$DIST" && zip -q -9 AtivosKart-windows-x86_64.zip "$(basename "$OUT")")

echo
echo "Pronto:"
ls -lh "$DIST" | awk 'NR > 1 { printf "  %-34s %s\n", $9, $5 }'
echo
echo "No Windows: descompacte AtivosKart-windows-x86_64.zip e dê dois cliques em AtivosKart.exe"
