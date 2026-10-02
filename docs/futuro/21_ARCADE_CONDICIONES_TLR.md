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
| `aurea` | Proporción áurea | pecho en x = 0,382 o 0,618 (± 0,045) |
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
