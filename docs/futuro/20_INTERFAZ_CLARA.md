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

Mientras se construye el parque (unos 4 s) el motor muestra `assets/marca/carga.png`: la cámara de bloques del logotipo, **PhotoHacks** en naranja (Russo One) y «Cargando el parque…» sobre el azul de la marca. En cuanto el juego puede dibujar, `scripts/boot_loader.gd` pone encima la misma imagen con **la cámara dando una vuelta de 360°** (`assets/marca/giro.png`, hoja de 45 fotogramas) y se funde con el menú cuando el parque está listo. La imagen de arranque del motor es fija, así que para que la cámara gire `main.gd::_ready()` cede un fotograma entre las etapas de la construcción (`boot_step()`: tras el parque, las palomas, los figurantes y cada viandante); el fotograma se elige por el reloj, de modo que el giro mantiene su velocidad aunque el bloque del parque (unos 2 s) lo deje parado un momento. Solo aparece en el juego real y al grabar vídeo, no en las pruebas ni en las capturas. La ventana y los ejecutables llevan `assets/marca/icono.png` y la cabecera del menú, `assets/marca/camara.png`.

Las cuatro imágenes salen del logotipo modelado en Blender: `GIRO=1 ./tools/build_logo.sh` (modelo y dibujo, `tools/blender/build_logo.py`) y después `bash tools/build_branding.sh` (composición con Pillow y las fuentes del proyecto). Se importan como texturas normales (con `importer="keep"` entraban dos veces en el APK de Android y no se podía firmar). El texto de `carga.png` va dentro de la imagen, porque se muestra antes de que exista `texts.gd` (lo toma de `nombre_juego` y `cargando_parque` al generarla). Ajustes en `project.godot` (`boot_splash/*`, `config/icon`); comprobado en `tests/test_export.gd`.

**Naranja de la marca en los menús** (usuario, 04-10-2026): el nombre y todos los títulos de los menús, que van en Russo One, se escriben en el naranja del logotipo (`UiStyle.BRAND`, `#f07d28`): `main.gd::label()` lo aplica a los títulos de 26 px o más, salvo a los que llevan un color con significado (nota de la foto, nivel superado o no). Dentro del juego (visor, Academia) no se usa. Licencia de las tipografías en el README y en `scripts/ui_style.gd`; el texto de la OFL de Russo One (`assets/fuentes/RussoOne-OFL.txt`) va dentro de los ejecutables.
