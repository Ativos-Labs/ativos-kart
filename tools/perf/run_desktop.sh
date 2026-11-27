#!/bin/bash
# Roda um probe do desktop (Forward+, Vulkan para ter tempo de GPU) numa janela pequena,
# sem som, guardando e devolvendo as opções e os recordes do jogo instalado.
# Durante a rodada vale um opcoes.cfg de teste: janela 320×180, volume zero e gráficos
# em Alta (ou sem nada salvo, como na primeira vez, com AUTO=1).
#
#   tools/perf/run_desktop.sh <probe.gd> <log> [timeout_s] [args do probe...]
#   ex.: tools/perf/run_desktop.sh zz_gpu_ab.gd /tmp/gpu.log 1500 tracks=0,2 views=2
#
# O probe precisa estar em _probe/ (o Godot não enxerga tools/, que tem .gdignore).
set -u
if [ "$(uname)" = "Darwin" ]; then
	GODOT=${GODOT:-/Users/marcosbueno/Downloads/Godot.app/Contents/MacOS/Godot}
	UD="$HOME/Library/Application Support/Godot/app_userdata/Ativos Kart"
else
	GODOT=${GODOT:-godot}
	UD="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Ativos Kart"
fi
PROBE=$1
LOG=$2
TO=${3:-900}
shift 3 || shift $#
B=$(mktemp -d)
cp "$UD/opcoes.cfg" "$B/opcoes.cfg" 2>/dev/null
cp "$UD/recordes.cfg" "$B/recordes.cfg" 2>/dev/null
restore() {
	if [ -f "$B/opcoes.cfg" ]; then cp "$B/opcoes.cfg" "$UD/opcoes.cfg"; else rm -f "$UD/opcoes.cfg"; fi
	if [ -f "$B/recordes.cfg" ]; then cp "$B/recordes.cfg" "$UD/recordes.cfg"; fi
	rm -rf "$B"
}
trap restore EXIT
mkdir -p "$UD"
if [ "${AUTO:-0}" = "1" ]; then
	GFX=""
else
	GFX='\n[graficos]\n\nmostrar_fps=false\ncenario=1\nsombras=2\nefeitos=2\nantisserrilhado=3\nresolucao_3d=0.0\n'
fi
printf "[audio]\n\nMaster=0.0\nEfeitos=0.0\nMusica=0.0\n\n[tela]\n\ntela_cheia=false\nresolucao=\"320x180\"\n$GFX" > "$UD/opcoes.cfg"
cd "$(dirname "$0")/../.."
perl -e "alarm $TO; exec @ARGV" "$GODOT" --rendering-driver vulkan --audio-driver Dummy \
	--resolution 320x180 --path . -s "res://_probe/$PROBE" -- "$@" > "$LOG" 2>&1
