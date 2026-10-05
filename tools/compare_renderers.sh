#!/usr/bin/env bash
# Compara la imagen de Forward+ (Vulkan, Metal) con la de gl_compatibility (OpenGL: Android y web)
# en el mismo plano y a las cuatro luces: brillo medio, contraste (desviación), sombras (p5),
# luces (p95) y saturación. Sirve para calibrar park.gd::LO_EXPOSURE y LO_AMBIENT: las dos escenas
# no son iguales (la de OpenGL es la ligera), pero su impacto visual debe parecerse.
#   ./tools/compare_renderers.sh [solo_gl]      → build/comparativa/ y una tabla
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT="${GODOT_BIN:-$HOME/bin/godot-4-fp}"
OUT=build/comparativa; mkdir -p "$OUT"
export PAPARAZZI_GFX_CFG="$PWD/$OUT/graficos.cfg"
RENDERERS="forward_plus gl_compatibility"; [ "${1:-}" = solo_gl ] && RENDERERS="gl_compatibility"
for t in day golden blue night; do for a in 120 245; do for r in $RENDERERS; do
	timeout 120 "$GODOT" --path . --disable-vsync --rendering-method $r --resolution 1280x720 -- --screenshot="$PWD/$OUT/${t}_${a}_$r.png" --angle=$a --pitch=-3 --focal=28 --time=$t --hud=0 --profile=Medio >/dev/null 2>&1 || true
done; done; done
python3 - "$OUT" <<'PY'
import sys
from PIL import Image, ImageStat
D = sys.argv[1] + "/"
def stats(path):
    im = Image.open(path).convert("RGB").resize((320, 180))
    lum = im.convert("L"); s = ImageStat.Stat(lum); h = lum.histogram(); n = sum(h)
    def pct(q):
        c = 0
        for i, v in enumerate(h):
            c += v
            if c >= n * q: return i
    return s.mean[0], s.stddev[0], pct(.05), pct(.95), ImageStat.Stat(im.convert("HSV")).mean[1]
print("luz    plano | Forward+: brillo contraste p5 p95 sat | OpenGL: brillo contraste p5 p95 sat | brillo GL/F+")
for t in ["day", "golden", "blue", "night"]:
    for a in ["120", "245"]:
        f = stats(D + f"{t}_{a}_forward_plus.png"); g = stats(D + f"{t}_{a}_gl_compatibility.png")
        print(f"{t:6} {a}   | {f[0]:5.1f} {f[1]:5.1f} {f[2]:3d} {f[3]:3d} {f[4]:5.1f} | {g[0]:5.1f} {g[1]:5.1f} {g[2]:3d} {g[3]:3d} {g[4]:5.1f} | {g[0]/f[0]:.2f}")
PY
