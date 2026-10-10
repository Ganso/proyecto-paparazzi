# 21 · Modo arcade, condiciones por nivel y cámara TLR

**Estado: ✅ Implementado (01-10-2026)**, encargo del usuario a partir de la especificación original del blog (blog.ganso.org/proyectos/proyecto-paparazzi.html). Sustituye a la sesión de 5 encargos: el menú queda en **Arcade**, **Sandbox** y **Academia**.

## 1. Arcade (`scripts/arcade.gd`)

- **20 niveles en 4 bloques de 5** (25 en 5 desde el 02-10-2026: ver «Bloque 5» al final), un encargo por nivel. Se desbloquean en orden y se pueden repetir; se guardan la mejor nota y las estrellas de cada nivel superado en `user://arcade.cfg`.
- **El nivel lo fija todo**: escenario, luz y equipo (en el sandbox se eligen en el menú). La curva va de lo automático a lo manual:

  | Bloque | Cámara | Escenarios y luz | Disparos | Tiempo | Nota mínima |
  |---|---|---|---|---|---|
  | 1 · Primeros pasos | Compacta automática | Clásico, día y hora dorada | 5 → 3 | sin límite → 90 s | 50 → 60 |
  | 2 · La réflex | Réflex AF: programa, prioridad a la apertura (A) y a la velocidad (S) | Clásico | 4 → 3 | 120 → 90 s | 55 → 65 |
  | 3 · Calle | Telemétrica MF: exposición automática, luego A, luego manual; gente más lenta | Clásico y parque grande, día, hora dorada, azul y noche | 3 → 2 | sin límite → 120 s | 65 → 70 |
  | 4 · La TLR | TLR 6×6 con carrete, todo manual; gente más lenta | Clásico, día, hora dorada y azul | 3 → 1 | sin límite → 60 s | 70 → 75 |

- **Flujo**: menú → niveles (`show_arcade()`) → encargo del nivel con cámara, disparos, tiempo, nota mínima y condiciones (`show_level_briefing()`) → búsqueda con el reloj (`level_time`, en la barra de estado) y las condiciones en la línea del encargo → resultado de cada foto con las condiciones marcadas ✓/✗ → **Nivel superado / no superado** (`end_level()`) con la mejor foto, el motivo y Repetir · Siguiente nivel · Niveles.
- **Fallo**: si se acaban el tiempo o los disparos sin una foto que cumpla, «Nivel no superado» y reintento inmediato, sin vidas.
- **Estrellas**: la nota mínima da una y cada cuarto del camino hasta 100 otra (`Arcade.stars_for()`).
- En el arcade el equipo no se puede cambiar (la pantalla de equipo solo deja la interfaz y los gráficos).
- La población del parque clásico sigue en 21; los niveles del parque grande tienen 45.
- `start_session()` sin nivel sigue existiendo para las pruebas y los vídeos guionizados: encadena encargos sin fin.

## 2. Condiciones (`scripts/conditions.gd`)

Obligatorias: una condición fallida **rechaza la foto** con su motivo, como el sujeto fuera del encuadre. Se calculan sobre la evidencia (`main.gd::capture_evidence()`), de forma determinista.

| Clave | Condición | Cálculo |
|---|---|---|
| `ojos` | Ojos nítidos | CoC en los ojos ≤ 0,030 mm |
| `aislado` | Nadie más en el encuadre | 0 personas más visibles con el pecho dentro y altura ≥ 10 % |
| `acompanado` | Acompañado de N | exactamente N personas así |
| `grande` | Sujeto grande | altura en la foto ≥ el umbral |
| `focal_min` | Focal mínima | focal ≥ el valor |
| `aurea` | Proporción áurea | cara en x = 0,382 o 0,618 (± 0,045) |
| `fondo` | Fondo desenfocado | CoC de un punto 10 m detrás del sujeto ≥ 0,07 mm |
| `congelado` | Movimiento congelado | sujeto a ≥ 1,5 m/s y arrastre ≤ 0,030 mm |

El límite de tiempo es una restricción más del nivel (`limit`).

**El sujeto se juzga en los ojos**, como hacen los fotógrafos: la evidencia lleva `eyes` y `d_eyes` (a media altura de la cabeza) y `Photography.evaluate()` mide el enfoque a esa distancia en todas las fotos, no solo en el arcade. `others` recoge al resto de viandantes en el encuadre, con un rayo para saber si se ven.

## 3. TLR 6×6

- **Cuerpo 3** de `equipment.gd`: «TLR 6×6» con el **Planar 80 f/2.8**, que en el cuadrado de 56 mm abarca el campo de un 50 mm sobre el ancho de referencia de 36 mm (equivalente 50 mm). Solo enfoque manual, exposición manual y **carrete de ISO fijo**. Preajuste «Clásica · TLR 6×6».
- **A la cintura**: la cámara baja a **1,10 m** (contrapicado) y vuelve a 1,60 m con los demás cuerpos (también en el parque grande).
- **Visor de cintura espejado**: `viewfinder_lens.gdshader` (`mirror`, `square`, `loupe`) invierte izquierda y derecha y muestra solo el cuadrado central; la ayuda de enfoque (`focus_aid.gdshader`) también. Los controles no se tocan: giras la cámara a la derecha y la imagen del cristal esmerilado va al revés, como en una TLR real. `image_position()` deshace el espejo al medir.
- **Lupa 3×** (tecla L) sobre el centro del cristal esmerilado.
- **Formato cuadrado**: la foto se recorta al cuadrado y sale **derecha** (solo el visor está espejado). La evaluación se proyecta sobre el cuadrado (`square_evidence()`): un sujeto dentro del 16:9 pero fuera del cuadrado queda fuera del encuadre.
- **Carrete de 12 y manivela**: en el sandbox cada foto gasta un fotograma y hay que girar la manivela (K, con sonido de trinquete) antes de la siguiente; al acabar, K carga otro carrete. En el arcade mandan los disparos del nivel y la película avanza sola.
- **Visor realista** (`camera_body.gd::draw_tlr()`): caperuza vista desde arriba, cuadrícula del cristal esmerilado, contador de fotogramas y fotómetro de mano con aguja.

## 4. Pruebas y evidencias

- `tests/test_arcade.gd` (headless): datos de los niveles y su curva, desbloqueo, estrellas, progreso y cada condición.
- `tests/test_game.gd`: flujo del arcade (equipo fijo, disparos, reloj, sujeto corredor, condiciones en la línea del encargo), TLR (cintura, foto cuadrada, evidencia sobre el cuadrado, carrete y manivela).
- `tests/test_finders.gd`: visor espejado y cuadrado; misma nota con las dos interfaces también en la TLR.
- `tests/test_equipment.gd`: preajuste y objetivo de la TLR.
- `tools/arcade_solver.gd`: juega los niveles solo (los 25 desde el 02-10-2026) y comprueba que **todos se pueden superar** (20/20).
- Capturas: `tools/capture_screens.gd` (`11_arcade` a `17_fin_nivel`). `--level=N` abre un nivel al arrancar.

## 5. Un control manual cada vez (02-10-2026)

Tras probar el usuario el primer nivel manual («demasiado complicado: cámara, foco y exposición a la vez»):

- **Modos de prioridad** en `equipment.gd` (`priority`, `exposure_mode()`, `set_exposure_mode()`): **A**, tú eliges el diafragma y la cámara el tiempo y el ISO; **S**, al revés. `auto_expose()` respeta el control del jugador. También en la pantalla de equipo y con la letra del modo en los visores (P, A, S, M).
- **Curva rehecha**: el bloque 2 introduce A (nivel 7, fondo desenfocado) y S (nivel 10, congelar al corredor); el bloque 3 empieza con enfoque manual y exposición automática (11 y 12), luego A (13) y por fin todo manual (14 y 15). La nota mínima sube de 50 a 75 y puede bajar al estrenar cámara. Tiempos más holgados (120–150 s en los niveles manuales; el primero de la telemétrica y el de la TLR, sin límite).
- **Personajes más lentos** donde enfoque y exposición son manuales: `pace` del nivel (0,5–0,7) multiplica la velocidad de los caminantes (`main.walk_pace`, también en el parque grande); los corredores mantienen la suya. Es una excepción deliberada al rango de velocidades de AGENTS §3.2, solo dentro de esos niveles.
- **Exposición de partida medida**: en los niveles con exposición manual o semiautomática la cámara empieza ajustada para el sujeto; el jugador la afina.
- Los diales se detienen en sus extremos (antes pasaban de f/22 a f/1.4).

## 6. Ratón y ayuda en pantalla (02-10-2026)

- **El ratón mueve la vista hacia donde va**, en los dos ejes (antes el giro lateral arrastraba la escena y el vertical seguía al ratón). El táctil no cambia.
- **Ayuda en pantalla** (`scripts/control_help.gd`): un interruptor siempre visible sobre la imagen y la tecla **F1** muestran un panel con los controles de la cámara montada, su tecla, su valor y si los llevas tú (**MAN**, resaltado) o la cámara (**AUTO**); los fijos (objetivo fijo, ISO del carrete) aparecen apagados, y con exposición manual el exposímetro en verde o naranja. En la interfaz clásica la tecla aparece también sobre cada botón. Va en su propio cristal oscuro (igual en tema claro y oscuro) y se recuerda en `user://interfaz.cfg`. Activada por defecto.

## 8. Bajar la cámara para buscar (02-10-2026)

En el parque clásico la cámara también se baja (tecla **Y**, botón en pantalla «Bajar la cámara · Y» o el botón Y del mando): vista natural amplia (72°) sin visor para localizar a alguien, y de vuelta al ojo con el objetivo puesto, mirando al mismo sitio (`main.gd::update_classic_raise()`, `view_focal()`; el giro con la cámara bajada va a la velocidad de un 30 mm). Sin la cámara al ojo no se puede disparar. En la Academia no se baja. Además, **el sujeto de un encargo nunca corre**, salvo en los niveles de congelar a un corredor (`target: "runner"`).

## 7. Pendiente

Barrido (`congelado` exige congelar; el barrido sigue en [11](11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md)), insignias de [05 §3](05_DESAFIOS_Y_MODOS_JUEGO.md), condiciones de luz y de punto de interés (fuente, quiosco), sonido propio del obturador central de la TLR y la manivela animada.

## Bloque 5 · Maestría, y la condición «barrido» (02-10-2026)

El arcade tiene ahora **25 niveles en 5 bloques**. El quinto, «Maestría · la réflex a fondo», vuelve a la réflex con todo lo aprendido:

| Nivel | Título | Luz · objetivo · exposición | Condiciones | Disparos · tiempo · mínimo |
|---|---|---|---|---|
| 21 | El barrido | Día · zoom 24–105 · prioridad S · corredor | `barrido` | 4 · 150 s · 65 |
| 22 | Retrato de autor | Hora dorada · 105 mm f/1,8 · prioridad A | `fondo`, `aurea` | 3 · 120 s · 70 |
| 23 | Sola y de cerca | Parque grande, día · 70–200 · manual | `aislado`, `grande` 60 % | 3 · 150 s · 70 |
| 24 | Barrido al atardecer | Hora dorada · zoom 24–105 · manual · corredor | `barrido`, `grande` 45 % | 3 · 150 s · 70 |
| 25 | Nocturno | Noche · 50 mm f/1,8 · manual, AF puntual | `ojos`, `aislado`, `grande` 50 % | 2 · 90 s · 80 |

- **Condición `barrido`** (`conditions.gd`): un corredor (≥ 1,5 m/s) nítido con la cámara siguiéndolo —arrastre relativo ≤ `Photography.PAN_TOLERANCE` (0,075 mm)— y el fondo arrastrado al menos `PAN_STREAK` (0,5 mm). El motivo del rechazo distingue «no corre», «sale movido: gira a su ritmo» y «el fondo apenas se arrastra: usa una velocidad más lenta». `congelado` usa ahora también la velocidad relativa al giro de la cámara: un buen barrido cuenta como congelado, y mover la cámara al disparar emborrona.
- **Barrido con teclas** (`main.gd::key_turn()`, `key_follow_speed()`): las teclas de girar tienen una sola velocidad (42·24/focal °/s), así que acertar con el ritmo del corredor era cuestión de suerte. Mientras se mantiene pulsada una tecla, la cámara **acompaña a quien cruza el centro del encuadre en ese sentido** (si su velocidad angular está entre 0,3 y 2,5 veces la de la tecla), como un fotógrafo que sigue al sujeto. Con ratón y con el stick del mando el giro sigue siendo del todo manual. La tolerancia del barrido se amplió de 0,030 a 0,075 mm: antes había que igualar el giro con un error de 1°/s; ahora, de alrededor de un 10 %.
- La pantalla del arcade dibuja los bloques que haya (`Arcade.BLOCKS`), con tarjetas algo más bajas para que quepan cinco filas.
- **Se pueden superar**: `tools/arcade_solver.gd` aprende a hacer barridos (sigue al corredor fotograma a fotograma y dispara sin parar) y pasa los 25 niveles; los nuevos, tres veces seguidas. El solucionador pone a cero el giro de la cámara antes de las fotos que no son barridos, como haría quien se detiene a disparar.
- Pruebas: `tests/test_arcade.gd` (25 niveles, textos, la condición con sus cuatro motivos), `tests/test_photography.gd` (tolerancia) y `tests/test_input.gd` (la tecla sigue al corredor en su sentido y nunca en contra).
- **Código de trampa** (02-10-2026): lanzar el juego con `-- --cheat=niveles` abre los 25 niveles en esa partida (`Arcade.all_open`), sin tocar el progreso guardado.
- **El corredor de un nivel corre** (02-10-2026): en los niveles con `target: runner` se elige al del tercer camino (7 m; desde el 03-10-2026 los corredores van por los dos caminos exteriores con el centro libre, [NAVEGACION §3.2](../NAVEGACION_Y_COLISIONES.md)) y, mientras es el sujeto del nivel, no se para a estirar (`main.gd::runner_on_duty()`).

- **04-10-2026 (usuario)**: en los niveles que piden al sujeto solo (`aislado`: 3, 12 y 15) el parque se queda más tranquilo: tres de cada cinco personas no aparecen (`main.gd::new_assignment()`, meta `away`: ocultas y sin colisionador para la foto). Con el parque lleno, el 15 no había manera de hacerlo. El 14 pasó a «Todo manual» con el sujeto grande.

## Nubes solo donde toca medir (05-10-2026)

Decisión del usuario: las nubes que pasan y oscurecen el parque **ya no son la norma**. Quedan para los niveles del arcade con **exposición manual** de día o a la hora dorada (`arcade.gd::clouds()`: `auto == false` y luz `day` o `golden`), que es donde leer la luz es el trabajo, y su encargo lo avisa con una línea más en «Condiciones»: «Cuidado con las nubes, que oscurecen la zona cuando pasan» (`arcade_aviso_nubes`). En el resto del juego (tutorial, Academia, demás niveles) la luz se queda quieta (`park.clouds_enabled` es `false` por defecto y `main.gd::start_session()` lo fija por nivel); el sandbox las sigue ofreciendo en sus ajustes («Nubes en movimiento»), apagadas de entrada. `tests/test_arcade.gd` lo comprueba.

## Treinta niveles en seis bloques: un encargo por cada concepto (06-10-2026, usuario)

El arcade pedía nueve cosas y varios niveles se resolvían igual. Ahora **cada concepto que el juego enseña tiene un nivel que lo exige**: 30 niveles en 6 bloques (se añade «La luz»), 19 condiciones. Los personajes no tienen ojos: los niveles de «cara nítida» bromean con ello en su encargo.

| Nº | Título | Luz · equipo · exposición | Condiciones |
|---|---|---|---|
| 1–5 | **Primeros pasos** · compacta automática | | —, `grande` 60 %, `aislado`, `acompanado` 1 (90 s), `aurea` |
| 6 | Teleobjetivo | Día · 70–200 · P | `focal_min` 135 |
| 7 | **Con aire por delante** (nuevo) | Día · 24–105 · P | `focal_max` 35, `aire` |
| 8 | Fondo desenfocado | Dorada · 105 f/1,8 · A | `fondo` |
| 9 | Cara nítida | Día · 50 f/1,8 · AF puntual | `ojos`, `grande` 50 % |
| 10 | Congela al corredor | Día · 70–200 · S | `congelado` |
| 11 | Enfoque manual | Día · telemétrica · P | — |
| 12 | Parque grande | Dorada · telemétrica · P | `aislado` |
| 13 | **Lo que hace** (nuevo) | Día · telemétrica 50 · A · `target: activity` | `actividad`, `ojos` |
| 14 | **Todo nítido** (nuevo) | Día · telemétrica 35 · A · `toward: quiosco` | `lugar` quiosco, `nitido` |
| 15 | Todo manual | Parque grande, día · M | `grande` 50 % |
| 16 | Hora azul | Azul · telemétrica · A | `ojos` |
| 17 | **Exposición clavada** (nuevo) | Día con nubes · réflex · M | `exposicion` |
| 18 | **A contraluz** (nuevo) | Dorada · réflex · A, medición puntual · `toward: sol` | `contraluz` |
| 19 | **La silueta** (nuevo) | Dorada · réflex · M · `toward: sol` | `silueta` |
| 20 | Noche en el quiosco | Noche · telemétrica · M | `aislado`, `ojos` |
| 21–25 | **La TLR** (los antiguos 16–20) | Día ISO 200 · día ISO 400 · **hora dorada ISO 100** · día ISO 800 · hora azul ISO 1600 | —, `aurea`, `ojos`+`fondo`+`grande`, `congelado`, `ojos`+`aislado` |
| 26 | El barrido | Hora dorada · S | `barrido` |
| 27 | **La estela** (nuevo) | Hora azul · S | `estela` |
| 28 | Retrato de autor | Dorada · 105 f/1,8 · A | `fondo`, `aurea` |
| 29 | **Paseando al perro** (nuevo) | Parque grande, día · M · `target: dog` | `perro`, `grande` 40 % |
| 30 | Nocturno | Noche · 50 f/1,8 · M | `ojos`, `aislado`, `grande` 50 % |

Desaparecen dos niveles que repetían combinación («Sola y de cerca» y «Barrido al atardecer»); «En pareja» baja al nivel 4 (antes un nivel sin condición).

**Condiciones nuevas** (`conditions.gd`; los datos salen de `main.gd::capture_evidence()`):

| Clave | Qué comprueba |
|---|---|
| `focal_max` | Focal como mucho esa (un angular, de cerca) |
| `aire` | El sujeto cruza el encuadre (≥ 0,25 m/s de lado) y tiene delante el lado ancho: pecho en x ≤ 45 % si va a la derecha, ≥ 55 % si va a la izquierda |
| `exposicion` | Error de exposición ≤ ¼ de paso: con tercios se consigue siempre, con pasos enteros a veces |
| `nitido` | Un punto 10 m detrás del sujeto dentro del límite de nitidez (0,030 mm) |
| `lugar` | Un hito del parque (`park.places`: `quiosco`, `estanque`) delante de la cámara y dentro del encuadre |
| `actividad` | El sujeto está sentado o parado haciendo algo (`e.activity`) |
| `perro` | El perro del sujeto dentro del encuadre y nítido (≤ 0,045 mm a su distancia) |
| `contraluz` | La cámara mira hacia el sol (`e.backlight` ≥ 0,5: a menos de 60° en planta) con el sujeto al sol, y la exposición acierta **dos pasos por encima** de lo que mide el fotómetro, ± 0,75 |
| `silueta` | La misma luz, al revés: entre 0,7 y 2,7 pasos **por debajo** del fotómetro |
| `estela` | Un corredor arrastrado ≥ 0,5 mm con la cámara quieta (fondo ≤ 0,030 mm) |

- **Tres condiciones cambian cómo se juzga la foto**, no solo si pasa: `Conditions.prepare()` mueve el objetivo de exposición (contraluz −2 EV, silueta +1,7 EV respecto a la luz del sujeto) y marca la estela como virtud (`e.trail`: `Photography.evaluate()` da el movimiento por bueno y lo explica con `mov_estela`). `Conditions.judge()` hace las tres cosas (preparar, evaluar, aplicar) y es lo que usan `main.gd::take_photo()` y el solucionador. Sin el nivel, esas mismas fotos puntúan como siempre. La imagen revelada se sigue dibujando como era la escena (`e.ev_shift`): quemada alrededor de una cara bien expuesta a contraluz, oscura en una silueta.
- **A contraluz mide en puntual** (`"metering":"puntual"` en el nivel): con la matricial la lectura depende de lo que rodea al sujeto y la compensación de +2 no acertaba de forma fiable (a la hora dorada las farolas ya alumbran).
- **Sujetos especiales** (`new_assignment()`): `target: "activity"` elige a alguien del camino de los bancos que pueda sentarse, lo lleva a un banco libre (`seat_target()`) y lo mantiene en su actividad lo que dura el nivel (`activity_on_duty()`); `target: "dog"`, al dueño del perro; `toward` elige, de los del tercer camino, a quien antes vaya a pasar por delante del quiosco o por el lado del sol (`toward_theta()`), para no esperar una vuelta entera.
- **Progreso**: `user://arcade.cfg` lleva `formato = 2`. Un fichero de los 25 niveles se migra al cargar (`Arcade.FROM_25`, `migrate()`): cada resultado va a donde está ahora su nivel y los de los dos niveles retirados se descartan. Un nivel ya superado sigue abierto aunque el anterior sea nuevo (`unlocked()`).
- **Pantalla de niveles**: seis filas de tarjetas de 62 px.
- **Pruebas**: `tests/test_arcade.gd` (183: datos de los niveles, migración, que cada condición la pida algún nivel y los casos de cada condición nueva), `tests/test_game.gd` (el sujeto de «Lo que hace» va a un banco, los datos nuevos de la foto, la medición puntual del contraluz) y `tools/arcade_solver.gd` (30 de 30; `SOLVER_SHOTS=<carpeta>` guarda la pantalla de resultado de cada nivel), que aprende a dejar aire, encuadrar el quiosco, exponer por tercios y compensar el contraluz.

## El sujeto siempre se puede encuadrar con el objetivo del nivel (10-10-2026, usuario)

En el nivel 30 (50 mm fijo, «medio encuadre») podía tocar un niño en el tercer camino: a 7,6 m y con 1,15 m de altura llena un 37 % de la foto, haga lo que haga el jugador, y la foto se rechazaba. Ahora `main.gd::new_assignment()` solo elige a quien el objetivo del nivel puede encuadrar como se pide:

- `subject_reach(p, lane)`: la altura máxima que puede ocupar en la foto, desde el centro del parque clásico, en el borde lejano de su camino y con la focal más larga que permite el encargo (la del objetivo, o `focal_max` si el nivel la limita).
- `subject_fits(p, lane)`: esa altura llega a lo que pide `grande` más un 5 %, o al 40 % si el nivel no pide tamaño (por debajo del 45 % el encuadre ya baja la nota). En el parque grande siempre vale: el fotógrafo se acerca andando.
- Si nadie cumple (los corredores del nivel 24, todos lejos para la TLR), se elige a quien sale más grande.
- El sujeto de un encargo no cambia a un camino donde su foto ya no cabría (`try_change_lane()`).

Vale también para el modo libre con encargo, con el objetivo que lleve el jugador. Lo comprueba `tests/test_game.gd` (cada nivel del parque clásico, seis veces) y los 30 niveles se resuelven con `tools/arcade_solver.gd`, que ahora pone el punto de enfoque sobre el sujeto antes de disparar.

## Velocidades lentas, con poca luz (10-10-2026, usuario)

A pleno sol (EV 14,7), con el diafragma cerrado del todo (f/22) e ISO 100, la velocidad más lenta que no quema la foto es 1/60 s: a 1/30 s sobra casi un paso y a 1/15 s casi dos, y en prioridad de velocidad la cámara ya no tiene nada que cerrar. La estela del nivel 27 pide a menudo 1/30 s o menos (con un angular, 1/15 s), así que de día la foto salía siempre sobreexpuesta. El barrido (26) pasa a la **hora dorada**, donde 1/30 s cabe justo, y la estela (27) a la **hora azul**, donde caben de 1/60 s a 1/8 s. No hay filtros de densidad neutra en el juego; si se añaden, estos niveles podrían volver al día.

## Auditoría de los 30 niveles: lo que se pide tiene que poder hacerse (10-10-2026, usuario)

Tras dos niveles imposibles en dos días (un niño que no llenaba el encuadre del nivel 30, una estela que a pleno sol solo podía salir quemada), el usuario pidió repasar **uno por uno** todo lo que cada nivel exige y cómo lo consigue el jugador. Se hizo con dos herramientas: `tools/arcade_audit.gd` (nueva: por nivel, 20 situaciones reales; mide la altura que alcanza el sujeto, lo que lee el exposímetro frente a la luz que se juzga y la mejor nota **al alcance del jugador**, que no es la mejor posible) y `tools/arcade_solver.gd --repeat=3` (90 partidas).

### Lo que estaba mal y cómo quedó

| Dónde | Qué pasaba | Arreglo |
|---|---|---|
| **Todos los niveles** (medición matricial) | Con el sujeto encuadrado, el exposímetro se iba 3 o 4 pasos en una de cada cinco o seis fotos: el punto caía al lado de una figura delgada, o el sujeto quedaba fuera del centro en una cámara sin autofoco, o era lo más luminoso del encuadre y su zona se rebajaba como si fuera cielo | La matricial sigue al sujeto de su zona, o al que está enfocado en las cámaras sin autofoco, y nunca rebaja su zona ([12 §10](12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md)). El exposímetro queda a menos de 0,6 pasos del sujeto en todas las muestras |
| **1–5** (compacta) | El AF matricial enfocaba el seto si ninguno de sus nueve puntos tocaba al sujeto | Enfoca a quien esté dentro del área de sus puntos |
| **5, 22, 28** (proporción áurea) | La condición decía «Pecho en una línea áurea», pero ya se mide la cara | «Cara en una línea áurea» |
| **6** Teleobjetivo | A 135 mm no cabe el cuerpo; el encargo no decía qué encuadrar | «Con tanto tele no cabe entero: Encuadra la cara» |
| **10** Congela al corredor | El encargo decía 1/500 s; con el 70–200 sobre un corredor a 7 m hace falta 1/2000 s (1/4000 s desde unos 125 mm) | El encargo dice 1/2000 s o más rápido, y más cuanto más zoom |
| **17** Exposición clavada | Con pasos enteros era «cuestión de suerte» (a veces imposible), y el error se medía contra la luz del sujeto, no contra el exposímetro que el jugador deja en cero: clavarlo podía no bastar | El nivel se juega **siempre en tercios** (`thirds_on()`), y la condición mide la distancia al cero del exposímetro (`evidence.metered`); lo acertada que fuera la lectura ya lo puntúa la exposición |
| **18, 19** A contraluz, silueta | De cara al sol pero con el sujeto a la sombra de un árbol, el aviso era «el sol no está detrás» | Aviso propio: «tu objetivo está a la sombra: Espera a que le dé el sol». Medido: el sujeto está a contraluz entre 25 y 45 s de los 180, en 4–6 ratos, y la primera vez antes del minuto |
| **19** La silueta | Siguiendo el encargo (uno o dos pasos bajo el exposímetro) fallaba una de cada seis combinaciones, porque la matricial leía al sujeto paso y medio oscuro | Con la medición corregida, 0 de 829 |
| **23** Retrato 6×6 | A pleno sol y con película ISO 200, el exposímetro en cero pedía f/8: imposible desenfocar el fondo sin quemar la foto (la TLR acaba en 1/1000 s). Y en el tercer camino ni a f/2,8 se desenfocaba | **Hora dorada y película ISO 100** (f/4 y 1/1000 s al sol), y el sujeto solo se elige donde el objetivo puede desenfocar el fondo un paso por debajo de su máxima abertura (`subject_fits()`). El nivel 22 pasa a ser de día, para no repetir luz |
| **24** Corredor al espejo | El encargo decía «1/500 s o más rápido»; a 7 m con el 50 mm hace falta 1/1000 s | El encargo dice 1/1000 s, la más rápida de la TLR |
| **26, 27** Barrido, estela | A pleno sol las velocidades lentas quemaban la foto | Hora dorada y hora azul (apartado anterior) |
| **30** y los demás con `grande` | El sujeto podía no llenar el encuadre con el objetivo del nivel | `subject_fits()` (apartado anterior) |
| Textos de resultado | «Espera a verla caminar», «la pillaste en ello», «fotografíala»: en femenino para cualquier sujeto | Formas neutras |

### Lo que se revisó y está bien

Luz y exposición de cada nivel (EV del sujeto en sus caminos: 14,8 al sol y 11 a la sombra de día, 14,0 y 9,5 a la hora dorada, 8,1–8,6 a la hora azul, 4,4–7,3 de noche junto a las farolas): en todos hay combinación con el exposímetro en cero que cumple las condiciones, también de noche con el 50 mm f/1,4 y f/1,8 a 1/250 s e ISO 3200. Tamaño del sujeto: siempre alcanza lo pedido. Tiempos: el sujeto de «Lo que hace» está sentado antes de 25 s y se queda; el quiosco entra en la foto antes de 50 s; los corredores no paran a estirar durante su nivel. Nivel 24: el corredor más cercano es un niño que llena el 37–42 % de la altura con el 50 mm; cuesta 2–4 puntos de encuadre, sin rechazo. Nivel 20 y 30: la nota no depende de esperar bajo una farola.

Resultado: en las 30 auditorías, **todas las muestras válidas quedan al alcance del jugador por encima del mínimo** (mediana 100 en 29 niveles), y el solucionador supera 90 de 90 partidas.

