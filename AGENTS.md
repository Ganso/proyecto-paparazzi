# AGENTS.md — Enrutador Central y Guía Operativa de IA

Bienvenido a **Proyecto Paparazzi**. Este documento es el **punto de entrada principal y enrutador maestro** para cualquier agente de IA o desarrollador automatizado.

---

## 1. Identificación del Entorno y Motor

- **Comando de Godot en esta máquina**: **`godot-4`** (utilizar siempre `godot-4 --path . ...`).
- **Versión de Godot**: Godot 4.4+ (validado con **Godot 4.7 Mono/Official**).
- **Método de Renderizado**: **`gl_compatibility`** (OpenGL Core Profile / WebGL).
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
| **Equipamiento y Ópticas** | [docs/EQUIPAMIENTO_Y_OPTICAS.md](docs/EQUIPAMIENTO_Y_OPTICAS.md) | Cuerpos (compacta, telemétrica, réflex), catálogo de objetivos (24 mm a 200 mm), diafragmas, compensación de exposición (±EV), carretes analógicos y visor HUD de 9 colimadores. |
| **Escenario y Rendimiento** | [docs/ESCENARIO_Y_RENDIMIENTO.md](docs/ESCENARIO_Y_RENDIMIENTO.md) | Disposición del parque, peana de diorama, masa vegetal de fondo, iluminación (día, hora dorada, noche), sombras dinámicas, sistema de nubes y presupuestos de hardware. |
| **Pruebas y Verificación** | [docs/TESTS_Y_VERIFICACION.md](docs/TESTS_Y_VERIFICACION.md) | **Fuente única** de comandos de prueba, opciones de arranque, herramientas de `tools/` y cifras de referencia medidas. Headless vs. Display y uso con Xvfb. |
| **Banco de Futuras Mejoras** | [docs/futuro/README.md](docs/futuro/README.md) | Especificaciones técnicas de mapa abierto, TLR, nuevos escenarios, academia, estilos de maniquí (toon y diorama físico PBR realista), animación universal (Quaternius), modos de fotometría (matricial/spot) y autofoco avanzado (AF-C/AF-S), interfaz móvil utilizable, soporte de gamepad, variedad procedural de vegetación y personajes, y perfiles gráficos con Ultra para GPUs potentes. Empieza por la **hoja de ruta** ([docs/futuro/README.md §4](docs/futuro/README.md)); la siguiente tarea es el [parque ilustrado](docs/futuro/16_PARQUE_ILUSTRADO_QUICK_WIN.md). |

---

## 3. Invariantes Críticos Inquebrantables

Cualquier cambio o extensión en este repositorio **debe respetar estrictamente estos límites**:

### 3.1 Presupuestos de Geometría y Memoria
- **Población en escena**: Exactamente **21 viandantes** (`counts = [3, 7, 6, 5]`).
- **Presupuestos por perfil gráfico** (tabla completa y justificación en [docs/futuro/02 §10.2](docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md)):

  | Perfil | Triángulos por viandante | Triángulos en escena | VRAM | Renderizador |
  |---|---:|---:|---:|---|
  | Bajo / Medio (móvil) | ≤ 1.900 | ≤ 100.000 | < 60 MiB | `gl_compatibility` |
  | Alto (escritorio) | ≤ 4.000 | ≤ 300.000 | < 256 MiB | `gl_compatibility` |
  | Ultra (GPU potente) | ≤ 8.000 | ≤ 1.500.000 | < 1 GiB | `forward_plus` (con reinicio) |

  **Hasta que se implementen los perfiles ampliados, todo el juego debe cumplir la fila Bajo/Medio**, que es la que comprueban hoy `test_art.gd`, `--smoke-test` y `test_game.gd`. Cualquier ampliación debe justificarse por calidad visual visible, no por tener margen.
- **Coherencia entre perfiles**: ningún perfil cambia la puntuación. Colisionadores y puntos de control usan siempre la geometría base, y lo que un perfil añade solo puede colocarse fuera de la zona jugable ($r > 12.8	ext{ m}$) o por debajo de 0,3 m ([02 §10.3](docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md)).
- Los valores medidos actuales de estos presupuestos están en [docs/TESTS_Y_VERIFICACION.md §5](docs/TESTS_Y_VERIFICACION.md).
- **Draw Calls**: Cada personaje consta de **1 única superficie combinada** con colores de vértice (`Mesh.ARRAY_COLOR`), sin texturas individuales, dibujada con un material de 2 pases (toon `shaders/cel_shading.gdshader` + contorno `shaders/cel_outline.gdshader`). El parque estático **debería** fusionarse en muy pocas superficies con colores de vértice; hoy `park.gd::merge_static_meshes()` agrupa por color y celda de 6 m (692 nodos, 78 materiales) y el visor dibuja unos 1.800 draw calls por fotograma (cifra en [docs/TESTS_Y_VERIFICACION.md §5](docs/TESTS_Y_VERIFICACION.md)). Restaurar este invariante es parte del paso 1 de la hoja de ruta ([docs/futuro/16_PARQUE_ILUSTRADO_QUICK_WIN.md](docs/futuro/16_PARQUE_ILUSTRADO_QUICK_WIN.md)).

### 3.2 Rigging y Locomoción
- **Esqueleto**: Exactamente **20 huesos** idénticos para los 4 perfiles anatómicos.
- **Pesos rígidos**: Cada vértice pertenece con peso `1.0` a un único hueso (`ARRAY_WEIGHTS[0] == 1.0`, los demás a 0).
- **Cinemática**: `gait.gd` garantiza matemáticamente que el pie apoyado no desliza (`drift == 0.000000 m/frame`) y la suela se mantiene horizontal ($y = 0$).
- **Velocidades**:
  - Caminantes: $v \in [0.55, 0.85]\text{ m/s}$.
  - Corredores: $v \in [2.6, 3.0]\text{ m/s}$ (exclusivamente ropa deportiva, fase aérea balística).

### 3.3 Sistema de Carriles y Navegación 2D
- Origen en jugador: $(0, 1.60\text{ m}, 0)$.
- **Carril 0**: $r = 1.8\text{ m}$ (aforo máx. 3).
- **Carril 1**: $r = 4.0\text{ m}$ (aforo máx. 7). Calzada útil ancha $[2.9, 4.85]\text{ m}$ con 4 bancos exteriores a $r = 4.85\text{ m}$.
- **Carril 2**: $r = 7.0\text{ m}$ (aforo máx. 7).
- **Carril 3**: $r = 11.5\text{ m}$ (aforo máx. 6).
- **Fondo vegetal**: Cortina densa de setos y arbolado entre $r = 13.2\text{ m}$ y $r = 17.5\text{ m}$.

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

---

## 4. Protocolo y Comandos de Verificación

> [!WARNING]
> **NO USAR `--headless` EN PRUEBAS CON DISPLAY**: Las pruebas que esperan a `RenderingServer.frame_post_draw` (`test_expansion.gd`, `test_game.gd`, `test_navigation.gd`, `simulate_jams.gd` y `--smoke-test`) se congelan si se ejecutan con `--headless`.

Los comandos de todas las suites, qué valida cada una, las opciones de arranque (`--smoke-test`, `--metrics`, `--stress`, `--screenshot=`), las herramientas de `tools/` y las cifras de referencia medidas están en **[docs/TESTS_Y_VERIFICACION.md](docs/TESTS_Y_VERIFICACION.md)**, que es la fuente única. No dupliques comandos ni cifras en otros documentos: enlaza ahí.

- **Headless**: `test_photography.gd`, `test_art.gd`, `test_equipment.gd`, `test_gait.gd`, `test_export.gd`.
- **Exportación Android**: `./tools/export_android.sh` genera `build/paparazzi-debug.apk`, que **se versiona en git** (excepción en `.gitignore`). Si cambias el juego para una entrega móvil, recompila y haz commit del APK.
- **Con display**: `test_navigation.gd`, `simulate_jams.gd`, `test_expansion.gd`, `test_game.gd`, `--smoke-test`, `./tools/run_evidence.sh`. En servidores sin pantalla se pueden ejecutar con `xvfb-run` (ver §1 del documento de pruebas).
- **Mínimo antes de cerrar una tarea**: `godot-4 --path . -- --smoke-test`.

---

## 5. Preguntas Frecuentes y Respuestas Rápidas para Agentes

- **¿Dónde cambio la cantidad de personajes?**  
  En `scripts/main.gd::populate()` (`counts = [3, 7, 6, 5]`) y ajusta `LANE_CAPACITIES = [3, 7, 7, 6]`. Actualiza también la aserción en `smoke_test()` y `test_game.gd:85`.
- **¿Cómo cambio la velocidad de los viandantes?**  
  En `scripts/person.gd:49` (`speed = rng.randf_range(...)`). La animación de pisada se adapta automáticamente en `gait.gd` sin deslizar.
- **¿Por qué los viandantes no se atascan en el Carril 1?**  
  Porque los bancos se movieron al borde exterior a $r = 4.85\text{ m}$ y los viandantes usan navegación espacial continua 2D (`space_out` vs `space_in`) dentro de `LANE_BOUNDS`.
- **¿Cómo añado un nuevo objeto al parque?**  
  En `scripts/park.gd::build()`. Usa las funciones `prop()`, `cylinder()`, `cube()` o `ring()`. Si interactúa con el fotómetro o AF, ponle etiqueta con `Texts.get_text(...)`.
- **¿Cómo añado una nueva prenda?**  
  Añade la geometría en `tools/build_catalog.py` (que genera `data/piezas/`) y regístrala en `data/catalogo.json` indicando su ranura (`torso`, `piernas`, `cabeza`, `accesorio`), colores compatibles, formas morfológicas de género/número y si es `sport: true`. Usa las zonas de color existentes (tabla en [docs/PERSONAJES_Y_CINEMATICA.md §3](docs/PERSONAJES_Y_CINEMATICA.md)) y comprueba las uniones con `test_art.gd`.
