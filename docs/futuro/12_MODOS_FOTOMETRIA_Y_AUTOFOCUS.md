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

### 2.1 ✅ Corregido (30-09-2026): los automatismos ya no conocen al objetivo

> Hecho en `main.gd::select_matrix_point()` (la persona más cercana al centro del encuadre, y en empate la más próxima a la cámara), `update_meter()` y `auto_expose()` (miden lo que hay bajo el punto de enfoque activo). Lo comprueba `tests/test_automatisms.gd`. Se conserva abajo la descripción del problema original.
- **AF matricial**: `main.gd::select_matrix_point()` recorre los 9 puntos de enfoque y, si alguno toca al objetivo (`p == target`), lo elige antes que a cualquier otra persona. Basta con barrer el parque en AF matricial para ver en qué persona «salta» el punto de enfoque, lo que **delata al sujeto buscado** y anula parte del reto de identificación.
- **Exposición automática**: `update_meter()` y `auto_expose()` sustituyen la lectura del punto de enfoque por la luz sobre el pecho del objetivo en cuanto aparece en el encuadre.
- **Corrección (fase 0 de este documento)**: el AF matricial elige con una regla geométrica independiente de la identidad (la persona más cercana al centro del encuadre y, en caso de empate, la más próxima a la cámara), y la exposición automática mide el punto de enfoque activo o las zonas del §3. Ningún automatismo lee `target`.

## 3. Especificación de Modos de Exposición Automática (Metering)

Se proyecta una arquitectura de fotometría TTL (*Through-The-Lens*) con tres modos clásicos seleccionables según el cuerpo y la preferencia del jugador:

| Modo de Medición | Área de Cobertura | Algoritmo de Cálculo | Caso de Uso Óptimo | Cuerpos Disponibles |
|---|---|---|---|---|
| **Matricial / Evaluativa (Multi-zona)** | 100% del encuadre dividido en $3 \times 3$ o $5 \times 5$ celdas | Histograma zonal ponderado con mayor peso en la zona que contiene al sujeto o punto de enfoque activo. | Escenas generales con iluminación equilibrada; fotografía de calle espontánea. | Compacta digital, Réflex moderna |
| **Puntual (Spot Metering)** | $2.5\% - 3.5\%$ del encuadre, centrado en el punto de enfoque activo | Lectura física estricta en el microcono de visión del punto de enfoque `finder.active`. | Fuertes contraluces, sujetos en penumbra o bajo focos directos de farolas nocturnas. | Compacta digital, Réflex moderna |
| **Ponderada al Centro (Center-Weighted)** | 75% elipse central (radio 12 mm en sensor), 25% periferia | Media ponderada gaussiana decreciente desde el centro óptico. | Fotografía clásica analógica; comportamiento predecible y consistente. | Réflex analógica, Telemétrica |

### 3.1 Modelo Matemático de Medición Matricial (Zonas)
La escena proyectada en el frustum de la cámara se subdivide en $M \times N$ zonas (ej. $5 \times 5 = 25$ zonas). Cada zona $k$ evalúa su luminancia equivalente $EV_k$:

$$EV_{matricial} = \sum_{k=1}^{K} w_k \cdot EV_k$$

Donde los pesos $w_k$ se normalizan ($\sum w_k = 1$) y se modulan dinámicamente:
- **Prioridad de persona**: la zona que contiene a la persona bajo el punto de enfoque activo recibe un multiplicador $w_k \times 2.5$. Es cualquier persona detectada por los rayos, sin saber si es el objetivo del encargo (ver §2.1).
- **Compensación de Cielo**: Si las zonas superiores exhiben $EV_k > EV_{medio} + 3.0$ (cielo brillante), su peso se atenúa para evitar que la cámara subexponga a los peatones en el suelo.

### 3.2 Medición Puntual Ligada al Punto de enfoque
La medición puntual muestrea exclusivamente la luminancia en el punto 3D interceptado por el punto de enfoque activo:
$$target\_ev = park.illumination\_ev(hit.position, night, hit.collider) - equipment.exposure\_compensation()$$
Esto permite al jugador apuntar al rostro o prenda clave del sujeto, ajustar la compensación a $+0.7\text{ EV}$ si se trata de un tono claro, y obtener la exposición exacta con independencia de si el fondo es negro azabache o blanco cegador.

---

## 4. Especificación de Modos de Autofoco (AF Systems)

El sistema de autofoco se diversifica en cuatro modos especializados que complementan el modo manual con telémetro de coincidencia (MF):

### 4.1 AF-S (Single Shot / Autofoco Simple con Bloqueo)
- **Mecánica**: Al presionar a medio recorrido el disparador o pulsar la tecla `F`, el motor óptico busca el plano de foco sobre la superficie apuntada por el punto de enfoque activo.
- **Focus Lock (Bloqueo de Enfoque)**: Una vez alcanzada la confirmación (halo verde en visor), el plano de enfoque queda **bloqueado** mientras no se suelte el pulsador.
- **Recomposición (Focus and Recompose)**: Permite centrar el punto de enfoque en el sujeto, fijar foco a $4.20\text{ m}$, y luego reencuadrar la cámara aplicando la regla de los tercios sin que la lente modifique su distancia.

### 4.2 AF-C (Continuous / Autofoco Continuo Predictivo)

> [!NOTE]
> **Valor limitado en el parque actual**: con el jugador en el centro de carriles circulares, la distancia a un viandante apenas cambia (solo por su desvío lateral dentro de `LANE_BOUNDS` o en los cambios de carril). La predicción solo aporta algo con corredores que cambian de carril o en escenarios lineales ([04](04_DIVERSIDAD_ESCENARIOS.md)). Aquí la dificultad real es *a quién* enfocar, no seguirlo.
- **Mecánica**: El autofoco permanece activo cuadro a cuadro a 60 FPS mientras el disparador esté a medio recorrido o el modo esté activo.
- **Algoritmo Predictivo Cinemático**: Para viandantes en movimiento (especialmente corredores deportivos a $v \in [2.6, 3.0]\text{ m/s}$), enfocar a la distancia actual produce desenfoque por culpa del retardo mecánico del obturador ($\Delta t_{lag} \approx 0.040\text{ s}$).
- **Ecuación Predictiva**:
  $$\vec{p}_{predicha} = \vec{p}_{sujeto}(t) + \vec{v}_{sujeto} \cdot \Delta t_{lag}$$
  $$s_{target} = \| \vec{p}_{predicha} - \vec{p}_{camara} \|$$
  La lente se desplaza proactivamente hacia $s_{target}$, garantizando que en el instante exacto de apertura del obturador el círculo de confusión $CoC$ se mantenga dentro del límite de nitidez ($CoC \le 0.030\text{ mm}$).

### 4.3 AF-A (Automatic / Autofoco Híbrido Inteligente)
- Monitorea la velocidad del sujeto bajo el punto de enfoque.
- Si el sujeto permanece quieto o en pausa de banco, opera en **AF-S** permitiendo recomponer el encuadre.
- Si el sujeto inicia la marcha o carrera ($\|\vec{v}\| > 0.3\text{ m/s}$), el sistema conmuta instantáneamente a **AF-C** emitiendo un doble bip de confirmación en el HUD.

### 4.4 ❌ Descartado: Detección y Seguimiento Inteligente de Sujetos (AI Subject / Eye Tracking)

> [!CAUTION]
> **Descartado.** Buscar «el personaje que mejor coincide con los rasgos del briefing» resolvería por el jugador el reto central del juego: identificar al objetivo. Se conserva el texto como antecedente. Un seguimiento aceptable solo podría engancharse a la persona que el jugador ya ha elegido con el punto de enfoque.

- Exclusivo de cuerpos compactos digitales modernos y cámaras de gama alta.
- Evalúa el frustum visible en busca del personaje que mejor coincide con los rasgos del briefing (o el más próximo al centro del visor).
- El punto de enfoque activo se desprende de la cuadrícula rígida de 9 puntos y **persigue de forma autónoma** la cabeza del sujeto a través del visor 2D, proyectando un marco delimitador dinámico.

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
> [!NOTE]
> Estas entradas se declaran como acciones en el mapa único de `InputMap` ([14 §2](14_SOPORTE_GAMEPAD.md)): `fotometria_siguiente`, `modo_af_siguiente` y `bloqueo_af_ae`. En mando y en móvil, el bloqueo AF-L/AE-L es la fase 1 del disparador de dos fases ([14 §3](14_SOPORTE_GAMEPAD.md), [13 §4.1](13_INTERFAZ_MOVIL_UTILIZABLE.md)).

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

---

## 7. Orden de Implementación y Criterios de Aceptación

1. **Fase 0** ✅ (30-09-2026): AF matricial y AE sin conocer al objetivo (§2.1).
2. **Fase 1** ✅ (02-10-2026): los tres modos de fotometría y el bloqueo AF-L/AE-L.
   - **Fotometría** (`equipment.metering`, `main.gd::update_meter()`): `puntual` (lo de siempre: lo que hay bajo el punto de enfoque activo, y sigue siendo el modo por defecto para no cambiar ningún nivel), `ponderada` (75 % para el centro del encuadre —el centro y un anillo— y 25 % para la periferia) y `matricial` (5 × 5 zonas; la del punto activo pesa 2,5 veces y las que superan en 3 EV a la media —el cielo— pesan un cuarto). Todas leen `park.illumination_ev()` de lo que el rayo encuentra o `sky_ev()` si no hay nada: ninguna sabe quién es el objetivo. Se cambia con la tecla de fotometría (`{fotometria}`, `next_metering()`); la ayuda en pantalla muestra el modo.
   - **Bloqueo AF-L/AE-L** (`toggle_lock()`, control `{bloqueo}`): enfoca y mide sobre el punto activo y conserva foco y exposición mientras se reencuadra; lo suelta la siguiente foto o la misma tecla. Con la tecla es un conmutador; en el mando es la **media pulsación del gatillo**, que lo mantiene mientras siga a medias ([14 §3](14_SOPORTE_GAMEPAD.md)).
   - Diferencias con el §3: los modos no dependen del cuerpo (los tres están en todas las cámaras) y no hay selector en el menú de equipo.
   - Pruebas: `tests/test_automatisms.gd` (49 comprobaciones): la puntual lee exactamente `illumination_ev()` del punto activo; ponderada y matricial son deterministas, no dependen del objetivo y la matricial queda dentro del rango de sus zonas y no se va con el cielo; el bloqueo aguanta el reencuadre, la foto sale con el foco y la exposición bloqueados y después se suelta.
3. **Fase 2** ✅ (02-10-2026): AF-C y AF-A.
   - **AF automático** (`"AF automático"`, `subject_moving()`): si la persona bajo el punto activo se mueve a más de 0,3 m/s (`AF_A_SPEED`), sigue como el AF continuo y lo avisa con un doble pitido; con alguien quieto o con el decorado se comporta como AF simple (enfoca cuando se le pide).
   - **AF continuo** (`"AF continuo"` en `equipment.focus_modes()` de la compacta y la réflex; `main.gd::update_continuous_af()`): mientras el modo está puesto, el objetivo sigue en silencio lo que hay bajo el punto activo, unas ocho veces por segundo (`AF_C_INTERVAL`), acercándose en cada paso (la lente tarda un instante en llegar). Si es una persona en movimiento, enfoca donde estará al abrirse el obturador: `posición + velocidad × 0,04 s` (`SHUTTER_LAG`, la ecuación del §4.2). Al disparar toma esa distancia predicha de golpe, sin el pitido del AF simple. El bloqueo AF-L lo detiene. Se elige en el menú de equipo, como los demás modos; el visor dibuja solo el punto activo.
   - Pruebas en `tests/test_automatisms.gd` (60 comprobaciones): lleva el foco a la persona bajo el punto, la sigue al girar hacia alguien más cercano, el bloqueo lo para, el AF simple no reenfoca solo, y el AF automático sigue a quien anda y deja el foco quieto con quien está parado.

**Criterios de aceptación** (ampliar `test_equipment.gd`):
1. Con el objetivo y otra persona a la misma distancia y en puntos de enfoque simétricos, el AF matricial elige según la regla geométrica, nunca por identidad. Intercambiar quién es el objetivo no cambia el punto de enfoque elegido.
2. Con el objetivo en sombra y el fondo al sol, la exposición automática depende solo del modo de medición y del punto de enfoque, no de `target`.
3. La medición puntual lee exactamente `park.illumination_ev()` en el punto del punto de enfoque activo, y la matricial es la media ponderada del §3.1, ambas deterministas.
4. El bloqueo AF-L/AE-L mantiene foco y exposición mientras dura la fase 1 del disparador.
