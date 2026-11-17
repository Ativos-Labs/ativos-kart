#!/usr/bin/env bash
# Exporta o jogo para a web em web/dist/, pronto para `vercel deploy`.
#
# Uso:  web/export.sh                 # versão final, com threads (padrão)
#       web/export.sh --sem-threads   # sem threads (para hosts sem COOP/COEP)
#       web/export.sh --debug         # template debug (erros no console do navegador)
#
# O Godot é procurado em $GODOT, depois no PATH (godot / godot4) e por fim no
# caminho padrão desta máquina.
set -euo pipefail
cd "$(dirname "$0")/.."

PRESET="Web"
MODE="--export-release"
for arg in "$@"; do
	case "$arg" in
		--sem-threads) PRESET="Web (sem threads)" ;;
		--debug) MODE="--export-debug" ;;
		*) echo "Opção desconhecida: $arg" >&2; exit 2 ;;
	esac
done

GODOT="${GODOT:-$(command -v godot || command -v godot4 || echo /Users/marcosbueno/Downloads/Godot.app/Contents/MacOS/Godot)}"
if [ ! -x "$GODOT" ]; then
	echo "Godot não encontrado. Defina GODOT=/caminho/do/Godot e rode de novo." >&2
	exit 1
fi

DIST="web/dist"
mkdir -p "$DIST"
# Apaga só os arquivos do export anterior; mantém a pasta .vercel/ (o vínculo
# com o projeto na Vercel, criado no primeiro `vercel deploy`).
find "$DIST" -maxdepth 1 -type f -delete

echo "Exportando \"$PRESET\" ($MODE) para $DIST ..."
# O export guarda os .tres/.tscn já convertidos para binário em .godot/exported e só
# refaz um deles quando o arquivo muda, não quando o script dele muda (assim um
# conserto em KartData não chegava ao jogo exportado). Limpa para converter tudo de novo.
rm -rf .godot/exported
"$GODOT" --headless --path . "$MODE" "$PRESET" "$DIST/index.html"

if [ ! -f "$DIST/index.wasm" ] || [ ! -f "$DIST/index.pck" ]; then
	echo "O export falhou (faltam index.wasm/index.pck). Veja as mensagens acima." >&2
	exit 1
fi
cp web/vercel.json "$DIST/vercel.json"

echo
echo "Pronto: $DIST"
ls -lh "$DIST" | awk 'NR > 1 { printf "  %-28s %s\n", $9, $5 }'
echo
echo "Testar local:  python3 web/serve.py   (abre em http://localhost:8060)"
echo "Publicar:      cd $DIST && vercel deploy --prod"
