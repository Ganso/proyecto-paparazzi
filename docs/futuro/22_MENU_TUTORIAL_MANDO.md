# 22 · Menú de modos, tutorial, mando y ayudas por dispositivo

**Estado: ✅ Implementado (02-10-2026)**, encargo del usuario.

## 1. Menú principal: los modos en grande (`scripts/main_menu.gd`)

Los modos **Tutorial, Arcade, Sandbox, Academia, Opciones e Historia** (en ese orden desde el 03-10) se muestran de uno en uno en una tarjeta grande sobre el parque vivo, con ‹ › a los lados y puntos debajo. Se cambia con **← →** (también A/D), la **cruceta** o **LB/RB**, y se entra con **Intro / A** o el botón «Entrar». Cada tarjeta lleva lo suyo: el progreso del Arcade y de la Academia, escenario y luz para el Sandbox, y en Opciones equipo, gráficos, tema claro/oscuro, interfaz cámara/clásica y ayuda en pantalla. El modo elegido se recuerda mientras dura la partida. **Historia** aparece anunciado con la etiqueta «Próximamente» y un botón desactivado («Disponible en una versión futura»): su diseño está en [10](10_MODO_HISTORIA_DUAL_LEGADO.md).

## 2. Tutorial (`scripts/tutorial.gd`)

Doce pasos en el parque clásico que se comprueban solos y avanzan con «✓ ¡Bien hecho!»: bienvenida, mirar, inclinar, zoom (más de 70 mm y menos de 40 mm), bajar y subir la cámara, autofoco sobre una persona, ocultar y mostrar la ayuda en pantalla, disparar y leer el revelado, un encargo real (al menos 50 puntos), el diafragma en prioridad a la apertura y el enfoque manual con la imagen partida; al final, al Arcade o al menú. Cada paso se puede saltar y el tutorial se puede dejar. Las instrucciones nombran los controles del dispositivo en uso, dibujados como teclas o botones.

## 3. Mando y ayudas por dispositivo

- **Regla permanente**: ningún texto de ayuda escribe una tecla a mano. Los textos llevan `{control}` y `Texts` los rellena con `scripts/input_glyphs.gd`, la tabla única de controles para teclado, Xbox, PlayStation y Nintendo. La interfaz sigue al **último dispositivo usado** (`main.gd::_input()` → `Glyphs.note()`).
- **Teclas y botones dibujados** (`scripts/glyph_label.gd`): en los textos, una tecla (`⟦Q⟧`) es una tecla en trapecio con su letra y un botón del mando (`⦅A⦆`) un círculo azul (cápsula si el nombre es largo). `Texts.get_rich()` da el texto marcado; `get_text()`, el mismo sin marcas para etiquetas normales.
- **Mando en la búsqueda** ([14](14_SOPORTE_GAMEPAD.md) fases 1–3, salvo la migración completa a `InputMap`): stick izquierdo mirar (zona muerta 0,15, respuesta cúbica, L3 precisión ×⅓); stick derecho ↕ zoom y ↔ enfoque manual; **RT en dos fases** (a medias enfoca, a fondo dispara); cruceta ←→ elige diafragma, velocidad, ISO o compensación y ↑↓ lo cambia (autorrepetición); LB/RB punto de enfoque; A autofoco (manivela en la TLR); B controles y atrás; X ayuda en pantalla; Y bajar o subir la cámara; R3 tercios; LT lupa de la TLR; View controles sobre el visor; Menu pausa. Los botones de las pantallas toman el foco para recorrerlas con la cruceta (A pulsa, B vuelve). **Paseando** (parque grande, cámara bajada): seta izquierda andar, derecha mirar, **L3 correr** (hasta soltar la seta) y **LT mantenido agacharse**. **En el menú**, en la tarjeta del modo libre, ↑↓ llevan a las tarjetas de escenario y a las horas del día, y ahí ←→ recorren la fila (con vecinos de foco explícitos) en vez de cambiar de modo; LB/RB siguen cambiando de modo (`tests/test_input.gd`, `tests/test_big_park.gd`).
- **Pantalla de controles** (H, o B con mando): con mando, el **mando dibujado** con la función de cada botón (`scripts/pad_diagram.gd`, líneas ordenadas sin cruzarse); con teclado, el **teclado dibujado** con las teclas del juego encendidas por grupos de color y el ratón con sus botones (`scripts/keyboard_diagram.gd`).
- La ayuda en pantalla y la línea de controles del HUD usan los mismos glifos.
- «Colimador» pasó a **«punto de enfoque»** en todo el juego y la documentación, a petición del usuario.

## 4. Pausa y salir de la fase

**Esc**, el botón «✕ Salir» sobre la imagen o **Menu/Start** abren la pausa: Seguir, Ver los controles o Salir al menú, que pide confirmación («Se pierde lo que llevas en ella»). Los gráficos ya no se cambian durante una fase: solo desde Opciones del menú.

## 5. Pruebas y evidencias

- `tests/test_input.gd`: textos por dispositivo y familia de mando, marcas de tecla y botón, botones del mando en la búsqueda, ayuda con el mando dibujado, pausa y salida confirmada, zona muerta de los sticks.
- `tests/test_tutorial.gd`: los cinco modos del menú y su navegación, y el tutorial completo haciendo lo que pide cada paso.
- Capturas en `tools/capture_screens.gd` (`18_menu_*`, `19_tutorial`, `20_ayuda_teclado`, `21_ayuda_mando`, `22_pausa`).

## 7. Referencias durante la búsqueda (02-10-2026)

- **El sujeto en miniatura**: arriba a la izquierda, una copia pequeña del personaje del encargo gira 360° cada 8 s (`main.gd::update_portrait()`, su propio mundo 3D), para verlo desde todos los lados y no perder la referencia. La ayuda en pantalla queda debajo.
- **Corredores**: el sujeto de un nivel de corredores nunca es el que pasa por el carril más cercano, en primer plano: se elige uno de los carriles 1 a 3.
- **«Cara», no «ojos»**: los maniquíes no tienen ojos; la condición `ojos` se llama «Cara nítida» y mide el desenfoque a media altura de la cabeza.
- **Guías de encuadre**: en los niveles con proporción áurea el visor dibuja sus líneas doradas (φ, 38 % y 62 %); en el resto, las de tercios. En la TLR, las del cuadrado. G (R3) las oculta.
- **Movimiento en velocidades**: el informe y la condición de congelar ya no hablan de milímetros: dicen la velocidad mínima a la focal usada («a 135 mm hace falta 1/1000 s o más rápido; usaste 1/250 s»), si el problema es el pulso (regla 1/focal) o si ni 1/1000 s basta (menos focal, o fotografiarla cuando venga hacia ti). `Photography.needed_shutter()`.

## 8. Muñeco con tarjeta e interfaz clásica retirada (02-10-2026)

- El sujeto en miniatura va sobre una **tarjeta translúcida oscura** (como la de la ayuda) para destacar sobre cualquier fondo. Muñeco, ayuda en pantalla y botones se colocan siempre por debajo de la barra superior y del panel del encargo cuando estos se ven (`main.gd::hud_clear_top()`), y «Bajar la cámara» por encima de la barra inferior; el fotómetro de mano de la TLR pasa a la derecha del cuadrado. Comprobado en las cuatro cámaras, con Tab, con y sin ayuda, cámara bajada, tutorial, parque grande y tema oscuro.
- **Interfaz clásica retirada en escritorio**: con Tab y la ayuda en pantalla ya no aportaba nada. Se quita de Opciones y de la pantalla de equipo; en escritorio siempre se usa la de cámara y en el móvil la clásica hasta que exista la interfaz táctil ([13](13_INTERFAZ_MOVIL_UTILIZABLE.md)). `--interface=clasica` la sigue forzando para pruebas y capturas.

## 9. Correcciones del 03-10-2026

- Las flechas ← → del menú no hacían nada: el botón «Entrar» con el foco se las quedaba para navegar. El menú las lee ahora en `_input()`.
- En el parque grande la tecla **Y** también sube y baja la cámara (antes solo el clic derecho o el botón Y del mando).
- Las barras del HUD ya no se despliegan al acercar el ratón a los bordes: solo con Tab.
- Las texturas del suelo se leen de los bytes del fichero (`load_webp_from_buffer`): `Image.load_from_file()` sobre `res://` daba un aviso por textura en cada arranque.

## 6. Pendiente

> **Pendiente mayor (usuario, 03-10-2026): replantear por completo el control con teclado y ratón y con mando, que sigue siendo confuso.** No es un retoque: hay que rediseñar desde cero qué hace cada tecla, botón y gesto (mirar, andar, zoom, enfoque, exposición, atajos), con el «control en mano» (ver más abajo) como base y los atajos directos solo para quien los quiera. Hasta entonces no se añaden atajos nuevos.

Migración completa a acciones de `InputMap` y vibración ([14](14_SOPORTE_GAMEPAD.md)), probar con un mando físico.

## Vibración del mando (02-10-2026)

`main.gd::rumble()` hace vibrar el mando solo mientras es el dispositivo en uso: un golpe seco al disparar, un toque al confirmar el autofoco y un traqueteo con la manivela de la TLR. Se activa o desactiva en **Opciones → Vibración del mando** (`set_vibration()`, clave `vibracion` de `user://interfaz.cfg`, activada por defecto). Comprobado en `tests/test_input.gd` con el contador `rumbles` (en las pruebas no hay mando conectado). **Pendiente de probar con un mando físico**, como el resto del soporte de mando.

## Álbum de fotos (02-10-2026)

- **Qué guarda**: toda foto aceptada de un encargo (arcade, tutorial o Academia; el sandbox no) que alcance **80 puntos** (`Album.MIN_SCORE`). Se guarda **revelada**: `main.gd::save_to_album()` la pasa por el mismo material de revelado de la pantalla de resultado (`photo_material()`: exposición, desenfoque, arrastre o barrido, grano, viñeteo y aberración del objetivo) en un `SubViewport` aparte y la escribe como JPG de 1.280 px de ancho (cuadrada con la TLR).
- **Dónde**: `user://album/foto_NNNNN.jpg`, con sus datos (nota, estrellas, focal, diafragma, velocidad, ISO, fecha, nivel y si fue un barrido) en `user://album/album.cfg` (`scripts/album.gd`). Se conservan las **60 más recientes**.
- **Pantalla**: Opciones → **Álbum** (`show_album()`): rejilla de ocho miniaturas por página con su pie; al pulsar una se ve grande (`show_album_photo()`), con botón para borrarla; «Abrir la carpeta» la abre en el gestor de archivos.
- Solo el juego real escribe en el álbum (`badges_count()`): las pruebas y las herramientas de captura usan otra carpeta (`Album.DIR`, o la variable de entorno `PAPARAZZI_ALBUM_DIR`).
- Pruebas: `tests/test_album.gd` (con display, 20 comprobaciones): la foto revelada se guarda con sus datos y no es un fotograma negro, la pantalla la muestra, se borra, y el álbum se queda con las 60 más recientes.
- Pendiente: guardar a mano fotos del sandbox o de menos de 80 puntos.

## Correcciones con mando (03-10-2026, aviso del usuario)

- **La ayuda volvía a las teclas jugando con mando**: bastaba con que el ratón se moviera 3 píxeles (un roce en la mesa, la deriva del propio sensor) para que `input_glyphs.gd::note()` diera el teclado por dispositivo en uso. Ahora el ratón solo toma el relevo si recorre 60 píxeles en menos de 0,4 s (`MOUSE_SWITCH`); teclas y clics siguen cambiándolo al momento.
- **Al andar con la seta izquierda se miraba hacia arriba**: en el parque grande, a pie, la seta izquierda anda y la derecha mira, pero `update_pad()` también aplicaba la izquierda a la mirada (hacia delante = inclinar hacia arriba). Ahora, mientras se camina sin la cámara al ojo, la seta izquierda solo anda.
- Pruebas en `tests/test_input.gd` (el roce de ratón no cambia la ayuda; moverlo de verdad sí). La seta no se puede simular sin un mando conectado: **pendiente de comprobar con el mando físico**.
- **El mando no pulsaba nada en los menús** (segundo aviso, 03-10-2026): la acción `ui_accept` de Godot no trae ningún botón del mando (solo Intro y Espacio), así que el foco se movía con la cruceta pero A no pulsaba. `main.gd::register_pad_ui()` añade A a `ui_accept` y B a `ui_cancel`. Las tarjetas del arcade y del álbum tampoco podían recibir el foco; ahora sí (el foco empieza en el primer nivel por superar), y cualquier pantalla deja el foco en su primer botón si nadie lo ha puesto (`ensure_modal_focus()`).
- **Detección del mando por sondeo**: además de por eventos, `poll_pad()` mira cada fotograma los botones y las setas; así ninguna pantalla que se quede antes con el evento deja la ayuda con las teclas.
- **Registro para diagnosticar** en `user://dispositivo.log` (en Linux, `~/.local/share/godot/app_userdata/PhotoHacks/`): cada cambio de dispositivo con el evento que lo causó y, andando con el mando, una línea por segundo con las dos setas y la vista. Sirve para ver en la máquina del jugador qué devuelve la ayuda a las teclas o si la seta izquierda mueve la vista.

## Control en mano, final del tutorial y pista de bajar la cámara (03-10-2026, usuario)

- **Control en mano** (`scripts/control_strip.gd`, `main.gd::selectable_controls()`, `current_control()`, `select_control()`, `change_control()`): es la manera normal de manejar una cámara con controles manuales. Sobre la parte baja del visor hay una tira con los ajustes que lleva el jugador en la cámara montada (zoom, enfoque manual, diafragma, velocidad, ISO, compensación, según el modo) y **uno está elegido** (en azul; también se marca en la lista de ayuda en pantalla). Con el **mando**, cruceta ←→ elige y ↑↓ cambia. Con el **ratón**, un clic en el ajuste (o pulsar la rueda: el siguiente) lo elige y la **rueda** lo cambia; la rueda sobre un ajuste lo elige y lo cambia a la vez. Con el **teclado**, `Tab` elige (también `,` `.`) y `Re Pág`/`Av Pág` cambian. Al empezar está elegido el zoom, así que la rueda sigue haciendo zoom. Los atajos directos (Q E, Z X, C V, R T, Mayús+rueda…) siguen ahí para usuarios avanzados. Controles `{elegir_control}` y `{cambiar_control}` en `input_glyphs.gd`. Lo comprueba `tests/test_input.gd`.
- **Final del tutorial**: ya no es un panel sobre el visor que dejaba al jugador en el parque sin saber qué hacer, sino una pantalla propia, «Tutorial completado» (`main.gd::show_tutorial_end()`), con tres salidas explicadas: Jugar al Arcade (la recomendada, con el foco), Ir a la Academia y Menú principal. El paso del diafragma enseña el control en mano.
- **Pista de bajar la cámara** (`main.gd::update_hunt_hint()`): tras 30 s buscando con la cámara al ojo sin tener al objetivo en el encuadre (y luego cada 75 s), un aviso recuerda que se puede bajar la cámara para buscar a simple vista y volver a subirla, con la tecla o el botón del dispositivo en uso (`pista_bajar_camara`). No sale en sandbox, tutorial ni Academia.

## Una sola interfaz (03-10-2026, usuario: «a veces es confuso: en unos sitios la de la cámara, en otros la del juego»)

En escritorio la interfaz es **siempre la de la cámara**: el visor de cada cuerpo, la tira del control en mano y la ayuda en pantalla. Las barras de la interfaz clásica **ya no aparecen nunca** sobre ella (`main.gd::update_hud_visibility()`): ni en las lecciones de la Academia ni con Tab.
- **Academia**: los resaltes de las lecciones señalan lo de la propia cámara (`academy.gd::highlight_rect()`): el exposímetro del visor (`camera_body.meter_box`) y el ajuste correspondiente en la tira (`control_strip.gd::chip_rect()`), que ahora se ve también durante la demostración. Textos de teoría y pistas sin teclas escritas a mano (`{diafragma}`, `{velocidad}`, `{iso}`, `{af}`, `{disparar}`, `{tercios}`).
- **Tab / View** pasan al siguiente control en mano (antes desplegaban las barras); `,` `.` siguen valiendo.
- Tras una pantalla (encargo, resultado, pausa) ya no asoman los LED de la cámara, y los botones de continuar nombran el control del dispositivo (`entrar_fase`, `seguir_probando`, `academia_seguir`).
- **Equipo y gráficos con cruceta**: ←→ cambia una lista sin abrirla, la lista conserva el foco al reconstruirse la pantalla y la lista de gráficos se desplaza con el foco (`main.gd::option()`).
- Ayudas de captura: `--strip-demo` (el control en mano trabajando), `--device=teclado|mando`, `--screen=ayuda`; guion en `tools/videos/control_en_mano.txt`.

## Tutorial: «Continuar», tres maneras de manejar los controles y vuelta al menú (04-10-2026, usuario)

- Al lograr un paso ya no se pasa solo al siguiente: aparece el botón **«Continuar»** (Intro / A también) y el jugador decide cuándo seguir. Catorce pasos: se añaden dos que solo explican (`INFO`): **«controles»** (las tres maneras: Tab y Re/Av Pág, clic y rueda, o el atajo directo; los atajos se consultan con la ayuda) y **«abruma»** (quitar la ayuda en pantalla y quedarse con la tira, donde solo salen los controles que se pueden cambiar). Los pasos del diafragma y del enfoque manual dicen su atajo.
- El paso de bajar la cámara avisa de que **tras la verja solo hay figurantes**; el del encargo recuerda bajar la cámara para buscar y subirla para la foto.
- La nota del tutorial en el resultado de la foto va junto al título (abajo se montaba sobre la línea de la mejor foto).
- La pantalla final ofrece también **repetir el tutorial**.
- **El menú recuerda el último modo** entre sesiones (`main_menu.gd::load_mode()`, `remember_mode()`, `user://interfaz.cfg`).

## Tutorial hasta el parque grande y mando con A solo para aceptar (04-10-2026, usuario)

- **Tutorial**: «mirar» e «inclinar» son un solo paso (a los lados y arriba y abajo). Los pasos que hablan de la ayuda en pantalla la activan. Sin punto y coma en ningún texto. Con mando, los pasos de controles, diafragma, ayuda y enfoque manual tienen su propio texto (`tutorial_<paso>_mando`), sin ratón ni teclas. **Termina en el parque grande** (`WALKING`: «paseo», «sacar», «foto_paseo»): la escena se recarga allí (`Tutorial.resume_step`, `main.gd::start_tutorial()`) y enseña a andar con la cámara bajada, sacarla para disparar y bajarla para seguir.
- **Mando**: **A solo acepta** (continuar en el tutorial, «siguiente» en teoría y demostración de la Academia, pulsar el botón enfocado en las pantallas). Enfocar es el gatillo a medias y disparar, a fondo. La manivela de la TLR pasa a X cuando hace falta. En la práctica y el examen de la Academia A ya no salta de fase.
- **Menú de la lección** (`main.gd::show_lesson_menu()`: Esc, el botón ✕ o Menu en el mando): seguir, siguiente, atrás, pausar la escena y salir de la lección, todo al alcance del mando. Sobre el panel se dibuja qué hace el mando en cada fase.
- **Listas con desplazamiento** (Academia, gráficos): la seta derecha (o la izquierda) las mueve como una rueda (`scroll_with_stick()`), y la cruceta recorre también las filas «Próximamente».
- **Nivel 14 del arcade**: ya no pide «exactamente dos personas más» (no quedaba claro quién contaba): ahora es «Todo manual», con el sujeto llenando al menos media foto. Las condiciones de compañía explican quién cuenta (quien ocupa un décimo de la altura).
- **Parque grande**: la ayuda de enfoque manual ya no parpadea al andar con la cámara bajada.

## Versión a la vista y novedades tras actualizar (05-10-2026)

- **Indicador de versión**: en la esquina inferior izquierda del menú, en letra de 10 px, «v0.3.2-alpha · Android · OpenGL» (versión de `project.godot`, sistema y renderizador). Es para pruebas y soporte.
- **Novedades**: al arrancar, si la versión es posterior a la última que abrió ese jugador (`interfaz.cfg`, `version_vista`), el menú abre una ventana con un bloque por versión intermedia, de la más nueva a la más antigua, cada una con dos o tres puntos y en una lista que se desplaza (`main.gd::VERSION_NOTES` y `check_version()`, `main_menu.gd::show_news()`, textos `novedades_*`). Las versiones que cambian los valores gráficos por defecto (la 0.3.1) lo dicen en rojo y la ventana ofrece **«Restablecer gráficos»** (`main.gd::reset_graphics()`: perfil que le toca al equipo, 60 FPS y sincronía vertical). Quien ya tenía el juego de antes de existir el aviso lo ve desde la 0.3.1; un jugador nuevo no ve nada. En el navegador, el aviso de la versión web sale después. Solo en el juego real: pruebas y capturas no lo abren ni tocan `interfaz.cfg`.

## Aviso de versión nueva en itch.io (05-10-2026)

Al arrancar (solo el juego real, nunca pruebas ni herramientas), `main.gd::check_update()` pregunta a la dirección pública de itch «última versión de un canal» (`https://itch.io/api/1/x/wharf/latest?target=geese-bumps/photohacks&channel_name=<canal>`, la que usa su propio actualizador: sin clave ni cuenta, y sin enviar nada del jugador) por el canal de su plataforma (`windows`, `linux`, `mac`). Si la versión de allí es posterior, el menú enseña abajo a la derecha el botón «Versión x disponible · Descargar», que abre la ficha del juego. Sin red, sin respuesta o con una respuesta rara, no pasa nada. En el navegador no se pregunta: la página siempre sirve la última (y el navegador bloquearía la petición). **En Android no se pregunta**: el APK no pide ningún permiso, tampoco el de internet (`tests/test_export.gd` lo comprueba), y añadirlo queda a decisión del usuario. Se prueba con `-- --version-as=0.3.1` (finge una versión anterior sin tocar los datos del jugador).
