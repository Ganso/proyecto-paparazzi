"""Ayudas para cambiar textos de textos/es/*.md desde un script (las usan las sesiones de trabajo):
    from textos_editar import *;  setv(clave, texto);  add(tras_clave, clave, etiqueta, texto, limite);  delete(clave);  guardar()
"""
import re, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
files = {f: f.read_text() for f in (ROOT / "textos/es").glob("*.md")}

def find(key):
    for f, t in files.items():
        m = re.search(r'(?m)^### ' + re.escape(key) + r'(?: ·[^\n]*)?\n', t)
        if m: return f, m
    raise KeyError(key)

def _end(t, m):
    n = re.search(r'(?m)^##', t[m.end():])
    return m.end() + n.start() if n else len(t)

def setv(key, value):
    f, m = find(key); t = files[f]; end = _end(t, m)
    notes = "".join(l + "\n" for l in t[m.end():end].split("\n") if l.startswith("> "))
    files[f] = t[:m.end()] + notes + value + "\n\n" + t[end:]

def add(after, key, label, value, limit=0):
    f, m = find(after); t = files[f]; end = _end(t, m)
    block = "### %s%s\n%s%s\n\n" % (key, " · " + label if label else "", "> máximo %d caracteres\n" % limit if limit else "", value)
    files[f] = t[:end] + block + t[end:]

def delete(key):
    f, m = find(key); t = files[f]
    files[f] = t[:m.start()] + t[_end(t, m):]

def guardar():
    for f, t in files.items(): f.write_text(t)
