# Especificación: Visores Realistas, Ergonomía Móvil y Efectos de Cielo

> [!NOTE]
> **Estado (01-10-2026): §1 ✅ implementado** (visores realistas por cuerpo e interfaz de cámara), ver §5. El §2 queda sustituido por [13](13_INTERFAZ_MOVIL_UTILIZABLE.md) y el §3 (sol, sombras de nubes, atardecer continuo) sigue pendiente.

Este documento detalla la simulación estética fotorrealista de carcasas de visor óptico, el diseño ergonómico de controles táctiles en smartphones y las mejoras visuales en el sol y las nubes.

---

## 1. Simulación Realista de Carcasas de Visor Óptico

Actualmente, [scripts/viewfinder.gd](../../scripts/viewfinder.gd) dibuja líneas vectoriales limpias. La propuesta futura consiste en simular **la experiencia física de apoyar el ojo contra el ocular de una cámara real**.

```
+-------------------------------------------------------------------------------+
| [BORDE DE GOMA DEL OCULAR CON VIÑETEO ÓPTICO Y LIGERA ABERRACIÓN CROMÁTICA]   |
|                                                                               |
|       +---------------------------------------------------------------+       |
|       |                                                               |       |
|       |   [Textura sutil de cristal esmerilado y micro-motas de polvo]|       |
|       |                                                               |       |
|       |         +-----+         +-----+         +-----+               |       |
|       |         | [ ] |         | [ ] |         | [ ] |               |       |
|       |         +-----+         +-----+         +-----+               |       |
|       |                                                               |       |
|       |                       ( ( / ) )                               |       |
|       |                                                               |       |
|       |         +-----+         +-----+         +-----+               |       |
|       |         | [ ] |         | [ ] |         | [ ] |               |       |
|       |         +-----+         +-----+         +-----+               |       |
|       |                                                               |       |
|       +---------------------------------------------------------------+       |
|                                                                               |
| [PANTALLA LCD INFERIOR ILUMINADA EN VERDE/ROJO RETRO DE 7 SEGMENTOS]          |
|  [ 1/250 ]    [ F 2.8 ]    [ o + - ]    [ ISO 400 ]    [ [36] DISPAROS ]      |
+-------------------------------------------------------------------------------+
```

### Características de Inmersión Visual
1. **Ocular de Goma y Viñeteo Óptico**:
   - Marco de goma redondeado en los bordes de la pantalla con una atenuación sutil en las esquinas que emula la distancia del ojo al ocular (*eye relief*).
2. **Cristal Esmerilado Auténtico**:
   - Micro-textura muy sutil en la pantalla de enfoque con pequeñas motas microscópicas de polvo estáticas, habituales en cualquier visor réflex de los años 80-90.
3. **Barra de Datos LCD/LED Retro Iluminada**:
   - En lugar de etiquetas gráficas genéricas de interfaz, los datos de exposición se proyectan en una franja negra inferior mediante dígitos de 7 segmentos de cristal líquido o LEDs rojos analógicos (estilo Nikon FM2 / Canon AE-1 / Pentax K1000).
4. **Marcas de Corrección de Paralaje (Telemétricas y Compactas)**:
   - Dado que el visor de una telemétrica no mira a través de la lente, a distancias cortas ($s < 2.0\text{ m}$) se muestran marcos auxiliares desplazados hacia abajo y a la derecha para advertir del recorte de paralaje real.

---

## 2. Ergonomía Táctil Especializada para Móviles

> [!NOTE]
> **Sustituida por [13_INTERFAZ_MOVIL_UTILIZABLE.md](13_INTERFAZ_MOVIL_UTILIZABLE.md)**, que desarrolla esta sección con medidas, gestos y pruebas. Se conserva como antecedente.

Para garantizar una experiencia fluida con dos pulgares en pantallas táctiles de 5 a 7 pulgadas:

```
+-------------------------------------------------------------------------------+
| [PULGAR IZQUIERDO]                                         [PULGAR DERECHO]   |
|                                                                               |
|   ( Rueda semicircular                                         [ DISPARADOR ] |
|     de enfoque métrico                                        Botón de 2 fases|
|     0.8m ... 15m ... inf )                                     (Presión media)|
|                                                                               |
|   [ AF / MF ]                                                 [ Rueda Apertura|
|   Selector rápido                                               f/1.8 .. f/16]|
+-------------------------------------------------------------------------------+
```

### Mecánica de Disparador en Dos Fases (*Half-Press*)
- **Pulsación mantenida suave (Fase 1)**: Bloquea el autofoco sobre el sujeto y fija la medición del exposímetro (emulando presionar el disparador hasta la mitad).
- **Levantar o pulsar a fondo (Fase 2)**: Disparo instantáneo con retroalimentación háptica (vibración corta del motor del teléfono).

---

## 3. Mejoras Visuales de Cielo, Sol y Nubes

Para hacer aún más legible y comprensible el paso de las nubes y el oscurecimiento de la escena:

1. **Disco Solar Procedural en el Cielo**:
   - Representación visual del sol con corona de destello anamórfico (*lens flare*) que varía en intensidad según la apertura seleccionada (más estrellado a $f/16$, más suave y circular a $f/2.8$).
2. **Sombras de Nubes Proyectadas en el Suelo**:
   - Proyección de sombras oscuras sobre el césped y las calzadas que se desplazan visualmente en la dirección del viento.
   - Permite al jugador anticipar visualmente cuándo la sombra de una nube va a cubrir al sujeto que está siguiendo.
3. **Hora Dorada y Atardecer Dinámico**:
   - ✅ *Parcialmente hecho*: ya existe una hora dorada fija (`park.set_time_of_day("golden")`, [ESCENARIO §3.1](../ESCENARIO_Y_RENDIMIENTO.md)). Falta la progresión continua descrita aquí.
   - Progresión suave de la temperatura de color de la luz solar (de luz blanca diurna de mediodía $5500\text{ K}$ a luz cálida rasante de atardecer $3200\text{ K}$ con sombras alargadas).

---

## 4. Criterios de Aceptación

1. **Las capas del visor no afectan a la puntuación**: ocular, cristal esmerilado y LCD se dibujan en la interfaz, fuera del `SubViewport` que captura `take_photo()`. Una misma escena da la misma nota con y sin esos efectos (`test_photography.gd`/`test_game.gd`).
2. El disco solar y el destello varían con la apertura de forma determinista y no cambian `park.illumination_ev()`.
3. Las sombras de nubes proyectadas coinciden con `sun_transmission()`: un punto bajo sombra de nube mide la misma reducción de EV que ya documenta [ESCENARIO §3.2](../ESCENARIO_Y_RENDIMIENTO.md).
4. VRAM dentro del presupuesto del perfil ([02 §10](02_ESTILO_VISUAL_Y_POLIGONOS.md)) y capturas añadidas a `./tools/run_evidence.sh`.

---

## 5. Implementación del §1 (01-10-2026)

Decisiones del usuario: **interfaz de la cámara** (los datos van dentro del visor y los controles se pliegan), información adicional permitida en la Academia y **el visor nunca enseña menos que la foto** (nada de cobertura del 95 % ni de recortes). Lo demás, a criterio del desarrollo: un visor genérico por cuerpo, sin marcas, de su época.

### 5.1 Piezas

| Pieza | Qué hace |
|---|---|
| `scripts/camera_body.gd` | Lo que rodea la imagen y los datos de cada visor, dibujado en la interfaz (fuera de la captura). Máscaras generadas por código (goma del ocular, cristal, plástico), dígitos de 7 segmentos dibujados por código, apagón del espejo al disparar y línea del encargo fuera de la imagen. |
| `scripts/main.gd` | `view_rect` (dónde se ve la imagen: pantalla completa en la interfaz clásica, enmarcada por el cuerpo en la de cámara; siempre 16:9, así que la foto nunca se recorta), `place_view()`, `image_position()` (clics y puntos de enfoque siguen a la imagen, deshaciendo el paralaje), interfaz `camara`/`clasica` (`set_interface()`, `user://interfaz.cfg`, opción en Equipo, `--interface=`), barras plegables (`update_hud_visibility()`: Tab, borde de la pantalla, Academia y pantallas modales las muestran) y sonido de disparo por cuerpo. |
| `scripts/viewfinder.gd` | Puntos de enfoque, tercios y ayuda de enfoque dentro de `view`; el exposímetro y la batería del HUD clásico solo en la interfaz clásica. |
| `shaders/viewfinder_lens.gdshader` | Además del carácter del objetivo: grano fijo de pantalla esmerilada, centro Fresnel y motas de polvo (réflex), cristal limpio y desplazado por el paralaje (telemétrica), rejilla de píxeles, contraste de pantalla pequeña y ruido con poca luz (compacta). Corre también en Bajo, sin viñeteo ni aberración. |
| `tools/audio/build_camera_sounds.py` | `assets/audio/camara/`: espejo y cortinilla de la réflex, cortinilla de tela de la telemétrica, beep y falso obturador de la compacta. |

### 5.2 Los tres visores

| Cuerpo | Visor | Datos dentro |
|---|---|---|
| Réflex (años 80) | Ocular de goma redondeado, pantalla esmerilada con anillo de microprismas alrededor de la imagen partida, polvo y apagón del espejo al disparar (proporcional a la velocidad) | Tira de LED rojos de 7 segmentos bajo la imagen: velocidad, diafragma, exposímetro + ● − (parpadea si se va más de 2 pasos), A y ± en automático, confirmación de foco y fotos restantes |
| Telemétrica (años 60) | Cristal brillante y **nítido de cerca a lejos** (la profundidad de campo solo aparece en la foto: el pase se activa en el fotograma del disparo), marco de líneas blancas de la focal corregido por **paralaje** (base de unos 3 cm; a 1 m con un 50 mm se desplaza un 4 % a la derecha y un 6 % hacia abajo), mancha amarillenta de doble imagen | Exposímetro de LED ▶ ● ◀ y dígitos de velocidad y diafragma bajo el marco |
| Compacta (años 2000) | Pantalla LCD trasera con píxeles visibles y ruido con poca luz, en un cuerpo de plástico con botones | Modo P/M, AF/MF, fotos restantes, batería, velocidad, diafragma, ISO, escala de exposición, compensación y barra de zoom W–T |

### 5.3 Fuera de alcance y decisiones

- La telemétrica conserva la imagen a la focal del objetivo (no simula un visor de aumento fijo con marcos dentro de un campo mayor): mostrar más o menos que la foto quedó descartado.
- No hay botón de previsualización de profundidad de campo: el visor de la réflex ya enseña la profundidad de campo del diafragma elegido, que es lo que el jugador necesita.
- Android sigue con la interfaz clásica hasta [13](13_INTERFAZ_MOVIL_UTILIZABLE.md).
- De paso se corrigió un fallo antiguo: el pase de profundidad de campo es también el que sanea los píxeles no finitos antes del brillo; ahora corre siempre en Forward+ (solo el desenfoque depende del perfil y del cuerpo), y desaparecieron las manchas blancas que salían a veces sin él.

### 5.4 Pruebas y evidencias

- `tests/test_finders.gd`: por cuerpo, la imagen cabe y es 16:9, el centro del visor es el centro de la foto, los puntos de enfoque están dentro, las barras se pliegan y Tab las muestra; el paralaje crece de cerca y casi desaparece de lejos; el visor de la telemétrica no desenfoca pero la foto sí; **la misma escena da la misma nota con la interfaz clásica y con la de cámara**; un disparo real por cuerpo; los sonidos existen; la interfaz clásica es la de siempre.
- Capturas `13_visor_reflex` a `16_visor_telemetrica_noche` en `docs/evidencias/ultra/` (`tools/capture_ultra.sh`).

