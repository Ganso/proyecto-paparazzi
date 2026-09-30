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
>
> Lo mismo ocurre en Wayland (KDE) si la ventana de la prueba queda tapada por otra: el compositor deja de entregar fotogramas y la sincronía vertical espera ~1.000 ms. Pasa también con el código anterior. Añade `--disable-vsync` al comando (`godot-4 --path . --disable-vsync --script tests/test_game.gd`).

### Forward+ (Vulkan) en escritorio
Los cuatro perfiles de escritorio usan el renderizador `forward_plus` (`project.godot`; [futuro/17 §2.4](futuro/17_SALTO_GRAFICO_ULTRA.md)); `gl_compatibility` queda para Android. **En esta máquina todas las suites se ejecutan con `~/bin/godot-4-fp`**: con el snap `godot-4` el juego cae a OpenGL y prueba la escena de Android. En el equipo de desarrollo el Godot del snap (`godot-4`) no arranca Vulkan (trae sus drivers vacíos) y cae a OpenGL, así que Ultra se ejecuta con el **binario oficial de Godot 4.7.2** instalado en `~/.local/opt/godot/` y enlazado como `~/bin/godot-4-fp`. Ese binario tampoco depende del sandbox del snap, que no puede escribir en `/tmp`.

```bash
~/bin/godot-4-fp --path . --rendering-method forward_plus -- --smoke-test
~/bin/godot-4-fp --path . --rendering-method forward_plus --resolution 2560x1440 -- --metrics
~/bin/godot-4-fp --path . --rendering-method forward_plus --disable-vsync --script tests/test_game.gd
```

`--rendering-method` en la línea de comandos manda sobre `override.cfg`, que es donde el juego guarda el perfil elegido. Las suites de `gl_compatibility` se ejecutan igual con `godot-4` o con `~/bin/godot-4-fp --rendering-method gl_compatibility`.

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
| **Multitud (60 s)** | `~/bin/godot-4-fp --path . --disable-vsync --script tests/test_crowd.gd` | 1.800 pasos a 30 Hz con los 21 viandantes: la orientación gira como mucho $125^\circ/\text{s}$ (sin saltos), nadie invierte su desplazamiento lateral dos veces en menos de 1,5 s (sin temblequeo), dos caminantes nunca quedan a menos de 0,42 m y nadie sigue atascado al final. Con `CROWD_DEBUG=1` imprime cada inversión rápida | `CROWD: max turn …°/s, worst quick lateral reversals …, min gap … m, mean walking speed … m/s, jammed …` y `CROWD TESTS: N checks, N failures` |
| **Vida en el parque** | `~/bin/godot-4-fp --path . --disable-vsync --script tests/test_park_life.gd` | Siguen siendo 21 viandantes; figurantes fuera de la lista, sin colisionadores y más allá de 12,8 m también andando; palomas sin colisionadores, baratas y en el suelo; perro con dueño, con colisionador fuera de la capa 2 y etiquetado, dentro de la correa; ciclo completo del banco (acercarse, sentarse mirando al camino con la cadera en el asiento, levantarse y liberarlo) sin teletransportes (< 6 cm por fotograma); dos caminantes que se cruzan se paran a charlar frente a frente; cada actividad muestra su objeto de mano, sin colisionadores, y lo oculta al acabar; la luz del móvil no proyecta sombras. Con `LIFE_DEBUG=1` traza la aproximación al banco | `PARK LIFE TESTS: N checks, N failures` |
| **Atascos (20 s)** | `godot-4 --path . --script tests/simulate_jams.gd` | 400 pasos a $\Delta t = 0.05\text{ s}$ sin jugador. Éxito: **0 viandantes con `stuck_time > 0.8 s`** | `Deadlocked pedestrians (stuck_time > 0.8s): N` |
| **Expansión** | `godot-4 --path . --script tests/test_expansion.gd` | Pantalla de encargo, ropa deportiva de corredores, nubes y EV, bloqueo de ISO con carrete y sandbox. Guarda capturas en `/tmp/paparazzi-*.png` | `EXPANSION TESTS: N checks, N failures` |
| **Sesión completa** | `godot-4 --path . --script tests/test_game.gd` | 5 encargos, entrada, disparo, revelado, flujo de pantallas, **VRAM del perfil** (60.000.000 bytes en `gl_compatibility`, 8 GiB en Forward+), perfil inicial y nivel de detalle según el renderizador, superficies del parque fusionado (≤ 40 en `lo`, ≤ 80 en `hd` por el suelo texturizado) y suelo texturizado solo en `hd`. Guarda capturas en `/tmp/paparazzi-*.png` | `SESSION VIDEO MEMORY: …` y `GAME TESTS: N checks, N failures` |
| **Humo** | `godot-4 --path . -- --smoke-test` | 21 viandantes, 20 huesos por persona, presupuestos del perfil (escena ≤ 100.000 triángulos y ≤ 1.900 por viandante en `lo`; ≤ 5.000.000 y ≤ 60.000 en `hd`; los 20 huesos se cuentan sin los secundarios de pelo y ropa; la escena incluye figurantes y palomas, y comprueba que los figurantes no tienen colisionadores) y expediente determinista | `SMOKE PASS: 21 viandantes (+N figurantes, N palomas), … (límite …, perfil …, detalle …, máximo por viandante …)` |

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
| `--profile=<Bajo\|Medio\|Alto\|Ultra>` | Fuerza el perfil gráfico (si no, el guardado en `override.cfg` o el de la primera vez: Ultra con GPU dedicada, Alto en otro caso). Ultra solo es real en Forward+; en `gl_compatibility` aplica sus valores sin los efectos de Forward+. |
| `--time=<day\|golden\|night>` | Hora del día de la sesión que abren `--smoke-test`, `--metrics` y `--screenshot`. |
| `--angle=<grados>`, `--pitch=<grados>`, `--focal=<mm>` | Encuadre fijo para las capturas (azimut, inclinación y focal). |
| `--lens=<cuerpo>,<objetivo>`, `--pan=<°/s>`, `--zoom-to=<mm>`, `--follow`, `--follow-target`, `--mf-rack`, `--expose`, `--shoot-at=<s>`, `--af`, `--hud=0` | Cámara guionizada para el vídeo de evidencias (`main.gd::update_demo()`): equipo, paneo continuo, zoom progresivo en 12 s, seguimiento centrado y enfocado de un viandante de los carriles medios (`--follow`) o del objetivo del encargo, que pasa a un viandante del carril exterior (`--follow-target`), enfoque manual de 1,2 m al sujeto en 5 s (`--mf-rack`), exposición medida sobre el sujeto (`--expose`, `main.gd::expose_for()`), disparo a los `s` segundos, autofoco cada medio segundo y HUD oculto. Arranca la sesión como `--screenshot`. |
| `--advance=<s>` | Antes de la captura, simula `s` segundos de vida del parque (viandantes, palomas y perro) a 30 Hz, para fotografiar bancos ocupados, charlas y actividades. |
| `--activity=<actividad>` | Tras `--advance`, todos los caminantes que no corren se paran y hacen esa actividad (`movil`, `leer`, `foto`, `cafe`, `charla`, `mirar`, `palomas`), y los parados y sentados también; luego simula 8 s más para que las posturas entren y las palomas lleguen. Solo para evidencias. |
| `--burst=<n>` | Con `--screenshot=<ruta>.png`, guarda `n` fotogramas seguidos (`<ruta>_000.png`, …) para cazar artefactos de un solo fotograma. |
| `--debug-off=<lista>` | Apaga efectos para aislar artefactos (lista en [futuro/17 §2.5](futuro/17_SALTO_GRAFICO_ULTRA.md)); `nanview` pinta de magenta los píxeles no finitos. |
| `--metrics` (Forward+) | Además imprime `METRICS_GPU profile=… renderer=… time=… resolution=… gpu_median_ms=… gpu_p95_ms=… render_cpu_median_ms=… primitives=… vram_mib=…`. Desactiva la sincronía vertical para medir el coste real. |

### 4.2 Scripts de `tools/`

| Herramienta | Comando | Función |
|---|---|---|
| `run_evidence.sh` | `./tools/run_evidence.sh` | Orquesta la suite de evidencias gráficas: ejecuta `capture_evidence.gd`, `build_sheets.py` y `capture_ultra.sh`. Requiere display. |
| `capture_evidence.gd` | `godot-4 --path . --script tools/capture_evidence.gd` | Renderiza estados del juego, assets, el lineup y las vistas de revisión de personajes (frente, 3/4, perfil y espalda) y fotogramas de animación en `docs/evidencias/scratch/`. |
| `build_sheets.py` | `python3 tools/build_sheets.py` | Monta hojas de assets, GIFs y [`docs/evidencias/GALERIA.md`](evidencias/GALERIA.md). Requiere Pillow y `ffmpeg` en el `PATH` (`pip install imageio-ffmpeg` trae un binario). Los GIF se montan con el *demuxer* `concat` y una lista de fotogramas, que funciona también en Windows (sus compilaciones de ffmpeg no admiten `-pattern_type glob`). |
| `export_android.sh` | `./tools/export_android.sh` (`INSTALL=1` para instalar y lanzar con `adb`) | Exporta `build/paparazzi-debug.apk` en headless con el preset `Android` y la firma de depuración de `~/.android/debug.keystore` (la genera si falta). Busca Godot en `GODOT_BIN`, `Godot*_win64_console.exe` local, `godot-4` o `godot`; el JDK 17 y el SDK en `JAVA_HOME`/`ANDROID_HOME` o en `ANDROID_TOOLCHAIN` (`jdk17/` y `sdk/`, por defecto `D:/Android-toolchain` en Windows). Requiere las plantillas de exportación de Godot 4.7.2 y en el SDK `platform-tools`, `build-tools;35.0.1` y `platforms;android-35`. El APK se versiona en git: haz commit tras compilar. Ver [futuro/09](futuro/09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md). |
| `build_catalog.py` | `python3 tools/build_catalog.py` | Regenera `data/catalogo.json` y `data/piezas/` (piezas base: colisionadores y Android). `--lod hd` está desactivado: `data/piezas_hd/` se genera con Blender. Aviso: las normales de `data/piezas/` versionadas ya no coinciden bit a bit con las que genera el script actual (la geometría sí); no regenerar la base sin revisar `test_art.gd`. |
| `preview_people.gd` | `godot-4 --path . --script tools/preview_people.gd -- [--hd] [--zoom=<m>] [--x=<m>] [--output=<png>]` | Lineup de seis maniquíes. `--hd` usa los de Ultra con texturas procedurales (ejecutar con Forward+); `--zoom` y `--x` encuadran de cerca. |
| `build_park_assets.sh` | `./tools/build_park_assets.sh [--only banco,farola]` | Regenera los objetos del parque con Blender (`tools/blender/build_park_assets.py`, sin interfaz) y las texturas del suelo (`tools/texturas/build_textures.py`, Python + numpy). Requiere Blender 4.3 en el `PATH` (o `BLENDER_BIN`). |
| `blender/build_park_assets.py` | `blender -b --factory-startup -P tools/blender/build_park_assets.py -- [--only …] [--no-bake]` | Genera `assets/parque/*.glb` (mallas `hd` y `lo`, color y oclusión horneados con Cycles en el color de vértice). |
| `blender/preview_assets.py` | `blender -b --factory-startup -P tools/blender/preview_assets.py -- <png> [nombres]` | Hoja de vista previa de los objetos (fila `hd` delante, `lo` detrás). |
| `texturas/build_textures.py` | `python3 tools/texturas/build_textures.py [--size 2048] [--only …]` | Texturas periódicas del suelo en `assets/texturas/` (color, normal y ORM). |
| `capture_characters.gd` | `~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 800x1000 --script tools/capture_characters.gd -- [--only=torsos,cabezas] [--out=<dir>]` | Hojas de modelado de personajes en `docs/evidencias/personajes_modelado/`: catálogo por ranura en cuatro vistas, perfiles, articulaciones en marcha, ciclos, sentado, `09_dinamica` (andar y pararse en seco, para el movimiento de falda, pelo y bolso) y `10_actividades` (posturas y objetos de mano de la vida en el parque). Deja reposar los muelles antes de cada vista. **Con la ventana tapada en Wayland se cuelga si no se pasa `--disable-vsync`** (el compositor deja de dar fotogramas). |
| `audio/build_ambience.py` | `python3 tools/audio/build_ambience.py` | Sintetiza el sonido ambiente en `assets/audio/ambiente/` (pájaros, fuente, grillos, viento, ciudad, zureo y aleteo; WAV mono de 22,05 kHz). Requiere numpy y scipy. Ver [ESCENARIO_Y_RENDIMIENTO.md §3.4](ESCENARIO_Y_RENDIMIENTO.md). |
| `blender/build_characters.py` | `blender -b --factory-startup -P tools/blender/build_characters.py -- [--only <perfil>] [--slots <ranuras>]` | Genera maniquíes, ropa, pelucas y accesorios de escritorio en `data/piezas_hd/` ([futuro/18](futuro/18_PERSONAJES_BLENDER.md)). La simulación de tela de la falda hace que los cuatro perfiles tarden unos 2,5 min. |
| `capture_video.sh` | `./tools/capture_video.sh [--only 1,3] [--res 1920x1080] [--out <mp4>]` | **Vídeo de evidencias bajo demanda, solo para cambios grandes.** Graba 8 secuencias de 15 s con el Movie Maker de Godot (`--write-movie`, 30 FPS fijos: el resultado no depende de la velocidad del equipo) en día, hora dorada y noche, con gran angular, teleobjetivo siguiendo a un viandante, zoom y paneos, y una última con la **telemétrica de 90 mm en enfoque manual**: gira el anillo hasta alinear la imagen partida, mide la luz del sujeto, dispara y muestra el revelado puntuado (94/100 en la prueba). Las monta con ffmpeg (libx264) en un MP4 rotulado de 2 min en `build/video/` (ignorado por git), con la **música de fondo del proyecto** (`assets/audio/musica_videos.mp3`, o la variable `MUSIC`) recortada a la duración del vídeo con fundido de entrada de 1 s y de salida en los últimos 10 s. Tarda unos 6 min. |
| `capture_ultra.sh` | `./tools/capture_ultra.sh` | Capturas de Ultra a 2560 × 1440 en `docs/evidencias/ultra/` (lo llama `run_evidence.sh`; se omite si no hay Godot con Vulkan en `GODOT_FP` o `~/bin/godot-4-fp`). |
| `preview_gait.gd` | `godot-4 --path . --script tools/preview_gait.gd` | Visor interactivo de la marcha. |

---

## 5. Cifras de Referencia (Fuente Única)

Medidas el **2026-09-27** con **Godot 4.7-stable** (Linux; suites con display en GPU Radeon RX 6700 XT) y actualizadas el **2026-09-30** con el salto gráfico ([futuro/17](futuro/17_SALTO_GRAFICO_ULTRA.md)). Cada cifra es la que imprime la suite indicada; si cambia el código, vuelve a ejecutar la suite y actualiza esta tabla.

| Cifra | Valor | Límite (invariante) | Fuente |
|---|:---:|:---:|---|
| Comprobaciones de óptica | 535, 0 fallos | 0 fallos | `test_photography.gd` |
| Ensamblajes de personajes | 2.880, 0 fallos | 0 fallos | `test_art.gd` |
| Triángulos por viandante (**máximo** del catálogo) | 1.690 | ≤ 1.900 | `test_art.gd` |
| Comprobaciones de prendas | 701, 0 fallos | 0 fallos | `test_art.gd` |
| Comprobaciones de equipo | 561, 0 fallos | 0 fallos | `test_equipment.gd` |
| Comprobaciones de marcha | 8.840, 0 fallos | 0 fallos | `test_gait.gd` |
| Deriva máxima del pie de apoyo | 0.000000 m/fotograma | 0 | `test_gait.gd` |
| Comprobaciones de navegación | 10, 0 fallos (marcha suave, 2026-09-30) | 0 fallos | `test_navigation.gd` |
| Multitud en 60 s | giro máximo 120°/s · 1 inversión lateral rápida en el peor caso · separación mínima 0,58 m · 0,64 m/s de media andando · 0 atascados (2026-09-30) | ≤ 125°/s · ≤ 2 · ≥ 0,42 m · 0 | `test_crowd.gd` |
| Comprobaciones de vida en el parque | 116, 0 fallos (2026-09-30) | 0 fallos | `test_park_life.gd` |
| Viandantes atascados tras 20 s | 0 en Linux (2026-09-27 y de nuevo el 2026-09-30 con la marcha suave y el carril 0 ensanchado) · 1 en Windows con Intel Iris Xe (2026-09-29, código anterior) | 0 | `simulate_jams.gd` |
| Comprobaciones de expansión | 140, 0 fallos | 0 fallos | `test_expansion.gd` |
| Comprobaciones de sesión | Forward+: 52, 0 fallos (incluye pesos suaves de la ropa `hd`) · `gl_compatibility` (escena de Android): 48, 1 fallo, el de VRAM (58,37 MiB) (con `--disable-vsync`; 2026-09-30, RX 6700 XT) | 0 fallos | `test_game.gd` |
| Tiempo de GPU por perfil a 2560 × 1440, día | Ultra 10,94 ms · Alto 7,84 · Medio 3,93 · Bajo 2,16 (VRAM 1.525 / 1.413 / 1.196 / 766 MiB; 2026-09-30) | Ultra ≤ 12 ms | `--metrics --profile=<p>` |
| Destellos (píxeles no finitos) | 0 en 300 fotogramas (tres ráfagas de 100, 24–35 mm, día y hora dorada; 2026-09-30) | 0 | `--burst` + detector |
| VRAM en sesión completa | `gl_compatibility`: **59,91 MiB** (texturas 40,93 · buffers 18,98), **supera** el límite desde el parque de Blender y la pradera; pendiente de optimizar ([futuro/17 §6](futuro/17_SALTO_GRAFICO_ULTRA.md)) · Forward+ Ultra: 1.104 MiB en `test_game.gd`, 1.509 MiB en `--metrics` a 1440p | 60.000.000 bytes en `gl_compatibility` · 8 GiB en Ultra | `test_game.gd`, `--metrics` |
| Triángulos en escena (21 viandantes + parque) | `lo` (Android y respaldo sin Vulkan): 94.112 (2026-09-30, tras dibujar en `lo` solo parte de los árboles lejanos; antes había subido a 108.498) · `hd`: ver la fila siguiente | `lo` ≤ 100.000 · `hd` ≤ 5.000.000 | `--smoke-test` (`--rendering-method gl_compatibility` para `lo`) |
| Triángulos por maniquí `hd` (máximo en escena) | 41.436 (maniquíes de Blender con peluca y ropa; 2026-09-30) | ≤ 60.000 | `--smoke-test` en Forward+ |
| Triángulos en escena `hd` | 3.391.125 con 14 figurantes y 18 palomas (2.915.193 sin ellos; 2026-09-30) | ≤ 5.000.000 | `--smoke-test` en Forward+ |
| Tiempo de GPU de Ultra a 2560 × 1440 (RX 6700 XT, sin vsync) | día 10,30 ms (p95 10,52) · noche 11,80 ms (p95 12,10), con profundidad de campo, LUT y carácter de objetivo; sin la profundidad de campo, 7,27 y 8,86 ms (2026-09-30) | Objetivo ≤ 12 ms de día y ≤ 16 ms de noche | `--metrics` (Forward+) |
| Draw calls del visor 3D (perfil Ultra, día) | 119 en `--metrics` · 85 en `test_game.gd` (2026-09-29, Windows, Intel Iris Xe; antes del paso 1, 1.790) | ≤ 300 de día | `--metrics`, `test_game.gd` |
| Tiempo de fotograma (perfil Ultra, día) | mediana 16,67 ms · p95 16,67 ms, limitado por sincronía vertical (2026-09-29, Intel Iris Xe; antes 20,22 ms) | Objetivo 16,7 ms (60 FPS), sin umbral automatizado | `--metrics` |
| Comprobaciones de exportación | 26, 0 fallos | 0 fallos | `test_export.gd` |
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
| **Navegación, carriles o `park.gd`** | `test_navigation.gd`, `simulate_jams.gd` y `test_crowd.gd` |
| **Bancos, actividades, figurantes, palomas, perro o sonido** | `test_park_life.gd`, `test_crowd.gd`, `test_gait.gd`, `--smoke-test` en los dos renderizadores y la hoja `10_actividades` de `capture_characters.gd` |
| **Interfaz, flujo de pantallas o memoria** | `test_game.gd` y `test_expansion.gd` |
| **`export_presets.cfg`, ajustes móviles de `project.godot` o `.gitignore`** | `test_export.gd` y `./tools/export_android.sh` |
| **Cambios grandes (varios sistemas visuales a la vez)** | Además, `./tools/capture_video.sh` y revisar el MP4 |
| **Cambios visuales (shaders, mallas, escena)** | `./tools/run_evidence.sh` y, en Ultra, `--smoke-test` y `--metrics` con `~/bin/godot-4-fp --rendering-method forward_plus` |
| **Objetos o texturas del parque** | `./tools/build_park_assets.sh`, después `--smoke-test` en los dos renderizadores y `test_game.gd` |
| **Cualquier cambio antes de dar por cerrada una tarea** | `godot-4 --path . -- --smoke-test` |
