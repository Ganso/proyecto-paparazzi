#!/usr/bin/env bash
# Vídeo de evidencias (bajo demanda, para cambios grandes): el proyecto entero en unos 180 s.
# Muchas secuencias cortas, un poco de todo: pantalla de carga, menú y arcade (25 niveles, una
# condición, la TLR, el barrido), las cuatro luces con el cielo propio, los dos escenarios
# (parque clásico y parque grande a pie), la vida del parque (bancos, palomas, perro, figurantes,
# móviles de noche), los tres cuerpos con su visor real (compacta, telemétrica con enfoque manual,
# réflex con teleobjetivo), disparo y revelado, el modo sandbox, la Academia con su examen, las
# insignias y las opciones. Graba cada secuencia
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
# El vídeo no usa los ajustes gráficos del jugador (ni su contador de FPS): perfil por defecto.
export PAPARAZZI_GFX_CFG="$WORK/graficos.cfg"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$(dirname "$OUT")"
FONT="$(fc-match -f '%{file}' 'sans:bold')"
MUSIC="${MUSIC:-$PROJECT_DIR/assets/audio/musica_videos.mp3}"

# título | segundos | argumentos del juego (tras --); sin argumentos de demo arranca el menú
SEQUENCES=(
	"Proyecto Paparazzi|3|@img:assets/marca/carga.png"
	"Menú · Arcade, Tutorial, Sandbox, Academia y Opciones|5|"
	"Arcade · 25 niveles en cinco bloques|5|--arcade --cheat=niveles"
	"Parque clásico de día · 21 viandantes, gran angular 24 mm|6|--time=day --lens=0,0 --angle=100 --pitch=2 --focal=24 --pan=6 --af"
	"Hora dorada · el estanque a 35 mm|5|--time=golden --lens=0,0 --angle=200 --pitch=3 --focal=35 --pan=4 --af"
	"Hora azul · cirros y resplandor de poniente|5|--time=blue --lens=0,0 --angle=300 --pitch=12 --focal=24 --pan=4 --af"
	"Noche · luna, estrellas y farolas|6|--time=night --lens=0,0 --angle=205 --pitch=20 --focal=28 --pan=3 --af"
	"Vida en el parque · bancos y charlas|6|--time=day --stage=banco --angle=125 --pitch=-7 --focal=40 --af"
	"Palomas que acuden a las migas|5|--time=day --stage=palomas --angle=125 --pitch=-12 --focal=40 --af"
	"Palomas posadas en la verja|5|--time=day --pigeons=verja --lens=2,1 --angle=94 --pitch=-1 --focal=70 --pan=1.5 --af"
	"Paseando al perro|5|--time=day --stage=perro --pitch=-12 --focal=24 --af"
	"La pradera · mesas de pícnic, lector y figurantes|6|--time=day --lens=2,1 --angle=103 --pitch=-2 --focal=85 --pan=1.2 --advance=6 --af"
	"Patos en el estanque|5|--time=day --lens=2,1 --angle=243 --pitch=-4 --focal=135 --pan=.8 --af"
	"El quiosco · paseantes y el perro pequeño|5|--time=golden --lens=2,1 --angle=116 --pitch=-2 --focal=90 --pan=1.2 --advance=8 --af"
	"Andar sin rebote · cada uno con su paso|6|--time=day --lens=2,0 --angle=40 --pitch=-6 --focal=35 --pan=5 --af"
	"Compacta · su visor real y zoom 24–120|5|--time=day --interface=camara --lens=0,0 --angle=200 --pitch=-3 --focal=35 --pan=3 --af"
	"Réflex · teleobjetivo siguiendo a un viandante|6|--time=day --interface=camara --lens=2,1 --angle=40 --focal=150 --follow --af"
	"Telemétrica 90 mm · enfoque manual, disparo y revelado|10|--time=day --lens=1,2 --focal=90 --follow-target --mf-rack --expose --shoot-at=6"
	"Nivel 8 · condición: cara nítida y sujeto grande|9|--level=8 --interface=camara --follow-target --mf-rack --shoot-at=5"
	"TLR 6×6 · a la cintura, visor espejado y foto cuadrada|11|--level=16 --interface=camara --follow-target --mf-rack --expose --shoot-at=7"
	"Nivel 21 · barrido: corredor nítido, fondo arrastrado|10|--level=21 --interface=camara --focal=85 --follow-target --pan-shot --shutter=30 --shoot-at=6"
	"Parque grande · paseo libre y cámara al ojo|12|--scenario=grande --time=golden --photo-walk"
	"Modo sandbox · fotografía libre, sin encargo|5|--sandbox --time=day --lens=2,0 --angle=150 --pitch=-2 --focal=50 --pan=3 --af"
	"Academia · teoría y demostración guiada|12|--academy=2:teoria --academy-tour=3:2"
	"Academia · examen con informe del tutor|9|--academy=1:examen --shoot-at=4"
	"Insignias de maestría|4|--screen=insignias"
	"Opciones · gráficos, tema, vibración, insignias y álbum|4|--screen=opciones"
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
	if [[ "$args" == @img:* ]]; then
		# Una imagen fija (la pantalla de carga no se puede grabar: sale antes del primer fotograma).
		ffmpeg -loglevel error -y -loop 1 -framerate "$FPS" -t "$((LEAD + LENGTH))" -i "$PROJECT_DIR/${args#@img:}" \
			-f lavfi -t "$((LEAD + LENGTH))" -i anullsrc=r=48000:cl=stereo -c:v mjpeg -q:v 3 -c:a pcm_s16le "$raw"
	else
	# shellcheck disable=SC2086
	"$GODOT" --path "$PROJECT_DIR" --disable-vsync --rendering-method forward_plus --resolution "$RES" \
		--write-movie "$raw" --fixed-fps "$FPS" --quit-after "$frames" -- $args > "$WORK/log_$index.txt" 2>&1 || true
	fi
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
# El último vídeo largo va siempre al repositorio (docs/evidencias/video/evidencias.mp4), en una copia
# ligera: GitHub avisa a partir de 50 MB y rechaza los ficheros de más de 100 MB. Solo cuando se
# graba el guion entero (sin --only ni --sequences).
if [ -z "$ONLY" ] && [ -z "$SEQ_FILE" ]; then
	REPO_COPY="$PROJECT_DIR/docs/evidencias/video/evidencias.mp4"
	mkdir -p "$(dirname "$REPO_COPY")"
	ffmpeg -loglevel error -y -i "$OUT" -c:v libx264 -preset slow -crf 27 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart "$REPO_COPY"
	size=$(stat -c %s "$REPO_COPY")
	echo "=== Copia para el repositorio: $REPO_COPY ($(du -h "$REPO_COPY" | cut -f1))"
	if [ "$size" -gt 50000000 ]; then echo "    AVISO: pasa de 50 MB; recodifícala con más compresión antes de subirla."; fi
fi
