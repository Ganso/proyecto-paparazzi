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
| **Arquitectura Global** | [docs/ARQUITECTURA.md](file:///home/ganso/codigo/afotando/docs/ARQUITECTURA.md) | Diagrama de módulos, máquina de estados (`INTRO`, `SEARCH`, `RESULT`, `SANDBOX`), pipeline de fotograma y renderizado. |
| **Navegación y Colisiones** | [docs/NAVEGACION_Y_COLISIONES.md](file:///home/ganso/codigo/afotando/docs/NAVEGACION_Y_COLISIONES.md) | Coordenadas cilíndricas, calzadas peatonales, límites `LANE_BOUNDS`, steering lateral 2D, cruces, adelantamientos y anti-deadlock. |
| **Personajes y Locomoción** | [docs/PERSONAJES_Y_CINEMATICA.md](file:///home/ganso/codigo/afotando/docs/PERSONAJES_Y_CINEMATICA.md) | 4 perfiles anatómicos, rig universal de 20 huesos, pesaje rígido, coloreado por vértice (`ARRAY_COLOR`), cinemática `gait.gd` y ética de casting. |
| **Simulación Óptica y Foto** | [docs/SIMULACION_FOTOGRAFICA.md](file:///home/ganso/codigo/afotando/docs/SIMULACION_FOTOGRAFICA.md) | Ecuaciones de CoC, profundidad de campo, EV, trepidación, shaders de revelado (`develop.gdshader`), ayuda de foco y algoritmo de puntuación. |
| **Equipamiento y Ópticas** | [docs/EQUIPAMIENTO_Y_OPTICAS.md](file:///home/ganso/codigo/afotando/docs/EQUIPAMIENTO_Y_OPTICAS.md) | Cuerpos (compacta, telemétrica, réflex), catálogo de objetivos (28 mm a 135 mm), diafragmas, carretes analógicos y visor HUD de 9 colimadores. |
| **Escenario y Rendimiento** | [docs/ESCENARIO_Y_RENDIMIENTO.md](file:///home/ganso/codigo/afotando/docs/ESCENARIO_Y_RENDIMIENTO.md) | Disposición del parque, masa vegetal densa de fondo, ciclo día/noche, sombras dinámicas, sistema de nubes y presupuestos de hardware. |
| **Pruebas y Verificación** | [docs/TESTS_Y_VERIFICACION.md](file:///home/ganso/codigo/afotando/docs/TESTS_Y_VERIFICACION.md) | Clasificación Headless vs. Display, suite de atascos (`simulate_jams.gd`), smoke test y comandos de validación obligatorios. |
| **Banco de Futuras Mejoras** | [docs/futuro/README.md](file:///home/ganso/codigo/afotando/docs/futuro/README.md) | Especificaciones técnicas de mapa abierto, TLR, nuevos escenarios, academia, estilos de maniquí, animación universal (Quaternius) y desafíos. |

---

## 3. Invariantes Críticos Inquebrantables

Cualquier cambio o extensión en este repositorio **debe respetar estrictamente estos límites**:

### 3.1 Presupuestos de Geometría y Memoria
- **Población en escena**: Exactamente **21 viandantes** (`counts = [3, 7, 6, 5]`).
- **Triángulos por viandante**: Máximo **1.900 triángulos** (media del catálogo $\approx 1.550$).
- **Triángulos totales en escena**: Máximo **100.000 triángulos** (con parque, vegetación de fondo densa y 21 personas suma **57.532 triángulos**).
- **Memoria de vídeo (VRAM)**: Mantener siempre por debajo de **60 MiB** (consumo medido: **42.68 MiB** con atlas de sombras de 2048).
- **Draw Calls**: Cada personaje consta de **1 única superficie combinada** con colores de vértice (`Mesh.ARRAY_COLOR`), sin texturas individuales. El parque estático se fusiona en **1 único draw call**.

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
- **Regla Ética**: El tono de piel **nunca** se utiliza para describir al objetivo ni forma parte de los predicados.
- **Determinismo**: Una entrada fotográfica idéntica en `photography.gd` produce siempre la misma puntuación numérica.
- **Oclusión física**: Se evalúan **5 rayos directos** contra la geometría 3D real de personajes y mobiliario.
- **Textos e Idioma**: Todo texto visible debe resolverse a través de `texts.gd` y estar registrado en `data/textos.es.json`.

---

## 4. Protocolo y Comandos de Verificación

> [!WARNING]
> **NO USAR `--headless` EN PRUEBAS CON DISPLAY**: Las pruebas que esperan a `RenderingServer.frame_post_draw` (`test_expansion.gd`, `test_game.gd`, `test_navigation.gd`, `simulate_jams.gd` y `--smoke-test`) se congelan si se ejecutan con `--headless`.

### 4.1 Pruebas Headless (CI / Servidor)
```bash
# Óptica, CoC y determinismo (535 checks)
godot-4 --headless --path . --script tests/test_photography.gd

# Ensamblaje de mallas, pesos y 20 huesos (2.880 mallas)
godot-4 --headless --path . --script tests/test_art.gd

# Equipos, aperturas, modos AF/MF y EV (543 checks)
godot-4 --headless --path . --script tests/test_equipment.gd

# Cinemática inversa y cero deslizamiento (8.840 checks)
godot-4 --headless --path . --script tests/test_gait.gd
```

### 4.2 Pruebas con Entorno Gráfico (Requieren Display / X11 / Wayland)
```bash
# Suite completa de captura automática de evidencias gráficas
./tools/run_evidence.sh
# Simulación de atascos durante 20s (debe dar 0 deadlocks)
godot-4 --path . --script tests/simulate_jams.gd

# Pruebas de navegación, adelantamientos y cruces (10 checks)
godot-4 --path . --script tests/test_navigation.gd

# Prueba rápida de humo (21 viandantes, triángulos <= 100k)
godot-4 --path . -- --smoke-test

# Sesión de juego completa (5 encargos, VRAM < 60 MB)
godot-4 --path . --script tests/test_game.gd

# Expansión, nubes, carretes analógicos y sandbox (140 checks)
godot-4 --path . --script tests/test_expansion.gd
```

---

## 5. Preguntas Frecuentes y Respuestas Rápidas para Agentes

- **¿Dónde cambio la cantidad de personajes?**  
  En `scripts/main.gd::populate()` (`counts = [3, 7, 6, 5]`) y ajusta `LANE_CAPACITIES = [3, 7, 7, 6]`. Actualiza también la aserción en `smoke_test()`, `test_game.gd:85` y `test_expansion.gd:36`.
- **¿Cómo cambio la velocidad de los viandantes?**  
  En `scripts/person.gd:49` (`speed = rng.randf_range(...)`). La animación de pisada se adapta automáticamente en `gait.gd` sin deslizar.
- **¿Por qué los viandantes no se atascan en el Carril 1?**  
  Porque los bancos se movieron al borde exterior a $r = 4.85\text{ m}$ y los viandantes usan navegación espacial continua 2D (`space_out` vs `space_in`) dentro de `LANE_BOUNDS`.
- **¿Cómo añado un nuevo objeto al parque?**  
  En `scripts/park.gd::build()`. Usa las funciones `prop()`, `cylinder()`, `cube()` o `ring()`. Si interactúa con el fotómetro o AF, ponle etiqueta con `Texts.get_text(...)`.
- **¿Cómo añado una nueva prenda?**  
  Añade la geometría JSON en `data/piezas/` y regístrala en `data/catalogo.json` indicando su ranura (`torso`, `piernas`, `cabeza`, `accesorio`), colores compatibles, formas morfológicas de género/número y si es `sport: true`.
