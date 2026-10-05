#!/usr/bin/env bash
# Exporta el juego para Windows, Linux, macOS y Android (docs/TESTS_Y_VERIFICACION.md §4.2).
#
#   ./tools/export_all.sh [--only windows,linux,macos,android] [--debug]
#
# Genera en build/:
#   windows/PhotoHacks.exe          un solo ejecutable con el juego dentro (Forward+, Vulkan/D3D12)
#   linux/PhotoHacks.x86_64         ídem para Linux x86_64
#   macos/PhotoHacks.zip            aplicación universal (Intel y Apple Silicon), firma ad hoc
#   paparazzi-debug.apk                    Android (tools/export_android.sh, gl_compatibility)
# y en build/dist/ un .zip por plataforma de escritorio, listo para repartir.
#
# Necesita las plantillas de exportación de la MISMA versión de Godot que el editor
# (~/bin/godot-4-fp, hoy 4.7.2). Si faltan, el script lo dice y explica cómo instalarlas; no
# descarga nada por su cuenta. Android además necesita JDK 17 y el SDK (ver export_android.sh).
# macOS sin certificado: la app sale con firma ad hoc y en el Mac hay que abrirla con clic derecho
# → Abrir la primera vez (Gatekeeper).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT_BIN:-${GODOT_FP:-$HOME/bin/godot-4-fp}}"
ONLY="windows,linux,macos,android,web"
MODE="--export-release"
while [ $# -gt 0 ]; do
	case "$1" in
		--only) ONLY="$2"; shift 2 ;;
		--debug) MODE="--export-debug"; shift ;;
		*) echo "Opción desconocida: $1"; exit 1 ;;
	esac
done
want() { [[ ",$ONLY," == *",$1,"* ]]; }

VERSION_FULL="$("$GODOT" --version | head -1)"          # p. ej. 4.7.2.stable.official.ed1daf0bf
TEMPLATE_VERSION="$(echo "$VERSION_FULL" | cut -d. -f1-4)"   # 4.7.2.stable
TEMPLATES="${GODOT_TEMPLATES:-$HOME/.local/share/godot/export_templates/$TEMPLATE_VERSION}"
GAME_VERSION="$(grep -m1 'version/name=' "$PROJECT_DIR/export_presets.cfg" | cut -d'"' -f2)"
echo "==> Godot $VERSION_FULL · plantillas en $TEMPLATES · versión del juego $GAME_VERSION"

# Plantilla necesaria por plataforma (nombres de las plantillas oficiales de Godot 4).
declare -A NEED=( [windows]="windows_release_x86_64.exe" [linux]="linux_release.x86_64" [macos]="macos.zip" [web]="web_nothreads_release.zip" )
missing=()
for plat in windows linux macos web; do
	if want "$plat" && [ ! -f "$TEMPLATES/${NEED[$plat]}" ]; then missing+=("$plat (${NEED[$plat]})"); fi
done
if [ ${#missing[@]} -gt 0 ]; then
	echo
	echo "Faltan plantillas de exportación para: ${missing[*]}"
	echo "Instálalas una vez (≈1 GB) con la versión exacta del editor:"
	echo "  1. Descarga Godot_v${TEMPLATE_VERSION/.stable/-stable}_export_templates.tpz desde"
	echo "     https://github.com/godotengine/godot/releases/tag/${TEMPLATE_VERSION/.stable/-stable}"
	echo "  2. mkdir -p \"$TEMPLATES\" && unzip -j Godot_*_export_templates.tpz 'templates/*' -d \"$TEMPLATES\""
	echo "     (o en el editor: Editor → Gestionar plantillas de exportación → Instalar desde archivo)"
	echo
	echo "Sigo con las plataformas que sí se pueden exportar."
fi

mkdir -p "$PROJECT_DIR/build/dist"
ok=()
fail=()
export_desktop() {
	local plat="$1" preset="$2" out="$3"
	if [ ! -f "$TEMPLATES/${NEED[$plat]}" ]; then fail+=("$plat: sin plantilla"); return; fi
	mkdir -p "$(dirname "$PROJECT_DIR/$out")"
	rm -f "$PROJECT_DIR/$out"
	echo "==> Exportando $preset → $out"
	if "$GODOT" --headless --path "$PROJECT_DIR" "$MODE" "$preset" "$out" > "$PROJECT_DIR/build/export_$plat.log" 2>&1 && [ -s "$PROJECT_DIR/$out" ]; then
		local zip="$PROJECT_DIR/build/dist/PhotoHacks-$GAME_VERSION-$plat.zip"
		rm -f "$zip"
		if [ "$plat" = "macos" ]; then cp "$PROJECT_DIR/$out" "$zip"
		else (cd "$(dirname "$PROJECT_DIR/$out")" && zip -q -9 -r "$zip" .)
		fi
		ok+=("$plat: $out ($(du -h "$PROJECT_DIR/$out" | cut -f1)) · $(basename "$zip") ($(du -h "$zip" | cut -f1))")
	else
		fail+=("$plat: falló la exportación (build/export_$plat.log)")
		tail -5 "$PROJECT_DIR/build/export_$plat.log"
	fi
}
want windows && export_desktop windows "Windows" "build/windows/PhotoHacks.exe"
want linux && export_desktop linux "Linux" "build/linux/PhotoHacks.x86_64"
want macos && export_desktop macos "macOS" "build/macos/PhotoHacks.zip"
if want web; then
	if [ ! -f "$TEMPLATES/${NEED[web]}" ]; then fail+=("web: sin plantilla"); else
		mkdir -p "$PROJECT_DIR/build/web"
		echo "==> Exportando Web → build/web/index.html"
		if "$GODOT" --headless --path "$PROJECT_DIR" "$MODE" "Web" "$PROJECT_DIR/build/web/index.html" > "$PROJECT_DIR/build/export_web.log" 2>&1 && [ -s "$PROJECT_DIR/build/web/index.html" ]; then
			local_zip="$PROJECT_DIR/build/dist/PhotoHacks-$GAME_VERSION-web.zip"
			rm -f "$local_zip"
			(cd "$PROJECT_DIR/build/web" && zip -q -9 -r "$local_zip" .)
			ok+=("web: build/web/index.html · $(basename "$local_zip") ($(du -h "$local_zip" | cut -f1))")
		else
			fail+=("web: falló la exportación (build/export_web.log)")
			tail -5 "$PROJECT_DIR/build/export_web.log"
		fi
	fi
fi
if want android; then
	if GODOT_BIN="$GODOT" JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/default-java}" bash "$SCRIPT_DIR/export_android.sh" > "$PROJECT_DIR/build/export_android.log" 2>&1; then ok+=("android: build/paparazzi-debug.apk ($(du -h "$PROJECT_DIR/build/paparazzi-debug.apk" | cut -f1))")
	else fail+=("android: $(grep -m1 ERROR "$PROJECT_DIR/build/export_android.log" || echo 'ver build/export_android.log')"); fi
fi
echo
echo "==> Resultado"
for line in "${ok[@]}"; do echo "  ✓ $line"; done
for line in "${fail[@]+"${fail[@]}"}"; do echo "  ✗ $line"; done
[ ${#fail[@]} -eq 0 ]
