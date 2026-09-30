#!/usr/bin/env bash
# Regenera los recursos gráficos del parque (docs/futuro/17 §2.2):
#   assets/parque/*.glb     mobiliario, vegetación, quiosco, estanque y torres (Blender, sin interfaz)
#   assets/texturas/*.webp  texturas procedurales del suelo (Python + numpy)
# Uso: ./tools/build_park_assets.sh [--only banco,farola]   (--only se aplica solo a Blender)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BLENDER="${BLENDER_BIN:-blender}"

echo "=== [1/2] Objetos del parque con Blender ==="
"$BLENDER" -b --factory-startup -P "$PROJECT_DIR/tools/blender/build_park_assets.py" -- "$@" 2>&1 | grep -E "^ASSET|Error|Traceback" || true

echo "=== [2/2] Texturas procedurales del suelo ==="
python3 "$PROJECT_DIR/tools/texturas/build_textures.py"
