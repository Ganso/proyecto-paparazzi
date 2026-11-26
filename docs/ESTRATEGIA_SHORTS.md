# Estrategia de Vídeos Cortos (Shorts / TikTok / Reels): PhotoHacks
**Ámbito**: Adquisición orgánica de jugadores y alumnos para **PhotoHacks** (simulador y academia interactiva de fotografía).  
**Autor**: GeeseBumps  
**Fecha**: 27 de octubre de 2026  
**Documentos relacionados**: [`AGENTS.md`](../AGENTS.md), [`docs/ARQUITECTURA.md`](ARQUITECTURA.md), [`docs/SIMULACION_FOTOGRAFICA.md`](SIMULACION_FOTOGRAFICA.md), [`/home/ganso/codigo/automatizaciones/AGENTS.md`](/home/ganso/codigo/automatizaciones/AGENTS.md)

---

> **Cómo se publica** (subida, visibilidad, metadatos, lista de reproducción, verificación): [`~/codigo/automatizaciones/PUBLICAR_VIDEOS.md`](/home/ganso/codigo/automatizaciones/PUBLICAR_VIDEOS.md), común a todos los proyectos y por encima de lo que diga aquí sobre la subida. Reglas clave: un vídeo por orden (si hay varios, se pregunta el calendario), privado por defecto y cada vídeo en la lista de su juego («PhotoHacks»).

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
7. **Vídeo Relacionado:** Todo Short debe llevar vinculado en YouTube Studio el enlace al tráiler oficial más reciente del juego (`PhotoHacks — Official Trailer (Learn photography by playing)`, `IZoAsAiY5Fk`) para dirigir todo el tráfico de Shorts hacia la presentación completa y descarga en Itch.io.

---

## 3. Catálogo de Episodios (Temporada 1)

| Ep. | Eje Didáctico | Gancho en Pantalla | Vista Previa | Demostración Visual | Audio / SFX | Estado |
|---|---|---|---|---|---|---|
| **#1** | **El Secreto del Bokeh** | *«¿POR QUÉ TUS RETRATOS NO TIENEN ESTE DESENFOQUE?»* | *f/1.8 vs f/16* | De f/1.8 a f/16 con teleobjetivo 135mm: desenfoque cremoso a plena apertura que se vuelve nítido al cerrar. Sujeto sentado en banco. | Clics de rueda con cada paso + Sonido de obturador réflex + Música alegre | **Publicado** (27-10-2026; 65 visitas el 26-11): [`nVvqfVOqyB4`](https://youtube.com/shorts/nVvqfVOqyB4). Vídeo relacionado: tráiler oficial (`IZoAsAiY5Fk`). Lista «PhotoHacks». |
| **#2** | **El barrido** | *«EL BARRIDO: SIGUE AL CORREDOR»* | *1/30 s + giro* | Nivel 26: la cámara sigue al corredor a 1/30 s y la foto sale con él nítido y el fondo arrastrado (100/100). | Sonido del juego + música | **Publicado** (30-10-2026; 130 visitas el 26-11): [`XjeIYtMmzcw`](https://youtube.com/shorts/XjeIYtMmzcw). Vídeo relacionado: tráiler oficial (`IZoAsAiY5Fk`). |
| **#3** | **Estrellas de Noche** | *«CONVIERTE LAS FAROLAS EN ESTRELLAS»* | *f/2.8 vs f/16* | Sandbox nocturno: foto a f/2.8 (luces redondas), el diafragma cerrándose en el visor y foto a f/16 con las farolas y el quiosco en estrella. | Sonido del juego + música | **Publicado** (01-11-2026; 99 visitas el 26-11): [`S8Nta5sNZRc`](https://youtube.com/shorts/S8Nta5sNZRc). Vídeo relacionado: tráiler oficial (`IZoAsAiY5Fk`). |
| **#4** | **Compresión Focal** | *«EL TELE «APLASTA» EL FONDO»* | *28mm vs 135mm* | Demostración de la lección 3 de la Academia: 28 mm de cerca (fondo pequeño) frente a 135 mm de lejos (árboles enormes y pegados). | Sonido del juego + música | **Publicado** (06-11-2026; 53 visitas el 26-11): [`kXOGhUiUuOg`](https://youtube.com/shorts/kXOGhUiUuOg). Vídeo relacionado: tráiler oficial (`IZoAsAiY5Fk`). |
| **#5** | **Enfoque manual** | *«ASÍ SE ENFOCABA ANTES DEL AUTOFOCO»* | *Enfoque manual* | Zoom al centro del visor: imagen partida de la réflex encajando al girar el anillo y doble imagen de la telemétrica juntándose. | Sonido del juego + música | **Publicado** (04-11-2026; 54 visitas el 26-11): [`KvJ3tcRInAw`](https://youtube.com/shorts/KvJ3tcRInAw). Vídeo relacionado: tráiler oficial (`IZoAsAiY5Fk`). |
| **#6** | **La cámara TLR** | *«LA CÁMARA QUE SE MIRA DESDE ARRIBA»* | *A la cintura* | Nivel 21: visor de cintura cuadrado e invertido, enfoque manual y foto 6×6 de 97/100. Sin nombres de marcas de cámaras. | Sonido del juego + música | **Publicado** (05-11-2026; 37 visitas el 26-11): [`mxBqg-Qol9A`](https://youtube.com/shorts/mxBqg-Qol9A). Vídeo relacionado: tráiler oficial (`IZoAsAiY5Fk`). |

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
- **Episodios por receta** (desde el #2, 28-10-2026): en `data/shorts_estrategia.json`, `takes` son grabaciones del juego (Movie Maker, 1440×810 a 30 FPS, con sus argumentos de arranque; se guardan en `build/video/raw/take_<nombre>.avi` y se reutilizan) y `cuts` los tramos que se montan: `ss`, `t`, `crop` (`"w:h:x:y"` del fotograma de 1440×810 o `"full"`) y `labels` (`[inicio, fin, texto]`). El juego va centrado sobre su propia imagen desenfocada, con la cartela arriba y el rótulo debajo; cierre de 4 s con la tarjeta de PhotoHacks; sonido del juego bajo la música, a −14 LUFS. `--regrabar` vuelve a grabar las tomas. `--mf` (opción de arranque del juego) pone el enfoque manual en un cuerpo con autofoco (la imagen partida de la réflex).
- **Sin marcas ajenas** (guía de publicación, regla 5): ni Rolleiflex ni Photoshop en títulos, descripciones, etiquetas o rótulos.
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

---

## 6. Temporada 2: clases independientes (26-11-2026)

> **Decisiones del usuario (26-11-2026):** «me gusta enfocarlos como una escuela de fotografía más que como publicidad del juego» y «Vamos a hacer clases 100% independientes, sin relación entre sí».

### 6.1 Qué nos dicen los seis primeros

Los que más se ven enseñan **un fenómeno que se ve solo**: el barrido (130 visitas) y las estrellas de las farolas (99). Los que explican una herramienta (enfoque manual, TLR) se ven la mitad. Todos cierran vendiendo el juego, y con 37–130 visitas la venta no compensa.

### 6.2 Formato de cada clase (30–45 s, completa en sí misma)

1. **Pregunta** (0–3 s): la duda real de quien hace fotos, sobre la imagen del problema. Es también la vista previa.
2. **Fenómeno** (3–20 s): el antes y el después, con los datos de la cámara visibles.
3. **Por qué** (20–30 s): una sola idea.
4. **Regla y deberes** (30–40 s): la regla para recordar y «Pruébalo hoy», un ejercicio con el móvil o la cámara.

Sin número de clase, sin «próxima clase», sin referencias a otros vídeos y sin exámenes que repasen. Cada una se entiende vista sola y en cualquier orden. Interfaz mínima: visor y datos de exposición sí; menús y puntuaciones no.

**El juego, al final y en la descripción** (usuario, 26-11-2026: «sí quiero que salga una tarjeta del juego al final y se vea en la descripción. Quiero que la gente aprenda con los shorts, pero luego se vaya a la academia del juego a terminar de aprender»): Tras la regla, 5 s de tarjeta «Sigue aprendiendo en PhotoHacks» con qué es (una escuela de fotografía que se juega), **dónde practicar esa clase en el juego** (campo `practica`: la lección de la Academia o el modo que toque), plataformas y enlace. En la descripción, el mismo mensaje y el enlace justo después de la primera línea.

### 6.3 Temas, en orden de publicación

Primero, los fenómenos más visuales y las dudas más comunes de quien empieza.

| # | Tema | Pregunta (vista previa) | Fenómeno | Regla y deberes | Imágenes |
|---|---|---|---|---|---|
| 1 | La hora dorada · **Programada (28-11-2026, 18:00)**: [`sTazaLwY3bQ`](https://youtube.com/shorts/sTazaLwY3bQ) | «¿Por qué las fotos de la tarde son más bonitas?» | El mismo encuadre de día, en la hora dorada, en la hora azul y de noche | La luz baja dibuja; la de mediodía aplana. Sal una hora antes de que se ponga el sol | Sandbox, `--time=day/golden/blue/night` |
| 2 | Congelar o dejar estela | «¿Por qué sale borroso el que corre?» | El corredor a 1/1000 s y a 1/15 s | Rápida congela; lenta cuenta el movimiento | Lección 7, prioridad S |
| 3 | El fotómetro quiere gris | «¿Por qué me sale la cara oscura?» | Matricial con mucho cielo frente a puntual en la cara o +1 de compensación | La cámara lo lleva todo a gris medio. Toca la cara en el móvil antes de disparar | Lección 8 y niveles de contraluz |
| 4 | Nunca cortes por una articulación | «¿Por qué esta foto queda rara?» | Cortar por las rodillas frente a cortar por media pierna | Corta entre articulaciones, nunca en ellas | Arcade, nivel 32 |
| 5 | Desenfocar el fondo sin un objetivo caro | «¿Cómo consigo el fondo borroso?» | Mismo diafragma: cerca y con el fondo lejos frente a lejos y con el fondo cerca | Acércate, aleja el fondo, usa tele. Vale con el modo normal del móvil | Lección 6 |
| 6 | Contraluz o silueta | «¿Error o silueta?» | El mismo contraluz medido para la cara y para el cielo | Mide para lo que quieras ver bien. Busca una silueta esta tarde | Arcade, contraluz y silueta |
| 7 | La foto movida | «¿Por qué sale borrosa si nada se mueve?» | A 200 mm, 1/30 s tiembla y 1/250 s no | Velocidad mínima ≈ 1/focal | Trepidación, lección 7 |
| 8 | Aire delante de la mirada | «¿Centro o a un lado?» | Corredor centrado, en un tercio mirando al borde y con aire delante | Deja espacio hacia donde mira o va. Activa la cuadrícula | Lección 1 |
| 9 | Los seis planos | «¿Plano medio o americano?» | Una persona del plano general al primerísimo, con el maniquí de cada plano | Cada plano corta en un sitio. Haz los seis a la misma persona | Lección 2, Paparazzi |
| 10 | Enfoca a los ojos | «¿Por qué no está nítida si he enfocado?» | f/1.8 a 135 mm: foco en la oreja frente a foco en el ojo | En un retrato, el ojo más cercano | Lección 3 |
| 11 | ¿Quién es el protagonista? | «¿A quién miro en esta foto?» | Plano general con mucha gente frente al tele que aísla a una persona | Una foto, una persona | Paparazzi |
| 12 | A o S: qué modo usar | «¿Qué modo uso?» | Retrato en A (eliges el fondo) y corredor en S (eliges el movimiento) | A si importa el fondo; S si importa el movimiento | Lección 9 |
| 13 | El gran angular deforma de cerca | «¿Por qué salgo con la nariz grande?» | Retrato a 24 mm pegado frente a 85 mm de lejos | Para retratos, aléjate y usa más focal | Lección 4 |
| 14 | Enfocar y reencuadrar | «¿Cómo enfoco algo que no está en el centro?» | Foco al centro en el fondo frente a bloqueo de foco y reencuadre | Enfoca, mantén, reencuadra | Bloqueo AF/AE |
| 15 | Cuándo todo nítido | «¿Cómo saco nítido el delante y el fondo?» | f/2 a 24 mm frente a f/11 a 24 mm, con banco cerca y quiosco lejos | Cierra y usa angular para paisaje | Lección 6 |

### 6.4 Lo que hay que añadir a `publicar_short.py`

1. Plantilla de clase: cartela con la pregunta y tarjeta fija de regla y deberes (3–4 s). Cierre sin marca ni llamada a otro vídeo; logo pequeño en una esquina.
2. Comparación en paralelo de dos tomas en el 9:16.
3. Campos nuevos en `shorts_estrategia.json`: `pregunta`, `regla`, `deberes`.
4. Descripción con la regla y el ejercicio; el juego, solo en la última línea.

Las seis primeras clases ya publicadas no se tocan.
