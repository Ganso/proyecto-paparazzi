# 20 · Interfaz clara

**Estado: ✅ Implementado (01-10-2026)**, a petición del usuario.

Estilo limpio en tonos claros con resaltes celestes, en todo el juego salvo la interfaz de cámara (los visores de [07](07_VISORES_REALISTAS_Y_MOVIL.md), que imitan cámaras reales).

- **Menú principal** (`scripts/main_menu.gd`): el parque vivo de fondo, con la gente paseando y la cámara girando despacio, visto a través de un bloque de cristal blanco esmerilado (`shaders/frosted_glass.gdshader`, más opaco a la izquierda, donde va el menú, con resplandores celestes). Tarjetas de escenario, píldoras de luz (cambian el parque del fondo al momento), un botón principal y entradas secundarias (sandbox, Academia, equipo, gráficos). Subtítulo: «Versión alfa · en desarrollo».
- **Resto de pantallas** (equipo, gráficos, encargo, ayuda, resultado, resumen, sandbox, Academia): el mismo cristal como fondo. `scripts/ui_style.gd` define un `Theme` (fuentes, botones, desplegables, deslizadores) y traduce la paleta oscura antigua: los paneles oscuros pasan a cristal blanco y los textos claros, a tinta oscura (azul profundo para los acentos, rojo teja para los avisos). Los ayudantes `panel()`, `label()` y `button()` de `main.gd` lo aplican solos.
- **En juego con la interfaz clásica**: barras claras translúcidas; el exposímetro de la barra se dibuja en tinta oscura. Los textos sobre la escena (avisos, paseo) siguen en blanco con sombra.
- **Tipografía**: Quicksand para títulos y botones, Roboto para el texto (`assets/fuentes/`, licencias en `assets/LICENCIAS.md`).
- **Textos sin retórica**: «Resultado de la foto», «Resultado de la sesión», «Controles», «Busca a la persona del encargo».
- **Contraste**: tinta `0e1924`, texto secundario `26394a`; ningún texto gris claro sobre blanco.

Evidencias: `tools/capture_screens.gd` → `docs/evidencias/interfaz/`.

## Prueba inversa (`--ui=oscuro`)

Variante de prueba con textos claros sobre cristal oscuro: `UiStyle.set_dark(true)` cambia la paleta (tinta `eef4fa`, acentos `7cc6ff`, avisos `ff9a76`, superficies pizarra) y el tinte del cristal (`tint` en `frosted_glass.gdshader`). Por defecto sigue la interfaz clara. Capturas: `tools/capture_screens.gd -- --out=<dir> --ui=oscuro`.
