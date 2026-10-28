# 25. Textos editables en Markdown y camino al multiidioma

> **Estado**: textos en Markdown con importación y validación ✅ **hecho** (03-10-2026). **Versión en inglés ✅ hecha** (28-10-2026, §4): el juego entero en inglés, con elección de idioma en el primer arranque y en Opciones. Otros idiomas: misma receta (§5).

## 1. Cómo se editan los textos

Los textos del juego **se editan en `textos/<idioma>/*.md`** (`es`, el original, y `en`) y de ahí se genera `data/textos.<idioma>.json`, que es lo que lee el juego (`scripts/texts.gd`). **El JSON no se toca a mano.** Un texto nuevo o cambiado se escribe en los dos idiomas.

| Fichero | Contenido |
|---|---|
| `academia.md` | Las diez lecciones (un bloque por lección), el informe de los exámenes, los esquemas y los botones del panel |
| `arcade.md` | Un bloque por nivel (título y encargo), las condiciones y lo general del modo |
| `tutorial.md` | Los pasos del tutorial y su pantalla final |
| `menu.md` | Menú principal, pausa, equipo, sandbox y encargo |
| `controles.md` | Ayuda de teclado, ratón y mando, y la ayuda en pantalla |
| `camara.md` | Visor, avisos de la búsqueda, paseo |
| `resultado.md` | El informe de cada foto |
| `graficos.md` | Ajustes gráficos |
| `progreso.md` | Insignias y álbum |
| `personajes.md` | Rasgos de los encargos y nombres de los objetos del parque |
| `varios.md` | Lo demás (textos antiguos con claves largas) |

Formato:

```markdown
## Lección 1 · La exposición

### academia_l1_t1_texto · teoría 1 · texto
> máximo 240 caracteres
Hacer una foto es llenar un cubo de luz: si te quedas corto, sale oscura…
```

- `## …` abre un bloque (una pantalla, una lección, un nivel). Es solo para orientarse.
- `### clave · etiqueta` abre un texto. **La clave no se cambia** (es por la que el juego lo pide); la etiqueta tras el `·` es libre.
- Las líneas que empiezan por `> ` son notas: no llegan al juego (el tamaño máximo, para qué sirve).
- El texto puede ocupar varias líneas; los saltos de línea se conservan.
- **Mayúscula tras punto y tras dos puntos** (estilo del proyecto: «La velocidad: El tiempo»).
- `{control}` es una tecla o un botón: lo pone el juego según el dispositivo en uso (lista en `scripts/input_glyphs.gd`).
- `%s`, `%d`, `%.1f`… son huecos que rellena el juego: hay que conservarlos, y en el mismo orden.

## 2. Reimportar

```bash
python3 tools/textos.py
```

Valida y escribe el JSON de cada idioma (primero el español, contra el que se validan los demás; `--idioma en` hace solo uno). Dice cuántos textos han cambiado y cuáles. No escribe nada si hay errores:

- **Errores** (bloquean): clave repetida, un `{control}` que no existe, huecos `%…` que no coinciden con los que había, un texto que el código pide y no está.
- **Avisos** (no bloquean): un texto más largo que el tamaño razonable de su hueco ([TESTS_Y_VERIFICACION §4.3](../TESTS_Y_VERIFICACION.md), el mismo para todos los idiomas), un texto vacío, textos sin traducir.

`python3 tools/textos.py --comprobar` valida sin escribir; lo pasa `tests/test_texts.gd` (sin pantalla), que falla si el JSON no está al día con el Markdown. El aviso de tamaño cuenta caracteres, que es una aproximación: tras cambiar un texto sigue haciendo falta la captura de su pantalla (`tools/check_text_fit.gd`).

Un texto nuevo: se añade su `### clave` en el bloque que toque, se importa y se usa en el código con `Texts.get_text("clave")` (o `get_rich` si lleva teclas dibujadas).

## 3. Decisiones tomadas pensando en otros idiomas

1. **El español es el original** (`textos/es/`). Cada idioma tendrá su carpeta `textos/<código>/` con los mismos ficheros, bloques y claves, y su `data/textos.<código>.json`.
2. **Las claves son el contrato**, no el texto español: ningún sitio del código compara textos visibles ni depende de su contenido (la última excepción, el pantalón de vestir de `casting.gd`, se quitó con la versión inglesa).
3. **Lo que falte en un idioma sale en español**: `texts.gd` carga el español y superpone el idioma. Una traducción a medias no rompe nada.
4. **Los huecos se validan contra el español**: una traducción no puede perder un `%d` ni inventarse un `{control}`.
5. **Arranque de un idioma**: `python3 tools/textos.py --nuevo-idioma en` crea `textos/en/` con cada texto en español y su original en una nota `> es:` para traducir encima. `python3 tools/textos.py --idioma en` lo importa y avisa de lo que queda sin traducir.
6. **Sin texto en el código**: el 03-10-2026 se sacaron los 91 textos que quedaban escritos a mano (equipo, sandbox, encargo, barra de estado, fichas de la foto, esquemas de la Academia, botones del panel).

## 4. La versión en inglés (28-10-2026)

Encargo del usuario: «la versión en inglés del juego completo: todos los textos, todos los menús», con elección al arrancar si nunca se ha definido y en el menú a partir de ahí, comprobada pantalla a pantalla en los dos idiomas («no solo que quepan, sino que la distribución sea agradable y armónica») y **con el mismo tono que el español**, novedades de cada versión incluidas.

### 4.1 Cómo funciona

- **Idioma del jugador** en `user://interfaz.cfg` (`interfaz/idioma`), leído por `scripts/texts.gd` (`current()`, `set_language()`, `chosen()`). Lo que falte en inglés sale en español.
- **Primer arranque**: si nunca se ha elegido, el menú abre antes que nada (antes que las novedades) la ventana «Idioma · Language» (`main_menu.gd::show_language_choice()`), escrita en los dos idiomas, con el idioma del sistema en foco (inglés si el sistema no está en español). Hasta elegir, el juego usa ese mismo idioma propuesto.
- **Opciones**: botón «Idioma: Español» / «Language: English», que pasa al siguiente. Cambiar de idioma recarga la escena, como el tema (`main.gd::set_language()`). La tarjeta de Opciones quedó en un botón ancho (Gráficos) y cuatro filas de dos por parejas: idioma y tema, equipo del Sandbox y pasos de exposición, mirada y vibración, álbum e insignias.
- **Pruebas y capturas**: `-- --idioma=es|en` elige el idioma sin guardarlo (las pruebas nunca tocan la elección del jugador).

### 4.2 Lo que no estaba en los textos y se resolvió

| Qué | Dónde estaba | Cómo queda |
|---|---|---|
| Nombres de controles («Cruceta», «Stick izquierdo», «Mayús», «Re Pág»…) | `scripts/input_glyphs.gd` | Tablas `CONTROLS_EN` y `TOUCH_EN` junto a las españolas (`k()` elige por idioma); `tests/test_texts.gd` comprueba que tienen los mismos controles. Las teclas anchas del teclado dibujado, en `keyboard_diagram.gd::KEY_NAMES_EN`. |
| Cámaras, objetivos y modos de enfoque | `scripts/equipment.gd` (también identificadores) | Los identificadores no cambian; lo visible sale de `camera_name()`, `lens_name()` («Fijo» → `equipo_fijo`) y `focus_name()` (textos `equipo_cuerpo_*`, `equipo_af_*`). |
| Perfiles gráficos («Bajo», «Medio», «Alto») | `main.gd` | `profile_name()` y textos `gfx_nombre_*`. |
| Prendas, colores y complexiones | `data/catalogo.json`, gramática española en `casting.gd` | Campos `en` (y `en_color` cuando el color no va delante: «short %s hair», «a %s backpack») en piezas, tonos y perfiles. **Quién se distingue de quién se decide siempre en español** (`descriptors(t,"es")`), así que el reparto y los encargos son idénticos en los dos idiomas. Se quitó la comparación del identificador del pantalón de vestir con un texto (§3, punto 2). |
| Lugar de cada foto del álbum | Se guardaba ya traducido | Se guarda la clave (`lugar`: `["album_nivel", n]`) y se traduce al enseñarlo (`main.gd::album_where()`); las fotos antiguas conservan su `where`. |
| «Cargando el parque…» en la imagen de arranque del motor | `assets/marca/carga.png` | La imagen solo lleva cámara y nombre (el motor no sabe el idioma); la frase la pone `boot_loader.gd`. |
| Cuatro textos escritos a mano (resultado del Sandbox, botón «Equipo», lo que tapa un viandante, nombres del triángulo de exposición) | `main.gd`, `person.gd`, `academy_diagram.gd` | Pasados a textos. |

### 4.3 Criterios de la traducción

- **Inglés americano** (*color*, *center*, *gray*, *meters*), en segunda persona, cercano y con humor, como el español: es divulgación al estilo de Jaime Altozano, no un manual.
- **Mayúscula tras dos puntos** también en inglés, para conservar el estilo de la casa («Aperture priority (A): You're in charge…»).
- **Comillas** “inglesas” donde el español usa «latinas». Personajes sin género cuando el español solo lo tiene por gramática (*they*).
- Vocabulario fijo: *assignment* (encargo), *gear* (equipo), *light meter* (exposímetro), *stop* (paso), *third stops* (tercios de paso), *panning* (barrido), *light trail* (estela), *camera shake* (trepidación), *rangefinder* (telemétrica), *SLR* (réflex), *prime* (fijo), *Area AF* / *Single-point AF* (AF matricial / puntual), *spot / center-weighted / matrix* (medición), *bandstand* (quiosco), *passers-by* (viandantes), *extras* (figurantes).
- Los tamaños razonables (§4.3 de [TESTS_Y_VERIFICACION](../TESTS_Y_VERIFICACION.md)) valen igual para el inglés: el importador avisa si un texto inglés se pasa.

### 4.4 Comprobación

`tools/check_text_fit.gd` recorre todas las pantallas en cada idioma (`-- --idioma=en`), con teclado, con mando y, con `-- --touch`, con los dedos. Desde esta versión recorre también la elección de idioma, las novedades de todas las versiones (página a página), el aviso de la versión web, el botón de versión nueva, los gráficos en Personalizado y el menú de pausa de la Academia, y **detecta un texto que se mete bajo un botón que no es suyo** (así apareció «Show FPS» bajo su desplegable). Además de la herramienta, cada captura se mira a ojo.

## 5. Para otro idioma

1. `python3 tools/textos.py --nuevo-idioma xx` (crea `textos/xx/` con el español y su original en notas) y traducir encima.
2. Añadir `xx` a `Texts.LANGUAGES`, su nombre (`idioma_xx`, escrito en ese idioma) en todos los ficheros y su línea en `idioma_titulo` / `idioma_nota`.
3. Tablas de controles (`input_glyphs.gd`), teclas anchas (`keyboard_diagram.gd`) y nombres del catálogo (`catalogo.json`, con la regla de concordancia que pida su gramática en `casting.gd::garment()`).
4. **Tipografías**: Roboto, Quicksand y Russo One cubren los idiomas latinos; otros alfabetos necesitarán fuentes.
5. Recorrer todas las pantallas con `check_text_fit.gd -- --idioma=xx --all-shots` y mirar las capturas: idiomas más largos (alemán) apretarán botones y tarjetas.
