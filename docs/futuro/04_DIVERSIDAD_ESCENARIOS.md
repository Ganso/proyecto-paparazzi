# Especificación Futura: Diversidad de Escenarios Temáticos

Este documento describe el diseño de cuatro nuevos entornos temáticos que expanden el universo de **Proyecto Paparazzi** más allá del parque urbano circular actual.

---

## 1. Catálogo de Nuevos Escenarios

```
+-------------------------------------------------------------------------------+
|                       BANCO DE ESCENARIOS PROPUESTOS                          |
+-------------------------------------------------------------------------------+
  1. Bulevar Comercial Urbano     - Tiendas, escaparates, terrazas de café
  2. Gran Estación de Tren        - Bóvedas de hierro, haces de luz cenital y maletas
  3. Museo de Arte y Escultura    - Suelo de mármol, luz difusa tenue e interiorismo
  4. Pista de Atletismo Urbana    - 8 calles elípticas, corredores rápidos y gradas
```

---

## 2. Detalle de Escenarios

### 2.1 Bulevar Comercial Urbano (*Street Photography Clásica*)
- **Estructura Espacial**:
  - Calle peatonal ancha flanqueada por fachadas de edificios con escaparates iluminados y toldos de colores.
  - El jugador se sitúa en una mesa de terraza de café exterior o en un cruce de calles concurrido.
- **Iluminación y Reto Fotográfico**:
  - Contrastes fuertes entre la sombra de los edificios y los escaparates brillantes.
  - Reflejos en cristales que pueden utilizarse creativamente en la composición.
- **Conducta de Peatones**:
  - Caminantes que se detienen a mirar escaparates, viandantes cargando bolsas de compras y camareros cruzando la calzada.

### 2.2 Vestíbulo de la Gran Estación Central (*Atmósfera Cinematográfica*)
- **Estructura Espacial**:
  - Inmensa nave cubierta por una bóveda de arcos de fundición de hierro y cristaleras polvorientas.
  - Andenes con trenes estacionados a los lados y un gran panel electromecánico de horarios al fondo.
- **Iluminación y Reto Fotográfico**:
  - Haces de luz solar volumétrica que atraviesan el humo y el vapor ambiente.
  - Escenario perfecto para fotografías de **alto contraste** y pruebas de siluetas a contraluz.
- **Conducta de Peatones**:
  - Viandantes apresurados arrastrando maletas con ruedas, personas despidiéndose o consultando billetes.

### 2.3 Galería de Museo de Arte y Escultura (*Fotografía Silenciosa de Interior*)
- **Estructura Espacial**:
  - Salas amplias de techos altos con claraboyas cenitales y pavimentos de piedra pulida con reflejos sutiles.
  - Peanas con estatuas clásicas y grandes marcos pictóricos en las paredes.
- **Iluminación y Reto Fotográfico**:
  - **Luz ambiente baja ($EV = 6.0 - 8.0$)**: Prohibición estricta de iluminación artificial directa.
  - Obliga al jugador a utilizar objetivos muy luminosos ($f/1.8$), películas de alta sensibilidad ($\text{ISO } 800 - 1600$) y mantener el pulso firme para no trepidar a $1/30\text{ s}$.
- **Conducta de Peatones**:
  - Marcha pausadísima ($v \approx 0.4\text{ m/s}$) y largos periodos de observación inmóvil frente a las obras.

### 2.4 Pista de Atletismo al Aire Libre (*Fotografía Deportiva y Acción Rápida*)
- **Estructura Espacial**:
  - Anillo elíptico reglamentario de 8 calles de tartán rojo rodeado por gradas con público.
- **Iluminación y Reto Fotográfico**:
  - Luz solar abierta diurna ($EV = 14.0 - 15.0$) o potentes torretas de focos nocturnas.
  - **El reto supremo del obturador**: Congelar atletas esprintando a $v \in [3.5, 6.0]\text{ m/s}$ requiere $1/1000\text{ s}$, o dominar la técnica de **barrido (*panning*)** a $1/60\text{ s}$ para obtener fondos en estela con el corredor nítido.

---

## 3. Matriz Técnica de Integración

| Escenario | Radio / Superficie | Nivel de Luz ($EV$) | Tipología Dominante de Lente | Invariante de Rendimiento |
|---|:---:|:---:|:---:|:---:|
| **Parque Actual** | Cilíndrico $r = 45\text{ m}$ (zona jugable hasta $12.4\text{ m}$) | $2.0 - 14.8$ | $50\text{ mm}$ y zoom $70\text{–}200\text{ mm}$ | Cifras medidas en [TESTS §5](../TESTS_Y_VERIFICACION.md); ≤ 100.000 tris en los perfiles móviles |
| **Bulevar** | Pasillo $14 \times 80\text{ m}$ | $8.0 - 13.0$ | $28\text{ mm}$ y $35\text{ mm}$ | $\le 65.000$ tris, oclusión de fachadas |
| **Estación** | Bóveda $30 \times 60\text{ m}$ | $5.0 - 10.0$ | $50\text{ mm}$ y $85\text{ mm}$ | $\le 70.000$ tris, niebla volumétrica |
| **Museo** | Sala $20 \times 30\text{ m}$ | $6.0 - 8.0$ | $35\text{ mm}$ y $50\text{ mm}$ ($f/1.8$) | $\le 50.000$ tris, sin sombras solares |
| **Pista Atletismo** | Elipse $80 \times 120\text{ m}$ | $11.0 - 15.0$ | $105\text{ mm}$ y $135\text{ mm}$ | $\le 60.000$ tris, LOD en gradas |

---

## 4. Dependencias, Coste Real y Criterios de Aceptación

- **Coste real: muy alto (XL).** Ningún escenario nuevo es circular: el bulevar y la estación son recorridos lineales, el museo es una sala y la pista es una elipse. Todos exigen sustituir `LANES`, `LANE_BOUNDS` y el steering cilíndrico de `main.gd` por recorridos genéricos, que es la navegación por grafo de [01 §3 Alternativa C](01_MAPA_ABIERTO_Y_PROTAGONISTA.md). Esa navegación debe diseñarse una sola vez para ambos documentos.
- **Enfoque por zonas**: las zonas de [13 §3.2](13_INTERFAZ_MOVIL_UTILIZABLE.md) usan los radios de los carriles; cada escenario debe declarar sus propias distancias de referencia.
- **Presupuestos por perfil**: las cifras de la tabla §3 son para los perfiles móviles (Bajo/Medio); los perfiles de escritorio siguen la tabla de [02 §10](02_ESTILO_VISUAL_Y_POLIGONOS.md).
- **Criterios de aceptación por escenario**:
  1. Equivalentes de `test_navigation.gd` (cruces y adelantamientos) y de `simulate_jams.gd` (0 viandantes atascados en 20 s) sobre sus recorridos.
  2. `--smoke-test` y `test_game.gd` parametrizados por escenario, con los presupuestos de su perfil.
  3. Las etiquetas de oclusión nuevas (`Texts.get_text(...)`) registradas en `data/textos.es.json`.
  4. Capturas del escenario añadidas a `./tools/run_evidence.sh`.
