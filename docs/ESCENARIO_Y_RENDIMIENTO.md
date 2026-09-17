# Escenario Cilíndrico, Clima y Presupuestos de Rendimiento — Proyecto Paparazzi

Este documento describe la arquitectura geométrica del parque procedural, la iluminación dinámica, el sistema meteorológico de nubes y los presupuestos estrictos de rendimiento documentados en [scripts/park.gd](file:///home/ganso/codigo/afotando/scripts/park.gd).

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
  - Exposición base en el parque: **$EV = 14.0$**.
- **Noche**:
  - Sol desactivado / atenuado (`light_energy = 0.035`, tinte nocturno `9caed4`).
  - 12 farolas cilíndricas con luminarias omnidireccionales cálidas (`ffcd82`, radio de alcance $6.0\text{ m}$) que proyectan sombras directas.
  - Exposición bajo farola: **$EV = 4.0 - 6.0$**.

### 3.2 Sistema Meteorológico de Nubes
El parque cuenta con un sistema de nubes procedurales cúbicas de baja altura:
- **Transición de cobertura ($1.4\text{ s}$)**: Cuando una nube tapa el sol, la energía lumínica directa desciende bruscamente, reduciendo el valor de exposición en aproximadamente **$3.0\text{ EV}$** (de $EV = 14$ a $EV = 11$).
- **Afectación dual**: La nube oscurece tanto la imagen renderizada en el Viewport como la lectura del exposímetro fotográfico en tiempo real, obligando al jugador a compensar la apertura o la velocidad sobre la marcha.

---

## 4. Fusión de Malla Estática (`merge_static_meshes`)

Para mantener el máximo rendimiento en `gl_compatibility`:
- Toda la arquitectura del parque (anillos de suelo, verjas, farolas, bancos, jardineras, edificios y los **280 elementos vegetales**) se consolidan en **un único nodo de malla estática combinada** al arrancar.
- **Impacto**: El escenario completo se dibuja en **1 único draw call**.

---

## 5. Presupuestos y Rendimiento (Invariantes de Diseño)

| Métrica | Límite Máximo Permitido | Valor Medido Actual | Margen de Seguridad |
|---|:---:|:---:|:---:|
| **Triángulos en Escena** | $\le 100.000$ | **$57.532$** | $+42.468$ triángulos libres |
| **Triángulos por Viandante** | $\le 1.900$ | **$\sim 1.550$** | $+350$ triángulos libres |
| **Memoria de Vídeo (VRAM)** | $< 60\text{ MiB}$ | **$42.68\text{ MiB}$** | $+17.32\text{ MiB}$ libres |
| **Draw Calls Totales** | $< 40$ | **$\sim 23$** (1 parque + 21 personas + 1 visor) | Excelente |
| **Tasa de Refresco** | $\ge 60\text{ FPS}$ sostenidos | **$\ge 60\text{ FPS}$** en desktop y WebGL | Cumplido |
| **Relación de Aspecto** | **16:9 estricto** | $1280 \times 720$ nativo | Bloqueado |

---

## 6. Comandos de Verificación Automatizada

```bash
# 1. Verificación de presupuestos de geometría y smoke test
godot-4 --path . -- --smoke-test

# 2. Verificación de VRAM (< 60 MiB) y renderizado completo
godot-4 --path . --script tests/test_game.gd

# 3. Verificación de sistema de nubes y transiciones EV
godot-4 --path . --script tests/test_expansion.gd
```
