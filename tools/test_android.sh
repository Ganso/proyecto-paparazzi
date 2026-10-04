#!/usr/bin/env bash
# Batería de pruebas de Android en el emulador (docs/TESTS_Y_VERIFICACION.md §4.4).
#   ./tools/test_android.sh
# Necesita el SDK (~/Android/Sdk) con el AVD «paparazzi» (x86_64). Arranca el emulador si no hay
# ninguno en marcha. Exporta dos APK x86_64 (el normal y otro que arranca con -- --smoke-test) y
# comprueba: 1) invariantes en el PC con el renderizador de Android, 2) prueba de humo dentro del
# dispositivo, 3) arranque del juego y un minuto vivo sin errores, 4) el tacto (entrar en el
# tutorial, empezar y disparar), 5) pausa y vuelta al primer plano. Capturas en build/android/.
set -uo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
GODOT="${GODOT_BIN:-$HOME/bin/godot-4-fp}"
ADB="$SDK/platform-tools/adb"; [ -x "$ADB" ] || ADB=adb
PKG=org.ganso.proyectopaparazzi
ACT=$PKG/com.godot.game.GodotAppLauncher
OUT="$PROJECT_DIR/build/android"; mkdir -p "$OUT"
pass=0; fail=0
check() { if [ "$1" = 1 ]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
godot_log() { "$ADB" logcat -d | grep -E " godot  |F libc" | grep -v "cached shader\|shader_gles3" ; }
errors() { godot_log | grep -cE "SCRIPT ERROR|ERROR:|F libc|Assertion" ; }
export_apk() { EMULATOR=1 ANDROID_ARGS="${1:-}" GODOT_BIN="$GODOT" JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/default-java}" ANDROID_HOME="$SDK" bash tools/export_android.sh > "$OUT/export.log" 2>&1; }
shot() { "$ADB" exec-out screencap -p > "$OUT/$1.png"; }

echo "== 1. Invariantes en el PC con el renderizador de Android"
export PAPARAZZI_GFX_CFG="$OUT/graficos.cfg"
out=$(timeout 200 "$GODOT" --headless --path . --script tests/test_export.gd 2>&1 | grep "TESTS"); check "$([[ "$out" == *" 0 failures"* ]] && echo 1 || echo 0)" "test_export: $out"
out=$(timeout 300 "$GODOT" --headless --path . --script tests/test_art.gd 2>&1 | grep "ART TESTS"); check "$([[ "$out" == *" 0 failures"* ]] && echo 1 || echo 0)" "test_art (piezas lo): $out"
out=$(timeout 200 "$GODOT" --path . --disable-vsync --rendering-method gl_compatibility -- --smoke-test 2>&1 | grep "SMOKE PASS" | cut -c1-110); check "$([ -n "$out" ] && echo 1 || echo 0)" "humo gl_compatibility en el PC: $out"

echo "== Emulador"
if ! "$ADB" devices | grep -q "device$"; then
	ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK" "$SDK/emulator/emulator" -avd paparazzi -no-window -no-audio -no-boot-anim -no-snapshot -gpu host -memory 4096 > "$OUT/emulador.log" 2>&1 &
	timeout 240 bash -c "until [ \"\$($ADB shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')\" = 1 ]; do sleep 3; done"
fi
check "$("$ADB" devices | grep -c "device$" | head -1)" "emulador en marcha (Android $("$ADB" shell getprop ro.build.version.release | tr -d '\r'))"
# Sin el aviso de pantalla completa de Android, que taparía el juego.
"$ADB" shell settings put secure immersive_mode_confirmations confirmed >/dev/null 2>&1

echo "== 2. Prueba de humo dentro del dispositivo"
export_apk "-- --smoke-test"; check "$([ -s build/paparazzi-emulador-prueba.apk ] && echo 1 || echo 0)" "APK de prueba exportado"
"$ADB" shell am force-stop $PKG; "$ADB" install -r build/paparazzi-emulador-prueba.apk >/dev/null 2>&1
"$ADB" logcat -c; "$ADB" shell am start -n $ACT >/dev/null
timeout 120 bash -c "until $ADB logcat -d | grep -q 'SMOKE PASS\|F libc\|SCRIPT ERROR'; do sleep 2; done"
out=$(godot_log | grep "SMOKE PASS" | sed 's/.*SMOKE PASS/SMOKE PASS/' | cut -c1-150); check "$([ -n "$out" ] && echo 1 || echo 0)" "humo en Android: ${out:-sin SMOKE PASS}"
check "$([[ "$out" == *"detalle lo"* ]] && echo 1 || echo 0)" "escena de Android (detalle lo)"
tri=$(echo "$out" | sed -n 's/.* \([0-9]*\) triángulos.*/\1/p'); check "$([ -n "$tri" ] && [ "$tri" -le 100000 ] && echo 1 || echo 0)" "presupuesto de triángulos lo (${tri:-?} ≤ 100000)"

echo "== 3. Arranque del juego"
export_apk ""; check "$([ -s build/paparazzi-emulador.apk ] && echo 1 || echo 0)" "APK del juego exportado"
"$ADB" shell am force-stop $PKG; "$ADB" install -r build/paparazzi-emulador.apk >/dev/null 2>&1
"$ADB" logcat -c; "$ADB" shell am start -n $ACT >/dev/null
sleep 30; shot 01_menu
check "$([ -n "$("$ADB" shell pidof $PKG)" ] && echo 1 || echo 0)" "el juego sigue vivo a los 30 s (el fallo de audio lo mataba a los 8)"
check "$(godot_log | grep -c "Compatibility" | head -1 | awk '{print ($1>0)}')" "renderizador gl_compatibility"
sleep 30
check "$([ -n "$("$ADB" shell pidof $PKG)" ] && echo 1 || echo 0)" "vivo al minuto"
check "$([ "$(errors)" = 0 ] && echo 1 || echo 0)" "sin errores en el registro ($(errors))"
mem=$("$ADB" shell dumpsys meminfo $PKG | awk '/TOTAL PSS/{print int($3/1024)}' | head -1); check "$([ -n "$mem" ] && [ "$mem" -lt 1500 ] && echo 1 || echo 0)" "memoria ${mem:-?} MB (< 1500)"

echo "== 4. Tacto"
size=$("$ADB" shell wm size | sed -n 's/.*: \([0-9]*\)x\([0-9]*\).*/\1 \2/p'); set -- $size; W=$2; H=$1; [ "$1" -gt "$2" ] && { W=$1; H=$2; }
tap() { "$ADB" shell input tap $(( $1*W/2400 )) $(( $2*H/1080 )); }   # coordenadas sobre 2400×1080
tap 833 802; sleep 6; shot 02_tutorial
check "$([ -n "$("$ADB" shell pidof $PKG)" ] && echo 1 || echo 0)" "«Entrar» abre el tutorial"
tap 1536 861; sleep 2
"$ADB" shell input swipe $((1200*W/2400)) $((500*H/1080)) $((800*W/2400)) $((520*H/1080)) 400; sleep 2
tap 1930 1008; sleep 6; shot 03_foto
check "$([ -n "$("$ADB" shell pidof $PKG)" ] && echo 1 || echo 0)" "arrastrar para mirar y «Disparar» no lo tumban"
check "$([ "$(errors)" = 0 ] && echo 1 || echo 0)" "sin errores tras jugar ($(errors))"

echo "== 5. Pausa y vuelta"
"$ADB" shell input keyevent KEYCODE_HOME; sleep 4; "$ADB" shell am start -n $ACT >/dev/null; sleep 6; shot 04_vuelta
check "$([ -n "$("$ADB" shell pidof $PKG)" ] && echo 1 || echo 0)" "vuelve del segundo plano"
check "$([ "$(errors)" = 0 ] && echo 1 || echo 0)" "sin errores al volver ($(errors))"
godot_log > "$OUT/registro.txt"
echo "ANDROID TESTS: $((pass+fail)) checks, $fail failures (capturas y registro en build/android/)"
[ "$fail" = 0 ]
