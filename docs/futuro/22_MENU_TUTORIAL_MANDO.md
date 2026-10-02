# 22 · Menú de modos, tutorial, mando y ayudas por dispositivo

**Estado: ✅ Implementado (02-10-2026)**, encargo del usuario.

## 1. Menú principal: los modos en grande (`scripts/main_menu.gd`)

Los modos **Arcade, Historia, Tutorial, Sandbox, Academia y Opciones** se muestran de uno en uno en una tarjeta grande sobre el parque vivo, con ‹ › a los lados y puntos debajo. Se cambia con **← →** (también A/D), la **cruceta** o **LB/RB**, y se entra con **Intro / A** o el botón «Entrar». Cada tarjeta lleva lo suyo: el progreso del Arcade y de la Academia, escenario y luz para el Sandbox, y en Opciones equipo, gráficos, tema claro/oscuro, interfaz cámara/clásica y ayuda en pantalla. El modo elegido se recuerda mientras dura la partida. **Historia** aparece anunciado con la etiqueta «Próximamente» y un botón desactivado («Disponible en una versión futura»): su diseño está en [10](10_MODO_HISTORIA_DUAL_LEGADO.md).

## 2. Tutorial (`scripts/tutorial.gd`)

Doce pasos en el parque clásico que se comprueban solos y avanzan con «✓ ¡Bien hecho!»: bienvenida, mirar, inclinar, zoom (más de 70 mm y menos de 40 mm), bajar y subir la cámara, autofoco sobre una persona, ocultar y mostrar la ayuda en pantalla, disparar y leer el revelado, un encargo real (al menos 50 puntos), el diafragma en prioridad a la apertura y el enfoque manual con la imagen partida; al final, al Arcade o al menú. Cada paso se puede saltar y el tutorial se puede dejar. Las instrucciones nombran los controles del dispositivo en uso, dibujados como teclas o botones.

## 3. Mando y ayudas por dispositivo

- **Regla permanente**: ningún texto de ayuda escribe una tecla a mano. Los textos llevan `{control}` y `Texts` los rellena con `scripts/input_glyphs.gd`, la tabla única de controles para teclado, Xbox, PlayStation y Nintendo. La interfaz sigue al **último dispositivo usado** (`main.gd::_input()` → `Glyphs.note()`).
- **Teclas y botones dibujados** (`scripts/glyph_label.gd`): en los textos, una tecla (`⟦Q⟧`) es una tecla en trapecio con su letra y un botón del mando (`⦅A⦆`) un círculo azul (cápsula si el nombre es largo). `Texts.get_rich()` da el texto marcado; `get_text()`, el mismo sin marcas para etiquetas normales.
- **Mando en la búsqueda** ([14](14_SOPORTE_GAMEPAD.md) fases 1–3, salvo la migración completa a `InputMap`): stick izquierdo mirar (zona muerta 0,15, respuesta cúbica, L3 precisión ×⅓); stick derecho ↕ zoom y ↔ enfoque manual; **RT en dos fases** (a medias enfoca, a fondo dispara); cruceta ←→ elige diafragma, velocidad, ISO o compensación y ↑↓ lo cambia (autorrepetición); LB/RB punto de enfoque; A autofoco (manivela en la TLR); B controles y atrás; X ayuda en pantalla; Y bajar o subir la cámara; R3 tercios; LT lupa de la TLR; View controles sobre el visor; Menu pausa. Los botones de las pantallas toman el foco para recorrerlas con la cruceta.
- **Pantalla de controles** (H, o B con mando): con mando, el **mando dibujado** con la función de cada botón (`scripts/pad_diagram.gd`, líneas ordenadas sin cruzarse); con teclado, el **teclado dibujado** con las teclas del juego encendidas por grupos de color y el ratón con sus botones (`scripts/keyboard_diagram.gd`).
- La ayuda en pantalla y la línea de controles del HUD usan los mismos glifos.
- «Colimador» pasó a **«punto de enfoque»** en todo el juego y la documentación, a petición del usuario.

## 4. Pausa y salir de la fase

**Esc**, el botón «✕ Salir» sobre la imagen o **Menu/Start** abren la pausa: Seguir, Ver los controles o Salir al menú, que pide confirmación («Se pierde lo que llevas en ella»). Los gráficos ya no se cambian durante una fase: solo desde Opciones del menú.

## 5. Pruebas y evidencias

- `tests/test_input.gd`: textos por dispositivo y familia de mando, marcas de tecla y botón, botones del mando en la búsqueda, ayuda con el mando dibujado, pausa y salida confirmada, zona muerta de los sticks.
- `tests/test_tutorial.gd`: los cinco modos del menú y su navegación, y el tutorial completo haciendo lo que pide cada paso.
- Capturas en `tools/capture_screens.gd` (`18_menu_*`, `19_tutorial`, `20_ayuda_teclado`, `21_ayuda_mando`, `22_pausa`).

## 6. Pendiente

Migración completa a acciones de `InputMap` y vibración ([14](14_SOPORTE_GAMEPAD.md)), recorrido con cruceta de las pantallas de equipo y gráficos con desplegables, y probar con un mando físico.
