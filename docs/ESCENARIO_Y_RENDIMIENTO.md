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

## 2. Masa Vegetal Densa de Fondo

Para cerrar visualmente el horizonte y proporcionar un fondo natural continuo tras la verja perimetral:

1. **Seto Perimetral Bajo ($r \approx 13.4\text{ m}$)**:
   - 84 arbustos procedurales (`SphereMesh`, $r \in [0.55, 0.95]\text{ m}$, altura $1.6 - 2.2\text{ m}$) solapados.
   - Ocultan la base de la verja y la franja desnuda de césped exterior.
2. **Arbolado Primario ($r = 14.2\text{ m}$)**:
   - 30 árboles espaciados cada $12^\circ$ con troncos cilíndricos y 4 variedades botánicas (coníferas escalonadas y copas esféricas frondosas).
3. **Arbolado Secundario Intercalado ($r \approx 15.6\text{ m}$)**:
   - 36 árboles adicionales desfasados $9^\circ$ respecto a la primera fila, situándose exactamente en los huecos visuales para formar un telón boscoso continuo.
4. **Sotobosque de Conexión ($r \approx 15.0\text{ m}$)**:
   - 60 arbustos medianos bajo las copas para unificar visualmente el suelo con las ramas.

---

## 3. Iluminación y Clima Procedural

### 3.1 Ciclo Día / Noche (`park.set_night()`)
- **Día**:
  - Sol direccional (`DirectionalLight3D`): `light_energy = 1.4`, color cálido `fff0d7`.
  - Sombras dinámicas ortogonales activadas con atlas de 2048.
  - Cielo celeste y luz ambiental difusa (`c6d6df`, energía 0.16).
  - Luz incidente: **$EV \approx 14.8$** al sol y **$EV = 11.0$** en sombra (detalle en [SIMULACION_FOTOGRAFICA.md §2.2](SIMULACION_FOTOGRAFICA.md)).
- **Noche**:
  - Sol desactivado / atenuado (`light_energy = 0.035`, tinte nocturno `9caed4`).
  - 12 farolas cilíndricas con luminarias omnidireccionales cálidas (`ffcd82`, radio de alcance $6.0\text{ m}$) que proyectan sombras directas.
  - Luz incidente: **$EV = 2.0$** lejos de farolas; bajo farola $\approx 8.4$ a 1 m, $5.2$ a 3 m y $2.9$ a 5 m.

### 3.2 Sistema Meteorológico de Nubes
El parque cuenta con un sistema de nubes procedurales cúbicas de baja altura:
- **Ciclo de 18 s** (`park.gd`, `weather_time`): `cloud_cover` sube de 0 a 1 entre los segundos 6.0 y 7.2 del ciclo, se mantiene hasta el 11.0 y baja a 0 entre el 11.0 y el 12.2.
- **Atenuación**: la transmisión solar pasa de 1.0 a 0.09 (`sun_transmission()`, −3.5 EV en la luz directa). En un punto al sol la luz incidente baja de $EV \approx 14.8$ a $\approx 12.1$ (−2.7 EV), porque la componente ambiental ($EV = 11$) no cambia.
- **Afectación dual**: La nube oscurece tanto la imagen renderizada en el Viewport como la lectura del exposímetro fotográfico en tiempo real, obligando al jugador a compensar la apertura o la velocidad sobre la marcha.

---

### 3.3 Perspectiva Aérea y Niebla de Profundidad (Atmospheric Depth Fog)
Para evitar el ruido visual y el apiñamiento de planos entre viandantes y masa vegetal de fondo:
- **Niebla de profundidad (`Environment.fog_mode = FOG_MODE_DEPTH`)**:
  - Comienzo a $r = 8.0\text{ m}$ (tras el carril intermedio 2) y cota máxima a $22.0\text{ m}$.
  - Los primeros planos ($r < 8.0\text{ m}$) mantienen contraste y saturación íntegros.
  - El fondo vegetal y el horizonte urbano se funden suavemente con el tono del horizonte (`c5d4c9` de día, `192139` de noche).
- **Mapeo de tonos HDR / ACES (`tonemap_mode = TONE_MAPPER_ACES`, `tonemap_white = 1.4` y ajustes de contraste)**: Curva cinematográfica de compresión de altas luces.
- **Atenuación adaptativa de tinta (`cel_outline.gdshader`)**: El contorno exterior de los maniquíes disminuye progresivamente su grosor relativo entre 7 m y 17 m para no saturar con líneas negras los planos lejanos.

---

## 4. Fusión de Malla Estática (`merge_static_meshes`)

Para mantener el máximo rendimiento en `gl_compatibility`:
- Toda la arquitectura del parque (anillos de suelo, verjas, farolas, bancos, jardineras, edificios y los **280 elementos vegetales**) se consolidan en **un único nodo de malla estática combinada** al arrancar.
- **Impacto**: El escenario completo se dibuja en **1 único draw call**.

---

## 5. Presupuestos y Rendimiento (Invariantes de Diseño)

| Métrica | Límite | Cómo se verifica |
|---|:---:|---|
| **Triángulos en escena** | $\le 100.000$ | `--smoke-test` |
| **Triángulos por viandante** | $\le 1.900$ | `tests/test_art.gd` |
| **Memoria de vídeo (VRAM)** | $< 60\text{ MiB}$ | `tests/test_game.gd` |
| **Draw calls** | 1 parque estático + 2 por viandante (superficie única dibujada con toon + contorno de tinta) | Por construcción (`merge_static_meshes`, superficie única y material de 2 pases en `person.gd`; `test_art.gd` comprueba el material); ningún test cuenta los draw calls |
| **Tiempo de fotograma** | Objetivo 60 FPS | `godot-4 --path . -- --metrics` imprime mediana, p95 y máximo; no hay umbral automatizado |
| **Relación de aspecto** | 16:9 estricto ($1280 \times 720$) | `project.godot` |

Los valores medidos actuales (triángulos, VRAM, etc.) están en la tabla única de [TESTS_Y_VERIFICACION.md §5](TESTS_Y_VERIFICACION.md).

---

## 6. Verificación Automatizada

`--smoke-test`, `tests/test_game.gd` y `tests/test_expansion.gd` (requieren display). Comandos y criterios en [TESTS_Y_VERIFICACION.md](TESTS_Y_VERIFICACION.md).
