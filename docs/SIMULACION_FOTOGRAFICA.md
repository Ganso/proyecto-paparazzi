# Simulación Fotográfica y Evaluación Determinista — Proyecto Paparazzi

Este documento describe las leyes ópticas, el cálculo fotométrico, los shaders de revelado químico y el algoritmo determinista de calificación implementados en [scripts/photography.gd](../scripts/photography.gd).

---

## 1. Óptica Geométrica y Círculo de Confusión (CoC)

El juego modela el comportamiento óptico de una lente delgada sobre un sensor de **formato completo (36 × 24 mm)** con un círculo de confusión estándar admisible de **$c_{\text{adm}} = 0.030\text{ mm}$**.

### 1.1 Fórmula del Círculo de Confusión
Dado un objetivo con distancia focal $f$ (mm) y número f $N$, enfocado a $s$ (m) y con el sujeto a $d$ (m):

$$c = \frac{f^2 \cdot |d - s|}{N \cdot d \cdot (s \cdot 1000 - f)} \quad (\text{mm})$$

Con enfoque a infinito ($s = \infty$): $c = \dfrac{f^2}{N \cdot d \cdot 1000}$.

En `photography.gd` (argumentos en el orden focal, número f, **distancia al sujeto**, **distancia de enfoque**):
```gdscript
static func coc(f: float, n: float, d: float, s: float) -> float:
	if is_inf(s): return f*f/(n*d*1000.0)
	return f*f*abs(d-s)/(n*d*(s*1000.0-f))
```

### 1.2 Distancia Hiperfocal y Profundidad de Campo (`Photo.dof`)
Con $s$ en mm:
- **Hiperfocal**: $H = \dfrac{f^2}{N \cdot c_{\text{adm}}} + f$
- **Límite cercano**: $D_{\text{near}} = \dfrac{H \cdot s}{H + s - f}$
- **Límite lejano**: $D_{\text{far}} = \dfrac{H \cdot s}{H - s + f}$, o $\infty$ si $H \le s - f$.

`dof()` devuelve ambos límites en metros como `Vector2(near, far)`.

---

## 2. Fotometría y Triángulo de Exposición

### 2.1 Error de Exposición (`Photo.ev`)
La función no devuelve el EV de la cámara, sino directamente el **error** entre el ajuste de la cámara y la luz medida:

$$\Delta EV = \log_2\left(\frac{N^2}{t}\right) - \log_2\left(\frac{S}{100}\right) - EV_{\text{escena}}$$

- $\Delta EV > 0$: **subexpuesta** (la cámara deja pasar menos luz de la necesaria).
- $\Delta EV < 0$: **sobreexpuesta**.
- $|\Delta EV| \le 0.5$: dentro de tolerancia (medio paso).

### 2.2 Luz de Escena (`park.illumination_ev` / `park.sky_ev`)
La luz se calcula como luz incidente en el punto medido, con rayos reales hacia el sol o las farolas (se excluye la propia geometría del sujeto):

| Situación | Cálculo | EV resultante |
|---|---|:---:|
| Día, punto al sol | $\log_2(2^{11} + 2^{14.7} \cdot T_{\text{sol}})$ | $\approx 14.8$ |
| Día, punto en sombra | $\log_2(2^{11})$ | $11.0$ |
| Día, nube completa sobre el sol ($T_{\text{sol}} = 0.09$) | igual, con transmisión reducida | $\approx 12.1$ al sol (−2.7 EV) |
| Cielo sin impacto (día) | $15 + \log_2 T_{\text{sol}}$ | $15.0 \rightarrow 11.5$ con nube |
| Noche, sin farola | $\log_2(2^{2})$ | $2.0$ |
| Noche, bajo farola ($E = 2.2$, alcance 6 m) | $2^2 + 150 \cdot E \cdot \frac{(1 - (r/6)^4)^2}{\max(0.25, r^2)}$ por farola visible | $\approx 8.4$ a 1 m · $5.2$ a 3 m · $2.9$ a 5 m |
| Cielo sin impacto (noche) | constante | $3.0$ |

$T_{\text{sol}} = \text{lerp}(1.0, 0.09, \text{cloud\_cover})$ (`park.sun_transmission()`).

---

## 3. Trepidación y Desenfoque por Movimiento

### 3.1 Arrastre del Sujeto
Con $v$ la velocidad perpendicular al eje óptico (m/s), $t$ el tiempo de obturación (s), $f$ en mm y $d$ en m:
$$\text{arrastre} = \frac{v \cdot t \cdot f}{d} \quad (\text{mm en el sensor})$$

### 3.2 Pulso del Fotógrafo
Se mide con la razón $t \cdot f$ (regla clásica $t \le 1/f$): sin penalización si $t \cdot f \le 1$ y penalización máxima a partir de $t \cdot f = 3$.

La componente de movimiento de la nota es el mínimo de ambas (ver §5).

---

## 4. Shaders de Revelado y Ayuda Óptica

### 4.1 Revelado (`shaders/develop.gdshader`)
Shader `canvas_item` aplicado a la captura del Viewport. `main.gd` le pasa estos uniformes a partir del resultado de `evaluate()`:

| Uniforme | Valor asignado en `main.gd` | Efecto |
|---|---|---|
| `coc_pixels` | $\min(\text{CoC}/36 \cdot \text{ancho} \cdot 0.5,\ 35)$ | Radio del disco de desenfoque |
| `motion` | $\min(\text{arrastre}/36 \cdot \text{ancho},\ 90)$ en horizontal, con el signo del movimiento | Estela lineal |
| `shake` | $\min(\max(0, t f - 1) \cdot 5,\ 45)$ con ángulo derivado de la semilla | Trepidación |
| `exposure` | $\Delta EV$ acotado a $[-8, 8]$ | Aclara/oscurece |
| `grain` | $\log_2(S/100) \cdot 0.035$ | Amplitud de ruido |
| `shot_seed` | número de disparo | Semilla del grano |

Funcionamiento:
1. **17 muestras en espiral** (ángulo áureo) que combinan disco de CoC, estela de movimiento y trepidación en una sola pasada.
2. **Exposición, en luz lineal** (desde el 01-10-2026): la captura se pasa de sRGB a lineal, se multiplica por $2^{-\Delta EV}$ y vuelve a sRGB. Cuando un píxel pasa del blanco, conserva su tono a plena luz y se funde hacia el blanco a medida que se quema (fundido completo 2,5 veces por encima del máximo); hasta el máximo es la identidad, así que una foto bien expuesta no cambia. Antes la exposición multiplicaba los valores ya codificados y recortaba cada canal por separado, y las fotos sobreexpuestas salían con amarillos, magentas y azules falsos.
3. **Grano**: ruido pseudoaleatorio uniforme, mayor cuanto mayor es el ISO (0 a ISO 100, 0.175 a ISO 3200).

### 4.2 Ayuda de Enfoque Manual (`shaders/focus_aid.gdshader`)
Solo visible en MF. Recibe `offset` proporcional al error de foco ($\text{error} \cdot f \cdot 0.006$, acotado a ±0.06):
- **Réflex y compacta** (`body != 1`): círculo central de imagen partida; la mitad superior se desplaza `+offset` y la inferior `−offset`, con una línea divisoria oscura.
- **Telemétrica** (`body == 1`): parche rectangular teñido donde se superpone la imagen desplazada (doble imagen).

---

## 5. Algoritmo Determinista de Calificación (`Photo.evaluate`)

Al disparar, `main.gd` construye un diccionario de evidencia (`evidence`) con todas las variables físicas; `Photo.evaluate(evidence)` es una función pura, así que la misma entrada da siempre la misma nota.

### 5.1 Componentes (cada una en $[0, 1]$)

| Componente | Fórmula | 1.0 cuando… | 0.0 cuando… |
|---|---|---|---|
| **Foco** | $\text{clamp}\left(\frac{5c_{\text{adm}} - \text{CoC}}{4c_{\text{adm}}}\right)$ | CoC ≤ 0.030 mm | CoC ≥ 0.150 mm |
| **Exposición** | $1 - \frac{\max(0,\ |\Delta EV| - 0.5)}{2.5}$ | $|\Delta EV| \le 0.5$ | $|\Delta EV| \ge 3$ |
| **Movimiento** | $\min(\text{pulso}, \text{sujeto})$; pulso $= 1 - \frac{tf - 1}{2}$; sujeto $= \frac{3c_{\text{adm}} - \text{arrastre}}{2c_{\text{adm}}}$ | $tf \le 1$ y arrastre ≤ 0.030 mm | $tf \ge 3$ o arrastre ≥ 0.090 mm |
| **Oclusión** | $(5 - \text{bloqueos}) / 5$ | 5 puntos visibles | 5 puntos tapados |
| **Encuadre** | $\text{clamp}(\text{tamaño} \cdot \text{recorte} + \text{tercios})$ | ver abajo | — |

**Encuadre**, con $h$ = altura cabeza–pies en pantalla (fracción de la altura del visor):
- *tamaño* = 1 si $h \in [0.45, 0.85]$; baja linealmente hasta 0 en $h = 0.15$ y en $h = 1.15$.
- *recorte* = 1 si cabeza y pies están dentro del encuadre; 0.6 en caso contrario.
- *tercios* = +0.15 si el pecho está a menos de 0.05 (horizontal) de una línea de tercios.

### 5.2 Oclusión física
Se lanzan **5 rayos** desde la cámara hacia los puntos de control del objetivo (`person.control_points()`): **cabeza, tórax, caderas, pierna izquierda y pierna derecha**. Un rayo cuenta como bloqueado si choca antes con cualquier cosa que no sea el propio objetivo (farolas, bancos, árboles, otros viandantes…); la etiqueta del obstáculo se muestra en el informe.

### 5.3 Rechazo, nota, estrellas y créditos
- **Rechazada** (nota 0, 0 estrellas) si el objetivo está detrás de la cámara, si su pecho queda fuera del encuadre o si **4 o más** de los 5 puntos están tapados.
- **Nota**:
$$\text{nota} = \text{round}\big(100 \cdot (0.28\,\text{foco} + 0.24\,\text{exposición} + 0.18\,\text{movimiento} + 0.15\,\text{oclusión} + 0.15\,\text{encuadre})\big)$$
- **Estrellas**: ≥ 90 → 5 · ≥ 75 → 4 · ≥ 60 → 3 · ≥ 40 → 2 · resto → 1.
- **Créditos**: $\text{round}(150 \cdot [0,\ 0.15,\ 0.35,\ 0.60,\ 0.85,\ 1.0][\text{estrellas}])$.
- Un encargo se considera **superado** con 3 o más estrellas (`main.gd`, pantalla de resumen). Cuenta la mejor de las 3 fotos del encargo.

### 5.4 Informe
`evaluate()` devuelve también `lines`: una línea por componente con su porcentaje y un consejo concreto (p. ej. la velocidad mínima `1/x s` que congelaría el movimiento, calculada recorriendo `DENOMINATORS`).

---

## 6. Verificación Automatizada

Suite `tests/test_photography.gd` (headless). Comando, volumen y criterios en [TESTS_Y_VERIFICACION.md](TESTS_Y_VERIFICACION.md).

> **Barrido (02-10-2026)**: la evidencia lleva `camera_omega` (giro de la cámara en el disparo) y el arrastre del sujeto se calcula con su velocidad relativa a ese giro; seguir a un corredor a 1/30 s lo deja nítido con el fondo arrastrado. Detalle en [futuro/11 §1](futuro/11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md).
