# Manual de Pruebas y Verificación — Proyecto Paparazzi

Este documento es la **fuente única** de comandos de prueba y de cifras medidas del proyecto. El resto de documentos (README, AGENTS y los monográficos de `docs/`) enlazan aquí en lugar de repetir comandos o valores.

---

## 1. Clasificación Fundamental: Headless vs. Display

El motor se invoca como `godot-4` (en macOS u otros sistemas puede llamarse `godot`).

> [!WARNING]
> **REGLA CRÍTICA DE EJECUCIÓN**:
> Las pruebas que toman capturas o esperan fotogramas renderizados (`RenderingServer.frame_post_draw`) **NO DEBEN EJECUTARSE NUNCA CON `--headless`**. En modo headless el servidor de render no procesa fotogramas de dibujo y el proceso se congela indefinidamente.

| Tipo | Suites | Requisito |
|---|---|---|
| **Headless** | `test_photography`, `test_art`, `test_equipment`, `test_gait`, `test_export`, `tools/export_android.sh` | Ninguno (CI, servidor) |
| **Display** | `test_navigation`, `simulate_jams`, `test_expansion`, `test_game`, `--smoke-test`, `tools/run_evidence.sh` | Ventana X11 / Wayland con OpenGL 3.3 |

### Servidores sin pantalla (Xvfb)
Las suites con display funcionan en una máquina sin monitor con un servidor X virtual y renderizado por software (Mesa llvmpipe):
```bash
xvfb-run -a -s "-screen 0 1440x900x24" godot-4 --audio-driver Dummy --path . --script tests/test_game.gd
```
`--audio-driver Dummy` evita los avisos de ALSA cuando no hay tarjeta de sonido.

> [!NOTE]
> Con renderizado por software cada fotograma tarda más de 50 ms, así que la comprobación `Pan input under 50 ms` de `test_game.gd` (latencia real de un fotograma) falla bajo Xvfb. El resto de comprobaciones son válidas; la de latencia solo es significativa con GPU.

---

## 2. Suites en Modo Headless (Sin Pantalla)

| Suite | Comando | Qué valida | Línea de salida |
|---|---|---|---|
| **Óptica y determinismo** | `godot-4 --headless --path . --script tests/test_photography.gd` | CoC, profundidad de campo, error de EV, puntuación y determinismo (la misma evidencia da la misma nota) | `TESTS: N checks, N failures` |
| **Arte y mallas** | `godot-4 --headless --path . --script tests/test_art.gd` | Ensambla todas las combinaciones del catálogo en los 4 perfiles: ≤ 1.900 triángulos por viandante, 20 huesos, pesos rígidos. Además revisa las piezas: calzado con zona de color propia, muslo que rellena el asiento del pantalón (y no asoma bajo la falda), hombro no más ancho que la manga, falda más ancha que los muslos, visera de gorra solo hacia delante, color de zapato determinista, oclusión de vértices acotada y estilo maniquí (material toon con pase de contorno, acabado de madera sin tonos de piel, rótulas más gruesas que el miembro y paneles excluidos del contorno) | `ART TESTS: N assemblies, maximum N triangles/person, N failures` y `GARMENT CHECKS: N checks, N failures` |
| **Equipo** | `godot-4 --headless --path . --script tests/test_equipment.gd` | Cuerpos, objetivos, diafragmas, modos AF/MF, carrete, lectura de EV y rayos de oclusión | `EQUIPMENT TESTS: N checks, N failures` |
| **Marcha** | `godot-4 --headless --path . --script tests/test_gait.gd` | Pie de apoyo sin deslizamiento y suela a $y = 0$ en marcha y carrera | `GAIT TESTS: N checks, N failures, min sole y …, max contact drift …` |
| **Exportación Android** | `godot-4 --headless --path . --script tests/test_export.gd` | Preset `Android` de `export_presets.cfg`: ruta versionada `build/paparazzi-debug.apk`, datos JSON empaquetados, `docs/`, `tests/` y `tools/` excluidos, paquete `org.ganso.proyectopaparazzi`, solo `arm64-v8a`, firma activa, solo permiso de vibración, orientación `sensor_landscape`, ETC2/ASTC y excepción en `.gitignore` | `EXPORT TESTS: N checks, N failures` |

---

## 3. Suites con Entorno Gráfico (Requieren Display)

| Suite | Comando | Qué valida | Línea de salida |
|---|---|---|---|
| **Navegación** | `godot-4 --path . --script tests/test_navigation.gd` | Cruce en sentidos opuestos en el carril 1, adelantamiento de un corredor a un caminante y desvío ante un obstáculo estático | `NAVIGATION TESTS: N checks, N failures` |
| **Atascos (20 s)** | `godot-4 --path . --script tests/simulate_jams.gd` | 400 pasos a $\Delta t = 0.05\text{ s}$ sin jugador. Éxito: **0 viandantes con `stuck_time > 0.8 s`** | `Deadlocked pedestrians (stuck_time > 0.8s): N` |
| **Expansión** | `godot-4 --path . --script tests/test_expansion.gd` | Pantalla de encargo, ropa deportiva de corredores, nubes y EV, bloqueo de ISO con carrete y sandbox. Guarda capturas en `/tmp/paparazzi-*.png` | `EXPANSION TESTS: N checks, N failures` |
| **Sesión completa** | `godot-4 --path . --script tests/test_game.gd` | 5 encargos, entrada, disparo, revelado, flujo de pantallas y **VRAM < 60 MiB**. Guarda capturas en `/tmp/paparazzi-*.png` | `SESSION VIDEO MEMORY: …` y `GAME TESTS: N checks, N failures` |
| **Humo** | `godot-4 --path . -- --smoke-test` | 21 viandantes, 20 huesos por persona, ≤ 100.000 triángulos y expediente determinista | `SMOKE PASS: …` |

---

## 4. Herramientas y Opciones de Arranque

### 4.1 Opciones de línea de comandos de `main.gd`
Se pasan tras `--` (`godot-4 --path . -- <opción>`):

| Opción | Efecto |
|---|---|
| `--smoke-test` | Prueba de humo (§3) y salida. |
| `--metrics` | Tras 120 fotogramas en `SEARCH`, mide 600 fotogramas e imprime `METRICS frames=… median_ms=… p95_ms=… max_ms=… draw_calls=… shadow_draw_calls=…` (los draw calls son los del último fotograma del visor 3D, leídos con `RenderingServer.viewport_get_render_info`). Es la única medida de rendimiento disponible; no tiene umbral automatizado. |
| `--stress` | Confina a los viandantes en el sector $\theta \in [96^\circ, 144^\circ]$ para forzar congestión. |
| `--screenshot=<ruta>` | Guarda una captura del fotograma 100 en `<ruta>`. |

### 4.2 Scripts de `tools/`

| Herramienta | Comando | Función |
|---|---|---|
| `run_evidence.sh` | `./tools/run_evidence.sh` | Orquesta la suite de evidencias gráficas: ejecuta `capture_evidence.gd` y después `build_sheets.py`. Requiere display. |
| `capture_evidence.gd` | `godot-4 --path . --script tools/capture_evidence.gd` | Renderiza estados del juego, assets, el lineup y las vistas de revisión de personajes (frente, 3/4, perfil y espalda) y fotogramas de animación en `docs/evidencias/scratch/`. |
| `build_sheets.py` | `python3 tools/build_sheets.py` | Monta hojas de assets, GIFs y [`docs/evidencias/GALERIA.md`](evidencias/GALERIA.md). Requiere Pillow y `ffmpeg` en el `PATH` (sin él fallan los GIFs; `pip install imageio-ffmpeg` trae un binario). |
| `export_android.sh` | `./tools/export_android.sh` (`INSTALL=1` para instalar y lanzar con `adb`) | Exporta `build/paparazzi-debug.apk` en headless con el preset `Android` y la firma de depuración de `~/.android/debug.keystore` (la genera si falta). Busca Godot en `GODOT_BIN`, `Godot*_win64_console.exe` local, `godot-4` o `godot`; el JDK 17 y el SDK en `JAVA_HOME`/`ANDROID_HOME` o en `ANDROID_TOOLCHAIN` (`jdk17/` y `sdk/`, por defecto `D:/Android-toolchain` en Windows). Requiere las plantillas de exportación de Godot 4.7.2 y en el SDK `platform-tools`, `build-tools;35.0.1` y `platforms;android-35`. El APK se versiona en git: haz commit tras compilar. Ver [futuro/09](futuro/09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md). |
| `build_catalog.py` | `python3 tools/build_catalog.py` | Regenera `data/catalogo.json` y `data/piezas/`. |
| `preview_people.gd` | `godot-4 --path . --script tools/preview_people.gd` | Visor interactivo de vestuario y perfiles anatómicos. |
| `preview_gait.gd` | `godot-4 --path . --script tools/preview_gait.gd` | Visor interactivo de la marcha. |

---

## 5. Cifras de Referencia (Fuente Única)

Medidas el **2026-09-27** con **Godot 4.7-stable** (Linux; suites con display en GPU Radeon RX 6700 XT). Cada cifra es la que imprime la suite indicada; si cambia el código, vuelve a ejecutar la suite y actualiza esta tabla.

| Cifra | Valor | Límite (invariante) | Fuente |
|---|:---:|:---:|---|
| Comprobaciones de óptica | 535, 0 fallos | 0 fallos | `test_photography.gd` |
| Ensamblajes de personajes | 2.880, 0 fallos | 0 fallos | `test_art.gd` |
| Triángulos por viandante (**máximo** del catálogo) | 1.690 | ≤ 1.900 | `test_art.gd` |
| Comprobaciones de prendas | 701, 0 fallos | 0 fallos | `test_art.gd` |
| Comprobaciones de equipo | 561, 0 fallos | 0 fallos | `test_equipment.gd` |
| Comprobaciones de marcha | 8.840, 0 fallos | 0 fallos | `test_gait.gd` |
| Deriva máxima del pie de apoyo | 0.000000 m/fotograma | 0 | `test_gait.gd` |
| Comprobaciones de navegación | 10, 0 fallos | 0 fallos | `test_navigation.gd` |
| Viandantes atascados tras 20 s | 0 | 0 | `simulate_jams.gd` |
| Comprobaciones de expansión | 140, 0 fallos | 0 fallos | `test_expansion.gd` |
| Comprobaciones de sesión | 34, 0 fallos | 0 fallos | `test_game.gd` |
| VRAM en sesión completa | 50,51 MiB (texturas 40,93 · buffers 9,58) · en Windows con Intel Iris Xe, 56,60 MiB (texturas 40,93 · buffers 15,67; medido el 2026-09-29) | < 60 MiB | `test_game.gd` |
| Triángulos en escena (21 viandantes + parque) | 82.198 | ≤ 100.000 | `--smoke-test` |
| Draw calls del visor 3D (perfil Ultra, día) | 1.790 (medido el 2026-09-29 en Windows, Intel Iris Xe) | Objetivo: 1 parque + 2 por viandante, hoy **incumplido** (ver [futuro/16](futuro/16_PARQUE_ILUSTRADO_QUICK_WIN.md)) | `--metrics` |
| Tiempo de fotograma (perfil Ultra, día) | mediana 20,22 ms · p95 24,38 ms (medido el 2026-09-29, Intel Iris Xe) | Objetivo 16,7 ms (60 FPS), sin umbral automatizado | `--metrics` |
| Comprobaciones de exportación | 24, 0 fallos | 0 fallos | `test_export.gd` |
| Tamaño de `build/paparazzi-debug.apk` (arm64-v8a) | 28 MB | < 50 MB (aviso de GitHub; límite 100 MB) | `tools/export_android.sh` |

**Nota sobre `test_game.gd`**: bajo Xvfb pasaron 22 de 23 comprobaciones; la que falla es la de latencia de 50 ms (ver §1). Hay que confirmar los 23/23 en una máquina con GPU.

---

## 6. Tabla Resumen de Diagnóstico Rápido

| Si modificas… | Debes ejecutar obligatoriamente |
|---|---|
| **Geometría de piezas o `catalogo.json`** | `test_art.gd` |
| **Locomoción o `gait.gd`** | `test_gait.gd` |
| **Fórmulas ópticas, CoC o puntuación** | `test_photography.gd` |
| **Cámaras, objetivos o exposímetro** | `test_equipment.gd` |
| **Navegación, carriles o `park.gd`** | `test_navigation.gd` y `simulate_jams.gd` |
| **Interfaz, flujo de pantallas o memoria** | `test_game.gd` y `test_expansion.gd` |
| **`export_presets.cfg`, ajustes móviles de `project.godot` o `.gitignore`** | `test_export.gd` y `./tools/export_android.sh` |
| **Cambios visuales (shaders, mallas, escena)** | `./tools/run_evidence.sh` |
| **Cualquier cambio antes de dar por cerrada una tarea** | `godot-4 --path . -- --smoke-test` |
