#!/usr/bin/env python3
"""Textos del juego: se editan en Markdown (textos/<idioma>/*.md) y de ahí se genera el JSON que
lee el juego (data/textos.<idioma>.json). El JSON no se toca a mano.

    python3 tools/textos.py                 importa el español (valida y escribe el JSON)
    python3 tools/textos.py --comprobar     valida sin escribir (sale con error si el JSON no está al día)
    python3 tools/textos.py --idioma en     importa otro idioma (textos/en/)
    python3 tools/textos.py --nuevo-idioma en   crea textos/en/ con el español como punto de partida
    python3 tools/textos.py --exportar      (una sola vez) crea textos/es/ a partir del JSON actual

Formato de un fichero:

    # Título del fichero
    ## Bloque (una pantalla, una lección, un nivel)
    ### clave_del_texto · etiqueta para quien edita
    > nota: no llega al juego (el tamaño máximo, para qué es)
    El texto, en una o varias líneas. Una línea en blanco dentro del texto se conserva.

Dentro de un texto: {control} es una tecla o un botón (los pone el juego según el dispositivo) y
%s, %d, %.1f… son huecos que el juego rellena: hay que conservarlos, y en el mismo orden.
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = "es"
# Tamaño razonable de cada hueco (docs/TESTS_Y_VERIFICACION.md §4.3), en caracteres.
LIMITS = [
    (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_t\d+_texto|academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_examen", 240), (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_t\d+_titulo", 30),
    (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_d\d+", 110), (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_resumen", 60), (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_p\d+", 75),
    (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_pista_.*", 130), (r"arcade_nivel_\d+_titulo", 22), (r"arcade_nivel_\d+_texto", 220),
    (r"academia_[a-z]+_intro", 110), (r"esquema_.*", 62), (r"cond_.*", 100), (r"tutorial_(?!resultado|paso|fin_titulo|ir_|menu|bien|pendiente|empezar|saltar|salir|continuar).*", 210),
    (r"tutorial_.*_texto", 120), (r"modo_.*_texto", 180), (r"insignia_.*_texto", 100), (r"pista_bajar_camara", 85),
]
# Dónde va cada clave al exportar: (patrón, fichero, bloque). El primero que casa manda.
PLACES = [
    (r"academia_(composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_.*", "academia", "Lección · {0}"), (r"academia_ex_.*|academia_examen.*|academia_graduado", "academia", "Exámenes: informe del tutor"),
    (r"academia_op_.*", "academia", "Botones de elección del panel"), (r"esquema_.*", "academia", "Esquemas"), (r"academia.*", "academia", "General"),
    (r"arcade_nivel_(\d+)_.*", "arcade", "Nivel {0}"), (r"cond_.*", "arcade", "Condiciones"), (r"arcade.*", "arcade", "General"),
    (r"tutorial_.*", "tutorial", "Tutorial"),
    (r"modo_.*|menu_.*|opcion_.*|tema_.*|intro_.*|escenario_.*", "menu", "Menú principal"), (r"pausa_.*", "menu", "Pausa"),
    (r"equipo_.*", "menu", "Equipo"), (r"sandbox_.*", "menu", "Sandbox"), (r"encargo_.*", "menu", "Encargo"),
    (r"gfx_.*", "graficos", "Gráficos"),
    (r"insignia_.*", "progreso", "Insignias"), (r"album_.*", "progreso", "Álbum"),
    (r"ayuda_.*|pad_.*|teclado_.*|raton_.*|control_.*", "controles", "Ayuda de controles"),
    (r"visor_.*|tlr_.*|bloqueo_.*|fotometria_.*|estado_.*|paseo_.*|buscar_.*|pista_.*|subir_.*|bajar_.*|af_.*", "camara", "Visor y búsqueda"),
    (r"ficha_.*|enfoque_.*|exposicion_.*|movimiento_.*|oclusion_.*|encuadre_.*|mov_.*", "resultado", "Informe de la foto"),
    (r"rasgo_.*|un_.*|una_.*|cabeza_.*|pantalon_.*", "personajes", "Personajes y objetos"),
    (r".*", "varios", "Varios"),
]
LABELS = [
    (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_titulo", "título de la lección"), (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_resumen", "resumen (menú de la Academia)"),
    (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_t(\d+)_titulo", "teoría {0} · título"), (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_t(\d+)_texto", "teoría {0} · texto"),
    (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_d(\d+)", "demostración · subtítulo {0}"), (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_p(\d+)", "práctica · tarea {0}"),
    (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_pista_(.*)", "pista · {0}"), (r"academia_(?:composicion|enfoque|focal|exposicion|dof|movimiento|medicion|modos|objetivos|camaras)_examen", "examen · enunciado"),
    (r"arcade_nivel_\d+_titulo", "título"), (r"arcade_nivel_\d+_texto", "encargo"),
]
SPEC = re.compile(r"%(?:[-+0 ]*\d*(?:\.\d+)?[sdf]|%)")
CONTROL = re.compile(r"\{([a-z_0-9]+)\}")


def limit_of(key):
    for pattern, limit in LIMITS:
        if re.fullmatch(pattern, key):
            return limit
    return 0


def visible_length(value):
    return len(re.sub(r"[⟦⟧⦅⦆]", "", CONTROL.sub("X", value)))


def read_markdown(folder):
    """→ ({clave: texto}, [(fichero, clave)] en orden), con los errores de formato."""
    texts, order, errors = {}, [], []
    for path in sorted(folder.glob("*.md")):
        key, lines = None, []

        def close():
            if key is None:
                return
            while lines and lines[-1].strip() == "":
                lines.pop()
            while lines and lines[0].strip() == "":
                lines.pop(0)
            if key in texts:
                errors.append("%s: la clave «%s» está repetida" % (path.name, key))
            texts[key] = "\n".join(lines)
            order.append((path.name, key))

        for raw in path.read_text(encoding="utf-8").split("\n"):
            if raw.startswith("### "):
                close()
                key, lines = raw[4:].split(" · ")[0].strip(), []
            elif raw.startswith("## ") or raw.startswith("# "):
                close()
                key, lines = None, []
            elif key is not None and not raw.startswith("> "):
                # «\» al final de una línea guarda los espacios finales (textos que acaban en espacio).
                lines.append(raw[:-1] if raw.endswith("\\") else raw.rstrip())
        close()
    return texts, order, errors


def controls():
    source = (ROOT / "scripts/input_glyphs.gd").read_text(encoding="utf-8")
    return set(re.findall(r'^\t"([a-z_0-9]+)": \[', source, re.M))


def used_keys():
    keys = set()
    for path in list((ROOT / "scripts").glob("*.gd")):
        keys.update(re.findall(r'get_(?:text|rich)\("([a-z_0-9]+)"\)', path.read_text(encoding="utf-8")))
    return keys


def validate(texts, base, language):
    errors, warnings = [], []
    known = controls()
    for key, value in texts.items():
        for name in CONTROL.findall(value):
            if name not in known:
                errors.append("%s: el control {%s} no existe (scripts/input_glyphs.gd)" % (key, name))
        limit = limit_of(key)
        if limit and visible_length(value) > limit:
            warnings.append("%s: %d caracteres, y su hueco pide %d como mucho" % (key, visible_length(value), limit))
        if key in base and SPEC.findall(value) != SPEC.findall(base[key]):
            errors.append("%s: los huecos (%s) no coinciden con los del original (%s)" % (key, " ".join(SPEC.findall(value)) or "ninguno", " ".join(SPEC.findall(base[key])) or "ninguno"))
        if value.strip() == "" and (key not in base or base[key].strip() != ""):
            warnings.append("%s: está vacío" % key)
    if language == BASE:
        for key in sorted(used_keys() - set(texts)):
            errors.append("%s: el juego lo usa y no está en ningún fichero" % key)
    else:
        missing = sorted(set(base) - set(texts))
        if missing:
            warnings.append("%d textos sin traducir (saldrán en español): %s%s" % (len(missing), ", ".join(missing[:8]), "…" if len(missing) > 8 else ""))
        for key in sorted(set(texts) - set(base)):
            errors.append("%s: no existe en español" % key)
    return errors, warnings


def write_markdown(texts, folder, note_from=None):
    files = {}
    for key, value in texts.items():
        for pattern, name, block in PLACES:
            match = re.fullmatch(pattern, key)
            if match:
                files.setdefault(name, {}).setdefault(block.format(*match.groups()), []).append((key, value))
                break
    folder.mkdir(parents=True, exist_ok=True)
    titles = {"academia": "Academia de fotografía", "arcade": "Arcade", "tutorial": "Tutorial", "menu": "Menú, equipo, sandbox y encargo",
              "graficos": "Ajustes gráficos", "progreso": "Insignias y álbum", "controles": "Ayuda de controles", "camara": "Visor y búsqueda",
              "resultado": "Informe de la foto", "personajes": "Personajes y objetos", "varios": "Varios"}
    for name, blocks in files.items():
        out = ["# %s" % titles[name], ""]
        natural = lambda b: [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", b)]
        for block in sorted(blocks, key=lambda b: (not b.startswith("General"), natural(b))):
            heading = block
            lesson = re.fullmatch(r"Lección · (\w+)", block)
            if lesson and ("academia_%s_titulo" % lesson.group(1)) in texts:
                heading = "Lección · " + texts["academia_%s_titulo" % lesson.group(1)]
            level = re.fullmatch(r"Nivel (\d+)", block)
            if level and ("arcade_nivel_%s_titulo" % level.group(1)) in texts:
                heading += " · " + texts["arcade_nivel_%s_titulo" % level.group(1)]
            out += ["## %s" % heading, ""]
            for key, value in blocks[block]:
                label = ""
                for pattern, text in LABELS:
                    match = re.fullmatch(pattern, key)
                    if match:
                        label = " · " + text.format(*[g.replace("_", " ") for g in match.groups()])
                        break
                out.append("### %s%s" % (key, label))
                if limit_of(key):
                    out.append("> máximo %d caracteres" % limit_of(key))
                if note_from is not None:
                    out += ["> es: " + line for line in note_from.get(key, "").split("\n")]
                out += [line + ("\\" if line != line.rstrip() else "") for line in value.split("\n")]
                out.append("")
        (folder / (name + ".md")).write_text("\n".join(out), encoding="utf-8")
    return len(files)


def main():
    args = sys.argv[1:]
    language = args[args.index("--idioma") + 1] if "--idioma" in args else BASE
    json_path = ROOT / "data" / ("textos.%s.json" % language)
    base_json = ROOT / "data" / ("textos.%s.json" % BASE)
    folder = ROOT / "textos" / language
    if "--exportar" in args:
        if folder.exists():
            sys.exit("textos/%s ya existe: se edita ahí y se importa; exportar lo pisaría." % language)
        count = write_markdown(json.loads(json_path.read_text(encoding="utf-8")), folder)
        print("Exportados %d ficheros a textos/%s/" % (count, language))
        return
    if "--nuevo-idioma" in args:
        new = args[args.index("--nuevo-idioma") + 1]
        target = ROOT / "textos" / new
        if target.exists():
            sys.exit("textos/%s ya existe." % new)
        spanish, _, _ = read_markdown(ROOT / "textos" / BASE)
        write_markdown(spanish, target, note_from=spanish)
        print("Creado textos/%s/ con el español de partida (cada texto lleva su original en una nota «> es:»)." % new)
        return
    texts, order, errors = read_markdown(folder)
    if not texts:
        sys.exit("No hay textos en textos/%s/" % language)
    base = texts if language == BASE else json.loads(base_json.read_text(encoding="utf-8"))
    previous = json.loads(json_path.read_text(encoding="utf-8")) if json_path.exists() else {}
    found, warnings = validate(texts, base if language != BASE else previous, language)
    errors += found
    for line in warnings:
        print("AVISO  " + line)
    for line in errors:
        print("ERROR  " + line)
    if errors:
        sys.exit("%d errores: no se ha escrito nada." % len(errors))
    ordered = {key: texts[key] for _, key in order}
    content = json.dumps(ordered, ensure_ascii=False, indent=2) + "\n"
    changed = sorted(k for k in ordered if previous.get(k) != ordered[k]) + sorted("−" + k for k in previous if k not in ordered)
    if "--comprobar" in args:
        if previous != ordered:
            sys.exit("data/textos.%s.json no está al día (%d cambios: %s). Ejecuta tools/textos.py." % (language, len(changed), ", ".join(changed[:6])))
        print("Textos al día: %d (%d avisos)." % (len(ordered), len(warnings)))
        return
    json_path.write_text(content, encoding="utf-8")
    print("%d textos → data/textos.%s.json · %d cambiados%s · %d avisos" % (len(ordered), language, len(changed), (": " + ", ".join(changed[:6]) + ("…" if len(changed) > 6 else "")) if changed else "", len(warnings)))


if __name__ == "__main__":
    main()
