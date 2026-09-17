# Banco de Funcionalidades Futuras — Proyecto Paparazzi

Este directorio contiene las especificaciones de diseño, análisis de viabilidad técnica y propuestas arquitectónicas para futuras expansiones de **Proyecto Paparazzi**.

---

## 1. Matriz de Estado de Funcionalidades Solicitadas

Evaluación del estado actual de la lista de ideas y requisitos frente al código base implementado:

| Propuesta | Estado | Documento de Especificación / Dónde vive |
|---|:---:|---|
| **Protagonista Controlable y Mapa Abierto** | 📝 *Propuesta futura* | [01_MAPA_ABIERTO_Y_PROTAGONISTA.md](file:///home/ganso/codigo/afotando/docs/futuro/01_MAPA_ABIERTO_Y_PROTAGONISTA.md) |
| **Mejora Gráfica Intensiva y Estilos Artísticos** | 📝 *Propuesta futura* | [02_ESTILO_VISUAL_Y_POLIGONOS.md](file:///home/ganso/codigo/afotando/docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md) |
| **Nuevas Cámaras: TLR (Visor invertido), Móvil, Gran Formato** | 📝 *Propuesta futura* | [03_NUEVAS_CAMARAS_Y_TLR.md](file:///home/ganso/codigo/afotando/docs/futuro/03_NUEVAS_CAMARAS_Y_TLR.md) |
| **Mayor Diversidad de Escenarios Urbanos** | 📝 *Propuesta futura* | [04_DIVERSIDAD_ESCENARIOS.md](file:///home/ganso/codigo/afotando/docs/futuro/04_DIVERSIDAD_ESCENARIOS.md) |
| **Desafíos Específicos y Modos de Juego** | 📝 *Propuesta futura* | [05_DESAFIOS_Y_MODOS_JUEGO.md](file:///home/ganso/codigo/afotando/docs/futuro/05_DESAFIOS_Y_MODOS_JUEGO.md) |
| **Modo "Tutor de Fotografía" y Academia** | 📝 *Propuesta futura* | [06_MODO_TUTOR_ACADEMIA.md](file:///home/ganso/codigo/afotando/docs/futuro/06_MODO_TUTOR_ACADEMIA.md) |
| **Visores Realistas de Carcasa y Ergonomía Móvil** | 📝 *Propuesta futura* | [07_VISORES_REALISTAS_Y_MOVIL.md](file:///home/ganso/codigo/afotando/docs/futuro/07_VISORES_REALISTAS_Y_MOVIL.md) |
| **Cámaras de Carrete con ISO Fijo** | ✅ **Ya implementado** | Activo en `scripts/equipment.gd:16` (`film = true`), bloquea ISO manual. Documentado en [docs/EQUIPAMIENTO_Y_OPTICAS.md](file:///home/ganso/codigo/afotando/docs/EQUIPAMIENTO_Y_OPTICAS.md). |
| **Ropa Deportiva Exclusiva para Corredores** | ✅ **Ya implementado** | Validado en `scripts/casting.gd:101` y `tests/test_expansion.gd:38` (sin accesorios sueltos). Documentado en [docs/PERSONAJES_Y_CINEMATICA.md](file:///home/ganso/codigo/afotando/docs/PERSONAJES_Y_CINEMATICA.md). |
| **Nubes y Sol Visibles con Atenuación Lumínica** | 🟡 **Parcialmente hecho** | Mallas de nubes dinámicas y reducción de 3 EV activas (`park.gd:192`). Mejoras visuales en sol/cielo documentadas en [07_VISORES_REALISTAS_Y_MOVIL.md](file:///home/ganso/codigo/afotando/docs/futuro/07_VISORES_REALISTAS_Y_MOVIL.md). |
| **Variedad de Árboles y Elementos en el Escenario** | 🟡 **Parcialmente hecho** | Capa vegetal densa de 280 elementos añadida en `park.gd`. Nuevas propuestas de mobiliario y atrezo en [04_DIVERSIDAD_ESCENARIOS.md](file:///home/ganso/codigo/afotando/docs/futuro/04_DIVERSIDAD_ESCENARIOS.md). |
| **Ampliación de Accesorios de Vestimenta** | 📝 *Propuesta futura* | Incluido en [02_ESTILO_VISUAL_Y_POLIGONOS.md](file:///home/ganso/codigo/afotando/docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md) (paraguas, mochilas, periódicos, gafas). |
| **Captura Automática de Evidencias Gráficas** | 📝 *Propuesta futura* | [08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md](file:///home/ganso/codigo/afotando/docs/futuro/08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md) |
| **Exportación Automatizada a Android (.apk)** | 📝 *Propuesta futura* | [09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md](file:///home/ganso/codigo/afotando/docs/futuro/09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md) |

---

## 2. Índice de Especificaciones Técnicas

1. [01_MAPA_ABIERTO_Y_PROTAGONISTA.md](file:///home/ganso/codigo/afotando/docs/futuro/01_MAPA_ABIERTO_Y_PROTAGONISTA.md) — Protagonista controlable, navegación libre, alternativas de raíles/bancos y esquema de controles.
2. [02_ESTILO_VISUAL_Y_POLIGONOS.md](file:///home/ganso/codigo/afotando/docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md) — Análisis comparativo de estilos (muñeco de dibujo anatómico vs. low-poly redondeado vs. semi-realismo) y nuevos accesorios.
3. [03_NUEVAS_CAMARAS_Y_TLR.md](file:///home/ganso/codigo/afotando/docs/futuro/03_NUEVAS_CAMARAS_Y_TLR.md) — Cámaras de formato medio TLR con visor de cintura invertido horizontalmente, smartphones computacionales y banco óptico 4×5.
4. [04_DIVERSIDAD_ESCENARIOS.md](file:///home/ganso/codigo/afotando/docs/futuro/04_DIVERSIDAD_ESCENARIOS.md) — Nuevas localizaciones (Bulevar comercial, Estación de tren, Terraza nocturna, Pista deportiva).
5. [05_DESAFIOS_Y_MODOS_JUEGO.md](file:///home/ganso/codigo/afotando/docs/futuro/05_DESAFIOS_Y_MODOS_JUEGO.md) — Modos de juego reglados (Reto de focal fija, Paparazzi contrarreloj, Multitud maratón, Fotoperiodismo puro).
6. [06_MODO_TUTOR_ACADEMIA.md](file:///home/ganso/codigo/afotando/docs/futuro/06_MODO_TUTOR_ACADEMIA.md) — Academia interactiva de fotografía, lecciones pedagógicas con ejercicios prácticos y evaluación por examen.
7. [07_VISORES_REALISTAS_Y_MOVIL.md](file:///home/ganso/codigo/afotando/docs/futuro/07_VISORES_REALISTAS_Y_MOVIL.md) — Ocular de visor fotorrealista, pantallas LCD de datos, paralelaje en compactas y ergonomía táctil móvil.
8. [08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md](file:///home/ganso/codigo/afotando/docs/futuro/08_CAPTURA_AUTOMATICA_DE_EVIDENCIAS.md) — Suite de capturas automáticas de hitos, spritesheets de assets por categoría, muestrario de personajes representativos, GIFs animados de cinemática y prevención de `.import` mediante `.gdignore`.
9. [09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md](file:///home/ganso/codigo/afotando/docs/futuro/09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md) — Pipeline de compilación y empaquetado desatendido a APK de depuración para pruebas en hardware móvil real vía CLI y ADB.
