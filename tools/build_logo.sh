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
canvas.alpha_composite(icon.resize((900, 900), Image.LANCZOS), ((W - 900) // 2, 10))
draw = ImageDraw.Draw(canvas)
font = ImageFont.truetype("assets/fuentes/Roboto-Light.ttf", 190)
width = draw.textlength(sys.argv[1], font=font)
draw.text(((W - width) / 2, 850), sys.argv[1], font=font, fill=(240, 125, 40, 255))
canvas.convert("RGB").save("build/marca/logotipo.png")
PY
echo "build/marca/icono.png · build/marca/logotipo.png"
