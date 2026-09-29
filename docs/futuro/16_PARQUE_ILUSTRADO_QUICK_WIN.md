# Paso 1 · Parque Ilustrado (Mejora Gráfica de Bajo Coste y Gran Impacto)

**Estado: 📝 Siguiente tarea a realizar.** Es el primer punto de la hoja de ruta ([README §4](README.md)) y la mejora G1 de [02 §11](02_ESTILO_VISUAL_Y_POLIGONOS.md).

---

## 1. Por qué esta mejora primero

Al comparar la [imagen de referencia](referencia.jpg) con la captura actual del parque ([docs/evidencias/estados/04_parque_dia.png](../evidencias/estados/04_parque_dia.png)), la mayor diferencia no está en los personajes, sino en **todo lo demás**:

| Aspecto | Referencia | Juego actual |
|---|---|---|
| Estilo | Toon con contorno de tinta en **todo**: árboles, bancos, farolas, verja | Toon y contorno solo en los maniquíes; el parque usa `StandardMaterial3D` con sombreado continuo, así que los personajes parecen recortados sobre otro juego |
| Contraste y color | Verdes saturados, cielo claro, planos nítidos hasta el fondo | La niebla de profundidad empieza a 7 m en Ultra (`park.gd::apply_graphics_preset`) y blanquea el parque desde el carril 2 |
| Volumen | Base de objetos y copas oscurecidas | Sin oclusión en el parque: arbustos y bancos «flotan» sobre el césped |

Además, el parque **no** está fusionado como dice la documentación: `merge_static_meshes()` agrupa por color y celda de 6 m (692 nodos, 78 materiales), y el visor dibuja **~1.800 draw calls** con una mediana de **20 ms** por fotograma en una Intel Iris Xe ([TESTS §5](../TESTS_Y_VERIFICACION.md)). La misma intervención que da el aspecto ilustrado (colores de vértice y un material compartido) resuelve también el rendimiento, en escritorio y sobre todo en móvil.

**Coste estimado: bajo-medio (S-M), 2–3 días.** Reutiliza los shaders existentes (`cel_shading.gdshader`, `cel_outline.gdshader`), no añade texturas ni geometría y no toca la lógica fotográfica.

---

## 2. Intervenciones

### 2.1 Fusión real del parque con colores de vértice
`park.gd::merge_static_meshes()` se reescribe:
1. Recorre los `MeshInstance3D` opacos, transforma sus vértices a coordenadas de mundo y escribe `ARRAY_COLOR = albedo_color` del material de cada nodo, con la oclusión de §2.3.
2. Agrupa por **sector**: 12 sectores angulares de 30° × 3 bandas radiales (0–9 m, 9–17 m, 17–45 m). Así el parque queda en unas 36 superficies y se conserva el recorte por frustum: al mirar en una dirección solo se dibujan los sectores visibles.
3. **Excepciones con material propio**: el vidrio de las farolas (`glass_material`, transparente) y las bombillas (`bulb_material`, emisión variable de día y de noche) se agrupan aparte, en dos superficies.
4. Los `StaticBody3D` con etiqueta (oclusión fotográfica, AF, fotómetro) **no se tocan**: siguen siendo hijos de los nodos originales, cuya malla ya se anula hoy.

### 2.2 Material toon compartido con contorno
- Un único `ShaderMaterial` para todo el parque con `cel_shading.gdshader`. Se añaden uniformes para desactivar el barniz (`varnish_specular = 0`) y suavizar el *rim* en superficies que no son de madera; o bien una variante `cel_shading_park.gdshader` si el código queda más claro.
- `next_pass` con `cel_outline.gdshader`: línea algo más fina que la de los maniquíes (1,2 px), con la misma atenuación por distancia, para que el fondo no se llene de trazos.
- **Suelo sin contorno**: los anillos de `ring()` escriben alfa 0 en `ARRAY_COLOR`. `cel_outline.gdshader` ya colapsa esos vértices, así que el suelo no genera casco.
- **Perfil Bajo**: sin `next_pass` (contorno desactivado), como hoy con los maniquíes.

### 2.3 Oclusión horneada en vértices
Multiplicador de color calculado al fusionar, sin coste en tiempo de ejecución:
- **Base de objetos**: ×0,72 a ras de suelo, subiendo hasta ×1,0 a 0,4 m de altura (bancos, papeleras, farolas, jardineras, troncos).
- **Copas y arbustos**: ×0,80 en las caras orientadas hacia abajo (`normal.y < 0`) y ×1,0 en las superiores.
- **Césped bajo las copas**: los vértices del anillo de suelo a menos de 1,5 m de un tronco se oscurecen ×0,85. Hace falta subdividir lo justo el anillo exterior; la mejora G2 de [02 §11](02_ESTILO_VISUAL_Y_POLIGONOS.md) aprovecha esa misma subdivisión.

### 2.4 Atmósfera reajustada
- **Niebla**: empieza tras la zona jugable (`fog_depth_begin` ≈ 13 m, fin ≈ 45 m) en lugar de a 7–9 m. Primer plano y carriles quedan con contraste pleno y solo el arbolado y el skyline se funden, como en la referencia.
- **Color**: cielo cenital más azul, horizonte claro y una ligera subida de saturación en Alto y Ultra.
- Ajustes por perfil en `park.gd::apply_graphics_preset()` y por hora del día en `set_time_of_day()`.

---

## 3. Lo que no cambia
- `photography.gd`, los 5 rayos de oclusión, `park.illumination_ev()` y la puntuación: el aspecto cambia, la física y la luz medida no.
- Los personajes, su material y sus presupuestos.
- Los triángulos de la escena: el contorno es un segundo pase, no geometría nueva.

---

## 4. Criterios de Aceptación

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 1 | Draw calls del visor ≤ **150** en Ultra de día (hoy ~1.800), y medidos también de noche | `--metrics` (`draw_calls=`) y nueva comprobación en `test_game.gd` con `RenderingServer.viewport_get_render_info` |
| 2 | Mediana de fotograma mejor que la actual en la misma máquina | `--metrics`; la cifra nueva va a [TESTS §5](../TESTS_Y_VERIFICACION.md) |
| 3 | Todas las superficies opacas del parque llevan `ARRAY_COLOR` y comparten el material toon; el suelo tiene alfa 0 | Nueva comprobación en `test_art.gd` o `test_game.gd` |
| 4 | Triángulos ≤ 100.000 y VRAM < 60 MiB (perfiles móviles) | `--smoke-test`, `test_game.gd` |
| 5 | Puntuación idéntica: las mismas evidencias dan la misma nota | `test_photography.gd`, `test_equipment.gd` (oclusión y fotómetro) |
| 6 | Oclusión y etiquetas intactas: los rayos siguen chocando con bancos, farolas y árboles con su etiqueta | `test_expansion.gd`, `test_game.gd` |
| 7 | Navegación sin cambios | `test_navigation.gd`, `simulate_jams.gd` |
| 8 | Evidencias gráficas regeneradas, con una comparativa antes/después de día, hora dorada y noche | `./tools/run_evidence.sh` → `docs/evidencias/comparativas/parque_ilustrado_*.png` |

---

## 5. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|---|---|
| Contorno con artefactos en piezas finas (barrotes de la verja, cristales, patas) | `max_width_m` del contorno más pequeño en el parque; alfa 0 en piezas de menos de 3 cm de grosor (barrotes) |
| Pérdida del recorte por frustum con superficies grandes | Sectorización 12 × 3 (§2.1) |
| Pases de luz extra por farola en `gl_compatibility` de noche | Medir `draw_calls` de noche (criterio 1); si se disparan, reducir el tamaño de sector en las bandas con farolas |
| Bandas toon demasiado duras en el césped | El suelo usa `band_softness` mayor o sombreado lambertiano (uniforme del shader) |
| Cambio de lectura del exposímetro | No hay riesgo: `illumination_ev()` se calcula con rayos y parámetros de luz, no con el render. El criterio 5 lo verifica |
