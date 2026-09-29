# Especificación Futura: Interfaz Móvil Utilizable

Este documento especifica la adaptación del HUD y de los controles a pantallas táctiles de 5–7 pulgadas. Nace de la revisión del banco contra el código del 29-09-2026 y sustituye a [07 §2](07_VISORES_REALISTAS_Y_MOVIL.md) y a la fase 3 de [09](09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md), que describían lo mismo sin cifras ni pruebas.

> [!IMPORTANT]
> **Principio rector**: la puntuación de `photography.gd` es idéntica en todas las plataformas (determinismo, AGENTS.md §3.5). Lo que cambia en móvil es **cómo** se llega a un valor de foco, zoom o exposición, nunca la tolerancia con que se evalúa.

---

## 1. Diagnóstico Medido

Referencia: móvil de 6,1" y 19,5:9 en horizontal (140,6 × 64,9 mm). El juego ocupa un rectángulo 16:9 de 115,4 × 64,9 mm (`stretch/aspect` por defecto `keep`), así que **1 px virtual ≈ 0,09 mm**. El mínimo táctil de Android (48 dp) equivale a unos **7,6 mm ≈ 84 px**.

### 1.1 Tamaño de los controles (`main.gd::build_ui()`)
| Control | Tamaño virtual | Alto físico | ¿Alcanza 7,6 mm? |
|---|---|---:|:---:|
| `Sandbox · escena`, `Gráficos · …` | 200×26, 130×26 | 2,3 mm | ❌ |
| Deslizadores de zoom y foco (zona de agarre) | 215×24 | 2,2 mm | ❌ |
| `Equipo` | 135×38 | 3,4 mm | ❌ |
| Tiempo, diafragma, ISO, compensación | ~115×50 | 4,5 mm | ❌ |
| `ENFOCAR` | 128×50 | 4,5 mm | ❌ |
| `DISPARAR` | 248×59 | 5,3 mm | ❌ |
| Colimadores AF (separación) | 134×86 | 7,8 mm | ✅ |

Los textos de 11–14 px (subtítulo, contador, estado, ayudas) miden **1,0–1,3 mm** de cuerpo, por debajo de lo legible a distancia de brazo (~2 mm, unos 22 px).

### 1.2 Enfoque manual
El control deslizante de foco (`focus_slider`, 215 px virtuales) es lineal en dioptrías entre 0,8 m e ∞ (1,25 D). Con las fórmulas de `photography.gd`, la ventana de enfoque que da la máxima nota (CoC ≤ 0,030 mm) y la que da una nota mayor que cero (CoC < 0,150 mm) miden, en recorrido de dedo:

| Caso | Ventana para 100 % | Ventana para > 0 % |
|---|---:|---:|
| Compacta 120 mm f/5.6 a 4 m | 3,9 px = **0,35 mm** | 19,5 px = 1,75 mm |
| Réflex 105 mm f/4 a 4 m | 3,6 px = **0,33 mm** | 18,2 px = 1,64 mm |
| Réflex 200 mm f/2.8 a 7 m | 0,7 px = **0,06 mm** | 3,5 px = 0,32 mm |
| Telemétrica 50 mm f/1.4 a 4 m | 5,7 px = **0,51 mm** | 28,5 px = 2,57 mm |
| Telemétrica 90 mm f/2.8 a 7 m | 3,5 px = **0,32 mm** | 17,6 px = 1,59 mm |

Un dedo tiene una superficie de contacto de 7–10 mm y un temblor de ~1 mm, así que con teleobjetivo **no se puede acertar ni para obtener un punto**: el enfoque manual es **inviable**. Rebajar la tolerancia solo en móvil rompería la comparabilidad y el determinismo; la solución debe estar en el control, no en la puntuación (§3).

### 1.3 Gestos y otros problemas
1. **Pellizco con efecto doble**: el mismo `InputEventScreenDrag` de dos dedos cambia el zoom (distancia entre dedos) y el foco (desplazamiento vertical) a la vez. Es imposible hacer zoom sin desenfocar.
2. **Parámetros cíclicos**: un toque en tiempo, diafragma o ISO avanza con `posmod`, así que un toque de más salta de f/22 a f/2.8 o de 1/8 a 1/1000. En táctil no hay clic derecho para retroceder.
3. **Ayudas de teclado en móvil**: `control_hint` muestra «Foto: Espacio · H: ayuda · Rueda: zoom» también en el teléfono.
4. **Bandas desaprovechadas**: el formato 16:9 deja unos 12,6 mm libres a cada lado en un 19,5:9, justo donde descansan los pulgares.
5. **Perfil gráfico**: el juego arranca en `Ultra` en cualquier dispositivo (`park.gd::current_graphics_preset`).
6. **Sin tacto**: el APK declara el permiso `VIBRATE`, pero el código no llama a `Input.vibrate_handheld()`.
7. **Título cortado**: la etiqueta del título (150 px de ancho y cuerpo 20) desborda bajo el botón de tiempo (`Rect2(205,13,…)`), que tapa el final de «Proyecto Paparazzi» (visible en [04_parque_dia.png](../evidencias/estados/04_parque_dia.png)). También ocurre en escritorio.

---

## 2. Disposición a Dos Pulgares

```
+------+-----------------------------------------------------------+------+
| [≡]  |  1/250   f/4.0   ISO 400   [-2 · · 0 · · +2]   AUTO +0.3  | [⚙]  |
|      |                                                           |      |
| ZONA |                                                           | [AF] |
| 1.8  |                    VISOR 16:9 (SubViewport)               |      |
| 4.0  |                                                           |      |
| 7.0  |                     ▢   ▢   ▢                             |  ◉   |
| 11.5 |                     ▢   ▣   ▢                             | DISP |
|  ∞   |                     ▢   ▢   ▢                             | ARAR |
|      |                                                           |      |
| ((·))|  FOCO 4.20 m · nítido 3.9–4.5 m        ZOOM 105 mm  ═══○══ | [👁]  |
+------+-----------------------------------------------------------+------+
 carril                                                            carril
 izquierdo: enfoque                                          derecho: disparo
```

- **Visor fijo en 16:9**: el `SubViewportContainer` pasa de `PRESET_FULL_RECT` a un rectángulo 16:9 centrado. Así se puede activar `display/window/stretch/aspect.mobile="expand"` sin cambiar el campo de visión vertical. Con `stretch = true` y `KEEP_WIDTH`, ensanchar el contenedor reduciría el encuadre vertical y alteraría la nota de encuadre. `image_position()` debe usar el rectángulo del contenedor, no `ui.size`.
- **Carriles laterales**: en las bandas sobrantes (o superpuestos semitransparentes en 16:9 puro). A la izquierda van el enfoque (rueda y zonas); a la derecha, el disparador, el AF y la previsualización DoF (11).
- **Tamaño mínimo**: 84 × 84 px virtuales para todo control interactivo en el perfil móvil y 22 px para el texto. El disparador mide al menos 140 px de diámetro.
- **HUD plegable**: `Sandbox`, `Gráficos` y `Equipo` pasan al menú `≡` durante la búsqueda.
- **Detección**: el perfil se activa con `OS.has_feature("mobile")` o `DisplayServer.is_touchscreen_available()`, y se puede forzar desde ajustes (tablets con teclado, PCs táctiles).

---

## 3. Enfoque Manual Táctil

Tres mecanismos combinables. La elección del jugador se guarda en la evidencia (`focus_assist`) y se muestra en el resultado, para que la nota siga siendo comparable.

### 3.1 Rueda de enfoque relativa con ganancia ligada a la profundidad de campo
En lugar de posición absoluta, el arrastre sobre la rueda desplaza el foco en unidades de **ventana de nitidez actual**:

$$\Delta\left(\tfrac{1}{s}\right) = \frac{W(f, N, s)}{k} \cdot \Delta x_{\text{mm}} \cdot g(v), \qquad W = \frac{1}{s_{\text{cerca}}} - \frac{1}{s_{\text{lejos}}}$$

- $W$ sale de `Photography.dof()`, que ya existe; $k = 8\text{ mm}$ de dedo por ventana.
- $g(v) = 1 + (v/v_0)^2$ es una curva de aceleración: un arrastre lento da precisión y uno rápido recorre la escala. Con $v_0 \approx 60\text{ mm/s}$, un gesto de 4 cm a unos 150 mm/s recorre 36 ventanas: todo el carril 1 con el 200 mm f/2.8, cuyo ancho equivale a 34.
- **Precisión exigida con esta rueda**: ±4 mm de dedo para quedar dentro de la ventana del 100 %, **sea cual sea el objetivo**, frente a los 0,06 mm actuales con el 200 mm.
- Un tic háptico (`Input.vibrate_handheld(8)`) y el sonido existente (`play_tone(1800, …)`) marcan cada ventana recorrida.

### 3.2 Enfoque por zonas (técnica fotográfica real)
Botones de distancia en el carril izquierdo: **1,8 · 4,0 · 7,0 · 11,5 m · ∞** (los radios de `LANES`), más la **hiperfocal** del objetivo y diafragma actuales. Un toque lleva el foco a esa distancia y la rueda de §3.1 hace el ajuste fino.
- Conserva la destreza fotográfica: hay que saber en qué carril está el sujeto y si la profundidad de campo cubre su desvío dentro de `LANE_BOUNDS`.
- Ejemplo: con 50 mm f/8 enfocado a 4 m, la zona nítida cubre de 2,9 a 6,4 m, así que el enfoque por zonas basta para todo el carril 1 (2,9–4,85 m).

### 3.3 Lupa de enfoque
Mientras el dedo toca la rueda, se muestra una ampliación ×3 del colimador activo. Reutiliza `focus_aid.gdshader`, que ya desplaza la imagen partida del telémetro.

### 3.4 Opción de accesibilidad: telémetro táctil
Nivel de asistencia opcional: tocar sobre una persona en MF mide su distancia en ese instante y lleva el foco allí, sin seguimiento posterior. El reto pasa a ser el *momento* del disparo y no la motricidad fina. Aparece marcado en el resultado como «Asistencia: telémetro».

---

## 4. Gestos Rediseñados

| Gesto | Acción | Cambio respecto a hoy |
|---|---|---|
| Arrastre con un dedo sobre el visor | Paneo e inclinación (sensibilidad ∝ 24/f) | Igual |
| Toque corto | Elegir colimador y enfocar (AF) | Igual |
| Pellizco | **Solo zoom** | Se elimina el foco por desplazamiento vertical de dos dedos |
| Pulsación larga en el visor | Bloqueo AF/AE (AF-L) en el colimador tocado | Nuevo |
| Arrastre vertical sobre un parámetro | Subir o bajar **sin dar la vuelta** (con tope) | Nuevo tope; el toque ya no cicla |
| Giroscopio (opcional, desactivado por defecto) | Ajuste fino del encuadre | Nuevo ([09 §1](09_EXPORTACION_AUTOMATIZADA_ANDROID_APK.md)) |

### 4.1 Disparador en dos fases
Hereda la mecánica de 07 §2:
- **Pulsar y mantener**: AF sobre el colimador activo y bloqueo de AE, con tic háptico al confirmar.
- **Soltar**: dispara.
- **Deslizar fuera del botón antes de soltar**: cancela sin gastar disparo (en el juego actual cada disparo cuenta).

Es el mismo modelo que el gatillo analógico del mando ([14 §3](14_SOPORTE_GAMEPAD.md)), así que la lógica se escribe una vez.

---

## 5. Otros Ajustes del Perfil Móvil
- **Perfil gráfico inicial** `Medio` en móvil, en lugar de `Ultra`, respetando el presupuesto de 60 MiB con el atlas de sombras `.mobile` de 1024 que ya declara `project.godot`.
- **Ayudas por dispositivo**: `control_hint` elige su texto según la última entrada (táctil, teclado o mando). Todos los textos van a `data/textos.es.json`; hoy la ayuda de AF está escrita directamente en `refresh()`, contra lo que exige AGENTS.md §3.5.
- **Modo Compacta simplificado**: con exposición automática, los botones de tiempo, diafragma e ISO se sustituyen por una lectura y el control de compensación.

---

## 6. Criterios de Aceptación y Pruebas

Nueva suite `tests/test_mobile_ui.gd`, con display y con el perfil móvil forzado:
1. Todo `Control` interactivo visible en `SEARCH`, `BRIEFING`, `RESULT` e `INTRO` mide ≥ 84 × 84 px virtuales, y todo `Label` visible usa un tamaño ≥ 22 px.
2. Ningún par de controles interactivos se solapa.
3. El `SubViewportContainer` mantiene la proporción 16:9 exacta con ventanas 19,5:9, 20:9 y 4:3, y `camera.fov` no cambia.
4. **Rueda de foco** (función pura, prueba headless): con 200 mm f/2.8 a 7 m, un arrastre lento de 8 mm recorre una ventana $W$ ± 5 %; el resultado es el mismo con la misma secuencia de eventos (determinismo).
5. Un pellizco no modifica `focus_distance`.
6. Un parámetro en su tope no cambia al seguir arrastrando en esa dirección.
7. El disparador en dos fases cancelado no reduce `shots`.

Cuando los carriles laterales estén implementados, se añade la captura móvil a `./tools/run_evidence.sh`.

---

## 7. Fases y Esfuerzo

| Fase | Contenido | Esfuerzo |
|---|---|:---:|
| 1 | Visor fijo 16:9, `aspect.mobile = expand`, tamaños mínimos, HUD plegable, perfil `Medio` en móvil | S-M |
| 2 | Rueda de foco relativa, zonas e hiperfocal, lupa, háptica | M |
| 3 | Gestos rediseñados, disparador de dos fases, parámetros con tope | S-M |
| 4 | Telémetro táctil, giroscopio y captura móvil en evidencias | S |

**Dependencias**: la migración a `InputMap` ([14 §2](14_SOPORTE_GAMEPAD.md)) es recomendable antes de la fase 3, para no duplicar la lógica de disparo.
