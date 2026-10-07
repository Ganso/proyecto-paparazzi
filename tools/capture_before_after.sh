#!/usr/bin/env bash
# Vídeo del antes y el después de la foto y del seguimiento con teclas (docs/SIMULACION_FOTOGRAFICA.md §9
# y docs/futuro/11): cada escena se prepara una vez y se revela dos veces desde el mismo instante
# (tools/capture_before_after.gd), en Vulkan y en OpenGL; el seguimiento se graba jugando, con
# PAPARAZZI_LEGACY=1 para el «antes». Sin música.
#   ./tools/capture_before_after.sh [--out build/video/antes_despues.mp4]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT="${GODOT_FP:-$HOME/bin/godot-4-fp}"
OUT="build/video/antes_despues.mp4"
[ "${1:-}" = "--out" ] && OUT="$2"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/photohacks-antes-despues.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
FONT="$(fc-match -f '%{file}' 'sans:bold')"
export PAPARAZZI_GFX_CFG="$WORK/graficos.cfg" PAPARAZZI_ARCADE_CFG="$WORK/arcade.cfg" PAPARAZZI_ALBUM_DIR="$WORK/album" PAPARAZZI_ACADEMY_CFG="$WORK/academia.cfg"
mkdir -p "$(dirname "$OUT")"
list="$WORK/list.txt"; : > "$list"; n=0
esc() { local t="${1//:/\\:}"; t="${t//,/\\,}"; echo "${t//\'/}"; }
clip() {   # fichero de vídeo ya montado → a la lista
	n=$((n+1)); cp "$1" "$WORK/clip_$n.mp4"; echo "file '$WORK/clip_$n.mp4'" >> "$list"
}
card() {   # título, subtítulo, segundos
	ffmpeg -nostdin -loglevel error -y -f lavfi -t "$3" -i "color=c=0x101820:s=1920x1080:r=30" -f lavfi -t "$3" -i anullsrc=r=48000:cl=stereo \
		-vf "drawtext=fontfile=$FONT:text='$(esc "$1")':x=(w-text_w)/2:y=h/2-90:fontsize=72:fontcolor=white,drawtext=fontfile=$FONT:text='$(esc "$2")':x=(w-text_w)/2:y=h/2+30:fontsize=36:fontcolor=white@0.8" \
		-c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 -shortest "$WORK/t.mp4"
	clip "$WORK/t.mp4"
}
still() {  # imagen, etiqueta (ANTES/DESPUÉS), color, título, ajustes, segundos
	ffmpeg -nostdin -loglevel error -y -loop 1 -framerate 30 -t "$6" -i "$1" -f lavfi -t "$6" -i anullsrc=r=48000:cl=stereo \
		-vf "scale=1920:1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x101820,drawbox=x=0:y=0:w=iw:h=92:color=black@0.55:t=fill,drawtext=fontfile=$FONT:text='$(esc "$2")':x=40:y=22:fontsize=52:fontcolor=$3,drawtext=fontfile=$FONT:text='$(esc "$4")':x=420:y=18:fontsize=34:fontcolor=white,drawtext=fontfile=$FONT:text='$(esc "$5")':x=420:y=58:fontsize=24:fontcolor=white@0.8" \
		-c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 -shortest "$WORK/t.mp4"
	clip "$WORK/t.mp4"
}
pair() {   # antes, después, título, ajustes, segundos: las dos mitades centrales, lado a lado
	ffmpeg -nostdin -loglevel error -y -loop 1 -framerate 30 -t "$5" -i "$1" -loop 1 -framerate 30 -t "$5" -i "$2" -f lavfi -t "$5" -i anullsrc=r=48000:cl=stereo \
		-filter_complex "[0]scale=1920:1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x101820,crop=956:1080:482:0[a];[1]scale=1920:1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x101820,crop=956:1080:482:0[b];[a][b]hstack=inputs=2,pad=1920:1080:4:0:color=white,drawbox=x=0:y=0:w=iw:h=92:color=black@0.55:t=fill,drawtext=fontfile=$FONT:text='ANTES':x=40:y=22:fontsize=52:fontcolor=0xff9a7a,drawtext=fontfile=$FONT:text='DESPUÉS':x=1000:y=22:fontsize=52:fontcolor=0x9ae6a0,drawtext=fontfile=$FONT:text='$(esc "$3")':x=40:y=h-70:fontsize=34:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=10[v]" \
		-map "[v]" -map 2:a -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -ar 48000 -ac 2 -shortest "$WORK/t.mp4"
	clip "$WORK/t.mp4"
}
play() {   # título, segundos, [variable=valor] argumentos del juego: un trozo jugado, con su sonido
	local title="$1" secs="$2"; shift 2
	local envs=(); while [[ "${1:-}" == *=* && "${1:-}" != --* ]]; do envs+=("$1"); shift; done
	env "${envs[@]}" "$GODOT" --path . --disable-vsync --rendering-method forward_plus --resolution 1920x1080 \
		--write-movie "$WORK/raw.avi" --fixed-fps 30 --quit-after $(( (4+secs)*30 )) -- "$@" > "$WORK/play.log" 2>&1 || true
	ffmpeg -nostdin -loglevel error -y -ss 4 -t "$secs" -i "$WORK/raw.avi" \
		-vf "drawbox=x=0:y=ih-80:w=iw:h=80:color=black@0.55:t=fill,drawtext=fontfile=$FONT:text='$(esc "$title")':x=40:y=h-58:fontsize=34:fontcolor=white" \
		-c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -ac 2 -r 30 "$WORK/t.mp4"
	clip "$WORK/t.mp4"
}

card "PhotoHacks · antes y después" "La foto y el seguimiento con teclas, en las mismas condiciones" 4
card "Seguimiento con teclas" "La tecla de giro mantenida desde antes de que llegue el corredor" 3
play "ANTES: Sin marca, y el corredor no se queda quieto en el punto de enfoque" 11 PAPARAZZI_LEGACY=1 --level=26 --interface=camara --focal=70 --hold-turn=0.5
play "DESPUÉS: Lo espera, se adapta a su paso y lo mantiene en el punto de enfoque" 11 --level=26 --interface=camara --focal=70 --hold-turn=0.5
for pass in "forward_plus|Vulkan (escritorio)|" "gl_compatibility|OpenGL (Android y web)|barrido estela trepidacion fondo estrellas"; do
	IFS='|' read -r method name only <<< "$pass"
	dir="$WORK/$method"
	"$GODOT" --path . --disable-vsync --rendering-method "$method" --resolution 1920x1080 --script tools/capture_before_after.gd -- --out="$dir" 2>&1 | grep -E "^ESCENA|SCRIPT ERROR" || true
	card "La foto · $name" "Cada escena, revelada como antes y como ahora desde el mismo instante" 3
	while IFS='|' read -r file title settings; do
		[ -z "$file" ] && continue
		scene="${file#*_}"
		if [ -n "$only" ] && [[ " $only " != *" $scene "* ]]; then continue; fi
		still "$dir/${file}_antes.png" "ANTES" 0xff9a7a "$title" "$settings" 3.5
		still "$dir/${file}_despues.png" "DESPUÉS" 0x9ae6a0 "$title" "$settings" 3.5
		pair "$dir/${file}_antes.png" "$dir/${file}_despues.png" "$title" "$settings" 3
	done < "$dir/escenas.txt"
done
ffmpeg -nostdin -loglevel error -y -f concat -safe 0 -i "$list" -c copy -movflags +faststart "$OUT"
echo "=== Vídeo: $OUT ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT" | cut -d. -f1) s, $(du -h "$OUT" | cut -f1))"
