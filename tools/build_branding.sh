#!/usr/bin/env bash
# Genera la pantalla de carga y el icono del juego (assets/marca/) con ImageMagick.
#   carga.png   1280 × 720: lo que se ve mientras se construye el parque (boot splash)
#   icono.png   256 × 256: icono de la ventana y de los ejecutables
# El texto de la pantalla de carga va dentro de la imagen (el motor la muestra antes de cargar
# data/textos.es.json): si cambia el nombre del juego, se cambia aquí.
# Uso: bash tools/build_branding.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
OUT=assets/marca
mkdir -p "$OUT"
# Diafragma: aro blanco con un hexágono (las palas) y la pupila.
aperture() {  # tamaño, fichero
	local s=$1
	convert -size ${s}x${s} xc:none -fill none -stroke white -strokewidth $((s/14)) \
		-draw "circle $((s/2)),$((s/2)) $((s/2)),$((s/10))" \
		-strokewidth $((s/28)) \
		-draw "polygon $((s/2)),$((s*27/100)) $((s*70/100)),$((s*385/1000)) $((s*70/100)),$((s*615/1000)) $((s/2)),$((s*73/100)) $((s*30/100)),$((s*615/1000)) $((s*30/100)),$((s*385/1000))" \
		-draw "line $((s/2)),$((s*27/100)) $((s*60/100)),$((s*12/100))" \
		-draw "line $((s*70/100)),$((s*385/1000)) $((s*88/100)),$((s*40/100))" \
		-draw "line $((s*70/100)),$((s*615/1000)) $((s*78/100)),$((s*78/100))" \
		-draw "line $((s/2)),$((s*73/100)) $((s*40/100)),$((s*88/100))" \
		-draw "line $((s*30/100)),$((s*615/1000)) $((s*12/100)),$((s*60/100))" \
		-draw "line $((s*30/100)),$((s*385/1000)) $((s*22/100)),$((s*22/100))" \
		"$2"
}
TMP=$(mktemp -d)
aperture 220 "$TMP/a220.png"
aperture 176 "$TMP/a176.png"
convert -size 1280x720 gradient:'#155a8c'-'#2f9be8' \
	"$TMP/a220.png" -geometry +120+170 -composite \
	-font assets/fuentes/RussoOne-Regular.ttf -pointsize 80 -fill white -annotate +390+300 'PhotoHacks' \
	-font assets/fuentes/Roboto-Light.ttf -pointsize 28 -fill '#d6ecfb' -annotate +394+356 'Cargando el parque…' \
	-strip "$OUT/carga.png"
convert -size 256x256 xc:none -fill '#2f9be8' -draw "roundrectangle 8,8 247,247 52,52" \
	"$TMP/a176.png" -geometry +40+40 -composite -strip "$OUT/icono.png"
rm -r "$TMP"
# Las dos se importan como texturas normales (sus .import están versionados): el exportador ya mete
# por su cuenta el icono y la imagen de carga, y con importer="keep" entraban dos veces en el APK
# de Android, que no se podía firmar.
echo "BRANDING $OUT/carga.png $OUT/icono.png"
