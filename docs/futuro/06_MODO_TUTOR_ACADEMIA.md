# Especificación: Modo "Tutor de Fotografía" y Academia Interactiva

Este documento especifica la arquitectura pedagógica y los exámenes interactivos para el modo educativo **Academia de Fotografía**.

> [!NOTE]
> **Estado (02-10-2026): ✅ implementado, con exámenes.** Las cinco lecciones tienen **teoría, demostración guiada, práctica y examen** con informe del tutor; aprobar los cinco da el título de **Graduado de la Academia Fotográfica**. Lo implementado está en el §6 (los exámenes, en el §6.1). Evidencias en [`docs/evidencias/academia/`](../evidencias/academia/).

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

- ~~Exámenes~~: hechos el 02-10-2026 (§6.1).
- Narración hablada de la teoría (TTS local).
- Controles táctiles y Android (el APK no se ha recompilado).
- Lecciones extra (enfoque manual con telemétrica y réflex; luz nocturna, ISO y grano) y más escenarios.

### 6.4 Pruebas y evidencias

- `tests/test_academy.gd` (con display): textos de todas las páginas, subtítulos y tareas, menú con el examen no disponible, teoría y resaltado, las cinco demostraciones hasta el final con sus fotos (la 1 acaba con la aguja en 0; la 2 compara f/1,8 y f/11 y la zona nítida crece; la 3 pilla al corredor a 1/30 con rastro y a 1/1000 congelado; la 5 hace el 28 mm de cerca y el 135 mm de lejos de cuerpo entero), criterios de práctica con evidencias fabricadas, la detección real de los tercios de la lección 4 (centrado no vale; en un cruce con aire delante, sí), una práctica real de la lección 1 y el progreso en disco.
- `tests/test_automatisms.gd`: el AF matricial y el exposímetro no dependen del objetivo del encargo.
- `tools/capture_academy_video.sh`: vídeo de unos 3 min con una visita por lección (`--academy-tour=<segundos>:<páginas>`: pasa sola dos páginas de teoría, la demostración y la práctica), con la música del proyecto suave bajo el sonido del juego.
- `tools/capture_academy.gd`: capturas en `docs/evidencias/academia/` (menú, teoría, demostraciones, prácticas y díptico de la lección 5).

### 6.1 Exámenes (02-10-2026)

Cuarta fase de cada lección (`academy.gd`, fase `"examen"`): se entra desde la práctica («Ir al examen») o desde el menú de la Academia («Examinarme»). Sin pistas ni resaltados: un enunciado, la escena preparada y tantos intentos como se quiera. Cada foto recibe el **informe del tutor** en la pantalla de resultado: veredicto (`TODAVÍA NO`, `APROBADO` o `APROBADO CON MENCIÓN`, con nota sobre 100) y una línea por criterio, con `+` o `−` y la explicación con sus números. Se aprueba cuando se cumplen **todos** los criterios; el aprobado se guarda en `user://academia.cfg` y con los cinco aparece el título de graduado en el menú de la Academia.

| Lección | Escena del examen (`start_exam()`) | Criterios (`exam_report()`) |
|---|---|---|
| 1 Exposición | El cielo se nubla (`forced_cover = 1`) y los ajustes quedan unos 3 EV cortos | Error de exposición ≤ 0,5 EV · pulso (t ≤ 1/focal) |
| 2 Profundidad de campo | Dos personas de altura parecida a 4,0 y 4,4 m, con el 105 mm | Ambas dentro de `Photography.dof()` · ambas en el encuadre · exposición ≤ 1 EV · pulso |
| 3 Movimiento | El corredor pasa una y otra vez | Es el corredor · congelado (`Photography.needed_shutter()`) · nítido · exposición ≤ 1 EV · pulso |
| 4 Composición | Una persona cruza andando, cuadrícula de tercios a la vista | Cabeza en un cruce con aire por delante (`thirds_check()`) · nítida · exposición · pulso |
| 5 Focal | Alguien lejos en el paseo exterior; botones de 28 y 135 mm | Focal ≥ 120 mm · a más de 9 m y de cuerpo entero (45–130 % del alto) · nítido · exposición · pulso |

- El examen 2 usa 4,4 m en lugar de los 4,7 m del §2: con el 105 mm a f/11 enfocando al primero, la zona nítida llega a 4,5 m, así que se aprueba cerrando a f/11 (o a f/8 enfocando entre los dos), como pedía el enunciado original.
- `exam_report(lección, evidencia, contexto)` es estática y **determinista**: la misma evidencia da siempre el mismo informe. El contexto (`exam_context()`) añade lo que la evidencia no trae: las distancias de las dos personas, el estado de los tercios y cuánto llena el encuadre la persona.
- La nota es el porcentaje de criterios cumplidos, menos hasta 12 puntos por el error de exposición cuando se aprueba; mención a partir de 94.
- Textos: `academia_l<n>_examen`, `academia_ex_*` y `academia_examen_*` en `data/textos.es.json`.
- Pruebas (`tests/test_academy.gd`, 164 comprobaciones): informes con evidencias fijas de las cinco lecciones (aprobado y suspenso por cada causa), coherencia del examen 2 con `Photography.dof()`, un examen real de la lección 1 (suspende sin corregir, aprueba con la aguja en 0, el informe sale en pantalla), la puesta en escena del examen 2 y el título de graduado.
- **Exposímetro de la barra superior (02-10-2026, aviso del usuario)**: la lección 1 resaltaba «la aguja de arriba», pero con la interfaz de cámara ese hueco estaba vacío (la escala solo la dibujaba el visor clásico). Ahora `main.gd::draw_meter_bar()` dibuja la escala de −2 a +2 EV y la aguja entre los botones de exposición, y el resaltado usa su rectángulo real.
- **Corrección del examen 1 (02-10-2026)**: los ajustes de partida quedaban hasta 8 EV cortos (foto negra) porque el bucle que los desajusta leía la aguja del visor sin refrescar; ahora calcula el error él mismo (`exam_needle()`) y quedan unos 3 EV cortos, como dice el enunciado. El informe expresa el error de exposición con el signo de la aguja (negativo = subexpuesta).

## Tono de las lecciones: la idea fundamental (03-10-2026)

Las cinco lecciones se reescribieron para **enseñar fotografía como Jaime Altozano enseña la música** (idea fundamental del proyecto, cabecera de `AGENTS.md`): cada página arranca con una pregunta o una imagen cotidiana (la foto como un cubo de luz y tres grifos, el ISO como subir el volumen de una grabación floja, el fondo «hecho crema»), trata de tú, avisa de las trampas («número pequeño, agujero GRANDE»), guarda un giro para el final («la focal no cambia la perspectiva: la cambia dónde te pones») y enlaza unas lecciones con otras. El rigor no se toca: las cifras, las reglas y lo que comprueban la práctica y el examen son los de antes. Solo cambian textos de `data/textos.es.json` (`academia_l<n>_*`, 73 entradas), dentro de los tamaños de [TESTS_Y_VERIFICACION §4.3](../TESTS_Y_VERIFICACION.md) y sin teclas escritas a mano. Al escribir una página nueva: una idea por página, un ejemplo que se vea en el visor o en el esquema, y una frase que apetezca repetir.

## Diez lecciones: las cinco del equipo (03-10-2026, usuario: «mínimo el doble de lecciones»)

| Nº | Lección | Luz | Lo que pone en las manos | Práctica | Examen |
|---|---|---|---|---|---|
| 6 | **Los objetivos** | Hora azul (la poca luz es el tema) | Zoom 24–105 f/4 y fijo 50 f/1,8 | Centrar el exposímetro a ISO 100 con el zoom (velocidad lentísima), luego con el fijo a f/1,8, y disparar sin trepidar | Foto nítida, a pulso y bien expuesta a ISO 100: solo el fijo puede |
| 7 | **Las cámaras** | Día | Cada página monta su cuerpo: compacta, telemétrica, réflex, TLR | Una foto nítida de una persona con la telemétrica, la TLR y la réflex (botones de cuerpo en el panel) | Foto nítida con la telemétrica (enfoque manual) |
| 8 | **El enfoque** | Día | Los nueve puntos y el bloqueo | Elegir otro punto, bloquear el foco sobre alguien, reencuadrar y disparar | La persona nítida y a un lado del encuadre |
| 9 | **Medir la luz** | Día | Matricial, ponderada y puntual (botones en el panel: el mando no tiene control de fotometría) y la compensación | Elegir puntual, compensar a +1 EV, volver a 0 y exponer bien | Foto bien expuesta (±0,5 EV) y nítida midiendo en puntual |
| 10 | **P, A, S y M** | Día | Cada página pone su modo; botones P A S M en el panel | En A, foto a f/2,8 o más abierto; en S, a 1/500 o más; en M, bien expuesta | En M: nítida, a pulso y a medio paso |

- **Implementación** (`scripts/academy.gd`): `LESSONS = 10`; `SETUP[6..10]` con `page_do` (la acción que ejecuta cada página de teoría: `body:k`, `lens:i:f`, `mode:X`, `meter:nombre`) y `mode`; `CHOICES` (los botones de elección de práctica y examen, también los de la lección 5); acciones nuevas de `do_action()` (`body`, `lens`, `mode`, `meter`, `comp`, `lock`, `expose_m`, `shoot_now`); `set_body()`; criterios en `check_practice()`, `on_practice_photo()`, `exam_context()` y `exam_report()`. Sin esquema (`pages` vacías): el propio visor es el ejemplo.
- **Luz de las lecciones** (usuario): buena luz salvo que la luz sea el tema. De día las lecciones 2, 3 (nubladas: f/1,8 o 1/30 quemarían la foto a pleno sol), 4, 5, 7, 8, 9 y 10; hora dorada la 1 (exposición) y hora azul la 6 (objetivos).
- El menú de la Academia pasa a diez filas compactas; el título de graduado y su insignia piden los diez exámenes. El progreso guarda también los exámenes entre sesiones (`SAVED`; antes se perdían al reiniciar el juego).
- Pruebas: `tests/test_academy.gd` (293 comprobaciones: las diez demostraciones, criterios de práctica y de examen de las lecciones nuevas); textos dentro de los tamaños de [TESTS_Y_VERIFICACION §4.3](../TESTS_Y_VERIFICACION.md).

- **04-10-2026 (usuario)**: los objetivos (6) van antes que las cámaras (7). La nota del examen solo descuenta el error de exposición que pasa de medio paso: los diales van de paso en paso y medio paso de error puede ser lo mejor que permite la luz (antes no se podía sacar un 100). En los textos, **mayúscula tras punto y tras dos puntos**.

## Academia replanteada (04-10-2026, tras probarla el usuario)

**Regla del orden**: ninguna lección habla de algo, lo pide en la práctica o lo examina si una lección anterior no lo ha enseñado. Las lecciones van por **identificador** (`academy.gd::ORDER`); el código, los textos (`academia_<id>_…`) y el fichero de progreso (`leccion_<id>`, con lectura de los ficheros antiguos por número) no dependen del orden, así que reordenar es cambiar esa lista.

| Nº | Id | Lección | Luz | La cámara | Práctica | El examen mira |
|---|---|---|---|---|---|---|
| 1 | `composicion` | La composición | Día | Todo automático | Cuadrícula, cabeza en un cruce, aire delante | Solo los tercios y el aire |
| 2 | `enfoque` | El enfoque | Día | Exposición automática | Otro punto, bloquear, reencuadrar | Persona a un lado y nítida |
| 3 | `focal` | La focal y la perspectiva | Día | Automático; 28 y 135 mm en el panel | Angular de cerca, tele de lejos, comparar | Tele, lejos, nitidez |
| 4 | `exposicion` | La exposición | Hora dorada | Manual | Cerrar a f/11, compensar, foto bien expuesta | Solo la exposición |
| 5 | `dof` | La profundidad de campo | Día nublado | **Prioridad a la apertura** | Enfocar a 3–6 m, foto abierta, foto cerrada | Las dos personas en la zona nítida |
| 6 | `movimiento` | El movimiento | Día nublado | **Prioridad a la velocidad; la cámara enfoca sola al corredor** | Foto lenta, foto rápida, comparar | Corredor congelado y pulso |
| 7 | `medicion` | Medir la luz | Día | Prioridad a la apertura (f/8) | Puntual, compensar +1, volver a 0 | Puntual, exposición, nitidez |
| 8 | `modos` | P, A, S y M | Día nublado | Cada página su modo | Una foto en A, una en S, una en M | Modo M, exposición, pulso, nitidez |
| 9 | `objetivos` | Los objetivos | Hora azul | Manual, ISO 100 | Centrar con el zoom, con el fijo, disparar sin trepidar | ISO 100, exposición, pulso, nitidez |
| 10 | `camaras` | Las cámaras | Día | Cada página su cuerpo | Telemétrica, TLR, réflex | Telemétrica y nitidez |

- **Qué mira cada examen**: `EXAM_ASKS` (exposición, pulso, nitidez, que haya una persona) más lo propio de la lección. El pulso no se pide hasta el movimiento; la exposición, hasta su lección. La nota solo descuenta el error de exposición que pasa de medio paso, y solo donde se examina.
- **Medio paso** (`HALF_STOP`): los diales van de paso en paso, así que «centrar el exposímetro» es quedar a medio paso o menos. Antes se pedía un tercio y había prácticas imposibles (la de exposición y la de objetivos).
- **Movimiento**: `auto_subject()` devuelve al corredor; la cámara lo mantiene enfocado y la foto es suya si está en el encuadre, esté donde esté el punto de enfoque (`main.gd::capture_sandbox_evidence()`). Antes había que acertarle con el punto y no se podía pasar.
- **Composición**: el aire va delante de hacia donde camina o, si está quieto, de hacia donde mira (`facing_side()`); antes una persona parada pasaba el examen sin aire.
- **Teoría que se ve**: en la profundidad de campo el diafragma se abre y se cierra solo cada 2,6 s; en la focal, las páginas del tele cambian de verdad al 135 mm sobre alguien lejano (`lens_wide`, `lens_tele`), a 86°, libre de bancos y farolas.
- **Demostraciones**: van a mitad de ritmo (`DEMO_PACE`: cada rótulo dura el doble); los rótulos son blancos sobre celeste y las fotos de ejemplo llevan borde celeste. **Mientras conduce el tutor**, un marco rojo rodea el visor, un cartel parpadea («El tutor maneja la cámara: Mira») y los controles del jugador no responden (`locks_input()`); al acabar, el marco desaparece y «Ir a la práctica» se enciende con un aro blanco y celeste.
- **Lenguaje visual** (usuario): **texto blanco y borde celeste llevan el ojo a lo que importa** en cada pantalla (rótulos, fotos de ejemplo, resaltes de controles, el siguiente botón); el rojo queda para «no toques».
- Otros arreglos: la pista de la práctica se construye de cero en cada pasada (se repetía hasta salirse del panel), los rótulos de los esquemas encogen si no caben, la cuadrícula de tercios es más gruesa (blanca sobre borde oscuro), los objetivos se nombran como en su barril («24–105 f/4», «50 mm f/1,8», y qué significan dos aperturas).
- **Comprobación real**: `scripts/academy_player.gd` juega la Academia como un alumno aplicado (cada tarea con los controles y las fotos del juego, y cada examen). `tests/test_academy_play.gd` exige que las diez prácticas y los diez exámenes se superen así; `tools/capture_academy.sh` graba el pase completo (`-- --academy-play=<segundos por página>[:<primera>-<última>]`).

## Segunda ronda de la Academia (04-10-2026, usuario)

- **El jugador no toca la cámara hasta la práctica** (`locks_input()`: teoría y demostración). La teoría, por tanto, **no da órdenes**: nada de «sigue al corredor» o «pruébalo»; se cuenta en «si seguimos…», «lo probaremos luego». El marco rojo y el cartel siguen siendo solo de la demostración (`tutor_drives()`).
- **Lo que se señala, se elige**: al resaltar un control (diafragma, velocidad, ISO, zoom) pasa a ser también el control en mano de la tira (relleno celeste además del aro).
- **Teclas dibujadas**: el texto de teoría y de examen se pinta con `glyph_label.gd` (`body_rich`), y las teclas van con «y»: `{diafragma_y}` → «Q y E» con sus teclas.
- **Siempre a foco y con el punto central**: en teoría y demostración quien enseña la lección se mantiene enfocado, y toda lección empieza con el punto de enfoque central. El visor muestra siempre los nueve puntos, con el activo destacado.
- **La práctica nunca está lista para disparar**: la cámara se entrega girada 22° y con lo propio de la lección fuera de sitio (exposición dos pasos desviada, foco al fondo, ISO 400 y f/8 en la de objetivos…).
- **Ningún examen repite la práctica**: composición (el modelo, descrito por su ropa, camina), enfoque (a mano), focal (el modelo está lejos y en otro sitio), movimiento (con el zoom a 70 mm), medición (un paso más clara, con la puntual), modos (fondo desenfocado a f/2,8 en el modo que se quiera), objetivos (plano general a 24 mm), cámaras (con la TLR), profundidad de campo (la segunda persona, un metro más lejos: hay que cerrar a f/22).
- **Margen de un paso** (`HALF_STOP = 0,9999`): los diales van por pasos enteros; menos de un paso de error es «punto encendido» (el LED del visor también) y no descuenta nota. La lección de exposición habla del **punto**, no del «centro».
- **Páginas nuevas**: «Cómo funciona la Academia» (primera de la primera lección), «Luego romperemos las normas» (exposición), «Cuándo llevarle la contraria» (medición: escena nocturna compensada a −1,3 EV, acción `noche`) e «Y hay muchas más» (cámaras: móviles y CSC).
- **Menú**: lista con desplazamiento; primero «Empezar/Repasar» y luego «Examinarme», que no se activa hasta haber leído la teoría; cinco lecciones «Próximamente» (macro, retrato, naturaleza, urbana, otras normas de composición) y «Y mucho más…».
- **Informe del tutor** del examen: en blanco sobre un marco celeste.
