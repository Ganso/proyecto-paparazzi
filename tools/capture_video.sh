#!/usr/bin/env bash
# Vídeo de evidencias (bajo demanda, para cambios grandes): el proyecto entero en unos 180 s.
# Menú principal y arcade (niveles, una condición, la TLR), las cuatro luces, los dos escenarios
# (parque clásico y parque grande a pie), la vida del parque (bancos, palomas, perro, figurantes,
# móviles de noche), los tres cuerpos con su visor real (compacta, telemétrica con enfoque manual,
# réflex con teleobjetivo), disparo y revelado, el modo sandbox y la Academia. Graba cada secuencia
# con el Movie Maker de Godot (--write-movie, 30 FPS fijos) y las monta con ffmpeg en un MP4 rotulado.
#
#   ./tools/capture_video.sh [--only 1,3] [--res 1920x1080] [--out build/video/evidencias.mp4]
#                            [--sequences <fichero>]   (otras secuencias: una por línea, «título|segundos|argumentos»)
#
# Necesita un Godot con Vulkan (GODOT_FP o ~/bin/godot-4-fp) y ffmpeg con libx264. El MP4 va a
# build/video/ (ignorado por git). Tarda unos 15 min. Lleva de fondo la música del proyecto
# (assets/audio/musica_videos.mp3, o la variable MUSIC) con fundido de salida de 10 s, mezclada
# sobre el sonido del juego (ambiente y clic del obturador).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT_FP:-$HOME/bin/godot-4-fp}"
RES="1920x1080"
OUT="$PROJECT_DIR/build/video/evidencias_$(date +%Y%m%d_%H%M).mp4"
ONLY=""
SEQ_FILE=""
while [ $# -gt 0 ]; do
	case "$1" in
		--only) ONLY="$2"; shift 2 ;;
		--res) RES="$2"; shift 2 ;;
		--out) OUT="$2"; shift 2 ;;
		--sequences) SEQ_FILE="$2"; shift 2 ;;
		*) echo "Opción desconocida: $1"; exit 1 ;;
	esac
done
FPS=30
LEAD=4          # segundos iniciales que se descartan (carga y reposo de los muelles)
WORK="$(mktemp -d "${TMPDIR:-/tmp}/paparazzi-video.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$(dirname "$OUT")"
FONT="$(fc-match -f '%{file}' 'sans:bold')"
MUSIC="${MUSIC:-$PROJECT_DIR/assets/audio/musica_videos.mp3}"

# título | segundos | argumentos del juego (tras --); sin argumentos de demo arranca el menú
SEQUENCES=(
	"Proyecto Paparazzi · menú: Arcade, Sandbox y Academia|9|"
	"Arcade · veinte niveles en cuatro bloques|6|--arcade"
	"Parque clásico de día · 21 viandantes, gran angular 24 mm|8|--time=day --lens=0,0 --angle=100 --pitch=2 --focal=24 --pan=6 --af"
	"Hora dorada · el estanque a 35 mm|8|--time=golden --lens=0,0 --angle=200 --pitch=3 --focal=35 --pan=4 --af"
	"Hora azul · el parque se enciende|8|--time=blue --lens=0,0 --angle=120 --pitch=3 --focal=28 --pan=4 --af"
	"Noche · farolas y quiosco iluminado|8|--time=night --lens=0,0 --angle=90 --pitch=4 --focal=24 --pan=5 --af"
	"Vida en el parque · bancos de dos plazas y charlas|8|--time=day --stage=banco --angle=125 --pitch=-7 --focal=40 --af"
	"Palomas que acuden a las migas|7|--time=day --stage=palomas --angle=125 --pitch=-12 --focal=40 --af"
	"Paseando al perro|7|--time=day --stage=perro --pitch=-12 --focal=24 --af"
	"La pradera · pícnic, balón y figurantes|7|--time=golden --angle=112 --pitch=-1 --focal=60 --pan=1.5 --lens=2,1 --af"
	"Compacta · su visor real y zoom 24–120|7|--time=day --interface=camara --lens=0,0 --angle=200 --pitch=-3 --focal=35 --pan=3 --af"
	"Réflex · teleobjetivo siguiendo a un viandante|8|--time=day --interface=camara --lens=2,1 --angle=40 --focal=150 --follow --af"
	"Telemétrica 90 mm · enfoque manual, disparo y revelado|12|--time=day --lens=1,2 --focal=90 --follow-target --mf-rack --expose --shoot-at=8"
	"Nivel 8 · condición: ojos nítidos con AF puntual|11|--level=8 --interface=camara --follow-target --expose --shoot-at=6"
	"TLR 6×6 · a la cintura, visor espejado y foto cuadrada|14|--level=16 --interface=camara --follow-target --mf-rack --expose --shoot-at=8"
	"Parque grande · paseo libre y cámara al ojo|16|--scenario=grande --time=golden --photo-walk"
	"Modo sandbox · fotografía libre, sin encargo|8|--sandbox --time=day --lens=2,0 --angle=150 --pitch=-2 --focal=50 --pan=3 --af"
	"Academia de fotografía · teoría, demostración y práctica|18|--academy=2:teoria --academy-tour=4:2"
)

if [ -n "$SEQ_FILE" ]; then mapfile -t SEQUENCES < <(grep -v '^\s*\(#\|$\)' "$SEQ_FILE"); fi
list="$WORK/list.txt"
: > "$list"
index=0
for entry in "${SEQUENCES[@]}"; do
	index=$((index + 1))
	if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$index,"* ]]; then continue; fi
	title="${entry%%|*}"
	rest="${entry#*|}"
	LENGTH="${rest%%|*}"
	args="${rest#*|}"
	frames=$(( (LEAD + LENGTH) * FPS ))
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
