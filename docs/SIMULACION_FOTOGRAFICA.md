# Simulación Fotográfica y Evaluación Determinista — Proyecto Paparazzi

Este documento describe las leyes ópticas, el cálculo fotométrico, los shaders de revelado químico y el algoritmo determinista de calificación implementados en [scripts/photography.gd](file:///home/ganso/codigo/afotando/scripts/photography.gd).

---

## 1. Óptica Geométrica y Círculo de Confusión (CoC)

El juego modela el comportamiento óptico de una lente delgada sobre un sensor de **formato completo (36 × 24 mm)** con un círculo de confusión estándar admisible de **$c_{\text{adm}} = 0.030\text{ mm}$**.

### 1.1 Fórmula del Círculo de Confusión
Dado un objetivo con distancia focal $f$ (en mm), número f/apertura $N$, enfocado a una distancia $s$ (en metros) para un sujeto situado a distancia $d$ (en metros):

$$c = \frac{f^2}{N \cdot (s \cdot 1000 - f)} \cdot \frac{|d - s| \cdot 1000}{d \cdot 1000} \quad (\text{mm})$$

En `photography.gd`:
```gdscript
static func coc(focal_mm: float, aperture: float, focus_dist_m: float, subject_dist_m: float) -> float:
    var s = focus_dist_m * 1000.0
    var d = subject_dist_m * 1000.0
    var f = focal_mm
    var num = f * f * absf(d - s)
    var den = aperture * (s - f) * d
    return num / den
```

### 1.2 Distancia Hiperfocal y Profundidad de Campo
- **Distancia Hiperfocal ($H$)**:
  $$H = \frac{f^2}{N \cdot c_{\text{adm}}} + f$$
- **Límite cercano de foco nítido ($D_{\text{near}}$)**:
  $$D_{\text{near}} = \frac{s \cdot (H - f)}{H + s - 2f}$$
- **Límite lejano de foco nítido ($D_{\text{far}}$)**:
  $$D_{\text{far}} = \frac{s \cdot (H - f)}{H - s}$$

---

## 2. Fotometría y Triángulo de Exposición

### 2.1 Ecuación del Valor de Exposición ($EV$)
La relación entre apertura ($N$), tiempo de obturación ($t$ en segundos) y sensibilidad ISO ($S$) se rige por:

$$EV_{100} = \log_2\left(\frac{N^2}{t}\right)$$
$$EV_S = EV_{100} - \log_2\left(\frac{S}{100}\right)$$

### 2.2 Fuentes de Luz en el Parque
- **Día despejado**: $EV = 14.0$ (Sol directo alto).
- **Paso de nube**: Atenúa la luz solar en aproximadamente **$3.0\text{ EV}$** ($EV \approx 11.0$).
- **Noche bajo farola**: $EV = 4.0$ a $6.0$ dependiendo de la distancia radial a la luminaria.
- **Noche en sombra**: $EV \approx 1.5 - 2.5$.

---

## 3. Trepidación y Desenfoque por Movimiento

### 3.1 Movimiento del Sujeto
El desplazamiento angular y lineal del sujeto durante el tiempo de obturación $t$ proyecta una estela en el sensor:
$$\text{desenfoque}_{\text{sujeto}} = \frac{v_{\text{relativa}} \cdot t \cdot f}{d} \quad (\text{mm})$$

### 3.2 Trepidación de la Cámara (Pulso del Fotógrafo)
Sigue la regla empírica clásica de la fotografía manual:
$$t_{\text{segura}} \le \frac{1}{f\text{ (mm)}}$$
Si el tiempo de obturación supera $1 / f$ sin apoyo, se calcula una penalización por trepidación angular proporcional a $t \cdot f$.

---

## 4. Shaders de Revelado y Ayuda Óptica

### 4.1 Revelado Químico (`shaders/develop.gdshader`)
Al capturar la fotografía, la imagen del Viewport no se guarda en bruto, sino que se procesa a través de un shader de simulación química analógica:
1. **Desenfoque Óptico de CoC**: Muestreo en disco (*bokeh*) cuyo radio de dispersión en píxeles corresponde al valor calculado de CoC.
2. **Desenfoque de Movimiento**: Muestreo direccional orientado en el vector de velocidad proyectada de cada sujeto.
3. **Grano de Haluro de Plata**: Simulación de ruido analógico proporcional a la sensibilidad ISO de la película ($S = 100 \rightarrow \text{fino}$, $S = 1600 \rightarrow \text{grano pronunciado}$).
4. **Curva Característica Sensitométrica**: Respuesta no lineal (curva Hurter & Driffield con hombro y pie suaves para luces y sombras).

### 4.2 Ayuda de Enfoque Telemétrica / Microprisma (`shaders/focus_aid.gdshader`)
Renderiza en el centro del visor:
- **Círculo de imagen partida**: Divide la mitad superior e inferior de la escena horizontalmente; si el objeto está desenfocado, las dos mitades se desplazan lateralmente.
- **Corona de microprismas**: Produce un patrón de fractura visual cuando la imagen no coincide en foco exacto.

---

## 5. Algoritmo Determinista de Calificación (`Photo.evaluate`)

Al disparar, se genera un diccionario inmutable de evidencia (`evidence`) con todas las variables físicas. La función `Photo.evaluate(evidence)` produce una calificación matemática entre **0 y 100 créditos**:

```
+-------------------------------------------------------------+
|               FACTORES DE CALIFICACIÓN (0 - 100)            |
+-------------------------------------------------------------+
  1. Sujeto Correcto (Condición previa obligatoria):
     - Si la persona fotografiada NO coincide con el encargo -> 0 puntos (Rechazada).
  
  2. Nitidez y Enfoque (Hasta 35 puntos):
     - CoC <= 0.030 mm -> 35 puntos (máxima nitidez).
     - CoC > 0.030 mm  -> Penalización cuadrática en función del radio de confusión.
  
  3. Encuadre y Composición (Hasta 25 puntos):
     - Posición del sujeto respecto a los puntos áureos / regla de los tercios.
     - Altura de cabeza (*headroom*) equilibrada en el tercio superior.
     - Proporción del sujeto en el encuadre (ni excesivamente lejos ni cortado).
  
  4. Exposición Fotométrica (Hasta 20 puntos):
     - Error Delta EV = |EV_medido - EV_exposicion|
     - |Delta EV| <= 0.3 EV -> 20 puntos (exposición clavada).
     - Penalización por sobreexposición (altas luces quemadas) o subexposición (ruido).
  
  5. Ausencia de Trepidación (Hasta 20 puntos):
     - Desplazamiento por obturación lenta por debajo del umbral visible.
  
  6. Descuento por Oclusión Física (0 a -50 puntos):
     - 5 rayos físicos directos lanzados desde la cámara hacia:
       cabeza, tórax, cintura, rodilla y pies.
     - Rayos que colisionan con farolas, bancos, árboles u otros viandantes
       reducen la puntuación proporcionalmente.
```

---

## 6. Verificación Automatizada

```bash
# Verificación de fórmulas ópticas, triángulo de exposición, CoC y determinismo (535 checks)
godot-4 --headless --path . --script tests/test_photography.gd
```
