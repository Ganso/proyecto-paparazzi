# Equipamiento, Ópticas e Instrumentación — Proyecto Paparazzi

Este documento detalla los cuerpos de cámara, el catálogo de objetivos, el sistema de película analógica y la instrumentación del visor HUD definidos en [scripts/equipment.gd](../scripts/equipment.gd) y [scripts/viewfinder.gd](../scripts/viewfinder.gd).

---

## 1. Cuerpos de Cámara

El simulador define 3 cuerpos (`Equipment.CAMERAS`). Todos comparten el mismo sensor de referencia de **36 mm de ancho** (formato completo): las focales se expresan siempre como equivalentes de 35 mm.

| Característica | Compacta (`body = 0`) | Telemétrica (`body = 1`) | Réflex (`body = 2`) |
|---|:---:|:---:|:---:|
| **Objetivos** | Zoom 24–120 o fijo 35 | Fijos 35 / 50 / 90 | Zoom 24–105, zoom 70–200 o fijos 50 / 28 / 105 / 135 |
| **Modos de foco** (`focus_modes()`) | AF matricial, AF puntual, MF | **Solo MF** | AF matricial, AF puntual, MF |
| **Ayuda en MF** (`focus_aid.gdshader`) | Imagen partida circular (ayuda digital) | Parche rectangular de doble imagen superpuesta | Imagen partida circular |
| **Exposición** | Automática o manual | Automática o manual | Automática o manual |

### Preajustes de la pantalla «Elige tu equipo» (`Equipment.preset()`)

| Preajuste | Cuerpo | Foco | Exposición |
|---|---|---|---|
| **Fácil · todo automático** | Compacta | AF matricial | Automática |
| **Calle · telemétrica manual** | Telemétrica | MF | Manual |
| **Acción · réflex AF puntual** | Réflex | AF puntual | Manual |

Tras elegir un preajuste, la sección «Selección manual de equipo» permite cambiar por separado cuerpo, objetivo, modo de foco, exposición (manual/automática) y soporte (digital/carrete).

---

## 2. Catálogo de Objetivos (`Equipment.LENSES`)

$\text{HFOV} = 2\arctan(36 / 2f)$ con el ancho de sensor fijo de 36 mm.

| Cuerpo | Objetivo | Focal | Apertura máx. | Apertura mín. (`stop`) | HFOV |
|---|---|:---:|:---:|:---:|:---:|
| Compacta | Zoom 24–120 · f/2.8–5.6 | 24–120 mm | f/2.8 (24 mm) → f/5.6 (120 mm) | f/8 | 73.7° – 17.1° |
| Compacta | Fijo 35 · f/2.8 | 35 mm | f/2.8 | f/8 | 54.4° |
| Telemétrica | Fijo 35 · f/2 | 35 mm | f/2 | f/16 | 54.4° |
| Telemétrica | Fijo 50 · f/1.4 | 50 mm | f/1.4 | f/16 | 39.6° |
| Telemétrica | Fijo 90 · f/2.8 | 90 mm | f/2.8 | f/22 | 22.6° |
| Réflex | Zoom 24–105 · f/4 | 24–105 mm | f/4 (constante) | f/22 | 73.7° – 19.5° |
| Réflex | Zoom 70–200 · f/2.8 | 70–200 mm | f/2.8 (constante) | f/22 | 28.8° – 10.3° |
| Réflex | Fijo 50 · f/1.8 | 50 mm | f/1.8 | f/22 | 39.6° |
| Réflex | Fijo 28 · f/2.8 | 28 mm | f/2.8 | f/22 | 65.5° |
| Réflex | Fijo 105 · f/1.8 | 105 mm | f/1.8 | f/22 | 19.5° |
| Réflex | Fijo 135 · f/2 | 135 mm | f/2 | f/22 | 15.2° |

Los tres últimos fijos se añadieron el 30-09-2026 para la Academia ([futuro/06](futuro/06_MODO_TUTOR_ACADEMIA.md)): el 28 mm para la perspectiva angular, el 105 mm f/1,8 para el desenfoque de fondo y el 135 mm para la compresión de planos.

En zooms de apertura variable, la apertura máxima se interpola linealmente con la focal (`Equipment.apertures(focal)`) y solo se ofrecen los pasos de `STOPS` que quedan dentro del rango del objetivo.

---

## 3. Escalas de Parámetros Fotográficos

### 3.1 Aperturas de Diafragma (`Equipment.STOPS`)
$$f/1.4 \;\cdot\; f/1.8 \;\cdot\; f/2 \;\cdot\; f/2.8 \;\cdot\; f/4 \;\cdot\; f/5.6 \;\cdot\; f/8 \;\cdot\; f/11 \;\cdot\; f/16 \;\cdot\; f/22$$

Cada objetivo expone solo el subconjunto comprendido entre su apertura máxima y su `stop`. (`Photo.APERTURES` existe en `photography.gd` pero la interfaz usa `Equipment.STOPS`.)

### 3.2 Tiempos de Obturación (`Photo.DENOMINATORS`)
$$\tfrac{1}{1000} \;\cdot\; \tfrac{1}{500} \;\cdot\; \tfrac{1}{250} \;\cdot\; \tfrac{1}{125} \;\cdot\; \tfrac{1}{60} \;\cdot\; \tfrac{1}{30} \;\cdot\; \tfrac{1}{15} \;\cdot\; \tfrac{1}{8}\text{ s}$$

### 3.3 Sensibilidad ISO y Carrete (`Photo.ISOS`)
$$\text{ISO } 100 \;\cdot\; 200 \;\cdot\; 400 \;\cdot\; 800 \;\cdot\; 1600 \;\cdot\; 3200$$

- **Soporte digital** (`equipment.film = false`): ISO libre con las teclas `C`/`V`.
- **Carrete** (`equipment.film = true`): se carga una película de ISO fijo (`film_iso_index`, por defecto ISO 400). El botón de ISO queda deshabilitado (`iso_button.disabled`) y la exposición automática solo ajusta apertura y velocidad, conservando el ISO de la película (`main.gd::auto_expose()`).

### 3.4 Medición, Exposición Automática y Compensación (±EV)
- **Medición TTL**: El exposímetro mide la luz incidente en el punto de la escena bajo el colimador activo (`park.illumination_ev()`); si el rayo no toca nada, usa `park.sky_ev()`. También con exposición automática: ningún automatismo mide sobre el objetivo del encargo.
- **Compensación de Exposición (±EV)**: En exposición automática, el usuario dispone de un control interactivo de compensación en el HUD superior (`exposure_button`), con un rango de $\pm 2.0\text{ EV}$ en pasos de $1/3$ de paso (`Equipment.EV_COMPENSATIONS`):
  $$\text{Compensación } \in \{-2.0, -1.7, -1.3, -1.0, -0.7, -0.3, 0.0, +0.3, +0.7, +1.0, +1.3, +1.7, +2.0\}\text{ EV}$$
  - **Interacción**: Clic izquierdo (subir) / clic derecho (bajar), rueda del ratón (`WHEEL_UP` / `WHEEL_DOWN`), arrastre horizontal o atajos de teclado (`[` / `]` y `-` / `+`).
  - **Efecto Óptico y Revelado**: La compensación modifica el valor objetivo (`target_ev = measured_ev - compensation`), obligando al resolvedor simplex a escoger exposiciones intencionadamente más claras o más oscuras. La aguja `delta_ev` del visor refleja la desviación exacta y el shader de revelado químico (`develop.gdshader`) escala la luminancia de los píxeles proporcionalmente con $\exp2(\text{compensación})$.
- **Optimizador Simplex**: En modo automático, `auto_expose()` recorre todas las combinaciones apertura × velocidad × ISO y minimiza una función de coste que prioriza el error respecto al EV objetivo compensado, luego evitar trepidación ($t > 1/f$), después ISO bajo y finalmente aperturas abiertas.
- **Los automatismos no conocen al objetivo** (corregido el 30-09-2026, [futuro/12 §2.1](futuro/12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md)): el AF matricial (`select_matrix_point()`) elige, entre los colimadores que tocan a alguien, el más cercano al centro del encuadre (en empate, la persona más próxima a la cámara); sin nadie, el decorado más cercano. Antes elegía al objetivo antes que a nadie y lo delataba al barrer el parque. Lo comprueba `tests/test_automatisms.gd`.
- **Modos Futuros de Fotometría y AF**: La especificación técnica completa de medición matricial/evaluativa, puntual ligada al colimador, ponderada al centro, y modos AF-S, AF-C predictivo y seguimiento inteligente se encuentra en [docs/futuro/12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md](futuro/12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md).

---

## 4. Instrumentación del Visor HUD (`viewfinder.gd`)

```
+-------------------------------------------------------------------+
|                  -2   -1    0   +1   +2           [batería]       |
|                  |||||              (decorativa)   |
|                            ^ aguja ΔEV                            |
|   ┌─                                                        ─┐   |
|                [ ]        [ ]        [ ]                          |
|                [ ]        [■]        [ ]   <- 9 colimadores      |
|                [ ]        [ ]        [ ]                          |
|   └─                                                        ─┘   |
+-------------------------------------------------------------------+
```

1. **Marcas de esquina**: cuatro escuadras que delimitan el área útil del visor.
2. **9 colimadores AF/medición** (cuadrícula 3×3, teclas `1`–`9`):
   - En **AF matricial** se dibujan los 9; en **AF puntual** solo el activo; en **MF** ninguno.
   - El activo se dibuja en verde. Al enfocar parpadea en **blanco** si el AF confirma y en **naranja** si falla.
3. **Guías de tercios** (tecla `G`): solo ayuda visual. La bonificación de tercios de la puntuación se calcula aparte en `Photo.evaluate()`.
4. **Exposímetro**: escala de −2 a +2 EV con aguja. Verde si $|\Delta EV| \le 0.5$ y ámbar en caso contrario.
5. **Enfoque manual táctil y gradual (MF)** (`focus_aid.gdshader`, centro del visor):
   - **Controles continuos y micro-pasos**: Rueda del ratón con paso fino (~0.0035 dioptrías, ~8 micro-pasos dentro de la profundidad de campo de un 90 mm a f/2.8), `Shift + rueda` para micro-enfoque quirúrgico (0.0012 dioptrías), `Ctrl + rueda` para barrido rápido, pulsación continua mantenida de teclas `R` y `T`, y **arrastre con botón derecho del ratón** para girar físicamente el anillo de enfoque de forma 1:1 analógica y continua.
   - **Estabilización de muestreo de parche**: El telémetro evalúa el área del parche central a 60 fps con amortiguamiento exponencial continuo, priorizando sujetos humanos y eliminando saltos bruscos o parpadeos al rotar la cámara.
   - **Bloqueo de colimador en MF**: En enfoque manual, el clic de paneo no altera el punto de enfoque activo ni descalibra el exposímetro.
   - **Confirmación óptica de coincidencia**: Al alinear las dos imágenes dentro de la profundidad de campo, el marco del parche se ilumina en verde dorado (`#b8d78c`) y el indicador confirma `MF · foco alineado` con un sutil clic mecánico de retén.
   - Réflex y compacta: círculo de imagen partida; las mitades superior e inferior se desplazan en sentidos opuestos.
   - Telemétrica: parche rectangular teñido con la doble imagen superpuesta.

---

## 5. Verificación Automatizada

Suite `tests/test_equipment.gd` (headless). Comando, volumen y criterios en [TESTS_Y_VERIFICACION.md](TESTS_Y_VERIFICACION.md).

---

## Visores realistas por cuerpo (01-10-2026)

Con la interfaz de cámara (por defecto en escritorio; se cambia en Equipo), cada cuerpo enseña su visor: la réflex un ocular de goma con pantalla esmerilada y LED rojos de 7 segmentos; la telemétrica un visor brillante y nítido con marco de líneas corregido por paralaje y exposímetro ▶ ● ◀; la compacta su pantalla LCD trasera con iconos. Los controles se pliegan y aparecen con Tab o llevando el ratón al borde. Nada de esto toca la foto ni la nota. Detalle en [futuro/07 §5](futuro/07_VISORES_REALISTAS_Y_MOVIL.md).

