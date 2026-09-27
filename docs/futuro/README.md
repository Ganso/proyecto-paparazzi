# Banco de Funcionalidades Futuras — Proyecto Paparazzi

Este directorio contiene las especificaciones de diseño, análisis de viabilidad técnica y propuestas arquitectónicas para futuras expansiones de **Proyecto Paparazzi**.

---

## 1. Matriz de Estado de Funcionalidades Solicitadas

Evaluación del estado actual de la lista de ideas y requisitos frente al código base implementado:

| Propuesta | Estado | Documento de Especificación / Dónde vive |
|---|:---:|---|
| **Protagonista Controlable y Mapa Abierto** | 📝 *Propuesta futura* | [01_MAPA_ABIERTO_Y_PROTAGONISTA.md](01_MAPA_ABIERTO_Y_PROTAGONISTA.md) |
| **Mejora Gráfica Canónica (Toon) y Modo Diorama Físico (PBR Realista + Render Avanzado)** | 🟡 **Parcialmente hecho** | Personajes ya con anatomía de maniquí de madera, rótulas visibles, sombreado toon y contorno de tinta (subfases 2.1 y 2.2; `shaders/cel_shading.gdshader`, `shaders/cel_outline.gdshader`) y menú reactivo de perfiles gráficos estándar (Bajo, Medio, Alto, Ultra por defecto) en `scripts/main.gd` y `scripts/park.gd`. Pendiente: cell shading en parque, animaciones Quaternius UAL, arquitectura 7 capas, y especificación completa del **Modo Diorama Físico de Estudio** (texturas realistas PBR de madera barnizada y telas, entorno de alta fidelidad, y arsenal de render Godot 4 Forward+: VoxelGI/SDFGI, sombras PCSS, SSAO, volumetría y postprocesado macro tilt-shift) en [02_ESTILO_VISUAL_Y_POLIGONOS.md](02_ESTILO_VISUAL_Y_POLIGONOS.md). |
| **Nuevas Cámaras: TLR (Visor invertido), Móvil, Gran Formato** | 📝 *Propuesta futura* | [03_NUEVAS_CAMARAS_Y_TLR.md](03_NUEVAS_CAMARAS_Y_TLR.md) |
| **Mayor Diversidad de Escenarios Urbanos** | 📝 *Propuesta futura* | [04_DIVERSIDAD_ESCENARIOS.md](04_DIVERSIDAD_ESCENARIOS.md) |
| **Desafíos Específicos y Modos de Juego** | 📝 *Propuesta futura* | [05_DESAFIOS_Y_MODOS_JUEGO.md](05_DESAFIOS_Y_MODOS_JUEGO.md) |
| **Modo "Tutor de Fotografía" y Academia** | 📝 *Propuesta futura* | [06_MODO_TUTOR_ACADEMIA.md](06_MODO_TUTOR_ACADEMIA.md) |
| **Visores Realistas de Carcasa y Ergonomía Móvil** | 📝 *Propuesta futura* | [07_VISORES_REALISTAS_Y_MOVIL.md](07_VISORES_REALISTAS_Y_MOVIL.md) |
| **Cámaras de Carrete con ISO Fijo** | ✅ **Ya implementado** | Activo en `scripts/equipment.gd:15` (`film`), bloquea ISO manual. Documentado en [docs/EQUIPAMIENTO_Y_OPTICAS.md](../EQUIPAMIENTO_Y_OPTICAS.md). |
| **Ropa Deportiva Exclusiva para Corredores** | ✅ **Ya implementado** | Validado en `scripts/casting.gd:18` y `tests/test_expansion.gd:38` (sin accesorios sueltos). Documentado en [docs/PERSONAJES_Y_CINEMATICA.md](../PERSONAJES_Y_CINEMATICA.md). |
| **Nubes y Sol Visibles con Atenuación Lumínica** | 🟡 **Parcialmente hecho** | Mallas de nubes dinámicas y reducción de ~3,5 EV en la luz solar directa activas (`park.gd:301` `build_clouds()`, `park.gd:325` `update_weather()`). Mejoras visuales en sol/cielo documentadas en [07_VISORES_REALISTAS_Y_MOVIL.md](07_VISORES_REALISTAS_Y_MOVIL.md). |
| **Variedad de Árboles y Elementos en el Escenario** | ✅ **Completado** | 4 especies botánicas estilizadas (roble, ciprés, tilo, arce dorado) con variación procedural orgánica individual (rotación 360°, inclinación natural, jitter 3D, cuello radicular, escala y micro-modulación cromática) y arbustos facetados en `park.gd`. |
| **Ampliación de Accesorios de Vestimenta** | 📝 *Propuesta futura* | Incluido en [02_ESTILO_VISUAL_Y_POLIGONOS.md](02_ESTILO_VISUAL_Y_POLIGONOS.md) (paraguas, mochilas, periódicos, gafas). |
| **Captura Automática de Evidencias Gráficas** | ✅ **Ya implementado** | Suite completa en `tools/run_evidence.sh` y `tools/capture_evidence.gd`. Galería viva en [docs/evidencias/GALERIA.md](../evidencias/GALERIA.md). Doc: [08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md](08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md). |
| **Exportación Automatizada a Android (.apk)** | 📝 *Propuesta futura* | [09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md](09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md) |
| **Modo Historia Dual: El Legado del Paparazzi** | 📝 *Propuesta futura* | [10_MODO_HISTORIA_DUAL_LEGADO.md](10_MODO_HISTORIA_DUAL_LEGADO.md) |
| **Mecánicas de Barrido (Panning) y Previsualización DoF** | 📝 *Propuesta futura* | [11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md](11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md) |
| **Modos de Fotometría Avanzada y Autofoco (AF-C / AF-S)** | 🟡 **Parcialmente hecho** | Compensación de exposición $\pm\text{EV}$ activa y funcional en `main.gd` y `equipment.gd`. Modos matricial, puntual, AF-C y AF-S especificados en [12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md](12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md). |

---

## 2. Estimación Comparativa de Complejidad y Esfuerzo

Evaluación técnica de la dificultad de implementación, riesgo de regresión y alcance arquitectónico de cada futurible:

| Especificación / Futurible | Complejidad Estimada | Factores Clave de Esfuerzo | Impacto Arquitectónico | Dependencias |
|---|:---:|---|---|---|
| [01. Mapa Abierto y Protagonista Controlable](01_MAPA_ABIERTO_Y_PROTAGONISTA.md) | **Muy Alta (XL)** | Reescritura del bucle de cámara, físicas de movimiento 3D del personaje, navegación libre por el parque, replanteamiento de la IA de evasión de peatones y controles simultáneos (movimiento + cámara). | Modificación nuclear de `main.gd` y del modelo de control. | Ninguna |
| [02. Mejora Gráfica, Animación Universal y Modo Diorama Físico](02_ESTILO_VISUAL_Y_POLIGONOS.md) | **Alta (L)** | Toon canónico y Modo Diorama Físico PBR; arquitectura escalonada estándar (Bajo, Medio, Alto, Ultra) con menú personalizable desde móviles (60 FPS fluidos) hasta PCs modernos (NVIDIA serie 5000 con Forward+, VoxelGI, sombras PCSS y DoF macro). | Mallas procedurales multi-LOD, shaders Toon/PBR, AnimationTree y pipeline Forward+. | Ninguna |
| [03. Nuevas Cámaras y TLR](03_NUEVAS_CAMARAS_Y_TLR.md) | **Media (M)** | Inversión horizontal en shader/viewport para emular visor de cintura, simulación de procesado computacional móvil y ampliación del catálogo en `equipment.gd`. | Módulo de cámara y renderizado en espejo. | Ninguna |
| [04. Diversidad de Escenarios Urbanos](04_DIVERSIDAD_ESCENARIOS.md) | **Alta (L)** | Creación de geometrías de bulevares, estaciones y terrazas, adaptación del sistema de carriles a recorridos lineales/irregulares y mantenimiento de 1 draw call estático. | Escenarios (`park.gd`), navegación y POIs. | Ninguna |
| [05. Desafíos y Modos de Juego](05_DESAFIOS_Y_MODOS_JUEGO.md) | **Baja-Media (S-M)** | Temporizadores, filtros de encargos fotográficos, condiciones de puntuación y menús adicionales; no requiere cambios gráficos ni de motor físico. | Capa de juego (`gameplay.gd`), aislada y modular. | Ninguna |
| [06. Academia y Tutor de Fotografía](06_MODO_TUTOR_ACADEMIA.md) | **Media (M)** | Lógica pedagógica de diagnóstico interactivo de errores (sub/sobreexposición, desenfoque, trepidación), textos en `textos.es.json` y UI de retroalimentación. | Interfaz y máquina de estados del juego. | Ninguna |
| [07. Visores Realistas y Ergonomía Móvil](07_VISORES_REALISTAS_Y_MOVIL.md) | **Media (M)** | Shaders de viñeteo óptico y LCD retro en visor, diseño de interfaz táctil a dos pulgares con `TouchScreenButton` y disparador de 2 fases (*half-press*). | Capa de visor (`viewfinder.gd`) y controles. | Ninguna |
| [08. Captura Automática de Evidencias](08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md) | ✅ **Completado** | Implementado en `tools/capture_evidence.gd`, `tools/build_sheets.py` y orquestador `tools/run_evidence.sh`. Galería activa en `docs/evidencias/`. | Aislado en `tools/`, riesgo cero de regresión en el juego. | Ninguna |
| [09. Exportación Automatizada a Android](09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md) | **Baja (S)** | Configuración de preset en `export_presets.cfg` y script bash con llamada headless a Godot y ADB; el motor ya usa `gl_compatibility` y presupuestos óptimos para móvil. | Toolchain externo e infraestructura de build. | SDK de Android |
| [10. Modo Historia Dual: El Legado](10_MODO_HISTORIA_DUAL_LEGADO.md) | **Media-Alta (M-L)** | Campaña por actos en dos líneas temporales (Abuelo 1950 vs Nieto moderno), shader de emulsión B&W química y reglas estrictas de carrete analógico. | Máquina de estados (`campaign.gd`) y shaders. | [03](03_NUEVAS_CAMARAS_Y_TLR.md) |
| [11. Barrido (Panning) y Previsualización DoF](11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md) | **Media (M)** | Evaluación angular de arrastre en `photography.gd`, shader de estriado horizontal en `develop.gdshader` y botón de apertura de trabajo en visor. | Pipeline fotográfico y shader de revelado. | Ninguna |
| [12. Modos de Fotometría Avanzada y Autofoco](12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md) | **Media (M)** | Lógica de fotometría multizona/spot, cálculo predictivo de distancia para corredores en AF-C, bloqueo AF-L/AE-L y controles de conmutación en HUD. | Módulo de exposición (`auto_expose`), buscador AF (`viewfinder.gd`) y controles. | Ninguna |

### Criterios de Calificación de Complejidad
- **Baja (S)**: Tarea autocontenida de 1 a 2 días de desarrollo; sin riesgo de regresión en la física, óptica o navegación existente.
- **Media (M)**: Requiere modificaciones en módulos específicos (visores, shaders, lógica de reglas de juego), con pruebas unitarias focalizadas.
- **Alta (L)**: Demanda remodelado masivo de mallas o rediseño estructural de escenarios y carriles; requiere rebalanceo de presupuestos de GPU y VRAM.
- **Muy Alta (XL)**: Cambio de paradigma arquitectónico fundamental (del modelo paparazzi estático/raíles a un juego de acción y exploración libre con controles simultáneos de personaje y óptica).

---

## 3. Índice de Especificaciones Técnicas

1. [01_MAPA_ABIERTO_Y_PROTAGONISTA.md](01_MAPA_ABIERTO_Y_PROTAGONISTA.md) — Protagonista controlable, navegación libre, alternativas de raíles/bancos y esquema de controles.
2. [02_ESTILO_VISUAL_Y_POLIGONOS.md](02_ESTILO_VISUAL_Y_POLIGONOS.md) — Estilo visual canónico Toon (Maniquíes + Cell Shading) y **Modo Diorama Físico de Estudio** (PBR realista de madera, telas y forja, peana perimetral, arsenal Forward+: VoxelGI, SDFGI, PCSS, SSAO, volumetría y DoF tilt-shift macro); arquitectura multi-perfil estándar (Bajo, Medio, Alto, Ultra) y configuración personalizada granular para móviles y PCs modernos (NVIDIA serie 5000).
3. [03_NUEVAS_CAMARAS_Y_TLR.md](03_NUEVAS_CAMARAS_Y_TLR.md) — Cámaras de formato medio TLR con visor de cintura invertido horizontalmente, smartphones computacionales y banco óptico 4×5.
4. [04_DIVERSIDAD_ESCENARIOS.md](04_DIVERSIDAD_ESCENARIOS.md) — Nuevas localizaciones (Bulevar comercial, Estación de tren, Terraza nocturna, Pista deportiva).
5. [05_DESAFIOS_Y_MODOS_JUEGO.md](05_DESAFIOS_Y_MODOS_JUEGO.md) — Modos de juego reglados (Reto de focal fija, Paparazzi contrarreloj, Multitud maratón, Fotoperiodismo puro).
6. [06_MODO_TUTOR_ACADEMIA.md](06_MODO_TUTOR_ACADEMIA.md) — Academia interactiva de fotografía, lecciones pedagógicas con ejercicios prácticos y evaluación por examen.
7. [07_VISORES_REALISTAS_Y_MOVIL.md](07_VISORES_REALISTAS_Y_MOVIL.md) — Ocular de visor fotorrealista, pantallas LCD de datos, paralelaje en compactas y ergonomía táctil móvil.
8. [08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md](08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md) — Suite de capturas automáticas de hitos, spritesheets de assets por categoría, muestrario de personajes representativos, GIFs animados de cinemática y prevención de `.import` mediante `.gdignore`.
9. [09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md](09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md) — Pipeline de compilación y empaquetado desatendido a APK de depuración para pruebas en hardware móvil real vía CLI y ADB.
10. [10_MODO_HISTORIA_DUAL_LEGADO.md](10_MODO_HISTORIA_DUAL_LEGADO.md) — Campaña narrativa en dos líneas temporales alternas (el fotorreportero clásico de 1950 vs. el paparazzi moderno), dilemas éticos y restricciones de época.
11. [11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md](11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md) — Algoritmo de arrastre angular y trepidación diferencial para barrido (*panning*) y previsualización de profundidad de campo en tiempo real.
12. [12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md](12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md) — Modos de medición TTL (matricial, puntual, ponderada al centro), compensación de exposición $\pm\text{EV}$, modos de autofoco (AF-S, AF-C predictivo, AF-A) y seguimiento de sujetos.
