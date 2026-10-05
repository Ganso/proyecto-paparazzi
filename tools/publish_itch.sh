#!/usr/bin/env bash
# Sube a itch.io (https://geese-bumps.itch.io/photohacks) lo que dejó ./tools/export_all.sh,
# con butler, la herramienta oficial de itch. Solo bajo demanda, como los ejecutables.
#
#   ./tools/publish_itch.sh [--only windows,linux,mac,android,html5] [--dry-run]
#
# Un canal por plataforma (el nombre le dice a itch qué es cada fichero):
#   windows  build/dist/PhotoHacks-<versión>-windows.zip
#   linux    build/dist/PhotoHacks-<versión>-linux.zip
#   mac      build/dist/PhotoHacks-<versión>-macos.zip
#   android  build/paparazzi-debug.apk                 (no se publica de momento: solo con --only)
#   html5    build/dist/PhotoHacks-<versión>-web.zip   (la versión que se juega en la ficha)
# La versión es la de export_presets.cfg. itch solo sube lo que cambia respecto a la anterior.
#
# Antes, una sola vez y a mano: `butler login` (abre el navegador; la sesión queda en
# ~/.config/itch/butler_creds). Y tras la primera subida de html5, en «Edit game» de la ficha:
# marcar ese fichero como «This file will be played in the browser» y el marco a 1280 × 720.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
TARGET="${ITCH_TARGET:-geese-bumps/photohacks}"
BUTLER="${BUTLER_BIN:-$(command -v butler || echo "$HOME/bin/butler")}"
# Android no se publica de momento (usuario, 05-10-2026): solo con --only android.
ONLY="windows,linux,mac,html5"
DRY=0
while [ $# -gt 0 ]; do
	case "$1" in
		--only) ONLY="$2"; shift 2 ;;
		--dry-run) DRY=1; shift ;;
		*) echo "Opción desconocida: $1" >&2; exit 2 ;;
	esac
done
[ -x "$BUTLER" ] || { echo "Falta butler ($BUTLER): https://itch.io/docs/butler/" >&2; exit 1; }
VERSION="$(grep -m1 'version/name=' export_presets.cfg | cut -d'"' -f2)"
declare -A FILE=(
	[windows]="build/dist/PhotoHacks-$VERSION-windows.zip"
	[linux]="build/dist/PhotoHacks-$VERSION-linux.zip"
	[mac]="build/dist/PhotoHacks-$VERSION-macos.zip"
	[android]="build/paparazzi-debug.apk"
	[html5]="build/dist/PhotoHacks-$VERSION-web.zip"
)
if [ "$DRY" = 0 ] && [ -z "${BUTLER_API_KEY:-}" ] && [ ! -s "$HOME/.config/itch/butler_creds" ]; then
	echo "butler no tiene sesión: ejecuta «butler login» una vez." >&2; exit 1
fi
echo "==> $TARGET · versión $VERSION"
failed=0
for channel in windows linux mac android html5; do
	case ",$ONLY," in *",$channel,"*) ;; *) continue ;; esac
	file="${FILE[$channel]}"
	if [ ! -s "$file" ]; then echo "  ✗ $channel: falta $file (./tools/export_all.sh)"; failed=1; continue; fi
	echo "  → $channel: $file ($(du -h "$file" | cut -f1), $(date -r "$file" '+%d-%m %H:%M'))"
	[ "$DRY" = 1 ] && continue
	"$BUTLER" push --if-changed "$file" "$TARGET:$channel" --userversion "$VERSION" || failed=1
done
[ "$DRY" = 1 ] && echo "(simulación: no se ha subido nada)" || "$BUTLER" status "$TARGET" || true
exit $failed
