#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== [1/2] Renderizando estados, assets y cinemática con Godot 4 ==="
godot-4 --path "$PROJECT_DIR" --script "$PROJECT_DIR/tools/capture_evidence.gd"

echo "=== [2/2] Ensamblando spritesheets estructurados, GIFs y GALERIA.md ==="
python3 "$PROJECT_DIR/tools/build_sheets.py"

echo "=== Generación completa de evidencias finalizada con éxito ==="
