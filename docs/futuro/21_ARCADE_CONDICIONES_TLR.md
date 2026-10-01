# 21 · Modo arcade, condiciones por nivel y cámara TLR

**Estado: ✅ Implementado (01-10-2026)**, encargo del usuario a partir de la especificación original del blog (blog.ganso.org/proyectos/proyecto-paparazzi.html). Sustituye a la sesión de 5 encargos: el menú queda en **Arcade**, **Sandbox** y **Academia**.

## 1. Arcade (`scripts/arcade.gd`)

- **20 niveles en 4 bloques de 5**, un encargo por nivel. Se desbloquean en orden y se pueden repetir; se guardan la mejor nota y las estrellas de cada nivel superado en `user://arcade.cfg`.
- **El nivel lo fija todo**: escenario, luz y equipo (en el sandbox se eligen en el menú). La curva va de lo automático a lo manual:

  | Bloque | Cámara | Escenarios y luz | Disparos | Tiempo | Nota mínima |
  |---|---|---|---|---|---|
  | 1 · Primeros pasos | Compacta automática | Clásico, día y hora dorada | 5 → 3 | sin límite → 90 s | 50 → 60 |
  | 2 · La réflex | Réflex AF, automática y luego manual | Clásico | 4 → 3 | 90 → 75 s | 60 → 65 |
  | 3 · Calle | Telemétrica manual (MF) | Clásico y parque grande, día, hora dorada, azul y noche | 3 → 2 | 120 → 75 s | 65 → 70 |
  | 4 · La TLR | TLR 6×6 con carrete | Clásico, día, hora dorada y azul | 3 → 1 | 90 → 45 s | 70 → 80 |

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
- `tools/arcade_solver.gd`: juega los 20 niveles solo y comprueba que **todos se pueden superar** (20/20).
- Capturas: `tools/capture_screens.gd` (`11_arcade` a `17_fin_nivel`). `--level=N` abre un nivel al arrancar.

## 5. Pendiente

Barrido (`congelado` exige congelar; el barrido sigue en [11](11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md)), insignias de [05 §3](05_DESAFIOS_Y_MODOS_JUEGO.md), condiciones de luz y de punto de interés (fuente, quiosco), sonido propio del obturador central de la TLR y la manivela animada.
