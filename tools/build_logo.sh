#!/usr/bin/env bash
# Icono 3D del juego (tools/blender/build_logo.py) y su composición con el nombre sobre azul.
#   ./tools/build_logo.sh [nombre]      → build/marca/icono.png y build/marca/logotipo.png
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
NAME="${1:-PhotoHacks}"
mkdir -p build/marca
blender -b --factory-startup -P tools/blender/build_logo.py -- --out "$PWD/build/marca" --size 1024 --samples 400 > build/marca/blender.log 2>&1
python3 - "$NAME" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
icon = Image.open("build/marca/icono.png")
W, H = 2048, 1118
canvas = Image.new("RGBA", (W, H), (41, 108, 165, 255))
canvas.alpha_composite(icon.resize((900, 900), Image.LANCZOS), ((W - 900) // 2, 20))
draw = ImageDraw.Draw(canvas)
font = ImageFont.truetype("assets/fuentes/RussoOne-Regular.ttf", 170)
width = draw.textlength(sys.argv[1], font=font)
draw.text(((W - width) / 2, 850), sys.argv[1], font=font, fill=(240, 125, 40, 255))
canvas.convert("RGB").save("build/marca/logotipo.png")
PY
# Vuelta de 360° (GIRO=1): build/marca/giro.mp4, sobre el mismo azul.
if [ "${GIRO:-0}" = 1 ]; then
	rm -rf build/marca/giro; mkdir -p build/marca/giro
	blender -b --factory-startup -P tools/blender/build_logo.py -- --out "$PWD/build/marca" --size 640 --samples 100 --turntable 90 > build/marca/blender_giro.log 2>&1
	ffmpeg -loglevel error -y -f lavfi -i "color=c=0x296ca5:s=640x640:r=30" -framerate 30 -i build/marca/giro/giro_%03d.png \
		-filter_complex "[0][1]overlay=shortest=1,format=yuv420p" -c:v libx264 -crf 18 -movflags +faststart build/marca/giro.mp4
	echo "build/marca/giro.mp4"
fi
echo "build/marca/icono.png · build/marca/logotipo.png"
