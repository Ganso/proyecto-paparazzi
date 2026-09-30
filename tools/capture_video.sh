#!/usr/bin/env bash
# Vídeo de evidencias (bajo demanda, para cambios grandes): graba varias secuencias de 15 s del
# juego en distintas condiciones con el Movie Maker de Godot (--write-movie, fotogramas fijos a
# 30 FPS, sin depender de la velocidad del equipo) y las monta con ffmpeg en un MP4 rotulado.
#
#   ./tools/capture_video.sh [--only 1,3] [--res 1920x1080] [--out build/video/evidencias.mp4]
#
# Necesita un Godot con Vulkan (GODOT_FP o ~/bin/godot-4-fp) y ffmpeg con libx264. El MP4 va a
# build/video/ (ignorado por git). Cada secuencia tarda de 1 a 3 min en grabarse. La última usa la
# telemétrica con enfoque manual (anillo de 1,2 m al sujeto con la imagen partida), mide la luz del
# sujeto, dispara y muestra el revelado. Tres secuencias enseñan la vida del parque (bancos,
# palomas, perro, figurantes y móviles de noche). Lleva de fondo la música del proyecto
# (assets/audio/musica_videos.mp3, o la variable MUSIC) con fundido de salida de 10 s, mezclada
# sobre el sonido del juego (ambiente y clic del obturador).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT_FP:-$HOME/bin/godot-4-fp}"
RES="1920x1080"
OUT="$PROJECT_DIR/build/video/evidencias_$(date +%Y%m%d_%H%M).mp4"
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
LEAD=4          # segundos iniciales que se descartan (carga y reposo de los muelles)
LENGTH=15
WORK="$(mktemp -d "${TMPDIR:-/tmp}/paparazzi-video.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$(dirname "$OUT")"
FONT="$(fc-match -f '%{file}' 'sans:bold')"
MUSIC="${MUSIC:-$PROJECT_DIR/assets/audio/musica_videos.mp3}"

# título | argumentos del juego (tras --)
SEQUENCES=(
	"Día · gran angular 24 mm, paneo|--time=day --lens=0,0 --angle=100 --pitch=2 --focal=24 --pan=6 --af"
	"Día · teleobjetivo 150 mm siguiendo a un viandante|--time=day --lens=2,1 --angle=40 --focal=150 --follow --af"
	"Hora dorada · 35 mm, paneo hacia el estanque|--time=golden --lens=0,0 --angle=200 --pitch=3 --focal=35 --pan=4 --af"
	"Noche · 24 mm, farolas y quiosco iluminado|--time=night --lens=0,0 --angle=90 --pitch=4 --focal=24 --pan=5 --af"
	"Vida en el parque · bancos, palomas y perro|--time=day --lens=0,0 --angle=118 --pitch=-7 --focal=35 --pan=1.2 --advance=75 --af"
	"Pradera · figurantes junto al quiosco, 70 mm|--time=golden --lens=2,1 --angle=108 --pitch=-1 --focal=70 --pan=1.5 --advance=20 --af"
	"Noche · el móvil ilumina las caras|--time=night --lens=0,0 --angle=120 --pitch=-3 --focal=40 --pan=1 --advance=60 --activity=movil --af"
	"Telemétrica 90 mm · enfoque manual, disparo y revelado|--time=day --lens=1,2 --focal=90 --follow-target --mf-rack --expose --shoot-at=9"
)

frames=$(( (LEAD + LENGTH) * FPS ))
list="$WORK/list.txt"
: > "$list"
index=0
for entry in "${SEQUENCES[@]}"; do
	index=$((index + 1))
	if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$index,"* ]]; then continue; fi
	title="${entry%%|*}"
	args="${entry#*|}"
	echo "=== [$index/${#SEQUENCES[@]}] $title"
	raw="$WORK/raw_$index.avi"
	# shellcheck disable=SC2086
	"$GODOT" --path "$PROJECT_DIR" --disable-vsync --rendering-method forward_plus --resolution "$RES" \
		--write-movie "$raw" --fixed-fps "$FPS" --quit-after "$frames" -- $args > "$WORK/log_$index.txt" 2>&1 || true
	if [ ! -s "$raw" ]; then
		echo "    sin vídeo (ver $WORK/log_$index.txt)"; tail -5 "$WORK/log_$index.txt"; continue
	fi
	clip="$WORK/clip_$index.mp4"
	safe_title="${title//:/\\:}"
	ffmpeg -loglevel error -y -ss "$LEAD" -t "$LENGTH" -i "$raw" \
		-vf "scale=${RES%x*}:${RES#*x}:flags=lanczos,drawbox=x=0:y=ih-90:w=iw:h=90:color=black@0.45:t=fill:enable='lt(t,4)',drawtext=fontfile=$FONT:text='$safe_title':x=40:y=h-62:fontsize=34:fontcolor=white:alpha='if(lt(t,3),1,max(0,4-t))',fade=t=in:st=0:d=0.4,fade=t=out:st=$((LENGTH - 1)).6:d=0.4" \
		-af "afade=t=in:st=0:d=0.4,afade=t=out:st=$((LENGTH - 1)).6:d=0.4" -c:a aac -b:a 192k -ar 48000 -ac 2 \
		-r "$FPS" -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p "$clip"
	echo "file '$clip'" >> "$list"
done
if [ ! -s "$list" ]; then echo "No se grabó ninguna secuencia."; exit 1; fi
silent="$WORK/silent.mp4"
ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" -c copy "$silent"
duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$silent")
# Música de fondo de los vídeos del proyecto (assets/audio/musica_videos.mp3, más larga que el
# vídeo): se recorta a su duración con un fundido de salida en los últimos 10 s. Debajo suena el
# audio del juego (ambiente del parque y clic del obturador), algo más bajo.
if [ -s "$MUSIC" ]; then
	fade_start=$(awk -v d="$duration" 'BEGIN { printf "%.2f", (d > 10 ? d - 10 : 0) }')
	ffmpeg -loglevel error -y -i "$silent" -i "$MUSIC" -map 0:v -c:v copy \
		-filter_complex "[1:a]afade=t=in:st=0:d=1,afade=t=out:st=$fade_start:d=10,volume=0.8[m];[0:a]volume=1.6[g];[m][g]amix=inputs=2:duration=shortest:normalize=0[a]" \
		-map "[a]" -c:a aac -b:a 192k -movflags +faststart "$OUT"
else
	ffmpeg -loglevel error -y -i "$silent" -c copy -movflags +faststart "$OUT"
fi
echo "=== Vídeo: $OUT (${duration%.*} s, $(du -h "$OUT" | cut -f1))"
