# 26. Lo que falta para una versión de Android perfecta

> **Estado**: 🚧 **en curso** (lista del 04-10-2026). Primera tanda hecha el 05-10-2026, marcada con ✅ en las tablas y resumida en el §«Hecho el 05-10-2026». Probada en el emulador (20:9) y en `tests/test_touch.gd`; **falta probarla en un teléfono real**.
> **Punto de partida**: el APK arranca y se juega entero con los dedos. Probado por el usuario en un Redmi Note 14 Pro 5G (unos 35 FPS en el perfil Bajo) y en el emulador (`tools/test_android.sh`, `tests/test_touch.gd`). Interfaz táctil funcional en [13, última sección](13_INTERFAZ_MOVIL_UTILIZABLE.md).

Ordenado por bloques; dentro de cada uno, de más a menos importante. **Esfuerzo**: S (horas), M (un día), L (varios días).

## A. Pantalla y disposición

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| A1 | **✅ Hecho: `main.gd::fit_frame()` (aspecto `expand` con la interfaz táctil, el juego centrado, capas desplazadas por `frame_offset`), botones en las bandas (`touch_controls.gd`), pantallas y menús a todo el ancho (`full_rect()`), y a simple vista el parque llena la pantalla.** **Usar toda la pantalla** en 20:9 y 19,5:9: hoy el juego ocupa un 16:9 centrado con bandas negras. Pasar a `aspect = expand`, dejar el visor en 16:9 y llevar las columnas de botones a las bandas | Los botones dejan de tapar la imagen y quedan bajo los pulgares | M |
| A2 | **✅ Hecho: `safe_inset` en `fit_frame()`; las columnas de botones no entran en la zona de la muesca. Sin probar en un teléfono con muesca.** **Zona segura**: respetar muesca, cámara perforada y esquinas redondeadas (`DisplayServer.get_display_safe_area()`) | En algunos teléfonos un botón puede quedar bajo la cámara | S |
| A3 | **Tamaño táctil mínimo** (7,6 mm, unos 84 px virtuales) en todas las pantallas: menú, encargo, resultado, equipo, gráficos, lista y panel de la Academia, tarjetas del arcade, álbum | Hoy son los del escritorio: se aciertan, pero justos | L |
| A4 | **Texto mínimo legible** (unos 22 px virtuales) y repaso con `check_text_fit.gd` en perfil móvil | Informes de la foto, pistas y panel de la Academia son pequeños en 6,7" | M |
| A5 | Tabletas y plegables (4:3, 16:10): comprobar la disposición | El 16:9 fijo deja bandas arriba y abajo | S |

## B. Controles

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| B1 | **✅ Hecho (apretar enfoca, soltar dispara, deslizar fuera cancela).** **Disparador en dos fases**: mantener enfoca y bloquea, soltar dispara, deslizar fuera cancela ([13 §4.1](13_INTERFAZ_MOVIL_UTILIZABLE.md)) | Es el gesto de una cámara, y ahorra el botón AF | M |
| B2 | **Rueda de enfoque manual** con ganancia ligada a la profundidad de campo, y enfoque por zonas ([13 §3](13_INTERFAZ_MOVIL_UTILIZABLE.md)) | Con − y + el enfoque manual es lento; telemétrica y TLR lo usan siempre | L |
| B3 | **✅ Hecho (`control_strip.gd`, un paso cada 34 px).** **Arrastrar sobre una ficha de la tira** para cambiar su valor, además de − y + | Un gesto en vez de dos toques | S |
| B4 | **✅ Hecho (`main.gd::check_long_press()`, 0,55 s).** **Pulsación larga** sobre la imagen: bloqueo de foco y exposición en ese punto | Sustituye al botón «Bloqueo» | S |
| B5 | **✅ Hecho (`main.gd::rumble()` hace vibrar el teléfono; respeta la opción de vibración). Sin probar en un teléfono.** **Vibración háptica** al enfocar, disparar y llegar a un tope (`Input.vibrate_handheld`) | Confirmación sin mirar | S |
| B6 | **Sensibilidad** de la mirada y de la palanca ajustables; **modo zurdo** (columnas espejadas) | Cada mano y cada pantalla son distintas. Invertir la mirada ya está (Opciones) | S |
| B7 | **✅ Hecho (`main.gd::go_back()`: lo mismo que Escape, y sale del juego desde el menú).** **Botón y gesto «atrás» de Android**: pausa durante la partida, volver en las pantallas | Hoy no hace nada dentro del juego | S |
| B8 | **Giroscopio** opcional para el ajuste fino del encuadre | Apuntar moviendo el teléfono, como una cámara | M |
| B9 | **✅ Hecho: botones «Agacharse» y «Correr», que se quedan puestos.** Agacharse en el parque grande; correr con un botón en vez de llevar la palanca al borde | Falta el primero; el segundo es poco preciso | S |
| B10 | Mando Bluetooth: probarlo en el teléfono (el código es el del escritorio) | Sin verificar en Android | S |

## C. Rendimiento y gráficos

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| C1 | *(En parte: el contador de FPS del móvil ya enseña CPU, física, llamadas de dibujo y triángulos; falta leerlo en teléfonos reales.)* **Medir en teléfonos reales** con un contador de tiempos por fase (CPU, GPU, viandantes) y fijar el objetivo: 60 FPS en gama media, 30 estables en gama baja | 35 FPS en Bajo en un gama media-alta es poco; no se sabe aún dónde se va el tiempo | M |
| C2 | *(El visor ya se dibuja a 1280 × 720 en `gl_compatibility`, no a la resolución de la pantalla.)* **Perfil automático por dispositivo** y resolución interna escalable (el visor puede renderizar al 70–80 %) | La pantalla es de 2712×1220: es donde más se gana | M |
| C3 | Coste de los 21 viandantes en `gl_compatibility`: pieles, sombras, animación en CPU; niveles de detalle por distancia | Probable cuello de botella | L |
| C4 | **Precompilar sombreadores** en la carga | Evita tirones la primera vez que aparece cada material | M |
| C5 | Límite de FPS elegible (30/60) y pausa del render en segundo plano | Batería y temperatura | S |
| C6 | Renderizador **Mobile (Vulkan)** como opción en gama alta | Efectos del escritorio que `gl_compatibility` no tiene | L |
| C7 | Texturas comprimidas ETC2/ASTC y revisión del tamaño del APK (44 MB) y de la VRAM (< 60 MB) | Descarga y memoria | S |
| C8 | Tiempo de arranque en frío en el teléfono | En el emulador son unos 8 s | S |

## D. Contenido que el móvil no tiene

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| D1 | **Vida del parque** en el nivel `lo`: palomas, patos, perro y figurantes no existen en Android | El parque del móvil está más vacío que el del escritorio | M |
| D2 | Parque grande en el móvil: medir con sus 45 viandantes y, si hace falta, reducirlos | Sin medir | S |
| D3 | Efectos del visor (viñeteo, aberración, ruido del LCD) y profundidad de campo en la foto en `gl_compatibility` | Parte del aprendizaje (el fondo desenfocado) depende de verlo | M |

## E. Sistema

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| E1 | **✅ Hecho (`main.gd::to_background()`: pausa y silencio).** **Ciclo de vida**: pausar la partida y el sonido al ir a segundo plano o recibir una llamada, y reanudar bien | Hoy vuelve, pero el juego sigue corriendo | S |
| E2 | **Guardar fotos del álbum en la galería** del teléfono y compartirlas | Es lo que uno espera de un juego de fotos | M |
| E3 | Copia de seguridad del progreso (copia automática de Android) | No perderlo al cambiar de teléfono | S |
| E4 | Orientación apaisada en los dos sentidos; mantener la pantalla encendida durante las demostraciones | Comodidad | S |
| E5 | Idioma del sistema ([25](25_TEXTOS_Y_MULTIIDIOMA.md)) | Tiendas internacionales | L |

## F. Distribución

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| F1 | **APK de publicación** firmado con clave propia (hoy es de depuración) y **AAB** para Google Play | Requisito de la tienda; el de depuración pide permisos de origen desconocido | M |
| F2 | Icono adaptativo, nombre e imagen de carga para Android | El icono actual no se adapta a las formas de cada lanzador | S |
| F3 | Código de versión automático y `targetSdk` al día | Requisito de Play en cada subida | S |
| F4 | Ficha: capturas en móvil, descripción, política de privacidad (no se recoge nada), clasificación por edades | Requisito de Play; itch.io pide menos | M |
| F5 | Canal de Android en itch.io | Distribución inmediata sin tienda | S |

## G. Calidad

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| G1 | **Las suites del juego dentro del dispositivo** (tutorial, arcade, Academia jugada) y no solo la prueba de humo | Hoy se prueban en el PC | M |
| G2 | Emulador con varias pantallas (teléfono pequeño, tableta, 20:9) y capturas de cada pantalla | Detectar solapes antes de llegar al teléfono | M |
| G3 | Un teléfono de gama baja de referencia y cifras guardadas | Saber cuándo algo empeora | S |
| G4 | Exportación y batería de Android en integración continua ([09](09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md) fase 4) | Que no se rompa sin enterarnos | M |
| G5 | Accesibilidad: tamaño de texto ajustable, contraste, daltonismo en los resaltes | Público amplio | M |

## Hecho el 05-10-2026

- **Toda la pantalla** (A1, A2): en 20:9 ya no hay bandas negras. El juego sigue dispuesto sobre 1280 × 720, centrado; la ventana enseña más (`content_scale_aspect = expand`, solo con la interfaz táctil) y `main.gd::fit_frame()` desplaza todas las capas (`frame_layer()`). Los botones táctiles salen a las bandas, fuera de la imagen; pantallas y menús cubren todo el ancho; a simple vista (parque grande, cámara bajada) el parque llena la pantalla, y al subir la cámara vuelve el visor de 16:9, que es lo que se fotografía. En el PC se prueba con `--resolution 1600x720 -- --touch`.
- **Controles** (B1, B3, B4, B5, B7, B9): disparador en dos fases, deslizar sobre un ajuste de la tira, pulsación larga para bloquear foco y exposición, vibración del teléfono, botón «atrás» del sistema, y «Correr» y «Agacharse» en el parque grande.
- **Rendimiento** (C1, C3 en parte, C5): medido en el PC con el renderizador de Android (`-- --metrics`), un fotograma cuesta unos 5 ms de procesador y 1,2 ms de gráfica: **lo que frena el teléfono es el código, no los gráficos**. De esos 5 ms, 2,7 son los 21 viandantes (1,4 en doblar los esqueletos, 1,3 en la navegación). Primer recorte: en el móvil y en el navegador, quien queda fuera de cuadro se dobla un fotograma de cada cuatro, con todo el tiempo y la distancia acumulados (`main.gd::pose_person()`, `POSE_EVERY`; se prueba en el PC con `-- --lean`): de 6,25 a 5,56 ms por fotograma, un 11 %. La navegación, la foto y la nota no cambian. Límite de fotogramas por segundo elegible, 60 por defecto ([23](23_GRAFICOS_PERSONALIZADOS.md)). Segunda tanda, el mismo día: quien está lejos dentro de cuadro se dobla uno de cada dos fotogramas (`POSE_FAR`); fuera de cuadro los viandantes **caminan** uno de cada dos fotogramas con el tiempo de ambos (`step_person()`), que es lo que ya hace el juego entero en un equipo lento; y `travel_clear()`, lo más caro de la navegación, reutiliza forma y consulta, hace la lista de gente una vez por fotograma (`everybody()`) y descarta por distancia antes de la geometría (mismas respuestas por construcción y cifras equivalentes en `tools/measure_flow.gd`; esto vale también en el escritorio: [NAVEGACION](../NAVEGACION_Y_COLISIONES.md), última sección). **Parque grande, con el renderizador de Android en el PC: de 9,7 a 5,6 ms por fotograma** (y la medida toca suelo en 5,56 ms, los 180 Hz del monitor: el ahorro real puede ser mayor). El bucle de vecinos de `crowd_graph.gd::walk()` (cada uno mira a los otros 44) ya pasa por el mismo cribado. Pendiente: medir de nuevo en el teléfono.
- **Imagen**: los maniquíes salían mucho más oscuros de lo debido en OpenGL (color de vértice convertido dos veces) y la imagen era más brillante y dura que la de escritorio; corregido y calibrado contra Forward+ ([ESCENARIO](../ESCENARIO_Y_RENDIMIENTO.md), «Misma imagen en Vulkan y en OpenGL»). Vale igual para la web.
- **Tamaño de los botones** (A3, en parte): fuera de la imagen los botones táctiles ocupan todo el ancho de la banda y miden 74–78 unidades de alto (unos 8 mm en 6,7"), con letra de 20 px; el usuario los veía pequeños. Sobre la imagen (pantallas 16:9, lecciones) conservan la columna estrecha. Quedan por agrandar los de menús y pantallas.
- **Referencia en un teléfono real** (usuario, 05-10-2026, Redmi Note 14 Pro 5G): **42 FPS en Medio en el parque grande**, en una escena cargada (antes, unos 35 en Bajo); el contador daba unos 23,5 ms por fotograma, con el procesador como límite. «Bastante usable.»
- **Menús y pantallas para el dedo** (A3, segunda parte; usuario: «termina de arreglar el interfaz con controles ampliados en los menús»): la tarjeta del menú principal se dibuja 1,22 veces mayor, con flechas más grandes, y ocupa el sitio del lema (`main_menu.gd::FINGER`); los botones y listas de todas las pantallas crecen hasta 66 y 56 unidades de alto alrededor de su centro (`main.gd::finger_rect()`), con filas más altas en las listas desplegables; pantalla de gráficos propia del renderizador ligero (`show_light_graphics()`: perfil, límite de FPS y contador, sin los parámetros del escritorio); filas de 78 unidades en la lista de la Academia; el panel de la lección crece y sus cuatro botones con él; pausa y menú de la lección con más separación. «Atrás» vuelve también desde Insignias, Álbum y Academia. Evidencias: `build/android/evidencias/` (23 pantallas en el emulador, 20:9). Queda: el texto pequeño de informes, insignias y panel de la lección (A4), y aprovechar mejor el espacio en Equipo, Insignias y Resultado.
- **Tercera medida en el Redmi** (usuario, 05-10-2026, APK de cierre): **54 FPS** en Medio en el parque grande (42 antes de los recortes de procesador, unos 35 en Bajo al empezar).
- **Sistema** (E1): pausa y silencio al pasar a segundo plano.
- La pantalla de gráficos del móvil ya no ofrece modo de ventana, tamaño ni sincronía vertical.
- **También para la versión web** ([27](27_VERSION_WEB.md) B7): la interfaz táctil y la pantalla completa se activan en el navegador de un teléfono o una tableta (`web_android`, `web_ios`).

Siguiente, por orden: A3 y A4 (tamaños táctiles y de texto en todas las pantallas), medir en el teléfono con el contador nuevo (C1) y, según salga, C3; D1 y D3; F1.

## Orden propuesto

1. **Jugarlo cómodo**: A1, A2, A3, B1, B7, E1.
2. **Que vaya fluido**: C1, C2, C3, C5.
3. **Que sea el mismo juego**: D1, D3, B2, B5.
4. **Publicarlo**: F1, F2, F3, F5, E2.
5. **Pulido y red de seguridad**: el resto.

iOS queda fuera de esta lista: comparte casi todo lo anterior, más su propia cadena de exportación.
