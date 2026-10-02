# Especificación Futura: Soporte de Gamepad

Este documento especifica el control completo del juego con mando (Xbox, PlayStation, Switch Pro y genéricos SDL) en PC, Steam Deck y Android. Nace de la revisión del banco contra el código del 29-09-2026 y armoniza los esquemas de mando dispersos en [01 §2](01_MAPA_ABIERTO_Y_PROTAGONISTA.md), [11 §2.2](11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md) y [12 §5](12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md).

---

## 1. Diagnóstico

1. **Sin soporte**: ningún script procesa `InputEventJoypadButton` ni `InputEventJoypadMotion`.
2. **Sin `InputMap`**: `project.godot` no tiene sección `[input]`. `_unhandled_input()` compara `physical_keycode` y `_process()` consulta `Input.is_physical_key_pressed()` para el paneo, el zoom y el foco.
3. **Menús solo con puntero**: `main.gd::button()` crea todos los botones con `focus_mode = FOCUS_NONE`, así que la intro, el briefing, el equipo (`OptionButton`), los gráficos, la ayuda y el resultado no se pueden recorrer con cruceta ni con teclado.
4. **Ayudas fijas** para teclado y ratón («Foto: Espacio · Clic: AF · Rueda: zoom»).

---

## 2. Prerrequisito: Migración a Acciones de `InputMap`

Todas las entradas pasan a acciones con nombre en `project.godot`, cada una con su tecla actual **y** su evento de mando. Este es el único sitio donde se asignan controles; las especificaciones futuras (11, 12, 13) añaden acciones aquí en vez de teclas sueltas.

| Acción | Teclado (actual) | Mando | Tipo |
|---|---|---|---|
| `mirar_izquierda/derecha/arriba/abajo` | `A`/`D`, flechas | Stick izquierdo | Analógica |
| `zoom_mas` / `zoom_menos` | `W` / `S`, rueda | Stick derecho ↑/↓ | Analógica |
| `foco_cerca` / `foco_lejos` | `R` / `T`, `Shift`+rueda | Stick derecho ←/→ | Analógica |
| `disparador` | `Espacio` | Gatillo derecho (RT/R2) | **Analógica en dos fases** |
| `previsualizar_dof` (11) | por asignar (no `Espacio`) | Gatillo izquierdo (LT/L2) | Mantener |
| `enfocar` | `F` | A / ✕ | Pulsar |
| `punto de enfoque_anterior/siguiente` | `1`–`9` | LB / RB (L1 / R1) | Pulsar |
| `parametro_anterior/siguiente` | — | Cruceta ← / → (elige t, N, ISO o ±EV) | Pulsar |
| `parametro_menos/mas` | `Q`/`E`, `Z`/`X`, `C`/`V`, `[`/`]` | Cruceta ↓ / ↑ (con autorrepetición) | Pulsar |
| `cuadricula_tercios` | `G` | Clic del stick derecho (R3) | Pulsar |
| `precision` | `Shift` | Clic del stick izquierdo (L3, conmuta) | Conmutar |
| `equipo` | — | X / ▢ | Pulsar |
| `ayuda` / `atras` | `H`, `Esc` | B / ◯ | Pulsar |
| `menu` | `Esc` | Start / Options | Pulsar |

Implementación: `Input.get_vector()` para los sticks, `Input.get_action_strength("disparador")` para el gatillo y `is_action_pressed()` / `is_action_just_pressed()` en lugar de `physical_keycode`. La autorrepetición de la cruceta se hace a mano (0,35 s de retardo y luego 8 Hz), igual para teclado y mando.

---

## 3. El Gatillo como Disparador de Dos Fases

El gatillo analógico reproduce de forma natural el disparador real:

```
fuerza del gatillo:  0 ──────── 0.35 ─────────────── 0.90 ──── 1
                     reposo     │ fase 1: AF + AE-L   │ fase 2: DISPARO
                                └ vibración corta     └ vibración + sonido
```

- **Fase 1 (≥ 0,35)**: AF sobre el punto de enfoque activo (salvo en MF) y bloqueo de la medición mientras se mantenga.
- **Fase 2 (≥ 0,90)**: `take_photo()`. Si se suelta por debajo de 0,35 sin pasar a la fase 2, se cancela.
- Histéresis de 0,05 en cada umbral para evitar rebotes.
- **Misma máquina de estados que el disparador táctil** de [13 §4.1](13_INTERFAZ_MOVIL_UTILIZABLE.md) y que `Espacio` (en teclado, pulsar equivale a fase 1 y soltar a fase 2).

---

## 4. Sticks: Apuntado y Enfoque

### 4.1 Paneo e inclinación (stick izquierdo)
- Zona muerta radial de 0,15 y curva de respuesta cúbica: $\omega = \omega_{\max}\cdot\text{sign}(x)\,|x|^{3}$, con $\omega_{\max} = 42°/\text{s}\cdot 24/f$. Es la misma escala por focal que ya usa el teclado en `_process()`, así que a 200 mm el stick es 8 veces más fino que a 24 mm.
- El modo `precision` (L3) divide la velocidad por 3 para seguir a un viandante con teleobjetivo.
- La velocidad angular de cámara se registra en cada fotograma. Es el dato que necesita el barrido de [11](11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md): el stick es el control más fiable para mantener una $\omega$ constante.
- **Sin asistencia de apuntado hacia el objetivo**: frenar o atraer la mira hacia el sujeto buscado lo delataría, igual que hoy lo hace el AF matricial ([12 §2.1](12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md)). Si se añade fricción de apuntado, se aplica igual a *cualquier* viandante.

### 4.2 Enfoque manual (stick derecho, eje horizontal)
Aplica la ganancia relativa a la profundidad de campo de [13 §3.1](13_INTERFAZ_MOVIL_UTILIZABLE.md), con la inclinación del stick en lugar del desplazamiento del dedo:

$$\frac{d(1/s)}{dt} = \frac{W(f, N, s)}{\tau} \cdot \text{sign}(x)\,|x|^{2}$$

Con $\tau = 0{,}25\text{ s}$, el stick a fondo recorre 4 ventanas por segundo y, a media inclinación, una. Con L3 activo el recorrido es 4 veces más lento. La vibración de 8 ms por ventana recorrida (`Input.start_joy_vibration`) sustituye al tic háptico del móvil. Los botones de zona de [13 §3.2](13_INTERFAZ_MOVIL_UTILIZABLE.md) se recorren manteniendo LT en MF y moviendo la cruceta ↑/↓.

---

## 5. Menús Navegables

- Los botones de los modales pasan a `FOCUS_ALL` y los del HUD de búsqueda siguen en `FOCUS_NONE`, para que la cruceta no robe el foco durante la partida.
- Cada modal llama a `grab_focus()` sobre su acción principal al abrirse (`Empezar`, `Aceptar encargo`, `Siguiente foto`…) y define `focus_neighbor_*` en rejillas irregulares como la de equipo.
- El estilo `focus` se añade al tema de `style()`: un borde de 3 px con el verde `a5cc79` del visor.
- Los `OptionButton` del equipo se abren con A/✕ y se recorren con la cruceta. B/◯ cierra el modal (igual que `Esc` hoy).
- En `RESULT`, LB/RB cambian entre la foto y el informe.

---

## 6. Iconos y Textos por Dispositivo

- La interfaz sigue al **último dispositivo usado**: cualquier evento de mando cambia los iconos a mando y cualquier evento de ratón, teclado o táctil los devuelve.
- Familia de iconos según `Input.get_joy_name()` (Xbox, PlayStation, Nintendo o genérico), con los textos en `data/textos.es.json` (`ayuda_mando_xbox`, `ayuda_mando_ps`…), como exige AGENTS.md §3.5.
- En Android, un mando Bluetooth desactiva el perfil táctil de [13](13_INTERFAZ_MOVIL_UTILIZABLE.md) (oculta los carriles laterales) hasta el siguiente toque en pantalla.

---

## 7. Criterios de Aceptación y Pruebas

Nueva suite `tests/test_input.gd` (headless, eventos inyectados con `Input.parse_input_event()`):
1. Todas las acciones de §2 existen en `InputMap` con al menos un evento de teclado y uno de mando.
2. Stick izquierdo a 0,1: sin movimiento (zona muerta). A 1,0 durante 1 s: $\Delta\theta = 42° \cdot 24/f$ ± 1 %.
3. Gatillo a 0,5 y soltar: AF ejecutado, `shots` sin cambios. Gatillo a 1,0: `shots` baja en 1.
4. Stick derecho a fondo durante 0,25 s en MF: el foco recorre una ventana $W$ ± 5 %.
5. Cada modal (`INTRO`, `BRIEFING`, `EQUIPMENT`, `GRAPHICS`, `HELP`, `RESULT`, `SUMMARY`, `SANDBOX_SETTINGS`) tiene un control con foco al abrirse y todos sus controles son alcanzables con la cruceta.
6. Las pruebas actuales siguen pasando: el teclado conserva exactamente sus teclas.

---

## 8. Fases y Esfuerzo

| Fase | Contenido | Esfuerzo |
|---|---|:---:|
| 1 | Migración a `InputMap` sin cambiar el comportamiento del teclado, con `test_input.gd` básico | S |
| 2 | Sticks, gatillo de dos fases y vibración | S-M |
| 3 | Menús navegables, estilo de foco e iconos por dispositivo | M |

**Dependencias**: ninguna. La fase 1 es prerrequisito de [13](13_INTERFAZ_MOVIL_UTILIZABLE.md) fase 3, de [11](11_MECANICAS_BARRIDO_Y_DOF_REALTIME.md) y de [12](12_MODOS_FOTOMETRIA_Y_AUTOFOCUS.md) §5.
