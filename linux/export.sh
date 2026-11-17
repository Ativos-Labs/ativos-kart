#!/usr/bin/env bash
# Gera o executável do jogo para Linux (x86_64) em linux/dist/.
#
# Uso:  linux/export.sh            # versão final (release)
#       linux/export.sh --debug    # template debug (mostra erros no terminal)
#
# Sai um arquivo só, linux/dist/AtivosKart.x86_64, com o jogo embutido (pck dentro
# do executável). No Linux: chmod +x AtivosKart.x86_64 && ./AtivosKart.x86_64
#
# O Godot é procurado em $GODOT, depois no PATH (godot / godot4) e por fim no
# caminho padrão desta máquina. Precisa dos templates de exportação Linux da mesma
# versão do Godot (4.7.2) — veja linux/README.md.
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

DIST="linux/dist"
OUT="$DIST/AtivosKart.x86_64"
mkdir -p "$DIST"
rm -f "$DIST"/AtivosKart.*

echo "Exportando \"Linux\" ($MODE) para $OUT ..."
# O export guarda os .tres/.tscn já convertidos para binário em .godot/exported e só
# refaz um deles quando o arquivo muda, não quando o script dele muda (assim um
# conserto em KartData não chegava ao jogo exportado). Limpa para converter tudo de novo.
rm -rf .godot/exported
"$GODOT" --headless --path . "$MODE" "Linux" "$OUT"

if [ ! -s "$OUT" ]; then
	echo "O export falhou (não gerou $OUT). Veja as mensagens acima." >&2
	exit 1
fi
chmod +x "$OUT"
# Pacote para mandar para outra máquina (o tar mantém a permissão de execução).
tar -C "$DIST" -czf "$DIST/AtivosKart-linux-x86_64.tar.gz" "$(basename "$OUT")"

echo
echo "Pronto:"
ls -lh "$DIST" | awk 'NR > 1 { printf "  %-34s %s\n", $9, $5 }'
echo
echo "No Linux:  tar xzf AtivosKart-linux-x86_64.tar.gz && ./AtivosKart.x86_64"
