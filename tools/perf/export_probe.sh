#!/usr/bin/env bash
# Exporta uma build web de TESTE com o probe de desempenho (zz_perf_probe.gd) e
# reverte o projeto na hora. O probe nunca fica no projeto nem na build normal.
#
# Uso: tools/perf/export_probe.sh <pasta_saida> [preset] [--debug]
#      (preset padrão: "Web"; a saída deve ficar fora do projeto)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || command -v godot4 || echo /Users/marcosbueno/Downloads/Godot.app/Contents/MacOS/Godot)}"
OUT="$1"
PRESET="${2:-Web}"
MODE="--export-release"
[ "${3:-}" = "--debug" ] && MODE="--export-debug"
GS="$PROJ/scripts/game_state.gd"
BAK="$(mktemp)"

cp "$GS" "$BAK"
cp "$HERE/zz_perf_probe.gd" "$PROJ/zz_perf_probe.gd"
# Gancho temporário: o GameState cria o probe se o arquivo existir.
python3 -I - "$GS" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
hook = ('\tif ResourceLoader.exists("res://zz_perf_probe.gd"):\n'
        '\t\tadd_child.call_deferred(load("res://zz_perf_probe.gd").new())\n\n\n')
marker = "func _notification(what: int) -> void:"
assert s.count(marker) == 1
s = s.replace(marker, hook + marker, 1)
open(p, "w", encoding="utf-8").write(s)
EOF

mkdir -p "$OUT"
rm -f "$OUT"/index.*
perl -e 'alarm 600; exec @ARGV' "$GODOT" --headless --path "$PROJ" "$MODE" "$PRESET" "$OUT/index.html" > "$OUT/export.log" 2>&1
STATUS=$?

# --- reverte ---
cp "$BAK" "$GS"
rm -f "$BAK" "$PROJ/zz_perf_probe.gd" "$PROJ/zz_perf_probe.gd.uid"
if [ -e "$PROJ/zz_perf_probe.gd" ]; then
	echo "ATENCAO: o probe ficou no projeto" >&2
else
	echo "projeto revertido"
fi
grep -iE "error" "$OUT/export.log" | head -20
echo "export status=$STATUS"
