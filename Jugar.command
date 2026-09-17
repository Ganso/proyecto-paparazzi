#!/bin/zsh
cd -- "$(dirname -- "$0")"
if [[ -n "$GODOT_BIN" && -x "$GODOT_BIN" ]]; then
  exec "$GODOT_BIN" --path "$PWD"
fi
for paparazzi_engine in '/Applications/Godot copia.app/Contents/MacOS/Godot' '/Applications/Godot.app/Contents/MacOS/Godot'; do
  if [[ -x "$paparazzi_engine" ]]; then
    exec "$paparazzi_engine" --path "$PWD"
  fi
done
if command -v godot-4 >/dev/null 2>&1; then
  exec godot-4 --path "$PWD"
fi
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD"
fi
print 'No se encuentra Godot 4. Instálalo o configura GODOT_BIN con la ruta al ejecutable.'
read '?Pulsa Intro para cerrar.'
