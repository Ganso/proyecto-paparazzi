# Registro de Publicación en Reddit y Plan de Difusión

**Fecha de publicación**: 1 de noviembre de 2026, 18:37 CET  
**Proyecto**: PhotoHacks (v0.6.0-alpha)  
**Comunidad**: `r/playmygame`  
**Enlace oficial del post**: [https://www.reddit.com/r/playmygame/comments/1xl96cb/dev_photohacks_a_wheres_waldo_photography/](https://www.reddit.com/r/playmygame/comments/1xl96cb/dev_photohacks_a_wheres_waldo_photography/)  
**ID del post**: `1xl96cb`  
**Etiqueta (Flair)**: `[PC] (Web)`  
**Autor**: `u/javierprieto`  

---

## 1. Estrategia y Decisiones de Posicionamiento

1. **Omisión absoluta del factor IA**:
   - **Antecedente empírico en Notrunner**: El post centrado en herramientas de IA en `r/aigamedev` obtuvo 0 votos y 33% de ratio, mientras que los posts centrados en la experiencia de juego en `r/playmygame` y `r/AndroidGaming` obtuvieron entre 99% y 100% de votos positivos.
   - **Valor humano y divulgativo**: PhotoHacks es la culminación de un sueño de más de 15 años iniciado por un redactor y analista de fotografía (XatakaFoto), con el objetivo pedagógico de «enseñar fotografía como Jaime Altozano enseña la música». Presentarlo como «juego de IA» degradaría el diseño del juego y activaría el rechazo frontal presente en las comunidades de jugadores de Reddit.
2. **Elección de `r/playmygame`**:
   - Subreddit de referencia para solicitar pruebas y opiniones de desarrolladores y jugadores sobre juegos gratuitos.
   - Encaje perfecto con la versión Web (HTML5 en Itch.io), que permite jugar al instante sin descargas ni instalaciones.
3. **Prueba de autenticidad histórica**:
   - Se incluyó en el cuerpo del mensaje el enlace al mini-GDD de 2011 publicado en el blog personal: `https://blog.ganso.org/proyectos/proyecto-paparazzi`.

---

## 2. Contenido del Post Publicado

### 2.1 Título Oficial
```
[DEV] PhotoHacks - A "Where's Waldo" photography simulator where you learn real camera optics in a living park (free in browser)
```

### 2.2 Cuerpo del Mensaje (Markdown Enriquecido)
```markdown
**Game Title:**  
PhotoHacks  
  
**Playable Link:**  
• itch.io (Play in browser / Downloads): https://geese-bumps.itch.io/photohacks  
• GitHub (Source Code): https://github.com/Ganso/proyecto-paparazzi  
  
**Platform:**  
Web (HTML5), Windows, Linux, macOS, Android (experimental)  
  
**Description:**  
More than 15 years ago, I came up with an idea while writing about photography and reviewing camera gear: a "Where's Waldo" style game where you hunt specific people in a crowd with a camera, trying to nail the best possible shot. I even wrote a [small design document back in 2011](https://blog.ganso.org/proyectos/proyecto-paparazzi) detailing the concept. After all these years living with the idea in my head, I finally brought it to life in Godot 4.

The core philosophy is simple: **learn real photography by taking photos**. You get an assignment describing your target (wardrobe, hairstyle, accessories), spot them in a living urban park, and take the picture. You control framing, focal length, focus, and exposure (aperture, shutter speed, ISO). The game then "develops" your shot and gives you a detailed critique report explaining what worked and what didn't.

**What's currently in the game (v0.6.0-alpha):**  
• **Arcade Mode (30 levels):** 6 progression blocks from simple auto-exposure compacts to manual SLRs, rangefinders, and TLR cameras. Challenges ask for specific techniques: shallow depth of field, panning, silhouette/backlight, freezing fast motion, or capturing people interacting with dogs and playground equipment.  
• **Photography Academy (10 lessons):** Composition, perspective, depth of field, shutter speed/motion, light metering modes, P/A/S/M exposure controls, and optics. Each lesson includes visual theory directly over the viewfinder, an automated demo, guided practice, and an exam with a tutor report.  
• **Sandbox Mode:** Free photography with no shot limits or timers, dynamic day/night lighting (Golden Hour, Blue Hour, night streetlights), and moving cloud fronts that dynamically affect your exposure meter.  
• **Realistic Optical Simulation:** Shaders simulating circle of confusion (bokeh), true depth of field, camera shake, motion blur, film grain, and manual split-image/rangefinder focusing aids.  
• **A Living Park:** Procedural crowds, people chatting, jogging, sitting on benches, kids on swings, ducks in the pond, and reactive environmental audio.  

The game is 100% free, fully open source under the MIT license, with zero ads, no microtransactions, and zero tracking.

I would love to get your feedback on:
1. Viewfinder ergonomics and controls (does manual focusing and exposure adjustment feel intuitive?).
2. Academy lesson pacing (do the optical explanations and critique reports make sense to someone without a photography background?).
3. Any performance issues on the browser version.

**Free to Play Status:**  
[X] Free to play  
[ ] Demo/Key available  
[ ] Paid (Allowed only on Tuesdays with [TT] in the title)  
  
**Involvement:**  
Solo developer (GeeseBumps / Javi Prieto). Original concept, game design, Godot implementation, and optical simulation by me; original music by Haddhar and code collaboration by Adeluiz.

---

**In-Game Screenshots & Visuals:**  
*(Note: While the interface in these screenshots is shown in Spanish, PhotoHacks is fully translated into English. The game prompts for language on the very first launch, and you can switch between English and Spanish anytime in Options).*
```

### 2.3 Galería de Imágenes Incrustadas (con `<figcaption>`)
Cada una de las 6 imágenes se subió directamente a los servidores de Reddit y cuenta con su pie de foto visible:

1. **`03_visor_reflex.png`**:
   - *Pie*: `SLR Viewfinder: true split-image manual focus, 9-point AF, and light metering bar.`
2. **`04_parque_dia.png`**:
   - *Pie*: `Urban Park (Daytime): 3D procedural crowd, pedestrian behaviors, and dynamic environment.`
3. **`05b_hora_dorada.png`**:
   - *Pie*: `Golden Hour lighting: warm directional sunlight with long cast shadows.`
4. **`06_parque_noche.png`**:
   - *Pie*: `Night scene: warm streetlamps with projected shadows and low light (EV 2-8).`
5. **`07_revelado.png`**:
   - *Pie*: `Photo critique report: detailed optical breakdown of depth of field, shake, blur, and exposure.`
6. **`ejemplo_pantalla.jpg`**:
   - *Pie*: `Where it all started: original game design document mockup from 2011 (Proyecto Paparazzi).`

---

## 3. Estado de la Publicación y Verificación

- **Verificación inicial**: Tras la publicación, el post apareció en el puesto #1 del feed de novedades `https://www.reddit.com/r/playmygame/new/`.
- **Filtro de AutoModerator**: No fue interceptado ni retirado de forma automática de entrada.

---

## 4. Próximos Pasos y Protocolos de Actuación

### Escenario A: El post permanece activo y recibe interacción (Escenario Principal)
1. **Atención a comentarios**:
   - Responder con rapidez, humildad y rigor técnico a quienes prueben el juego en el navegador.
   - Pauta GeeseBumps: Agradecer siempre el tiempo dedicado, no discutir críticas sobre dificultad o estética, e incorporar sugerencias útiles.
2. **Registro de feedback**:
   - Si señalan problemas con el enfoque manual o la navegación con WASD en el parque grande, registrarlos en `docs/futuro/28_ENFOQUE_MANUAL_IMAGEN_PARTIDA.md` o en `docs/NAVEGACION_Y_COLISIONES.md`.
   - Si reportan caídas de rendimiento en el navegador con WebGL, revisar el presupuesto de draw calls de la versión web (`docs/futuro/27_VERSION_WEB.md`).
3. **Plan de difusión escalonada (sin spam cruzado)**:
   - Esperar al menos 4–5 días antes de publicar en otras comunidades.
   - **Siguiente parada**: `r/godot` (post técnico sobre la implementación de shaders ópticos de desenfoque y telémetro analógico en Godot 4).
   - **Tercera parada**: `r/WebGames` (post directo con enlace a la versión jugable en navegador).

### Escenario B: Si el post es interceptado diferidamente por AutoModerator
1. **Causa probable**: Regla «1 post per month» interpretada por un bot a nivel de cuenta (Notrunner se publicó el 25-10-2026, hace 7 días).
2. **Acción inmediata (Modmail a `r/playmygame`)**:
   Enviar un mensaje a través de `https://www.reddit.com/message/compose?to=%2Fr%2Fplaymygame` con la siguiente plantilla:
   ```markdown
   Subject: Approval request for PhotoHacks post (different game, not a repost)

   Hi mod team,

   I noticed my post for PhotoHacks [https://www.reddit.com/r/playmygame/comments/1xl96cb/dev_photohacks_a_wheres_waldo_photography/] might have been caught by the automatic monthly filter.

   I wanted to clarify that this is a completely different game from my previous post (PhotoHacks is an open-source photography simulator and educational game in browser, whereas my previous post last week was Notrunner, an idle RPG).

   The game is 100% free, open source, playable directly in browser with no downloads, and has zero ads or microtransactions.

   Could you please review and manually approve the post?

   Thank you for your time and for maintaining this community!
   ```
3. **Plan de contingencia**:
   Si los moderadores insisten en aplicar la restricción de 30 días por autor, publicar PhotoHacks de inmediato en `r/godot` y reservar `r/playmygame` para finales de noviembre.
