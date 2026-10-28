# Estrategia de Vídeos Cortos (Shorts / TikTok / Reels): PhotoHacks
**Ámbito**: Adquisición orgánica de jugadores y alumnos para **PhotoHacks** (simulador y academia interactiva de fotografía).  
**Autor**: GeeseBumps  
**Fecha**: 27 de octubre de 2026  
**Documentos relacionados**: [`AGENTS.md`](../AGENTS.md), [`docs/ARQUITECTURA.md`](ARQUITECTURA.md), [`docs/SIMULACION_FOTOGRAFICA.md`](SIMULACION_FOTOGRAFICA.md), [`/home/ganso/codigo/automatizaciones/AGENTS.md`](/home/ganso/codigo/automatizaciones/AGENTS.md)

---

## 1. Filosofía de Contenido: El Enfoque Jaime Altozano

PhotoHacks nació con una vocación divulgativa clara: **«Enseñar fotografía como Jaime Altozano enseña la música»**.

En YouTube Shorts y TikTok, los vídeos técnicos de fotografía aburren si son conferencias teóricas, pero arrasan si muestran **un fenómeno visual sorprendente en 15 segundos**:
- Ver cómo un diafragma se abre y el fondo se desintegra en bokeh real.
- Ver cómo una farola nocturna se transforma en una estrella puntiaguda al cerrar a f/16.
- Ver cómo la imagen partida telemétrica de los años 70 alinea dos mitades desplazadas al girar el foco.
- Ver cómo un teleobjetivo de 200 mm «aplasta» el fondo contra el sujeto.

El mensaje final de cada Short es siempre el mismo:
> *«Aprende fotografía jugando, gratis, con simulación óptica real en tu móvil o PC.»*

---

## 2. Reglas Técnicas y Safe Zone

1. **Formato vertical nativo 9:16 (1080×1920, SAR 1:1, 30 FPS):** La simulación 3D de PhotoHacks (16:9) se encuadra en el centro con escalado nítido, ribetes de marca naranja (`#ff7700`) y fondo dinámico desenfocado del parque.
2. **Safe Zone Estricta:** Los rótulos y llamadas se sitúan en la **franja superior (`Y = 240` a `480 px`)** para que jamás queden ocultos por la interfaz de YouTube Shorts (título, autor y botones laterales).
3. **Alto Contraste y Branding PhotoHacks:** Fondo negro azabache sólido (`#080812`), marco de **8 px** en naranja de la marca (`#ff7700`), resplandor ámbar de 14 px y pastilla sólida de cabecera con letras en negro.
4. **Duración (16 a 19 segundos):** Bucle rápido y conciso para garantizar retención >100%.
5. **Subida en Privado y Validación:** Todo Short se genera y sube a YouTube Studio en modo **Privado** mediante automatización CDP en el perfil `geesebumps`, manteniéndose la ventana abierta para revisión del usuario.
6. **Texto en la Vista Previa / Miniatura:** La portada o fotograma de vista previa debe incluir un texto conciso de choque visual y alto contraste (por ejemplo, *«f/1.8 vs f/16»* en Ep #1 o *«1/1000s vs 1/15s»* en Ep #2).
7. **Vídeo Relacionado:** Todo Short debe llevar vinculado en YouTube Studio el enlace a un vídeo largo o tráiler del juego (`PhotoHacks - v0.3.0 alfa`, `NrxNwn-OvMU`) para dirigir todo el tráfico de Shorts hacia la presentación completa y descarga en Itch.io.

---

## 3. Catálogo de Episodios (Temporada 1)

| Ep. | Eje Didáctico | Gancho en Pantalla | Vista Previa | Demostración Visual | Audio / SFX | Estado |
|---|---|---|---|---|---|---|
| **#1** | **El Secreto del Bokeh** | *«¿POR QUÉ TUS RETRATOS NO TIENEN ESTE DESENFOQUE?»* | *f/1.8 vs f/16* | De f/1.8 a f/16 con teleobjetivo 135mm: desenfoque cremoso a plena apertura que se vuelve nítido al cerrar. Sujeto sentado en banco. | Clics de rueda con cada paso + Sonido de obturador réflex + Música alegre | **Publicado (Público)**: [`nVvqfVOqyB4`](https://youtube.com/shorts/nVvqfVOqyB4) |
| **#2** | **Congelar vs Barrido** | *«CÓMO FOTOGRAFIAR MOVIMIENTO: 1/1000s VS BARRIDO»* | *1/1000s vs 1/15s* | Corredor en el parque: 1/1000s congelado en el aire vs 1/15s con barrido de cámara y estelas de velocidad. | Pasos acelerados + Clic de alta velocidad + Música rítmica | *Pendiente* |
| **#3** | **Estrellas de Noche** | *«EL TRUCO PARA CONVERTIR FAROLAS EN ESTRELLAS»* | *f/2.8 vs f/22* | Parque nocturno: a f/2.8 bombillas normales; al cerrar a f/16–f/22 la difracción genera estrellas de 14 puntas. | Sonido de noche + Clic de diafragma + Música mágica | *Pendiente* |
| **#4** | **Compresión Focal** | *«EL ZOOM NO SOLO ACERCA: APLASTA EL FONDO»* | *24mm vs 200mm* | Comparación entre 24 mm angular (fondo lejano) y 200 mm teleobjetivo (fondo pegado al sujeto). | Clic de zoom mecánico + Música divulgativa | *Pendiente* |
| **#5** | **Enfoque de Imagen Partida** | *«ASÍ SE ENFOCABA ANTES DEL AUTOFOCUS»* | *Manual vs Auto* | Círculo telemétrico vintage: la línea de la cara está partida en dos mitades; giro del anillo y encaje perfecto. | Giro de anillo metálico + Disparo clásico telemétrico | *Pendiente* |
| **#6** | **La Cámara TLR Rolleiflex** | *«LA CÁMARA QUE SE MIRA DESDE ARRIBA»* | *Cintura vs Ojo* | Visor superior de cintura a la altura del pecho, formato cuadrado 6×6 y espejo invertido. | Mecanismo de muelle de cintura + Disparo de obturador central | *Pendiente* |

---

## 4. Protocolo Operativo: «Publica otro short»

La tubería está totalmente integrada con el gestor de perfiles y automatizaciones:

1. **Estado en disco:** `/home/ganso/codigo/afotando/data/shorts_estrategia.json` lleva el control del próximo episodio a publicar.
2. **Ejecución automática:** El script `/home/ganso/codigo/afotando/tools/publicar_short.py` renderiza el vídeo en `/home/ganso/codigo/afotando/build/video/`, lo conecta vía CDP al perfil `geesebumps`, rellena todos los campos con metadatos optimizados y lo guarda en **Privado**.
3. **Supervisión interactiva:** Si la sesión de Google hubiera caducado, la IA deja la ventana interactiva y pide al usuario que entre (siguiendo el protocolo de `AGENTS.md`).
4. **Entrega final:** Notifica con la ruta completa del fichero, la URL de YouTube Shorts y deja Chromium abierto en el panel para revisión del usuario.

---

## 5. Guía Técnica de Renderizado y Lecciones Críticas (Para los siguientes episodios)

Al generar los episodios siguientes, deben tenerse en cuenta las siguientes reglas críticas aprendidas en el Episodio #1:

### 5.1 Modo de Exposición y Barridos de Parámetros (`equipment.priority`)
- En Godot, el método `auto_expose()` opera por defecto en modo Programa (*P*): ajusta libremente diafragma, velocidad e ISO para cuadrar el EV medido.
- **Regla crítica**: Si un script o animación varía manualmente el diafragma (`n_index`), es obligatorio fijar `equipment.priority = "A"` (Prioridad de Apertura). De lo contrario, `auto_expose()` sobreescribe el diafragma en cada fotograma al valor automático elegido por el juego, anulando el efecto visible del barrido. Para velocidades de obturación (Episodio #2), fijar `equipment.priority = "S"`.

### 5.2 Activación del Pase de Profundidad de Campo (`dof_blur`)
- En `main.gd`, la profundidad de campo (`dof_pass`) requiere que `eye_ready()` sea verdadero (`camera_raised = true` y `raise_anim = 1.0`).
- Si la cámara está en modo paseo o a la altura del pecho, `dof_blur` se apaga y el sombreador pasa la imagen nativa sin desenfocar (`enabled = false`).
- Al iniciar cualquier demo o puesta en escena con desenfoque, debe forzarse explícitamente:
  ```gdscript
  camera_raised = true
  raise_anim = 1.0
  update_dof_pass()
  ```

### 5.3 Enfoque Exacto y Sombreador DOF (`max_radius`)
- Para teleobjetivos largos (105mm, 135mm, 200mm), el radio máximo de desenfoque en `shaders/viewfinder_dof.gdshader` debe ser amplio (`max_radius = 120.0`) para que el círculo de confusión físico no se corte artificialmente.
- El plano de enfoque (`focus_distance` / `focus_m`) debe apuntar exactamente a la coordenada del sujeto (por ejemplo, la cabeza del maniquí con `p.control_points()[0]`).

### 5.4 Puesta en Escena Limpia (`--stage=sentado` / `--stage=parado`)
- Los personajes no deben tapar el encuadre. `--stage=sentado` sienta al personaje objetivo en el banco 1 frente a la cámara, enfoca su rostro y oculta a los viandantes de los carriles interiores 0 y 1, dejando únicamente corredores y transeúntes en los carriles traseros 2 y 3.

### 5.5 Composición y Safe Zone de YouTube Shorts
- **Recorte del visor:** En el canvas de 1440×810 de Godot, el área útil del visor 3D se extrae con `crop=1120:624:160:32` y se escala a `1080×602` con filtro `lanczos`.
- **Fondo:** Se utiliza el fondo de la propia escena desenfocado (`gblur=sigma=32`, brillo `-0.35`) para llenar los 1920 px verticales sin bandas negras.
- **Marco:** Ribete naranja de 4 px (`#ff7700`) alrededor del visor para sellar visualmente la ventana 3D.
- **Pastilla de cartela:** Ancho de 960 px, fondo oscuro translúcido con resplandor neón, situada entre `y=260` y `y=480`, dentro de la *Safe Zone* superior de YouTube Shorts.
- **Audio normalizado:** Se mezcla música de fondo, ambiente del parque y efectos de sonido con `loudnorm=I=-14:LRA=11:TP=-1.0`.

### 5.6 CLI de Publicación (`tools/publicar_short.py`)
- `python3 tools/publicar_short.py`: Toma el siguiente episodio pendiente en `data/shorts_estrategia.json`, renderiza y sube a YouTube Studio vía CDP.
- `python3 tools/publicar_short.py --id <num>`: Fuerza la publicación de un episodio concreto.
- `python3 tools/publicar_short.py --solo-video`: Solo compila el MP4 y la comparativa sin abrir navegador.
- `python3 tools/publicar_short.py --skip-render`: Reutiliza el MP4 ya existente si ha sido verificado previamente.

### 5.7 Ratio de Aspecto, SAR:DAR y Detección de Shorts en YouTube
- **Trampa de FFmpeg en escalado vertical**: Si la entrada cruda es 16:9 (`1920×1080`), al aplicar `scale=1080:1920` sin especificar `setsar=1`, FFmpeg conserva el *Display Aspect Ratio* original de 16:9 ajustando automáticamente el *Sample Aspect Ratio* a `256:81`.
- **Efecto en YouTube**: Aunque la matriz de píxeles sea 1080×1920, la cabecera del contenedor MP4 declara `DAR 16:9`. YouTube lo clasifica inmediatamente como un vídeo horizontal estándar (640×360) en la pestaña «Vídeos» en lugar de un Short.
- **Solución obligatoria**:
  1. En el grafo de filtros de FFmpeg, incluir `setsar=1` en toda rama reescalada (`scale=1080:1920,setsar=1`) y en la salida final (`[outv_raw]setsar=1[outv]`).
  2. Forzar `-aspect 9:16` explícitamente en los comandos de codificación de FFmpeg.
  3. Comprobar siempre con `ffprobe`: `sample_aspect_ratio=1:1` y `display_aspect_ratio=9:16`.

### 5.8 Vista Previa (Texto de Choque) y Vídeo Relacionado
- **Texto de Choque en Vista Previa (`preview_text`)**:
  - Toda miniatura/portada debe incluir un texto conciso de choque visual (ej. *«f/1.8 vs f/16»*, *«1/1000s vs 1/15s»*) que resuma el conflicto técnico en menos de 15 caracteres.
  - Se define en el campo `preview_text` de `data/shorts_estrategia.json`.
- **Vídeo Relacionado (`linked-video-editor-link`)**:
  - En YouTube Shorts es fundamental asignar un «Vídeo relacionado» para convertir a los espectadores de 15 segundos en jugadores del juego completo.
  - Para PhotoHacks, el vídeo relacionado por defecto es el tráiler del juego: `PhotoHacks - v0.3.0 alfa` (ID `NrxNwn-OvMU`).
  - En la pantalla de edición de YouTube Studio, el campo `#linked-video-editor-link` debe apuntar siempre a este vídeo.
