# Proyecto Paparazzi (v0.1.0-alpha)

Simulador fotográfico y juego de observación procedural desarrollado en **Godot 4**. El jugador se sitúa en un parque urbano y debe localizar a objetivos específicos descritos por sus rasgos y vestuario, capturándolos con la técnica fotográfica adecuada (exposición, enfoque, distancia focal, velocidad y encuadre).

El visor toma como referencia compositiva [`docs/futuro/referencia.jpg`](docs/futuro/referencia.jpg); el parque, la iluminación, el mobiliario y la multitud de viandantes son geometría 3D generada y ensamblada proceduralmente a partir de datos paramétricos.

---

## Cómo Jugar y Ejecutar

### Requisitos del Sistema
- **Godot Engine 4.4 o posterior** (validado y optimizado con **Godot 4.7 Mono/Official**).
- Renderizador: **Compatibility** (`gl_compatibility`), con mallas de superficie única y colores de vértice.
- Proporción de aspecto bloqueada a **16:9** (resolución nativa `1280x720`, override `1440x810`).
- No requiere conexión a internet ni dependencias externas.

### Comandos de Ejecución

En sistemas Linux con `godot-4` instalado:
```bash
# Lanzar el juego directamente desde el directorio del proyecto
godot-4 --path .

# En macOS o sistemas donde el ejecutable se llame 'godot':
godot --path .
```

- **En macOS**: También puedes hacer doble clic en `Jugar.command`.
- **En Windows**: Doble clic en `Jugar.bat`. Si hay un `Godot*_win64.exe` en la raíz del proyecto (ignorado por git), se usa ese; si no, `godot-4`/`godot` del `PATH`.
- Ambos lanzadores respetan la variable `GODOT_BIN` y, a continuación, dan prioridad a los ejecutables `Godot*_win64.exe` locales (si hay varios, el último por orden alfabético).
- **En Android**: Instala `build/paparazzi-debug.apk` (arm64, firmado con clave de depuración; activa la instalación desde orígenes desconocidos). Para regenerarlo: `./tools/export_android.sh` (requisitos en [docs/TESTS_Y_VERIFICACION.md §4.2](docs/TESTS_Y_VERIFICACION.md)).
- **Desde el editor de Godot**: Abre la carpeta en el Project Manager y pulsa **F5**.

---

## Dinámica de Juego

1. **Modos de Iluminación**: Selecciona **Parque · Día** (luz solar dura de mediodía y nubes dinámicas, $EV \approx 14.8$ al sol) o **Parque · Noche** (farolas cálidas con sombras proyectadas, $EV \approx 2$–$8$ según la distancia a la farola).
2. **Éste es tu encargo**: Antes de cada fase se presenta la ficha del objetivo con un retrato 3D interactivo que muestra su vestuario exacto, peinado y accesorios. El parque permanece pausado durante la lectura.
3. **Búsqueda y Captura**:
   - Panea 360° y ajusta la inclinación ($\pm 75^\circ$).
   - Usa el zoom para dimensionar adecuadamente al sujeto dentro de su carril.
   - Ajusta apertura, velocidad e ISO para clavar la exposición en el fotómetro.
   - Enfoca con precisión manual (pantalla partida / coincidencia) o selecciona un punto de la cuadrícula AF de 9 puntos.
4. **Puntuación y Revelado**: Tienes **3 disparos por encargo** (cuenta la mejor puntuación). Cada disparo se revela con un shader que simula desenfoque por círculo de confusión (CoC), trepidación, arrastre por movimiento del sujeto, grano analógico y error de exposición ($\Delta EV$). Obtener tres estrellas supera el encargo. La sesión consta de **5 encargos progresivos**.

---

## Controles del Simulador

| Acción | Teclado / Ratón | Gestos Táctiles |
|---|---|---|
| **Giro horizontal (360°)** | Arrastrar en escena / Teclas `A`/`D` o `←`/`→` | Arrastre horizontal con inercia |
| **Inclinación ($\pm 75^\circ$)** | Arrastrar verticalmente / Teclas `↑`/`↓` | Arrastre vertical |
| **Zoom (distancia focal)** | Rueda del ratón / Teclas `W`/`S` / Deslizador ZOOM | Pellizco con dos dedos |
| **Seleccionar punto AF y enfocar** | Clic en la escena | Toque en la escena |
| **Enfocar con punto activo** | Tecla `F` o botón ENFOCAR | Pulsar botón ENFOCAR |
| **Selección rápida de punto AF (1–9)** | Teclas numéricas `1`–`9` | Toque en la cuadrícula del visor |
| **Apertura de diafragma** | Teclas `Q`/`E` / Arrastrar dial superior | Toque / arrastre en indicador `f/` |
| **Velocidad de obturación** | Teclas `Z`/`X` / Arrastrar dial superior | Toque / arrastre en indicador de tiempo |
| **Sensibilidad ISO** | Teclas `C`/`V` / Arrastrar dial superior | Toque / arrastre en indicador ISO |
| **Retroceder un ajuste** | Clic derecho sobre el valor | — |
| **Distancia de enfoque manual (MF)** | `Shift` + rueda, `R`/`T` o dial FOCO (rueda sola en fijas) | Arrastre vertical con dos dedos |
| **Disparador** | `Espacio` o botón DISPARAR | Botón DISPARAR |
| **Continuar / Aceptar** | `Intro` | Botón en pantalla |
| **Guías de tercios** | Tecla `G` | — |
| **Ayuda / Pausa** | Teclas `H`, `?` o `Esc` | Botón de ayuda |

---

## Familias de Equipos y Modos

Pulsa **Equipo / modos** en el menú o en la barra superior durante la partida:

- **Fácil (Compacta didáctica)**: Zoom 24–120 mm f/2.8–5.6 (o fija 35 mm f/2.8), enfoque automático matricial y exposición automática. Los diales manuales se bloquean.
- **Calle (Telemétrica)**: Ópticas fijas luminosas (35 mm f/2, 50 mm f/1.4, 90 mm f/2.8). Enfoque manual asistido por telémetro de coincidencia (doble imagen) y exposición manual.
- **Acción (Réflex SLR)**: Zoom 24–105 mm f/4, teleobjetivo 70–200 mm f/2.8 y fija 50 mm f/1.8. Admite AF puntual, AF matricial y MF con pantalla de enfoque partida. Exposición manual o automática.
- **Soporte Químico (Carrete)**: Posibilidad de cargar emulsión analógica fija de ISO 100 a 3200 (cualquier cuerpo), bloqueando la sensibilidad en los controles y en el exposímetro.

---

## Modo Sandbox y Clima Dinámico

- **Modo Sandbox**: Permite fotografiar sin encargos ni límites de disparos. Cada foto se evalúa detallando la distancia exacta, desenfoque en milímetros, velocidad perpendicular y $\Delta EV$.
- **Panel de Escena Sandbox**: Permite alternar instantáneamente día/noche, activar o desactivar nubes dinámicas y detener por completo a los personajes para estudiar la iluminación o la óptica.
- **Nubes Procedurales**: Durante el día, frentes nubosos atraviesan el cielo reducen la luz solar directa en $\approx 3.5\text{ EV}$ (la luz incidente al sol baja $\approx 2.7\text{ EV}$) con transiciones de 1,2 s.

---

## Suite de Verificación Automatizada

El proyecto tiene 8 suites automatizadas: 4 headless (óptica, arte, equipo y marcha) y 4 que requieren display (navegación, atascos, expansión y sesión completa), además de `--smoke-test`. Los comandos, qué valida cada suite y las cifras de referencia medidas (triángulos, VRAM, número de comprobaciones) están en **[docs/TESTS_Y_VERIFICACION.md](docs/TESTS_Y_VERIFICACION.md)**.

Comprobación mínima antes de cerrar un cambio:
```bash
godot-4 --path . -- --smoke-test
```

---

## Estructura del Repositorio y Documentación

- **[ESPECIFICACION.md](ESPECIFICACION.md)**: Especificación funcional normativa original del prototipo.
- **[AGENTS.md](AGENTS.md)**: Guía de directivas, restricciones de rendimiento y comandos para agentes de IA y automatización.
- **[docs/ARQUITECTURA.md](docs/ARQUITECTURA.md)**: Arquitectura de software, máquina de estados y pipeline de fotograma. Desde ahí se enlazan los demás monográficos de `docs/`.
- **[docs/TESTS_Y_VERIFICACION.md](docs/TESTS_Y_VERIFICACION.md)**: Comandos de prueba y cifras de referencia medidas (fuente única).
- **[docs/evidencias/GALERIA.md](docs/evidencias/GALERIA.md)**: Galería de capturas generada por `tools/run_evidence.sh`.
- **[docs/origen/](docs/origen/)**: Documento de diseño original de 2012 e imágenes.
- **`scripts/`**: Lógica de juego, generación procedural de personajes y parque, cinemática y visor.
- **`shaders/`**: Shaders de revelado fotográfico (`develop.gdshader`), ayuda de prisma (`focus_aid.gdshader`) y maniquí toon con contorno de tinta (`cel_shading.gdshader`, `cel_outline.gdshader`).
- **`data/`**: Catálogo paramétrico de piezas (`catalogo.json`, `data/piezas/`) y textos en español (`textos.es.json`).
- **`tools/`**: Generación de geometría (`build_catalog.py`), visualizadores (`preview_gait.gd`, `preview_people.gd`) y suite de evidencias (`run_evidence.sh`, `capture_evidence.gd`, `build_sheets.py`).

---

## Mejoras Implementadas y Hoja de Ruta

- **Navegación de Viandantes y Carriles Anchos (Implementado)**:
  - Sistema de bandas radiales con separación de flujo por dirección de marcha (`LANE_OFFSETS = [0.33, 0.35, 0.35, 0.35]`), permitiendo que varios personajes compartan el mismo carril y se crucen frontalmente sin colisionar.
  - Dirección anticipatoria (*anticipatory steering*) y evasión lateral continua para adelantamientos y rebase de obstáculos.
  - Mecanismo anti-deadlock progresivo (cambio de carril, cesión de paso y cambio de sentido).
  - Verificado deterministamente con la suite [`tests/test_navigation.gd`](tests/test_navigation.gd).

