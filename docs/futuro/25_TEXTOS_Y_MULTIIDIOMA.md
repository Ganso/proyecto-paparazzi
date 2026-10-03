# 25. Textos editables en Markdown y camino al multiidioma

> **Estado**: textos en Markdown con importación y validación ✅ **hecho** (03-10-2026). Soporte multiidioma ⏳ **pendiente** (§4): las decisiones de base ya están tomadas para que sea fácil.

## 1. Cómo se editan los textos

Los textos del juego **se editan en `textos/es/*.md`** y de ahí se genera `data/textos.es.json`, que es lo que lee el juego (`scripts/texts.gd`). **El JSON no se toca a mano.**

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
- `{control}` es una tecla o un botón: lo pone el juego según el dispositivo en uso (lista en `scripts/input_glyphs.gd`).
- `%s`, `%d`, `%.1f`… son huecos que rellena el juego: hay que conservarlos, y en el mismo orden.

## 2. Reimportar

```bash
python3 tools/textos.py
```

Valida y escribe el JSON. Dice cuántos textos han cambiado y cuáles. No escribe nada si hay errores:

- **Errores** (bloquean): clave repetida, un `{control}` que no existe, huecos `%…` que no coinciden con los que había, un texto que el código pide y no está.
- **Avisos** (no bloquean): un texto más largo que el tamaño razonable de su hueco ([TESTS_Y_VERIFICACION §4.3](../TESTS_Y_VERIFICACION.md)), un texto vacío.

`python3 tools/textos.py --comprobar` valida sin escribir; lo pasa `tests/test_texts.gd` (sin pantalla), que falla si el JSON no está al día con el Markdown. El aviso de tamaño cuenta caracteres, que es una aproximación: tras cambiar un texto sigue haciendo falta la captura de su pantalla (`tools/check_text_fit.gd`).

Un texto nuevo: se añade su `### clave` en el bloque que toque, se importa y se usa en el código con `Texts.get_text("clave")` (o `get_rich` si lleva teclas dibujadas).

## 3. Decisiones tomadas pensando en otros idiomas

1. **El español es el original** (`textos/es/`). Cada idioma tendrá su carpeta `textos/<código>/` con los mismos ficheros, bloques y claves, y su `data/textos.<código>.json`.
2. **Las claves son el contrato**, no el texto español: ningún sitio del código compara textos visibles ni depende de su contenido (queda una excepción, §4.3).
3. **Lo que falte en un idioma sale en español**: `texts.gd` carga el español y superpone el idioma. Una traducción a medias no rompe nada.
4. **Los huecos se validan contra el español**: una traducción no puede perder un `%d` ni inventarse un `{control}`.
5. **Arranque de un idioma**: `python3 tools/textos.py --nuevo-idioma en` crea `textos/en/` con cada texto en español y su original en una nota `> es:` para traducir encima. `python3 tools/textos.py --idioma en` lo importa y avisa de lo que queda sin traducir.
6. **Sin texto en el código**: el 03-10-2026 se sacaron los 91 textos que quedaban escritos a mano (equipo, sandbox, encargo, barra de estado, fichas de la foto, esquemas de la Academia, botones del panel).

## 4. Pendiente para el multiidioma

1. **Selector de idioma** en Opciones, guardado en `user://interfaz.cfg` (hoy `texts.gd` usa el idioma del sistema si existe su JSON), con recarga de la interfaz.
2. **Nombres de los controles** (`scripts/input_glyphs.gd`): «Cruceta», «Stick izquierdo», «Rueda», «Mayús», «Re Pág»… están en español dentro de la tabla. Hay que pasarlos a textos.
3. **Nombres del equipo y del vestuario**: cámaras, objetivos y modos de enfoque (`scripts/equipment.gd`; «AF puntual», «MF»… se usan además como identificadores en el código: hay que separar identificador y nombre visible) y prendas, colores y perfiles de `data/catalogo.json`, con sus formas de género y número, que son gramática española (`casting.gd::garment()`): cada idioma necesitará su regla de concordancia.
4. **Tamaños**: la tabla de tamaños razonables está medida para el español. Otros idiomas (alemán, por ejemplo) alargan los textos: habrá que revisar pantalla a pantalla con `tools/check_text_fit.gd` en cada idioma.
5. **Tipografías**: Roboto y Quicksand cubren los idiomas latinos; otros alfabetos necesitarán fuentes.
6. **Textos dentro de imágenes y sonidos**: no hay (la pantalla de carga solo lleva el nombre del juego).
7. **`varios.md`** conserva claves antiguas largas, algunas quizá sin uso: conviene limpiarlas antes de traducir.
