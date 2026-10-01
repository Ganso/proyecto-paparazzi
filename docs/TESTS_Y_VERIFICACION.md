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
| **Arcade y condiciones** | `~/bin/godot-4-fp --headless --path . --script tests/test_arcade.gd` | 20 niveles en 4 bloques con su curva (disparos 5 → 1, nota 50 → 80, reloj), títulos y textos, desbloqueo, estrellas, progreso guardado y cada condición (ojos, aislado, acompañado, grande, focal, áurea, fondo, congelado) con su rechazo determinista ([futuro/21](futuro/21_ARCADE_CONDICIONES_TLR.md)) | `ARCADE TESTS: N checks, N failures` |

---

## 3. Suites con Entorno Gráfico (Requieren Display)

| Suite | Comando | Qué valida | Línea de salida |
|---|---|---|---|
| **Navegación** | `godot-4 --path . --script tests/test_navigation.gd` | Cruce en sentidos opuestos en el carril 1, adelantamiento de un corredor a un caminante y desvío ante un obstáculo estático | `NAVIGATION TESTS: N checks, N failures` |
| **Multitud (60 s)** | `~/bin/godot-4-fp --path . --disable-vsync --script tests/test_crowd.gd` | 1.800 pasos a 30 Hz con los 21 viandantes: la orientación gira como mucho $125^\circ/\text{s}$ (sin saltos), nadie invierte su desplazamiento lateral dos veces en menos de 1,5 s (sin temblequeo), dos caminantes nunca quedan a menos de 0,42 m, nadie pasa más de 5,5 s atascado (la escalada da media vuelta a los 5 s) y al menos el 60 % del tiempo la gente camina (imprime el reparto de estados). Con `CROWD_DEBUG=1` imprime cada inversión rápida | `CROWD: …`, `CROWD STATES: …`, `CROWD STUCK: longest … s` y `CROWD TESTS: N checks, N failures` |
| **Vida en el parque** | `~/bin/godot-4-fp --path . --disable-vsync --script tests/test_park_life.gd` | Siguen siendo 21 viandantes; figurantes fuera de la lista, sin colisionadores y más allá de 12,8 m también andando; palomas sin colisionadores, baratas y en el suelo; perro con dueño, con colisionador fuera de la capa 2 y etiquetado, dentro de la correa; ciclo completo del banco (acercarse, sentarse mirando al camino con la cadera en el asiento, levantarse y liberarlo) sin teletransportes (< 6 cm por fotograma); dos personas en el mismo banco, cada una en su plaza, y si charlan giran la cabeza; dos caminantes que se cruzan se paran a charlar frente a frente; cada actividad muestra su objeto de mano, sin colisionadores, y lo oculta al acabar; la luz del móvil no proyecta sombras; de noche las palomas duermen en los árboles, se recogen pícnic, turista y balón y las pantallas brillan al máximo. Con `LIFE_DEBUG=1` traza la aproximación al banco | `PARK LIFE TESTS: N checks, N failures` |
| **Academia** | `~/bin/godot-4-fp --path . --disable-vsync --script tests/test_academy.gd` | Textos de las 21 páginas (≤ 60 palabras), subtítulos, tareas y diagramas; menú con el examen «no disponible»; teoría sobre el visor y resaltado; las cinco demostraciones hasta el final con sus fotos y lo que narran (aguja de vuelta a 0; f/1,8 frente a f/11 con la zona nítida mucho mayor; corredor a 1/30 con rastro y a 1/1000 congelado; 28 mm de cerca y 135 mm de lejos de cuerpo entero); criterios de práctica con evidencias fabricadas; tercios reales de la lección 4; práctica real de la lección 1 y progreso en disco (en un fichero de prueba). Tarda unos 2 min | `ACADEMY TESTS: N checks, N failures` |
| **Parque grande** | `~/bin/godot-4-fp --path . --disable-vsync --script tests/test_big_park.gd` | Grafo conexo y pavimentado; 60 s de multitud por los caminos (atasco < 5,5 s, sin solapes, repartida por la red; alguien se sienta y se para); paseo con WASD y la verja; cámara al ojo como interruptor (gesto, interfaz, quieto, disparo) y vuelta al paseo; reacción a una cámara cercana | `BIG PARK CROWD: …` y `BIG PARK TESTS: N checks, N failures` |
| **Visores** | `~/bin/godot-4-fp --path . --disable-vsync --script tests/test_finders.gd` | Por cuerpo: imagen dentro de la pantalla y 16:9 (sin recortes), centro del visor = centro de la foto, colimadores dentro, barras plegadas y Tab las muestra; paralaje de la telemétrica (crece de cerca, casi nulo de lejos) y visor sin desenfoque con la foto desenfocada; **misma nota con interfaz clásica y de cámara**; disparo real por cuerpo; sonidos; interfaz clásica intacta. Conserva el `user://interfaz.cfg` del jugador | `FINDER TESTS: N checks, N failures` |
| **Automatismos** | `~/bin/godot-4-fp --path . --disable-vsync --script tests/test_automatisms.gd` | En cuatro vistas con varias personas, el AF matricial elige el mismo colimador y el exposímetro da la misma lectura sea quien sea el objetivo del encargo ([futuro/12 §2.1](futuro/12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md)) | `AUTOMATISMS TESTS: N checks, N failures` |
| **Atascos (20 s)** | `godot-4 --path . --script tests/simulate_jams.gd` | 400 pasos a $\Delta t = 0.05\text{ s}$ sin jugador. Éxito: **0 viandantes con `stuck_time > 0.8 s`** | `Deadlocked pedestrians (stuck_time > 0.8s): N` |
| **Expansión** | `godot-4 --path . --script tests/test_expansion.gd` | Pantalla de encargo, ropa deportiva de corredores, nubes y EV, bloqueo de ISO con carrete y sandbox. Guarda capturas en `/tmp/paparazzi-*.png` | `EXPANSION TESTS: N checks, N failures` |
| **Sesión y arcade** | `godot-4 --path . --script tests/test_game.gd` | Encargos encadenados, entrada, disparo, revelado, flujo de pantallas, **VRAM del perfil** (60.000.000 bytes en `gl_compatibility`, 8 GiB en Forward+), perfil inicial y nivel de detalle según el renderizador, superficies del parque fusionado (≤ 40 en `lo`, ≤ 80 en `hd` por el suelo texturizado) y suelo texturizado solo en `hd`. Guarda capturas en `/tmp/paparazzi-*.png` Arcade: equipo fijo por nivel, disparos, reloj que acaba el nivel, sujeto corredor, condiciones en la línea del encargo; TLR a la cintura, foto cuadrada evaluada sobre el cuadrado, carrete de 12 y manivela. | `SESSION VIDEO MEMORY: …` y `GAME TESTS: N checks, N failures` |
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
| `--scenario=<clasico\|grande>` | Escenario de la sesión (el inicio permite elegirlo; cambiarlo recarga la escena). Con `grande`: `--at=x,z[,azimut]` coloca al fotógrafo y `--raised` empieza con la cámara en el ojo `--photo-walk` recorre los caminos y fotografía a la gente cercana (se gira, saca la cámara, encuadra, enfoca —a mano si el cuerpo es MF—, mide con `--manual`, dispara y enseña la foto; con `--sandbox` el resultado es el del sandbox) y `--walk-demo` hace un paseo guionizado (anda, gira, saca la cámara, enfoca, dispara y la guarda) para grabarlo con `--write-movie`. `--smoke-test` cuenta 45 viandantes en el grande. |
| `--level=<n>` | Abre el nivel `n` (1–20) del arcade al arrancar, con su escenario, luz y equipo ([futuro/21](futuro/21_ARCADE_CONDICIONES_TLR.md)); con la cámara guionizada (`--follow-target`, `--shoot-at`…) entra directamente en la búsqueda. `--arcade` abre la pantalla de niveles. |
| `--interface=<camara\|clasica>` | Interfaz de la sesión sin tocar la preferencia guardada: el visor real de cada cuerpo o la clásica a pantalla completa. Las capturas de escenario de `capture_ultra.sh` usan la clásica. |
| `--academy=<lección>:<teoria\|demo\|practica>[:página]` | Abre una lección de la Academia directamente (evidencias). También `--academy=menu` (menú de la Academia) e `--academy=inicio` (pantalla de inicio). Con `--academy-tour=<segundos>:<páginas>` la lección avanza sola: esas páginas de teoría, la demostración y la práctica. |
| `--stage=<escena>` | Prepara una escena delante de la cámara (según `--angle`) para el vídeo de novedades (`main.gd::stage_scene()`): `banco` (dos personas llegan al banco más cercano, se sientan y charlan), `palomas` (alguien se sienta a echar migas), `charla` (dos caminantes que se cruzan se paran a charlar), `estirar` (un corredor se para a estirar) y `perro` (la cámara sigue al dueño del perro). Aparta a los demás del sector. |
| `--scare-at=<s>` | En la cámara guionizada, la bandada más cercana al encuadre alza el vuelo a los `s` segundos. |
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
| `audio/build_camera_sounds.py` | `python3 tools/audio/build_camera_sounds.py` | Sintetiza los sonidos de disparo de cada cuerpo en `assets/audio/camara/` (réflex, telemétrica, compacta). |
| `audio/build_ambience.py` | `python3 tools/audio/build_ambience.py` | Sintetiza el sonido ambiente en `assets/audio/ambiente/` (pájaros, fuente, grillos, zureo y aleteo; WAV mono de 22,05 kHz). Requiere numpy y scipy. Ver [ESCENARIO_Y_RENDIMIENTO.md §3.4](ESCENARIO_Y_RENDIMIENTO.md). |
| `blender/build_characters.py` | `blender -b --factory-startup -P tools/blender/build_characters.py -- [--only <perfil>] [--slots <ranuras>]` | Genera maniquíes, ropa, pelucas y accesorios de escritorio en `data/piezas_hd/` ([futuro/18](futuro/18_PERSONAJES_BLENDER.md)). La simulación de tela de la falda hace que los cuatro perfiles tarden unos 2,5 min. |
| `capture_video.sh` | `./tools/capture_video.sh [--only 1,3] [--res 1920x1080] [--out <mp4>] [--sequences <fichero>]` | Con `--sequences` graba otra lista (una secuencia por línea, `título|segundos|argumentos`), p. ej. `tools/videos/interfaz_oscura.txt`: la interfaz en tema oscuro en 60 s. Sin ella: **Vídeo de evidencias bajo demanda, solo para cambios grandes: el proyecto entero en unos 180 s.** 16 secuencias de 8 a 22 s (título, duración y argumentos en `SEQUENCES`) grabadas con el Movie Maker de Godot (`--write-movie`, 30 FPS fijos): menú principal, pantalla de niveles del arcade (`--arcade`), parque clásico en las cuatro luces (día, hora dorada, hora azul, noche), vida del parque (`--stage=banco`, `palomas`, `perro`, pradera, móviles de noche), los tres cuerpos con su visor real (`--interface=camara`: compacta, réflex con teleobjetivo siguiendo a un viandante, telemétrica de 90 mm en enfoque manual que dispara y muestra el revelado), nivel 8 con su condición (ojos nítidos) y nivel 16 con la TLR (`--level=`), parque grande a pie (`--scenario=grande --photo-walk`), sandbox (`--sandbox`) y Academia (`--academy=2:teoria --academy-tour=4:2`). Montaje con ffmpeg (libx264) en `build/video/` (ignorado por git), con la **música de fondo del proyecto** (`assets/audio/musica_videos.mp3`, o `MUSIC`) con fundido de salida de 10 s sobre el sonido del juego. Tarda unos 15 min. |
| `arcade_solver.gd` | `~/bin/godot-4-fp --path . --disable-vsync --script tools/arcade_solver.gd [-- --only=1,16]` | **Demuestra que cada nivel del arcade se puede superar**: apunta al sujeto, encuadra según las condiciones, enfoca a los ojos y prueba todas las combinaciones de diafragma, velocidad e ISO sobre la evidencia; solo dispara cuando una pasa y luego hace la foto real. En el parque grande empieza a unos metros del sujeto. Imprime `LEVEL n: PASS nota/mínima` y `ARCADE SOLVER: 20/20` (unos 10 min). |
| `capture_screens.gd` | `~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 1600x900 --script tools/capture_screens.gd [-- --out=<dir> --ui=oscuro]` | Capturas de todas las pantallas en `docs/evidencias/interfaz/`: menú, equipo, gráficos, encargo, búsqueda, ayuda, resultado, sandbox, niveles del arcade, encargo de un nivel, visor de la TLR (con lupa y en la interfaz clásica), resultado con condiciones y fin de nivel ([futuro/20](futuro/20_INTERFAZ_CLARA.md), [futuro/21](futuro/21_ARCADE_CONDICIONES_TLR.md)). |
| `capture_academy_video.sh` | `./tools/capture_academy_video.sh [--only 1,3] [--res 1920x1080] [--out <mp4>]` | Vídeo de la Academia (≈3 min, unos 10 min de grabación): por cada lección, dos páginas de teoría, la demostración completa y la práctica, con `--academy-tour`; rótulo por lección y música del proyecto suave bajo el sonido del juego. |
| `capture_academy.gd` | `~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 1600x900 --script tools/capture_academy.gd [-- --out=<dir>]` | Evidencias de la Academia en `docs/evidencias/academia/`: menú, una página de teoría por lección, cada demostración con sus fotos, las prácticas y el díptico del resultado de la lección 5. Usa un fichero de progreso propio. |
| `capture_showcase.sh` | `./tools/capture_showcase.sh [--only 1,3] [--res 1920x1080] [--out <mp4>]` | **Vídeo de novedades de la vida en el parque** (bajo demanda): 11 escenas rotuladas sin HUD, preparadas con `--stage`, `--advance`, `--activity` y `--scare-at` (marcha suave, banco compartido, palomas que acuden y que alzan el vuelo, charla con saludo, corredor estirando, perro, actividades, pradera, estanque y noche). El sonido del juego va delante y la música del proyecto suave debajo, con fundido de salida de 10 s. Unos 2 min 20 s; tarda unos 10 min. |
| `capture_ultra.sh` | `./tools/capture_ultra.sh` | Capturas de Ultra a 2560 × 1440 en `docs/evidencias/ultra/`, incluidas tres de la vida del parque (`10_banco_palomas`, `11_picnic_hora_dorada` y `12_moviles_noche`, con `--advance` y `--activity`) y cuatro de los visores (`13`–`16`, con `--interface=camara`); las de escenario usan la interfaz clásica (lo llama `run_evidence.sh`; se omite si no hay Godot con Vulkan en `GODOT_FP` o `~/bin/godot-4-fp`). |
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
| Comprobaciones de equipo | 570, 0 fallos (con los tres fijos nuevos de la réflex) | 0 fallos | `test_equipment.gd` |
| Comprobaciones de marcha | 8.840, 0 fallos | 0 fallos | `test_gait.gd` |
| Deriva máxima del pie de apoyo | 0.000000 m/fotograma | 0 | `test_gait.gd` |
| Comprobaciones de navegación | 10, 0 fallos (marcha suave, 2026-09-30) | 0 fallos | `test_navigation.gd` |
| Multitud en 60 s | giro máximo 120°/s · 2 inversiones laterales rápidas en el peor caso · separación mínima 0,58 m · 0,67 m/s de media andando · atasco más largo 5,0 s · 79 % del tiempo caminando, 13 % parados y 8 % sentados (2026-09-30, con bancos de dos plazas) | ≤ 125°/s · ≤ 2 · ≥ 0,42 m · < 5,5 s · ≥ 60 % caminando | `test_crowd.gd` |
| Comprobaciones del parque grande | 53, 0 fallos; multitud: atasco más largo 5,0 s, 0 muestras fuera de los caminos, separación mínima 0,57 m, 20/20 nodos (2026-10-01) | 0 fallos | `test_big_park.gd` |
| Triángulos y GPU del parque grande (Ultra) | 3.503.056 triángulos · GPU 4,19 ms a 1440p · 67 draw calls de día (2026-10-01) | ≤ 5.000.000 | `--scenario=grande --smoke-test`, `--metrics` |
| Comprobaciones de visores | 36, 0 fallos (2026-10-01) | 0 fallos | `test_finders.gd` |
| Comprobaciones de la Academia | 132, 0 fallos (2026-10-01) | 0 fallos | `test_academy.gd` |
| Comprobaciones de automatismos | 9, 0 fallos (2026-09-30) | 0 fallos | `test_automatisms.gd` |
| Comprobaciones de vida en el parque | 131, 0 fallos (2026-09-30) | 0 fallos | `test_park_life.gd` |
| Viandantes atascados tras 20 s | 0 en Linux (2026-09-27 y de nuevo el 2026-09-30 con la marcha suave y el carril 0 ensanchado) · 1 en Windows con Intel Iris Xe (2026-09-29, código anterior) | 0 | `simulate_jams.gd` |
| Comprobaciones de expansión | 140, 0 fallos | 0 fallos | `test_expansion.gd` |
| Comprobaciones de sesión | Forward+: 52, 0 fallos (incluye pesos suaves de la ropa `hd`) · `gl_compatibility` (escena de Android): 48, 1 fallo, el de VRAM (58,37 MiB) (con `--disable-vsync`; 2026-09-30, RX 6700 XT) | 0 fallos | `test_game.gd` |
| Tiempo de GPU por perfil a 2560 × 1440, día | Ultra 10,94 ms · Alto 7,84 · Medio 3,93 · Bajo 2,16 (VRAM 1.525 / 1.413 / 1.196 / 766 MiB; 2026-09-30) | Ultra ≤ 12 ms | `--metrics --profile=<p>` |
| Destellos (píxeles no finitos) | 0 en 300 fotogramas (tres ráfagas de 100, 24–35 mm, día y hora dorada; 2026-09-30) | 0 | `--burst` + detector |
| VRAM en sesión completa | `gl_compatibility`: **59,91 MiB** (texturas 40,93 · buffers 18,98), **supera** el límite desde el parque de Blender y la pradera; pendiente de optimizar ([futuro/17 §6](futuro/17_SALTO_GRAFICO_ULTRA.md)) · Forward+ Ultra: 1.104 MiB en `test_game.gd`, 1.509 MiB en `--metrics` a 1440p | 60.000.000 bytes en `gl_compatibility` · 8 GiB en Ultra | `test_game.gd`, `--metrics` |
| Triángulos en escena (21 viandantes + parque) | `lo` (Android y respaldo sin Vulkan): 94.112 (2026-09-30, tras dibujar en `lo` solo parte de los árboles lejanos; antes había subido a 108.498) · `hd`: ver la fila siguiente | `lo` ≤ 100.000 · `hd` ≤ 5.000.000 | `--smoke-test` (`--rendering-method gl_compatibility` para `lo`) |
| Triángulos por maniquí `hd` (máximo en escena) | 41.436 (maniquíes de Blender con peluca y ropa; 2026-09-30) | ≤ 60.000 | `--smoke-test` en Forward+ |
| Triángulos en escena `hd` | 3.424.785 con 15 figurantes y 18 palomas (2.915.193 sin ellos; 2026-09-30) | ≤ 5.000.000 | `--smoke-test` en Forward+ |
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
| **Visores, interfaz de cámara o `camera_body.gd`** | `test_finders.gd`, `test_game.gd`, `test_academy.gd` y las capturas `13`–`16` de `capture_ultra.sh` |
| **Academia (lecciones, textos, diagramas)** | `test_academy.gd`, `test_automatisms.gd` y `tools/capture_academy.gd` |
| **Bancos, actividades, figurantes, palomas, perro o sonido** | `test_park_life.gd`, `test_crowd.gd`, `test_gait.gd`, `--smoke-test` en los dos renderizadores y la hoja `10_actividades` de `capture_characters.gd` |
| **Interfaz, flujo de pantallas o memoria** | `test_game.gd` y `test_expansion.gd` |
| **`export_presets.cfg`, ajustes móviles de `project.godot` o `.gitignore`** | `test_export.gd` y `./tools/export_android.sh` |
| **Cambios grandes (varios sistemas visuales a la vez)** | Además, `./tools/capture_video.sh` y revisar el MP4 |
| **Cambios visuales (shaders, mallas, escena)** | `./tools/run_evidence.sh` y, en Ultra, `--smoke-test` y `--metrics` con `~/bin/godot-4-fp --rendering-method forward_plus` |
| **Objetos o texturas del parque** | `./tools/build_park_assets.sh`, después `--smoke-test` en los dos renderizadores y `test_game.gd` |
| **Cualquier cambio antes de dar por cerrada una tarea** | `godot-4 --path . -- --smoke-test` |
