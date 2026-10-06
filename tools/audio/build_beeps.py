#!/usr/bin/env python3
"""Pitidos de tono puro de docs/futuro/24_SONIDOS_NECESARIOS.md, sintetizados.

    python3 tools/audio/build_beeps.py

Escribe en assets/audio/camara/ (WAV PCM, 48 kHz, 16 bits) los sonidos de la lista que son un
tono puro, con la duración, el canal y el pico de su ficha: no hace falta grabarlos ni generarlos
con una IA. Solo esos (usuario, 06-10-2026): las notas de campanilla y el tictac se generan aparte. Empiezan en la primera muestra y
acaban en silencio digital.
"""
import math, pathlib, struct, wave

RATE = 48000
ROOT = pathlib.Path(__file__).resolve().parent.parent.parent / "assets" / "audio"


def envelope(i, n, attack=.005, release=.005):
    t, total = i / RATE, n / RATE
    return min(1.0, t / attack, max(0.0, (total - t) / release))


def tone(freq, seconds, attack=.005, release=.005):
    n = round(seconds * RATE)
    return [math.sin(2 * math.pi * freq * i / RATE) * envelope(i, n, attack, release) for i in range(n)]


def silence(seconds):
    return [0.0] * round(seconds * RATE)


def write(folder, name, samples, peak_db, stereo=False):
    top = max(abs(s) for s in samples)
    gain = 10 ** (peak_db / 20) / top
    path = ROOT / folder / (name + ".wav")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(2 if stereo else 1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = struct.pack("<h", round(max(-1.0, min(1.0, s * gain)) * 32767))
            frames += v * (2 if stereo else 1)
        f.writeframes(bytes(frames))
    print("%-28s %.3f s  pico %+.1f dBFS  %s" % (folder + "/" + name, len(samples) / RATE, peak_db, "estéreo" if stereo else "mono"))


# 8 · foco conseguido: dos tonos de 3 kHz de 60 ms separados 40 ms
write("camara", "af_confirmado", tone(3000, .06) + silence(.04) + tone(3000, .06), -9)
# 9 · el autofoco no encuentra (la variante de pitido grave): 450 Hz
write("camara", "af_fallo", tone(450, .35, .008, .03), -9)
# 57 · bloqueo de foco y exposición: un solo pitido de 4 kHz
write("camara", "bloqueo", tone(4000, .12), -9)
