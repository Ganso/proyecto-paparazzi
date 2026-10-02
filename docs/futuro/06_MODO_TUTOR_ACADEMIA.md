# Especificación: Modo "Tutor de Fotografía" y Academia Interactiva

Este documento especifica la arquitectura pedagógica y los exámenes interactivos para el modo educativo **Academia de Fotografía**.

> [!NOTE]
> **Estado (01-10-2026): 🟡 implementado salvo los exámenes.** Las cinco lecciones tienen **teoría, demostración guiada y práctica**. El examen aparece en el menú como «todavía no disponible»: sus criterios de aprobado (§2, «Examen práctico»), el informe formativo (§3) y el título de graduado quedan para más adelante, por decisión del usuario. Lo implementado está en el §6. Evidencias en [`docs/evidencias/academia/`](../evidencias/academia/).

---

## 1. Filosofía Pedagógica

La mayoría de los simuladores fotográficos se limitan a mostrar valores numéricos sin enseñar la relación de causa y efecto. El modo **Academia** convierte **Proyecto Paparazzi** en un curso práctico de fotografía analógica y digital donde cada concepto se explica teóricamente y se valida inmediatamente mediante un ejercicio de disparo en tiempo real.

```
+-------------------------------------------------------------------------------+
|                       ESTRUCTURA DE CADA LECCIÓN                             |
+-------------------------------------------------------------------------------+
  1. Teoría Breve (Gráficos interactivos en visor explicando el concepto)
  2. Demostración Guiada (El juego ajusta los controles para ver el efecto)
  3. Ejercicio Práctico (El jugador debe resolver una situación real en el parque)
  4. Evaluación de Concepto (Examen con corrección física explicada)
```

---

## 2. Plan de Estudios (Currículo de 5 Lecciones)

### Lección 1: El Triángulo de Exposición (*Apertura, Velocidad e ISO*)
- **Concepto Teórico**:
  - Cómo el caudal de luz (apertura $N$), la duración de entrada (tiempo $t$) y la sensibilidad del sensor/película ($S$) deben equilibrarse para lograr $EV = 0$.
- **Demostración**:
  - Cambiar de $f/2.8$ a $f/5.6$ (cierra 2 pasos de luz) y observar cómo la aguja del exposímetro cae a $-2\text{ EV}$.
  - Compensar bajando la velocidad de $1/250\text{ s}$ a $1/60\text{ s}$ para volver a centrar la aguja en $0\text{ EV}$.
- **Examen Práctico**:
  - "El cielo se nubla repentinamente perdiendo 3 EV de luz. Ajusta el diafragma y la velocidad para que la aguja del exposímetro vuelva exactamente al centro."

### Lección 2: Profundidad de Campo y Enfoque Selectivo (*El Arte del Bokeh*)
- **Concepto Teórico**:
  - Cómo la apertura y la distancia focal controlan el espesor de la zona nítida según el círculo de confusión ($CoC \le 0.030\text{ mm}$).
- **Demostración**:
  - Enfocar al Carril 1 ($r = 4.0\text{ m}$) a $f/1.8$ con un $105\text{ mm}$ y ver el fondo ($r = 14\text{ m}$) completamente desdibujado en bokeh cremoso frente a $f/16$.
- **Examen Práctico**:
  - "Fotografía a dos personas caminando a diferentes distancias ($r = 4.0\text{ m}$ y $r = 4.7\text{ m}$) logrando que ambas salgan completamente nítidas en la misma toma (requiere cerrar diafragma a $f/8$ o $f/11$)."

### Lección 3: El Tiempo y la Captura del Movimiento (*Congelar vs. Trepidar*)
- **Concepto Teórico**:
  - La velocidad angular de los viandantes y la regla de seguridad contra la trepidación del pulso ($t \le 1/f$).
- **Demostración**:
  - Disparar a un corredor a $1/15\text{ s}$ (sujeto borroso) vs. $1/500\text{ s}$ (sujeto congelado en el aire).
- **Examen Práctico**:
  - "Captura al corredor en pleno salto sin una sola pizca de trepidación ni desenfoque de movimiento en su silueta."

### Lección 4: Composición y la Regla de los Tercios
- **Concepto Teórico**:
  - Puntos de intersección áurea del visor, espacio de aire en la dirección de la mirada (*headroom* y *lead room*).
- **Examen Práctico**:
  - "Encuadra al sujeto de modo que su rostro coincida exactamente con la intersección superior derecha de la cuadrícula mientras camina hacia la izquierda."

### Lección 5: Compresión de Planos y Elección de Óptica
- **Concepto Teórico**:
  - Diferencia entre acercarse físicamente con un $28\text{ mm}$ (perspectiva exagerada) o retroceder y disparar con un $135\text{ mm}$ (fondo comprimido y cercano).
- **Examen Práctico**:
  - "Haz que el árbol del fondo parezca gigantesco y pegado a la espalda del viandante utilizando el teleobjetivo de $135\text{ mm}$."

---

## 3. Sistema de Corrección Explicada Post-Disparo

A diferencia del modo estándar que solo otorga una puntuación numérica, el modo Tutor incluye una **devolución formativa detallada**:

```
[ INFORME DEL TUTOR FOTOGRÁFICO ]
Resultado: APROBADO CON MENCIÓN (94/100)

+ Exposición perfecta: Error de solo 0.1 EV.
+ Apertura correcta: Elegiste f/2.8, logrando aislar al sujeto del fondo.
- Ojo con la velocidad: Disparaste a 1/60s con un 105mm. Estuviste al borde
  de la trepidación (regla recomendada: mínimo 1/125s).
```

Al superar las 5 lecciones, el juego desbloquea el título **"Graduado de la Academia Fotográfica"** como insignia permanente. **No restringe el catálogo**: todas las ópticas siguen disponibles desde el principio, como en el juego actual.


---

## 4. Punto de Partida en el Código y Criterios de Aceptación

- **Buena parte del informe ya existe**: `Photography.evaluate()` devuelve `lines`, cinco diagnósticos explicados (enfoque con CoC y distancia, exposición con ΔEV, movimiento con t·f y arrastre, oclusión con obstáculos, encuadre con altura y tercios), que la pantalla `RESULT` ya muestra. El tutor los reutiliza y añade el umbral de aprobado de cada lección, así que el coste real es **bajo-medio (S-M)**.
- **Ejercicios sobre el sandbox**: `show_sandbox_controls()` ya permite pausar la escena y repetir disparos sin límite, una base natural para la demostración guiada.
- **Criterios de aceptación** (nueva suite `tests/test_academy.gd`, headless):
  1. Cada lección aprueba o suspende de forma determinista a partir de una evidencia fija (reutilizando el patrón de `test_photography.gd`).
  2. El examen de la lección 2 (dos personas nítidas a 4,0 y 4,7 m) solo se aprueba si ambas quedan dentro de `Photography.dof()`.
  3. Todos los textos de teoría, examen e informe están en `data/textos.es.json`.

---

## 5. Raíces en el Documento Fundacional (2012)
Esta especificación formaliza la propuesta 3 del documento de mayo de 2012 ([PROYECTO_PAPARAZZI_2012.md](../origen/PROYECTO_PAPARAZZI_2012.md)):
> *"Un tutor interactivo para aprender técnica fotográfica. Concepto: Simuladores de cámaras (CameraSim). El motor del juego se utiliza para demostrar en la práctica los conceptos más técnicos... y ofrecer un sistema de ayuda pedagógica interactiva."*

---

## 6. Implementación (01-10-2026)

Decisiones del usuario antes de empezar: lecciones libres (sin desbloqueo), progreso guardado, todo en el parque actual, el tutor fija cámara y objetivo, se añaden las ópticas necesarias, teoría sobre el visor en tono informal, demostración con subtítulos, sin narración hablada por ahora, botón «Academia» en el inicio y exámenes a futuro. Antes se corrigió la fase 0 de [12](12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md): el AF matricial y la exposición automática ya no conocen al objetivo, porque un tutor que hace trampa enseña mal.

### 6.1 Piezas

| Pieza | Qué hace |
|---|---|
| `scripts/academy.gd` | Lecciones (`SETUP`: luz, cuerpo, objetivo, exposición inicial y diagrama de cada página), panel del tutor sobre el visor, subtítulos, resaltado de controles del HUD, demostraciones guionizadas, prácticas con tareas y pistas en vivo, progreso en `user://academia.cfg` y acciones del InputMap (`academia_siguiente`: Intro o A del mando, `academia_atras`: Retroceso o B, `academia_pausa`: P o Start). |
| `scripts/academy_diagram.gd` | Diagramas en vivo que leen el estado de la cámara: triángulo de exposición, escalas de pasos (diafragma, velocidad, ISO), zona nítida en planta, rastro de un corredor según la velocidad, cuadrícula de tercios con aire delante y vista lateral de la compresión. |
| `scripts/main.gd` | Menú (`show_academy()`), resultado de la práctica (`show_academy_result()`, con díptico en las lecciones 2 y 5), fotos de la demostración al panel (`academy_demo_shot`), opción `--academy=<lección>:<fase>[:página]` (también `menu` e `inicio`). |
| `data/textos.es.json` | Todos los textos (`academia_*`): 21 páginas de teoría de 60 palabras como mucho, 29 subtítulos, 15 tareas y sus pistas. |
| `scripts/equipment.gd` | Tres fijos nuevos en la réflex: 28 f/2,8, 105 f/1,8 y 135 f/2. |
| `scripts/park.gd` | `forced_cover`: cielo cubierto fijo para la luz suave de la lección 2. |

### 6.2 Las lecciones

| Lección | Luz y equipo | Demostración | Práctica |
|---|---|---|---|
| 1 · La exposición | Hora dorada; réflex 24–105 a 50 mm, manual, empieza en f/4 | Cierra dos pasos (la aguja cae a −2), compensa con dos pasos de velocidad, sube dos de ISO y vuelve a 0 cerrando; dispara | f/11 · aguja en 0 con la velocidad (±⅓ EV) · foto bien expuesta (±½ EV) |
| 2 · La profundidad de campo | Hora dorada cubierta; 105 mm f/1,8, manual | Enfoca a alguien a 4 m a f/1,8 (franja de centímetros, fondo en bokeh), cierra paso a paso hasta f/11 compensando; compara las dos fotos | Enfocar a alguien a 3–6 m · foto a f/2,8 o más abierto · otra a f/8 o más cerrado (díptico) |
| 3 · El movimiento | Hora dorada; réflex a 50 mm, manual, AF puntual | El corredor pasa a 1/30 (fantasma) y a 1/1000 (congelado); el disparo espera a que un punto de enfoque lo cubra | Corredor a 1/60 o más lento · a 1/500 o más rápido · y bien expuesto (±1 EV). El corredor vuelve a pasar cada pocos segundos |
| 4 · La composición | Hora dorada; 50 mm f/1,8, exposición automática, tercios | Centra a un paseante y luego lo lleva a un tercio con aire hacia donde camina y los ojos en la línea de arriba | Activar la cuadrícula · la cabeza de alguien del encuadre (a menos de 15 m) en un cruce, a menos del 6 % del ancho · con aire delante y disparar |
| 5 · La focal y la perspectiva | Día; 28 mm y 135 mm (botones del panel), automática | 28 mm a alguien a 2,3 m (el quiosco pequeño y lejano) y 135 mm a alguien a 11,6 m (el quiosco llena el fondo); escena congelada | 28 mm de cuerpo entero a menos de 4,5 m · 135 mm de cuerpo entero a más de 9 m (con una persona bajo el punto de enfoque) · díptico |

Cada lección prepara su escena delante de la cámara: oculta el paseo interior (r ≈ 1,8 m, que se cruza por delante del objetivo; `Person.set_hidden()` desactiva también sus colisionadores), aparta a quien estorbe en el sector y coloca al sujeto con la marca `staged` (sin bancos ni paradas). Al salir, todo vuelve a su rutina.

### 6.3 Pendiente

- **Exámenes** (§2 y §4): criterios de aprobado deterministas, informe formativo (§3), intentos y título de graduado.
- Narración hablada de la teoría (TTS local).
- Controles táctiles y Android (el APK no se ha recompilado).
- Lecciones extra (enfoque manual con telemétrica y réflex; luz nocturna, ISO y grano) y más escenarios.

### 6.4 Pruebas y evidencias

- `tests/test_academy.gd` (con display): textos de todas las páginas, subtítulos y tareas, menú con el examen no disponible, teoría y resaltado, las cinco demostraciones hasta el final con sus fotos (la 1 acaba con la aguja en 0; la 2 compara f/1,8 y f/11 y la zona nítida crece; la 3 pilla al corredor a 1/30 con rastro y a 1/1000 congelado; la 5 hace el 28 mm de cerca y el 135 mm de lejos de cuerpo entero), criterios de práctica con evidencias fabricadas, la detección real de los tercios de la lección 4 (centrado no vale; en un cruce con aire delante, sí), una práctica real de la lección 1 y el progreso en disco.
- `tests/test_automatisms.gd`: el AF matricial y el exposímetro no dependen del objetivo del encargo.
- `tools/capture_academy_video.sh`: vídeo de unos 3 min con una visita por lección (`--academy-tour=<segundos>:<páginas>`: pasa sola dos páginas de teoría, la demostración y la práctica), con la música del proyecto suave bajo el sonido del juego.
- `tools/capture_academy.gd`: capturas en `docs/evidencias/academia/` (menú, teoría, demostraciones, prácticas y díptico de la lección 5).

