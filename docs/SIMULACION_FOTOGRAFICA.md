# Simulación Fotográfica y Evaluación Determinista — PhotoHacks

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

## 9. El obturador virtual: la foto como promedio de fotogramas (07-10-2026, usuario)

Encargo: «que la fotografía resultante tenga el máximo realismo posible tanto en OpenGL como en Vulkan; el jugador nos puede perdonar que tardemos unos milisegundos más en presentarla». Hasta ahora la foto era **un fotograma** retocado después: el movimiento era un arrastre de la imagen entera (o de todo menos un rectángulo, en el barrido), la profundidad de campo real solo existía en Alto y Ultra (en Bajo, Medio, Android y web la foto entera se emborronaba por igual, y un fondo desenfocado conseguido salía nítido) y la exposición se multiplicaba sobre la imagen ya comprimida a 8 bits.

### 9.1 Cómo se hace ahora (`main.gd::expose_photo()`)

Mientras el obturador está abierto el juego renderiza entre 8 y 64 fotogramas y los promedia en luz lineal, que es lo que hace un sensor:

| Qué | Cómo |
|---|---|
| **Movimiento** | Entre fotograma y fotograma el mundo avanza una fracción del tiempo de obturación (`advance_world()`) y la cámara sigue girando si se estaba barriendo (`shot_omega`). Salen solos el barrido (silueta exacta, sin halo), la estela semitransparente con el fondo nítido, los brazos y piernas más movidos que el tronco, las palomas en vuelo |
| **Trepidación** | El pulso es un vaivén real de la cámara durante la exposición (dos ondas lentas en cada eje, por la semilla del disparo), con la misma amplitud que antes (`shake_pixels()`); ninguno en un barrido o una estela |
| **Profundidad de campo** | Cada fotograma se toma desde otro punto de la abertura del diafragma (radio real, focal / 2N) desplazando la cámara y descentrando el frustum (`Camera3D.set_frustum()`) para que el plano de enfoque no se mueva. Desenfoque óptico con bordes y oclusiones correctos, **igual en todos los perfiles y en los dos renderizadores** |
| **Antialiasing** | Cada fotograma va desplazado una fracción de píxel |
| **Exposición** | Se aplica en la curva de tonos del propio renderizador (`Environment.tonemap_exposure` × 2^−ΔEV) durante esos fotogramas, no multiplicando después: lo que se quema, se quema donde de verdad está la luz |

- **Acumulación**: un `SubViewport` 2D en coma flotante (`use_hdr_2d`) que no se borra entre fotogramas dibuja el visor encima con peso 1/(k+1) (`shaders/photo_accumulate.gdshader`); otro lo pasa a sRGB con medio escalón de ruido para que el cielo no haga bandas (`shaders/photo_resolve.gdshader`). En OpenGL el fotograma llega codificado en sRGB y se decodifica; en Forward+ el lienzo HDR ya lo entrega lineal (`decode`).
- **Cuántos fotogramas** (`photo_samples()`): los que pide el arrastre o el desenfoque más largo de esa foto, 8 como mínimo y como máximo 64 en Ultra, 48 en Alto, 32 en Medio y en OpenGL de escritorio, 24 en Bajo, móviles y grabaciones, 16 en la web (`photo_samples_cap()`).
- **Tiempo**: unos 8 ms por fotograma en Forward+ (Ultra, RX 6700 XT) y 4 ms en OpenGL: de 0,1 a 0,5 s por foto. Durante la exposición se desactiva la sincronía vertical y el tope de FPS (en escritorio) y el visor queda en negro (`curtain`).
- **La nota no cambia**: se decide antes, con la evidencia del instante del disparo (`capture_evidence()`). Solo cambia la imagen. El revelado (`photo_material()`) ya no añade desenfoque, arrastre, trepidación ni exposición a una foto expuesta así (`evidence.exposed`): pone el objetivo (viñeteo, aberración) y el ruido.
- **Pruebas y herramientas** que arrancan el juego desde su propio guion (`--script`) hacen la foto con **un fotograma**, como antes, para no tardar más; `PAPARAZZI_PHOTO_SAMPLES=N` o `Main.photo_samples_override` lo cambian.

### 9.2 Lo que hubo que resolver

- `RenderingServer.force_draw()` renderiza varias veces en un mismo fotograma (5 ms cada una), pero **no aplica los cambios de posición ni de esqueleto**, que Godot reparte al final de cada vuelta del bucle: cada muestra es un fotograma real del motor (`await RenderingServer.frame_post_draw`), con el `_process()` del juego detenido (`exposing`).
- Los nodos del acumulador necesitan una vuelta del bucle antes de la primera muestra para que su lienzo exista.
- El visor y el acumulador se dibujan en el mismo fotograma en ese orden (comprobado: una muestra con la vista girada sale girada).

### 9.3 Ruido

`shaders/develop.gdshader`, en luz lineal: **sensor** (cuerpos digitales), ruido de fotones que crece con la raíz de la luz más un suelo que asoma en las sombras, la mitad de color; **película** (`film`), grano en racimos de dos o tres píxeles, sin color, presente ya a ISO 100. Los dos crecen con la sensibilidad.

### 9.4 Pruebas y evidencias

`tests/test_finders.gd` (en Vulkan y en OpenGL): bajo una prueba la foto es de un fotograma; con doce, la cámara, la exposición de la escena, la sincronía vertical y el tope de FPS quedan como estaban, el revelado no añade nada, y **una escena quieta y bien expuesta sale igual que el fotograma único**. `PAPARAZZI_PHOTO_SAMPLES=64 SOLVER_SHOTS=<carpeta> tools/arcade_solver.gd` guarda el resultado de cada nivel con la foto de verdad.

### 9.5 El cristal (07-10-2026)

Lo que el objetivo y el soporte hacen con la imagen, en el revelado (`shaders/develop.gdshader`, `main.gd::photo_material()`), igual en los dos renderizadores. Los datos salen de `main.gd::lens_evidence()` al disparar (dónde está el sol y si llega al objetivo, qué farolas encendidas se ven): **solo para la imagen, nunca para la nota**.

| Efecto | Cuándo | Cómo |
|---|---|---|
| **Velo y resplandor del sol** | De día y a la hora dorada, con el sol dentro del encuadre o cerca y sin nada que lo tape | Una capa de su propia luz sobre toda la foto (menos contraste, sombras levantadas), más fuerte hacia él, y su resplandor donde está; se apaga al salir del encuadre. Más fuerte a la hora dorada |
| **Estrellas en las farolas** | Desde f/11, largas a f/22 | Seis puntas en cada luz puntual visible (`lights`, hasta 12) |
| **Forma del desenfoque** | Al cerrar el diafragma un paso o más | El muestreo de la abertura del obturador virtual pasa de círculo a polígono de siete láminas (`blade_reach()`) |
| **Difracción** | Por encima de f/11 | Una ligera pérdida de nitidez general (algo más de un píxel a f/22) |
| **Distorsión** | Según la focal | Barril en angular (máxima a 24 mm), un poco de cojín en tele |
| **Halación** | Con carrete | Resplandor rojizo alrededor de lo que se quema |

Evidencias en `docs/evidencias/foto/`.

### 9.6 Pendiente

Balance de blancos (película de luz día bajo farolas) · «ojo de gato» del desenfoque en las esquinas · un fundido entre muestras para los desenfoques muy grandes, donde 24 fotogramas todavía se adivinan.
