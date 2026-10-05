#!/usr/bin/env bash
# Vídeo de las piezas de vestuario nuevas (tools/capture_characters.gd::NEW_PIECES): cada una da
# una vuelta de 360°, encuadrada en la parte del cuerpo que cambia. A la izquierda la versión de
# escritorio (Blender) y a la derecha la ligera (Android y web). Con la música de los vídeos del
# proyecto y su fundido de salida.
#   ./tools/capture_wardrobe_video.sh        → build/video/vestuario_nuevo.mp4
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT="${GODOT_BIN:-$HOME/bin/godot-4-fp}"
OUT=build/video/vestuario; rm -rf "$OUT"; mkdir -p "$OUT"
export PAPARAZZI_GFX_CFG="$PWD/$OUT/graficos.cfg"
for lod in hd lo; do
	flag=""; [ "$lod" = lo ] && flag="--lo"
	timeout 900 "$GODOT" --path . --disable-vsync --rendering-method forward_plus --resolution 800x1000 --script tools/capture_characters.gd -- --only=giros $flag --out="$PWD/$OUT/$lod" 2>&1 | grep -E "GIROS|ERROR" || true
done
python3 - "$OUT" <<'PY'
import sys, glob, os
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1]
font = ImageFont.truetype("assets/fuentes/RussoOne-Regular.ttf", 34)
small = ImageFont.truetype("assets/fuentes/Roboto-Medium.ttf", 22)
names = ["Gabardina", "Camiseta de tirantes", "Moño", "Pelo rizado", "Boina", "Gorra hacia atrás", "Mochila", "Paraguas", "Gafas", "Gafas de sol"]
os.makedirs(out + "/frames", exist_ok=True)
frames = sorted(glob.glob(out + "/hd/giros/*.png"))
for i, path in enumerate(frames):
    base = os.path.basename(path)
    left = Image.open(path).convert("RGB").resize((640, 800), Image.LANCZOS)
    right = Image.open(out + "/lo/giros/" + base).convert("RGB").resize((640, 800), Image.LANCZOS)
    w, h = left.size
    sheet = Image.new("RGB", (w * 2 + 8, h + 90), (41, 108, 165))
    sheet.paste(left, (0, 90)); sheet.paste(right, (w + 8, 90))
    d = ImageDraw.Draw(sheet)
    name = names[int(base[:2])]
    d.text(((sheet.width - d.textlength(name, font=font)) / 2, 8), name, font=font, fill=(240, 125, 40))
    for x, label in ((0, "Escritorio"), (w + 8, "Android y web")):
        d.text((x + (w - d.textlength(label, font=small)) / 2, 56), label, font=small, fill=(214, 236, 251))
    if sheet.width % 2: sheet = sheet.crop((0, 0, sheet.width - 1, sheet.height))
    sheet.save(out + "/frames/%05d.png" % i)
print(len(frames), "fotogramas")
PY
N=$(ls "$OUT/frames" | wc -l); SECS=$(python3 -c "print($N/30)")
ffmpeg -loglevel error -y -framerate 30 -i "$OUT/frames/%05d.png" -i assets/audio/musica_videos.mp3 -filter_complex "[1:a]atrim=0:$SECS,afade=t=out:st=$(python3 -c "print(max(0,$SECS-10))"):d=10[a]" -map 0:v -map "[a]" -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac -b:a 160k -shortest -movflags +faststart build/video/vestuario_nuevo.mp4
echo "build/video/vestuario_nuevo.mp4 ($(du -h build/video/vestuario_nuevo.mp4 | cut -f1), ${SECS} s)"
