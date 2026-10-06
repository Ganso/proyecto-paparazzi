# Especificación Futura: Mecánicas de Barrido (Panning) y Previsualización Óptica

Este documento especifica la implementación técnica de dos dinámicas visuales avanzadas introducidas en el documento fundacional de 2012 ([PROYECTO_PAPARAZZI_2012.md](../origen/PROYECTO_PAPARAZZI_2012.md)): el **barrido fotográfico (*panning*)** y la **previsualización en vivo de profundidad de campo (*DoF preview*)**.

---

## 1. El Barrido Fotográfico (*Panning*)

> **Estado (02-10-2026): ✅ implementado**: mecánica, puntuación, revelado, condición de arcade `barrido` y dos niveles que la piden ([21, bloque 5](21_ARCADE_CONDICIONES_TLR.md)). Tolerancia del sujeto: 0,075 mm (`PAN_TOLERANCE`). Con teclas, la cámara acompaña a quien cruza el centro del encuadre (`main.gd::key_turn()`).
> - **Giro de la cámara en la evidencia**: `main.gd::track_camera_turn()` mide cada fotograma cuánto gira la cámara (grados por segundo, positivo hacia la derecha, suavizado; un salto de más de 6° en un fotograma no cuenta como giro) y `take_photo()` lo guarda en la evidencia como `camera_omega` (rad/s). En las demostraciones de la Academia vale 0, para que el seguimiento del tutor no congele al corredor que enseña movido.
> - **Puntuación** (`Photography.evaluate()`): el arrastre del sujeto usa su velocidad **relativa** al barrido de la cámara, `|v·signo − ω·d|·t·f/d`; el fondo se arrastra `|ω|·t·f` mm. Es un **barrido** si el fondo se arrastra al menos 0,5 mm (`PAN_STREAK`, unos 18 px de 1.280), el sujeto queda dentro del círculo de confusión y se mueve de verdad (≥ 0,4 m/s): entonces la regla del pulso no penaliza y la línea de movimiento lo dice («Barrido: …»). Girar la cámara sobre alguien quieto emborrona la foto («Moviste la cámara…»). Sin `camera_omega` el resultado es idéntico al de antes: sigue siendo determinista.
> - **Revelado** (`shaders/develop.gdshader`, uniformes `pan` y `subject_box`): todo el fotograma se arrastra en horizontal salvo la caja del sujeto (de la cabeza a los pies de la evidencia), que conserva su propio arrastre.
> - **Cómo se hace**: con el ratón o con A/D siguiendo a quien se mueve y disparando sin dejar de girar. A 50 mm, A/D gira a unos 20°/s, casi lo que pide un corredor a 7 m (23°/s) a 1/30 s.
> - **Academia**: la lección 3 tiene una quinta página de teoría, «El barrido: al revés».
> - **Pruebas**: `tests/test_photography.gd` (cámara quieta = igual que antes; seguir al corredor lo deja nítido y arrastra el fondo; girar al revés o a media velocidad no; girar sobre alguien quieto emborrona; determinismo). El examen 3 de la Academia acepta un barrido bien hecho.

### 1.1 Fundamento Físico y Fotográfico
Cuando un sujeto se desplaza horizontalmente a una velocidad lineal $v$ a una distancia $r$, su velocidad angular respecto a la cámara es:
$$\omega_{\text{sujeto}} = \frac{v}{r}$$

Si el fotógrafo rota la cámara con una velocidad angular constante $\omega_{\text{cámara}} \approx \omega_{\text{sujeto}}$ durante el tiempo de exposición $t$ ($1/15\text{ s}$ a $1/60\text{ s}$):
- El sujeto permanece inmóvil en el plano focal: **imagen nítida**.
- El fondo estático (árboles, edificios, suelo) se desplaza a través del sensor con velocidad angular relativa $-\omega_{\text{cámara}}$: **desenfoque direccional de movimiento estriado horizontalmente**.

### 1.2 Algoritmo de Evaluación en `photography.gd`

```gdscript
# Pseudocódigo de cálculo de trepidación diferencial
func evaluate_panning(target_velocity_rad_s: float, camera_angular_speed_rad_s: float, shutter_speed: float) -> Dictionary:
    var relative_target_speed: float = abs(camera_angular_speed_rad_s - target_velocity_rad_s)
    var relative_bg_speed: float = abs(camera_angular_speed_rad_s)
    
    # Desenfoque del sujeto (en píxeles)
    var subject_motion_px: float = relative_target_speed * shutter_speed * viewport_width_px
    # Desenfoque del fondo (en píxeles)
    var bg_motion_px: float = relative_bg_speed * shutter_speed * viewport_width_px
    
    var is_good_panning: bool = (subject_motion_px <= 2.5) and (bg_motion_px >= 18.0) and (shutter_speed >= 0.015)
    return {
        "subject_sharp": subject_motion_px <= 2.5,
        "background_streaked": bg_motion_px >= 18.0,
        "is_panning": is_good_panning,
        "bonus_multiplier": 1.4 if is_good_panning else 1.0
    }
```

### 1.2.1 Prerrequisito: el motor aún no simula la exposición en el tiempo
- `take_photo()` pone `pan_velocity = 0` antes de capturar y el revelado parte de **un único fotograma**.
- `Photography.evaluate()` solo usa `e.v`, la velocidad del **sujeto** perpendicular al eje de visión. El «pulso» es la regla $t \cdot f$ y el movimiento de la cámara no interviene.
- **Trabajo necesario**:
  1. Registrar la velocidad angular de cámara de los últimos $t$ segundos (historial de `angle` y `pitch`) y guardarla en la evidencia como `camera_omega`, para que la puntuación siga siendo determinista.
  2. Pasar `camera_omega` a `evaluate_panning()`.
  3. Sintetizar el estriado en `develop.gdshader` a partir de la evidencia, porque el render es un único fotograma.
- **Coste real: medio-alto (M-L)**. Es prerrequisito de [05 §2.4](05_DESAFIOS_Y_MODOS_JUEGO.md) y del capítulo 3A de [10](10_MODO_HISTORIA_DUAL_LEGADO.md). El control más fiable para mantener una $\omega$ constante es el stick del mando ([14 §4.1](14_SOPORTE_GAMEPAD.md)).

### 1.3 Shader de Revelado con Desenfoque Direccional
Para plasmar el barrido en la evidencia fotográfica final, el shader de revelado (`develop.gdshader`) incorpora una pasada de desenfoque direccional en el eje X:
- Máscara de silueta para el sujeto (preservando su nitidez).
- Acumulación de muestras horizontales con decaimiento gaussiano para el entorno estático y otros peatones que no se muevan a la misma velocidad angular.

---

## 2. Previsualización en Vivo de Profundidad de Campo (*DoF Preview*)

### 2.1 Problemática en el Visor
En una cámara réflex real, el visor óptico muestra siempre la imagen a máxima apertura para permitir una visualización luminosa y facilitar el enfoque manual; sólo al presionar el **botón de previsualización de profundidad de campo** (o al disparar) el diafragma se cierra al valor seleccionado.

En el simulador:
- Por defecto, el visor muestra la escena nítida o con la profundidad de campo correspondiente a la máxima apertura del objetivo ($f_{\max}$).
- Al mantener pulsado el botón de previsualización (acción `previsualizar_dof` del mapa único de [14 §2](14_SOPORTE_GAMEPAD.md): gatillo izquierdo en el mando y botón 👁 del carril derecho en móvil, según [13 §2](13_INTERFAZ_MOVIL_UTILIZABLE.md); nunca `Espacio`, que es el disparador):
  1. Se calcula el mapa de CoC para la apertura de trabajo fijada ($f/8, f/11$, etc.).
  2. El shader del visor actualiza en tiempo real el desenfoque de los carriles anterior y posterior.
  3. La luminancia del visor se atenúa ligeramente (como en un visor óptico réflex real) o se compensa con ganancia electrónica (visor EVF digital).

---

## 3. Beneficios Pedagógicos y de Jugabilidad
1. **Entrenamiento de pulso**: Enseña al jugador a seguir con cadencia fluida a los corredores y ciclistas.
2. **Control creativo**: El jugador decide conscientemente si aislar al objetivo mediante velocidad rápida ($1/1000\text{ s}$ congelado) o mediante barrido artístico ($1/30\text{ s}$ estriado).

---

## 4. Implementación del DoF en Vivo por Perfil y Criterios de Aceptación

- **`gl_compatibility`** (perfiles Bajo, Medio y Alto): no ofrece desenfoque de profundidad de campo integrado, así que la previsualización debe hacerse con un shader propio que lea la textura de profundidad y aplique el CoC de `Photography.coc()`.
- **Forward+** (perfil Ultra de [02 §10](02_ESTILO_VISUAL_Y_POLIGONOS.md)): se puede usar el DoF de `CameraAttributesPractical`, **calibrado** con las distancias de `Photography.dof()` para que lo que se ve coincida con lo que se puntúa.
- **Criterios de aceptación** (ampliar `test_photography.gd` y `test_game.gd`):
  1. `evaluate_panning()` es determinista: la misma `camera_omega` da la misma nota.
  2. Con $\omega_{\text{cámara}} = \omega_{\text{sujeto}}$ a 1/30 s el sujeto queda nítido y el fondo estriado; con la cámara quieta, el sujeto queda movido.
  3. Mover la cámara durante una exposición larga sin sujeto al que seguir penaliza el pulso (hoy no ocurre).
  4. La previsualización DoF no cambia la puntuación: activarla o no da la misma nota.

## Pendiente: que el barrido y la estela se vean reales en la foto (usuario, 06-10-2026)

`shaders/develop.gdshader` arrastra **toda la imagen** con un único vector (`motion`), así que un barrido bien hecho y una estela (nivel 27 del arcade) se dibujan igual: todo el fotograma emborronado en horizontal. El informe sí los distingue; la imagen, no. Lo que falta:

- **Barrido**: el sujeto seguido debe quedar nítido y solo el fondo arrastrado (hoy se compensa en parte con `drag_sign` y el fondo arrastrado, pero sin separar sujeto y fondo píxel a píxel).
- **Estela**: al revés, el fondo nítido y solo el corredor arrastrado, con su rastro.
- Hace falta una máscara del sujeto (o un búfer de velocidades por píxel) en la captura de la foto, y que el revelado aplique el arrastre según esa máscara. Mismo criterio en Vulkan y en OpenGL, y sin cambiar la nota (`tests/test_photography.gd`, `tests/test_finders.gd`).
