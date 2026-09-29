# Paso 1 · Parque Fusionado, Oclusión Horneada y Atmósfera

**Estado: ✅ Completado (29-09-2026).** Primer punto de la hoja de ruta ([README §4](README.md)) y mejora G1 de [02 §11](02_ESTILO_VISUAL_Y_POLIGONOS.md). Comparativas antes/después en `docs/evidencias/comparativas/parque_ilustrado_*.png` (día, hora dorada y noche, dos encuadres cada una).

> [!NOTE]
> El plan original era un «parque ilustrado»: toon y contorno de tinta en todo el parque, como en la referencia. Se implementó y **se descartó tras revisarlo**: el parque perdía el aspecto propio del juego y, sin niebla, la imagen quedaba plana (§4). Se conservan la fusión, la oclusión horneada, las correcciones de luz y la atmósfera. El toon y el contorno siguen reservados a los maniquíes.

---

## 1. Motivación

| Aspecto | Antes de este paso |
|---|---|
| Rendimiento | El parque no estaba fusionado como decía la documentación: 692 nodos y 78 materiales, ~1.790 draw calls por fotograma y mediana de 20,2 ms (Intel Iris Xe) |
| Profundidad | Niebla de profundidad desde 7 m (Ultra) que blanqueaba el parque desde el carril 2 |
| Volumen | Sin oclusión: arbustos y bancos «flotaban» sobre el césped |

---

## 2. Lo que se ha implementado

### 2.1 Fusión real del parque con colores de vértice (`park.gd::merge_static_meshes()`)
- Los props opacos se transforman a coordenadas de mundo y escriben su color en `ARRAY_COLOR`, multiplicado por la oclusión de §2.2. El color se escribe **en sRGB, sin convertir**, igual que los maniquíes: el motor ya lo convierte. Convertirlo antes con `srgb_to_linear()` lo linealizaba dos veces y oscurecía y saturaba el parque.
- Se agrupan en **12 sectores de 30° × 3 bandas radiales** (0–9, 9–17 y 17–45 m): 36 superficies con recorte por frustum. El vidrio de las farolas y las bombillas conservan su material propio: **38 superficies en total**, frente a 692.
- Material único `StandardMaterial3D` con `vertex_color_use_as_albedo` (`park.gd::vertex_color_material()`), sombreado suave como antes, sin bandas ni contorno.
- Los `StaticBody3D` con etiqueta (oclusión fotográfica, AF, fotómetro) siguen colgando de los nodos originales, cuya malla se anula. Ni los rayos ni las etiquetas cambian.
- Los anillos del suelo (`ring()`) se subdividen (120 segmentos y pasos radiales de 0,6 m hasta 19 m) y se indexan con `SurfaceTool.index()`, para que la oclusión de contacto tenga vértices sin multiplicar el coste.

### 2.2 Oclusión horneada en vértices (sin coste por fotograma)
- **Pie de los objetos**: ×0,72 a ras de suelo, subiendo hasta ×1,0 a 0,4 m.
- **Volumen de copas y arbustos**: las caras que miran hacia el eje del tronco (o el centro del arbusto) o hacia abajo bajan hasta ×0,72.
- **Contacto en el suelo** (`ground_occlusion()`): cada prop bajo (arbustos, bancos, papeleras, jardineras, troncos y copas hasta 4,5 m) oscurece el suelo bajo su huella y a su alrededor (radio ×1,6, intensidad 0,35), hasta un mínimo de ×0,55. Los oclusores se reparten en una rejilla de 3 m para que el horneado sea rápido.

### 2.3 Atmósfera y luz
- **Niebla moderada**: de 8 a 40 m en Alto y Ultra, de 9 a 48 m en Medio y sin niebla en Bajo. Deja los carriles casi limpios y da bruma al arbolado y al skyline. Antes era un muro de 7 a 20 m; una versión intermedia de 4 a 110 m dejaba la imagen plana.
- Las distancias de niebla viven solo en los perfiles (`apply_preset_values()`): `set_time_of_day()` las fijaba, pero los perfiles las sobrescribían siempre. Lo mismo ocurría con el desenfoque de las sombras.
- `fog_sky_affect = 0,3`, cielo diurno más azul (`6fa3cf` / `dce8ea`), skyline pálido azulado y ambiente de día 0,22 (antes 0,16).
- **Sombras del sol nítidas y pegadas a los pies**: `shadow_blur` 0,6 (Medio) y 0,8 (Alto y Ultra), antes 1,0–2,0; `shadow_normal_bias` 0,7 (Alto) y 0,6 (Ultra), antes 1,2 y 1,4.
- **Hora dorada**: ambiente de cielo azul claro tomado de su color (`9aaed0`, energía 0,55, `ambient_light_sky_contribution = 0`), para que las sombras largas se lean.
- **Noche**: luna fría (`MOONLIGHT = 0,32`, antes 0,035), ambiente `394568` a 0,42, bruma azul cercana (4–34 m), exposición ×1,25 y `tonemap_white = 4` aplicados tras el perfil: el parque se lee fuera del cono de las farolas sin reventar los blancos bajo ellas. `park.illumination_ev()` ignora el sol de noche, así que el exposímetro no cambia.
- **Antialiasing FXAA** en el visor (`Viewport.screen_space_aa`, `main.gd::apply_graphics_preset()`) en todos los perfiles salvo Bajo. No añade memoria; MSAA 4× costaría unos 30 MB.
- **Contorno de los maniquíes** con un mínimo de 1 px (`cel_outline.gdshader::min_width_px`), para que no se rompa en trazos a distancia.

### 2.4 Farolas
En `gl_compatibility`, cada luz que toca un objeto le añade un pase de dibujo, aunque tenga energía 0. Por eso:
- **De día** las farolas se ocultan (`visible = false`).
- **En hora dorada** se encienden sin sombras.
- **De noche**, las sombras dependen del perfil (`update_lamp_shadows()`): Ultra las 12, Alto las 4 interiores (carriles 0–1), Medio y Bajo ninguna. Cada sombra de farola cuesta ~100 draw calls, porque se vuelve a renderizar en cada fotograma.

`illumination_ev()` usa `light_energy` y sus propios rayos, así que visibilidad y sombras del render no alteran la lectura del fotómetro ni la puntuación.

---

## 3. Resultados medidos

Windows, Intel Iris Xe, perfil Ultra (cifras de referencia en [TESTS §5](../TESTS_Y_VERIFICACION.md)):

| Cifra | Antes | Después |
|---|---:|---:|
| Nodos de malla del parque | 692 (78 materiales) | 38 (3 materiales) |
| Draw calls del visor, día (`--metrics`) | 1.790 | **119** |
| Mediana de fotograma (`--metrics`) | 20,22 ms | **16,67 ms** (60 FPS, limitado por sincronía vertical) |
| Triángulos en escena (`--smoke-test`) | 82.198 | 90.646 (suelo subdividido; límite 100.000) |
| VRAM en sesión completa (`test_game.gd`) | 56,60 MiB | 56,54 MiB (con picos puntuales de búferes transitorios; ver §5) |
| Construcción del parque (`park.build()`) | 349 ms | ~645 ms (horneado de colores y oclusión) |

---

## 4. Intentos descartados

| Intento | Problema | Decisión |
|---|---|---|
| Toon + contorno de tinta en todo el parque | Cambiaba el estilo propio del juego; los bordes del casco se rompían a distancia y el toon dejaba negras las caras a contraluz | Revertido: el parque vuelve al sombreado suave. Se retiraron los uniformes `shadow_tone` y `smooth_normal_from_uv2` que solo lo servían |
| Niebla casi eliminada (4–110 m) | Sin bruma, todos los planos pesaban igual y la imagen quedaba plana | Niebla moderada de 8 a 40 m |
| Relleno mínimo de luz también dentro de las sombras | Dejaba las sombras de los personajes a medio contraste: parecían flotar | Retirado junto al toon del parque |
| Exposición nocturna ×1,7 | Reventaba los blancos de los maniquíes bajo las farolas | ×1,25 con `tonemap_white = 4`, más luna y ambiente |

---

## 5. Verificación

| Criterio | Resultado |
|---|---|
| Superficies fusionadas (≤ 40), material de colores de vértice sin contorno, colores por vértice, oclusión de contacto en el suelo, colisionadores y etiquetas intactos, FXAA según perfil, farolas por hora y perfil, draw calls de día ≤ 300 | Comprobaciones en `test_game.gd`: 47 checks, 0 fallos |
| Puntuación idéntica | `test_photography.gd` y `test_equipment.gd` sin cambios (535 y 561, 0 fallos) |
| Triángulos ≤ 100.000 | `--smoke-test`: 90.646 |
| VRAM | `test_game.gd` compara con 60.000.000 bytes (57,2 MiB, no 60 MiB). Hoy da 56,54 MiB, con 0,7 MiB de margen; en 2 de 6 ejecuciones un pico de búferes transitorios lo superó. El margen ya era igual de estrecho antes de este paso (56,60 MiB) |
| Navegación | `test_navigation.gd` 10/10. `simulate_jams.gd` da 1 viandante atascado en este equipo **también con el código anterior**, así que no lo causa este paso |
| Evidencias | `./tools/run_evidence.sh` regenerado. `build_sheets.py` usa el *demuxer* `concat` de ffmpeg, porque `-pattern_type glob` no existe en Windows |

---

## 6. Pendiente
- **Margen de VRAM**: estabilizar la medición (o reducir memoria) para que los picos transitorios no rompan `test_game.gd`, y alinear el límite documentado (60 MiB) con el que se comprueba (60 MB).
- **Coste de noche en Ultra** (~1.470 draw calls): limitar las sombras a las farolas del sector visible si pesa en equipos modestos.
- **Tiempo de construcción** (~645 ms en escritorio): cachear las mallas horneadas en `user://` si pesa en móvil ([15 §5](15_VARIEDAD_PROCEDURAL.md)).
