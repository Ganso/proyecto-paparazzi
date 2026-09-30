#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Desktop profiles render in Forward+ (docs/futuro/17 §2.4): prefer a Godot with Vulkan.
GODOT="${GODOT_FP:-$HOME/bin/godot-4-fp}"
[ -x "$GODOT" ] || GODOT=godot-4

echo "=== [1/3] Renderizando estados, assets y cinemática con Godot 4 ==="
"$GODOT" --path "$PROJECT_DIR" --disable-vsync --script "$PROJECT_DIR/tools/capture_evidence.gd"

echo "=== [2/3] Ensamblando spritesheets estructurados, GIFs y GALERIA.md ==="
python3 "$PROJECT_DIR/tools/build_sheets.py"

echo "=== [3/3] Capturas de Ultra en Forward+ a 1440p (docs/futuro/17) ==="
"$PROJECT_DIR/tools/capture_ultra.sh"

echo "=== Generación completa de evidencias finalizada con éxito ==="
