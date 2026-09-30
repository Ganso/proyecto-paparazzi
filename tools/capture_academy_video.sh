#!/usr/bin/env bash
# Vídeo de la Academia de fotografía (docs/futuro/06): una visita por cada lección, con dos páginas
# de teoría, la demostración guiada completa y la práctica (--academy-tour). Movie Maker a 30 FPS
# fijos, montaje con ffmpeg, rótulo por lección y la música del proyecto
# (assets/audio/musica_videos.mp3) suave bajo el sonido del juego, con fundido de salida de 10 s.
#
#   ./tools/capture_academy_video.sh [--only 1,3] [--res 1920x1080] [--out build/video/academia.mp4]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT_FP:-$HOME/bin/godot-4-fp}"
RES="1920x1080"
OUT="$PROJECT_DIR/build/video/academia_$(date +%Y%m%d_%H%M).mp4"
ONLY=""
while [ $# -gt 0 ]; do
	case "$1" in
		--only) ONLY="$2"; shift 2 ;;
		--res) RES="$2"; shift 2 ;;
		--out) OUT="$2"; shift 2 ;;
		*) echo "Opción desconocida: $1"; exit 1 ;;
	esac
done
FPS=30
LEAD=1
PAGE=5          # segundos por página de teoría
PAGES=2
WORK="$(mktemp -d "${TMPDIR:-/tmp}/paparazzi-academia.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$(dirname "$OUT")"
FONT="$(fc-match -f '%{file}' 'sans:bold')"
MUSIC="${MUSIC:-$PROJECT_DIR/assets/audio/musica_videos.mp3}"
# lección | título | segundos totales (teoría + demostración + práctica)
LESSONS=(
	"1|Lección 1 · La exposición|42"
	"2|Lección 2 · La profundidad de campo|40"
	"3|Lección 3 · El movimiento|38"
	"4|Lección 4 · La composición|33"
	"5|Lección 5 · La focal y la perspectiva|36"
)
list="$WORK/list.txt"
: > "$list"
for entry in "${LESSONS[@]}"; do
	n="${entry%%|*}"
	rest="${entry#*|}"
	title="${rest%%|*}"
	length="${rest#*|}"
	if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$n,"* ]]; then continue; fi
	echo "=== $title"
	raw="$WORK/raw_$n.avi"
	frames=$(( (LEAD + length) * FPS ))
	"$GODOT" --path "$PROJECT_DIR" --disable-vsync --rendering-method forward_plus --resolution "$RES" \
		--write-movie "$raw" --fixed-fps "$FPS" --quit-after "$frames" -- --academy="$n":teoria --academy-tour="$PAGE":"$PAGES" > "$WORK/log_$n.txt" 2>&1 || true
	if [ ! -s "$raw" ]; then echo "    sin vídeo"; tail -5 "$WORK/log_$n.txt"; continue; fi
	clip="$WORK/clip_$n.mp4"
	ffmpeg -loglevel error -y -ss "$LEAD" -t "$length" -i "$raw" \
		-vf "scale=${RES%x*}:${RES#*x}:flags=lanczos,drawbox=x=0:y=ih/2-60:w=iw:h=120:color=black@0.55:t=fill:enable='lt(t,2.2)',drawtext=fontfile=$FONT:text='$title':x=(w-text_w)/2:y=h/2-22:fontsize=46:fontcolor=white:alpha='if(lt(t,1.6),1,max(0,2.2-t)/0.6)':enable='lt(t,2.2)',fade=t=in:st=0:d=0.4,fade=t=out:st=$((length - 1)).6:d=0.4" \
		-af "afade=t=in:st=0:d=0.4,afade=t=out:st=$((length - 1)).6:d=0.4" -c:a aac -b:a 192k -ar 48000 -ac 2 \
		-r "$FPS" -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p "$clip"
	echo "file '$clip'" >> "$list"
done
if [ ! -s "$list" ]; then echo "No se grabó ninguna lección."; exit 1; fi
joined="$WORK/joined.mp4"
ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" -c copy "$joined"
duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$joined")
if [ -s "$MUSIC" ]; then
	fade_start=$(awk -v d="$duration" 'BEGIN { printf "%.2f", (d > 10 ? d - 10 : 0) }')
	ffmpeg -loglevel error -y -i "$joined" -stream_loop -1 -i "$MUSIC" -map 0:v -c:v copy \
		-filter_complex "[1:a]afade=t=in:st=0:d=1,afade=t=out:st=$fade_start:d=10,volume=0.35[m];[0:a]volume=1.6[g];[g][m]amix=inputs=2:duration=first:normalize=0[a]" \
		-map "[a]" -c:a aac -b:a 192k -movflags +faststart "$OUT"
else
	ffmpeg -loglevel error -y -i "$joined" -c copy -movflags +faststart "$OUT"
fi
echo "=== Vídeo: $OUT (${duration%.*} s, $(du -h "$OUT" | cut -f1))"
