#!/usr/bin/env bash
# Gera as imagens da tela de pistas (assets/pistas/<id>_fundo.jpg e <id>_cartao.jpg):
# exporta uma build web de teste com o probe zz_track_shots.gd (o projeto volta igual
# logo depois), abre no Chrome headless (sem janela, sem som), tira os prints e
# converte. Rode de novo depois de mudar o traçado ou o cenário de uma pista.
#
# Uso: tools/track_shots/gerar.sh [pasta_temporaria]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || command -v godot4 || echo /Users/marcosbueno/Downloads/Godot.app/Contents/MacOS/Godot)}"
OUT="${1:-$(mktemp -d)}"
PORT="${PORT:-8072}"

PROBE="$HERE/zz_track_shots.gd" "$PROJ/tools/perf/export_probe.sh" "$OUT/build"
python3 -I "$PROJ/tools/perf/serve.py" "$OUT/build" "$PORT" &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 1
rm -f "$OUT"/shots.log*
SCRATCH="$OUT" node --experimental-websocket "$PROJ/tools/perf/run_chrome.mjs" \
	"http://127.0.0.1:$PORT/index.html?s=shots" "$OUT/shots.log" \
	--viewport=1920,1080 --size=1920,1200 --timeout=300
cat "$OUT/shots.log"
grep -q "PERF|DONE" "$OUT/shots.log" || { echo "o probe não terminou" >&2; exit 1; }
python3 -I "$HERE/make_images.py" "$OUT/shots.log" "$PROJ/assets/pistas"
# Importa as imagens novas (o .import de cada uma guarda a compressão).
perl -e 'alarm 300; exec @ARGV' "$GODOT" --headless --path "$PROJ" --import > /dev/null 2>&1 || true
