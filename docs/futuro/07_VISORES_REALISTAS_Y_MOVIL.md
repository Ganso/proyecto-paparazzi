# Especificación Futura: Visores Realistas, Ergonomía Móvil y Efectos de Cielo

Este documento detalla la simulación estética fotorrealista de carcasas de visor óptico, el diseño ergonómico de controles táctiles en smartphones y las mejoras visuales en el sol y las nubes.

---

## 1. Simulación Realista de Carcasas de Visor Óptico

Actualmente, [scripts/viewfinder.gd](file:///home/ganso/codigo/afotando/scripts/viewfinder.gd) dibuja líneas vectoriales limpias. La propuesta futura consiste en simular **la experiencia física de apoyar el ojo contra el ocular de una cámara real**.

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
   - Progresión suave de la temperatura de color de la luz solar (de luz blanca diurna de mediodía $5500\text{ K}$ a luz cálida rasante de atardecer $3200\text{ K}$ con sombras alargadas).
