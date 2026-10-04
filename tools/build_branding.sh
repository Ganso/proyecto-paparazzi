#!/usr/bin/env bash
# Imágenes de la marca que usa el juego (assets/marca/), a partir del logotipo de Blender:
#   camara.png  512 × 512, la cámara de bloques sin fondo (cabecera del menú)
#   icono.png   256 × 256, la cámara sobre el azul: icono de la ventana y de los ejecutables
#   carga.png   1280 × 720, lo que enseña el motor al arrancar (boot splash): cámara, nombre en
#               naranja y «Cargando el parque…». scripts/boot_loader.gd dibuja lo mismo encima
#               y hace girar la cámara, así que las posiciones de aquí y de allí son las mismas.
#   giro.png    hoja de 9 × 5 fotogramas de 256 px con la vuelta de 360° (45 fotogramas)
# El texto de carga.png va dentro de la imagen (el motor la muestra antes de cargar los textos):
# si cambia el nombre del juego o `cargando_parque`, se regenera.
# Uso: GIRO=1 ./tools/build_logo.sh && bash tools/build_branding.sh
#      (el primero modela y dibuja en Blender: build/marca/icono.png y build/marca/giro/)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
[ -f build/marca/icono.png ] && [ -f build/marca/giro/giro_000.png ] || { echo "Falta build/marca: GIRO=1 ./tools/build_logo.sh" >&2; exit 1; }
python3 - <<'PY'
import glob, json
from PIL import Image, ImageDraw, ImageFont
OUT = "assets/marca/"
BLUE, ORANGE = (41, 108, 165, 255), (240, 125, 40, 255)
texts = json.load(open("data/textos.es.json"))
frames = sorted(glob.glob("build/marca/giro/giro_*.png"))
frames = frames[::max(1, len(frames) // 45)][:45]
first = Image.open(frames[0]).convert("RGBA")

Image.open("build/marca/icono.png").convert("RGBA").resize((512, 512), Image.LANCZOS).save(OUT + "camara.png")

icon = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
ImageDraw.Draw(icon).rounded_rectangle((32, 32, 991, 991), 208, fill=BLUE)
icon = icon.resize((256, 256), Image.LANCZOS)
icon.alpha_composite(Image.open("build/marca/icono.png").convert("RGBA").resize((224, 224), Image.LANCZOS), (16, 16))
icon.save(OUT + "icono.png")

splash = Image.new("RGBA", (1280, 720), BLUE)
splash.alpha_composite(first.resize((440, 440), Image.LANCZOS), (420, 40))
draw = ImageDraw.Draw(splash)
for text, path, size, y, colour in ((texts["nombre_juego"], "RussoOne-Regular", 92, 470, ORANGE), (texts["cargando_parque"], "Roboto-Light", 28, 600, (214, 236, 251, 255))):
    font = ImageFont.truetype("assets/fuentes/%s.ttf" % path, size)
    # (línea base donde la pone boot_loader.gd: y + 0,8 × tamaño)
    draw.text(((1280 - draw.textlength(text, font=font)) / 2, y + size * .8), text, font=font, fill=colour, anchor="ls")
splash.convert("RGB").save(OUT + "carga.png")

sheet = Image.new("RGBA", (9 * 256, 5 * 256), (0, 0, 0, 0))
for k, frame in enumerate(frames):
    sheet.alpha_composite(Image.open(frame).convert("RGBA").resize((256, 256), Image.LANCZOS), ((k % 9) * 256, (k // 9) * 256))
sheet.save(OUT + "giro.png")
PY
# Se importan como texturas normales (sus .import están versionados): el exportador ya mete por
# su cuenta el icono y la imagen de carga, y con importer="keep" entraban dos veces en el APK.
echo "BRANDING assets/marca/{camara,icono,carga,giro}.png"
