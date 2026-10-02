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
- Migas visibles (partículas) al echar de comer y palomas que se posan en la verja.
- Más razas de perro y algún perro con los figurantes del quiosco.
- Voces lejanas y risas de niños (difíciles de sintetizar con naturalidad; mejor con muestras CC0 si el usuario lo aprueba).
- Figurantes que entren y salgan de la escena por los caminos de la pradera.
- Que las actividades formen parte de los encargos («la persona que lee el periódico»), con cuidado de no romper el determinismo del sorteo.

## Pendientes anotados por el usuario (03-10-2026)

- **Personajes que se despatarran de repente al andar**: algunos viandantes abren las piernas de golpe mientras caminan. Sin diagnosticar. Sospechas por orden: la mezcla de la marcha que ahora espera 0,6 s parado antes de apagarse (`gait.gd::pose()`, `idle_time`, del 01-10-2026), el `reset_contacts()` cuando la posición salta más de 0,7 zancadas y el ritmo reducido de los niveles manuales (`walk_pace`), que alarga el tiempo de apoyo.
- **Parque infantil con vida**: en el parque grande, que haya siempre algún niño jugando en los columpios o el tobogán y niños dando vueltas cerca (hoy la zona suele estar vacía). Encaja con los figurantes de `scripts/extras.gd`.
