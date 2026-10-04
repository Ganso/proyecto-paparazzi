#!/usr/bin/env bash
# Exporta build/paparazzi-debug.apk (arm64-v8a, firmado con keystore de depuración).
# El APK se versiona en el repositorio: tras compilar, haz commit de build/paparazzi-debug.apk.
#
# Variables opcionales:
#   GODOT_BIN          Ejecutable de Godot 4.7 (por defecto: Godot*_win64_console.exe local, godot-4 o godot).
#   JAVA_HOME          JDK 17.
#   ANDROID_HOME       Android SDK con platform-tools y build-tools.
#   ANDROID_TOOLCHAIN  Carpeta con jdk17/ y sdk/ (por defecto D:/Android-toolchain en Windows).
#   INSTALL=1          Instala y lanza el APK con adb si hay un dispositivo conectado.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APK_REL="build/paparazzi-debug.apk"
APK="$PROJECT_DIR/$APK_REL"
PACKAGE="org.ganso.proyectopaparazzi"

is_windows=0
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) is_windows=1 ;; esac

# Godot y sus herramientas nativas de Windows necesitan rutas C:\...
native_path() {
	if [ "$is_windows" = 1 ]; then cygpath -w "$1"; else printf '%s' "$1"; fi
}

echo "==> [Paparazzi] Comprobando entorno de exportación Android..."

# 1. Godot: GODOT_BIN, ejecutable local de Windows (versión de consola, para ver la salida) o PATH.
if [ -z "${GODOT_BIN:-}" ]; then
	for candidate in $(ls -r "$PROJECT_DIR"/Godot*_win64_console.exe 2>/dev/null); do
		GODOT_BIN="$candidate"; break
	done
fi
if [ -z "${GODOT_BIN:-}" ]; then
	GODOT_BIN="$(command -v godot-4 || command -v godot || true)"
fi
if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
	echo "ERROR: no se encuentra Godot 4. Configura GODOT_BIN." >&2
	exit 1
fi

# 2. JDK 17 y Android SDK.
if [ -z "${ANDROID_TOOLCHAIN:-}" ] && [ "$is_windows" = 1 ]; then
	ANDROID_TOOLCHAIN="/d/Android-toolchain"
fi
if [ -z "${JAVA_HOME:-}" ] && [ -n "${ANDROID_TOOLCHAIN:-}" ] && [ -d "$ANDROID_TOOLCHAIN/jdk17" ]; then
	JAVA_HOME="$ANDROID_TOOLCHAIN/jdk17"
fi
if [ -z "${ANDROID_HOME:-}" ]; then
	if [ -n "${ANDROID_TOOLCHAIN:-}" ] && [ -d "$ANDROID_TOOLCHAIN/sdk" ]; then
		ANDROID_HOME="$ANDROID_TOOLCHAIN/sdk"
	else
		ANDROID_HOME="$HOME/Android/Sdk"
	fi
fi
JAVA_HOME="$(cd "${JAVA_HOME:?ERROR: configura JAVA_HOME con un JDK 17}" && pwd)"
if [ ! -d "$ANDROID_HOME/platform-tools" ] || [ ! -d "$ANDROID_HOME/build-tools" ]; then
	echo "ERROR: Android SDK incompleto en $ANDROID_HOME (faltan platform-tools o build-tools)." >&2
	exit 1
fi
ANDROID_HOME="$(cd "$ANDROID_HOME" && pwd)"
KEYTOOL="$JAVA_HOME/bin/keytool"
ADB="$ANDROID_HOME/platform-tools/adb"
if [ "$is_windows" = 1 ]; then KEYTOOL="$KEYTOOL.exe"; ADB="$ADB.exe"; fi

# 3. Keystore de depuración.
KEYSTORE_PATH="$HOME/.android/debug.keystore"
if [ ! -f "$KEYSTORE_PATH" ]; then
	echo "==> Generando debug.keystore local..."
	mkdir -p "$(dirname "$KEYSTORE_PATH")"
	"$KEYTOOL" -genkeypair -keystore "$(native_path "$KEYSTORE_PATH")" -storepass android \
		-alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
		-validity 10000 -dname "CN=Android Debug,O=Android,C=US"
fi

# Godot lee el SDK de JAVA_HOME/ANDROID_HOME y la firma de estas variables.
export JAVA_HOME="$(native_path "$JAVA_HOME")"
export ANDROID_HOME="$(native_path "$ANDROID_HOME")"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$(native_path "$KEYSTORE_PATH")"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

# Para el emulador (x86_64): EMULATOR=1 exporta build/paparazzi-emulador.apk con esa arquitectura,
# sin tocar el APK que se reparte (arm64). El de ARM, traducido en un emulador x86, revienta en el
# hilo de audio del traductor: no sirve para probar. El preajuste se restaura al terminar.
if [ "${EMULATOR:-0}" = 1 ]; then
	APK_REL="build/paparazzi-emulador.apk"
	APK="$PROJECT_DIR/$APK_REL"
	cp "$PROJECT_DIR/export_presets.cfg" "$PROJECT_DIR/export_presets.cfg.bak"
	trap 'mv -f "$PROJECT_DIR/export_presets.cfg.bak" "$PROJECT_DIR/export_presets.cfg"' EXIT
	sed -i 's|^architectures/arm64-v8a=true|architectures/arm64-v8a=false|; s|^architectures/x86_64=false|architectures/x86_64=true|' "$PROJECT_DIR/export_presets.cfg"
	# ANDROID_ARGS="-- --smoke-test": argumentos de arranque dentro del APK de pruebas.
	if [ -n "${ANDROID_ARGS:-}" ]; then
		APK_REL="build/paparazzi-emulador-prueba.apk"
		APK="$PROJECT_DIR/$APK_REL"
		sed -i "s|^architectures/x86_64=true|architectures/x86_64=true\ncommand_line/extra_args=\"$ANDROID_ARGS\"|" "$PROJECT_DIR/export_presets.cfg"
	fi
fi

# 4. Exportación headless.
mkdir -p "$PROJECT_DIR/build"
rm -f "$APK"
echo "==> Exportando APK con $(basename "$GODOT_BIN")..."
"$GODOT_BIN" --headless --path "$(native_path "$PROJECT_DIR")" --export-debug "Android" "$APK_REL"
if [ ! -s "$APK" ]; then
	echo "ERROR: Godot no ha generado $APK_REL." >&2
	exit 1
fi
echo "==> Compilación finalizada con éxito: $APK_REL ($(du -h "$APK" | cut -f1))"

# 5. Despliegue opcional por ADB.
if [ "${INSTALL:-0}" = 1 ]; then
	if "$ADB" devices | grep -q "device$"; then
		echo "==> Dispositivo Android detectado. Instalando y ejecutando..."
		"$ADB" install -r "$(native_path "$APK")"
		"$ADB" shell am start -n "$PACKAGE/com.godot.game.GodotAppLauncher"
	else
		echo "==> No hay ningún dispositivo conectado por ADB."
	fi
fi
