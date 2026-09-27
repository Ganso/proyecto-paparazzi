# 12. Modos de Fotometría Avanzada (Exposición Automática) y Sistemas de Autofoco (AF)

Este documento define la especificación técnica, arquitectura matemática e integración jugable para la **diversificación de modos de fotometría automática** y los **sistemas avanzados de enfoque automático (AF)** en Proyecto Paparazzi, construyendo sobre el control interactivo de **compensación de exposición ($\pm\text{EV}$)** ya implementado en el prototipo.

---

## 1. Visión y Motivación Fotográfica

En la fotografía profesional y analógica, la exposición y el enfoque no son operaciones mecánicas de valor único, sino decisiones deliberadas tomadas por el fotógrafo según las condiciones de la escena:

1. **Exposición Automática y Fotometría TTL**:
   - Una escena con un viandante en sombra bajo una arboleda espesa frente a un cielo resplandeciente engaña a los fotómetros promedio, arrojando sujetos completamente oscuros (subexpuestos).
   - Un sujeto que viste prendas oscuras sobre un fondo claro genera sobreexposiciones severas si la cámara asume que toda la imagen debe promediarse a un gris neutro del 18%.
   - La combinación de **modos de medición** (matricial, puntual y ponderada al centro) junto a un dial accesible de **compensación de exposición ($\pm 2.0\text{ EV}$)** dota al jugador de las mismas herramientas correctivas que poseen las cámaras réflex y telemétricas reales.

2. **Sistemas de Autofoco (AF)**:
   - Los caminantes lentos ($v \in [0.55, 0.85]\text{ m/s}$) permiten un enfoque estático previo y recomposición del encuadre.
   - Los corredores rápidos ($v \in [2.6, 3.0]\text{ m/s}$) requieren seguimiento continuo predictivo que anticipe el desplazamiento del sujeto durante el retardo del obturador (*shutter lag*).

---

## 2. Estado Actual Implementado en el Prototipo

El prototipo actual cuenta con los siguientes cimientos operativos y verificados:

- **Compensación de Exposición Directa ($\pm\text{EV}$)**:
  - Selector interactivo integrado en el HUD superior (`exposure_button`), con rango $\pm 2.0\text{ EV}$ en pasos de $1/3$ de paso: `[-2.0, -1.7, -1.3, -1.0, -0.7, -0.3, 0.0, +0.3, +0.7, +1.0, +1.3, +1.7, +2.0]`.
  - Controles multientrada: clic izquierdo (subir) / clic derecho (bajar), rueda del ratón (`WHEEL_UP` / `WHEEL_DOWN`), arrastre continuo horizontal y atajos de teclado (`[` / `]` y `-` / `+`).
  - Acoplamiento con el resolvedor simplex de exposición `auto_expose()`: resta la compensación de `target_ev`, haciendo que la cámara elija conscientemente combinaciones más luminosas (apertura mayor / obturador más lento / ISO más alto) o más oscuras.
  - Indicador de aguja en el visor (`finder.delta_ev` en `scripts/viewfinder.gd`) que señala con precisión milimétrica la desviación respecto al fotómetro central.
  - Simulación física en el revelado químico (`shaders/develop.gdshader`): amplificación o atenuación lumínica exponencial `exp2(-exposure)`.

---

## 3. Especificación de Modos de Exposición Automática (Metering)

Se proyecta una arquitectura de fotometría TTL (*Through-The-Lens*) con tres modos clásicos seleccionables según el cuerpo y la preferencia del jugador:

| Modo de Medición | Área de Cobertura | Algoritmo de Cálculo | Caso de Uso Óptimo | Cuerpos Disponibles |
|---|---|---|---|---|
| **Matricial / Evaluativa (Multi-zona)** | 100% del encuadre dividido en $3 \times 3$ o $5 \times 5$ celdas | Histograma zonal ponderado con mayor peso en la zona que contiene al sujeto o colimador activo. | Escenas generales con iluminación equilibrada; fotografía de calle espontánea. | Compacta digital, Réflex moderna |
| **Puntual (Spot Metering)** | $2.5\% - 3.5\%$ del encuadre, centrado en el colimador activo | Lectura física estricta en el microcono de visión del colimador `finder.active`. | Fuertes contraluces, sujetos en penumbra o bajo focos directos de farolas nocturnas. | Compacta digital, Réflex moderna |
| **Ponderada al Centro (Center-Weighted)** | 75% elipse central (radio 12 mm en sensor), 25% periferia | Media ponderada gaussiana decreciente desde el centro óptico. | Fotografía clásica analógica; comportamiento predecible y consistente. | Réflex analógica, Telemétrica |

### 3.1 Modelo Matemático de Medición Matricial (Zonas)
La escena proyectada en el frustum de la cámara se subdivide en $M \times N$ zonas (ej. $5 \times 5 = 25$ zonas). Cada zona $k$ evalúa su luminancia equivalente $EV_k$:

$$EV_{matricial} = \sum_{k=1}^{K} w_k \cdot EV_k$$

Donde los pesos $w_k$ se normalizan ($\sum w_k = 1$) y se modulan dinámicamente:
- **Prioridad de Sujeto**: La zona que contiene el pecho/cabeza del objetivo recibe un multiplicador $w_k \times 2.5$.
- **Compensación de Cielo**: Si las zonas superiores exhiben $EV_k > EV_{medio} + 3.0$ (cielo brillante), su peso se atenúa para evitar que la cámara subexponga a los peatones en el suelo.

### 3.2 Medición Puntual Ligada al Colimador
La medición puntual muestrea exclusivamente la luminancia en el punto 3D interceptado por el colimador activo:
$$target\_ev = park.illumination\_ev(hit.position, night, hit.collider) - equipment.exposure\_compensation()$$
Esto permite al jugador apuntar al rostro o prenda clave del sujeto, ajustar la compensación a $+0.7\text{ EV}$ si se trata de un tono claro, y obtener la exposición exacta con independencia de si el fondo es negro azabache o blanco cegador.

---

## 4. Especificación de Modos de Autofoco (AF Systems)

El sistema de autofoco se diversifica en cuatro modos especializados que complementan el modo manual con telémetro de coincidencia (MF):

### 4.1 AF-S (Single Shot / Autofoco Simple con Bloqueo)
- **Mecánica**: Al presionar a medio recorrido el disparador o pulsar la tecla `F`, el motor óptico busca el plano de foco sobre la superficie apuntada por el colimador activo.
- **Focus Lock (Bloqueo de Enfoque)**: Una vez alcanzada la confirmación (halo verde en visor), el plano de enfoque queda **bloqueado** mientras no se suelte el pulsador.
- **Recomposición (Focus and Recompose)**: Permite centrar el colimador en el sujeto, fijar foco a $4.20\text{ m}$, y luego reencuadrar la cámara aplicando la regla de los tercios sin que la lente modifique su distancia.

### 4.2 AF-C (Continuous / Autofoco Continuo Predictivo)
- **Mecánica**: El autofoco permanece activo cuadro a cuadro a 60 FPS mientras el disparador esté a medio recorrido o el modo esté activo.
- **Algoritmo Predictivo Cinemático**: Para viandantes en movimiento (especialmente corredores deportivos a $v \in [2.6, 3.0]\text{ m/s}$), enfocar a la distancia actual produce desenfoque por culpa del retardo mecánico del obturador ($\Delta t_{lag} \approx 0.040\text{ s}$).
- **Ecuación Predictiva**:
  $$\vec{p}_{predicha} = \vec{p}_{sujeto}(t) + \vec{v}_{sujeto} \cdot \Delta t_{lag}$$
  $$s_{target} = \| \vec{p}_{predicha} - \vec{p}_{camara} \|$$
  La lente se desplaza proactivamente hacia $s_{target}$, garantizando que en el instante exacto de apertura del obturador el círculo de confusión $CoC$ se mantenga dentro del límite de nitidez ($CoC \le 0.030\text{ mm}$).

### 4.3 AF-A (Automatic / Autofoco Híbrido Inteligente)
- Monitorea la velocidad del sujeto bajo el colimador.
- Si el sujeto permanece quieto o en pausa de banco, opera en **AF-S** permitiendo recomponer el encuadre.
- Si el sujeto inicia la marcha o carrera ($\|\vec{v}\| > 0.3\text{ m/s}$), el sistema conmuta instantáneamente a **AF-C** emitiendo un doble bip de confirmación en el HUD.

### 4.4 Detección y Seguimiento Inteligente de Sujetos (AI Subject / Eye Tracking)
- Exclusivo de cuerpos compactos digitales modernos y cámaras de gama alta.
- Evalúa el frustum visible en busca del personaje que mejor coincide con los rasgos del briefing (o el más próximo al centro del visor).
- El colimador activo se desprende de la cuadrícula rígida de 9 puntos y **persigue de forma autónoma** la cabeza del sujeto a través del visor 2D, proyectando un marco delimitador dinámico.

---

## 5. Integración en UI y Esquema de Controles

```
+----------------------------------------------------------------------------------------------------+
|  AFOTANDO PAPARAZZI   [ 1/250s ]   [ f/4.0 ]   [ ISO 400 ]   [ Equipo: Réflex ]   [ AUTO +0.7 EV ] |
|                                                                                                    |
|                                       ( Visor Réflex / LCD )                                       |
|                                                                                                    |
|                                    -2   -1    0   +1   +2                                          |
|                                   [·····|·····▲·····|·····]                                         |
|                                         (Aguja +0.7 EV)                                            |
|                                                                                                    |
|                                    [AF-C · PUNTUAL · 3.8m]                                         |
|                                                                                                    |
|  [ZOOM 70 mm]   [FOCO 3.80 m]   [NÍTIDO 3.52 - 4.14 m]   [Modo AF: AF-C]   [Fotometría: Puntual]   |
+----------------------------------------------------------------------------------------------------+
```

### Controles Previstos:
- **Compensación de Exposición**: Botón superior, rueda de ratón sobre el botón o teclas `[` / `]` y `-` / `+`.
- **Selector de Fotometría**: Menú de equipo o tecla de acceso rápido `M` (alterna entre Matricial $\to$ Puntual $\to$ Ponderada).
- **Selector de Modo AF**: Menú de equipo o combinación `Shift + F` (alterna entre AF-S $\to$ AF-C $\to$ AF-A $\to$ MF).
- **Bloqueo AF-L / AE-L**: Pulsación mantenida del botón central del ratón o tecla `L` para congelar tanto la exposición medida como el plano de foco.

---

## 6. Presupuestos de Rendimiento y Memoria

1. **CPU / Rendimiento por Fotograma**:
   - Medición puntual: Coste $0.01\text{ ms}$ (un único rayo de colisión ya calculado en el pipeline).
   - Medición matricial: Muestreo de 9 puntos espaciales distribuidos en el frustum; coste inferior a $0.08\text{ ms}$.
   - Seguimiento predictivo AF-C: Operaciones vectoriales simples en `person.actual_velocity`, coste despreciable ($< 0.005\text{ ms}$).
2. **Consumo de Memoria VRAM**:
   - $0\text{ bytes}$ adicionales de VRAM; no requiere búferes de renderizado independientes.
   - Respeta estrictamente el límite de **$60\text{ MiB}$** de memoria de vídeo global.
3. **Determinismo**:
   - Las ecuaciones de CoC y EV en `photography.gd` se mantienen matemáticamente puras y deterministas.
