# Especificación Futura: Modo "Tutor de Fotografía" y Academia Interactiva

Este documento especifica la arquitectura pedagógica y los exámenes interactivos para el modo educativo **Academia de Fotografía**.

---

## 1. Filosofía Pedagógica

La mayoría de los simuladores fotográficos se limitan a mostrar valores numéricos sin enseñar la relación de causa y efecto. El modo **Academia** convierte **Proyecto Paparazzi** en un curso práctico de fotografía analógica y digital donde cada concepto se explica teóricamente y se valida inmediatamente mediante un ejercicio de disparo en tiempo real.

```
+-------------------------------------------------------------------------------+
|                       ESTRUCTURA DE CADA LECCIÓN                             |
+-------------------------------------------------------------------------------+
  1. Teoría Breve (Gráficos interactivos en visor explicando el concepto)
  2. Demostración Guiada (El juego ajusta los controles para ver el efecto)
  3. Ejercicio Práctico (El jugador debe resolver una situación real en el parque)
  4. Evaluación de Concepto (Examen con corrección física explicada)
```

---

## 2. Plan de Estudios (Currículo de 5 Lecciones)

### Lección 1: El Triángulo de Exposición (*Apertura, Velocidad e ISO*)
- **Concepto Teórico**:
  - Cómo el caudal de luz (apertura $N$), la duración de entrada (tiempo $t$) y la sensibilidad del sensor/película ($S$) deben equilibrarse para lograr $EV = 0$.
- **Demostración**:
  - Cambiar de $f/2.8$ a $f/5.6$ (cierra 2 pasos de luz) y observar cómo la aguja del exposímetro cae a $-2\text{ EV}$.
  - Compensar bajando la velocidad de $1/250\text{ s}$ a $1/60\text{ s}$ para volver a centrar la aguja en $0\text{ EV}$.
- **Examen Práctico**:
  - "El cielo se nubla repentinamente perdiendo 3 EV de luz. Ajusta el diafragma y la velocidad para que la aguja del exposímetro vuelva exactamente al centro."

### Lección 2: Profundidad de Campo y Enfoque Selectivo (*El Arte del Bokeh*)
- **Concepto Teórico**:
  - Cómo la apertura y la distancia focal controlan el espesor de la zona nítida según el círculo de confusión ($CoC \le 0.030\text{ mm}$).
- **Demostración**:
  - Enfocar al Carril 1 ($r = 4.0\text{ m}$) a $f/1.8$ con un $105\text{ mm}$ y ver el fondo ($r = 14\text{ m}$) completamente desdibujado en bokeh cremoso frente a $f/16$.
- **Examen Práctico**:
  - "Fotografía a dos personas caminando a diferentes distancias ($r = 4.0\text{ m}$ y $r = 4.7\text{ m}$) logrando que ambas salgan completamente nítidas en la misma toma (requiere cerrar diafragma a $f/8$ o $f/11$)."

### Lección 3: El Tiempo y la Captura del Movimiento (*Congelar vs. Trepidar*)
- **Concepto Teórico**:
  - La velocidad angular de los viandantes y la regla de seguridad contra la trepidación del pulso ($t \le 1/f$).
- **Demostración**:
  - Disparar a un corredor a $1/15\text{ s}$ (sujeto borroso) vs. $1/500\text{ s}$ (sujeto congelado en el aire).
- **Examen Práctico**:
  - "Captura al corredor en pleno salto sin una sola pizca de trepidación ni desenfoque de movimiento en su silueta."

### Lección 4: Composición y la Regla de los Tercios
- **Concepto Teórico**:
  - Puntos de intersección áurea del visor, espacio de aire en la dirección de la mirada (*headroom* y *lead room*).
- **Examen Práctico**:
  - "Encuadra al sujeto de modo que su rostro coincida exactamente con la intersección superior derecha de la cuadrícula mientras camina hacia la izquierda."

### Lección 5: Compresión de Planos y Elección de Óptica
- **Concepto Teórico**:
  - Diferencia entre acercarse físicamente con un $28\text{ mm}$ (perspectiva exagerada) o retroceder y disparar con un $135\text{ mm}$ (fondo comprimido y cercano).
- **Examen Práctico**:
  - "Haz que el árbol del fondo parezca gigantesco y pegado a la espalda del viandante utilizando el teleobjetivo de $135\text{ mm}$."

---

## 3. Sistema de Corrección Explicada Post-Disparo

A diferencia del modo estándar que solo otorga una puntuación numérica, el modo Tutor incluye una **devolución formativa detallada**:

```
[ INFORME DEL TUTOR FOTOGRÁFICO ]
Resultado: APROBADO CON MENCIÓN (94/100)

+ Exposición perfecta: Error de solo 0.1 EV.
+ Apertura correcta: Elegiste f/2.8, logrando aislar al sujeto del fondo.
- Ojo con la velocidad: Disparaste a 1/60s con un 105mm. Estuviste al borde
  de la trepidación (regla recomendada: mínimo 1/125s).
```

Al superar las 5 lecciones, el juego desbloquea el título **"Graduado de la Academia Fotográfica"** y concede acceso al catálogo de ópticas profesionales en el modo estándar.


---

## 5. Raíces en el Documento Fundacional (2012)
Esta especificación formaliza la propuesta 3 del documento de mayo de 2012 ([PROYECTO_PAPARAZZI_2012.md](../origen/PROYECTO_PAPARAZZI_2012.md)):
> *"Un tutor interactivo para aprender técnica fotográfica. Concepto: Simuladores de cámaras (CameraSim). El motor del juego se utiliza para demostrar en la práctica los conceptos más técnicos... y ofrecer un sistema de ayuda pedagógica interactiva."*
