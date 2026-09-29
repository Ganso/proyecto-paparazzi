# Escenario Cilíndrico, Clima y Presupuestos de Rendimiento — Proyecto Paparazzi

Este documento describe la arquitectura geométrica del parque procedural, la iluminación dinámica, el sistema meteorológico de nubes y los presupuestos estrictos de rendimiento documentados en [scripts/park.gd](../scripts/park.gd).

---

## 1. Disposición Cilíndrica del Parque

El escenario es un parque urbano procedural concéntrico de $45\text{ m}$ de radio modelado en coordenadas cilíndricas $(r, \theta)$ con la cámara del jugador situada en el centro exacto $(0, 1.60\text{ m}, 0)$.

```
+-------------------------------------------------------------------------------+
|                       ESTRUCTURA RADIAL DEL PARQUE                            |
+-------------------------------------------------------------------------------+
  r = 0.0 m          [CÁMARA DEL JUGADOR] y = 1.60 m
  r = 0.8 m          Farolas interiores de la plaza central (4 unidades)
  r = 1.2 - 2.4 m    CARRIL 0: Paseo circular interior (3 viandantes)
  r = 2.9 - 4.85 m   CARRIL 1: Plaza central y calzada principal (7 viandantes)
  r = 4.85 m         4 Bancos urbanos orientados al centro (a 90°)
  r = 5.55 m         Papeleras cilíndricas
  r = 6.1 - 7.9 m    CARRIL 2: Calzada intermedia (6 viandantes)
  r = 8.6 m          Farolas exteriores (8 unidades)
  r = 9.2 m          Arbustos interiores decorativos (70 unidades)
  r = 9.7 m          Jardineras con flores
  r = 10.6 - 12.4 m  CARRIL 3: Calzada perimetral de tierra (5 viandantes)
  r = 12.8 m         Verja perimetral de barrotes (72 postes)
  ------------------ LÍMITE DE LA ZONA JUGABLE ---------------------------------
  r = 13.2 - 13.8 m  Masa densa de setos y arbustos perimetrales (84 arbustos)
  r = 14.2 m         Fila primaria de arbolado (30 árboles)
  r = 15.0 - 16.4 m  Sotobosque y arbustos bajo copas (60 arbustos)
  r = 15.2 - 16.2 m  Fila secundaria de árboles intercalados (36 árboles)
  r = 17.8 - 19.2 m  Peana perimetral de caoba con moldura de diorama y placa de latón (Escala 1:18)
  r = 21.0 - 27.0 m  Bloques de edificios del horizonte urbano (36 edificios)
  r = 45.0 m         Límite exterior del césped
```

---

## 2. Masa Vegetal Densa y Especies Botánicas con Variación Procedural

Para cerrar visualmente el horizonte y dotar al diorama de una riqueza orgánica viva y estilizada:

### 2.1 Catálogo de Especies Botánicas Estilizadas (`build_tree`)
El parque implementa **4 especies botánicas** diferenciadas estructural y cromáticamente:

1. **Especie 0: Roble / Plátano de Sombra (*Quercus / Platanus*)**:
   - **Estructura**: Fuste robusto con ensanchamiento/cuello radicular basal ($r = 0.20\text{ m}$), bifurcación en 2 ramas secundarias oblicuas divergentes.
   - **Follaje**: Cúpula central ancha semiesférica y 4 racimos esféricos perimetrales distribuidos en corona tridimensional 3D (rompiendo cualquier alineación plana).
   - **Paleta**: Verde bosque denso y frondoso (`#486b33`, `#577a3d`, `#3d5a2a`).
2. **Especie 1: Ciprés / Álamo Columnar (*Cupressus / Populus nigra*)**:
   - **Estructura**: Fuste estilizado vertical arropado por el follaje.
   - **Follaje**: Silueta columnar/fusiforme estrecha escalonada en 4 niveles ovoides superpuestos rematados en ápice cónico sutil.
   - **Paleta**: Verde ciprés profundo azulado (`#274434`, `#315340`, `#3b614b`).
3. **Especie 2: Tilo / Castaño (*Tilia / Castanea*)**:
   - **Estructura**: Tronco limpio y equilibrado con cuello visible ($r = 0.18\text{ m}$).
   - **Follaje**: Copa globosa compacta (estilo nube diorama suave) compuesta por un domo central superior y 3 racimos esféricos densos en tríada.
   - **Paleta**: Verde tilo/manzana luminoso y fresco (`#6fa040`, `#608e36`, `#517a2d`).
4. **Especie 3: Arce Dorado Otoñal (*Acer*)**:
   - **Estructura**: Tronco esbelto asimétrico con una rama lateral extendida que sostiene una masa de follaje suspendida más baja.
   - **Follaje**: 3 nubes escalonadas horizontales que generan una silueta asimétrica de inspiración japonesa y señorial.
   - **Paleta**: Gradiente otoñal cálido de ámbar, oro y siena tostada (`#c48d35`, `#af7629`, `#975d20`).

### 2.2 Sistema de Variación Procedural Individual
Cada espécimen vegetal se genera mediante una semilla pseudoaleatoria única y determinista (`seed`), garantizando que no existan dos árboles idénticos:
- **Rotación azimutal libre en 360° (`rotation.y in [0, 2*PI]`)**: Elimina la repetición angular desde cualquier ángulo de visión del fotógrafo.
- **Inclinación orgánica del fuste (`rotation.x, rotation.z in [-2 deg, +2 deg]`)**: Simula el fototropismo y la asimetría natural del crecimiento en exteriores.
- **Variación de escala y esbeltez (+-15%)**: Modulación independiente de altura y anchura por espécimen.
- **Jitter tridimensional en racimos de copa**: Los centros, radios y alturas de las masas esféricas se perturban sutilmente en 3D.
- **Micro-modulación cromática**: Las copas reciben variaciones tonales según la altura de la masa (luces superiores más claras y masas bajas más densas).

### 2.3 Estratificación en Anillos del Paisaje
1. **Seto Perimetral Bajo ($r \approx 13.4\text{ m}$)**:
   - 84 arbustos facetados (`SphereMesh` de 7 segmentos y 2 anillos, $r \in [0.55, 0.95]\text{ m}$) solapados que ocultan la base de la verja.
2. **Arbolado Primario ($r = 14.2\text{ m}$)**:
   - 30 árboles botánicos principales distribuidos cada $12^\circ$.
3. **Arbolado Secundario Intercalado ($r \approx 15.6\text{ m}$)**:
   - 36 árboles botánicos adicionales de mayor escala ($+15\%$), desfasados $9^\circ$ para sellar los huecos visuales con un telón boscoso denso.
4. **Sotobosque de Conexión ($r \approx 15.0\text{ m}$)**:
   - 60 arbustos medianos bajo las copas para unificar visualmente el suelo con las ramas.

---

## 3. Iluminación y Clima Procedural

### 3.1 Iluminación y Horas del Día: Día, Hora Dorada y Noche (`park.set_time_of_day()`)
- **Día**:
  - Sol cenital (`DirectionalLight3D`, pitch $-72^\circ$): `light_energy = 1.4`, color cálido `fff0d7`.
  - Sombras dinámicas ortogonales activadas con atlas de 2048, nítidas y pegadas a los pies: `shadow_blur` 0,6–0,8 y `shadow_normal_bias` 0,6–0,7 según el perfil (`apply_preset_values()`).
  - Cielo celeste (`6fa3cf` en el cenit, `dce8ea` en el horizonte) y luz ambiental difusa (`c6d6df`, energía 0.22, tomada del cielo).
  - Farolas ocultas (`visible = false`): en `gl_compatibility`, una luz a energía 0 seguiría costando un pase de dibujo por objeto.
  - Luz incidente: **$EV \approx 14.8$** al sol y **$EV = 11.0$** en sombra (detalle en [SIMULACION_FOTOGRAFICA.md §2.2](SIMULACION_FOTOGRAFICA.md)).
- **Hora Dorada (Golden Hour)**:
  - **Sol rasante bajo en el horizonte** (pitch $-15^\circ$, azimut $-48^\circ$): proyecta sombras largas, dramáticas y oblicuas que atraviesan los paseos circulares y acentúan el volumen y relieve de los maniquíes.
  - **Luz solar ámbar dorado intensa**: `light_color = Color("ffa544")`, `light_energy = 2.2`, con la misma penumbra del perfil.
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

### 3.2 Sistema Meteorológico de Nubes
El parque cuenta con un sistema de nubes procedurales cúbicas de baja altura:
- **Ciclo de 18 s** (`park.gd`, `weather_time`): `cloud_cover` sube de 0 a 1 entre los segundos 6.0 y 7.2 del ciclo, se mantiene hasta el 11.0 y baja a 0 entre el 11.0 y el 12.2.
- **Atenuación**: la transmisión solar pasa de 1.0 a 0.09 (`sun_transmission()`, −3.5 EV en la luz directa). En un punto al sol la luz incidente baja de $EV \approx 14.8$ a $\approx 12.1$ (−2.7 EV), porque la componente ambiental ($EV = 11$) no cambia.
- **Afectación dual**: La nube oscurece tanto la imagen renderizada en el Viewport como la lectura del exposímetro fotográfico en tiempo real, obligando al jugador a compensar la apertura o la velocidad sobre la marcha.

---

### 3.3 Perspectiva Aérea y Niebla de Profundidad (Atmospheric Depth Fog)
Para evitar el ruido visual y el apiñamiento de planos entre viandantes y masa vegetal de fondo:
- **Niebla de profundidad moderada (`Environment.fog_mode = FOG_MODE_DEPTH`)**, fijada solo por el perfil gráfico (`park.gd::apply_preset_values()`):
  - Alto y Ultra: de 8 a 40 m; Medio: de 9 a 48 m; Bajo: sin niebla. `fog_sky_affect = 0.3` para que el cielo siga azul.
  - Los carriles conservan contraste y color casi íntegros, y el arbolado y el skyline ganan bruma. Antes era un muro de 7 a 20 m que blanqueaba el parque desde el carril 2; una versión casi sin niebla (4–110 m) dejaba la imagen plana.
  - Tono del horizonte: `cddcdd` de día, `e58b3e` en hora dorada y `192139` de noche (de noche, bruma de 4 a 34 m).
- **Mapeo de tonos HDR / ACES (`tonemap_mode = TONE_MAPPER_ACES`, `tonemap_white = 1.4` y ajustes de contraste)**: Curva cinematográfica de compresión de altas luces.
- **Atenuación adaptativa de tinta y tintado armónico (`cel_outline.gdshader`)**: El contorno exterior de los maniquíes disminuye progresivamente su grosor mediante una curva cúbica suave (`smoothstep`) entre 6,5 m y 17,5 m para no saturar con líneas negras los planos lejanos, incorporando modulación armónica sobre el color de vértice (`tint_strength`) y sesgo de profundidad anti-intersección (`depth_bias`).

---

## 4. Parque Fusionado y Oclusión Horneada (`merge_static_meshes`)

Implementado en el paso 1 de la hoja de ruta ([futuro/16](futuro/16_PARQUE_ILUSTRADO_QUICK_WIN.md)), que detalla parámetros, resultados y comparativas.
- **Fusión**: al arrancar, los props opacos (suelo, verjas, farolas, bancos, jardineras, edificios y los **280 elementos vegetales**) se transforman a coordenadas de mundo y se combinan en **36 superficies** (12 sectores de 30° × 3 bandas radiales: 0–9, 9–17 y 17–45 m), que conservan el recorte por frustum. El vidrio y las bombillas de las farolas mantienen su material: **38 superficies en total** (antes 692).
- **Material**: un único `StandardMaterial3D` con `vertex_color_use_as_albedo` (`park.gd::vertex_color_material()`), con el mismo sombreado suave de antes: el parque no lleva toon ni contorno, que son propios de los maniquíes.
- **Color**: el albedo de cada prop se escribe en `ARRAY_COLOR` en sRGB (el motor lo convierte, igual que con los maniquíes), multiplicado por la **oclusión horneada**: pie de los objetos (×0,72 a ras de suelo), volumen de copas y arbustos (caras hacia el tronco o hacia abajo, hasta ×0,72) y **contacto en el suelo** bajo cada prop bajo (hasta ×0,55, `ground_occlusion()` con una rejilla de oclusores de 3 m). Para ello el suelo está subdividido (120 segmentos, pasos de 0,6 m hasta 19 m) e indexado.
- **Colisionadores**: los `StaticBody3D` con etiqueta siguen colgando de los nodos originales, cuya malla se anula, así que rayos de oclusión, AF y fotómetro no cambian.
- **Coste**: unos 645 ms de horneado al construir el parque en escritorio (349 ms antes). Por fotograma no hay coste extra.

---

## 5. Presupuestos y Rendimiento (Invariantes de Diseño)

Límites actuales, que son los de los perfiles Bajo y Medio. Los presupuestos ampliados de Alto y Ultra, y las reglas para que ningún perfil altere la puntuación, están en [futuro/02 §10](futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md).

| Métrica | Límite | Cómo se verifica |
|---|:---:|---|
| **Triángulos en escena** | $\le 100.000$ | `--smoke-test` |
| **Triángulos por viandante** | $\le 1.900$ | `tests/test_art.gd` |
| **Memoria de vídeo (VRAM)** | $< 60\text{ MiB}$ | `tests/test_game.gd` |
| **Draw calls** | Día ≤ 300 en el visor (38 superficies de parque + 2 por viandante + pases de sombra del sol). De noche depende de las farolas con sombra del perfil | `--metrics` imprime `draw_calls`; `test_game.gd` impone el límite de día y comprueba las sombras de farola por perfil |
| **Tiempo de fotograma** | Objetivo 60 FPS | `godot-4 --path . -- --metrics` imprime mediana, p95 y máximo; no hay umbral automatizado |
| **Relación de aspecto** | 16:9 estricto ($1280 \times 720$) | `project.godot` |

Los valores medidos actuales (triángulos, VRAM, etc.) están en la tabla única de [TESTS_Y_VERIFICACION.md §5](TESTS_Y_VERIFICACION.md).

---

## 6. Verificación Automatizada

`--smoke-test`, `tests/test_game.gd` y `tests/test_expansion.gd` (requieren display). Comandos y criterios en [TESTS_Y_VERIFICACION.md](TESTS_Y_VERIFICACION.md).
