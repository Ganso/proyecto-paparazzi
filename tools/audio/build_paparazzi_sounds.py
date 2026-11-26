#!/usr/bin/env python3
"""Sonidos propios del modo Paparazzi (docs/futuro/29 §20, E8), sintetizados.

    python3 tools/audio/build_paparazzi_sounds.py

Escribe en assets/audio/interfaz/ (WAV PCM, 48 kHz, 16 bits, mono):
- pz_polaroid: el motor que escupe la foto instantánea (zumbido que sube y un chasquido al final).
- pz_hito: tres notas de campanilla que suben (do, mi, sol), al consolidar un hito.
- pz_congelar: un brillo que baja, como de hielo, al congelar el parque.
- pz_otro: una tarjeta que se baraja, al pedir otro encargo.
Empiezan en la primera muestra y acaban en silencio digital. Deterministas (semilla fija).
"""
import math, pathlib, random, struct, wave

RATE = 48000
OUT = pathlib.Path(__file__).resolve().parent.parent.parent / "assets" / "audio" / "interfaz"


def write(name, samples, peak_db):
    top = max(abs(s) for s in samples) or 1.0
    gain = 10 ** (peak_db / 20) / top
    samples = samples + [0.0] * 240
    with wave.open(str(OUT / (name + ".wav")), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, round(s * gain * 32767)))) for s in samples))
    (OUT / (name + ".wav.import")).write_text('[remap]\n\nimporter="keep"\n')


def fade(i, n, attack, release):
    t, total = i / RATE, n / RATE
    return max(0.0, min(1.0, t / attack if attack else 1.0, (total - t) / release if release else 1.0))


def polaroid(rng):
    n = round(.95 * RATE)
    out, phase, lp = [], 0.0, 0.0
    for i in range(n):
        t = i / RATE
        f = 140 + 60 * min(1.0, t / .5)                      # the motor spins up
        phase += 2 * math.pi * f / RATE
        hum = .5 * math.sin(phase) + .25 * math.sin(2 * phase) + .12 * math.sin(3 * phase)
        lp += .08 * (rng.uniform(-1, 1) - lp)                # paper sliding out
        s = (hum * .6 + lp * 1.4) * fade(i, n - round(.12 * RATE), .03, .08) if i < n - round(.12 * RATE) else 0.0
        out.append(s)
    click_at = n - round(.12 * RATE)
    for k in range(round(.03 * RATE)):                       # the print drops out: a click
        out[click_at + k] += math.exp(-k / (.004 * RATE)) * rng.uniform(-1, 1) * 1.2
    return out


def chime(freqs, step, ring):
    n = round((step * (len(freqs) - 1) + ring) * RATE)
    out = [0.0] * n
    for k, f in enumerate(freqs):
        start = round(k * step * RATE)
        for i in range(n - start):
            t = i / RATE
            env = math.exp(-t / (ring * .32)) * min(1.0, t / .004)
            out[start + i] += env * (math.sin(2 * math.pi * f * t) + .3 * math.sin(2 * math.pi * 2.01 * f * t) + .12 * math.sin(2 * math.pi * 3.0 * f * t))
    for i in range(1, round(.02 * RATE)): out[-i] *= i / (.02 * RATE)
    return out


def freeze(rng):
    n = round(.7 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        f = 2600 * (1 - .55 * t / .7)                        # a glitter going down
        s = sum(math.sin(2 * math.pi * f * m * t + m) / m for m in (1, 1.5, 2.25))
        out.append(s * math.exp(-t / .3) * min(1.0, t / .01) * (1 + .3 * rng.uniform(-1, 1)))
    for i in range(1, round(.02 * RATE)): out[-i] *= i / (.02 * RATE)
    return out


def shuffle(rng):
    n = round(.32 * RATE)
    out, lp = [], 0.0
    for i in range(n):
        t = i / RATE
        lp += .35 * (rng.uniform(-1, 1) - lp)
        flicks = sum(math.exp(-max(0.0, t - c) / .012) * (t >= c) for c in (0.0, .07, .13, .18))
        out.append(lp * flicks * fade(i, n, .002, .03))
    return out


if __name__ == "__main__":
    rng = random.Random(2911)
    OUT.mkdir(parents=True, exist_ok=True)
    write("pz_polaroid", polaroid(rng), -8.0)
    write("pz_hito", chime([523.25, 659.25, 783.99], .14, 1.1), -6.0)
    write("pz_congelar", freeze(rng), -10.0)
    write("pz_otro", shuffle(rng), -9.0)
    print("Escritos: pz_polaroid, pz_hito, pz_congelar, pz_otro →", OUT)
