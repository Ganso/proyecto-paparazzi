# 26. Lo que falta para una versión de Android perfecta

> **Estado**: ⏳ futurible (lista hecha el 04-10-2026, a petición del usuario, para decidir si se acomete).
> **Punto de partida**: el APK arranca y se juega entero con los dedos. Probado por el usuario en un Redmi Note 14 Pro 5G (unos 35 FPS en el perfil Bajo) y en el emulador (`tools/test_android.sh`, `tests/test_touch.gd`). Interfaz táctil funcional en [13, última sección](13_INTERFAZ_MOVIL_UTILIZABLE.md).

Ordenado por bloques; dentro de cada uno, de más a menos importante. **Esfuerzo**: S (horas), M (un día), L (varios días).

## A. Pantalla y disposición

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| A1 | **Usar toda la pantalla** en 20:9 y 19,5:9: hoy el juego ocupa un 16:9 centrado con bandas negras. Pasar a `aspect = expand`, dejar el visor en 16:9 y llevar las columnas de botones a las bandas | Los botones dejan de tapar la imagen y quedan bajo los pulgares | M |
| A2 | **Zona segura**: respetar muesca, cámara perforada y esquinas redondeadas (`DisplayServer.get_display_safe_area()`) | En algunos teléfonos un botón puede quedar bajo la cámara | S |
| A3 | **Tamaño táctil mínimo** (7,6 mm, unos 84 px virtuales) en todas las pantallas: menú, encargo, resultado, equipo, gráficos, lista y panel de la Academia, tarjetas del arcade, álbum | Hoy son los del escritorio: se aciertan, pero justos | L |
| A4 | **Texto mínimo legible** (unos 22 px virtuales) y repaso con `check_text_fit.gd` en perfil móvil | Informes de la foto, pistas y panel de la Academia son pequeños en 6,7" | M |
| A5 | Tabletas y plegables (4:3, 16:10): comprobar la disposición | El 16:9 fijo deja bandas arriba y abajo | S |

## B. Controles

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| B1 | **Disparador en dos fases**: mantener enfoca y bloquea, soltar dispara, deslizar fuera cancela ([13 §4.1](13_INTERFAZ_MOVIL_UTILIZABLE.md)) | Es el gesto de una cámara, y ahorra el botón AF | M |
| B2 | **Rueda de enfoque manual** con ganancia ligada a la profundidad de campo, y enfoque por zonas ([13 §3](13_INTERFAZ_MOVIL_UTILIZABLE.md)) | Con − y + el enfoque manual es lento; telemétrica y TLR lo usan siempre | L |
| B3 | **Arrastrar sobre una ficha de la tira** para cambiar su valor, además de − y + | Un gesto en vez de dos toques | S |
| B4 | **Pulsación larga** sobre la imagen: bloqueo de foco y exposición en ese punto | Sustituye al botón «Bloqueo» | S |
| B5 | **Vibración háptica** al enfocar, disparar y llegar a un tope (`Input.vibrate_handheld`) | Confirmación sin mirar | S |
| B6 | **Sensibilidad** de la mirada y de la palanca ajustables; **modo zurdo** (columnas espejadas) | Cada mano y cada pantalla son distintas. Invertir la mirada ya está (Opciones) | S |
| B7 | **Botón y gesto «atrás» de Android**: pausa durante la partida, volver en las pantallas | Hoy no hace nada dentro del juego | S |
| B8 | **Giroscopio** opcional para el ajuste fino del encuadre | Apuntar moviendo el teléfono, como una cámara | M |
| B9 | Agacharse en el parque grande; correr con un botón en vez de llevar la palanca al borde | Falta el primero; el segundo es poco preciso | S |
| B10 | Mando Bluetooth: probarlo en el teléfono (el código es el del escritorio) | Sin verificar en Android | S |

## C. Rendimiento y gráficos

| # | Qué falta | Por qué | Esfuerzo |
|---|---|---|:---:|
| C1 | **Medir en teléfonos reales** con un contador de tiempos por fase (CPU, GPU, viandantes) y fijar el objetivo: 60 FPS en gama media, 30 estables en gama baja | 35 FPS en Bajo en un gama media-alta es poco; no se sabe aún dónde se va el tiempo | M |
| C2 | **Perfil automático por dispositivo** y resolución interna escalable (el visor puede renderizar al 70–80 %) | La pantalla es de 2712×1220: es donde más se gana | M |
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
| E1 | **Ciclo de vida**: pausar la partida y el sonido al ir a segundo plano o recibir una llamada, y reanudar bien | Hoy vuelve, pero el juego sigue corriendo | S |
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

## Orden propuesto

1. **Jugarlo cómodo**: A1, A2, A3, B1, B7, E1.
2. **Que vaya fluido**: C1, C2, C3, C5.
3. **Que sea el mismo juego**: D1, D3, B2, B5.
4. **Publicarlo**: F1, F2, F3, F5, E2.
5. **Pulido y red de seguridad**: el resto.

iOS queda fuera de esta lista: comparte casi todo lo anterior, más su propia cadena de exportación.
