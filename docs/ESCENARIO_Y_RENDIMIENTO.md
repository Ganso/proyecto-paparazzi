# Escenario Cilíndrico, Clima y Presupuestos de Rendimiento — PhotoHacks

Este documento describe la arquitectura geométrica del parque procedural, la iluminación dinámica, el sistema meteorológico de nubes y los presupuestos de rendimiento por perfil documentados en [scripts/park.gd](../scripts/park.gd).

> [!IMPORTANT]
> **Salto gráfico (2026-09-29/30, [futuro/17](futuro/17_SALTO_GRAFICO_ULTRA.md))**: el mobiliario, la vegetación, el quiosco, el estanque y las torres se generan con Blender por script (`tools/blender/build_park_assets.py`) en dos niveles de detalle: `hd` para Ultra (Forward+) y `lo` para Bajo, Medio y Alto. Los **colisionadores no cambian con el perfil**: siguen siendo las primitivas de siempre, sin malla visible, o se sacan de la malla `lo`. La peana de diorama se eliminó y el parque se abre a una pradera.

---

> **Dos escenarios** (01-10-2026): este documento describe el **parque clásico**, cilíndrico y centrado en el fotógrafo. El **parque grande**, de paseo libre, reutiliza su entorno, su luz y sus modelos con otra disposición: [futuro/01 §6](futuro/01_MAPA_ABIERTO_Y_PROTAGONISTA.md).

## 1. Disposición Cilíndrica del Parque

El escenario es un parque urbano procedural concéntrico de $45\text{ m}$ de radio modelado en coordenadas cilíndricas $(r, \theta)$ con la cámara del jugador situada en el centro exacto $(0, 1.60\text{ m}, 0)$.

```
+-------------------------------------------------------------------------------+
|                       ESTRUCTURA RADIAL DEL PARQUE                            |
+-------------------------------------------------------------------------------+
  r = 0.0 m          [CÁMARA DEL JUGADOR] y = 1.60 m
  r = 0.0 - 2.8 m    Plaza central de losas (textura en hd)
  r = 1.2 - 2.4 m    CARRIL 0: Paseo circular interior (3 viandantes)
  r = 2.6 m          Farolas interiores (4 unidades), entre los carriles 0 y 1
  r = 2.9 - 4.85 m   CARRIL 1: Paseo de asfalto (7 viandantes)
  r = 4.85 m         4 Bancos de listones con bastidores de fundición, orientados al centro
  r = 5.55 m         Papeleras de chapa
  r = 6.1 - 7.9 m    CARRIL 2: Paseo de adoquín (6 viandantes)
  r = 8.6 m          Farolas exteriores (8 unidades)
  r = 9.2 m          Arbustos interiores decorativos (70 unidades)
  r = 9.7 m          Jardineras de tablones con flores
  r = 10.6 - 12.4 m  CARRIL 3: Paseo perimetral de grava (5 viandantes)
  r = 2.8 ... 12.5   Bordillos de piedra entre paseos y césped (hd)
  r = 12.8 m         Verja de lanzas con pilares de piedra cada 30°; abierta ante quiosco y estanque
  ------------------ LÍMITE DE LA ZONA JUGABLE ---------------------------------
  r = 13.4 m         Seto perimetral (84 arbustos, sin arbustos en las dos aperturas)
  r = 14.2 m         Arbolado primario (30 posiciones, sin árboles en las dos aperturas)
  r = 18.5 - 36 m    PRADERA: 44 árboles sueltos y matas; quiosco (120°, 24 m) y estanque (245°, 21 m)
  r = 39 - 44 m      Franja de arbolado lejano (60 árboles)
  r = 46 - 52 m      Segunda franja (54 árboles) y matas de pradera: solo se dibujan en hd
  r = 50 - 200 m     Calles de la ciudad (asfalto)
  r = 110 - 160 m    Horizonte de 30 torres escalonadas con ventanas (iluminadas de noche en hd)
```

## 2. Vegetación, Pradera y Agua

### 2.1 Árboles y arbustos de Blender
- **4 especies por gramática** (`SPECIES` en `tools/blender/build_park_assets.py`), con **4 variantes** cada una: plátano (copa ancha), tilo (copa globosa), ciprés (huso de racimos apilados) y arce otoñal (oro y ámbar). Fuste curvo con cuello radicular, ramas en dos niveles (el segundo solo en `hd`) y racimos de follaje en las puntas: icosferas deformadas por ruido, más claras arriba y hacia fuera, con la oclusión ambiental horneada por Cycles.
- `park.gd::build_tree()` conserva la variación por semilla (giro, inclinación y escala) y elige la variante con `semilla % 4`. Los **colisionadores** (tronco y copa, etiquetas `un_arbol` y `una_copa_de_arbol`) salen de la envolvente convexa de la malla `lo`, idéntica en todos los perfiles.
- **Arbustos**: 6 variantes de radio 1, escaladas al elipsoide de siempre (`park.gd::bush()`), cuyo colisionador se mantiene.
- Triángulos por árbol: ~2.500–4.000 en `hd` y ~150–300 en `lo`. En `lo` (Android) solo se dibujan uno de cada tres árboles de la franja lejana y uno de cada cuatro de los sueltos de la pradera; los colisionadores están todos en cualquier perfil.

### 2.2 Pradera exterior (fuera de la zona jugable)
- **Mobiliario (02-10-2026)**: dos mesas de pícnic de tablones con sus bancos y una papelera a la izquierda del quiosco (`park.gd::MEADOW_TABLES`, θ ≈ 103–107°, r = 18–21,5 m, fuera del círculo por el que pasean los figurantes) y una fuente de beber de fundición camino del estanque (`MEADOW_TAP`, θ = 229°). Modeladas por código (`build_mesa_picnic`, `build_fuente_beber` en `tools/blender/build_park_assets.py`; se regeneran con `--only mesa_picnic,fuente_beber`). Solo se dibujan en `hd` y no tienen colisionador: están más allá de la verja. Comprobado en `test_park_life.gd`.
- **Quiosco de música** octogonal (Ø 4,6 m): gradas, columnas torneadas, barandilla de balaustres, tejado con nervios y remate. De noche y en hora dorada se encienden una guirnalda de bombillas bajo el alero y un farol central (`meadow_lights`).
- **Estanque** elíptico (7 × 4,6 m) con borde bajo de piedra y **fuente** de dos tazas. Tres farolas detrás lo iluminan en hora dorada y de noche.
- **Agua animada**: `shaders/park_water.gdshader` (ondulación de ruido que se desplaza, ondas concéntricas donde cae la cortina, espuma y color según el ángulo; en Ultra refleja por SSR) y `shaders/park_spray.gdshader` (surtidor que sube y cortinas que caen como hilos translúcidos con destellos).
- Las luces de la pradera no están en `lamps`: `illumination_ev()` no las ve y, a más de 20 m de los carriles, tampoco iluminan a los viandantes.
- **Verja abierta** ante el quiosco y el estanque: faltan tres tramos (±7,5°) y un pilar marca cada lado.
- **Torres** (6 estilos, `TOWER_STYLES`): volúmenes escalonados con remate; en `hd`, ventanas en `shaders/park_windows.gdshader`, que enciende de noche una de cada tres.

### 2.2.bis Vida en la pradera y en el parque (desde el 30-09-2026)
Detalle en [futuro/19_VIDA_EN_EL_PARQUE.md](futuro/19_VIDA_EN_EL_PARQUE.md). Resumen:
- **Figurantes** (`scripts/extras.gd`, solo `hd`): 15 personas en las dos aberturas de la verja. Pasean alrededor del quiosco y del estanque (una de ellas con perro), hacen un pícnic con manta de cuadros y cesta, charlan, hacen fotos al quiosco, leen o miran el móvil sentadas en la hierba, hay un niño mirando el agua y otro jugando con un balón. De noche se recogen el pícnic, el turista y el juego de balón, y las palomas duermen en los árboles. Viven más allá de $r = 12.8\text{ m}$, **no tienen colisionadores** y no están en `main.people`: nunca son objetivo ni tapan una foto a efectos de puntuación.
- **Palomas** (`scripts/pigeons.gd`, solo `hd`): dos bandadas de 9 en el anillo de césped de $r = 5.1$–$6.0\text{ m}$, dibujadas con 3 `MultiMesh` (cuerpo, cabeza y alas: 3 draw calls). Picotean, cabecean, se apartan a saltitos de la gente y del perro, a veces (probabilidad 0,3 por paso) huyen volando a los árboles cuando pasa un corredor y vuelven al cabo de 8–16 s, y acuden a quien les echa migas desde un banco. Miden menos de 0,3 m en el suelo y no tienen colisionadores.
- **Perro** (`scripts/dog.gd`): un viandante del carril 1 lo pasea con correa. Tiene colisionador en la capa 1 con la etiqueta `un_perro`, para que tape en las fotos lo que tapa en pantalla; la navegación (máscara 2) no lo ve.
- **Sonido ambiente** (`scripts/ambience.gd`): ver §3.4.
- En `lo` (Android) no hay figurantes ni palomas, para no pasar de 100.000 triángulos; el perro sí está.

### 2.3 Suelo y césped (hd)
- **Suelo texturizado** (`shaders/park_ground.gdshader`): losas en la plaza, asfalto, adoquín y grava en los paseos y césped, con texturas periódicas generadas por `tools/texturas/build_textures.py` (color, normal y ORM de 2048 px, `Texture2DArray`), mapeadas en coordenadas del mundo y con una segunda muestra girada para romper la repetición. El alfa del color de vértice elige la capa y el RGB conserva la oclusión de contacto.
- **Bordillos de piedra** biselados (6 cm) en los bordes de los paseos (`park.gd::curb()`).
- **Hierba instanciada** (`park.gd::build_grass()`, `shaders/park_grass.gdshader`): matas de cinco briznas de 6–14 cm en `MultiMeshInstance3D` por sector, más densas cerca (110 matas/m² hasta 11 m y 4 más allá de 35 m), fuera de paseos, estanque y quiosco. Se mecen con ráfagas que recorren el parque. Por debajo de 0,3 m y sin colisionador (regla de [02 §10.3](futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md)).
- En `lo` el suelo mantiene los colores de vértice planos y no hay hierba instanciada.

---

## 3. Iluminación y Clima Procedural

### 3.1 Iluminación y Horas del Día: Día, Hora Dorada y Noche (`park.set_time_of_day()`)
- **Perfiles**: los cuatro de escritorio usan Forward+ y comparten aspecto; Alto, Medio y Bajo solo quitan coste (tabla en [futuro/17 §2.4](futuro/17_SALTO_GRAFICO_ULTRA.md)). Bajo, sin SDFGI, calibra la luz ambiente por hora (`NO_GI_AMBIENT`) para mantener la exposición de Ultra; lo mismo ocurre en cualquier perfil con GPU integrada, donde SDFGI se desactiva (`park.gd::sdfgi_cascades()`, [futuro/17 §2.4](futuro/17_SALTO_GRAFICO_ULTRA.md)).
- **Ultra (Forward+)**: SDFGI (energía 0,7 y rebote 0,25, para que el césped no tiña de verde las superficies claras), SSAO, SSIL, SSR, niebla volumétrica ligera (densidad 0,0022), glow (umbral 1,4), sombras del sol de 4096 con penumbra (`light_angular_distance`) y MSAA 4×, todo en `park.gd::apply_forward_effects()`. Los colores de vértice se leen como sRGB (en los perfiles `lo` se siguen usando como lineales, el aspecto para el que está ajustada su luz).
- **Gradación de color por hora** (Alto y Ultra, `park.gd::grading_lut()`): LUT 3D de 33³ generada por código y aplicada en `Environment.adjustment_color_correction`. Día: sombras frías y luces cálidas; hora dorada: sombras verde azuladas y violáceas con luces ámbar; noche: sombras azules, luz de farola cálida y algo menos de saturación.
- **Día**:
  - Sol cenital (`DirectionalLight3D`, pitch $-72^\circ$): `light_energy = 1.4`, color cálido `fff0d7`.
  - Sombras dinámicas ortogonales activadas con atlas de 2048, nítidas y pegadas a los pies: `shadow_blur` 0,6–0,8 y `shadow_normal_bias` 0,6–0,7 según el perfil (`apply_preset_values()`).
  - Cielo celeste (`6fa3cf` en el cenit, `dce8ea` en el horizonte) y luz ambiental difusa (`c6d6df`, energía 0.22, tomada del cielo).
  - Farolas ocultas (`visible = false`): en `gl_compatibility`, una luz a energía 0 seguiría costando un pase de dibujo por objeto.
  - Luz incidente: **$EV \approx 14.8$** al sol y **$EV = 11.0$** en sombra (detalle en [SIMULACION_FOTOGRAFICA.md §2.2](SIMULACION_FOTOGRAFICA.md)).
- **Hora Dorada (Golden Hour)**:
  - **Sol rasante bajo en el horizonte** (pitch $-15^\circ$, azimut $-48^\circ$): proyecta sombras largas, dramáticas y oblicuas que atraviesan los paseos circulares y acentúan el volumen y relieve de los maniquíes.
  - **Luz solar ámbar dorado intensa**: `light_color = Color("ffa544")`, `light_energy = 2.6`, ambiente 0,7 y exposición ×1,2 (más luminosa desde el 30-09-2026; el fotómetro no cambia), con la misma penumbra del perfil.
  - **Gradiente de cielo crepuscular**: cenit azul índigo profundo (`18355e`), horizonte naranja resplandeciente (`ed8234`) y suelo reflectante ambarino (`b55e24`).
  - **Ambiente y niebla dorada**: contraste cromático con ambiente de cielo azul claro (`9aaed0`, energía 0.55, tomado de su color y no del cielo) y neblina de profundidad dorada difusa (`e58b3e`).
  - **Encendido crepuscular de farolas**: filamentos incandescentes encendiéndose con luz cálida suave (`light_energy = 0.90`, `ffcb74`), sin sombras.
  - **Nubes melocotón dorado**: cúmulos al atardecer (`f09e60`).
  - Luz incidente: **$EV \approx 14.0$** a pleno sol rasante y **$EV \approx 9.6$** en las sombras proyectadas.
- **Noche**:
  - Luna fría: el sol queda como luz lunar (`MOONLIGHT = 0.32`, tinte `9caed4`). `illumination_ev()` no lo usa de noche, así que no altera el fotómetro.
  - Ambiente de su color (`394568`, energía 0.42), bruma azul cercana (4–34 m), exposición ×1,25 y `tonemap_white = 4` aplicados tras el perfil gráfico: el parque se lee fuera del cono de las farolas sin reventar los blancos bajo ellas.
  - Sombras de farola según el perfil (`update_lamp_shadows()`): Ultra las 12, Alto las 4 interiores y Medio y Bajo ninguna. Cada una cuesta unos 100 draw calls por fotograma.
  - 12 farolas ornamentales de fundición de hierro con pedestal moldurado, 4 paneles de cristal transparente (`TRANSPARENCY_ALPHA`), bombilla con filamento incandescente de emisión activa y luminarias omnidireccionales cálidas (`ffcd82`, radio de alcance $6.0\text{ m}$) que proyectan sombras directas (`light_energy = 2.2`).
  - Luz incidente: **$EV = 2.0$** lejos de farolas; bajo farola $\approx 8.4$ a 1 m, $5.2$ a 3 m y $2.9$ a 5 m.

**Hora azul** (`set_time_of_day("blue")`, 01-10-2026): el sol bajo el horizonte; la luz viene de todo el cielo, fría y sin sombras duras (`sun.shadow_enabled = false`, un sol cenital tenue y azulado y ambiente `7f93c4`), cielo de `142553` a `7d8fbf` con un resto cálido en el horizonte, farolas, guirnalda del quiosco y el 75 % de las ventanas encendidas, exposición del tonemap ×1,7 y LUT propia (sombras azules, luces cálidas). Exposímetro: cielo EV 9, escena unos EV 8 más las farolas (`illumination_ev()`). Pájaros a −14 dB y grillos empezando (−8 dB); las pantallas de los móviles brillan al 80 %. Se elige en el inicio («Hora azul») y en el sandbox.

### 3.2 Sistema Meteorológico de Nubes
El parque cuenta con un sistema de nubes procedurales cúbicas de baja altura:
- **Ciclo de 45 s** (`park.gd`, `WEATHER_CYCLE`, `weather_time`): un frente pasa de vez en cuando; `cloud_cover` sube de 0 a 1 entre los segundos 6,0 y 6,5 del ciclo, se mantiene hasta el 8,5 y baja a 0 entre el 8,5 y el 9,0 (antes, cada 18 s y durante 6 s). El frente no se dibuja: solo oscurece la luz del sol y el fotómetro (las nubes cercanas parecían misiles bajo el cielo).
- **Nubes lejanas** (`build_sky_clouds()`): 16 cúmulos a 170–260 m y 85–135 m de altura que giran despacio alrededor del parque (0,35°/s), fuera de la niebla y teñidos por la hora. Son decorativas: no tapan el sol ni afectan al fotómetro.
- **Atenuación**: la transmisión solar pasa de 1.0 a 0.09 (`sun_transmission()`, −3.5 EV en la luz directa). En un punto al sol la luz incidente baja de $EV \approx 14.8$ a $\approx 12.1$ (−2.7 EV), porque la componente ambiental ($EV = 11$) no cambia.
- **Afectación dual**: La nube oscurece tanto la imagen renderizada en el Viewport como la lectura del exposímetro fotográfico en tiempo real, obligando al jugador a compensar la apertura o la velocidad sobre la marcha.

---

### 3.3 Perspectiva Aérea y Niebla de Profundidad (Atmospheric Depth Fog)
Para evitar el ruido visual y el apiñamiento de planos entre viandantes y masa vegetal de fondo:
- **Niebla de profundidad moderada (`Environment.fog_mode = FOG_MODE_DEPTH`)**, fijada solo por el perfil gráfico (`park.gd::apply_preset_values()`):
  - Con la pradera abierta: Ultra de 30 a 220 m (curva 1,4), Alto de 25 a 140 m y Medio de 25 a 150 m; de noche, de 15 a 120 m. Bajo, sin niebla. Sin los objetos de Blender se usan los valores anteriores (de 8 a 40 m). `fog_sky_affect = 0.3` para que el cielo siga azul.
  - Los carriles conservan contraste y color casi íntegros, y el arbolado y el skyline ganan bruma. Antes era un muro de 7 a 20 m que blanqueaba el parque desde el carril 2; una versión casi sin niebla (4–110 m) dejaba la imagen plana.
  - Tono del horizonte: `cddcdd` de día, `e58b3e` en hora dorada y `192139` de noche (de noche, bruma de 4 a 34 m).
- **Mapeo de tonos HDR / ACES (`tonemap_mode = TONE_MAPPER_ACES`, `tonemap_white = 1.4` y ajustes de contraste)**: Curva cinematográfica de compresión de altas luces.
- **Atenuación adaptativa de tinta y tintado armónico (`cel_outline.gdshader`)**: El contorno exterior de los maniquíes disminuye progresivamente su grosor mediante una curva cúbica suave (`smoothstep`) entre 6,5 m y 17,5 m para no saturar con líneas negras los planos lejanos, incorporando modulación armónica sobre el color de vértice (`tint_strength`) y sesgo de profundidad anti-intersección (`depth_bias`).

---

### 3.4 Sonido ambiente (`scripts/ambience.gd`)
Todo sintetizado por `tools/audio/build_ambience.py` (numpy y scipy, sin muestras de terceros) en `assets/audio/ambiente/` (WAV mono de 16 bits y 22,05 kHz, 2,5 MB), cargado en tiempo de ejecución con `AudioStreamWAV.load_from_file()` y exportado en el APK (`include_filter`).

| Sonido | Fuente | Cuándo |
|---|---|---|
| `pajaros.wav` (carbonero, mirlo, petirrojo, gorrión) | 4 `AudioStreamPlayer3D` en las copas, a $r = 15\text{ m}$ y 5 m de altura, con tonos algo distintos | de día; −5 dB en la hora dorada; apagados de noche |
| `grillos.wav` | 3 fuentes 3D entre los setos ($r = 10.5\text{ m}$) | solo de noche |
| `fuente.wav` | 3D en el estanque | siempre (se oye más al mirar hacia él) |
| `zureo.wav`, `aleteo.wav` | 3D en cada bandada | zureo cada 3–10 s en el suelo; aleteo al alzar el vuelo |

Los cambios de hora funden los volúmenes a 20 dB/s. Nivel medido en una grabación de día: −31 dB de media y −14 dB de pico. El viento y el rumor de ciudad que sonaban siempre de fondo se quitaron el 01-10-2026: el usuario los encontraba muy molestos.

---

### 3.3 Cielo (`shaders/park_sky.gdshader`)
Desde el 02-10-2026 el cielo es un shader propio (antes, el `ProceduralSkyMaterial` del motor), con el mismo degradado vertical y el mismo sol, y lo que a aquel le faltaba:
- **Noche**: estrellas (rejilla de celdas con posición, tamaño, brillo y tinte por hash, que se apagan hacia el horizonte) y **luna** con sus mares y un halo tenue. La luna se dibuja a 34° de altura en el mismo acimut que la luz que proyecta (que sigue a 72°): así las sombras apuntan hacia donde deben y el fotógrafo puede verla (θ ≈ 215°).
- **Cirros altos**: vetas de ruido estiradas en un plano lejano, teñidas por la hora y más claras cerca del sol.
- **Resplandor de poniente** en la hora dorada y en la azul: una banda cálida baja sobre el horizonte, hacia el acimut por donde se pone el sol.
- Los colores por hora se fijan en `park.gd::set_time_of_day()` (`sky_extras()` para luna, estrellas, cirros y resplandor). El shader no usa `TIME`: la radiancia del cielo se calcula una vez por hora del día, no en cada fotograma. Funciona igual en `gl_compatibility`.
- Las nubes lejanas de noche se aclararon (antes eran manchas negras). Nada de esto toca el fotómetro ni la puntuación (`sky_ev()` es analítico). Comprobado en `test_game.gd`.

## 4. Parque Fusionado y Oclusión Horneada (`merge_static_meshes`)

Implementado en el paso 1 de la hoja de ruta ([futuro/16](futuro/16_PARQUE_ILUSTRADO_QUICK_WIN.md)), que detalla parámetros, resultados y comparativas. Desde el salto gráfico ([futuro/17](futuro/17_SALTO_GRAFICO_ULTRA.md)):
- Los objetos de Blender entran en la fusión con su color y oclusión ya horneados (`meta baked`); `ParkAssets` (`scripts/park_assets.gd`) lee los `.glb` en tiempo de ejecución con `GLTFDocument` y convierte solo el nivel de detalle pedido.
- Materiales propios fuera de los sectores: vidrio, bombillas, agua, agua en movimiento y ventanas. En `hd` el suelo forma 36 sectores más con su material texturizado (≤ 80 superficies en total).
- Las primitivas etiquetadas de siempre se crean en modo `collider_only`: conservan su `StaticBody3D` y no dibujan nada.
- **Fusión**: al arrancar, los props opacos (suelo, verjas, farolas, bancos, jardineras, edificios y los **280 elementos vegetales**) se transforman a coordenadas de mundo y se combinan en **36 superficies** (12 sectores de 30° × 3 bandas radiales: 0–9, 9–17 y 17–45 m), que conservan el recorte por frustum. El vidrio y las bombillas de las farolas mantienen su material: **38 superficies en total** (antes 692).
- **Material**: un único `StandardMaterial3D` con `vertex_color_use_as_albedo` (`park.gd::vertex_color_material()`), con el mismo sombreado suave de antes: el parque no lleva toon ni contorno, que son propios de los maniquíes.
- **Color**: el albedo de cada prop se escribe en `ARRAY_COLOR` en sRGB (el motor lo convierte, igual que con los maniquíes), multiplicado por la **oclusión horneada**: pie de los objetos (×0,72 a ras de suelo), volumen de copas y arbustos (caras hacia el tronco o hacia abajo, hasta ×0,72) y **contacto en el suelo** bajo cada prop bajo (hasta ×0,55, `ground_occlusion()` con una rejilla de oclusores de 3 m). Para ello el suelo está subdividido (120 segmentos, pasos de 0,6 m hasta 19 m) e indexado.
- **Colisionadores**: los `StaticBody3D` con etiqueta siguen colgando de los nodos originales, cuya malla se anula, así que rayos de oclusión, AF y fotómetro no cambian.
- **Coste**: unos 950 ms de fusión al construir el parque clásico en escritorio (3,0 s hasta el 02-10-2026). Por fotograma no hay coste extra.
- **Arranque rápido (02-10-2026)**: los objetos de Blender se fusionan de forma nativa (`SurfaceTool.append_from()` aplica la transformación y desplaza los índices en C++; `park.gd::srgb_mesh()` convierte los colores de cada malla de origen una sola vez, por muchas copias que haya), y solo las primitivas y el suelo, que llevan oclusión calculada, se recorren vértice a vértice. Las quince texturas del suelo se decodifican y generan sus mipmaps en hilos (`start_ground_load()`, `WorkerThreadPool`) mientras se coloca el parque. Los viandantes comparten el JSON de cada pieza (`Person.piece_cache` estático) y cada pieza de Blender se convierte una vez en una malla que los demás añaden de forma nativa y tiñen en `finish_mesh()`. Además, los 35 MB de JSON de las piezas se leen en hilos mientras se construye el parque (`Person.preload_pieces()`), y el bucle que convierte cada pieza no invierte matrices ni llama a funciones por vértice. En la colocación, los triángulos se cuentan una vez por malla y la envolvente convexa de cada árbol se comparte entre todas sus copias (`convex_shapes`). Arranque del parque clásico: de 7,7 s a 3,4 s; del grande, de 9,9 s a 4,2 s. El pase de colisión de cada viandante ya no construye mallas: usa una envolvente convexa por pieza, compartida entre todos los que la llevan. Se mide con `-- --timing` ([TESTS_Y_VERIFICACION.md §4.1](TESTS_Y_VERIFICACION.md)).

---

## 5. Presupuestos y Rendimiento (Invariantes de Diseño)

Límites por nivel de detalle ([futuro/17 §3](futuro/17_SALTO_GRAFICO_ULTRA.md)). El parque `lo` es común a Bajo, Medio y Alto, así que cumple el presupuesto móvil. Las reglas para que ningún perfil altere la puntuación están en [futuro/02 §10.3](futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md) y [futuro/17 §2.3](futuro/17_SALTO_GRAFICO_ULTRA.md).

| Métrica | `lo` (Bajo, Medio, Alto) | `hd` (Ultra, Forward+) | Cómo se verifica |
|---|:---:|:---:|---|
| **Triángulos en escena** (incluye figurantes y palomas en `hd`) | $\le 100.000$ | $\le 5.000.000$ | `--smoke-test` |
| **Triángulos por viandante** | $\le 1.900$ | $\le 60.000$ | `tests/test_art.gd` (`lo`), `--smoke-test` (`hd`) |
| **Memoria de vídeo (VRAM)** | $< 60\text{ MB}$ | $< 8\text{ GiB}$ | `tests/test_game.gd` |
| **Resolución del visor 3D** | 1280 × 720 | Nativa de la ventana | `main.gd::update_render_resolution()` |
| **Draw calls** | Día ≤ 300 en el visor (38 superficies de parque + 2 por viandante + pases de sombra del sol). De noche depende de las farolas con sombra del perfil | `--metrics` imprime `draw_calls`; `test_game.gd` impone el límite de día y comprueba las sombras de farola por perfil |
| **Tiempo de fotograma** | Objetivo 60 FPS | `godot-4 --path . -- --metrics` imprime mediana, p95 y máximo; no hay umbral automatizado |
| **Relación de aspecto** | 16:9 estricto ($1280 \times 720$) | `project.godot` |

Los valores medidos actuales (triángulos, VRAM, etc.) están en la tabla única de [TESTS_Y_VERIFICACION.md §5](TESTS_Y_VERIFICACION.md).

---

## 6. Verificación Automatizada

`--smoke-test`, `tests/test_game.gd`, `tests/test_expansion.gd` y `tests/test_park_life.gd` (requieren display). Comandos y criterios en [TESTS_Y_VERIFICACION.md](TESTS_Y_VERIFICACION.md).

## Misma imagen en Vulkan y en OpenGL (05-10-2026)

Forward+ (Vulkan en Windows y Linux, Metal en macOS) y `gl_compatibility` (OpenGL: Android, web y respaldo) no dibujan la misma escena —la de OpenGL es la ligera, sin iluminación global ni oclusión ambiental—, pero **el brillo y el contraste deben parecerse**. `./tools/compare_renderers.sh` saca el mismo plano en los dos, a las cuatro luces, y da una tabla con brillo medio, contraste, sombras (p5), luces (p95) y saturación.

OpenGL salía entre un 14 % (noche) y un 45 % (hora dorada) más brillante, y más duro. Ahora `park.gd::LO_EXPOSURE` va por luz (era una sola cifra, 0,72) y `LO_AMBIENT` sube la luz ambiente para que el lado en sombra de personas y árboles no quede negro:

| Luz | Brillo OpenGL / Forward+ antes | ahora |
|---|---:|---:|
| Día | 1,18–1,23 | 1,04–1,09 |
| Hora dorada | 1,45–1,46 | 1,11–1,14 |
| Hora azul | 1,27–1,30 | 1,01–1,03 |
| Noche | 1,16–1,20 | 1,06–1,08 |

Lo que sigue distinto, y no es cuestión de exposición: el suelo de OpenGL es liso y más claro (sin textura), no hay hierba ni figurantes, y de noche el suelo junto a las farolas queda más claro (p95 de 120 frente a 80). La nota de la foto no depende de nada de esto.

## Portátiles sin gráfica dedicada y pantallas de alta densidad (05-10-2026)

Tras el aviso de un MacBook Air que no llegaba a 60 FPS (allí Forward+ va sobre Metal): sin gráfica dedicada el juego arranca en **Medio** (era Alto), y los perfiles ligeros no siguen a la pantalla más allá de `main.gd::RENDER_LINES` (Bajo y Medio 1080 líneas, Alto 1440; la escala del perfil se aplica encima): una ventana de 1440 × 810 en una pantalla Retina son 2880 × 1620 píxeles reales. Ultra y Personalizado dibujan todos los píxeles, así que quien quiera más lo tiene a un clic. Si aun así el juego va a menos de 42 FPS durante 12 s, avisa una vez sobre el visor (`watch_speed()`, texto `aviso_rendimiento`).

