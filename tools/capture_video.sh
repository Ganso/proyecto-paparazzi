#!/usr/bin/env bash
# Vídeo largo de evidencias (bajo demanda): un tráiler de presentación del proyecto en unos 180 s,
# por capítulos rotulados (el parque, su vida, las cámaras, los modos de juego, el parque grande y
# el progreso), que enseña todo lo implementado. Contenido: pantalla de carga, menú y arcade (30 niveles, una
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
# Ni su progreso de la Academia: las demostraciones lo marcarían.
export PAPARAZZI_ACADEMY_CFG="$WORK/academia.cfg"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$(dirname "$OUT")"
FONT="$(fc-match -f '%{file}' 'sans:bold')"
MUSIC="${MUSIC:-$PROJECT_DIR/assets/audio/musica_videos.mp3}"

# título | segundos | argumentos del juego (tras --); sin argumentos de demo arranca el menú.
# «@img:fichero» es una imagen fija y «@card:subtítulo» un rótulo de capítulo sobre la pantalla de
# carga desenfocada. El guion es un tráiler de presentación: capítulos (el parque, su vida, las
# cámaras, los modos de juego, el parque grande, el progreso) que enseñan todo lo implementado.
SEQUENCES=(
	"PhotoHacks|3|@img:assets/marca/carga.png"
	"Un juego para aprender fotografía haciendo fotos|4|"
	"El parque|2|@card:Un diorama vivo, a cualquier hora"
	"De día · 21 viandantes, cada uno con su ropa y su paso|4|--time=day --lens=0,0 --angle=100 --pitch=2 --focal=24 --pan=6 --af"
	"Hora dorada|3|--time=golden --lens=0,0 --angle=200 --pitch=3 --focal=35 --pan=4 --af"
	"Hora azul|3|--time=blue --lens=0,0 --angle=300 --pitch=12 --focal=24 --pan=4 --af"
	"Noche · luna, estrellas y farolas|4|--time=night --lens=0,0 --angle=205 --pitch=20 --focal=28 --pan=3 --af"
	"Vida en el parque|2|@card:Gente, animales y sonido ambiente"
	"Bancos · leer, charlar, mirar el móvil|4|--time=day --stage=banco --angle=125 --pitch=-7 --focal=40 --af"
	"Palomas · acuden a las migas y echan a volar|5|--time=day --stage=palomas --angle=125 --pitch=-12 --focal=40 --af --scare-at=8"
	"Paseando al perro|3|--time=day --stage=perro --pitch=-12 --focal=24 --af"
	"La pradera · pícnic, lectores y figurantes|3|--time=day --lens=2,1 --angle=103 --pitch=-2 --focal=85 --pan=1.2 --advance=6 --af"
	"Patos en el estanque|3|--time=day --lens=2,1 --angle=243 --pitch=-4 --focal=135 --pan=.8 --af"
	"Las cámaras|2|@card:Cuatro cuerpos, cada uno con su visor"
	"Compacta · zoom 24–120 y todo automático|3|--time=day --interface=camara --lens=0,0 --angle=200 --pitch=-3 --focal=35 --pan=3 --af"
	"Réflex · teleobjetivo y autofoco continuo|4|--time=day --interface=camara --lens=2,1 --angle=40 --focal=150 --follow --af"
	"Telemétrica · enfoque manual, disparo y revelado|8|--time=day --lens=1,2 --focal=90 --follow-target --mf-rack --expose --shoot-at=5"
	"TLR 6×6 · a la cintura, visor espejado y foto cuadrada|9|--level=21 --interface=camara --follow-target --mf-rack --expose --shoot-at=6"
	"Modos de juego|2|@card:Tutorial, Arcade, Sandbox y Academia"
	"Tutorial · los controles, paso a paso|4|--tutorial"
	"Arcade · 30 niveles en seis bloques|3|--arcade --cheat=niveles"
	"Arcade · barrido: corredor nítido, fondo arrastrado|8|--level=26 --interface=camara --focal=85 --follow-target --pan-shot --shutter=30 --shoot-at=5"
	"Parque grande · camina, busca y llévate la cámara al ojo|8|--scenario=grande --time=golden --photo-walk"
	"Sandbox · fotografía libre, sin encargo|3|--sandbox --time=day --lens=0,0 --angle=150 --pitch=-2 --focal=50 --pan=3 --af"
	"La Academia|2|@card:Diez lecciones para entender la fotografía"
	"Diez lecciones · teoría, demostración, práctica y examen|4|--academy=menu"
	"Lección 1 · La composición: los tercios y el aire|4|--academy=1:teoria:2"
	"El tutor lo enseña con la cámara en la mano|10|--academy=1:demo"
	"Lección 4 · La exposición: un cubo de luz y tres grifos|4|--academy=4:teoria"
	"Diafragma, velocidad e ISO, paso a paso|10|--academy=4:demo"
	"Lección 5 · La profundidad de campo, abriendo y cerrando|6|--academy=5:teoria:2"
	"Lección 6 · El movimiento: del fantasma al corredor congelado|12|--academy=6:demo"
	"Lección 7 · Medir la luz: cuándo llevarle la contraria|4|--academy=7:teoria:5"
	"Lección 9 · Los objetivos: zoom o fijo con poca luz|8|--academy=9:demo"
	"Lección 10 · Las cámaras: la TLR|4|--academy=10:teoria:5"
	"Y después, la práctica: te toca a ti|4|--academy=4:practica"
	"Tu progreso|2|@card:Álbum e insignias"
	"Álbum · tus mejores fotos|3|--screen=album"
	"Insignias de maestría|3|--screen=insignias"
	"PhotoHacks|3|@card:Windows · Linux · macOS · Android"
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
	card=""
	if [[ "$args" == @card:* ]]; then
		# Rótulo de capítulo: la pantalla de carga desenfocada y oscurecida, con el título grande.
		card="${args#@card:}"
		ffmpeg -loglevel error -y -loop 1 -framerate "$FPS" -t "$((LEAD + LENGTH))" -i "$PROJECT_DIR/assets/marca/carga.png" \
			-f lavfi -t "$((LEAD + LENGTH))" -i anullsrc=r=48000:cl=stereo -vf "scale=${RES%x*}:${RES#*x},gblur=sigma=28,eq=brightness=-0.22" \
			-c:v mjpeg -q:v 3 -c:a pcm_s16le "$raw"
	elif [[ "$args" == @img:* ]]; then
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
	if [ -n "$card" ]; then
		safe_card="${card//:/\\:}"
		ffmpeg -loglevel error -y -ss "$LEAD" -t "$LENGTH" -i "$raw" \
			-vf "drawtext=fontfile=$FONT:text='$safe_title':x=(w-text_w)/2:y=h/2-110:fontsize=104:fontcolor=white,drawtext=fontfile=$FONT:text='$safe_card':x=(w-text_w)/2:y=h/2+40:fontsize=40:fontcolor=white@0.85,fade=t=in:st=0:d=0.3,fade=t=out:st=$((LENGTH - 1)).7:d=0.3" \
			-c:a aac -b:a 192k -ar 48000 -ac 2 -r "$FPS" -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p "$clip"
		echo "file '$clip'" >> "$list"
		continue
	fi
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
