#!/usr/bin/env bash
# Vídeo de un pase completo por la Academia: cada lección de principio a fin (todas las páginas
# de teoría, la demostración, la práctica hecha tarea a tarea y el examen), jugada por el propio
# juego (scripts/academy_player.gd, -- --academy-play=). Una grabación por lección con el Movie
# Maker de Godot y un MP4 por lección más el montaje completo, en build/video/academia/.
#
#   ./tools/capture_academy.sh [--only 3,6] [--page 3.5] [--res 1280x720]
#
# Tarda unos 25 min. No usa los ajustes gráficos del jugador ni toca su progreso.
set -uo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_FP:-$HOME/bin/godot-4-fp}"
OUT_DIR="$PROJECT_DIR/build/video/academia"
ONLY=""; PAGE="3.5"; RES="1280x720"
while [ $# -gt 0 ]; do
	case "$1" in
		--only) ONLY="$2"; shift 2 ;;
		--page) PAGE="$2"; shift 2 ;;
		--res) RES="$2"; shift 2 ;;
		*) echo "Opción desconocida: $1"; exit 1 ;;
	esac
done
WORK="$(mktemp -d "${TMPDIR:-/tmp}/paparazzi-academia.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT_DIR"
export PAPARAZZI_GFX_CFG="$WORK/graficos.cfg"
export PAPARAZZI_ACADEMY_CFG="$WORK/academia.cfg"
export PAPARAZZI_BADGES_CFG="$WORK/insignias.cfg"
export PAPARAZZI_ALBUM_DIR="$WORK/album"
for n in $(seq 1 10); do
	if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$n,"* ]]; then continue; fi
	raw="$WORK/leccion_$n.avi"
	echo "=== Lección $n"
	"$GODOT" --path "$PROJECT_DIR" --disable-vsync --rendering-method forward_plus --resolution "$RES" \
		--write-movie "$raw" --fixed-fps 30 --quit-after 18000 -- "--academy-play=$PAGE:$n-$n" > "$WORK/log_$n.txt" 2>&1
	grep "ACADEMY PLAY" "$WORK/log_$n.txt" || echo "    (sin resultado: ver el registro)"
	if [ ! -s "$raw" ]; then echo "    sin vídeo"; tail -5 "$WORK/log_$n.txt"; continue; fi
	ffmpeg -loglevel error -y -i "$raw" -vf "scale=${RES%x*}:${RES#*x}:flags=lanczos" -r 30 -c:v libx264 -preset medium -crf 27 -pix_fmt yuv420p \
		-c:a aac -b:a 96k -movflags +faststart "$OUT_DIR/leccion_$(printf %02d "$n").mp4"
	rm -f "$raw"
	echo "    $(du -h "$OUT_DIR/leccion_$(printf %02d "$n").mp4" | cut -f1)"
done
if [ -z "$ONLY" ]; then
	list="$WORK/list.txt"; : > "$list"
	for f in "$OUT_DIR"/leccion_*.mp4; do echo "file '$f'" >> "$list"; done
	ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" -c copy -movflags +faststart "$OUT_DIR/academia_completa.mp4"
	echo "=== $OUT_DIR/academia_completa.mp4 ($(du -h "$OUT_DIR/academia_completa.mp4" | cut -f1))"
fi
