# 19 · Vida en el Parque

**Estado: ✅ Implementado (30-09-2026)**, en una sesión autónoma encargada por el usuario. Pidió gente que haga cosas (sentarse en los bancos, mirar el móvil, charlar, pasear al perro, dar de comer a las palomas), sonido ambiente, figurantes fuera de la zona jugable y rutinas sin temblequeo, **más lentas pero más naturales**, ampliando carriles si hacía falta.

Evidencias: `docs/evidencias/personajes_modelado/10_actividades.png` (posturas y objetos de mano) y `08_sentado.png`. Para capturas del parque vivo: `--advance=<s>`, `--activity=<actividad>` y `--stage=<escena>` ([TESTS_Y_VERIFICACION.md §4.1](../TESTS_Y_VERIFICACION.md)). Vídeo de todas las novedades: `./tools/capture_showcase.sh`.

---

## 1. Marcha suave y sin temblequeo

Detalle en [NAVEGACION_Y_COLISIONES.md §3](../NAVEGACION_Y_COLISIONES.md). En resumen:

- **Causa del temblequeo**: el código anterior probaba cada fotograma pasos alternativos de golpe (radial, tangencial, ±0,12 m) y recalculaba la orientación desde cero, así que dos personas que se encontraban alternaban decisiones fotograma a fotograma.
- **Ahora**: velocidades de avance y radial con aceleración limitada, un **lado de paso** elegido una vez y mantenido 3 s (quien viene de frente siempre por su derecha), seguimiento a 1,3 m de quien va más lento y orientación que gira como mucho 75°/s.
- **Más lento**: las paradas duran 6–16 s (antes 3–8), el cambio de carril espontáneo se intenta cada 25–60 s (antes 8–18) y la probabilidad de parada en un punto de interés es 0,12. Las velocidades configuradas no cambian (invariante §3.2 de AGENTS.md).
- **Carril 0 ensanchado** de [1,20; 2,40] a [1,05; 2,70] m: con el espacio personal de 0,72 m, el ancho antiguo no dejaba cruzarse a dos personas.
- `tests/test_crowd.gd` mide el temblequeo: giro máximo, inversiones laterales rápidas, separación mínima y atascos en 60 s de multitud.

## 2. Bancos, paradas y actividades

- **Bancos de dos plazas**: el viandante decide una vez por banco (probabilidad 0,4, o 0,55 si ya hay alguien sentado) si sentarse, reserva una plaza, se arrima a su borde frenando, se gira hacia el camino y se sienta en 1,3 s con cinemática inversa: los pies se quedan quietos y la cadera va atrás y abajo hasta el asiento ([PERSONAJES_Y_CINEMATICA.md §4.bis](../PERSONAJES_Y_CINEMATICA.md)). Si se sienta junto a alguien, suelen charlar girando la cabeza el uno hacia el otro. Al levantarse espera a tener hueco. Nada se teletransporta (`test_park_life.gd`: menos de 6 cm por fotograma).
- **Paradas con actividad**: se para frenando (`pending_stop`) y mira al paisaje mientras hace algo (`mirar`, `movil`, `foto`, `cafe`). Dos caminantes que se cruzan pueden **pararse a charlar** frente a frente, y se saludan con la mano al encontrarse. Los corredores se paran a veces (probabilidad 0,05 por sector) a **estirar** junto al camino.
- **Sentados**: leen el periódico, miran el móvil, toman café, echan migas a las palomas o descansan.
- **Andando**: a veces sacan el móvil y caminan más despacio mirándolo.
- **Reparto medido** en 60 s de multitud: el 79 % del tiempo caminando, el 13 % parados y el 8 % sentados (`test_crowd.gd` exige al menos un 60 % caminando).
- **Capa de actividades** (`gait.gd::activity`): tren superior mezclado con peso `act_w`; las piernas no se tocan.
- **Objetos de mano** (`person.gd::make_prop`): teléfono, periódico con texto procedural, cámara, vaso de café y bolsa de pan. Se construyen al usarse, en la mano (`BoneAttachment3D`), sin colisionadores. **El móvil ilumina la cara** con una luz pequeña sin sombras, más intensa de noche (petición del usuario durante la sesión).

## 3. El perro

`scripts/dog.gd`: cuerpo, cabeza, cola y cuatro patas de primitivas con colores de vértice, animados por código (trote diagonal, cabeceo, cola que se mueve). Va con correa a la derecha de su dueño (un viandante del carril 1, `has_dog`), olfatea cuando este se para y se tumba delante del banco si se sienta. Espanta a las palomas.

**Coherencia con la puntuación**: mide unos 45 cm, así que no cumple la regla de «por debajo de 0,3 m». Tiene un colisionador propio en la **capa 1** con la etiqueta `un_perro` (`data/textos.es.json`): los rayos de oclusión de la foto lo ven y el informe dice qué tapaba; la navegación, que usa la máscara 2, no. Existe igual en todos los perfiles, así que ninguno cambia la puntuación.

## 4. Palomas

`scripts/pigeons.gd`: dos bandadas de 9 en el anillo de césped de r = 5,1–6,0 m. Tres `MultiMesh` (cuerpo, cabeza y alas) dibujan todas las aves: 3 draw calls, unos 20.000 triángulos. Comportamiento:

- en el suelo andan a saltitos, cabecean y picotean;
- se apartan de la gente y del perro;
- cuando pasa un corredor, con probabilidad 0,3 por pasada, la bandada vuela a las copas y vuelve a los 8–16 s;
- cuando alguien echa migas desde un banco, la bandada más cercana acude a sus pies.

En el suelo miden menos de 0,3 m y no tienen colisionadores. Solo en `hd`.

## 5. Figurantes de la pradera

`scripts/extras.gd`: 15 personas en las dos aberturas de la verja (quiosco y estanque):

- paseantes en bucle, uno de ellos con perro;
- un pícnic con manta de cuadros y cesta;
- dos amigas charlando;
- un turista fotografiando el quiosco;
- gente leyendo o con el móvil sentada en la hierba;
- un niño mirando el agua;
- otro niño jugando con un balón junto al quiosco.

De noche se recogen el pícnic, el turista y el juego de balón (`extras.set_time_of_day()`), y las palomas duermen en los árboles.

Son `Pedestrian` con `ambient = true`: solo se construye la malla visual, sin colisionadores. No están en `main.people`, así que nunca son objetivo ni entran en el sorteo de rasgos. Viven más allá de r = 12,8 m. Solo en `hd`: en Android no caben en los 100.000 triángulos.

## 6. Sonido ambiente

`scripts/ambience.gd` y `tools/audio/build_ambience.py`: todo sintetizado, sin muestras de terceros. Suenan pájaros en las copas (de día; más bajos en la hora dorada), grillos de noche, la fuente en 3D junto al estanque, más el zureo de las palomas y el aleteo cuando alzan el vuelo. Detalle en [ESCENARIO_Y_RENDIMIENTO.md §3.4](../ESCENARIO_Y_RENDIMIENTO.md).

## 7. Perfiles y presupuestos

| Elemento | `hd` (escritorio, los 4 perfiles) | `lo` (Android) | Colisionador |
|---|:---:|:---:|---|
| Marcha suave, bancos, actividades, objetos de mano | ✅ | ✅ | objetos: no |
| Perro | ✅ | ✅ | capa 1, etiqueta `un_perro` |
| Palomas | ✅ | — | no |
| Figurantes | ✅ | — | no |
| Sonido ambiente | ✅ | ✅ | — |

Triángulos medidos: 3.424.785 en `hd` y 94.112 en `lo` ([TESTS_Y_VERIFICACION.md §5](../TESTS_Y_VERIFICACION.md)). Para que Android cupiera, `lo` dibuja ahora solo parte de los árboles lejanos (los colisionadores siguen todos). El presupuesto ya se pasaba (108.498) antes de esta sesión.

## 8. Criterios de aceptación y pruebas

- `tests/test_crowd.gd`: sin temblequeo ni solapes en 60 s de multitud.
- `tests/test_park_life.gd`: 21 viandantes; figurantes sin colisionadores y fuera de la zona jugable; palomas sin colisionadores; perro con colisionador fuera de la capa 2; ciclo del banco sin teletransportes; charla frente a frente; objetos de mano por actividad.
- `tests/test_gait.gd`: la postura sentada sigue cumpliendo (muslos al frente, rodillas flexionadas).
- `--smoke-test` en los dos renderizadores: presupuestos con figurantes y palomas.

## 9. Pendiente y mejoras posibles

- **Falda sentada** (hecho a medias): sus cadenas cuelgan de los muslos y con rigidez 2,6 se quedaban tiesas en horizontal al sentarse. Ahora `person.gd::update_skirt_springs()` baja la rigidez a 0,25 y sube la gravedad a 2,5 según `seat`, y la tela cae entre las rodillas. Falta un colisionador del asiento para la parte de atrás.
- ~~Migas visibles y palomas que se posan en la verja~~: hecho. Las migas ya salían de la mano (`person.gd`, objeto `migas`); desde el 02-10-2026, en el parque clásico una bandada espantada de día se queda seis de cada diez veces en la **verja** (`pigeons.gd::perch_on_fence()`, `FENCE_CHANCE`): cada paloma sobre la bola de un poste (1,21 m) o de un pilar (1,59 m) del tramo más cercano (`park.fence_perches`), mirando al parque, y al rato vuelve al césped. El resto de las veces, y siempre de noche, van a los árboles. Captura: `-- --pigeons=verja`; prueba en `test_park_life.gd`.
- ~~Gente en el mobiliario de la pradera~~: hecho el 02-10-2026. Dos amigos se sientan en la mesa de pícnic más cercana, uno en cada banco, con un café y un móvil (`extras.gd`, `PICNIC_TABLE`); de noche se van, como el pícnic de la manta. Ahora son 17 figurantes.
- Más razas de perro y algún perro con los figurantes del quiosco.
- Voces lejanas y risas de niños (difíciles de sintetizar con naturalidad; mejor con muestras CC0 si el usuario lo aprueba).
- Figurantes que entren y salgan de la escena por los caminos de la pradera.
- Que las actividades formen parte de los encargos («la persona que lee el periódico»), con cuidado de no romper el determinismo del sorteo.

## 10. Resuelto el 03-10-2026 (anotado por el usuario)

- **Personajes que se despatarraban al andar.** Causa: los pies apoyados se clavan en el suelo (para no deslizar) y, cuando el cuerpo gira mucho durante un paso (reanudar la marcha mirando a otro lado, dar media vuelta, esquivar, o un corredor arrancando en los carriles interiores con su zancada de casi 2 m), el pie apoyado quedaba muy lejos de lado: hasta 76 cm. `gait.gd::pose()` deja ahora que el pie **pivote con el cuerpo** al pasar de `SPLAY_LIMIT` (10 cm de su sitio lateral) y que la punta gire con él a partir de `TWIST_LIMIT`. En línea recta nada cambia (`test_gait.gd`: deriva 0). `test_crowd.gd` comprueba que los pies no se separan de lado más de 0,5 m (medido: 0,42).
- **Parque infantil con vida** (`extras.gd::build_playground()`, solo `hd`): un niño en un columpio que se balancea de verdad (asiento y cuerdas cuelgan de un pivote), otro que sube la escalera y baja por el tobogán en bucle, uno sentado en el arenero y tres corriendo alrededor. Son figurantes: sin colisionadores, fuera de `main.people` y de los encargos; de noche se van. El borde del arenero, que formaba una estrella, es ahora un octágono. Lo comprueba `test_big_park.gd`.
- **Falda al sentarse**: colgaba recta desde la cadera, por detrás de las piernas. Sus cadenas (hijas de los muslos) siguen ahora al muslo hasta la rodilla y el último tramo se dobla hacia abajo (`person.gd::update_skirt_springs()`, `SKIRT_BEND`), con los muelles tomando esa pose como reposo. Las cadenas de detrás de la cadera quedaban, con el muslo adelantado, *debajo* de él (dentro del asiento) y además se doblaban tras la rodilla como las delanteras, colgando en tiras por detrás de las pantorrillas: desde el 02-10-2026 su raíz sube hasta la cara inferior del muslo (`SKIRT_TUCK`) y no se doblan hacia abajo (`SKIRT_BEND_BACK`). Queda algún hilo fino entre las piernas, en la costura entre las cadenas de un muslo y del otro.
- **Correcciones del mismo día** tras probarlo el usuario: el tobogán estaba inclinado al revés (subía al alejarse de la plataforma); las farolas de la plaza quedaban delante de dos bancos (ahora van entre ellos y cualquier farola a menos de 2,2 m de un banco se descarta, `park_grande.gd::bench_spots()`); las palomas **se espantan cuando el fotógrafo camina hacia ellas** (a menos de 2,6 m) y en el parque grande se posan en **árboles reales** (`pigeons.perches`), no en el aire; el agua de las cortinas de la fuente **cae acelerando** (el patrón corre sobre `sqrt(caída) − tiempo`; antes subía despacio); y la aberración cromática y el viñeteo **solo se ven con la cámara al ojo**.
- **Colisiones (03-10-2026)**: en el parque grande ya no se atraviesa nada. Tenían colisionador árboles, bancos, farolas, fuente, quiosco y verja; faltaban los peldaños del tobogán, el asiento y las cuerdas del columpio fijo y las tablas del arenero (ahora con etiqueta, y por tanto con `StaticBody3D`), y los niños del parque infantil y el perro, que no tienen colisionador propio: el fotógrafo se aparta de ellos como de los viandantes (`main.gd::update_photographer()`). Los tres niños que corren lo hacen dentro del círculo de grava (radio 4,55–4,83 m), sin cruzar caminos ni bancos.
- **Tobogán animado a medida** (`extras.gd::update_slider()`, `gait.gd::climb()` y `slide()`): el niño sube los cinco peldaños de uno en uno (un pie y luego el otro en cada peldaño, a 0,3 m), con cada mano agarrando un peldaño tres por encima de los pies (cinemática inversa de dos huesos en el brazo); al acabarse los peldaños apoya las manos en el borde de la plataforma y se alza; la cruza andando; se sienta en la boca de la rampa; baja sentado y pegado a ella (62 % de pendiente, acelerando) y se levanta al final para dar la vuelta. La plataforma se acortó hasta la escalera (antes volaba sobre ella y la cabeza la atravesaba). `tools/capture_slide.gd` graba el bucle en vista lateral; `test_big_park.gd` comprueba que no se separa de la rampa más de 5 cm.
