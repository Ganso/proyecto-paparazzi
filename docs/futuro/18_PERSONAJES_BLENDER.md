# Paso 3 · Personajes y Ropa Modelados en Blender

**Estado: ✅ Implementado y revisado por el usuario (30-09-2026).** Quedan las mejoras opcionales de §5. Evidencias en [`docs/evidencias/personajes_modelado/`](../evidencias/personajes_modelado/) (estado actual) y [`antes/`](../evidencias/personajes_modelado/antes/) (catálogo anterior), generadas con `tools/capture_characters.gd`.

## 1. Decisiones del usuario
- **Pesos suaves en la ropa** (2–4 huesos por vértice): la madera del maniquí sigue rígida, un hueso por pieza; ropa, pelo y accesorios se doblan en las articulaciones. Sustituye al invariante «pesos rígidos» de AGENTS.md §3.2 solo para ropa y pelo.
- **Modelado por script en Blender** (`tools/blender/build_characters.py`), como el parque.
- **Rediseño libre**: no hay que heredar el modelo anterior. Solo el cuerpo es de madera; el pelo es una **peluca** de mechones y la ropa es tela.
- Se mantienen el esqueleto de 20 huesos (posiciones de `person.gd::make_rig()`), las zonas de color, los rasgos con nombre, el casting y la ética.

## 2. Arquitectura
- `build_characters.py` escribe `data/piezas_hd/<perfil>_<ranura>_<índice>.json` con formas `"skinned"`: vértices en espacio de modelo, normales suaves (subdivisión Catmull-Clark aplicada), índices en el sentido de Godot y `bone_names`/`joints`/`weights` (hasta 4 por vértice).
- Pesos: la madera y el calzado van a un hueso; la ropa, por distancia inversa a los segmentos de los huesos candidatos (`smooth_weights()`); la falda, con una regla propia que sigue a la cadera arriba y a los muslos hacia el bajo.
- Las prendas declaran `"hides"`: partes del cuerpo que tapan y que `person.gd` no dibuja, para que la madera rígida no asome por la tela que se dobla.
- `person.gd::build_skinned_mesh()` monta estas formas; los colisionadores siguen saliendo de `data/piezas/` (pasada `collision`), así que la puntuación no cambia.
- Uso: `blender -b --factory-startup -P tools/blender/build_characters.py -- [--only estandar] [--slots torso,cabeza]` (2 s los cuatro perfiles).

## 3. Contenido de esta iteración
| Parte | Antes | Ahora |
|---|---|---|
| Maniquí | Tubos finos, cuello largo | Pelvis, abdomen y pecho torneados, cintura articulada, bíceps y gemelos, manos con pulgar, rótulas encajadas, cuello más grueso y barbilla por delante |
| Torsos | Un tubo con solapas pintadas | Holgura por prenda, hombros caídos, dobladillos con grosor, cuello de camisa con puntas, tapeta, botones y bolsillo; americana con solapas con grosor, escote en V con camisa y carteras; sudadera con capucha abierta, cordones, bolsillo canguro y puños |
| Piernas | Perneras cortadas en la rodilla | Culera y perneras continuas que se doblan, cinturón, raya del pantalón de vestir, franja lateral deportiva, falda con vuelo y pliegues que sigue a los muslos |
| Pelo | Casco con borde escalonado | Peluca de mechones en cintas sobre una base, línea del pelo continua, flequillo con puntas, melena que cae recta, coleta con goma |
| Tocados | Chistera, gorro plano | Fedora con copa hendida, cinta y ala curvada; gorra con visera con grosor; gorro con vuelta de canalé y pompón |
| Calzado | Cuña | Zapato con puntera y suela |

## 3.1 Movimiento de tela y pelo (segunda iteración)
- **Huesos secundarios con muelles** (`SpringBoneSimulator3D`, nativo desde Godot 4.4): las piezas `hd` declaran `"chains"` (cadenas de huesos) que `person.gd::add_secondary_chains()` añade tras los 20 huesos del rig, y `build_spring_simulator()` las hace oscilar con inercia, rigidez, arrastre y gravedad propios. Colisionan con cápsulas en muslos, piernas, tórax y cabeza.
  - **Falda**: 8 cadenas colgadas de los muslos; se balancea al andar, ondea al pararse y al sentarse queda sobre el regazo.
  - **Melena**: 7 cadenas desde la altura de las orejas. **Coleta**: una cadena. **Bufanda**: dos cadenas en las colas. **Bandolera**: el bolso pende de una cadena.
  - Los 20 huesos universales no cambian (`primary_bone_count`); la marcha y la puntuación no ven los secundarios.
- **Caída de tela simulada en Blender** (modificador Cloth, gravedad en −y, cuerpo de madera como colisionador): la falda evasé se asienta sobre la cadera con pliegues naturales en el bajo (`Piece.drape`).
- **Arrugas modeladas** (`wrinkles()` sobre anillos densificados): pliegues del codo por delante, tela acumulada sobre el puño, pliegue tras la rodilla, quiebre del pantalón sobre el zapato y tela ahuecada sobre el cinturón.
- `tools/capture_characters.gd` añade `09_dinamica` (andar y pararse en seco) y deja reposar los muelles antes de cada vista.

## 3.1.1 Correcciones tras la prueba del usuario (30-09-2026)
- **Camisas con «donut» y bajo que se hinchaba**: el tronco de la prenda tomaba peso de los antebrazos, que cuelgan junto a la cadera, y el bajo se estiraba al balancear los brazos. Ahora el tronco solo usa huesos del torso (`TOP_BONES`) y cada manga es una pieza con los huesos de su brazo (`ARM_BONES`). También se redujeron la holgura sobre el pantalón y la arruga del bajo, y el dobladillo usa los mismos 16 lados que el tronco.
- **Pantalones que se salían del cuerpo al andar**: las perneras repartían peso por distancia entre ambas piernas y la pelvis. `pants_weights()` asigna cada pernera a su pierna (muslo y pierna fundidos en la rodilla) y solo mezcla con la pelvis en la cadera y la entrepierna.
- Silueta de las prendas de arriba en V suave: pecho y hombros más anchos que la cintura.
- **Manga corta sin antebrazo**: la prenda ocultaba todo el brazo de madera aunque la manga acabara antes del codo. Ahora el brazo solo se oculta si la manga lo cubre entero (`top_hides()`).
- **Bolso atravesado por brazo y cuerpo**: la bandolera lleva ahora un tote fino (2,6 cm) con asas, colgado plano en el costado derecho de la cadera. Quien lo lleva separa un poco ese brazo del cuerpo (`person.gd::arm_out`, 0,2 rad en reposo y al andar, que `gait.gd` aplica), así que la mano pasa por fuera del bolso. Con falda se usa una variante corta (`<perfil>_accesorio_2_falda.json`, elegida por `person.gd`): el bolso va a la altura de la cintura, por encima del vuelo. La correa va pegada a una camiseta normal: separarla para las prendas holgadas la dejaba flotando alrededor del cuerpo, y el usuario prefiere el roce ocasional.
- **Transparentes borrados en Ultra**: el pase de profundidad de campo copiaba la imagen opaca y se dibujaba el último, así que tapaba vidrio, agua en movimiento y nubes. Ahora va primero en el pase transparente (`render_priority = -128`).

## 3.2 Evaluación de herramientas existentes
| Herramienta | Qué ofrece | Decisión |
|---|---|---|
| `SpringBoneSimulator3D` (Godot 4.4+) | Oscilación inercial de cadenas de huesos con colisiones propias, pensada para pelo, ropa y colas | **Adoptada** para pelo, falda, bufanda y bolso: barata (no usa el servidor de física) y estable con 21 personajes |
| `SoftBody3D` (Godot) | Tela física real por vértice | Descartada: no sigue bien una malla con esqueleto, es inestable y cara con 21 personajes |
| Modificador Cloth de Blender | Simulación de tela offline | **Adoptado** para asentar prendas holgadas (falda) sobre el cuerpo; se exporta la forma resultante |
| MPFB2 / MakeHuman (Blender, CC0) | Personajes humanos y un catálogo de ropa y pelo CC0 | Descartado por ahora: topología de cuerpo humano realista, no de maniquí articulado; adaptar su ropa al esqueleto de 20 huesos costaría más que generarla. Útil como referencia de patrones |
| Cloth Weaver, Garment Tool, Simply Cloth (Blender, de pago) | Patronaje y costura de prendas | Descartados: de pago y pensados para uso interactivo, no para generar el catálogo por script |
| Marvelous Designer | Patronaje profesional | Descartado: propietario, no automatizable en este proceso |

## 4. Presupuesto
Hasta **60.000 triángulos por maniquí** en `hd` (máximo en escena: 41.372; las arrugas densifican las prendas). Rendimiento sin medir en esta iteración (la GPU estaba ocupada con otro proceso).

## 5. Pendiente (opcional)
- Correa de la bandolera adaptada a cada prenda de arriba (hoy roza las holgadas), como ya se hace con la variante para faldas.
- Torso aún algo tubular: pecho y espalda con más forma, pliegues de tela en codos y cintura.
- Falda sentada: el bajo delantero cae en diagonal sobre las rodillas; afinar rigidez y longitud.
- Simular también la caída de americana, sudadera y pantalones (hoy solo la falda) y añadir cadena a la capucha.
- Bandolera: la correa debe apoyarse mejor sobre el pecho.
- Revisar los perfiles delgado, robusto y niño con zoom.
- Nivel `lo` (Android) sigue con el catálogo antiguo.

## Muelles de falda, pelo y bolso reajustados (02-10-2026)

Al andar, la falda, la melena y la coleta se quedaban **tendidas hacia atrás casi en horizontal**, como una bandera, y solo caían al parar: el `drag` del `SpringBoneSimulator3D` actúa contra el aire (cuanto mayor, más se rezaga la cadena respecto de quien la lleva) y las piezas traían mucho rozamiento y casi nada de peso. `person.gd::SPRING_TUNING` fija ahora, por tipo de cadena, `[rigidez, rozamiento, gravedad]`: falda `[3,4 · 0,12 · 1,6]`, melena `[1,8 · 0,15 · 1,3]`, coleta `[1,4 · 0,12 · 1,5]`, bufanda `[1,8 · 0,15 · 1,0]` y bolso `[3,0 · 0,2 · 1,2]` (las piezas de Blender no se regeneran: los valores se aplican al montar el simulador). Tela y pelo cuelgan, oscilan con cada paso y se asientan.

Sentada, la falda necesita lo contrario —mantener la pose que se le da sobre el regazo y bajo los muslos—, así que `update_skirt_springs()` lleva sus muelles a `SKIRT_SEATED` (`[9,0 · 0,5 · 0,1]`) según se sienta. Hojas `08_sentado` y `09_dinamica` regeneradas. Queda un hilo fino entre las piernas al sentarse y algún pico en el bajo al arrancar a andar.

## Americana que parece americana y ropa de niños (03-10-2026, usuario)

- **La americana se leía como una sudadera**: las solapas eran del color del paño y el escote, un triángulo plano que se hundía en el pecho. Ahora (`build_torso`, estilo `lapel`) va **abierta en V hasta el botón con la camisa blanca a la vista**, puntas de cuello, **solapas de muesca** más oscuras, el canto del delantero, dos botones grandes, **pañuelo en el bolsillo del pecho** y carteras. Todo con `patch()`, placas con grosor que siguen la curva del pecho. Se regenera con `blender -b --factory-startup -P tools/blender/build_characters.py -- --slots torso`.
- **Los niños llevan ropa de niños**: las piezas marcadas `"solo_adultos": true` en `data/catalogo.json` (americana, pantalón de vestir, sombrero de ala) no se le dan al perfil `nino` (`casting.gd::generate()`), y un niño no lee el periódico, ni toma café ni lleva cámara (`person.gd::CHILD_ACTIVITY`: se queda mirando). Lo comprueba `tests/test_art.gd`. Una prenda nueva solo de adultos lleva esa marca.
