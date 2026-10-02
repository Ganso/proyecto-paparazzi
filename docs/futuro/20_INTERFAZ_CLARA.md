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

## Tema claro u oscuro

Selector **Tema: Claro / Oscuro** en la esquina superior derecha del menú principal. El oscuro pone textos claros sobre cristal oscuro: `UiStyle.set_dark()` cambia entre `LIGHT_PALETTE` y `DARK_PALETTE` (tinta `eef4fa`, acentos `7cc6ff`, avisos `ff9a76`, superficies pizarra) y el tinte del cristal (`tint` en `frosted_glass.gdshader`). La elección se guarda en `user://interfaz.cfg` (`[interfaz] tema`) y, como toda la interfaz se construye con la paleta, `main.gd::set_theme()` recarga la escena (solo se cambia desde el menú). `--ui=claro|oscuro` fuerza uno al arrancar. Por defecto, claro. Lo comprueba `tests/test_game.gd`; capturas con `tools/capture_screens.gd -- --out=<dir> --ui=oscuro`.

## Pantalla de carga e icono (02-10-2026)

Mientras se construye el parque (unos 4 s) el motor mostraba su propio logotipo. Ahora muestra `assets/marca/carga.png` (el nombre del juego, «Cargando el parque…» y un diafragma sobre el azul de la interfaz), y la ventana y los ejecutables llevan `assets/marca/icono.png`. Las dos imágenes las genera `bash tools/build_branding.sh` con ImageMagick y las fuentes del proyecto; se envían sin importar (`importer="keep"`). El texto de la pantalla de carga va dentro de la imagen, porque se muestra antes de que exista `texts.gd`: es la única excepción a la regla de textos. Ajustes en `project.godot` (`boot_splash/*`, `config/icon`); comprobado en `tests/test_export.gd`.
