#!/usr/bin/env bash
# Lanzador para Linux: busca un Godot 4 capaz de usar Vulkan (Forward+), que es el renderizador
# de escritorio del juego. El snap «godot-4» no arranca Vulkan (cae a OpenGL y carga la escena de
# Android), así que solo se usa como último recurso y avisando.
#   ./Jugar.sh [argumentos de Godot o del juego tras --]
# Orden: GODOT_BIN, GODOT_FP, ~/bin/godot-4-fp, un Godot*linux*x86_64 en la carpeta del proyecto o
# en ~/Descargas / ~/Downloads, godot/godot-4 del PATH que no sean snap, el flatpak oficial y, por
# último, el snap.
cd -- "$(dirname -- "$0")" || exit 1

is_snap() { [[ "$(readlink -f -- "$1" 2>/dev/null)" == */snap* ]]; }

candidates=()
[[ -n "${GODOT_BIN:-}" ]] && candidates+=("$GODOT_BIN")
[[ -n "${GODOT_FP:-}" ]] && candidates+=("$GODOT_FP")
candidates+=("$HOME/bin/godot-4-fp")
shopt -s nullglob
for f in ./Godot*linux*x86_64 "$HOME"/Descargas/Godot*linux*x86_64 "$HOME"/Downloads/Godot*linux*x86_64 \
	"$HOME"/Descargas/Godot*/Godot*linux*x86_64 "$HOME"/Downloads/Godot*/Godot*linux*x86_64; do
	candidates+=("$f")
done
shopt -u nullglob
for name in godot4 godot godot-4; do
	path="$(command -v "$name" 2>/dev/null)" && candidates+=("$path")
done

engine=""
for c in "${candidates[@]}"; do
	if [[ -x "$c" ]] && ! is_snap "$c"; then engine="$c"; break; fi
done

has_vulkan() {
	local ld; ld="$(command -v ldconfig || echo /sbin/ldconfig)"
	"$ld" -p 2>/dev/null | grep -q 'libvulkan\.so\.1' && return 0
	compgen -G "/usr/lib*/libvulkan.so.1" >/dev/null || compgen -G "/usr/lib/*/libvulkan.so.1" >/dev/null
}
if ! has_vulkan; then
	echo "Aviso: no se encuentra libvulkan.so.1. Instala el cargador de Vulkan y los controladores Mesa (mesa-vulkan-drivers)."
fi

if [[ -n "$engine" ]]; then
	exec "$engine" --path "$PWD" --rendering-method forward_plus "$@"
fi
if command -v flatpak >/dev/null 2>&1 && flatpak info org.godotengine.Godot >/dev/null 2>&1; then
	exec flatpak run --filesystem="$PWD" org.godotengine.Godot --path "$PWD" --rendering-method forward_plus "$@"
fi
snap_godot="$(command -v godot-4 2>/dev/null || command -v godot 2>/dev/null)"
if [[ -n "$snap_godot" ]]; then
	echo "Aviso: solo hay un Godot de snap, que no usa Vulkan: el juego se verá con la calidad de Android."
	echo "Descarga el Godot 4 oficial (godotengine.org) y deja el ejecutable en ~/bin/godot-4-fp o en esta carpeta."
	exec "$snap_godot" --path "$PWD" "$@"
fi
echo "No se encuentra Godot 4. Descárgalo de godotengine.org y deja el ejecutable en ~/bin/godot-4-fp, en esta carpeta o configura GODOT_BIN."
read -rp "Pulsa Intro para cerrar."
