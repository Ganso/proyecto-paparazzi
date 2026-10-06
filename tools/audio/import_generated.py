#!/usr/bin/env python3
"""Pasa a assets/audio/ los sonidos generados por IA (docs/futuro/24_SONIDOS_NECESARIOS.md).

    python3 tools/audio/import_generated.py [--only 26,27]

Lee una toma por sonido de cada generador:
    SA  Stable Audio Open   ~/docker/StableAudio/output/stable_audio_completo/NN_nombre.wav  (44,1 kHz estéreo)
    AG  AudioGen            ~/docker/AudioCraft/output/audiogen_completo/NN_nombre.wav       (16 kHz mono)
(o las carpetas de las variables SONIDOS_SA y SONIDOS_AG) y deja cada una como pide su ficha:
48 kHz y 16 bits (los ambientes en bucle, a 32 kHz y mono: suenan desde un punto del parque),
paso alto, recortada a su parte útil (empieza en la primera muestra y acaba en silencio), con el
pico de la ficha; los bucles, con el final fundido sobre el principio para que empalmen.

Qué toma se usa de cada sonido está en TABLE, con el motivo cuando no es la de Stable Audio (que
es la que se prefiere a igualdad: AudioGen sale a 16 kHz y a menudo con ruido de fondo continuo).
Donde la ficha pide variaciones, la segunda es la del otro generador si vale. Las que faltan se
añaden como más ficheros nombre_N.wav en las carpetas de origen (NN_nombre_3.wav…) y aquí.
"""
import math, os, pathlib, sys, wave
import numpy as np
import scipy.io.wavfile as wavfile
import scipy.signal as sg

HOME = pathlib.Path.home()
SRC = {"SA": pathlib.Path(os.environ.get("SONIDOS_SA", HOME / "docker/StableAudio/output/stable_audio_completo")),
       "AG": pathlib.Path(os.environ.get("SONIDOS_AG", HOME / "docker/AudioCraft/output/audiogen_completo"))}
OUT = pathlib.Path(__file__).resolve().parent.parent.parent / "assets" / "audio"

# n.º, nombre, carpeta, tipo (one | loop | asis), canales, pico dBFS, duración máxima (s; en los
# bucles, la del bucle), paso alto (Hz), tomas (generador[:modo]; modo «peak» = el evento más fuerte)
C, A, G, U = "camara", "ambiente", "gente", "interfaz"
TABLE = [
    (1, "obturador_reflex", C, "one", 1, -3, .50, 80, ["SA"]),
    (2, "obturador_reflex_lento", C, "one", 1, -3, .95, 80, ["SA"]),
    (3, "obturador_telemetrica", C, "one", 1, -6, .30, 80, ["SA"]),
    (4, "obturador_compacta", C, "one", 1, -6, .40, 80, ["SA"]),
    (5, "obturador_tlr", C, "one", 1, -6, .20, 80, ["SA"]),
    (6, "manivela_tlr", C, "one", 1, -6, 1.10, 80, ["SA"]),
    (7, "carrete_nuevo", C, "one", 1, -6, 2.80, 80, ["SA"]),
    (10, "motor_af", C, "one", 1, -12, .40, 80, ["SA"]),                    # AG: un zumbido grave continuo, no vale de segunda
    (11, "zoom_compacta", C, "loop", 1, -12, 1.40, 80, ["AG"]),             # SA arranca y se para a los 0,67 s: no da un régimen constante
    (12, "zoom_compacta_fin", C, "one", 1, -12, .18, 80, ["SA"]),
    (13, "anillo_enfoque", C, "one", 1, -15, .07, 80, ["SA", "AG"]),
    (14, "dial", C, "one", 1, -12, .09, 80, ["SA", "AG"]),
    (15, "camara_subir", C, "one", 1, -15, .45, 80, ["SA"]),
    (16, "camara_bajar", C, "one", 1, -15, .50, 80, ["SA"]),
    (17, "pajaros_dia", A, "loop", 1, -6, 23.0, 150, ["SA"]),               # AG: solo graves, sin pájaros
    (18, "pajaros_atardecer", A, "loop", 1, -6, 23.0, 150, ["SA"]),
    (19, "hora_azul", A, "loop", 1, -9, 23.0, 150, ["SA"]),
    (20, "grillos_noche", A, "loop", 1, -9, 23.0, 150, ["SA"]),
    (21, "fuente", A, "loop", 1, -9, 11.0, 80, ["SA"]),
    # 22 hojas_viento: ninguna de las dos vale (las dos son un rumor por debajo de 80 Hz, sin hojas).
    (23, "zureo", A, "one", 1, -9, 2.0, 80, ["SA", "AG"]),
    (24, "aleteo_bandada", A, "one", 1, -6, 2.5, 80, ["SA"]),
    (25, "aleteo_paloma", A, "one", 1, -12, .6, 80, ["SA"]),
    (26, "paso_grava", G, "one", 1, -12, .30, 40, ["SA", "AG"]),
    (27, "paso_losa", G, "one", 1, -12, .25, 40, ["SA"]),
    (28, "paso_cesped", G, "one", 1, -15, .30, 40, ["SA"]),
    (29, "paso_corredor", G, "one", 1, -9, .25, 40, ["SA", "AG:peak"]),
    (30, "charla", G, "loop", 1, -12, 11.0, 80, ["AG"]),                    # SA: casi todo por debajo de 80 Hz, sin voces
    (31, "risa", G, "one", 1, -12, 2.0, 80, ["SA", "AG"]),
    (32, "ninos_jugando", G, "loop", 1, -9, 18.0, 150, ["SA"]),
    (33, "columpio", G, "asis", 1, -15, 2.73, 150, ["SA"]),                 # 2,730 s exactos: se deja con su silencio final
    (34, "tobogan", G, "one", 1, -12, 1.3, 80, ["SA"]),
    (35, "balon_patada", G, "one", 1, -9, .25, 40, ["SA", "AG"]),
    (36, "balon_bote", G, "one", 1, -12, .20, 40, ["SA"]),
    (37, "perro_ladrido", G, "one", 1, -9, .60, 80, ["SA", "AG"]),
    (38, "perro_jadeo", G, "asis", 1, -18, 2.5, 150, ["SA"]),
    (39, "periodico", G, "one", 1, -15, 1.0, 150, ["SA", "AG"]),
    (40, "taza", G, "one", 1, -15, .25, 80, ["SA"]),
    (41, "ui_mover", U, "one", 2, -15, .10, 80, ["SA"]),
    (42, "ui_aceptar", U, "one", 2, -12, .30, 80, ["SA"]),
    (43, "ui_atras", U, "one", 2, -12, .30, 80, ["SA"]),
    (44, "ui_bloqueado", U, "one", 2, -12, .35, 60, ["SA"]),
    (45, "pausa", U, "one", 2, -12, .25, 80, ["SA"]),
    (46, "revelado", U, "one", 2, -12, .70, 80, ["SA"]),
    (47, "foto_rechazada", U, "one", 2, -12, .50, 80, ["SA"]),
    (48, "estrella", U, "one", 2, -9, .45, 80, ["SA"]),
    (49, "nivel_superado", U, "one", 2, -6, 3.0, 80, ["SA"]),
    (50, "nivel_no_superado", U, "one", 2, -9, 2.0, 80, ["SA"]),
    (51, "tictac", U, "one", 2, -12, .15, 80, ["SA"]),
    (52, "tiempo_agotado", U, "one", 2, -6, 1.0, 80, ["SA"]),
    (53, "tutorial_ok", U, "one", 2, -12, .50, 80, ["SA"]),
    (54, "obturador_reflex_rapido", C, "one", 1, -3, .30, 80, ["SA"]),
    (55, "control_elegir", C, "one", 1, -15, .13, 80, ["SA"]),
    (56, "dial_tope", C, "one", 1, -15, .10, 80, ["SA"]),
    (58, "medicion", C, "one", 1, -15, .15, 80, ["SA"]),
    (59, "lupa_tlr", C, "one", 1, -12, .30, 80, ["SA"]),
    (60, "pato", A, "one", 1, -9, .60, 150, ["SA"]),
    (61, "pato_agua", A, "one", 1, -12, 1.5, 80, ["SA"]),
    (62, "movil", G, "one", 1, -18, .80, 60, ["SA", "AG"]),
    (63, "migas", G, "one", 1, -18, .50, 150, ["SA", "AG"]),
    (64, "paraguas", G, "one", 1, -18, .50, 150, ["SA"]),
    (65, "insignia", U, "one", 2, -6, 1.5, 80, ["SA"]),
    (66, "album", U, "one", 2, -12, .75, 80, ["SA"]),
    (67, "leccion_superada", U, "one", 2, -9, 1.5, 80, ["SA"]),
    (68, "graduado", U, "one", 2, -3, 5.0, 80, ["SA"]),
    (69, "condicion_ok", U, "one", 2, -12, .25, 80, ["SA"]),
]
# Variaciones que pide la ficha (las que no están en TABLE, una sola).
WANTED = {10: 2, 13: 4, 14: 3, 22: 3, 23: 3, 24: 2, 25: 2, 26: 6, 27: 6, 28: 4, 29: 4, 30: 2, 31: 3, 35: 2, 36: 2,
          37: 3, 39: 2, 60: 3, 61: 2, 62: 2, 63: 2, 64: 2}
RATE = 48000
LOOP_RATE = 32000


def load(path, rate):
    sr, x = wavfile.read(path)
    x = x.astype(np.float64)
    if np.abs(x).max() > 1.5: x /= 32768.0
    if x.ndim == 1: x = x[:, None]
    if sr != rate:
        g = math.gcd(sr, rate)
        x = sg.resample_poly(x, rate // g, sr // g, axis=0)
    return x


def level(x, rate, hop=.002, win=.01):
    """Nivel por tramos, en dB respecto al tramo más fuerte."""
    m = x.mean(axis=1)
    h, w = int(rate * hop), int(rate * win)
    fr = np.array([np.sqrt(np.mean(m[i:i + w] ** 2)) for i in range(0, max(1, len(m) - w), h)]) + 1e-12
    return 20 * np.log10(fr / fr.max()), h


def fade(x, rate, head, tail):
    n = len(x)
    a, b = min(n, int(rate * head)), min(n, int(rate * tail))
    if a > 0: x[:a] *= np.linspace(0, 1, a)[:, None]
    if b > 0: x[-b:] *= np.linspace(1, 0, b)[:, None]
    return x


def one_shot(x, rate, max_dur, mode):
    db, h = level(x, rate)
    if mode == "peak":
        # The strongest event (a take with several steps): back to where it rises from the floor.
        top = int(np.argmax(db))
        start = top
        while start > 0 and db[start - 1] > -30: start -= 1
    else:
        active = np.where(db > -40)[0]
        start = int(active[0])
    first = max(0, start * h - int(rate * .002))
    limit = first + int(rate * max_dur)
    window = db[start:min(len(db), limit // h)]
    live = np.where(window > -45)[0]
    last = min(limit, (start + int(live[-1]) + 1) * h + int(rate * .012)) if len(live) else limit
    cut = x[first:min(last, len(x))].copy()
    natural_end = last < limit
    return fade(cut, rate, .001, .010 if natural_end else .020)


def loop(x, rate, length):
    db, h = level(x, rate, .05, .2)
    active = np.where(db > -35)[0]
    x = x[int(active[0]) * h:min(len(x), (int(active[-1]) + 1) * h + int(rate * .2))]
    n = int(rate * length)
    cross = int(rate * min(1.0, length * .08))
    if len(x) < n + cross:
        n = len(x) - cross
    body = x[:n].copy()
    tail = x[n:n + cross]
    # The end of the take, faded in under the beginning: where the loop wraps the sound goes on.
    t = np.linspace(0, 1, cross)[:, None]
    body[:cross] = body[:cross] * np.sin(t * math.pi / 2) + tail * np.cos(t * math.pi / 2)
    return body


def write(path, x, channels, peak_db, rate):
    if channels == 1: x = x.mean(axis=1, keepdims=True)
    elif x.shape[1] == 1: x = np.repeat(x, 2, axis=1)
    x = x * (10 ** (peak_db / 20) / (np.abs(x).max() + 1e-12))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(channels)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes((np.clip(x, -1, 1) * 32767).round().astype("<i2").tobytes())
    (path.parent / (path.name + ".import")).write_text('[remap]\n\nimporter="keep"\n')
    return len(x) / rate


def main():
    only = []
    if "--only" in sys.argv: only = [int(v) for v in sys.argv[sys.argv.index("--only") + 1].split(",")]
    missing = 0
    for number, name, folder, kind, channels, peak, max_dur, highpass, takes in TABLE:
        wanted = WANTED.get(number, 1)
        if only and number not in only:
            missing += max(0, wanted - len(takes))
            continue
        rate = LOOP_RATE if kind == "loop" and folder in (A, G) and max_dur > 5 else RATE
        for k, take in enumerate(takes):
            system, _, mode = take.partition(":")
            # (extra takes for the variations: NN_nombre_3.wav… in the folder of the generator)
            source = SRC[system] / ("%02d_%s.wav" % (number, name))
            if mode.isdigit(): source, mode = SRC[system] / ("%02d_%s_%s.wav" % (number, name, mode)), ""
            x = load(source, rate)
            x = sg.sosfiltfilt(sg.butter(4, highpass, "hp", fs=rate, output="sos"), x, axis=0)
            if kind == "one": x = one_shot(x, rate, max_dur, mode)
            elif kind == "loop": x = loop(x, rate, max_dur)
            else: x = x[:int(round(rate * max_dur))]
            target = OUT / folder / (name + ("_%d" % (k + 1) if wanted > 1 else "") + ".wav")
            seconds = write(target, x, channels, peak, rate)
            print("%2d %-28s %s %-7s %6.3f s  %d Hz  %s  pico %+d" % (number, target.name, system, kind, seconds, rate, "estéreo" if channels == 2 else "mono", peak))
        if wanted > len(takes): missing += wanted - len(takes)
    print("Faltan %d variaciones (más las 3 de hojas_viento)." % missing)


if __name__ == "__main__":
    main()
