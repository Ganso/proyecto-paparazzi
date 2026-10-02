# Especificación Futura: Variedad Procedural de Vegetación y Personajes

Este documento especifica la generación procedural de árboles, arbustos, césped y personajes para multiplicar la variedad visual sin modelar a mano ni romper los invariantes del proyecto. Complementa a [02](02_ESTILO_VISUAL_Y_POLIGONOS.md) (estilo y perfiles gráficos) y se apoya en el parque fusionado del [paso 1](16_PARQUE_ILUSTRADO_QUICK_WIN.md).

---

## 1. Punto de Partida

| Elemento | Hoy | Límite de variedad |
|---|---|---|
| **Cuerpos** | 4 perfiles fijos (`estandar`, `delgado`, `robusto`, `nino`) con altura, hombros y zancada constantes | Todos los adultos estándar miden exactamente 1,75 m |
| **Prendas** | 5 torsos, 6 piernas, 8 cabezas, 3 accesorios, generados offline por `tools/build_catalog.py` en `data/piezas/` (92 JSON) | 2.880 ensamblajes geométricos (`test_art.gd`) |
| **Color** | 10 colores de ropa, 5 de pelo, 4 de calzado, 4 acabados de madera | Prendas lisas de un solo color |
| **Marcha** | `gait.gd` analítico con velocidad aleatoria en la banda de caminantes o corredores | Mismo estilo de paso para todos |
| **Árboles** | 4 especies (`park.gd::build_tree`) con jitter de rotación, escala, inclinación, racimos y color | Siluetas reconocibles como la misma especie repetida 66 veces |
| **Arbustos** | Esferas facetadas de 7 segmentos | Muy homogéneos |
| **Suelo** | Anillos de color plano | Sin variación |

---

## 2. Principios Obligatorios

1. **Determinismo por semilla**: todo se genera a partir de una semilla (la de `Casting` para personas y una `park_seed` para el parque). La misma semilla produce la misma geometría, bit a bit, y la misma puntuación (AGENTS.md §3.5).
2. **Todo rasgo visible debe poder nombrarse**: el briefing describe al objetivo con palabras. Cada variante que distinga a una persona se cuantiza en valores con nombre registrados en `data/textos.es.json` («manga larga», «falda larga», «de rayas»). La variación continua solo se usa para lo que **no** entra en los predicados (altura exacta, proporciones, estilo de paso).
3. **Legibilidad a distancia de foto**: dos colores con nombre distinto deben separarse al menos $\Delta E_{00} \ge 20$ bajo la luz de día, hora dorada y noche de farola. Si no, el jugador no puede distinguir lo que el briefing le pide.
4. **Ética**: el acabado de madera (`madera_por_tono`) sigue sin entrar en los predicados. La variación morfológica no crea «tipos» nombrables asociados a ningún colectivo: los predicados de cuerpo siguen siendo los cuatro perfiles actuales.
5. **Invariantes técnicos**: 20 huesos, pesos rígidos 1.0, pie de apoyo sin deslizamiento, bandas de velocidad y presupuestos del perfil gráfico activo ([02 §10.2](02_ESTILO_VISUAL_Y_POLIGONOS.md)). La vegetación extra por perfil cumple la regla de coherencia de [02 §10.3](02_ESTILO_VISUAL_Y_POLIGONOS.md): fuera de la zona jugable o por debajo de 0,3 m.
6. **Colores de vértice y un material**: todo lo generado emite `ARRAY_COLOR` y se fusiona según el paso 1. En el canal alfa, 0 indica «sin contorno», el mismo convenio que ya usa `cel_outline.gdshader`.

---

## 3. Vegetación Procedural

### V1 · Árboles por gramática de especies
Cada especie es un conjunto de parámetros, no un modelo:

```gdscript
const SPECIES = {
    "platano":  {"trunk_h": [2.2, 3.0], "trunk_r": [0.16, 0.22], "lean": 3.0, "levels": 2, "branches": [2, 3],
                 "branch_angle": [35, 50], "crown": "lobes", "lobes": [5, 8], "lobe_r": [0.8, 1.2],
                 "palette": ["486b33", "577a3d", "3d5a2a"], "bark": "moteado"},
    "pino_pinonero": {"trunk_h": [3.5, 4.5], "crown": "parasol", "lobes": [6, 9], ...},
    "abedul":   {"trunk_r": [0.08, 0.11], "bark": "blanco", "crown": "columnar", ...},
    "sauce":    {"crown": "llorón", ...},   # ramas colgantes: enmarcado de la capa −1 de 02 §5
}
```

- **Construcción**: tronco como *loft* curvado (la misma primitiva que `build_catalog.py`) → ramas por recursión de 2–3 niveles con ángulos y longitudes muestreados → copa de lóbulos facetados (icosferas con desplazamiento de vértices por ruido) en los extremos de las ramas.
- **Catálogo objetivo**: de 4 a unas **10 especies**: plátano, roble, tilo, arce, ciprés, pino piñonero, abedul, sauce llorón, magnolia y cerezo en flor.
- **Estaciones**: cada especie define paletas de primavera, verano y otoño. La sesión elige una estación por semilla, y la hora dorada gana mucho con el otoño.
- **LOD por perfil**: número de lóbulos y subdivisión de icosfera (Bajo: icosfera 0 y pocos lóbulos; Ultra: icosfera 2 y hojas sueltas). El colisionador es siempre el mismo (cilindro de tronco más esfera de copa), independiente del perfil.
- **Presupuesto orientativo por árbol**: 250 triángulos en Bajo/Medio, 800 en Alto y 3.000 en Ultra. Los 66 árboles actuales caben en 16.500 triángulos en móvil.

### V2 · Arbustos, setos y parterres
- Arbustos como racimos de 3–7 icosferas con desplazamiento, fusionados y con oclusión horneada en la base.
- Setos topiarios (cajas redondeadas por ruido) en el perímetro $r \approx 13.4\text{ m}$.
- Parterres de las jardineras ($r = 9.7\text{ m}$) con flores de colores por semilla.

### V3 · Césped y suelo
- **Todos los perfiles**: variación cromática del césped por ruido de baja frecuencia en los colores de vértice y bordillos claros en los paseos (mejora G2 de [02 §11](02_ESTILO_VISUAL_Y_POLIGONOS.md)).
- **Alto y Ultra**: matas de hierba y flores con `MultiMeshInstance3D` (color por instancia y viento en el shader), excluidas de las calzadas `LANE_BOUNDS` y por debajo de 0,3 m.

---

## 4. Personajes Procedurales

### P1 · Color con nombre y estampados por anillos (bajo coste, gran variedad)
- **Paleta ampliada** de 10 a unos **16 colores con nombre** (naranja, rosa, morado, turquesa, mostaza, caqui…), validados con la regla $\Delta E_{00} \ge 20$ del §2.
- **Combinaciones armónicas**: reglas de neutro más acento para que el conjunto no resulte aleatorio.
- **Estampados de rayas gratis**: las prendas son *lofts* de anillos, así que alternar el color de vértice por anillo da **rayas horizontales** sin geometría extra. Es nombrable («camiseta de rayas azul marino y blanca») y encaja con la superficie única por personaje.

### P2 · Morfología continua dentro de cada perfil
- Parámetros por persona: altura ±6 %, anchura de hombros y caderas ±8 %, longitud de brazos y piernas ±4 %, cabeza ±5 % y volumen de torso. Se muestrean con semilla dentro de cada perfil.
- **No entran en los predicados**, que siguen siendo los cuatro perfiles (§2.2). Dan variedad sin crear categorías nuevas (§2.4).
- **Implementación**:
  1. El generador de piezas pasa de `tools/build_catalog.py` (offline) a GDScript en tiempo de ejecución, con los mismos *lofts* y la misma forma de las piezas, para escalar anillos y posiciones de reposo de los huesos.
  2. El script de Python se conserva como **oráculo de pruebas**: con la morfología neutra, la malla generada en GDScript debe coincidir con `data/piezas/`.
  3. Esto habilita también las mallas multi-LOD de [02 §10.5](02_ESTILO_VISUAL_Y_POLIGONOS.md).
- **Marcha**: `zancada` deja de ser una constante del perfil y se calcula con la longitud real de la pierna. `gait.gd` ya garantiza el pie apoyado sin deslizamiento para cualquier geometría coherente; `test_gait.gd` lo comprobará con morfologías aleatorias.

### P3 · Prendas paramétricas con variantes nombradas
- Cada familia de prenda expone parámetros cuantizados con nombre:
  - Torso: manga (sin manga, corta, larga), largo (corto, normal, largo) y ajuste (ajustado, holgado).
  - Piernas: largo de pantalón o falda (corto, rodilla, largo) y anchura de pernera.
  - Cuello: redondo, pico o camisa.
- Con 5 torsos × 3 mangas × 2 ajustes y 6 piernas × 3 largos, la variedad geométrica se multiplica por más de 10 sin modelar piezas nuevas.
- Las uniones críticas que ya comprueba `test_art.gd` (hombro contra manga, muslo contra falda, calzado) se validan en las combinaciones extremas de cada parámetro.

### P4 · Accesorios y actitudes
- Nuevos accesorios de [02 §7](02_ESTILO_VISUAL_Y_POLIGONOS.md) (mochila, bolso, gafas de sol, periódico, paraguas) como piezas rígidas paramétricas.
- **Estilo de paso** por persona dentro de la banda de velocidad: cadencia, amplitud del braceo, rebote vertical e inclinación del torso. No se nombra en el briefing, pero hace que la multitud no marche «en formación».
  - ✅ **Hecho el 02-10-2026** (braceo, codos, vaivén de hombros e inclinación): `person.gd::style` (`arm` 0,65–1,4, `sway` 0,6–1,7, `elbow` 0–0,28 rad, `lean` −0,035–0,02 rad; los corredores conservan su forma), sorteado con un generador propio para no desplazar la secuencia de velocidad, fase y actividades, y aplicado en `gait.gd::pose()`. Piernas y pies apoyados no cambian (`test_gait.gd`: deriva 0); comprobado en `test_park_life.gd`. Quedan la cadencia y el rebote vertical.

---

## 5. Rendimiento

- **Coste de arranque**: generar 21 personas y los 280 elementos vegetales en GDScript debe llevar < 300 ms en un móvil de gama media. Si no se consigue, se cachean las mallas por semilla en `user://`.
- **Draw calls**: la vegetación se fusiona en las superficies sectorizadas del paso 1 y los personajes siguen siendo una superficie cada uno, así que la variedad no añade draw calls.
- **Memoria**: sin texturas; solo crecen los búferes de vértices, dentro del presupuesto de VRAM del perfil.

---

## 6. Criterios de Aceptación y Pruebas

Nueva suite `tests/test_procedural.gd` (headless):
1. **Determinismo**: la misma semilla produce mallas con el mismo *hash* (vértices, índices y colores), tanto en árboles como en personas.
2. **Presupuestos**: cada árbol y cada persona respeta su límite en todos los perfiles, y la escena completa también.
3. **Rig**: en las morfologías extremas (todos los parámetros al mínimo y al máximo) hay 20 huesos y pesos rígidos 1.0, y se superan las comprobaciones de uniones de `test_art.gd`.
4. **Marcha**: `test_gait.gd` añade 100 morfologías aleatorias con deriva del pie de apoyo de 0.000000 m/fotograma y suela en $y = 0$.
5. **Nombres y legibilidad**: todos los colores con nombre cumplen $\Delta E_{00} \ge 20$ entre sí, y toda variante nombrable tiene su texto en `data/textos.es.json`.
6. **Unicidad**: con la paleta y las variantes ampliadas, `Casting.predicates_for()` encuentra predicados únicos de 3 rasgos en al menos el 95 % de los encargos (hoy a veces necesita 4).
7. **Vegetación y juego**: ningún elemento generado invade `LANE_BOUNDS` por debajo de 2,2 m ni tapa los puntos de control de un viandante sin tener colisionador.
8. **Oráculo**: con la morfología neutra, las piezas generadas en GDScript coinciden con `data/piezas/` dentro de una tolerancia de $10^{-5}$ m.
9. **Evidencias**: `./tools/run_evidence.sh` genera una hoja de 10 especies × 3 estaciones y un lineup de 24 personas con semillas fijas.

---

## 7. Fases y Esfuerzo

| Fase | Contenido | Esfuerzo | Impacto |
|---|---|:---:|:---:|
| 1 | P1 (paleta ampliada y rayas por anillos) y V3 en todos los perfiles (ruido del césped) | S | Alto |
| 2 | V1 y V2: árboles por gramática y arbustos, con estaciones | M | Muy alto |
| 3 | P2: generador de piezas en GDScript con oráculo y morfología continua | M-L | Alto |
| 4 | P3 y P4: prendas paramétricas, accesorios y estilo de paso | L | Alto |
| 5 | V3 en Alto y Ultra: hierba y flores instanciadas | M | Alto |

**Dependencias**: el [paso 1](16_PARQUE_ILUSTRADO_QUICK_WIN.md) (fusión con colores de vértice) antes de las fases 1, 2 y 5. La fase 3 habilita el multi-LOD de [02 §10.5](02_ESTILO_VISUAL_Y_POLIGONOS.md).
