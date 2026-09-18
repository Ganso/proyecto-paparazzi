# Especificación Futura: Mecánicas de Barrido (Panning) y Previsualización Óptica

Este documento especifica la implementación técnica de dos dinámicas visuales avanzadas introducidas en el documento fundacional de 2012 ([PROYECTO_PAPARAZZI_2012.md](../origen/PROYECTO_PAPARAZZI_2012.md)): el **barrido fotográfico (*panning*)** y la **previsualización en vivo de profundidad de campo (*DoF preview*)**.

---

## 1. El Barrido Fotográfico (*Panning*)

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
- Al mantener pulsado el botón de previsualización (o tecla asignada, ej. `Barra Espaciadora` o botón virtual en visor táctil):
  1. Se calcula el mapa de CoC para la apertura de trabajo fijada ($f/8, f/11$, etc.).
  2. El shader del visor actualiza en tiempo real el desenfoque de los carriles anterior y posterior.
  3. La luminancia del visor se atenúa ligeramente (como en un visor óptico réflex real) o se compensa con ganancia electrónica (visor EVF digital).

---

## 3. Beneficios Pedagógicos y de Jugabilidad
1. **Entrenamiento de pulso**: Enseña al jugador a seguir con cadencia fluida a los corredores y ciclistas.
2. **Control creativo**: El jugador decide conscientemente si aislar al objetivo mediante velocidad rápida ($1/1000\text{ s}$ congelado) o mediante barrido artístico ($1/30\text{ s}$ estriado).
