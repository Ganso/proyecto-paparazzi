# Manual de Pruebas y Verificación — Proyecto Paparazzi

Este documento contiene la guía operativa completa para ejecutar y ampliar las suites de pruebas automatizadas del proyecto **Proyecto Paparazzi**.

---

## 1. Clasificación Fundamental: Headless vs. Display

El motor en esta máquina se ejecuta con el comando:
```bash
godot-4
```

> [!WARNING]
> **REGLA CRÍTICA DE EJECUCIÓN**:
> Las pruebas que toman capturas o esperan fotogramas renderizados (`RenderingServer.frame_post_draw`) **NO DEBEN EJECUTARSE NUNCA CON `--headless`**. En modo headless el servidor de render no procesa fotogramas de dibujo y el proceso se congela indefinidamente.

```
                     +-----------------------------------+
                     |       SUITES DE PRUEBA GODOT-4    |
                     +-----------------------------------+
                                       |
            +--------------------------+--------------------------+
            |                                                     |
            v                                                     v
   MODO HEADLESS (Sin Display)                            REQUIEREN DISPLAY
   - CI/CD en servidor                                    - Ventana X11 / Wayland activa
   - Sin dependencias gráficas                            - Capturas reales y shaders
   - Fórmulas, mallas y cinemática                       - Viewport, navegación y VRAM
```

---

## 2. Suites en Modo Headless (Sin Pantalla)

Pueden ejecutarse en terminales de fondo, servidores o integración continua:

### 2.1 Óptica, Fotometría y Determinismo (`test_photography.gd`)
Valida la física óptica, las fórmulas de círculo de confusión (CoC), profundidad de campo, valores de exposición EV y determinismo numérico:
```bash
godot-4 --headless --path . --script tests/test_photography.gd
```
- **Volumen**: 535 comprobaciones matemáticas.
- **Invariante**: Dos expedientes idénticos devuelven la misma puntuación exacta.

### 2.2 Presupuestos de Arte y Mallas (`test_art.gd`)
Ensambla proceduralmente cada una de las combinaciones del catálogo para todos los perfiles anatómicos:
```bash
godot-4 --headless --path . --script tests/test_art.gd
```
- **Volumen**: 2.880 ensamblajes anatómicos.
- **Invariantes**:
  - Máximo **1.900 triángulos** por viandante (la media es ~1.550).
  - Exactamente **20 huesos** por esqueleto.
  - Pesaje rígido: 100% peso a un solo hueso por vértice.

### 2.3 Cuerpos, Objetivos y Físicas (`test_equipment.gd`)
Comprueba las ópticas, diafragmas, tiempos de obturación, modos AF/MF, lectura fotométrica y avance gradual de carril:
```bash
godot-4 --headless --path . --script tests/test_equipment.gd
```
- **Volumen**: 543 comprobaciones.

### 2.4 Cinemática Inversa y Locomoción (`test_gait.gd`)
Verifica analíticamente el sistema de marcha y carrera:
```bash
godot-4 --headless --path . --script tests/test_gait.gd
```
- **Volumen**: 8.840 comprobaciones biomecánicas.
- **Invariante**: **Deriva de pie en contacto = $0.000000\text{ m/frame}$** y suela horizontal a $y = 0.0\text{ m}$.

---

## 3. Suites con Entorno Gráfico (Requieren Display)

### 3.1 Simulación Autónoma de Atascos de 20 Segundos (`simulate_jams.gd`)
Simula 20 segundos de juego real continuo (400 pasos de física a $\Delta t = 0.05\text{ s}$) sin interacción del jugador, monitorizando la velocidad y el tiempo de bloqueo de cada viandante:
```bash
godot-4 --path . --script tests/simulate_jams.gd
```
- **Criterio de éxito**: **0 viandantes en deadlock** (`stuck_time > 0.8s`).

### 3.2 Navegación 2D, Cruces y Evasión (`test_navigation.gd`)
Valida maniobras específicas de navegación peatonal en calzadas anchas:
```bash
godot-4 --path . --script tests/test_navigation.gd
```
- **Checks incluidos (10/10)**:
  - Cruce de dos viandantes en sentidos opuestos en el Carril 1 con separación $\ge 0.70\text{ m}$.
  - Adelantamiento de un corredor rápido a un caminante lento en el mismo carril.
  - Desvío lateral autónomo para rodear un obstáculo estático frontal sin atascarse.

### 3.3 Sesión de Juego Completa (`test_game.gd`)
Simula una partida íntegra de 5 encargos, evaluando entradas de ratón, disparo, revelado, consumo de VRAM y flujo entre pantallas:
```bash
godot-4 --path . --script tests/test_game.gd
```
- **Invariante de memoria**: **VRAM $< 60\text{ MiB}$** en todo momento (típicamente $\approx 42.6\text{ MiB}$).

### 3.4 Pantalla Previa, Nubes, Carretes y Sandbox (`test_expansion.gd`)
Verifica la pantalla de briefing, ropa deportiva de corredores, atenuación lumínica de nubes, bloqueo de ISO con película y el modo libre sandbox:
```bash
godot-4 --path . --script tests/test_expansion.gd
```
- **Volumen**: 140 comprobaciones con capturas PNG en `/tmp`.

### 3.5 Prueba de Humo Rápida (`--smoke-test`)
Comprobación ultrarrápida del estado general del juego:
```bash
godot-4 --path . -- --smoke-test
```
- **Verifica**: 21 viandantes, 20 huesos por persona, presupuesto total $\le 100.000$ triángulos (actualmente $57.532$) y expediente determinista.

---

## 4. Herramientas Auxiliares

```bash
# Regeneración del catálogo paramétrico JSON
python3 tools/build_catalog.py

# Previsualizador interactivo de vestimentas y perfiles anatómicos
godot-4 --path . --script tools/preview_people.gd

# Previsualizador interactivo de locomoción y cinemática inversa
godot-4 --path . --script tools/preview_gait.gd
```

---

## 5. Tabla Resumen de Diagnóstico Rápido

Si modificas... | Debes ejecutar obligatoriamente:
---|---
**Geometría de piezas o `catalogo.json`** | `godot-4 --headless --path . --script tests/test_art.gd`
**Locomoción o `gait.gd`** | `godot-4 --headless --path . --script tests/test_gait.gd`
**Fórmulas ópticas, CoC o puntuación** | `godot-4 --headless --path . --script tests/test_photography.gd`
**Cámaras, lentes o exposímetro** | `godot-4 --headless --path . --script tests/test_equipment.gd`
**Navegación, carriles o `park.gd`** | `godot-4 --path . --script tests/test_navigation.gd` y `simulate_jams.gd`
**Cualquier cambio antes de dar por cerrada una tarea** | `godot-4 --path . -- --smoke-test`
