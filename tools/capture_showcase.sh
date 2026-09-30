#!/usr/bin/env bash
# Vídeo de novedades de la vida en el parque (docs/futuro/19): una escena por novedad, preparada con
# --stage (main.gd::stage_scene) para que ocurra delante de la cámara, sin HUD y rotulada. Graba con
# el Movie Maker de Godot (30 FPS fijos) y monta con ffmpeg; el sonido del juego (ambiente, palomas,
# grillos) va delante y la música del proyecto (assets/audio/musica_videos.mp3) suave debajo, con
# fundido de salida de 10 s.
#
#   ./tools/capture_showcase.sh [--only 1,3] [--res 1920x1080] [--out build/video/novedades.mp4]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT_FP:-$HOME/bin/godot-4-fp}"
RES="1920x1080"
OUT="$PROJECT_DIR/build/video/novedades_$(date +%Y%m%d_%H%M).mp4"
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
LEAD=2          # segundos iniciales que se descartan (carga; las escenas se preparan a los 0,7 s)
WORK="$(mktemp -d "${TMPDIR:-/tmp}/paparazzi-showcase.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$(dirname "$OUT")"
FONT="$(fc-match -f '%{file}' 'sans:bold')"
MUSIC="${MUSIC:-$PROJECT_DIR/assets/audio/musica_videos.mp3}"

# título | segundos | argumentos del juego (tras --)
SEQUENCES=(
	"Marcha suave: se cruzan y adelantan sin temblores|12|--time=day --angle=60 --pitch=-3 --focal=28 --advance=8 --pan=1 --af"
	"Bancos de dos plazas: se acercan, se sientan y charlan|17|--time=day --stage=banco --angle=125 --pitch=-7 --focal=40 --af"
	"Echar migas: las palomas acuden a sus pies|16|--time=day --stage=palomas --angle=125 --pitch=-12 --focal=40 --af"
	"Se cruzan, se saludan y se paran a charlar|12|--time=day --stage=charla --angle=80 --pitch=-8 --focal=35 --af"
	"Un corredor se para a estirar|12|--time=golden --stage=estirar --angle=100 --pitch=-4 --focal=40 --af"
	"Paseando al perro|12|--time=day --stage=perro --pitch=-12 --focal=24"
	"Palomas: picotean, se apartan y alzan el vuelo|12|--time=day --angle=80 --pitch=-14 --focal=70 --scare-at=7 --af"
	"Móvil, café, fotos, periódico: cada uno a lo suyo|12|--time=day --advance=40 --angle=200 --pitch=-4 --focal=35 --pan=2 --af"
	"La pradera: pícnic, un niño con su balón y paseantes|12|--time=golden --angle=112 --pitch=-1 --focal=60 --pan=1.5 --lens=2,1 --af"
	"El estanque: paseantes, otro perro y un niño mirando el agua|12|--time=day --angle=248 --pitch=-1 --focal=50 --pan=-1 --af"
	"De noche: el móvil ilumina las caras y cantan los grillos|14|--time=night --advance=60 --activity=movil --angle=120 --pitch=-3 --focal=40 --pan=1 --af"
)

list="$WORK/list.txt"
: > "$list"
index=0
for entry in "${SEQUENCES[@]}"; do
	index=$((index + 1))
	if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$index,"* ]]; then continue; fi
	title="${entry%%|*}"
	rest="${entry#*|}"
	length="${rest%%|*}"
	args="${rest#*|}"
	echo "=== [$index/${#SEQUENCES[@]}] $title"
	raw="$WORK/raw_$index.avi"
	frames=$(( (LEAD + length) * FPS ))
	# shellcheck disable=SC2086
	"$GODOT" --path "$PROJECT_DIR" --disable-vsync --rendering-method forward_plus --resolution "$RES" \
		--write-movie "$raw" --fixed-fps "$FPS" --quit-after "$frames" -- --hud=0 $args > "$WORK/log_$index.txt" 2>&1 || true
	if [ ! -s "$raw" ]; then
		echo "    sin vídeo (ver $WORK/log_$index.txt)"; tail -5 "$WORK/log_$index.txt"; continue
	fi
	clip="$WORK/clip_$index.mp4"
	safe_title="${title//:/\\:}"
	ffmpeg -loglevel error -y -ss "$LEAD" -t "$length" -i "$raw" \
		-vf "scale=${RES%x*}:${RES#*x}:flags=lanczos,drawbox=x=0:y=ih-90:w=iw:h=90:color=black@0.45:t=fill:enable='lt(t,4.5)',drawtext=fontfile=$FONT:text='$safe_title':x=40:y=h-62:fontsize=34:fontcolor=white:alpha='if(lt(t,3.5),1,max(0,4.5-t))',fade=t=in:st=0:d=0.4,fade=t=out:st=$((length - 1)).6:d=0.4" \
		-af "afade=t=in:st=0:d=0.4,afade=t=out:st=$((length - 1)).6:d=0.4" -c:a aac -b:a 192k -ar 48000 -ac 2 \
		-r "$FPS" -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p "$clip"
	echo "file '$clip'" >> "$list"
done
if [ ! -s "$list" ]; then echo "No se grabó ninguna secuencia."; exit 1; fi
joined="$WORK/joined.mp4"
ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" -c copy "$joined"
duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$joined")
if [ -s "$MUSIC" ]; then
	fade_start=$(awk -v d="$duration" 'BEGIN { printf "%.2f", (d > 10 ? d - 10 : 0) }')
	ffmpeg -loglevel error -y -i "$joined" -i "$MUSIC" -map 0:v -c:v copy \
		-filter_complex "[1:a]afade=t=in:st=0:d=1,afade=t=out:st=$fade_start:d=10,volume=0.35[m];[0:a]volume=1.8[g];[g][m]amix=inputs=2:duration=first:normalize=0[a]" \
		-map "[a]" -c:a aac -b:a 192k -movflags +faststart "$OUT"
else
	ffmpeg -loglevel error -y -i "$joined" -c copy -movflags +faststart "$OUT"
fi
echo "=== Vídeo: $OUT (${duration%.*} s, $(du -h "$OUT" | cut -f1))"
