# AGENTS.md — Enrutador Central y Guía Operativa de IA

Bienvenido a **Proyecto Paparazzi**. Este documento es el **punto de entrada principal y enrutador maestro** para cualquier agente de IA o desarrollador automatizado.

---

## 1. Identificación del Entorno y Motor

- **Comando de Godot en esta máquina**: **`~/bin/godot-4-fp`** (binario oficial 4.7.2 con Vulkan). Para jugar: **`./Jugar.sh`**, que busca un Godot con Vulkan y evita el snap. El snap `godot-4` no arranca Vulkan: cae a OpenGL y construye la escena de Android (`lo`).
- **Versión de Godot**: Godot 4.4+ (validado con **Godot 4.7 Mono/Official**).
- **Método de Renderizado**: **`forward_plus`** (Vulkan) en los cuatro perfiles de escritorio, que son subconjuntos de Ultra orientados al rendimiento y **nunca cambian el aspecto** ([docs/futuro/17 §2.4](docs/futuro/17_SALTO_GRAFICO_ULTRA.md)). **`gl_compatibility`** solo en el APK de Android y como respaldo sin Vulkan.
- **Proporción de Pantalla**: Bloqueada a **16:9** (`1280x720` nativo, override `1440x810`), con modo de cámara `keep_aspect = Camera3D.KEEP_WIDTH` (ancho de sensor de referencia: **36 mm**).

---

## 2. Enrutador Maestro de Documentación Técnica (`docs/`)

Para no tener que analizar el código fuente en detalle antes de cada tarea, consulta directamente el documento monográfico correspondiente:

| Tema / Dominio | Documento Técnico | Qué encontrarás allí |
|---|---|---|
| **Arquitectura Global** | [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) | Diagrama de módulos, máquina de estados (`INTRO`, `BRIEFING`, `SEARCH`, `RESULT`, `SUMMARY`…), pipeline de fotograma y renderizado. |
| **Navegación y Colisiones** | [docs/NAVEGACION_Y_COLISIONES.md](docs/NAVEGACION_Y_COLISIONES.md) | Coordenadas cilíndricas, calzadas peatonales, límites `LANE_BOUNDS`, steering lateral 2D, cruces, adelantamientos y anti-deadlock. |
| **Personajes y Locomoción** | [docs/PERSONAJES_Y_CINEMATICA.md](docs/PERSONAJES_Y_CINEMATICA.md) | 4 perfiles anatómicos, rig universal de 20 huesos, pesaje rígido, coloreado por vértice (`ARRAY_COLOR`), estilo maniquí (madera, rótulas, shaders toon y de contorno), cinemática `gait.gd` y ética de casting. |
| **Simulación Óptica y Foto** | [docs/SIMULACION_FOTOGRAFICA.md](docs/SIMULACION_FOTOGRAFICA.md) | Ecuaciones de CoC, profundidad de campo, EV, trepidación, shaders de revelado (`develop.gdshader`), ayuda de foco y algoritmo de puntuación. |
| **Equipamiento y Ópticas** | [docs/EQUIPAMIENTO_Y_OPTICAS.md](docs/EQUIPAMIENTO_Y_OPTICAS.md) | Cuerpos (compacta, telemétrica, réflex), catálogo de objetivos (24 mm a 200 mm), diafragmas, compensación de exposición (±EV), carretes analógicos y visor HUD de 9 puntos de enfoque. |
| **Escenario y Rendimiento** | [docs/ESCENARIO_Y_RENDIMIENTO.md](docs/ESCENARIO_Y_RENDIMIENTO.md) | Disposición del parque, peana de diorama, masa vegetal de fondo, iluminación (día, hora dorada, noche), sombras dinámicas, sistema de nubes y presupuestos de hardware. |
| **Pruebas y Verificación** | [docs/TESTS_Y_VERIFICACION.md](docs/TESTS_Y_VERIFICACION.md) | **Fuente única** de comandos de prueba, opciones de arranque, herramientas de `tools/` y cifras de referencia medidas. Headless vs. Display y uso con Xvfb. |
| **Salto Gráfico (Ultra, Blender)** | [docs/futuro/17_SALTO_GRAFICO_ULTRA.md](docs/futuro/17_SALTO_GRAFICO_ULTRA.md) | Perfiles y renderizador, niveles de detalle `hd`/`lo`, proceso de Blender (`tools/blender/`), texturas procedurales (`tools/texturas/`), reglas de coherencia de colisionadores, presupuestos y pendientes. |
| **Personajes en Blender** | [docs/futuro/18_PERSONAJES_BLENDER.md](docs/futuro/18_PERSONAJES_BLENDER.md) | Maniquí, ropa, pelucas y tocados generados por `tools/blender/build_characters.py`, pesos suaves, `hides`, evidencias `tools/capture_characters.gd`. |
| **Vida en el Parque** | [docs/futuro/19_VIDA_EN_EL_PARQUE.md](docs/futuro/19_VIDA_EN_EL_PARQUE.md) | Marcha suave sin temblequeo, bancos, paradas con actividad y objetos de mano (el móvil ilumina la cara), perro (`scripts/dog.gd`), palomas (`scripts/pigeons.gd`), figurantes de la pradera (`scripts/extras.gd`) y sonido ambiente (`scripts/ambience.gd`, `tools/audio/build_ambience.py`). |
| **Academia de Fotografía (tutor)** | [docs/futuro/06_MODO_TUTOR_ACADEMIA.md](docs/futuro/06_MODO_TUTOR_ACADEMIA.md) §6 | Cinco lecciones (exposición, profundidad de campo, movimiento, composición, focal) con teoría sobre el visor, demostración guiada y práctica (`scripts/academy.gd`, `scripts/academy_diagram.gd`); exámenes pendientes; progreso en `user://academia.cfg`. |
| **Visores realistas** | [docs/futuro/07_VISORES_REALISTAS_Y_MOVIL.md](docs/futuro/07_VISORES_REALISTAS_Y_MOVIL.md) §5 | Interfaz de cámara (la única en escritorio; la clásica solo en el móvil y con `--interface=clasica` para pruebas): `scripts/camera_body.gd` (ocular, LED, LCD, marco con paralaje), `view_rect`/`image_position()` en `main.gd`, efectos del visor en `shaders/viewfinder_lens.gdshader`, sonidos en `tools/audio/build_camera_sounds.py`. Nada toca la foto ni la nota (`tests/test_finders.gd`). |
| **Parque grande (paseo libre)** | [docs/futuro/01_MAPA_ABIERTO_Y_PROTAGONISTA.md](docs/futuro/01_MAPA_ABIERTO_Y_PROTAGONISTA.md) §6 | Escenario adicional: `scripts/park_grande.gd` (disposición y grafo de caminos), `scripts/crowd_graph.gd` (45 viandantes por el grafo), paseo con WASD y cámara al ojo como interruptor en `main.gd` (`update_photographer()`, `toggle_raise()`). El parque clásico y sus invariantes de carriles no cambian. |
| **Arcade, condiciones y TLR** | [docs/futuro/21_ARCADE_CONDICIONES_TLR.md](docs/futuro/21_ARCADE_CONDICIONES_TLR.md) | 20 niveles (`scripts/arcade.gd`), condiciones por nivel (`scripts/conditions.gd`), enfoque juzgado en los ojos, TLR 6×6 (cuerpo 3: cintura, visor espejado y cuadrado, lupa, carrete de 12), modos de prioridad A y S, ritmo de los viandantes por nivel y ayuda en pantalla (`scripts/control_help.gd`, F1); `tests/test_arcade.gd`, `tools/arcade_solver.gd`. |
| **Menú, tutorial y mando** | [docs/futuro/22_MENU_TUTORIAL_MANDO.md](docs/futuro/22_MENU_TUTORIAL_MANDO.md) | Menú de cinco modos (`scripts/main_menu.gd`), tutorial (`scripts/tutorial.gd`), mando, controles por dispositivo (`scripts/input_glyphs.gd`), teclas y botones dibujados (`scripts/glyph_label.gd`), mando y teclado dibujados en la ayuda, pausa con salida confirmada. |
| **Interfaz clara** | [docs/futuro/20_INTERFAZ_CLARA.md](docs/futuro/20_INTERFAZ_CLARA.md) | Menú principal (`scripts/main_menu.gd`), tema y paleta de toda la interfaz (`scripts/ui_style.gd`), cristal esmerilado (`shaders/frosted_glass.gdshader`); capturas con `tools/capture_screens.gd`. |
| **Banco de Futuras Mejoras** | [docs/futuro/README.md](docs/futuro/README.md) | Especificaciones técnicas de mapa abierto, TLR, nuevos escenarios, academia, estilos de maniquí (toon y diorama físico PBR realista), animación universal (Quaternius), modos de fotometría (matricial/spot) y autofoco avanzado (AF-C/AF-S), interfaz móvil utilizable, soporte de gamepad, variedad procedural de vegetación y personajes, y perfiles gráficos con Ultra para GPUs potentes. Empieza por la **hoja de ruta** ([docs/futuro/README.md §4](docs/futuro/README.md)); los pasos 1 ([parque fusionado](docs/futuro/16_PARQUE_ILUSTRADO_QUICK_WIN.md)), 2 ([salto gráfico](docs/futuro/17_SALTO_GRAFICO_ULTRA.md) y [personajes](docs/futuro/18_PERSONAJES_BLENDER.md)) y 2c ([vida en el parque](docs/futuro/19_VIDA_EN_EL_PARQUE.md)) ya están completados. |

---

## 3. Invariantes Críticos Inquebrantables

Cualquier cambio o extensión en este repositorio **debe respetar estrictamente estos límites**:

### 3.1 Presupuestos de Geometría y Memoria
- **Población en escena**: Exactamente **21 viandantes** (`counts = [3, 7, 6, 5]`) en el parque clásico; el parque grande tiene 45 (`GRANDE_PEOPLE`) y sus propias reglas ([docs/futuro/01 §6](docs/futuro/01_MAPA_ABIERTO_Y_PROTAGONISTA.md)).
- **Presupuestos por nivel de detalle** (justificación en [docs/futuro/17 §3](docs/futuro/17_SALTO_GRAFICO_ULTRA.md)):

  | Nivel | Perfiles | Triángulos por viandante | Triángulos en escena | VRAM | Renderizador |
  |---|---|---:|---:|---:|---|
  | `lo` | Android y respaldo sin Vulkan | ≤ 1.900 | ≤ 100.000 | < 60 MB | `gl_compatibility` |
  | `hd` | Bajo, Medio, Alto y Ultra en escritorio (Ultra apunta a la RX 6700 XT del equipo, 1440p, 60 FPS) | ≤ 60.000 | ≤ 5.000.000 | < 8 GiB | `forward_plus` |

  Los perfiles de escritorio comparten la escena `hd` y solo reducen resolución interna, efectos y densidad de hierba. En Ultra no hay que escatimar polígonos mientras el rendimiento se mantenga. Lo comprueban `test_art.gd` (`lo`), `--smoke-test` (el nivel del renderizador) y `test_game.gd`.
- **Coherencia entre perfiles**: ningún perfil cambia la puntuación. Colisionadores y puntos de control usan siempre la geometría base, y lo que un perfil añade solo puede colocarse fuera de la zona jugable ($r > 12.8	ext{ m}$) o por debajo de 0,3 m ([02 §10.3](docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md)).
- Los valores medidos actuales de estos presupuestos están en [docs/TESTS_Y_VERIFICACION.md §5](docs/TESTS_Y_VERIFICACION.md).
- **Draw Calls**: Cada personaje consta de **1 única superficie combinada** con colores de vértice (`Mesh.ARRAY_COLOR`), sin texturas de imagen, dibujada con un único material; el maniquí usa sombreado realista (`shaders/mannequin_pbr.gdshader`: madera barnizada y tela, sin bandas ni contorno de tinta) en todos los perfiles, con texturas procedurales de madera, punto, sarga y pelo (`shaders/mannequin_patterns.gdshaderinc`). El parque estático se fusiona en `park.gd::merge_static_meshes()`: 12 sectores × 3 bandas con colores de vértice y un único `StandardMaterial3D` de sombreado suave, más materiales propios (vidrio, bombillas, agua, agua en movimiento y ventanas; en `hd`, además, 36 sectores de suelo texturizado y la hierba instanciada). Los objetos vienen de Blender (`assets/parque/*.glb`, [docs/futuro/17](docs/futuro/17_SALTO_GRAFICO_ULTRA.md)). **El toon y el contorno son solo de los maniquíes.** De día el visor dibuja **≤ 300 draw calls** (comprobado en `test_game.gd`); de noche el coste depende de cuántas farolas proyectan sombra según el perfil (`park.gd::update_lamp_shadows()`). Cifras en [docs/TESTS_Y_VERIFICACION.md §5](docs/TESTS_Y_VERIFICACION.md).

### 3.2 Rigging y Locomoción
- **Esqueleto**: Exactamente **20 huesos** universales idénticos para los 4 perfiles anatómicos y los dos niveles de detalle. En escritorio, pelo, falda y accesorios añaden **huesos secundarios** después de esos 20 (`primary_bone_count`), movidos por `SpringBoneSimulator3D` ([docs/futuro/18](docs/futuro/18_PERSONAJES_BLENDER.md)); la marcha y la puntuación no los usan.
- **Pesos**: la madera del maniquí es rígida (cada vértice con peso `1.0` en un hueso). En los maniquíes de escritorio (`data/piezas_hd/`, Blender) **ropa, pelo y accesorios usan pesos suaves** (hasta 4 huesos) para doblarse en las articulaciones ([docs/futuro/18](docs/futuro/18_PERSONAJES_BLENDER.md)). Las piezas base (`data/piezas/`, colisionadores y Android) siguen rígidas.
- **Cinemática**: `gait.gd` garantiza matemáticamente que el pie apoyado no desliza (`drift == 0.000000 m/frame`) y la suela se mantiene horizontal ($y = 0$).
- **Velocidades**:
  - Caminantes: $v \in [0.55, 0.85]\text{ m/s}$ (los niveles del arcade con enfoque y exposición manuales los ralentizan con `pace`, [docs/futuro/21 §5](docs/futuro/21_ARCADE_CONDICIONES_TLR.md)).
  - Corredores: $v \in [2.6, 3.0]\text{ m/s}$ (exclusivamente ropa deportiva, fase aérea balística).

### 3.3 Sistema de Carriles y Navegación 2D
- Origen en jugador: $(0, 1.60\text{ m}, 0)$.
- **Carril 0**: $r = 1.8\text{ m}$ (aforo máx. 3). Calzada útil $[1.05, 2.70]\text{ m}$ (ensanchada el 30-09-2026 para que dos personas quepan al cruzarse).
- **Carril 1**: $r = 4.0\text{ m}$ (aforo máx. 7). Calzada útil ancha $[2.9, 4.85]\text{ m}$ con 4 bancos exteriores a $r = 4.85\text{ m}$.
- **Carril 2**: $r = 7.0\text{ m}$ (aforo máx. 7).
- **Carril 3**: $r = 11.5\text{ m}$ (aforo máx. 6).
- **Fondo vegetal**: Cortina densa de setos y arbolado entre $r = 13.2\text{ m}$ y $r = 17.5\text{ m}$.
- **Figurantes, palomas y objetos de mano** no tienen colisionadores y los figurantes no están en `main.people` (siguen siendo 21 viandantes). El **perro** sí tiene colisionador, en la capa 1 (fotos) y fuera de la máscara 2 de la navegación.

### 3.4 Actualización Obligatoria e Inmediata de Documentación (Directiva Crítica)
- **Documentación Viva e Inmediata**: Es **FUNDAMENTAL y OBLIGATORIO** actualizar la documentación técnica y las matrices de estado (`docs/`, `docs/futuro/README.md`, etc.) **inmediatamente después de cualquier cambio** de código, refactorización o resolución de tareas. Ningún desarrollo se considera completado si su estado documental no refleja con total exactitud la realidad del código y de las herramientas disponibles.
- **Sincronización de Matrices de Estado**: Cuando una funcionalidad futura o propuesta se implementa, debe cambiarse su estado a `✅ Ya implementado` o `✅ Completado`, vinculando los scripts, pruebas y evidencias generadas.
- **Preservación de Trazabilidad**: Todo nuevo script en `tools/`, shader o módulo del motor debe quedar registrado en el documento técnico monográfico correspondiente y en `AGENTS.md`.
- **Ampliación de Pruebas y Evidencias tras Cambios Fundamentales**: Tras cualquier cambio fundamental o estructural en el proyecto (nuevos shaders, sistemas de mallas, mecánicas escénicas, modos o perfiles gráficos), es **OBLIGATORIO**:
  1. **Ampliar la batería de pruebas automatizadas** (`tests/`) añadiendo checks unitarios o de integración específicos que validen la nueva funcionalidad y aseguren que no hay regresiones en los invariantes críticos.
  2. **Actualizar y ejecutar la suite de evidencias gráficas** (`./tools/run_evidence.sh`), comprobando que las capturas de estado, hojas de assets y animaciones en `docs/evidencias/` reflejan fielmente el nuevo estándar visual.

### 3.5 Ética y Fotografía Determinista
- **Regla Ética**: El tono de piel **nunca** se utiliza para describir al objetivo ni forma parte de los predicados. Los personajes son maniquíes de madera: el rasgo `skin` solo elige el acabado (`madera_por_tono`).
- **Determinismo**: Una entrada fotográfica idéntica en `photography.gd` produce siempre la misma puntuación numérica.
- **Oclusión física**: Se evalúan **5 rayos directos** contra la geometría 3D real de personajes y mobiliario.
- **Textos e Idioma**: Todo texto visible debe resolverse a través de `texts.gd` y estar registrado en `data/textos.es.json`.
- **Controles en los textos**: ninguna ayuda escribe una tecla a mano: usa `{control}` (tabla de `scripts/input_glyphs.gd`), que muestra la tecla o el botón del mando según el dispositivo en uso, y se dibuja como tecla o botón con `scripts/glyph_label.gd` (`Texts.get_rich()`). Un control nuevo se añade a esa tabla con sus nombres de teclado, Xbox, PlayStation y Nintendo ([docs/futuro/22 §3](docs/futuro/22_MENU_TUTORIAL_MANDO.md)).

---

## 4. Protocolo y Comandos de Verificación

> [!WARNING]
> **NO USAR `--headless` EN PRUEBAS CON DISPLAY**: Las pruebas que esperan a `RenderingServer.frame_post_draw` (`test_expansion.gd`, `test_game.gd`, `test_navigation.gd`, `simulate_jams.gd` y `--smoke-test`) se congelan si se ejecutan con `--headless`.

Los comandos de todas las suites, qué valida cada una, las opciones de arranque (`--smoke-test`, `--metrics`, `--stress`, `--screenshot=`), las herramientas de `tools/` y las cifras de referencia medidas están en **[docs/TESTS_Y_VERIFICACION.md](docs/TESTS_Y_VERIFICACION.md)**, que es la fuente única. No dupliques comandos ni cifras en otros documentos: enlaza ahí.

- **Headless**: `test_photography.gd`, `test_art.gd`, `test_equipment.gd`, `test_gait.gd`, `test_export.gd`.
- **Exportación a todas las plataformas**: `./tools/export_all.sh` genera los ejecutables de Windows, Linux, macOS y Android (necesita las plantillas de exportación de Godot instaladas; ver [docs/TESTS_Y_VERIFICACION.md §4.2](docs/TESTS_Y_VERIFICACION.md)). Los de escritorio no se versionan.
- **Exportación Android**: `./tools/export_android.sh` genera `build/paparazzi-debug.apk`, que **se versiona en git** (excepción en `.gitignore`). Si cambias el juego para una entrega móvil, recompila y haz commit del APK.
- **Con display**: `test_input.gd`, `test_tutorial.gd`, `test_navigation.gd`, `test_crowd.gd`, `test_park_life.gd`, `test_academy.gd`, `test_automatisms.gd`, `test_finders.gd`, `test_big_park.gd`, `simulate_jams.gd`, `test_expansion.gd`, `test_game.gd`, `--smoke-test`, `./tools/run_evidence.sh`. En esta máquina, con **`--disable-vsync`**: si la ventana queda tapada, Wayland deja de dar fotogramas y la prueba se cuelga. En servidores sin pantalla se pueden ejecutar con `xvfb-run` (ver §1 del documento de pruebas).
- **Mínimo antes de cerrar una tarea**: `~/bin/godot-4-fp --path . -- --smoke-test`; si toca Android, también con `--rendering-method gl_compatibility`.

---

## 5. Preguntas Frecuentes y Respuestas Rápidas para Agentes

- **¿Dónde cambio la cantidad de personajes?**  
  En `scripts/main.gd::populate()` (`counts = [3, 7, 6, 5]`) y ajusta `LANE_CAPACITIES = [3, 7, 7, 6]`. Actualiza también la aserción en `smoke_test()` y `test_game.gd:85`.
- **¿Cómo añado o cambio un nivel del arcade?**  
  En `scripts/arcade.gd::LEVELS` (escenario, luz, cuerpo, objetivo, exposición, disparos, `limit`, `min`, `cond`, `target`), con su título y texto en `data/textos.es.json` (`arcade_nivel_<n>_titulo`/`_texto`). Una condición nueva va en `scripts/conditions.gd` (`check()` y `describe()`, textos `cond_*`). Comprueba con `tests/test_arcade.gd` y que se puede superar con `tools/arcade_solver.gd -- --only=<n>`.
- **¿Cómo cambio la velocidad de los viandantes?**  
  En `scripts/person.gd:49` (`speed = rng.randf_range(...)`). La animación de pisada se adapta automáticamente en `gait.gd` sin deslizar.
- **¿Por qué los viandantes no se atascan en el Carril 1?**  
  Porque los bancos se movieron al borde exterior a $r = 4.85\text{ m}$ y los viandantes usan navegación espacial continua 2D (`space_out` vs `space_in`) dentro de `LANE_BOUNDS`.
- **¿Cómo añado un nuevo objeto al parque?**  
  Modélalo por código en `tools/blender/build_park_assets.py` (una función `build_<nombre>(lod)` que devuelva sus `Builder` por rol, registrada en `ASSETS`), regenera con `./tools/build_park_assets.sh --only <nombre>` y revísalo con `tools/blender/preview_assets.py`. En `scripts/park.gd::build()` colócalo con `visual("<nombre>", variante, padre)` y dale colisionador con las primitivas de siempre (`collider_only = true` y `cube()`/`cylinder()` con etiqueta) o con `landmark()`/`collider()` desde su malla `lo`. Si interactúa con el fotómetro o el AF, etiquétalo con `Texts.get_text(...)` y registra el texto en `data/textos.es.json`.
- **¿Cómo añado una actividad nueva (p. ej. «hacer estiramientos»)?**  
  Su postura va en `scripts/gait.gd::activity()` (un caso del `match` con `arm()` y `head()`; las piernas no se tocan). Si lleva un objeto, añádelo a `Person.PROP_FOR` y constrúyelo en `person.gd::make_prop()`. Luego haz que alguien la elija: `STAND_ACTIVITIES` o `SEAT_ACTIVITIES` en `main.gd` (o `WALKING_ACTIVITIES` en `gait.gd` si se hace andando). Revísala con `tools/capture_characters.gd -- --only=actividades` (añade el caso) y comprueba el objeto en `tests/test_park_life.gd`.
- **¿Cómo veo la vida del parque en una captura?**  
  `~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 1600x900 -- --screenshot=/tmp/x.png --angle=125 --pitch=-5 --focal=40 --advance=60 --hud=0`. `--advance=N` simula N segundos antes de la captura y `--activity=palomas` (u otra) obliga a todos a hacerla. Los bancos están en $\theta = 35^\circ, 125^\circ, 215^\circ, 305^\circ$ y la pradera se ve por $\theta \approx 120^\circ$ (quiosco) y $245^\circ$ (estanque).
- **¿Cómo añado o cambio una lección de la Academia?**  
  Textos en `data/textos.es.json` (`academia_l<n>_…`: `titulo`, `resumen`, `t<k>_titulo`/`t<k>_texto` para la teoría, `d<k>` para los subtítulos, `p<k>` para las tareas y `pista_*`). En `scripts/academy.gd`: `SETUP[n]` (luz, cuerpo, objetivo, exposición inicial y diagrama de cada página), `THEORY_PAGES`, la línea de tiempo de `start_demo()` (pasos `[segundo, subtítulo, acción]`) y las tareas de `check_practice()` y `on_practice_photo()`. Los diagramas viven en `scripts/academy_diagram.gd`. Ábrela con `--academy=<n>:<teoria|demo|practica>` y comprueba con `tests/test_academy.gd` y `tools/capture_academy.gd`.
- **¿Cómo genero un vídeo de las novedades de la vida en el parque?**  
  `./tools/capture_showcase.sh` (≈10 min, MP4 de unos 2 min 20 s en `build/video/`). Cada escena se prepara con `--stage=<banco|palomas|charla|estirar|perro>` (`main.gd::stage_scene()`) para que ocurra delante de la cámara; ver [docs/TESTS_Y_VERIFICACION.md §4](docs/TESTS_Y_VERIFICACION.md).
- **¿Cómo cambio o regenero el sonido ambiente?**  
  Edita `tools/audio/build_ambience.py` y ejecuta `python3 tools/audio/build_ambience.py` (escribe `assets/audio/ambiente/*.wav`). Dónde suena cada uno y a qué volumen está en `scripts/ambience.gd`. Graba una prueba con `--write-movie` y mide el nivel con `ffmpeg -af volumedetect`.
- **¿Cómo genero el vídeo de evidencias?**  
  `./tools/capture_video.sh` (≈15 min, MP4 de unos 180 s en `build/video/` que cuenta el proyecto entero: menú, las cuatro luces, los dos escenarios, la vida del parque, los tres cuerpos con su visor, disparo y revelado, sandbox y Academia). El audio es la música mezclada sobre el sonido del juego. **Música de fondo de todos los vídeos del proyecto: `assets/audio/musica_videos.mp3`** (del usuario), con fundido de salida en los últimos 10 s. Solo bajo demanda y para cambios grandes. Detalle en [docs/TESTS_Y_VERIFICACION.md §4.2](docs/TESTS_Y_VERIFICACION.md).
- **¿Cómo veo Ultra?**  
  `~/bin/godot-4-fp --path . --rendering-method forward_plus --resolution 2560x1440 -- --screenshot=/tmp/x.png --angle=120 --pitch=3 --focal=24 --time=day`, o `./tools/capture_ultra.sh`. Mide con `-- --metrics` (imprime `METRICS_GPU`).
- **¿Cómo cambio la ropa, el pelo o el maniquí de escritorio?**  
  En `tools/blender/build_characters.py` (una función por ranura: `build_body`, `build_torso`, `build_legs`, `build_head`, `build_accessory`). Regenera con `blender -b --factory-startup -P tools/blender/build_characters.py -- [--only estandar] [--slots torso]` y revisa con `~/bin/godot-4-fp --path . --rendering-method forward_plus --resolution 800x1000 --script tools/capture_characters.gd -- --only=torsos,dinamica`. Las piezas base de `data/piezas/` (colisionadores y Android) siguen saliendo de `tools/build_catalog.py`; ver [docs/futuro/18](docs/futuro/18_PERSONAJES_BLENDER.md).
- **¿Cómo añado una nueva prenda?**  
  Añade la geometría en `tools/build_catalog.py` (que genera `data/piezas/`) y regístrala en `data/catalogo.json` indicando su ranura (`torso`, `piernas`, `cabeza`, `accesorio`), colores compatibles, formas morfológicas de género/número y si es `sport: true`. Usa las zonas de color existentes (tabla en [docs/PERSONAJES_Y_CINEMATICA.md §3](docs/PERSONAJES_Y_CINEMATICA.md)) y comprueba las uniones con `test_art.gd`.
