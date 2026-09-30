#!/usr/bin/env bash
# Capturas de Ultra (Forward+) a 2560 × 1440 para docs/evidencias/ultra/ (docs/futuro/17).
# Necesita un Godot con Vulkan: GODOT_FP, o ~/bin/godot-4-fp (el snap de godot-4 no arranca Vulkan).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT_FP:-$HOME/bin/godot-4-fp}"
OUT="$PROJECT_DIR/docs/evidencias/ultra"
if [ ! -x "$GODOT" ]; then
	echo "Sin Godot con Vulkan ($GODOT): se omiten las capturas de Ultra."
	exit 0
fi
mkdir -p "$OUT"
# nombre ángulo inclinación focal hora
while read -r name angle pitch focal time; do
	"$GODOT" --path "$PROJECT_DIR" --rendering-method forward_plus --resolution 2560x1440 -- \
		--screenshot="$OUT/$name.png" --angle="$angle" --pitch="$pitch" --focal="$focal" --time="$time" 2>&1 | grep -E "SCREENSHOT|ERROR" || true
done <<'VIEWS'
01_quiosco_dia 120 3 24 day
02_estanque_dia 245 3 24 day
03_quiosco_hora_dorada 120 3 24 golden
04_quiosco_noche 120 3 24 night
05_plaza_losas 200 -30 24 day
06_teleobjetivo_quiosco 120 1 85 day
07_fuente_teleobjetivo 245 -1.5 85 day
08_fuente_noche 245 -1.5 85 night
VIEWS
# Maniquíes de Ultra (hd, texturas de madera y tela) en primer plano.
"$GODOT" --path "$PROJECT_DIR" --rendering-method forward_plus --resolution 2560x1440 --script "$PROJECT_DIR/tools/preview_people.gd" -- \
	--hd --zoom=1.1 --x=0.4 --output="$OUT/09_maniquies_hd.png" 2>&1 | grep -E "PREVIEW|ERROR" || true
